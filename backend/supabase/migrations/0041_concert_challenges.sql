-- Metalnini — défis de concert et récompenses des concerts.
-- Défis : créés dans l'admin (photo du pit, slam, circle pit…) ; le joueur en choisit jusqu'à 3 par concert, à l'avance ou sur place,
-- et les valide par une preuve (photo, ou vidéo de 10 s) le jour du concert ou dans les 2 jours qui suivent.
-- Validation automatique, l'admin peut annuler une preuve après coup. Les points de rang sont comptés par l'app à partir de ces lignes.
-- Récompenses : carte Rare de l'artiste (une fois par musicien du jeu, claim_concert) et objectif « Premier concert » (claim_objective).

create table if not exists public.concert_challenges (
  id         uuid primary key default gen_random_uuid(),
  title      text not null check (char_length(btrim(title)) between 2 and 60),
  hint       text check (hint is null or char_length(hint) <= 200),
  proof      text not null default 'photo' check (proof in ('photo', 'video')),
  points     int not null default 2 check (points between 0 and 20),
  band_only  boolean not null default false,
  active     boolean not null default true,
  sort       int not null default 0,
  created_at timestamptz not null default now()
);
alter table public.concert_challenges enable row level security;
drop policy if exists "défis: lecture" on public.concert_challenges;
create policy "défis: lecture" on public.concert_challenges for select to authenticated using (active or public.is_admin());
drop policy if exists "défis: admin" on public.concert_challenges;
create policy "défis: admin" on public.concert_challenges for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- premiers défis (idées du propriétaire), seulement si la liste est vide
insert into public.concert_challenges (title, hint, proof, points, sort)
select * from (values
  ('Photo du pit', 'Le pit vu de l''intérieur, en plein morceau.', 'photo', 2, 1),
  ('Crie son nom', 'Hurle le nom de l''artiste entre deux morceaux.', 'video', 2, 2),
  ('Headbanging', 'Dix secondes de nuque en roue libre.', 'video', 2, 3),
  ('Circle pit', 'Un tour complet dans le cercle.', 'video', 3, 4),
  ('Slam', 'Porté par la foule, en respectant la sécurité de la salle.', 'video', 4, 5)) v(title, hint, proof, points, sort)
where not exists (select 1 from public.concert_challenges);

create table if not exists public.concert_picks (
  concert_id   uuid not null references public.concerts (id) on delete cascade,
  challenge_id uuid not null references public.concert_challenges (id) on delete cascade,
  user_id      uuid not null references auth.users (id) on delete cascade,
  picked_early boolean not null,   -- choisi avant le jour du concert : un point de plus
  proof_path   text,
  proof_kind   text check (proof_kind is null or proof_kind in ('photo', 'video')),
  proof_public boolean not null default false,
  done_at      timestamptz,
  cancelled    boolean not null default false,   -- preuve refusée par l'admin : plus de points
  created_at   timestamptz not null default now(),
  primary key (concert_id, challenge_id)
);
create index if not exists concert_picks_user on public.concert_picks (user_id);
create index if not exists concert_picks_done on public.concert_picks (done_at desc) where done_at is not null;
alter table public.concert_picks enable row level security;   -- écritures par les fonctions ci-dessous
drop policy if exists "défis choisis: les siens et l'admin" on public.concert_picks;
create policy "défis choisis: les siens et l'admin" on public.concert_picks for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

-- concert dont la carte bonus de l'artiste a été réclamée ; une seule par musicien et par joueur
alter table public.concerts add column if not exists claimed boolean not null default false;
create table if not exists public.concert_bonuses (
  user_id     uuid not null references auth.users (id) on delete cascade,
  musician_id text not null references public.musicians (id) on delete cascade,
  concert_id  uuid references public.concerts (id) on delete set null,
  created_at  timestamptz not null default now(),
  primary key (user_id, musician_id)
);
alter table public.concert_bonuses enable row level security;

-- preuves (photo ou vidéo de 10 s) dans le même dossier que les photos souvenir ; visibles des potes si le joueur l'a choisi
update storage.buckets set file_size_limit = 31457280,
  allowed_mime_types = array['image/jpeg','image/png','image/webp','video/mp4','video/quicktime','video/webm'] where id = 'concerts';
drop policy if exists "concerts: lecture" on storage.objects;
create policy "concerts: lecture" on storage.objects for select to authenticated
  using (bucket_id = 'concerts' and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.is_admin()
    or exists (select 1 from public.concerts c join public.follows f on f.friend_id = c.user_id
                where c.photo_path = name and c.photo_public and f.user_id = auth.uid())
    or exists (select 1 from public.concert_picks p join public.follows f on f.friend_id = p.user_id
                where p.proof_path = name and p.proof_public and not p.cancelled and f.user_id = auth.uid())));

