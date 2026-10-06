-- Metalnini — messages ciblés de l'admin : on choisit la cible (app installée ou non, notifications activées ou non, plateforme,
-- joueurs actifs ou inactifs depuis N jours, ou des joueurs choisis), on voit l'audience avant d'envoyer. Ceux qui ont les
-- notifications reçoivent une notification ; les autres (ou si leur budget du jour est atteint) trouvent le message dans l'app
-- à la prochaine ouverture. Le message peut mener à un écran (lien de l'app). Tout envoi est inscrit au journal de l'admin.

create table if not exists public.player_messages (
  id         bigserial primary key,
  user_id    uuid not null references auth.users (id) on delete cascade,
  title      text not null,
  body       text not null,
  url        text,
  created_at timestamptz not null default now(),
  seen       boolean not null default false
);
create index if not exists player_messages_user on public.player_messages (user_id, seen);
alter table public.player_messages enable row level security;   -- lecture par my_messages

-- joueurs visés par un filtre : installed, push (true / false / absent = indifférent), platform, active_days (venu depuis N jours),
-- inactive_days (pas venu depuis N jours), users (liste d'identifiants : prioritaire sur le reste)
create or replace function public.admin_targets(p_filter jsonb) returns setof uuid
language sql stable security definer set search_path = public as $$
  select p.id from public.profiles p join auth.users u on u.id = p.id
   where not coalesce(p.blocked, false) and not u.is_anonymous
     and (jsonb_typeof(p_filter -> 'users') is distinct from 'array' or p.id::text in (select jsonb_array_elements_text(p_filter -> 'users')))
     and (p_filter ->> 'installed' is null or (p.installed_at is not null) = (p_filter ->> 'installed')::boolean)
     and (p_filter ->> 'push' is null or exists (select 1 from public.push_subscriptions s where s.user_id = p.id) = (p_filter ->> 'push')::boolean)
     and (p_filter ->> 'platform' is null or p.last_platform = p_filter ->> 'platform')
     and (p_filter ->> 'active_days' is null or p.last_seen_at >= now() - make_interval(days => (p_filter ->> 'active_days')::int))
     and (p_filter ->> 'inactive_days' is null or p.last_seen_at is null or p.last_seen_at < now() - make_interval(days => (p_filter ->> 'inactive_days')::int))
$$;
revoke execute on function public.admin_targets(jsonb) from public, anon, authenticated;

-- audience d'un filtre : combien de joueurs, dont combien joignables par notification
create or replace function public.admin_audience(p_filter jsonb) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  return (select jsonb_build_object('players', count(*), 'push', count(*) filter (where exists (select 1 from public.push_subscriptions s where s.user_id = t.id)))
            from public.admin_targets(coalesce(p_filter, '{}'::jsonb)) t(id));
end $$;
revoke execute on function public.admin_audience(jsonb) from public, anon;
grant execute on function public.admin_audience(jsonb) to authenticated;

-- envoyer : notification si possible (p_force : hors budget du jour), sinon message dans l'app ; renvoie les deux comptes
create or replace function public.admin_send_message(p_title text, p_body text, p_url text, p_filter jsonb, p_reason text, p_force boolean default false) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u uuid; n_push int := 0; n_inbox int := 0; v_url text := nullif(trim(coalesce(p_url, '')), '');
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  if p_reason is null or length(trim(p_reason)) = 0 then raise exception 'motif obligatoire'; end if;
  if length(trim(coalesce(p_title, ''))) not between 3 and 60 then raise exception 'titre : 3 à 60 caractères'; end if;
  if length(trim(coalesce(p_body, ''))) not between 3 and 160 then raise exception 'message : 3 à 160 caractères'; end if;
  if v_url is not null and v_url !~ '^https://pittilloni\.github\.io/metalnini/proto/' then raise exception 'le lien doit mener dans l''app'; end if;
  for u in select * from public.admin_targets(coalesce(p_filter, '{}'::jsonb)) loop
    if public.send_push(u, trim(p_title), trim(p_body), 'annonce', coalesce(v_url, 'https://pittilloni.github.io/metalnini/proto/'), coalesce(p_force, false)) then n_push := n_push + 1;
    else insert into public.player_messages (user_id, title, body, url) values (u, trim(p_title), trim(p_body), v_url); n_inbox := n_inbox + 1; end if;
  end loop;
  insert into public.admin_audit_log (admin_id, action, payload, reason)
    values (auth.uid(), 'targeted_message', jsonb_build_object('title', trim(p_title), 'body', trim(p_body), 'url', v_url, 'filter', p_filter, 'push', n_push, 'inbox', n_inbox), p_reason);
  return jsonb_build_object('push', n_push, 'inbox', n_inbox);
end $$;
revoke execute on function public.admin_send_message(text, text, text, jsonb, text, boolean) from public, anon;
grant execute on function public.admin_send_message(text, text, text, jsonb, text, boolean) to authenticated;

-- messages pas encore vus (puis marqués vus), montrés à l'ouverture de l'app
create or replace function public.my_messages() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v jsonb;
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('title', title, 'body', body, 'url', url) order by created_at), '[]'::jsonb) into v
    from public.player_messages where user_id = auth.uid() and not seen and created_at > now() - interval '30 days';
  update public.player_messages set seen = true where user_id = auth.uid() and not seen;
  return v;
end $$;
revoke execute on function public.my_messages() from public, anon;
grant execute on function public.my_messages() to authenticated;
