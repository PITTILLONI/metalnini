-- Metalnini — pogo : un joueur ouvre un pogo à une rareté (Commune, Rare…), ses potes ont 10 minutes pour entrer. Entrer, c'est
-- miser une carte de cette rareté tirée au hasard dans sa collection (même la dernière exemplaire : c'est le jeu). Chacun joue
-- une manche de 15 s : renvoyer d'un coup d'épaule ceux qui foncent sur soi ; trop de coups pris et on tombe. Chaque manche
-- rend le pogo plus violent pour le suivant. Un pote peut relever qui est à terre tant que le pogo dure. À la fin (3 joueurs
-- au moins), ceux restés à terre perdent leur mise, ramassée par le premier tiers (à l'énergie) ; les autres la récupèrent.
-- Missions de pogo (une fois chacune, plus une par semaine). Circle pit et pogo : lancements illimités pour l'instant.

insert into public.settings (key, value) values ('pogo', '{
  "duration_s": 600, "run_s": 15, "min_players": 3, "max_energy": 60, "hits_to_fall": 4,
  "heat_base": 1, "heat_step": 1, "heat_max": 8, "opens_per_day": 0
}'::jsonb) on conflict (key) do nothing;
update public.settings set value = value || '{"pogo_first":[{"w":1,"kind":"new_commune"}], "pogo_card":[{"w":1,"kind":"card"}]}'::jsonb where key = 'objective_loot';

-- circle pit : lancements par jour réglables (0 = illimité), jamais deux pits à soi en même temps
update public.settings set value = value || '{"opens_per_day": 0}'::jsonb where key = 'pit';
create or replace function public.pit_open(p_track text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_id uuid; v_name text := (select username from public.profiles where id = auth.uid());
        cfg jsonb := (select value from public.settings where key = 'pit'); v_max int := coalesce((cfg ->> 'opens_per_day')::int, 0);
begin
  if v_user is null then raise exception 'non connecté'; end if;
  perform 1 from public.profiles where id = v_user for update;
  if v_max > 0 and (select count(*) from public.pits where user_id = v_user and not cancelled and created_at >= public.paris_day_start()) >= v_max then
    raise exception 'Assez de circle pits pour aujourd''hui : tes jambes ont besoin de repos. Rejoins celui d''un pote.';
  end if;
  if exists (select 1 from public.pits where user_id = v_user and not cancelled and now() < ends_at) then raise exception 'Ton pit tourne déjà.'; end if;
  if not exists (select 1 from public.follows where user_id = v_user or friend_id = v_user) then
    raise exception 'Personne pour courir avec toi : ajoute des potes d''abord.';
  end if;
  if not exists (select 1 from public.musicians where id = p_track and active) then raise exception 'Cet extrait n''est pas dans le jeu.'; end if;
  insert into public.pits (user_id, track, ends_at) values (v_user, p_track, now() + make_interval(secs => (cfg ->> 'duration_s')::int)) returning id into v_id;
  insert into public.pit_runners (pit_id, user_id, rewarded) values (v_id, v_user, true);
  perform public.pit_spread(v_id, v_user, coalesce(v_name, 'Un pote') || ' ouvre un circle pit sur ' || (select name from public.musicians where id = p_track)
    || '. ' || round((cfg ->> 'duration_s')::int / 60.0) || ' minutes pour venir faire ta course !');
  return public.pit_state(v_id);
end $$;

-- « opened_today » devient « plus de lancement possible aujourd'hui » (toujours faux tant que c'est illimité)
create or replace function public.pit_feed() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := auth.uid(); cfg jsonb := (select value from public.settings where key = 'pit'); v_max int := coalesce((cfg ->> 'opens_per_day')::int, 0);
begin
  if v_user is null then raise exception 'non connecté'; end if;
  return jsonb_build_object(
    'live', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'name', coalesce(pr.username, 'Un pote'), 'avatar', pr.avatar_path, 'track', p.track, 'ends_at', p.ends_at,
                         'runners', (select count(*) from public.pit_runners r where r.pit_id = p.id and r.score is not null),
                         'in', exists (select 1 from public.pit_runners r where r.pit_id = p.id and r.user_id = v_user),
                         'ran', exists (select 1 from public.pit_runners r where r.pit_id = p.id and r.user_id = v_user and r.score is not null)) order by p.ends_at)
                       from public.pits p join public.profiles pr on pr.id = p.user_id
                      where not p.cancelled and now() < p.ends_at and (p.user_id = v_user or exists (select 1 from public.pit_notified n where n.pit_id = p.id and n.user_id = v_user)
                                                   or exists (select 1 from public.pit_runners r where r.pit_id = p.id and r.user_id = v_user))), '[]'),
    'done', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'name', coalesce(pr.username, 'Un pote'), 'track', p.track) order by p.ends_at desc)
                       from public.pit_runners r join public.pits p on p.id = r.pit_id join public.profiles pr on pr.id = p.user_id
                      where r.user_id = v_user and not r.claimed and not p.cancelled and now() >= p.ends_at and p.ends_at > now() - interval '3 days'), '[]'),
    'opened_today', v_max > 0 and (select count(*) from public.pits where user_id = v_user and not cancelled and created_at >= public.paris_day_start()) >= v_max,
    'duration', (cfg ->> 'duration_s')::int, 'run_s', (cfg ->> 'run_s')::int);
