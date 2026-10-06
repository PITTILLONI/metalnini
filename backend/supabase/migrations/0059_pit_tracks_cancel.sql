-- Metalnini — circle pit : jusqu'à 4 extraits enchaînés (un aperçu ne dure que 30 s), l'ouvreur peut annuler son pit (personne
-- ne gagne, il peut en relancer un le jour même), et l'invitation au pit passe outre le budget quotidien de notifications
-- (un pit ne dure que 2 minutes) dans la limite de 3 invitations de pit par joueur et par jour.

alter table public.pits add column if not exists tracks text[];
alter table public.pits add column if not exists cancelled boolean not null default false;
update public.pits set tracks = array[track] where tracks is null;

create or replace function public.pit_spread(p_pit uuid, p_from uuid, p_body text) returns void
language plpgsql volatile security definer set search_path = public as $$
declare f record; p record; v_today int;
begin
  select * into p from public.pits where id = p_pit;
  for f in select distinct x.id from (select friend_id as id from public.follows where user_id = p_from
                                       union select user_id from public.follows where friend_id = p_from) x
            where x.id <> p.user_id and not exists (select 1 from public.pit_runners r where r.pit_id = p_pit and r.user_id = x.id) loop
    insert into public.pit_notified (pit_id, user_id) values (p_pit, f.id) on conflict do nothing;
    if found then
      v_today := (select count(*) from public.pit_notified n join public.pits x on x.id = n.pit_id where n.user_id = f.id and x.created_at >= public.paris_day_start());
      perform public.send_push(f.id, 'Circle pit !', p_body, 'pit', 'https://pittilloni.github.io/metalnini/proto/?pit=' || p_pit, v_today <= 3);
    end if;
  end loop;
end $$;
revoke execute on function public.pit_spread(uuid, uuid, text) from public, anon, authenticated;

