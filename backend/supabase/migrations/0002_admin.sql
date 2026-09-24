-- Metalnini — espace admin (phase 0)
-- 1. Les droits admin exigent la double authentification (session de niveau aal2).
-- 2. Fonctions de lecture pour l'admin : joueurs, inventaire d'un joueur, statistiques, journal.
-- 3. Toute modification admin (catalogue, probabilités, réglages, comptes) est journalisée.

-- ---------------------------------------------------------------- 1. admin = rôle + double authentification
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid())
     and coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2';
$$;

-- rôle admin sans exiger la double authentification : sert seulement à l'écran de connexion
-- pour savoir s'il faut proposer l'activation de la double authentification
create or replace function public.is_admin_account() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;
grant execute on function public.is_admin_account() to authenticated;

-- ---------------------------------------------------------------- 2. lectures admin
create or replace function public.admin_list_players()
returns table (id uuid, email text, is_anonymous boolean, created_at timestamptz, last_sign_in_at timestamptz,
               blocked boolean, cards bigint, variants bigint, openings bigint)
language plpgsql stable security definer set search_path = public as $$
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
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  return query select i.musician_id, i.rarity, i.copies, i.placed from public.inventory i
    where i.user_id = p_user and i.copies > 0 order by i.musician_id, i.rarity;
end $$;

-- statistiques : paquets ouverts, répartition réelle des raretés comparée aux probabilités réglées
create or replace function public.admin_stats(p_days int default 30)
returns table (pack_type_id text, rarity public.rarity, drawn bigint, observed_pct numeric, configured_pct numeric, openings bigint)
language plpgsql stable security definer set search_path = public as $$
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

grant execute on function public.admin_list_players() to authenticated;
grant execute on function public.admin_player_inventory(uuid) to authenticated;
grant execute on function public.admin_stats(int) to authenticated;

-- ---------------------------------------------------------------- 3. écritures admin journalisées
create or replace function public.admin_set_odds(p_pack_type text, p_weights jsonb, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
declare r public.rarity;
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  if p_reason is null or length(trim(p_reason)) = 0 then raise exception 'motif obligatoire'; end if;
  foreach r in array enum_range(null::public.rarity) loop
    if (p_weights ->> r::text) is null or (p_weights ->> r::text)::numeric < 0 then raise exception 'poids manquant ou négatif pour %', r; end if;
  end loop;
  insert into public.admin_audit_log (admin_id, action, payload, reason)
    values (auth.uid(), 'set_odds', jsonb_build_object('pack_type', p_pack_type,
            'before', (select jsonb_object_agg(rarity, weight) from public.pack_odds where pack_type_id = p_pack_type), 'after', p_weights), p_reason);
  foreach r in array enum_range(null::public.rarity) loop
    insert into public.pack_odds (pack_type_id, rarity, weight) values (p_pack_type, r, (p_weights ->> r::text)::numeric)
      on conflict (pack_type_id, rarity) do update set weight = excluded.weight;
  end loop;
end $$;

create or replace function public.admin_set_setting(p_key text, p_value jsonb, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  if p_reason is null or length(trim(p_reason)) = 0 then raise exception 'motif obligatoire'; end if;
  insert into public.admin_audit_log (admin_id, action, payload, reason)
    values (auth.uid(), 'set_setting', jsonb_build_object('key', p_key, 'before', (select value from public.settings where key = p_key), 'after', p_value), p_reason);
  insert into public.settings (key, value) values (p_key, p_value) on conflict (key) do update set value = excluded.value;
end $$;

grant execute on function public.admin_set_odds(text, jsonb, text) to authenticated;
grant execute on function public.admin_set_setting(text, jsonb, text) to authenticated;

-- les éditions directes du catalogue par l'admin (permises par la RLS) sont aussi journalisées
create or replace function public.audit_catalog() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return coalesce(new, old); end if;   -- migrations et seed : pas de journal
  insert into public.admin_audit_log (admin_id, action, payload, reason)
    values (auth.uid(), 'catalog_' || lower(tg_op) || '_' || tg_table_name,
            jsonb_build_object('before', to_jsonb(old), 'after', to_jsonb(new)), 'édition du catalogue');
  return coalesce(new, old);
end $$;
revoke execute on function public.audit_catalog() from public, anon, authenticated;

create trigger audit_musicians after insert or update or delete on public.musicians for each row execute function public.audit_catalog();
create trigger audit_cards after insert or update or delete on public.cards for each row execute function public.audit_catalog();
create trigger audit_binders after insert or update or delete on public.binders for each row execute function public.audit_catalog();
create trigger audit_binder_members after insert or update or delete on public.binder_members for each row execute function public.audit_catalog();
create trigger audit_pack_types after insert or update or delete on public.pack_types for each row execute function public.audit_catalog();

-- probabilités et réglages : uniquement via les fonctions journalisées ci-dessus
drop policy if exists catalog_admin on public.pack_odds;
drop policy if exists settings_admin on public.settings;