end $$;

create table if not exists public.pogos (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  rarity     public.rarity not null,   -- rareté de la mise
  track      text not null,            -- extrait pendant les manches
  created_at timestamptz not null default now(),
  ends_at    timestamptz not null,
  cancelled  boolean not null default false,
  settled    boolean not null default false   -- ramassage calculé (une seule fois, à la première récupération)
);
create index if not exists pogos_user on public.pogos (user_id, created_at desc);
alter table public.pogos enable row level security;   -- tout passe par les fonctions ci-dessous

create table if not exists public.pogo_players (
  pogo_id        uuid not null references public.pogos (id) on delete cascade,
  user_id        uuid not null references auth.users (id) on delete cascade,
  joined_at      timestamptz not null default now(),
  stake_m        text not null,              -- carte misée (retirée de la collection à l'entrée)
  run_started_at timestamptz,
  run_heat       int,                        -- violence du pogo pendant sa manche
  energy         int,                        -- coups d'épaule réussis, null tant qu'il n'a pas joué
  fell           boolean,
  lifted_by      uuid references auth.users (id) on delete set null,
  result         text check (result in ('kept', 'lost', 'won')),
  won            jsonb not null default '[]',   -- cartes ramassées [{m, r}]
  points         int,
  claimed        boolean not null default false,
  primary key (pogo_id, user_id)
);
create index if not exists pogo_players_user on public.pogo_players (user_id, joined_at desc);
create index if not exists pogo_players_lifter on public.pogo_players (lifted_by);
alter table public.pogo_players enable row level security;

create table if not exists public.pogo_notified (
  pogo_id uuid not null references public.pogos (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  primary key (pogo_id, user_id)
);
alter table public.pogo_notified enable row level security;

create table if not exists public.pogo_mission_claims (
  user_id    uuid not null references auth.users (id) on delete cascade,
  key        text not null,
  reward     jsonb not null,
  created_at timestamptz not null default now(),
  primary key (user_id, key)
);
alter table public.pogo_mission_claims enable row level security;

create or replace function public.are_friends(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.follows where (user_id = a and friend_id = b) or (user_id = b and friend_id = a))
$$;
revoke execute on function public.are_friends(uuid, uuid) from public, anon, authenticated;

-- une carte misable : de cette rareté, d'un musicien du jeu (ni maudite, ni perso), tirée au hasard
create or replace function public.pogo_pick_stake(p_user uuid, p_rarity public.rarity) returns text
language sql volatile security definer set search_path = public as $$
  select i.musician_id from public.inventory i join public.musicians m on m.id = i.musician_id
   where i.user_id = p_user and i.rarity = p_rarity and i.copies > 0 and m.active and not m.cursed and not m.perso
   order by random() limit 1
$$;
revoke execute on function public.pogo_pick_stake(uuid, public.rarity) from public, anon, authenticated;

-- retirer un exemplaire de la collection (la ligne disparaît au dernier)
create or replace function public.take_card(p_user uuid, p_musician text, p_rarity public.rarity) returns void
language plpgsql volatile security definer set search_path = public as $$
declare v_left int;
begin
  update public.inventory set copies = copies - 1, updated_at = now()
   where user_id = p_user and musician_id = p_musician and rarity = p_rarity and copies > 0 returning copies into v_left;
  if v_left is null then raise exception 'carte introuvable dans ta collection'; end if;
  if v_left = 0 then delete from public.inventory where user_id = p_user and musician_id = p_musician and rarity = p_rarity; end if;
end $$;
revoke execute on function public.take_card(uuid, text, public.rarity) from public, anon, authenticated;

-- prévenir les potes d'un joueur (une fois par pogo), hors budget dans la limite de 3 invitations de pogo par jour
create or replace function public.pogo_spread(p_pogo uuid, p_from uuid, p_body text) returns void
language plpgsql volatile security definer set search_path = public as $$
declare f record; p record; v_today int;
begin
  select * into p from public.pogos where id = p_pogo;
  for f in select distinct x.id from (select friend_id as id from public.follows where user_id = p_from
                                       union select user_id from public.follows where friend_id = p_from) x
            where x.id <> p.user_id and not exists (select 1 from public.pogo_players r where r.pogo_id = p_pogo and r.user_id = x.id) loop
    insert into public.pogo_notified (pogo_id, user_id) values (p_pogo, f.id) on conflict do nothing;
    if found then
      v_today := (select count(*) from public.pogo_notified n join public.pogos x on x.id = n.pogo_id where n.user_id = f.id and x.created_at >= public.paris_day_start());
      perform public.send_push(f.id, 'Pogo !', p_body, 'pogo', 'https://pittilloni.github.io/metalnini/proto/?pogo=' || p_pogo, v_today <= 3);
    end if;
  end loop;
end $$;
revoke execute on function public.pogo_spread(uuid, uuid, text) from public, anon, authenticated;

-- violence de la prochaine manche : monte à chaque manche jouée
create or replace function public.pogo_heat(p_pogo uuid) returns int
language sql stable security definer set search_path = public as $$
  select least((c.value ->> 'heat_max')::int,
               (c.value ->> 'heat_base')::int + (c.value ->> 'heat_step')::int * (select count(*) from public.pogo_players r where r.pogo_id = p_pogo and r.energy is not null))
    from public.settings c where c.key = 'pogo'
$$;
revoke execute on function public.pogo_heat(uuid) from public, anon, authenticated;

-- état d'un pogo : danseurs (énergie, à terre, relevé, pote ou non), ma mise et mon résultat
create or replace function public.pogo_state(p_pogo uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := auth.uid(); p record; me record; cfg jsonb := (select value from public.settings where key = 'pogo');
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select * into p from public.pogos where id = p_pogo;
  if not found then raise exception 'Ce pogo n''existe plus.'; end if;
  select * into me from public.pogo_players where pogo_id = p_pogo and user_id = v_user;
  return jsonb_build_object('id', p.id, 'rarity', p.rarity, 'track', p.track, 'cancelled', p.cancelled, 'ends_at', p.ends_at, 'over', now() >= p.ends_at,
    'host', p.user_id = v_user, 'host_name', coalesce((select username from public.profiles where id = p.user_id), 'Un pote'),
    'players', coalesce((select jsonb_agg(jsonb_build_object('id', r.user_id, 'name', coalesce(pr.username, 'Un pote'), 'avatar', pr.avatar_path,
                                 'energy', r.energy, 'fell', r.fell, 'lifted', r.lifted_by is not null,
                                 'lifter', (select username from public.profiles where id = r.lifted_by),
                                 'me', r.user_id = v_user, 'friend', public.are_friends(v_user, r.user_id)) order by r.joined_at)
                           from public.pogo_players r left join public.profiles pr on pr.id = r.user_id where r.pogo_id = p_pogo), '[]'),
    'heat', public.pogo_heat(p_pogo), 'run_s', (cfg ->> 'run_s')::int, 'hits', (cfg ->> 'hits_to_fall')::int, 'min_players', (cfg ->> 'min_players')::int,
    'in', me.user_id is not null, 'stake', me.stake_m, 'result', me.result, 'won', coalesce(me.won, '[]'), 'claimed', coalesce(me.claimed, false));
end $$;
revoke execute on function public.pogo_state(uuid) from public, anon;
grant execute on function public.pogo_state(uuid) to authenticated;

-- ouvrir un pogo : rareté de la mise et extrait choisis ; l'ouvreur entre le premier (sa mise est tirée)
create or replace function public.pogo_open(p_rarity public.rarity, p_track text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_id uuid; v_name text := (select username from public.profiles where id = auth.uid()); v_m text;
        cfg jsonb := (select value from public.settings where key = 'pogo'); v_max int := coalesce((cfg ->> 'opens_per_day')::int, 0);
begin
  if v_user is null then raise exception 'non connecté'; end if;
  perform 1 from public.profiles where id = v_user for update;
  if v_max > 0 and (select count(*) from public.pogos where user_id = v_user and not cancelled and created_at >= public.paris_day_start()) >= v_max then
    raise exception 'Assez de pogos pour aujourd''hui. Rejoins celui d''un pote.';
  end if;
  if exists (select 1 from public.pogos where user_id = v_user and not cancelled and now() < ends_at) then raise exception 'Ton pogo est déjà ouvert.'; end if;
  if not exists (select 1 from public.follows where user_id = v_user or friend_id = v_user) then
    raise exception 'Personne pour pogoter avec toi : ajoute des potes d''abord.';
  end if;
  if not exists (select 1 from public.musicians where id = p_track and active) then raise exception 'Cet extrait n''est pas dans le jeu.'; end if;
  v_m := public.pogo_pick_stake(v_user, p_rarity);
  if v_m is null then raise exception 'Il te faut au moins une carte de cette rareté à miser.'; end if;
  insert into public.pogos (user_id, rarity, track, ends_at) values (v_user, p_rarity, p_track, now() + make_interval(secs => (cfg ->> 'duration_s')::int)) returning id into v_id;
  perform public.take_card(v_user, v_m, p_rarity);
  insert into public.pogo_players (pogo_id, user_id, stake_m) values (v_id, v_user, v_m);
  perform public.pogo_spread(v_id, v_user, coalesce(v_name, 'Un pote') || ' ouvre un pogo, mise ' || initcap(p_rarity::text)
    || '. ' || round((cfg ->> 'duration_s')::int / 60.0) || ' minutes pour venir te faire bousculer !');
  return public.pogo_state(v_id);
end $$;
revoke execute on function public.pogo_open(public.rarity, text) from public, anon;
grant execute on function public.pogo_open(public.rarity, text) to authenticated;

-- entrer dans le pogo : la mise est tirée et retirée de la collection ; potes avec l'ouvreur, et mes potes prévenus
create or replace function public.pogo_join(p_pogo uuid) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); p record; v_m text; v_name text := (select username from public.profiles where id = auth.uid());
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select * into p from public.pogos where id = p_pogo for update;
  if not found or p.cancelled then raise exception 'Ce pogo n''existe plus.'; end if;
  if now() >= p.ends_at then raise exception 'Le pogo est retombé.'; end if;
  if exists (select 1 from public.pogo_players where pogo_id = p_pogo and user_id = v_user) then return public.pogo_state(p_pogo); end if;
  v_m := public.pogo_pick_stake(v_user, p.rarity);
  if v_m is null then raise exception 'Il te faut au moins une carte % à miser.', initcap(p.rarity::text); end if;
  perform public.take_card(v_user, v_m, p.rarity);
  insert into public.pogo_players (pogo_id, user_id, stake_m) values (p_pogo, v_user, v_m);
  perform public.make_friends(v_user, p.user_id);
  perform public.pogo_spread(p_pogo, v_user, coalesce(v_name, 'Un pote') || ' saute dans le pogo de '
    || coalesce((select username from public.profiles where id = p.user_id), 'son pote') || '. Viens avant que ça retombe !');
  return public.pogo_state(p_pogo);
end $$;
revoke execute on function public.pogo_join(uuid) from public, anon;
grant execute on function public.pogo_join(uuid) to authenticated;

-- départ d'une manche (une par joueur ; abandonnée, elle se relance une fois son temps écoulé)
create or replace function public.pogo_run_start(p_pogo uuid) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); p record; r record; v_run int := (select (value ->> 'run_s')::int from public.settings where key = 'pogo');
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select * into p from public.pogos where id = p_pogo;
  if not found or p.cancelled then raise exception 'Ce pogo n''existe plus.'; end if;
  if now() + make_interval(secs => v_run) > p.ends_at then raise exception 'Le pogo retombe : plus le temps de danser.'; end if;
  select * into r from public.pogo_players where pogo_id = p_pogo and user_id = v_user for update;
  if not found then raise exception 'Entre dans le pogo d''abord.'; end if;
  if r.energy is not null then raise exception 'Tu as déjà dansé dans ce pogo.'; end if;
  if r.run_started_at is not null and now() < r.run_started_at + make_interval(secs => v_run + 15) then raise exception 'Ta manche est déjà lancée.'; end if;
  update public.pogo_players set run_started_at = now(), run_heat = public.pogo_heat(p_pogo) where pogo_id = p_pogo and user_id = v_user;
  return public.pogo_state(p_pogo);
end $$;
revoke execute on function public.pogo_run_start(uuid) from public, anon;
grant execute on function public.pogo_run_start(uuid) to authenticated;

-- fin d'une manche : énergie (plafonnée) et chute ; une chute prévient les potes présents dans le pogo
create or replace function public.pogo_run_finish(p_pogo uuid, p_energy int, p_fell boolean) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); r record; f record; cfg jsonb := (select value from public.settings where key = 'pogo'); v_run int := (cfg ->> 'run_s')::int;
        v_name text := (select username from public.profiles where id = auth.uid());
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select * into r from public.pogo_players where pogo_id = p_pogo and user_id = v_user for update;
  if not found or r.run_started_at is null then raise exception 'Aucune manche en cours.'; end if;
  if r.energy is not null then raise exception 'Tu as déjà dansé dans ce pogo.'; end if;
  if not coalesce(p_fell, false) and now() < r.run_started_at + make_interval(secs => v_run - 2) then raise exception 'Manche trop courte.'; end if;
  if now() > r.run_started_at + make_interval(secs => v_run + 15) then raise exception 'Manche expirée : relance-la.'; end if;
  update public.pogo_players set energy = greatest(0, least((cfg ->> 'max_energy')::int, coalesce(p_energy, 0))), fell = coalesce(p_fell, false)
   where pogo_id = p_pogo and user_id = v_user;
  if coalesce(p_fell, false) then
    for f in select r2.user_id from public.pogo_players r2 where r2.pogo_id = p_pogo and r2.user_id <> v_user and public.are_friends(v_user, r2.user_id) loop
      perform public.send_push(f.user_id, 'À terre !', coalesce(v_name, 'Ton pote') || ' est tombé dans le pogo. Relève-le avant la fin, sinon il perd sa carte.', 'pogo',
                               'https://pittilloni.github.io/metalnini/proto/?pogo=' || p_pogo);
    end loop;
  end if;
  return public.pogo_state(p_pogo);
end $$;
revoke execute on function public.pogo_run_finish(uuid, int, boolean) from public, anon;
grant execute on function public.pogo_run_finish(uuid, int, boolean) to authenticated;

-- relever un joueur à terre : un pote, ou un danseur du même pogo, tant que le pogo dure
create or replace function public.pogo_lift(p_pogo uuid, p_user uuid) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); p record; v_name text := (select username from public.profiles where id = auth.uid());
begin
  if v_user is null then raise exception 'non connecté'; end if;
  if v_user = p_user then raise exception 'On ne se relève pas tout seul : appelle tes potes.'; end if;
  select * into p from public.pogos where id = p_pogo;
  if not found or p.cancelled or now() >= p.ends_at then raise exception 'Le pogo est retombé.'; end if;
  if not public.are_friends(v_user, p_user) and not exists (select 1 from public.pogo_players where pogo_id = p_pogo and user_id = v_user) then
    raise exception 'Seuls ses potes ou les danseurs du pogo peuvent le relever.';
  end if;
  update public.pogo_players set lifted_by = v_user where pogo_id = p_pogo and user_id = p_user and fell and lifted_by is null;
  if not found then raise exception 'Déjà relevé.'; end if;
  perform public.send_push(p_user, 'Relevé !', coalesce(v_name, 'Un pote') || ' t''a relevé dans le pogo : ta carte est sauvée.', 'pogo',
                           'https://pittilloni.github.io/metalnini/proto/?pogo=' || p_pogo);
  return public.pogo_state(p_pogo);
