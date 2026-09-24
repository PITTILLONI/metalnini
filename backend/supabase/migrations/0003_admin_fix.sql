-- Correctif : lève l'ambiguïté entre colonnes et paramètres de sortie dans les fonctions admin de lecture.

create or replace function public.admin_list_players()
returns table (id uuid, email text, is_anonymous boolean, created_at timestamptz, last_sign_in_at timestamptz,
               blocked boolean, cards bigint, variants bigint, openings bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  return query
    select u.id, u.email::text, u.is_anonymous, u.created_at, u.last_sign_in_at, coalesce(p.blocked, false),
           coalesce((select sum(i.copies) from public.inventory i where i.user_id = u.id), 0)::bigint,
           (select count(*) from public.inventory i where i.user_id = u.id and i.copies > 0)::bigint,
           (select count(*) from public.pack_openings o where o.user_id = u.id)::bigint
      from auth.users u left join public.profiles p on p.id = u.id
     order by u.created_at desc;
end $$;

create or replace function public.admin_player_inventory(p_user uuid)
returns table (musician_id text, rarity public.rarity, copies int, placed boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  return query select i.musician_id, i.rarity, i.copies, i.placed from public.inventory i
    where i.user_id = p_user and i.copies > 0 order by i.musician_id, i.rarity;
end $$;

create or replace function public.admin_stats(p_days int default 30)
returns table (pack_type_id text, rarity public.rarity, drawn bigint, observed_pct numeric, configured_pct numeric, openings bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  return query
    with o as (select * from public.pack_openings where created_at > now() - make_interval(days => p_days)),
         c as (select o.pack_type_id, oc.rarity from o join public.pack_opening_cards oc on oc.opening_id = o.id),
         tot as (select c.pack_type_id, count(*) n from c group by 1),
         od as (select pack_type_id, rarity, weight, sum(weight) over (partition by pack_type_id) s from public.pack_odds)
    select od.pack_type_id, od.rarity,
           coalesce((select count(*) from c where c.pack_type_id = od.pack_type_id and c.rarity = od.rarity), 0)::bigint,
           round(100.0 * coalesce((select count(*) from c where c.pack_type_id = od.pack_type_id and c.rarity = od.rarity), 0)
                 / nullif((select n from tot where tot.pack_type_id = od.pack_type_id), 0), 2),
           round(100.0 * od.weight / nullif(od.s, 0), 2),
           (select count(*) from o where o.pack_type_id = od.pack_type_id)::bigint
      from od order by od.pack_type_id, od.rarity;
end $$;