update public.settings set value = value || '{"concert":[{"w":60,"kind":"pack"}, {"w":40,"kind":"new_commune"}]}'::jsonb
 where key = 'objective_loot' and not value ? 'concert';
insert into public.settings (key, value) values ('concert_challenges_max', '3'::jsonb) on conflict (key) do nothing;

-- choisir un défi pour un de ses concerts : au plus concert_challenges_max, jusqu'à la fin de la fenêtre de preuve
create or replace function public.pick_challenge(p_concert uuid, p_challenge uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_date date; v_max int;
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  select played_on into v_date from public.concerts where id = p_concert and user_id = auth.uid();
  if v_date is null then raise exception 'concert introuvable'; end if;
  if current_date > v_date + 2 then raise exception 'Trop tard : les défis se choisissent jusqu''à 2 jours après le concert.'; end if;
  if not exists (select 1 from public.concert_challenges where id = p_challenge and active and not band_only) then raise exception 'défi indisponible'; end if;
  select coalesce((select value::int from public.settings where key = 'concert_challenges_max'), 3) into v_max;
  if (select count(*) from public.concert_picks where concert_id = p_concert) >= v_max then raise exception 'Déjà % défis pour ce concert.', v_max; end if;
  insert into public.concert_picks (concert_id, challenge_id, user_id, picked_early)
  values (p_concert, p_challenge, auth.uid(), current_date < v_date) on conflict do nothing;
end $$;

create or replace function public.unpick_challenge(p_concert uuid, p_challenge uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  delete from public.concert_picks where concert_id = p_concert and challenge_id = p_challenge and user_id = auth.uid() and done_at is null;
  if not found then raise exception 'défi déjà relevé ou introuvable'; end if;
end $$;

-- preuve envoyée : le défi est relevé (le jour du concert ou dans les 2 jours) ; renvoie les points gagnés
create or replace function public.complete_challenge(p_concert uuid, p_challenge uuid, p_path text, p_kind text, p_public boolean)
returns int language plpgsql security definer set search_path = public as $$
declare v_date date; v_pick record; v_points int;
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  if p_path is null or split_part(p_path, '/', 1) <> auth.uid()::text then raise exception 'chemin invalide'; end if;
  select played_on into v_date from public.concerts where id = p_concert and user_id = auth.uid();
  if v_date is null then raise exception 'concert introuvable'; end if;
  if current_date < v_date then raise exception 'Patience : la preuve s''envoie le jour du concert.'; end if;
  if current_date > v_date + 2 then raise exception 'Trop tard : la preuve s''envoie dans les 2 jours qui suivent le concert.'; end if;
  select * into v_pick from public.concert_picks where concert_id = p_concert and challenge_id = p_challenge and user_id = auth.uid() for update;
  if not found then raise exception 'choisis d''abord ce défi'; end if;
  if v_pick.done_at is not null then raise exception 'défi déjà relevé'; end if;
  if p_kind is distinct from (select proof from public.concert_challenges where id = p_challenge) then raise exception 'mauvais type de preuve'; end if;
  update public.concert_picks set proof_path = p_path, proof_kind = p_kind, proof_public = coalesce(p_public, false), done_at = now()
   where concert_id = p_concert and challenge_id = p_challenge;
  select points into v_points from public.concert_challenges where id = p_challenge;
  return v_points + case when v_pick.picked_early then 1 else 0 end;
end $$;

-- admin : annuler (ou rétablir) une preuve
create or replace function public.admin_cancel_challenge(p_concert uuid, p_challenge uuid, p_cancel boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  update public.concert_picks set cancelled = p_cancel where concert_id = p_concert and challenge_id = p_challenge and done_at is not null;
  if not found then raise exception 'preuve introuvable'; end if;
end $$;

-- talon validé (concert passé) : carte Rare de l'artiste s'il est dans le jeu et que le joueur ne l'a jamais reçue par un concert
create or replace function public.claim_concert(p_concert uuid) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_c record;
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  select * into v_c from public.concerts where id = p_concert and user_id = auth.uid() for update;
  if not found then raise exception 'concert introuvable'; end if;
  if v_c.played_on > current_date then raise exception 'Le concert n''a pas encore eu lieu.'; end if;
  if v_c.claimed then raise exception 'talon déjà validé'; end if;
  update public.concerts set claimed = true where id = p_concert;
  if v_c.musician_id is not null and exists (select 1 from public.musicians where id = v_c.musician_id and active)
     and not exists (select 1 from public.concert_bonuses where user_id = auth.uid() and musician_id = v_c.musician_id) then
    insert into public.concert_bonuses (user_id, musician_id, concert_id) values (auth.uid(), v_c.musician_id, p_concert);
    return public.give_card(auth.uid(), v_c.musician_id, 'rare');
  end if;
  return null;
end $$;

-- objectif « Premier concert » : clé concert, vérifiée sur un concert passé
alter table public.objective_claims drop constraint if exists objective_claims_key_check;
alter table public.objective_claims add constraint objective_claims_key_check check (key ~ '^(binder|mastery|quiz):[a-z0-9-]+$' or key in ('avatar', 'share', 'cry', 'concert'));
create or replace function public.claim_objective(p_key text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_kind text := split_part(p_key, ':', 1); v_id text := split_part(p_key, ':', 2); v_reward jsonb;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  perform 1 from public.profiles where id = v_user for update;   -- deux touchers simultanés ne donnent pas deux récompenses
  if exists (select 1 from public.objective_claims where user_id = v_user and key = p_key) then raise exception 'récompense déjà récupérée'; end if;

  if v_kind = 'binder' then
    if not exists (select 1 from public.binders where id = v_id) then raise exception 'classeur inconnu'; end if;
    if exists (select 1 from public.musicians m
                where m.active and (v_id = 'all' or m.id in (select musician_id from public.binder_members where binder_id = v_id))
                  and not public.card_placed(v_user, m.id)) then
      raise exception 'classeur pas encore complet';
    end if;
    v_reward := public.objective_reward(v_user, 'binder');
  elsif v_kind = 'mastery' then
    if (select count(distinct rarity) from public.inventory where user_id = v_user and musician_id = v_id and placed and copies > 0) < 5 then
      raise exception 'maîtrise pas encore atteinte';
    end if;
    v_reward := public.objective_reward(v_user, 'mastery');
  elsif p_key = 'cry' then
    if not exists (select 1 from public.profiles where id = v_user and cry_path is not null) then raise exception 'enregistre d''abord ton cri'; end if;
    update public.profiles set cry_gift_claimed = true where id = v_user;
    v_reward := public.objective_reward(v_user, 'cry');
  elsif p_key in ('avatar', 'share') then
    if p_key = 'avatar' and not exists (select 1 from public.profiles where id = v_user and avatar_path is not null) then
      raise exception 'ajoute d''abord ta photo';
    end if;
    v_reward := public.objective_reward(v_user, 'small');
  elsif p_key = 'concert' then
    if not exists (select 1 from public.concerts where user_id = v_user and played_on <= current_date) then raise exception 'note d''abord un concert passé'; end if;
    v_reward := public.objective_reward(v_user, 'concert');
  else
    raise exception 'objectif inconnu';
  end if;

  insert into public.objective_claims (user_id, key, reward) values (v_user, p_key, v_reward);
  return v_reward;
end $$;

-- talons d'un pote : + défis relevés (titre, points, preuve seulement si rendue visible)
drop function if exists public.friend_concerts(uuid);
create or replace function public.friend_concerts(p_friend uuid)
returns table (id uuid, artist text, musician_id text, played_on date, venue text, city text, photo_path text, picks jsonb)
language plpgsql stable security definer set search_path = public as $$
begin
  if not exists (select 1 from public.follows where user_id = auth.uid() and friend_id = p_friend) then raise exception 'pas dans tes potes'; end if;
  return query select c.id, c.artist, c.musician_id, c.played_on, c.venue, c.city, case when c.photo_public then c.photo_path end,
    coalesce((select jsonb_agg(jsonb_build_object('title', ch.title, 'points', ch.points + case when p.picked_early then 1 else 0 end,
                'proof_path', case when p.proof_public then p.proof_path end, 'proof_kind', p.proof_kind))
                from public.concert_picks p join public.concert_challenges ch on ch.id = p.challenge_id
               where p.concert_id = c.id and p.done_at is not null and not p.cancelled), '[]'::jsonb)
    from public.concerts c where c.user_id = p_friend order by c.played_on desc;
end $$;

revoke execute on function public.pick_challenge(uuid, uuid) from public, anon;
revoke execute on function public.unpick_challenge(uuid, uuid) from public, anon;
revoke execute on function public.complete_challenge(uuid, uuid, text, text, boolean) from public, anon;
revoke execute on function public.admin_cancel_challenge(uuid, uuid, boolean) from public, anon;
revoke execute on function public.claim_concert(uuid) from public, anon;
revoke execute on function public.claim_objective(text) from public, anon;
revoke execute on function public.friend_concerts(uuid) from public, anon;
grant execute on function public.pick_challenge(uuid, uuid) to authenticated;
grant execute on function public.unpick_challenge(uuid, uuid) to authenticated;
grant execute on function public.complete_challenge(uuid, uuid, text, text, boolean) to authenticated;
grant execute on function public.admin_cancel_challenge(uuid, uuid, boolean) to authenticated;
grant execute on function public.claim_concert(uuid) to authenticated;
grant execute on function public.claim_objective(text) to authenticated;
grant execute on function public.friend_concerts(uuid) to authenticated;