end $$;
revoke execute on function public.pogo_lift(uuid, uuid) from public, anon;
grant execute on function public.pogo_lift(uuid, uuid) to authenticated;

-- ramassage (une fois) : à terre sans relève = mise perdue ; premier tiers à l'énergie = ramasse les cartes tombées
create or replace function public.pogo_settle(p_pogo uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
declare p record; n int; w int; v_winners uuid[]; s record; i int := 0; cfg jsonb := (select value from public.settings where key = 'pogo');
begin
  select * into p from public.pogos where id = p_pogo for update;
  if p.settled or now() < p.ends_at then return; end if;
  select count(*) into n from public.pogo_players where pogo_id = p_pogo and energy is not null;
  if p.cancelled or n < (cfg ->> 'min_players')::int then
    update public.pogo_players set result = 'kept', points = 0 where pogo_id = p_pogo;
  else
    update public.pogo_players set result = 'lost' where pogo_id = p_pogo and energy is not null and fell and lifted_by is null;
    update public.pogo_players set result = 'kept' where pogo_id = p_pogo and result is null;
    w := ceil(n / 3.0);
    update public.pogo_players set result = 'won' where pogo_id = p_pogo and user_id in
      (select user_id from public.pogo_players where pogo_id = p_pogo and energy is not null and result <> 'lost' order by energy desc, joined_at limit w);
    select array_agg(user_id order by energy desc, joined_at) into v_winners from public.pogo_players where pogo_id = p_pogo and result = 'won';
    if v_winners is not null then
      for s in select stake_m from public.pogo_players where pogo_id = p_pogo and result = 'lost' order by random() loop
        update public.pogo_players set won = won || jsonb_build_array(jsonb_build_object('m', s.stake_m, 'r', p.rarity))
         where pogo_id = p_pogo and user_id = v_winners[1 + i % array_length(v_winners, 1)];
        i := i + 1;
      end loop;
    end if;
    update public.pogo_players set points = case when energy is null then 0
      else 1 + case when result = 'won' then 1 else 0 end + case when user_id = p.user_id then 1 else 0 end end where pogo_id = p_pogo;
  end if;
  update public.pogos set settled = true where id = p_pogo;
end $$;
revoke execute on function public.pogo_settle(uuid) from public, anon, authenticated;

-- fin du pogo : je récupère ma mise (si je ne suis pas resté à terre) et mes cartes ramassées
create or replace function public.pogo_claim(p_pogo uuid) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); p record; r record; c jsonb;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select * into p from public.pogos where id = p_pogo;
  if not found or now() < p.ends_at then raise exception 'Le pogo bat encore son plein.'; end if;
  perform public.pogo_settle(p_pogo);
  select * into r from public.pogo_players where pogo_id = p_pogo and user_id = v_user for update;
  if not found then raise exception 'Tu n''étais pas dans ce pogo.'; end if;
  if r.claimed then raise exception 'Déjà récupéré.'; end if;
  if r.result in ('kept', 'won') then perform public.give_card(v_user, r.stake_m, p.rarity); end if;
  for c in select * from jsonb_array_elements(r.won) loop perform public.give_card(v_user, c ->> 'm', (c ->> 'r')::public.rarity); end loop;
  update public.pogo_players set claimed = true where pogo_id = p_pogo and user_id = v_user;
  return jsonb_build_object('result', r.result, 'stake', jsonb_build_object('m', r.stake_m, 'r', p.rarity), 'won', r.won, 'points', r.points,
                            'energy', r.energy, 'fell', r.fell, 'lifter', (select username from public.profiles where id = r.lifted_by));