-- état : les extraits et l'annulation
create or replace function public.pit_state(p_pit uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := auth.uid(); p record; me record;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select * into p from public.pits where id = p_pit;
  if not found then raise exception 'Ce circle pit n''existe plus.'; end if;
  select * into me from public.pit_runners where pit_id = p_pit and user_id = v_user;
  return jsonb_build_object('id', p.id, 'track', p.track, 'tracks', coalesce(to_jsonb(p.tracks), jsonb_build_array(p.track)), 'cancelled', p.cancelled,
    'ends_at', p.ends_at, 'over', now() >= p.ends_at, 'host', p.user_id = v_user,
    'host_name', coalesce((select username from public.profiles where id = p.user_id), 'Un pote'),
    'runners', coalesce((select jsonb_agg(jsonb_build_object('id', r.user_id, 'name', coalesce(pr.username, 'Un pote'), 'avatar', pr.avatar_path, 'taps', r.taps, 'me', r.user_id = v_user) order by r.joined_at)
                           from public.pit_runners r left join public.profiles pr on pr.id = r.user_id where r.pit_id = p_pit), '[]'),
    'tier', public.pit_tier(p_pit), 'in', me.user_id is not null, 'rewarded', coalesce(me.rewarded, false), 'claimed', coalesce(me.claimed, false));
end $$;

-- lancer un pit sur 1 à 4 extraits ; un pit lancé par jour (un pit annulé ne compte pas)
create or replace function public.pit_open_tracks(p_tracks text[]) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_id uuid; v_name text := (select username from public.profiles where id = auth.uid());
        cfg jsonb := (select value from public.settings where key = 'pit'); v_tracks text[];
begin
  if v_user is null then raise exception 'non connecté'; end if;
  perform 1 from public.profiles where id = v_user for update;
  if exists (select 1 from public.pits where user_id = v_user and not cancelled and created_at >= public.paris_day_start()) then
    raise exception 'Un circle pit lancé par jour : tes jambes ont besoin de repos. Rejoins celui d''un pote.';
  end if;
  if exists (select 1 from public.pits where user_id = v_user and not cancelled and now() < ends_at) then raise exception 'Ton pit tourne déjà.'; end if;
  if not exists (select 1 from public.follows where user_id = v_user or friend_id = v_user) then
    raise exception 'Personne pour courir avec toi : ajoute des potes d''abord.';
  end if;
  select array_agg(t order by o) into v_tracks from unnest(p_tracks) with ordinality u(t, o)
   where exists (select 1 from public.musicians m where m.id = t and m.active);
  if v_tracks is null or array_length(v_tracks, 1) = 0 then raise exception 'Choisis au moins un extrait du jeu.'; end if;
  v_tracks := v_tracks[1:4];
  insert into public.pits (user_id, track, tracks, ends_at) values (v_user, v_tracks[1], v_tracks, now() + make_interval(secs => (cfg ->> 'duration_s')::int)) returning id into v_id;
  insert into public.pit_runners (pit_id, user_id, rewarded) values (v_id, v_user, true);
  perform public.pit_spread(v_id, v_user, coalesce(v_name, 'Un pote') || ' ouvre un circle pit sur ' || (select name from public.musicians where id = v_tracks[1])
    || case when array_length(v_tracks, 1) > 1 then ' et ' || (array_length(v_tracks, 1) - 1) || ' autre' || case when array_length(v_tracks, 1) > 2 then 's' else '' end else '' end || '. 2 minutes, viens courir !');
  return public.pit_state(v_id);
end $$;
revoke execute on function public.pit_open_tracks(text[]) from public, anon;
grant execute on function public.pit_open_tracks(text[]) to authenticated;

-- l'ancien appel (un seul extrait) passe par le nouveau
create or replace function public.pit_open(p_track text) returns jsonb
language sql volatile security definer set search_path = public as $$ select public.pit_open_tracks(array[p_track]) $$;

-- annuler : l'ouvreur seulement, tant que le pit tourne ; personne ne gagne
create or replace function public.pit_cancel(p_pit uuid) returns boolean
language plpgsql volatile security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  update public.pits set cancelled = true, ends_at = least(ends_at, now()) where id = p_pit and user_id = auth.uid() and not cancelled and now() < ends_at;
  if not found then raise exception 'Ce pit ne peut plus être annulé.'; end if;
  update public.pit_runners set claimed = true, points = 0 where pit_id = p_pit;
  return true;
end $$;
revoke execute on function public.pit_cancel(uuid) from public, anon;
grant execute on function public.pit_cancel(uuid) to authenticated;

-- rien à récupérer sur un pit annulé ; le flux ne montre plus les pits annulés
create or replace function public.pit_feed() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'non connecté'; end if;
  return jsonb_build_object(
    'live', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'name', coalesce(pr.username, 'Un pote'), 'avatar', pr.avatar_path, 'track', p.track, 'ends_at', p.ends_at,
                         'runners', (select count(*) from public.pit_runners r where r.pit_id = p.id), 'in', exists (select 1 from public.pit_runners r where r.pit_id = p.id and r.user_id = v_user)) order by p.ends_at)
                       from public.pits p join public.profiles pr on pr.id = p.user_id
                      where not p.cancelled and now() < p.ends_at and (p.user_id = v_user or exists (select 1 from public.pit_notified n where n.pit_id = p.id and n.user_id = v_user)
                                                   or exists (select 1 from public.pit_runners r where r.pit_id = p.id and r.user_id = v_user))), '[]'),
    'done', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'name', coalesce(pr.username, 'Un pote'), 'track', p.track) order by p.ends_at desc)
                       from public.pit_runners r join public.pits p on p.id = r.pit_id join public.profiles pr on pr.id = p.user_id
                      where r.user_id = v_user and not r.claimed and not p.cancelled and now() >= p.ends_at and p.ends_at > now() - interval '3 days'), '[]'),
    'opened_today', exists (select 1 from public.pits where user_id = v_user and not cancelled and created_at >= public.paris_day_start()),
    'duration', (select (value ->> 'duration_s')::int from public.settings where key = 'pit'));
end $$;
