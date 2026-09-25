-- Metalnini — l'admin voit la photo, le cri et la capacité de metaleux de chaque joueur.
drop function if exists public.admin_list_players();
create function public.admin_list_players()
returns table (id uuid, username text, email text, is_anonymous boolean, email_confirmed boolean, created_at timestamptz, last_sign_in_at timestamptz,
               blocked boolean, cards bigint, variants bigint, openings bigint, bonus_points int, avatar_path text, cry_path text, metal_power text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  return query
    select u.id, p.username, u.email::text, u.is_anonymous, u.email_confirmed_at is not null, u.created_at, u.last_sign_in_at, coalesce(p.blocked, false),
           coalesce((select sum(i.copies) from public.inventory i where i.user_id = u.id), 0)::bigint,
           (select count(*) from public.inventory i where i.user_id = u.id and i.copies > 0)::bigint,
           (select count(*) from public.pack_openings o where o.user_id = u.id)::bigint,
           coalesce(p.bonus_points, 0), p.avatar_path, p.cry_path, p.metal_power
      from auth.users u left join public.profiles p on p.id = u.id
     order by u.created_at desc;
end $$;
grant execute on function public.admin_list_players() to authenticated;