end $$;
revoke execute on function public.pogo_claim(uuid) from public, anon;
grant execute on function public.pogo_claim(uuid) to authenticated;

-- annuler : l'ouvreur, tant que le pogo dure ; chacun retrouve sa mise tout de suite
create or replace function public.pogo_cancel(p_pogo uuid) returns boolean
language plpgsql volatile security definer set search_path = public as $$
declare p record; r record;
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  select * into p from public.pogos where id = p_pogo and user_id = auth.uid() and not cancelled and now() < ends_at for update;
  if not found then raise exception 'Ce pogo ne peut plus être annulé.'; end if;
  update public.pogos set cancelled = true, settled = true, ends_at = now() where id = p_pogo;
  for r in select * from public.pogo_players where pogo_id = p_pogo loop perform public.give_card(r.user_id, r.stake_m, p.rarity); end loop;
  update public.pogo_players set result = 'kept', points = 0, claimed = true where pogo_id = p_pogo;
  return true;
end $$;
revoke execute on function public.pogo_cancel(uuid) from public, anon;
grant execute on function public.pogo_cancel(uuid) to authenticated;

-- missions de pogo : progression d'un joueur
create or replace function public.pogo_progress(p_user uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'runs',   (select count(*) from public.pogo_players where user_id = p_user and energy is not null),
    'stands', (select count(*) from public.pogo_players where user_id = p_user and energy is not null and not fell),
    'lifts',  (select count(*) from public.pogo_players where lifted_by = p_user),
    'tops',   (select count(*) from public.pogo_players where user_id = p_user and result = 'won'),
    'open6',  (select count(*) from public.pogos p where p.user_id = p_user and not p.cancelled
                 and (select count(*) from public.pogo_players r where r.pogo_id = p.id and r.energy is not null) >= 6),
    'week',   (select count(*) from public.pogo_players where user_id = p_user and energy is not null
                 and run_started_at >= date_trunc('week', now() at time zone 'Europe/Paris') at time zone 'Europe/Paris'))
