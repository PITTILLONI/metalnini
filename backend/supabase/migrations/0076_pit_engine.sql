-- Metalnini — circle pit, nouveau moteur (PixiJS) : chaque course garde sa trace (rejouée en fantôme par les coureurs
-- suivants), le pit a une taille commune qui grossit (tours, relevés, potes attirés), et les réglages du jeu vivent
-- dans settings.pit.game. Les courses de 40 s viennent avec la mise en ligne du nouveau moteur (0077). Score toujours de 0 à 100 : paliers, points et récompenses inchangés.

alter table public.pit_runners add column if not exists trace jsonb;            -- course compressée (fantôme), null avant le nouveau moteur
alter table public.pits add column if not exists circle int not null default 0;  -- taille commune du cercle

update public.settings set value = value || '{"game": {"npc":24,"vmax":1.2,"accel":2.5,"lateral":0.9,"drain":0.12,"regen":0.25,"regenSlow":0.05,"body":0.035,"fallBase":0.15,"fallTired":0.6,"middleRisk":2,"downS":1.5,"upTaps":4,"npcFallPerS":0.02,"npcDownS":4,"liftHoldS":0.4,"liftMaxV":0.4,"pullHoldS":0.5,"pullAngle":0.027777777777777776,"groove":0.6,"pts":{"lap":4,"lift":6,"pull":8,"middleS":1,"rhythm":30},"circle":{"lap":1,"lift":2,"pull":3}}}'::jsonb
 where key = 'pit';

-- état : en plus, taille du cercle, réglages du jeu et trace de chaque course faite
create or replace function public.pit_state(p_pit uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := auth.uid(); p record; me record; cfg jsonb := (select value from public.settings where key = 'pit');
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select * into p from public.pits where id = p_pit;
  if not found then raise exception 'Ce circle pit n''existe plus.'; end if;
  select * into me from public.pit_runners where pit_id = p_pit and user_id = v_user;
  return jsonb_build_object('id', p.id, 'track', p.track, 'cancelled', p.cancelled,
    'ends_at', p.ends_at, 'over', now() >= p.ends_at, 'host', p.user_id = v_user,
    'host_name', coalesce((select username from public.profiles where id = p.user_id), 'Un pote'),
    'runners', coalesce((select jsonb_agg(jsonb_build_object('id', r.user_id, 'name', coalesce(pr.username, 'Un pote'), 'avatar', pr.avatar_path,
                                                             'score', r.score, 'rps', r.run_rps, 'me', r.user_id = v_user,
                                                             'trace', case when r.score is not null then r.trace end) order by r.joined_at)
                           from public.pit_runners r left join public.profiles pr on pr.id = r.user_id where r.pit_id = p_pit), '[]'),
    'rps', public.pit_rps(p_pit), 'run_s', (cfg ->> 'run_s')::int, 'circle', p.circle, 'game', coalesce(cfg -> 'game', '{}'::jsonb),
    'tier', public.pit_tier(p_pit), 'in', me.user_id is not null, 'rewarded', coalesce(me.rewarded, false), 'claimed', coalesce(me.claimed, false));
end $$;

-- fin d'une course : score de 0 à 100, trace (20 000 octets au plus) et part du cercle (0 à 200)
drop function if exists public.pit_run_finish(uuid, int);
create or replace function public.pit_run_finish(p_pit uuid, p_score int, p_trace jsonb default null, p_circle int default 0) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); r record; v_run int := (select (value ->> 'run_s')::int from public.settings where key = 'pit');
begin
  if v_user is null then raise exception 'non connecté'; end if;
  if p_trace is not null and octet_length(p_trace::text) > 20000 then raise exception 'Course trop lourde.'; end if;
  select * into r from public.pit_runners where pit_id = p_pit and user_id = v_user for update;
  if not found or r.run_started_at is null then raise exception 'Aucune course en cours.'; end if;
  if r.score is not null then raise exception 'Tu as déjà fait ta course dans ce pit.'; end if;
  if now() < r.run_started_at + make_interval(secs => v_run - 2) then raise exception 'Course trop courte.'; end if;
  if now() > r.run_started_at + make_interval(secs => v_run + 15) then raise exception 'Course expirée : relance-la.'; end if;
  update public.pit_runners set score = greatest(0, least(100, coalesce(p_score, 0))), trace = p_trace where pit_id = p_pit and user_id = v_user;
  update public.pits set circle = circle + greatest(0, least(200, coalesce(p_circle, 0))) where id = p_pit;
  return public.pit_state(p_pit);
end $$;
revoke execute on function public.pit_run_finish(uuid, int, jsonb, int) from public, anon;
grant execute on function public.pit_run_finish(uuid, int, jsonb, int) to authenticated;
