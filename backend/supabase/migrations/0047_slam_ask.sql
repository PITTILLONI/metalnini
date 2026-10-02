-- Metalnini — « Porte-moi » : pendant son slam, le joueur demande à un pote précis de le porter (notification qui ouvre le slam),
-- une fois par pote et par slam. slam_feed donne aussi les identifiants des porteurs et des potes déjà sollicités.

create table if not exists public.slam_asks (
  slam_id    uuid not null references public.slams (id) on delete cascade,
  user_id    uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (slam_id, user_id)
);
alter table public.slam_asks enable row level security;   -- tout passe par les fonctions ci-dessous

create or replace function public.slam_ask(p_friend uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); s record; v_name text := (select username from public.profiles where id = auth.uid()); v_left int;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select * into s from public.slams where user_id = v_user and landed_at is null and now() < ends_at order by created_at desc limit 1;
  if not found then raise exception 'Tu ne slammes pas en ce moment.'; end if;
  if not public.slam_linked(v_user, p_friend) then raise exception 'pas dans tes potes'; end if;
  if exists (select 1 from public.slam_carriers where slam_id = s.id and user_id = p_friend) then raise exception 'Il te porte déjà.'; end if;
  insert into public.slam_asks (slam_id, user_id) values (s.id, p_friend) on conflict do nothing;
  if not found then raise exception 'Déjà demandé : laisse-lui le temps de tendre les bras.'; end if;
  v_left := greatest(1, ceil(extract(epoch from s.ends_at - now()) / 60))::int;
  perform public.send_push(p_friend, 'Porte-moi !', coalesce(v_name, 'Un pote') || ' plane au-dessus de la foule et compte sur toi. Encore '
    || case when v_left >= 60 then (v_left / 60) || ' h ' || lpad((v_left % 60)::text, 2, '0') else v_left || ' min' end || '.', 'slam',
    'https://pittilloni.github.io/metalnini/proto/?slam=' || s.id);
end $$;
revoke execute on function public.slam_ask(uuid) from public, anon;
grant execute on function public.slam_ask(uuid) to authenticated;

-- mon slam : en plus, les identifiants des porteurs et des potes sollicités
create or replace function public.slam_feed() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_mine jsonb; v_crowd jsonb; v_carried jsonb;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select jsonb_build_object('id', s.id, 'goal', s.goal, 'ends_at', s.ends_at, 'landed', s.landed_at is not null, 'claimed', s.claimed,
           'crashed', s.landed_at is null and now() >= s.ends_at,
           'carriers', coalesce((select jsonb_agg(coalesce(p.username, 'Un pote') order by c.created_at) from public.slam_carriers c join public.profiles p on p.id = c.user_id where c.slam_id = s.id), '[]'),
           'carrier_ids', coalesce((select jsonb_agg(c.user_id) from public.slam_carriers c where c.slam_id = s.id), '[]'),
           'asked_ids', coalesce((select jsonb_agg(a.user_id) from public.slam_asks a where a.slam_id = s.id), '[]'))
    into v_mine from public.slams s
   where s.user_id = v_user and (s.created_at >= public.paris_day_start() or (s.landed_at is not null and not s.claimed))
   order by s.created_at desc limit 1;
  select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'name', coalesce(p.username, 'Un pote'), 'goal', s.goal, 'ends_at', s.ends_at,
           'count', (select count(*) from public.slam_carriers c where c.slam_id = s.id)) order by s.ends_at), '[]')
    into v_crowd from public.slams s join public.profiles p on p.id = s.user_id
   where s.landed_at is null and now() < s.ends_at and s.user_id <> v_user
     and not exists (select 1 from public.slam_carriers c where c.slam_id = s.id and c.user_id = v_user)
     and public.slam_in_crowd(s.id, v_user);
  select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'name', coalesce(p.username, 'Un pote'), 'goal', s.goal, 'ends_at', s.ends_at,
           'count', (select count(*) from public.slam_carriers x where x.slam_id = s.id), 'landed', s.landed_at is not null, 'rewarded', c.rewarded) order by c.created_at desc), '[]')
    into v_carried from public.slam_carriers c join public.slams s on s.id = c.slam_id join public.profiles p on p.id = s.user_id
   where c.user_id = v_user and not c.claimed
     and ((s.landed_at is not null and c.rewarded) or (s.landed_at is null and now() < s.ends_at));
  return jsonb_build_object('mine', v_mine, 'crowd', v_crowd, 'carried', v_carried,
           'goal', public.setting_int('slam_goal', 5), 'window', public.setting_int('slam_window_min', 120));
end $$;
