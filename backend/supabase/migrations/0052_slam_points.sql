-- Metalnini — points de rang du slam : porter un slam qui atterrit rapporte 1 point de rang au porteur (3 par jour au plus,
-- le même plafond que les récompenses de porteur), et 2 points au slammeur. Comptés par le serveur, lisibles pour soi et
-- pour le profil d'un pote.

create or replace function public.slam_points(p_user uuid default null) returns int
language sql stable security definer set search_path = public as $$
  with u as (select coalesce(p_user, auth.uid()) as id),
       carried as (select (c.created_at at time zone 'Europe/Paris')::date as d, count(*) as n
                     from public.slam_carriers c join public.slams s on s.id = c.slam_id, u
                    where c.user_id = u.id and s.landed_at is not null group by 1)
  select (coalesce((select sum(least(n, public.setting_int('slam_carry_rewards_per_day', 3))) from carried), 0)
        + 2 * (select count(*) from public.slams s, u where s.user_id = u.id and s.landed_at is not null))::int
   where auth.uid() is not null
$$;
revoke execute on function public.slam_points(uuid) from public, anon;
grant execute on function public.slam_points(uuid) to authenticated;