$$;
revoke execute on function public.pogo_progress(uuid) from public, anon, authenticated;

-- liste des missions : clé, titre, consigne, récompense, progression, déjà récupérée
create or replace function public.pogo_missions() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := auth.uid(); g jsonb; v_week text := 'week:' || to_char(now() at time zone 'Europe/Paris', 'IYYY-IW');
begin
  if v_user is null then raise exception 'non connecté'; end if;
  g := public.pogo_progress(v_user);
  return (select jsonb_agg(jsonb_build_object('key', m.key, 'title', m.title, 'hint', m.hint, 'reward', m.reward, 'goal', m.goal,
                                              'n', least(m.goal, (g ->> m.stat)::int), 'weekly', m.key = v_week,
                                              'claimed', exists (select 1 from public.pogo_mission_claims c where c.user_id = v_user and c.key = m.key)) order by m.o)
            from (values (1, v_week,   'Pogo de la semaine',     'Danse 3 pogos cette semaine',           '1 paquet',                       3, 'week'),
                         (2, 'first',  'Premier pogo',           'Danse ta première manche de pogo',      'Une Commune pas encore trouvée', 1, 'runs'),
                         (3, 'stand',  'Debout jusqu''au bout',  'Finis une manche sans tomber',          '1 paquet',                       1, 'stands'),
                         (4, 'lift5',  'On relève les copains',  'Relève 5 potes à terre',                'Une carte Rare ou mieux',        5, 'lifts'),
                         (5, 'top3',   'Ramasseur de fosse',     'Finis 3 fois dans le premier tiers',    '1 paquet et 1 ticket',           3, 'tops'),
                         (6, 'open6',  'Ouvre la fosse',         'Ouvre un pogo où 6 joueurs dansent',    'Une carte Holo',                 1, 'open6'),
                         (7, 'king',   'Roi du pogo',            'Danse 25 pogos',                        '3 paquets',                      25, 'runs')) m(o, key, title, hint, reward, goal, stat));
