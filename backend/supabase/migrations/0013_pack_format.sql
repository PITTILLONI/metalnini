-- Metalnini — format du paquet du jour : un gros paquet (5 cartes, probabilités du paquet) ou deux petits (2 cartes, meilleures chances).
-- Le quota quotidien se compte en points : gros = 2, petit = 1, 2 points par jour.

alter table public.pack_openings add column if not exists format text not null default 'big';
alter table public.pack_openings drop constraint if exists pack_openings_format;
alter table public.pack_openings add constraint pack_openings_format check (format in ('big', 'small'));

insert into public.settings (key, value) values
  ('pack_points_per_day', '2'), ('small_pack_size', '2'),
  ('small_odds', '{"commune":50,"rare":28,"holo":14,"signature":6,"legendaire":2}')
on conflict (key) do nothing;
delete from public.settings where key = 'packs_per_day';

-- tirage d'une rareté pour un petit paquet (poids lus dans small_odds)
create or replace function public.draw_rarity_small() returns public.rarity
language plpgsql volatile security definer set search_path = public as $$
declare v_odds jsonb := (select value from public.settings where key = 'small_odds'); v_total numeric; v_x numeric; r public.rarity;
begin
  select sum((v_odds ->> x::text)::numeric) into v_total from unnest(enum_range(null::public.rarity)) x;
  if v_total is null or v_total <= 0 then raise exception 'probabilités des petits paquets invalides'; end if;
  v_x := random() * v_total;
  foreach r in array enum_range(null::public.rarity) loop
    if v_x < coalesce((v_odds ->> r::text)::numeric, 0) then return r; end if;
    v_x := v_x - coalesce((v_odds ->> r::text)::numeric, 0);
  end loop;
  return 'commune';
end $$;
revoke execute on function public.draw_rarity_small() from public, anon, authenticated;

-- points restants aujourd'hui (gros = 2, petit = 1) ; null = illimité
create or replace function public.packs_left_today() returns int
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then return 0; end if;
  if exists (select 1 from public.profiles where id = v_user and unlimited_packs) then return null; end if;
  return greatest(0, public.setting_int('pack_points_per_day', 2)
    - coalesce((select sum(case when o.format = 'small' then 1 else 2 end) from public.pack_openings o
                 where o.user_id = v_user and o.created_at >= public.paris_day_start()), 0)::int);
end $$;

drop function if exists public.open_pack(text, uuid);
CREATE OR REPLACE FUNCTION public.open_pack(p_pack_type text, p_request_id uuid, p_format text DEFAULT 'big')
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
  v_left int;
  v_cost int := case when p_format = 'small' then 1 else 2 end;
  i int;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  if exists (select 1 from public.profiles where id = v_user and blocked) then raise exception 'compte bloqué'; end if;

  select o.id into v_opening from public.pack_openings o where o.user_id = v_user and o.request_id = p_request_id;
  if v_opening is not null then
    return query select c.position, c.musician_id, c.rarity, c.is_new from public.pack_opening_cards c where c.opening_id = v_opening order by c.position;
    return;
  end if;

  if p_format not in ('big', 'small') then raise exception 'format de paquet inconnu : %', p_format; end if;
  v_left := public.packs_left_today();
  if v_left = 0 then raise exception 'le merch est fermé : reviens demain pour ton paquet du jour'; end if;
  if v_left < v_cost then raise exception 'il ne te reste qu''un petit paquet aujourd''hui'; end if;

  select pt.size, pt.binder_id into v_size, v_binder from public.pack_types pt where pt.id = p_pack_type and pt.active;
  if v_size is null then raise exception 'type de paquet inconnu : %', p_pack_type; end if;
  if p_format = 'small' then v_size := public.setting_int('small_pack_size', 2); end if;

  insert into public.pack_openings (user_id, pack_type_id, request_id, format) values (v_user, p_pack_type, p_request_id, p_format) returning id into v_opening;

  for i in 1..v_size loop
    select m.id into v_musician from public.musicians m
      where m.active and (v_binder is null or exists (select 1 from public.binder_members b where b.binder_id = v_binder and b.musician_id = m.id))
      order by random() limit 1;
    if v_musician is null then raise exception 'aucun musicien disponible pour %', p_pack_type; end if;
    v_rarity := case when p_format = 'small' then public.draw_rarity_small() else public.draw_rarity(p_pack_type) end;

    insert into public.inventory as inv (user_id, musician_id, rarity, copies, placed)
      values (v_user, v_musician, v_rarity, 1, false)
      on conflict (user_id, musician_id, rarity) do update set copies = inv.copies + 1, updated_at = now()
      returning (xmax = 0) into v_new;               -- vrai si la ligne vient d'être créée

    insert into public.pack_opening_cards (opening_id, position, musician_id, rarity, is_new)
      values (v_opening, i, v_musician, v_rarity, v_new);
  end loop;

  return query select c.position, c.musician_id, c.rarity, c.is_new from public.pack_opening_cards c where c.opening_id = v_opening order by c.rarity, c.position;
end $function$;

grant execute on function public.open_pack(text, uuid, text) to authenticated;
