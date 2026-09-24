-- Metalnini — un paquet par jour (jour calendaire, heure de Paris), sauf comptes marqués « paquets illimités ».

alter table public.profiles add column if not exists unlimited_packs boolean not null default false;
-- le compte du créateur (admin) garde des paquets illimités pour tester
update public.profiles set unlimited_packs = true where id in (select user_id from public.admins);
insert into public.profiles (id, unlimited_packs) select user_id, true from public.admins on conflict (id) do update set unlimited_packs = true;

insert into public.settings (key, value) values ('packs_per_day', '1') on conflict (key) do update set value = '1';

-- début du jour en cours, heure de Paris
create or replace function public.paris_day_start() returns timestamptz
language sql stable set search_path = public as $$
  select date_trunc('day', now() at time zone 'Europe/Paris') at time zone 'Europe/Paris';
$$;

-- paquets restants aujourd'hui pour le joueur connecté ; null = illimité
create or replace function public.packs_left_today() returns int
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then return 0; end if;
  if exists (select 1 from public.profiles where id = v_user and unlimited_packs) then return null; end if;
  return greatest(0, public.setting_int('packs_per_day', 1)
    - (select count(*) from public.pack_openings o where o.user_id = v_user and o.created_at >= public.paris_day_start())::int);
end $$;
revoke execute on function public.packs_left_today() from public, anon;
grant execute on function public.packs_left_today() to authenticated;

CREATE OR REPLACE FUNCTION public.open_pack(p_pack_type text, p_request_id uuid)
 RETURNS TABLE(card_position integer, musician_id text, rarity rarity, is_new boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_column
declare
  v_user uuid := auth.uid();
  v_opening uuid;
  v_size int;
  v_binder text;
  v_musician text;
  v_rarity public.rarity;
  v_new boolean;
  i int;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  if exists (select 1 from public.profiles where id = v_user and blocked) then raise exception 'compte bloqué'; end if;

  select o.id into v_opening from public.pack_openings o where o.user_id = v_user and o.request_id = p_request_id;
  if v_opening is not null then
    return query select c.position, c.musician_id, c.rarity, c.is_new from public.pack_opening_cards c where c.opening_id = v_opening order by c.position;
    return;
  end if;

  if public.packs_left_today() = 0 then
    raise exception 'le merch est fermé : reviens demain pour ton paquet du jour';
  end if;

  select pt.size, pt.binder_id into v_size, v_binder from public.pack_types pt where pt.id = p_pack_type and pt.active;
  if v_size is null then raise exception 'type de paquet inconnu : %', p_pack_type; end if;

  insert into public.pack_openings (user_id, pack_type_id, request_id) values (v_user, p_pack_type, p_request_id) returning id into v_opening;

  for i in 1..v_size loop
    select m.id into v_musician from public.musicians m
      where m.active and (v_binder is null or exists (select 1 from public.binder_members b where b.binder_id = v_binder and b.musician_id = m.id))
      order by random() limit 1;
    if v_musician is null then raise exception 'aucun musicien disponible pour %', p_pack_type; end if;
    v_rarity := public.draw_rarity(p_pack_type);

    insert into public.inventory as inv (user_id, musician_id, rarity, copies, placed)
      values (v_user, v_musician, v_rarity, 1, false)
      on conflict (user_id, musician_id, rarity) do update set copies = inv.copies + 1, updated_at = now()
      returning (xmax = 0) into v_new;               -- vrai si la ligne vient d'être créée

    insert into public.pack_opening_cards (opening_id, position, musician_id, rarity, is_new)
      values (v_opening, i, v_musician, v_rarity, v_new);
  end loop;

  return query select c.position, c.musician_id, c.rarity, c.is_new from public.pack_opening_cards c where c.opening_id = v_opening order by c.rarity, c.position;
end $function$;