end $$;
revoke execute on function public.pogo_missions() from public, anon;
grant execute on function public.pogo_missions() to authenticated;

-- récupérer une mission accomplie (une fois ; la mission de la semaine, une fois par semaine)
create or replace function public.pogo_mission_claim(p_key text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); m jsonb; v_reward jsonb; v_m text;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  perform 1 from public.profiles where id = v_user for update;
  select x into m from jsonb_array_elements(public.pogo_missions()) x where x ->> 'key' = p_key;
  if m is null then raise exception 'Mission inconnue.'; end if;
  if (m ->> 'claimed')::boolean then raise exception 'Déjà récupérée.'; end if;
  if (m ->> 'n')::int < (m ->> 'goal')::int then raise exception 'Mission pas encore accomplie.'; end if;
  if p_key = 'first' then v_reward := public.objective_reward(v_user, 'pogo_first');
  elsif p_key = 'lift5' then v_reward := public.objective_reward(v_user, 'pogo_card');
  elsif p_key = 'open6' then
    select id into v_m from public.musicians where active and not cursed and not perso order by random() limit 1;
    v_reward := public.give_card(v_user, v_m, 'holo');
  else
    if p_key = 'top3' then update public.profiles set priority_tickets = priority_tickets + 1 where id = v_user; end if;
    update public.profiles set bonus_points = bonus_points + case when p_key = 'king' then 6 else 2 end where id = v_user;
    v_reward := jsonb_build_object('kind', 'points', 'points', case when p_key = 'king' then 6 else 2 end);
  end if;
  insert into public.pogo_mission_claims (user_id, key, reward) values (v_user, p_key, v_reward);
  return v_reward;
