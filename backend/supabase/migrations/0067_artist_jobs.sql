-- Metalnini — demandes d'artistes lancées depuis l'admin et traitées par l'agent cloud (routine Claude Code).
-- « Lancer » met la demande en file ; l'agent la prend (« en cours »), vérifie l'artiste (étape 0), génère les cartes, remplit le
-- catalogue sur une branche artiste/<id>, puis la rend « prête à publier » ; un cas limite revient « à trancher » avec son dossier.
-- « Publier » (fonction artist-publish) fusionne la branche, applique la seed et prévient les demandeurs.
-- L'agent n'a qu'une clé dédiée (empreinte dans worker_keys) qui ne sert qu'à worker_jobs et worker_job_update.

create table if not exists public.artist_jobs (
  id           bigint generated always as identity primary key,
  artist       text not null check (length(artist) between 2 and 80),
  request_ids  bigint[] not null,
  status       text not null default 'queued' check (status in ('queued', 'working', 'review', 'ready', 'published', 'refused', 'error')),
  musician_id  text,                 -- identifiant choisi par l'agent (ex. « durst »)
  branch       text,                 -- branche poussée par l'agent
  note         text,                 -- compte rendu de l'agent (dossier de vérification, choix faits, erreur)
  owner_note   text,                 -- consigne du propriétaire pour la reprise (cas limite tranché, correction)
  launched_by  uuid references auth.users (id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
alter table public.artist_jobs enable row level security;   -- aucun accès direct : tout passe par les fonctions ci-dessous

create table if not exists public.worker_keys (
  hash        text primary key,      -- sha256 hexadécimal de la clé de l'agent
  label       text not null,
  created_at  timestamptz not null default now()
);
alter table public.worker_keys enable row level security;

-- ---------------------------------------------------------------- admin
create or replace function public.admin_jobs() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  return coalesce((select jsonb_agg(to_jsonb(j) order by j.created_at desc) from public.artist_jobs j
                    where j.status not in ('published', 'refused') or j.updated_at > now() - interval '30 days'), '[]'::jsonb);
end $$;

-- lancer le traitement d'une demande (toutes les demandes du même artiste à la fois)
create or replace function public.admin_job_launch(p_ids bigint[], p_artist text, p_note text default null) returns bigint
language plpgsql volatile security definer set search_path = public as $$
declare v bigint;
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  if exists (select 1 from public.artist_jobs where request_ids && p_ids and status not in ('published', 'refused', 'error')) then
    raise exception 'déjà lancée';
  end if;
  insert into public.artist_jobs (artist, request_ids, owner_note, launched_by) values (trim(p_artist), p_ids, nullif(trim(p_note), ''), auth.uid())
    returning id into v;
  insert into public.admin_audit_log (admin_id, action, payload, reason)
    values (auth.uid(), 'artist_job_launch', jsonb_build_object('job', v, 'artist', p_artist), 'demande d''artiste');
  return v;
end $$;

-- suite donnée par le propriétaire : « go » relance avec sa consigne (cas limite tranché, retouche), « refuse » refuse et prévient
create or replace function public.admin_job_decide(p_job bigint, p_action text, p_note text default null) returns void
language plpgsql volatile security definer set search_path = public as $$
declare j public.artist_jobs;
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  select * into j from public.artist_jobs where id = p_job for update;
  if j.id is null then raise exception 'demande introuvable'; end if;
  if p_action = 'go' then
    if j.status not in ('review', 'ready', 'error') then raise exception 'rien à relancer'; end if;
    update public.artist_jobs set status = 'queued', owner_note = nullif(trim(p_note), ''), updated_at = now() where id = p_job;
  elsif p_action = 'refuse' then
    if j.status in ('published', 'refused') then raise exception 'déjà terminée'; end if;
    update public.artist_jobs set status = 'refused', owner_note = nullif(trim(p_note), ''), updated_at = now() where id = p_job;
    perform public.admin_request_handle(j.request_ids, 'refused');
  else raise exception 'action inconnue'; end if;
  insert into public.admin_audit_log (admin_id, action, payload, reason)
    values (auth.uid(), 'artist_job_' || p_action, jsonb_build_object('job', p_job, 'artist', j.artist), coalesce(nullif(trim(p_note), ''), 'demande d''artiste'));
end $$;

-- publication réussie (appelée par la fonction artist-publish, avec le jeton de l'admin) : demandeurs prévenus
create or replace function public.admin_job_published(p_job bigint) returns int
language plpgsql volatile security definer set search_path = public as $$
declare j public.artist_jobs;
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  select * into j from public.artist_jobs where id = p_job for update;
  if j.status <> 'ready' then raise exception 'pas prête à publier'; end if;
  update public.artist_jobs set status = 'published', updated_at = now() where id = p_job;
  insert into public.admin_audit_log (admin_id, action, payload, reason)
    values (auth.uid(), 'artist_job_publish', jsonb_build_object('job', p_job, 'artist', j.artist, 'musician', j.musician_id), 'demande d''artiste');
  return public.admin_request_handle(j.request_ids, 'added');
end $$;

-- ---------------------------------------------------------------- agent cloud (clé dédiée, aucun autre droit)
create or replace function public.worker_ok(p_key text) returns boolean
language sql stable security definer set search_path = public, extensions as $$
  select exists (select 1 from public.worker_keys where hash = encode(extensions.digest(p_key, 'sha256'), 'hex'));
$$;

-- demandes à traiter : les « queued » passent « working » ; une « working » de plus de 6 h est reprise (agent interrompu)
create or replace function public.worker_jobs(p_key text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v jsonb;
begin
  if not public.worker_ok(p_key) then raise exception 'clé refusée'; end if;
  with t as (update public.artist_jobs set status = 'working', updated_at = now()
              where status = 'queued' or (status = 'working' and updated_at < now() - interval '6 hours') returning *)
  select coalesce(jsonb_agg(jsonb_build_object('id', t.id, 'artist', t.artist, 'owner_note', t.owner_note, 'previous_note', t.note,
           'musician_id', t.musician_id, 'branch', t.branch,
           'notes', (select jsonb_agg(r.note) from public.artist_requests r where r.id = any(t.request_ids) and r.note is not null))), '[]'::jsonb)
    into v from t;
  return v;
end $$;

-- compte rendu de l'agent : « review » (cas limite, dossier dans note), « ready » (branche prête), « error »
create or replace function public.worker_job_update(p_key text, p_job bigint, p_status text, p_note text, p_musician text default null, p_branch text default null) returns void
language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.worker_ok(p_key) then raise exception 'clé refusée'; end if;
  if p_status not in ('review', 'ready', 'error') then raise exception 'statut refusé'; end if;
  update public.artist_jobs set status = p_status, note = left(p_note, 8000), musician_id = coalesce(p_musician, musician_id),
         branch = coalesce(p_branch, branch), updated_at = now()
   where id = p_job and status = 'working';
  if not found then raise exception 'demande pas en cours'; end if;
end $$;

revoke execute on function public.admin_jobs(), public.admin_job_launch(bigint[], text, text), public.admin_job_decide(bigint, text, text),
  public.admin_job_published(bigint) from public, anon;
grant execute on function public.admin_jobs(), public.admin_job_launch(bigint[], text, text), public.admin_job_decide(bigint, text, text),
  public.admin_job_published(bigint) to authenticated;
revoke execute on function public.worker_ok(text) from public, anon, authenticated;
revoke execute on function public.worker_jobs(text), public.worker_job_update(text, bigint, text, text, text, text) from public;
grant execute on function public.worker_jobs(text), public.worker_job_update(text, bigint, text, text, text, text) to anon;
