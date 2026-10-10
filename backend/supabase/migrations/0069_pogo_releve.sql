-- Metalnini — pogo rééquilibré (2026-10-10) : relever devient un vrai geste de fosse. Seul un danseur de ce pogo resté debout
-- (ou relevé) peut relever, une seule fois par pogo ; un danseur relevé garde sa carte mais ne ramasse plus. Avant : 9 chutes
-- sur 10 relevées, souvent de l'extérieur, aucune carte n'avait changé de main.

create or replace function public.pogo_can_lift(p_pogo uuid, p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.pogo_players where pogo_id = p_pogo and user_id = p_user and energy is not null and (not fell or lifted_by is not null))
     and not exists (select 1 from public.pogo_players where pogo_id = p_pogo and lifted_by = p_user)
$$;
revoke execute on function public.pogo_can_lift(uuid, uuid) from public, anon, authenticated;

-- état : en plus, can_lift (je peux encore relever quelqu'un dans ce pogo)
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
    'in', me.user_id is not null, 'can_lift', public.pogo_can_lift(p_pogo, v_user), 'stake', me.stake_m, 'result', me.result, 'won', coalesce(me.won, '[]'), 'claimed', coalesce(me.claimed, false));
end $$;

-- relever : seulement un danseur de ce pogo resté debout (ou relevé), une seule relève par danseur et par pogo
create or replace function public.pogo_lift(p_pogo uuid, p_user uuid) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); p record; v_name text := (select username from public.profiles where id = auth.uid());
begin
  if v_user is null then raise exception 'non connecté'; end if;
  if v_user = p_user then raise exception 'On ne se relève pas tout seul : appelle tes potes.'; end if;
  select * into p from public.pogos where id = p_pogo;
  if not found or p.cancelled or now() >= p.ends_at then raise exception 'Le pogo est retombé.'; end if;
  if not exists (select 1 from public.pogo_players where pogo_id = p_pogo and user_id = v_user and energy is not null and (not fell or lifted_by is not null)) then
    raise exception 'Seuls les danseurs restés debout dans ce pogo peuvent relever.';
  end if;
  if exists (select 1 from public.pogo_players where pogo_id = p_pogo and lifted_by = v_user) then
    raise exception 'Tu as déjà relevé quelqu''un dans ce pogo : une relève par danseur.';
  end if;
  update public.pogo_players set lifted_by = v_user where pogo_id = p_pogo and user_id = p_user and fell and lifted_by is null;
  if not found then raise exception 'Déjà relevé.'; end if;
  perform public.send_push(p_user, 'Relevé !', coalesce(v_name, 'Un pote') || ' t''a relevé dans le pogo : ta carte est sauvée.', 'pogo',
                           'https://pittilloni.github.io/metalnini/proto/?pogo=' || p_pogo);
  return public.pogo_state(p_pogo);
end $$;

-- ramassage : un danseur relevé garde sa carte mais ne fait plus partie du premier tiers qui ramasse
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
      (select user_id from public.pogo_players where pogo_id = p_pogo and energy is not null and result <> 'lost' and lifted_by is null order by energy desc, joined_at limit w);
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

-- flux : les danseurs à terre n'apparaissent qu'à ceux qui peuvent encore les relever
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
                        and public.pogo_can_lift(p.id, v_user)), '[]'),
    'limit_reached', v_max > 0 and (select count(*) from public.pogos where user_id = v_user and not cancelled and created_at >= public.paris_day_start()) >= v_max,
    'missions', public.pogo_missions(),
    'duration', (cfg ->> 'duration_s')::int, 'run_s', (cfg ->> 'run_s')::int);
end $$;