end $$;
revoke execute on function public.pogo_mission_claim(text) from public, anon;
grant execute on function public.pogo_mission_claim(text) to authenticated;

-- flux : pogos ouverts chez mes potes, les miens à récupérer (sans limite de temps : la mise y attend), potes à relever
create or replace function public.pogo_feed() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := auth.uid(); cfg jsonb := (select value from public.settings where key = 'pogo'); v_max int := coalesce((cfg ->> 'opens_per_day')::int, 0);
begin
  if v_user is null then raise exception 'non connecté'; end if;
  return jsonb_build_object(
    'live', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'name', coalesce(pr.username, 'Un pote'), 'avatar', pr.avatar_path, 'rarity', p.rarity, 'ends_at', p.ends_at,
                         'players', (select count(*) from public.pogo_players r where r.pogo_id = p.id),
                         'in', exists (select 1 from public.pogo_players r where r.pogo_id = p.id and r.user_id = v_user),
                         'ran', exists (select 1 from public.pogo_players r where r.pogo_id = p.id and r.user_id = v_user and r.energy is not null)) order by p.ends_at)
                       from public.pogos p join public.profiles pr on pr.id = p.user_id
                      where not p.cancelled and now() < p.ends_at and (p.user_id = v_user or exists (select 1 from public.pogo_notified n where n.pogo_id = p.id and n.user_id = v_user)
                                                   or exists (select 1 from public.pogo_players r where r.pogo_id = p.id and r.user_id = v_user))), '[]'),
    'done', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'name', coalesce(pr.username, 'Un pote'), 'rarity', p.rarity) order by p.ends_at desc)
                       from public.pogo_players r join public.pogos p on p.id = r.pogo_id join public.profiles pr on pr.id = p.user_id
                      where r.user_id = v_user and not r.claimed and now() >= p.ends_at), '[]'),
    'down', coalesce((select jsonb_agg(jsonb_build_object('pogo', p.id, 'id', r.user_id, 'name', coalesce(pr.username, 'Un pote'), 'avatar', pr.avatar_path, 'ends_at', p.ends_at))
                       from public.pogo_players r join public.pogos p on p.id = r.pogo_id left join public.profiles pr on pr.id = r.user_id
                      where not p.cancelled and now() < p.ends_at and r.fell and r.lifted_by is null and r.user_id <> v_user
                        and (public.are_friends(v_user, r.user_id) or exists (select 1 from public.pogo_players x where x.pogo_id = p.id and x.user_id = v_user))), '[]'),
    'limit_reached', v_max > 0 and (select count(*) from public.pogos where user_id = v_user and not cancelled and created_at >= public.paris_day_start()) >= v_max,
    'missions', public.pogo_missions(),
    'duration', (cfg ->> 'duration_s')::int, 'run_s', (cfg ->> 'run_s')::int);
end $$;
revoke execute on function public.pogo_feed() from public, anon;
grant execute on function public.pogo_feed() to authenticated;

-- points de rang de la fosse : slam, circle pit, et pogo (une fois récupéré)
create or replace function public.slam_points(p_user uuid default null) returns int
language sql stable security definer set search_path = public as $$
  with u as (select coalesce(p_user, auth.uid()) as id),
       carried as (select (c.created_at at time zone 'Europe/Paris')::date as d, count(*) as n
                     from public.slam_carriers c join public.slams s on s.id = c.slam_id, u
                    where c.user_id = u.id and s.landed_at is not null group by 1)
  select (coalesce((select sum(least(n, public.setting_int('slam_carry_rewards_per_day', 3))) from carried), 0)
        + 2 * (select count(*) from public.slams s, u where s.user_id = u.id and s.landed_at is not null)
        + coalesce((select sum(r.points) from public.pit_runners r, u where r.user_id = u.id), 0)
        + coalesce((select sum(r.points) from public.pogo_players r, u where r.user_id = u.id and r.claimed), 0))::int
   where auth.uid() is not null
$$;
