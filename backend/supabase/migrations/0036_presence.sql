-- Metalnini — présence : dernière visite (chaque ouverture de l'app), app installée (lancée depuis l'icône) et appareil,
-- visibles dans la liste des joueurs de l'admin avec l'abonnement aux notifications.

alter table public.profiles add column if not exists last_seen_at timestamptz;
alter table public.profiles add column if not exists installed_at timestamptz;
alter table public.profiles add column if not exists last_platform text check (last_platform is null or last_platform in ('iphone', 'android', 'ordinateur'));

-- le joueur connecté signale une visite (au plus une fois toutes les 5 minutes)
create or replace function public.touch_presence(p_standalone boolean, p_platform text) returns void
language sql volatile security definer set search_path = public as $$
  update public.profiles
     set last_seen_at = now(),
         last_platform = case when p_platform in ('iphone', 'android', 'ordinateur') then p_platform else last_platform end,
         installed_at = coalesce(installed_at, case when p_standalone then now() end)
   where id = auth.uid() and (last_seen_at is null or last_seen_at < now() - interval '5 minutes' or (p_standalone and installed_at is null));
$$;
revoke execute on function public.touch_presence(boolean, text) from public, anon;
grant execute on function public.touch_presence(boolean, text) to authenticated;

drop function if exists public.admin_list_players();
create function public.admin_list_players()
 returns table (id uuid, username text, email text, is_anonymous boolean, email_confirmed boolean, created_at timestamptz, last_sign_in_at timestamptz,
                blocked boolean, cards bigint, variants bigint, openings bigint, bonus_points int, avatar_path text, cry_path text, metal_power text,
                last_seen_at timestamptz, installed_at timestamptz, last_platform text, push boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  return query
    select u.id, p.username, u.email::text, u.is_anonymous, u.email_confirmed_at is not null, u.created_at, u.last_sign_in_at, coalesce(p.blocked, false),
           coalesce((select sum(i.copies) from public.inventory i where i.user_id = u.id), 0)::bigint,
           (select count(*) from public.inventory i where i.user_id = u.id and i.copies > 0)::bigint,
           (select count(*) from public.pack_openings o where o.user_id = u.id)::bigint,
           coalesce(p.bonus_points, 0), p.avatar_path, p.cry_path, p.metal_power,
           p.last_seen_at, p.installed_at, p.last_platform, exists (select 1 from public.push_subscriptions s where s.user_id = u.id)
      from auth.users u left join public.profiles p on p.id = u.id
     order by coalesce(p.last_seen_at, u.last_sign_in_at, u.created_at) desc;
end $$;
revoke execute on function public.admin_list_players() from public, anon;
grant execute on function public.admin_list_players() to authenticated;

-- joueurs qui ont déjà touché la récompense d'installation : l'app est installée (date exacte inconnue, celle du compte à défaut)
update public.profiles set installed_at = created_at where installed_at is null and install_rewarded;
