-- Metalnini — slam : le joueur plonge dans la foule (un slam par jour). Ses potes le portent d'un toucher avant la fin du temps
-- (slam_window_min, 120 min) ; chaque porteur fait passer le slam à ses propres potes (notification), la foule grandit.
-- À slam_goal porteurs (5), atterrissage réussi : récompense pour le slammeur (table slam de objective_loot) et pour chaque porteur
-- (table slamcarry, slam_carry_rewards_per_day porteurs récompensés par jour au plus). Temps écoulé avant : écrasé, rien à gagner.
-- La foule : les joueurs liés (potes, dans un sens ou dans l'autre) au slammeur ou à l'un de ses porteurs.

create table if not exists public.slams (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  goal       int not null check (goal >= 1),
  created_at timestamptz not null default now(),
  ends_at    timestamptz not null,
  landed_at  timestamptz,
  claimed    boolean not null default false
);
create index if not exists slams_user on public.slams (user_id, created_at desc);
alter table public.slams enable row level security;   -- tout passe par les fonctions ci-dessous

create table if not exists public.slam_carriers (
  slam_id    uuid not null references public.slams (id) on delete cascade,
  user_id    uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  rewarded   boolean not null,
  claimed    boolean not null default false,
  primary key (slam_id, user_id)
);
create index if not exists slam_carriers_user on public.slam_carriers (user_id, created_at desc);
alter table public.slam_carriers enable row level security;

-- qui a déjà été prévenu d'un slam (une notification par slam et par joueur)
create table if not exists public.slam_notified (
  slam_id uuid not null references public.slams (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  primary key (slam_id, user_id)
);
alter table public.slam_notified enable row level security;

insert into public.settings (key, value) values ('slam_goal', '5'), ('slam_window_min', '120'), ('slam_carry_rewards_per_day', '3')
  on conflict (key) do nothing;
update public.settings set value = value || '{"slam":[{"w":50,"kind":"card"}, {"w":35,"kind":"pack"}, {"w":15,"kind":"ticket"}], "slamcarry":[{"w":70,"kind":"new_commune"}, {"w":30,"kind":"pack"}]}'::jsonb
 where key = 'objective_loot' and not value ? 'slam';

-- deux joueurs liés : l'un suit l'autre
create or replace function public.slam_linked(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.follows where (user_id = a and friend_id = b) or (user_id = b and friend_id = a));
$$;
revoke execute on function public.slam_linked(uuid, uuid) from public, anon, authenticated;

-- dans la foule d'un slam : lié au slammeur ou à un porteur
create or replace function public.slam_in_crowd(p_slam uuid, p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.slams s where s.id = p_slam and s.user_id <> p_user and public.slam_linked(p_user, s.user_id))
      or exists (select 1 from public.slam_carriers c where c.slam_id = p_slam and c.user_id <> p_user and public.slam_linked(p_user, c.user_id));
$$;
revoke execute on function public.slam_in_crowd(uuid, uuid) from public, anon, authenticated;

-- prévenir les potes d'un joueur qu'un slam passe au-dessus d'eux (pas le slammeur, pas ceux qui portent déjà, une fois chacun)
create or replace function public.slam_spread(p_slam uuid, p_from uuid, p_title text, p_body text) returns void
language plpgsql volatile security definer set search_path = public as $$
declare u uuid; v_owner uuid := (select user_id from public.slams where id = p_slam);
begin
  for u in select distinct x from (select friend_id x from public.follows where user_id = p_from union select user_id from public.follows where friend_id = p_from) f
            where x <> v_owner
              and not exists (select 1 from public.slam_carriers c where c.slam_id = p_slam and c.user_id = x)
              and not exists (select 1 from public.slam_notified n where n.slam_id = p_slam and n.user_id = x)
              and not exists (select 1 from public.profiles p where p.id = x and p.blocked) loop
    insert into public.slam_notified (slam_id, user_id) values (p_slam, u);
    perform public.send_push(u, p_title, p_body, 'slam', 'https://pittilloni.github.io/metalnini/proto/?slam=' || p_slam);
  end loop;
end $$;
revoke execute on function public.slam_spread(uuid, uuid, text, text) from public, anon, authenticated;

-- état du slam pour le joueur connecté : le sien (du jour, ou réussi pas encore récupéré), ceux à porter, ceux portés à récupérer
create or replace function public.slam_feed() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_mine jsonb; v_crowd jsonb; v_carried jsonb;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select jsonb_build_object('id', s.id, 'goal', s.goal, 'ends_at', s.ends_at, 'landed', s.landed_at is not null, 'claimed', s.claimed,
           'crashed', s.landed_at is null and now() >= s.ends_at,
           'carriers', coalesce((select jsonb_agg(coalesce(p.username, 'Un pote') order by c.created_at) from public.slam_carriers c join public.profiles p on p.id = c.user_id where c.slam_id = s.id), '[]'))
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
revoke execute on function public.slam_feed() from public, anon;
grant execute on function public.slam_feed() to authenticated;

-- plonger : un slam par jour, au moins un pote pour porter ; les potes sont prévenus
create or replace function public.slam_launch() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_id uuid; v_end timestamptz; v_name text := (select username from public.profiles where id = auth.uid());
begin
  if v_user is null then raise exception 'non connecté'; end if;
  perform 1 from public.profiles where id = v_user for update;   -- deux touchers simultanés ne lancent pas deux slams
  if exists (select 1 from public.slams where user_id = v_user and created_at >= public.paris_day_start()) then
    raise exception 'Un slam par jour : la foule doit reprendre son souffle. Reviens demain.';
  end if;
  if not exists (select 1 from public.follows where user_id = v_user or friend_id = v_user) then
    raise exception 'Personne pour te porter : fais un troc d''abord, tes potes formeront la foule.';
  end if;
  v_end := now() + make_interval(mins => public.setting_int('slam_window_min', 120));
  insert into public.slams (user_id, goal, ends_at) values (v_user, public.setting_int('slam_goal', 5), v_end) returning id into v_id;
  perform public.slam_spread(v_id, v_user, 'Slam en approche',
    coalesce(v_name, 'Un pote') || ' plonge dans la foule. Porte-le avant ' || to_char(v_end at time zone 'Europe/Paris', 'HH24"h"MI') || '.');
  return public.slam_feed();
end $$;
revoke execute on function public.slam_launch() from public, anon;
grant execute on function public.slam_launch() to authenticated;

-- porter : une fois par slam, dans la foule, avant la fin ; le slam passe à mes potes ; atterrissage au dernier porteur
create or replace function public.slam_carry(p_slam uuid) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); s record; v_n int; v_rewarded boolean; v_name text := (select username from public.profiles where id = auth.uid());
        v_owner text; c record;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select * into s from public.slams where id = p_slam for update;   -- les porteurs passent un par un
  if not found then raise exception 'Ce slam n''existe plus.'; end if;
  if s.user_id = v_user then raise exception 'Tu ne peux pas te porter toi-même.'; end if;
  if s.landed_at is not null then raise exception 'Déjà atterri : la foule a fait le boulot.'; end if;
  if now() >= s.ends_at then raise exception 'Trop tard : il s''est écrasé dans la fosse.'; end if;
  if exists (select 1 from public.slam_carriers where slam_id = p_slam and user_id = v_user) then raise exception 'Tu le portes déjà.'; end if;
  if not public.slam_in_crowd(p_slam, v_user) then raise exception 'Ce slam passe trop loin de toi.'; end if;
  v_rewarded := (select count(*) from public.slam_carriers where user_id = v_user and rewarded and created_at >= public.paris_day_start())
                < public.setting_int('slam_carry_rewards_per_day', 3);
  insert into public.slam_carriers (slam_id, user_id, rewarded) values (p_slam, v_user, v_rewarded);
  v_n := (select count(*) from public.slam_carriers where slam_id = p_slam);
  v_owner := coalesce((select username from public.profiles where id = s.user_id), 'Ton pote');
  if v_n >= s.goal then
    update public.slams set landed_at = now() where id = p_slam;
    perform public.send_push(s.user_id, 'Atterrissage réussi', 'La foule t''a porté jusqu''au bout. Ta récompense t''attend dans Metal Corner.', 'slam',
                             'https://pittilloni.github.io/metalnini/proto/?slam=' || p_slam);
    for c in select user_id from public.slam_carriers where slam_id = p_slam and user_id <> v_user and rewarded loop
      perform public.send_push(c.user_id, 'Atterrissage réussi', v_owner || ' a atterri sans bobo. Ta récompense de porteur t''attend.', 'slam',
                               'https://pittilloni.github.io/metalnini/proto/?slam=' || p_slam);
    end loop;
  else
    perform public.send_push(s.user_id, 'Tu planes', coalesce(v_name, 'Un pote') || ' te porte (' || v_n || '/' || s.goal || ').', 'slam',
                             'https://pittilloni.github.io/metalnini/proto/?slam=' || p_slam);
    perform public.slam_spread(p_slam, v_user, 'Un slam passe au-dessus de toi', coalesce(v_name, 'Un pote') || ' porte ' || v_owner || '. Tends les bras.');
  end if;
  return jsonb_build_object('count', v_n, 'goal', s.goal, 'landed', v_n >= s.goal, 'rewarded', v_rewarded);
end $$;
revoke execute on function public.slam_carry(uuid) from public, anon;
grant execute on function public.slam_carry(uuid) to authenticated;

-- récompense d'un slam réussi : le slammeur (table slam) ou un porteur récompensé (table slamcarry), une seule fois
create or replace function public.slam_claim(p_slam uuid) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); s record;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select * into s from public.slams where id = p_slam for update;
  if not found or s.landed_at is null then raise exception 'Pas encore atterri.'; end if;
  if s.user_id = v_user then
    if s.claimed then raise exception 'récompense déjà récupérée'; end if;
    update public.slams set claimed = true where id = p_slam;
    return public.objective_reward(v_user, 'slam');
  end if;
  update public.slam_carriers set claimed = true where slam_id = p_slam and user_id = v_user and rewarded and not claimed;
  if not found then raise exception 'rien à récupérer sur ce slam'; end if;
  return public.objective_reward(v_user, 'slamcarry');
end $$;
revoke execute on function public.slam_claim(uuid) from public, anon;
grant execute on function public.slam_claim(uuid) to authenticated;
