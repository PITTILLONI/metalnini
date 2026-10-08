-- Metalnini — circle pit repensé : le pit reste ouvert 15 minutes pour rameuter, et chaque coureur fait UNE course de 20 s
-- quand il arrive : un repère tourne sur l'anneau, il faut garder le doigt dessus. Score = précision (part du temps sur le
-- repère, 0 à 100). Chaque course terminée accélère le cercle pour le coureur suivant. Le palier dépend du nombre de coureurs
-- qui ont couru et de la précision moyenne. Un seul morceau par pit. Fin des touchers (pit_run, taps).

update public.settings set value = (value - 'speeds' - 'max_tps') || '{
  "duration_s": 900, "run_s": 20, "base_rps": 0.3, "step_rps": 0.05, "max_rps": 1,
  "aims": [{"min": 0, "label": "Brouillon", "mult": 1}, {"min": 60, "label": "Carré", "mult": 2}, {"min": 85, "label": "Implacable", "mult": 3}],
  "loot": [{"size": 1, "aim": 1, "table": "pit1"}, {"size": 2, "aim": 2, "table": "pit2"}]
}'::jsonb where key = 'pit';

drop function if exists public.pit_run(uuid, int);
alter table public.pit_runners drop column if exists taps, drop column if exists last_at;
alter table public.pit_runners add column if not exists run_started_at timestamptz,   -- course lancée (une à la fois)
                               add column if not exists run_rps numeric,              -- vitesse du cercle pendant sa course (tours/s)
                               add column if not exists score int;                    -- précision, null tant qu'il n'a pas couru

-- vitesse du cercle pour la prochaine course : de plus en plus vite à chaque course terminée
create or replace function public.pit_rps(p_pit uuid) returns numeric
language sql stable security definer set search_path = public as $$
  select least((c.value ->> 'max_rps')::numeric,
               (c.value ->> 'base_rps')::numeric + (c.value ->> 'step_rps')::numeric * (select count(*) from public.pit_runners r where r.pit_id = p_pit and r.score is not null))
    from public.settings c where c.key = 'pit'
$$;
revoke execute on function public.pit_rps(uuid) from public, anon, authenticated;

