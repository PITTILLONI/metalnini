-- Metalnini — pseudo du joueur, choisi au premier lancement (avant l'onboarding complet).

alter table public.profiles add column if not exists username text;
alter table public.profiles add constraint username_format check (username is null or username ~ '^[A-Za-z0-9_.-]{3,20}$');
create unique index if not exists profiles_username_unique on public.profiles (lower(username));

-- choisir ou changer son pseudo ; renvoie le pseudo enregistré
create or replace function public.set_username(p_username text) returns text
language plpgsql security definer set search_path = public as $$
declare v text := trim(p_username);
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  if v !~ '^[A-Za-z0-9_.-]{3,20}$' then raise exception 'pseudo invalide : 3 à 20 caractères, lettres, chiffres, point, tiret ou tiret bas'; end if;
  if exists (select 1 from public.profiles where lower(username) = lower(v) and id <> auth.uid()) then raise exception 'ce pseudo est déjà pris'; end if;
  insert into public.profiles (id, username) values (auth.uid(), v)
    on conflict (id) do update set username = excluded.username;
  return v;
end $$;
grant execute on function public.set_username(text) to authenticated;

-- l'admin voit le pseudo dans la liste des joueurs
drop function if exists public.admin_list_players();
create function public.admin_list_players()
returns table (id uuid, username text, email text, is_anonymous boolean, created_at timestamptz, last_sign_in_at timestamptz,
               blocked boolean, cards bigint, variants bigint, openings bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  return query
    select u.id, p.username, u.email::text, u.is_anonymous, u.created_at, u.last_sign_in_at, coalesce(p.blocked, false),
           coalesce((select sum(i.copies) from public.inventory i where i.user_id = u.id), 0)::bigint,
           (select count(*) from public.inventory i where i.user_id = u.id and i.copies > 0)::bigint,
           (select count(*) from public.pack_openings o where o.user_id = u.id)::bigint
      from auth.users u left join public.profiles p on p.id = u.id
     order by u.created_at desc;
end $$;
grant execute on function public.admin_list_players() to authenticated;
