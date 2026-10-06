-- Metalnini — slam en avatars : le flux du slam donne les porteurs avec leur photo (people), et la photo du slammeur
-- pour les slams à porter et ceux qu'on porte.

create or replace function public.slam_feed() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_mine jsonb; v_crowd jsonb; v_carried jsonb;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select jsonb_build_object('id', s.id, 'goal', s.goal, 'ends_at', s.ends_at, 'landed', s.landed_at is not null, 'claimed', s.claimed,
           'crashed', s.landed_at is null and now() >= s.ends_at,
           'carriers', coalesce((select jsonb_agg(coalesce(p.username, 'Un pote') order by c.created_at) from public.slam_carriers c join public.profiles p on p.id = c.user_id where c.slam_id = s.id), '[]'),
           'carrier_ids', coalesce((select jsonb_agg(c.user_id) from public.slam_carriers c where c.slam_id = s.id), '[]'),
           'asked_ids', coalesce((select jsonb_agg(a.user_id) from public.slam_asks a where a.slam_id = s.id), '[]'),
           'people', coalesce((select jsonb_agg(jsonb_build_object('id', c.user_id, 'name', coalesce(p.username, 'Un pote'), 'avatar', p.avatar_path) order by c.created_at)
                                 from public.slam_carriers c join public.profiles p on p.id = c.user_id where c.slam_id = s.id), '[]'))
    into v_mine from public.slams s
   where s.user_id = v_user and (s.created_at >= public.paris_day_start() or (s.landed_at is not null and not s.claimed))
   order by s.created_at desc limit 1;
  select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'name', coalesce(p.username, 'Un pote'), 'avatar', p.avatar_path, 'goal', s.goal, 'ends_at', s.ends_at,
           'count', (select count(*) from public.slam_carriers c where c.slam_id = s.id)) order by s.ends_at), '[]')
    into v_crowd from public.slams s join public.profiles p on p.id = s.user_id
   where s.landed_at is null and now() < s.ends_at and s.user_id <> v_user
     and not exists (select 1 from public.slam_carriers c where c.slam_id = s.id and c.user_id = v_user)
     and public.slam_in_crowd(s.id, v_user);
  select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'name', coalesce(p.username, 'Un pote'), 'avatar', p.avatar_path, 'goal', s.goal, 'ends_at', s.ends_at,
           'count', (select count(*) from public.slam_carriers x where x.slam_id = s.id), 'landed', s.landed_at is not null, 'rewarded', c.rewarded) order by c.created_at desc), '[]')
    into v_carried from public.slam_carriers c join public.slams s on s.id = c.slam_id join public.profiles p on p.id = s.user_id
   where c.user_id = v_user and not c.claimed
     and ((s.landed_at is not null and c.rewarded) or (s.landed_at is null and now() < s.ends_at));
  return jsonb_build_object('mine', v_mine, 'crowd', v_crowd, 'carried', v_carried,
           'goal', public.setting_int('slam_goal', 5), 'window', public.setting_int('slam_window_min', 120));
end $$;
