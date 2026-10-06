-- Metalnini — circle pit : un joueur lance un pit de 2 minutes (le temps d'un morceau) sur l'extrait de son choix. Ses potes
-- sont prévenus et rejoignent le cercle par la notification, le lien ou le QR ; chaque coureur prévient à son tour ses potes
-- (on rameute, comme dans la vraie fosse). Chacun tape « Courir » : le cercle tourne. À la fin, le gain dépend de deux paliers :
-- le nombre de coureurs et la vitesse moyenne (tours par coureur). Points de rang pour tous (+1 pour qui l'a lancé), et à partir
-- des paliers hauts une récompense tirée dans objective_loot (tables pit1, pit2). Un pit lancé par jour ; 3 pits récompensés
-- par jour et par coureur. Les touchers sont plafonnés côté serveur (vitesse humaine).

insert into public.settings (key, value) values ('pit', '{
  "duration_s": 120, "max_tps": 8, "rewards_per_day": 3,
  "sizes":  [{"min": 2, "label": "Petit cercle", "pts": 1}, {"min": 5, "label": "Vrai pit", "pts": 2}, {"min": 10, "label": "Cyclone", "pts": 3}, {"min": 20, "label": "Ouragan", "pts": 5}],
  "speeds": [{"min": 0, "label": "Tranquille", "mult": 1}, {"min": 1.5, "label": "Endiablé", "mult": 2}, {"min": 3, "label": "Infernal", "mult": 3}],
  "loot": [{"size": 1, "speed": 1, "table": "pit1"}, {"size": 2, "speed": 2, "table": "pit2"}]
}'::jsonb) on conflict (key) do nothing;
update public.settings set value = value || '{"pit1":[{"w":70,"kind":"new_commune"}, {"w":30,"kind":"pack"}], "pit2":[{"w":50,"kind":"card"}, {"w":40,"kind":"pack"}, {"w":10,"kind":"ticket"}]}'::jsonb
 where key = 'objective_loot' and not (value ? 'pit1');

create table if not exists public.pits (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  track      text not null,            -- musicien dont l'extrait passe pendant le pit
  created_at timestamptz not null default now(),
  ends_at    timestamptz not null
);
create index if not exists pits_user on public.pits (user_id, created_at desc);
alter table public.pits enable row level security;   -- tout passe par les fonctions ci-dessous

create table if not exists public.pit_runners (
  pit_id    uuid not null references public.pits (id) on delete cascade,
  user_id   uuid not null references auth.users (id) on delete cascade,
  joined_at timestamptz not null default now(),
  taps      int not null default 0,
  last_at   timestamptz not null default now(),
  rewarded  boolean not null,          -- dans le plafond du jour
  points    int,                       -- points de rang, fixés à la récupération
  claimed   boolean not null default false,
  primary key (pit_id, user_id)
);
create index if not exists pit_runners_user on public.pit_runners (user_id, joined_at desc);
alter table public.pit_runners enable row level security;

create table if not exists public.pit_notified (
  pit_id  uuid not null references public.pits (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  primary key (pit_id, user_id)
);
alter table public.pit_notified enable row level security;

-- prévenir les potes d'un joueur (une notification par pit et par joueur, ni les coureurs ni le lanceur)
create or replace function public.pit_spread(p_pit uuid, p_from uuid, p_body text) returns void
language plpgsql volatile security definer set search_path = public as $$
declare f record; p record;
begin
  select * into p from public.pits where id = p_pit;
  for f in select distinct x.id from (select friend_id as id from public.follows where user_id = p_from
                                       union select user_id from public.follows where friend_id = p_from) x
            where x.id <> p.user_id and not exists (select 1 from public.pit_runners r where r.pit_id = p_pit and r.user_id = x.id) loop
    insert into public.pit_notified (pit_id, user_id) values (p_pit, f.id) on conflict do nothing;
    if found then
      perform public.send_push(f.id, 'Circle pit !', p_body, 'pit', 'https://pittilloni.github.io/metalnini/proto/?pit=' || p_pit);
    end if;
  end loop;
end $$;
revoke execute on function public.pit_spread(uuid, uuid, text) from public, anon, authenticated;

-- palier atteint : nombre de coureurs et vitesse moyenne (tours par coureur et par seconde, un tour = un toucher)
create or replace function public.pit_tier(p_pit uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare cfg jsonb := (select value from public.settings where key = 'pit'); n int; t int; v numeric; si int := -1; vi int := 0; i int;
begin
  select count(*), coalesce(sum(taps), 0) into n, t from public.pit_runners where pit_id = p_pit;
  v := case when n = 0 then 0 else round(t::numeric / n / (cfg ->> 'duration_s')::int, 2) end;
  for i in 0 .. jsonb_array_length(cfg -> 'sizes') - 1 loop if n >= (cfg -> 'sizes' -> i ->> 'min')::int then si := i; end if; end loop;
  for i in 0 .. jsonb_array_length(cfg -> 'speeds') - 1 loop if v >= (cfg -> 'speeds' -> i ->> 'min')::numeric then vi := i; end if; end loop;
  return jsonb_build_object('runners', n, 'taps', t, 'speed', v, 'size', si, 'speed_tier', vi,
    'size_label', case when si >= 0 then cfg -> 'sizes' -> si ->> 'label' end, 'speed_label', cfg -> 'speeds' -> vi ->> 'label',
    'points', case when si >= 0 then (cfg -> 'sizes' -> si ->> 'pts')::int * (cfg -> 'speeds' -> vi ->> 'mult')::int else 0 end);
end $$;
revoke execute on function public.pit_tier(uuid) from public, anon, authenticated;

-- état d'un pit (pour l'écran en direct) : coureurs avec photo, temps, palier en cours, ma part
create or replace function public.pit_state(p_pit uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := auth.uid(); p record; me record;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select * into p from public.pits where id = p_pit;
  if not found then raise exception 'Ce circle pit n''existe plus.'; end if;
  select * into me from public.pit_runners where pit_id = p_pit and user_id = v_user;
  return jsonb_build_object('id', p.id, 'track', p.track, 'ends_at', p.ends_at, 'over', now() >= p.ends_at, 'host', p.user_id = v_user,
    'host_name', coalesce((select username from public.profiles where id = p.user_id), 'Un pote'),
    'runners', coalesce((select jsonb_agg(jsonb_build_object('id', r.user_id, 'name', coalesce(pr.username, 'Un pote'), 'avatar', pr.avatar_path, 'taps', r.taps, 'me', r.user_id = v_user) order by r.joined_at)
                           from public.pit_runners r left join public.profiles pr on pr.id = r.user_id where r.pit_id = p_pit), '[]'),
    'tier', public.pit_tier(p_pit), 'in', me.user_id is not null, 'rewarded', coalesce(me.rewarded, false), 'claimed', coalesce(me.claimed, false));
end $$;
revoke execute on function public.pit_state(uuid) from public, anon;
grant execute on function public.pit_state(uuid) to authenticated;

-- lancer un pit : un par jour, au moins un pote ; l'extrait est un musicien du jeu
create or replace function public.pit_open(p_track text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_id uuid; v_name text := (select username from public.profiles where id = auth.uid());
        cfg jsonb := (select value from public.settings where key = 'pit');
begin
  if v_user is null then raise exception 'non connecté'; end if;
  perform 1 from public.profiles where id = v_user for update;
  if exists (select 1 from public.pits where user_id = v_user and created_at >= public.paris_day_start()) then
    raise exception 'Un circle pit lancé par jour : tes jambes ont besoin de repos. Rejoins celui d''un pote.';
  end if;
  if not exists (select 1 from public.follows where user_id = v_user or friend_id = v_user) then
    raise exception 'Personne pour courir avec toi : ajoute des potes d''abord.';
  end if;
  if not exists (select 1 from public.musicians where id = p_track and active) then raise exception 'Cet extrait n''est pas dans le jeu.'; end if;
  insert into public.pits (user_id, track, ends_at) values (v_user, p_track, now() + make_interval(secs => (cfg ->> 'duration_s')::int)) returning id into v_id;
  insert into public.pit_runners (pit_id, user_id, rewarded) values (v_id, v_user, true);
  perform public.pit_spread(v_id, v_user, coalesce(v_name, 'Un pote') || ' ouvre un circle pit sur ' || (select name from public.musicians where id = p_track) || '. 2 minutes, viens courir !');
  return public.pit_state(v_id);
end $$;
revoke execute on function public.pit_open(text) from public, anon;
grant execute on function public.pit_open(text) to authenticated;

-- rejoindre (notification, lien ou QR) : on devient pote du lanceur, et ses propres potes sont prévenus à leur tour
create or replace function public.pit_join(p_pit uuid) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); p record; v_name text := (select username from public.profiles where id = auth.uid()); v_rewarded boolean;
        cfg jsonb := (select value from public.settings where key = 'pit');
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select * into p from public.pits where id = p_pit;
  if not found then raise exception 'Ce circle pit n''existe plus.'; end if;
  if now() >= p.ends_at then return public.pit_state(p_pit); end if;
  if not exists (select 1 from public.pit_runners where pit_id = p_pit and user_id = v_user) then
    v_rewarded := (select count(*) from public.pit_runners r join public.pits x on x.id = r.pit_id
                    where r.user_id = v_user and r.rewarded and x.user_id <> v_user and r.joined_at >= public.paris_day_start()) < (cfg ->> 'rewards_per_day')::int;
    insert into public.pit_runners (pit_id, user_id, rewarded) values (p_pit, v_user, v_rewarded) on conflict do nothing;
    perform public.make_friends(v_user, p.user_id);
    perform public.pit_spread(p_pit, v_user, coalesce(v_name, 'Un pote') || ' court dans le circle pit de '
      || coalesce((select username from public.profiles where id = p.user_id), 'son pote') || '. Rejoins le cercle avant la fin !');
  end if;
  return public.pit_state(p_pit);
end $$;
revoke execute on function public.pit_join(uuid) from public, anon;
grant execute on function public.pit_join(uuid) to authenticated;

-- courir : les touchers envoyés par lots, plafonnés à une vitesse humaine depuis le dernier lot
create or replace function public.pit_run(p_pit uuid, p_taps int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); r record; p record; v_max int; cfg jsonb := (select value from public.settings where key = 'pit');
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select * into p from public.pits where id = p_pit;
  if not found then raise exception 'Ce circle pit n''existe plus.'; end if;
  select * into r from public.pit_runners where pit_id = p_pit and user_id = v_user for update;
  if found and now() < p.ends_at and coalesce(p_taps, 0) > 0 then
    v_max := ceil(extract(epoch from now() - r.last_at) * (cfg ->> 'max_tps')::numeric)::int + 4;
    update public.pit_runners set taps = taps + least(p_taps, v_max), last_at = now() where pit_id = p_pit and user_id = v_user;
  end if;
  return public.pit_state(p_pit);
end $$;
revoke execute on function public.pit_run(uuid, int) from public, anon;
grant execute on function public.pit_run(uuid, int) to authenticated;

-- fin du pit : chacun récupère ses points (palier atteint, +1 pour le lanceur) et, aux paliers hauts, une récompense
create or replace function public.pit_claim(p_pit uuid) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); p record; r record; t jsonb := public.pit_tier(p_pit); v_pts int; v_table text; l jsonb;
        cfg jsonb := (select value from public.settings where key = 'pit'); v_loot jsonb := null;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select * into p from public.pits where id = p_pit;
  if not found or now() < p.ends_at then raise exception 'Le pit tourne encore.'; end if;
  select * into r from public.pit_runners where pit_id = p_pit and user_id = v_user for update;
  if not found then raise exception 'Tu n''as pas couru dans ce pit.'; end if;
  if r.claimed then raise exception 'Déjà récupéré.'; end if;
  v_pts := case when r.rewarded and r.taps > 0 then (t ->> 'points')::int + case when p.user_id = v_user and (t ->> 'points')::int > 0 then 1 else 0 end else 0 end;
  update public.pit_runners set claimed = true, points = v_pts where pit_id = p_pit and user_id = v_user;
  if r.rewarded and r.taps > 0 then
    for l in select * from jsonb_array_elements(cfg -> 'loot') loop
      if (t ->> 'size')::int >= (l ->> 'size')::int and (t ->> 'speed_tier')::int >= (l ->> 'speed')::int then v_table := l ->> 'table'; end if;
    end loop;
    if v_table is not null then v_loot := public.objective_reward(v_user, v_table); end if;
  end if;
  return jsonb_build_object('points', v_pts, 'tier', t, 'loot', v_loot);
end $$;
revoke execute on function public.pit_claim(uuid) from public, anon;
grant execute on function public.pit_claim(uuid) to authenticated;

-- pits en cours chez mes potes (à rejoindre), et les miens à récupérer
create or replace function public.pit_feed() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'non connecté'; end if;
  return jsonb_build_object(
    'live', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'name', coalesce(pr.username, 'Un pote'), 'avatar', pr.avatar_path, 'track', p.track, 'ends_at', p.ends_at,
                         'runners', (select count(*) from public.pit_runners r where r.pit_id = p.id), 'in', exists (select 1 from public.pit_runners r where r.pit_id = p.id and r.user_id = v_user)) order by p.ends_at)
                       from public.pits p join public.profiles pr on pr.id = p.user_id
                      where now() < p.ends_at and (p.user_id = v_user or exists (select 1 from public.pit_notified n where n.pit_id = p.id and n.user_id = v_user)
                                                   or exists (select 1 from public.pit_runners r where r.pit_id = p.id and r.user_id = v_user))), '[]'),
    'done', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'name', coalesce(pr.username, 'Un pote'), 'track', p.track) order by p.ends_at desc)
                       from public.pit_runners r join public.pits p on p.id = r.pit_id join public.profiles pr on pr.id = p.user_id
                      where r.user_id = v_user and not r.claimed and now() >= p.ends_at and p.ends_at > now() - interval '3 days'), '[]'),
    'opened_today', exists (select 1 from public.pits where user_id = v_user and created_at >= public.paris_day_start()),
    'duration', (select (value ->> 'duration_s')::int from public.settings where key = 'pit'));
end $$;
revoke execute on function public.pit_feed() from public, anon;
grant execute on function public.pit_feed() to authenticated;

-- points de rang de la fosse : slam (0052) et circle pit
create or replace function public.slam_points(p_user uuid default null) returns int
language sql stable security definer set search_path = public as $$
  with u as (select coalesce(p_user, auth.uid()) as id),
       carried as (select (c.created_at at time zone 'Europe/Paris')::date as d, count(*) as n
                     from public.slam_carriers c join public.slams s on s.id = c.slam_id, u
                    where c.user_id = u.id and s.landed_at is not null group by 1)
  select (coalesce((select sum(least(n, public.setting_int('slam_carry_rewards_per_day', 3))) from carried), 0)
        + 2 * (select count(*) from public.slams s, u where s.user_id = u.id and s.landed_at is not null)
        + coalesce((select sum(r.points) from public.pit_runners r, u where r.user_id = u.id), 0))::int
   where auth.uid() is not null
$$;
