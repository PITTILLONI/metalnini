-- slam : « échange » à la place de « troc », et le pote par code (0046) est cité
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
    raise exception 'Personne pour te porter : ajoute d''abord un pote (par code ou par échange), tes potes formeront la foule.';
  end if;
  v_end := now() + make_interval(mins => public.setting_int('slam_window_min', 120));
  insert into public.slams (user_id, goal, ends_at) values (v_user, public.setting_int('slam_goal', 5), v_end) returning id into v_id;
  perform public.slam_spread(v_id, v_user, 'Slam en approche',
    coalesce(v_name, 'Un pote') || ' plonge dans la foule. Porte-le avant ' || to_char(v_end at time zone 'Europe/Paris', 'HH24"h"MI') || '.');
  return public.slam_feed();
end $$;
revoke execute on function public.slam_launch() from public, anon;
grant execute on function public.slam_launch() to authenticated;