-- palier : coureurs qui ont couru, et leur précision moyenne
create or replace function public.pit_tier(p_pit uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare cfg jsonb := (select value from public.settings where key = 'pit'); n int; a int; si int := -1; ai int := 0; i int;
begin
  select count(*), coalesce(round(avg(score)), 0) into n, a from public.pit_runners where pit_id = p_pit and score is not null;
  for i in 0 .. jsonb_array_length(cfg -> 'sizes') - 1 loop if n >= (cfg -> 'sizes' -> i ->> 'min')::int then si := i; end if; end loop;
  for i in 0 .. jsonb_array_length(cfg -> 'aims') - 1 loop if a >= (cfg -> 'aims' -> i ->> 'min')::int then ai := i; end if; end loop;
  return jsonb_build_object('runners', n, 'aim', a, 'size', si, 'aim_tier', ai,
    'size_label', case when si >= 0 then cfg -> 'sizes' -> si ->> 'label' end, 'aim_label', cfg -> 'aims' -> ai ->> 'label',
    'points', case when si >= 0 then (cfg -> 'sizes' -> si ->> 'pts')::int * (cfg -> 'aims' -> ai ->> 'mult')::int else 0 end);
end $$;
revoke execute on function public.pit_tier(uuid) from public, anon, authenticated;

-- état : coureurs (score, vitesse de leur course), vitesse de la prochaine course, durée d'une course
create or replace function public.pit_state(p_pit uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := auth.uid(); p record; me record;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select * into p from public.pits where id = p_pit;
  if not found then raise exception 'Ce circle pit n''existe plus.'; end if;
  select * into me from public.pit_runners where pit_id = p_pit and user_id = v_user;
  return jsonb_build_object('id', p.id, 'track', p.track, 'cancelled', p.cancelled,
    'ends_at', p.ends_at, 'over', now() >= p.ends_at, 'host', p.user_id = v_user,
    'host_name', coalesce((select username from public.profiles where id = p.user_id), 'Un pote'),
    'runners', coalesce((select jsonb_agg(jsonb_build_object('id', r.user_id, 'name', coalesce(pr.username, 'Un pote'), 'avatar', pr.avatar_path,
                                                             'score', r.score, 'rps', r.run_rps, 'me', r.user_id = v_user) order by r.joined_at)
                           from public.pit_runners r left join public.profiles pr on pr.id = r.user_id where r.pit_id = p_pit), '[]'),
    'rps', public.pit_rps(p_pit), 'run_s', (select (value ->> 'run_s')::int from public.settings where key = 'pit'),
    'tier', public.pit_tier(p_pit), 'in', me.user_id is not null, 'rewarded', coalesce(me.rewarded, false), 'claimed', coalesce(me.claimed, false));
end $$;

-- lancer un pit : un seul morceau ; un pit lancé par jour (un pit annulé ne compte pas)
create or replace function public.pit_open(p_track text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_id uuid; v_name text := (select username from public.profiles where id = auth.uid());
        cfg jsonb := (select value from public.settings where key = 'pit');
begin
  if v_user is null then raise exception 'non connecté'; end if;
  perform 1 from public.profiles where id = v_user for update;
  if exists (select 1 from public.pits where user_id = v_user and not cancelled and created_at >= public.paris_day_start()) then
    raise exception 'Un circle pit lancé par jour : tes jambes ont besoin de repos. Rejoins celui d''un pote.';
  end if;
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
drop function if exists public.pit_open_tracks(text[]);
alter table public.pits drop column if exists tracks;

-- départ d'une course : coureur du pit, pas encore couru, assez de temps avant la fin ; la vitesse du cercle est fixée ici
-- (une course lancée puis abandonnée, app fermée, se relance une fois son temps écoulé)
create or replace function public.pit_run_start(p_pit uuid) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); p record; r record; v_run int := (select (value ->> 'run_s')::int from public.settings where key = 'pit');
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select * into p from public.pits where id = p_pit;
  if not found or p.cancelled then raise exception 'Ce circle pit n''existe plus.'; end if;
  if now() + make_interval(secs => v_run) > p.ends_at then raise exception 'Le pit retombe : plus le temps de courir.'; end if;
  select * into r from public.pit_runners where pit_id = p_pit and user_id = v_user for update;
  if not found then raise exception 'Rejoins le pit d''abord.'; end if;
  if r.score is not null then raise exception 'Tu as déjà fait ta course dans ce pit.'; end if;
  if r.run_started_at is not null and now() < r.run_started_at + make_interval(secs => v_run + 15) then raise exception 'Ta course est déjà lancée.'; end if;
  update public.pit_runners set run_started_at = now(), run_rps = public.pit_rps(p_pit) where pit_id = p_pit and user_id = v_user;
  return public.pit_state(p_pit);
end $$;
revoke execute on function public.pit_run_start(uuid) from public, anon;
grant execute on function public.pit_run_start(uuid) to authenticated;

-- fin d'une course : précision de 0 à 100, acceptée si la course a vraiment duré (à 2 s près) et n'est pas trop vieille
create or replace function public.pit_run_finish(p_pit uuid, p_score int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); r record; v_run int := (select (value ->> 'run_s')::int from public.settings where key = 'pit');
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select * into r from public.pit_runners where pit_id = p_pit and user_id = v_user for update;
  if not found or r.run_started_at is null then raise exception 'Aucune course en cours.'; end if;
  if r.score is not null then raise exception 'Tu as déjà fait ta course dans ce pit.'; end if;
  if now() < r.run_started_at + make_interval(secs => v_run - 2) then raise exception 'Course trop courte.'; end if;
  if now() > r.run_started_at + make_interval(secs => v_run + 15) then raise exception 'Course expirée : relance-la.'; end if;
  update public.pit_runners set score = greatest(0, least(100, coalesce(p_score, 0))) where pit_id = p_pit and user_id = v_user;
  return public.pit_state(p_pit);
end $$;
revoke execute on function public.pit_run_finish(uuid, int) from public, anon;
grant execute on function public.pit_run_finish(uuid, int) to authenticated;

-- fin du pit : points et récompense pour qui a couru
create or replace function public.pit_claim(p_pit uuid) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); p record; r record; t jsonb := public.pit_tier(p_pit); v_pts int; v_table text; l jsonb;
        cfg jsonb := (select value from public.settings where key = 'pit'); v_loot jsonb := null; v_ran boolean;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select * into p from public.pits where id = p_pit;
  if not found or now() < p.ends_at then raise exception 'Le pit tourne encore.'; end if;
  select * into r from public.pit_runners where pit_id = p_pit and user_id = v_user for update;
  if not found then raise exception 'Tu n''as pas couru dans ce pit.'; end if;
  if r.claimed then raise exception 'Déjà récupéré.'; end if;
  v_ran := r.rewarded and r.score is not null;
  v_pts := case when v_ran then (t ->> 'points')::int + case when p.user_id = v_user and (t ->> 'points')::int > 0 then 1 else 0 end else 0 end;
  update public.pit_runners set claimed = true, points = v_pts where pit_id = p_pit and user_id = v_user;
  if v_ran then
    for l in select * from jsonb_array_elements(cfg -> 'loot') loop
      if (t ->> 'size')::int >= (l ->> 'size')::int and (t ->> 'aim_tier')::int >= (l ->> 'aim')::int then v_table := l ->> 'table'; end if;
    end loop;
    if v_table is not null then v_loot := public.objective_reward(v_user, v_table); end if;
  end if;
  return jsonb_build_object('points', v_pts, 'tier', t, 'loot', v_loot);
end $$;

-- flux : « coureurs » = ceux qui ont fait leur course ; « couru » = la mienne est faite
create or replace function public.pit_feed() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := auth.uid();
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
    'opened_today', exists (select 1 from public.pits where user_id = v_user and not cancelled and created_at >= public.paris_day_start()),
    'duration', (select (value ->> 'duration_s')::int from public.settings where key = 'pit'),
    'run_s', (select (value ->> 'run_s')::int from public.settings where key = 'pit'));
end $$;
