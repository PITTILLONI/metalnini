-- Metalnini — carte secrète Céline Dion (easter egg) : demander « Céline Dion » comme artiste (une fois par joueur)
-- ouvre une fenêtre de 7 jours pendant laquelle chaque carte tirée a une chance infime (réglage celine_odds, 1 sur 1 000)
-- d'être Céline, une seule fois. Hors classeurs et hors tirage normal (musicien inactif) : aucun effet sur la complétion.

insert into public.musicians (id, name, band, arcana_title, arcana_number, instruments, subgenre, active)
values ('celine', 'Céline Dion', 'Céline Dion', 'My Heart Will Go On', '0', array['chant']::text[], 'Variété', false)
on conflict (id) do update set active = false;
insert into public.cards (musician_id, rarity, image_path) values ('celine', 'legendaire', 'cards/celine-legendaire.jpg') on conflict do nothing;
alter table public.profiles add column if not exists celine_until timestamptz;
alter table public.profiles add column if not exists celine_unlocked boolean not null default false;
insert into public.settings (key, value) values ('celine_odds', '0.001'::jsonb) on conflict (key) do nothing;

-- demande d'artiste : la demande secrète ouvre la fenêtre (renvoie vrai la première fois)
drop function if exists public.request_artist(text, text, boolean);
create or replace function public.request_artist(p_artist text, p_note text, p_priority boolean default false) returns boolean
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_artist text := trim(coalesce(p_artist, '')); v_note text := nullif(trim(coalesce(p_note, '')), '');
begin
  if v_user is null then raise exception 'non connecté'; end if;
  if length(v_artist) < 2 or length(v_artist) > 80 then raise exception 'nom d''artiste : 2 à 80 caractères'; end if;
  if v_note is not null and length(v_note) > 200 then raise exception 'message : 200 caractères au plus'; end if;
  if (select count(*) from public.artist_requests where user_id = v_user and created_at >= public.paris_day_start()) >= 5 then
    raise exception 'cinq demandes par jour, pas plus : reviens demain';
  end if;
  if p_priority then
    update public.profiles set priority_tickets = priority_tickets - 1 where id = v_user and priority_tickets > 0;
    if not found then raise exception 'plus de ticket prioritaire'; end if;
  end if;
  insert into public.artist_requests (user_id, artist, note, priority) values (v_user, v_artist, v_note, coalesce(p_priority, false));
  if regexp_replace(translate(lower(v_artist), 'éèêëç', 'eeeec'), '[^a-z]', '', 'g') = 'celinedion' then
    update public.profiles set celine_until = now() + interval '7 days', celine_unlocked = true where id = v_user and not celine_unlocked;
    return found;
  end if;
  return false;
end $$;
revoke execute on function public.request_artist(text, text, boolean) from public, anon;
grant execute on function public.request_artist(text, text, boolean) to authenticated;

-- ouverture d'un paquet : + la chance de la carte secrète
create or replace function public.open_pack(p_pack_type text, p_request_id uuid, p_format text DEFAULT 'big'::text)
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
  v_daily int;
  v_bonus boolean := false;
  v_cost int := 2;   -- standard ou mini : toute la dotation du jour
  i int;
  v_celine boolean := exists (select 1 from public.profiles where id = auth.uid() and celine_until > now())
                      and not exists (select 1 from public.inventory where user_id = auth.uid() and musician_id = 'celine');
  v_celine_odds numeric := coalesce((select value::numeric from public.settings where key = 'celine_odds'), 0.001);
begin
  if v_user is null then raise exception 'non connecté'; end if;
  if exists (select 1 from public.profiles where id = v_user and blocked) then raise exception 'compte bloqué'; end if;

  select o.id into v_opening from public.pack_openings o where o.user_id = v_user and o.request_id = p_request_id;
  if v_opening is not null then
    return query select c.position, c.musician_id, c.rarity, c.is_new from public.pack_opening_cards c where c.opening_id = v_opening order by c.position;
    return;
  end if;

  if p_format not in ('big', 'small') then raise exception 'format de paquet inconnu : %', p_format; end if;
  -- le quota du jour d'abord, puis les points bonus (paquet de bienvenue ou cadeau de l'admin)
  v_left := public.packs_left_today();
  if v_left is not null then
    v_daily := public.daily_points_left();
    if v_daily < v_cost then
      if (select bonus_points from public.profiles where id = v_user) >= v_cost then v_bonus := true;
      elsif v_left = 0 then raise exception 'le merch est fermé : reviens demain pour ton paquet du jour';
      else raise exception 'il ne te reste qu''un mini aujourd''hui';
      end if;
    end if;
  end if;

  select pt.size, pt.binder_id into v_size, v_binder from public.pack_types pt where pt.id = p_pack_type and pt.active;
  if v_size is null then raise exception 'type de paquet inconnu : %', p_pack_type; end if;
  if p_format = 'small' then v_size := public.setting_int('small_pack_size', 2); end if;

  insert into public.pack_openings (user_id, pack_type_id, request_id, format, bonus) values (v_user, p_pack_type, p_request_id, p_format, v_bonus) returning id into v_opening;
  if v_bonus then update public.profiles set bonus_points = bonus_points - v_cost where id = v_user; end if;
  -- sinon on puise dans la réserve du jour (hors comptes illimités)
  if not v_bonus and v_left is not null then update public.profiles set daily_balance = greatest(0, daily_balance - v_cost) where id = v_user; end if;

  for i in 1..v_size loop
    select m.id into v_musician from public.musicians m
      where m.active and (v_binder is null or exists (select 1 from public.binder_members b where b.binder_id = v_binder and b.musician_id = m.id))
      order by random() limit 1;
    if v_musician is null then raise exception 'aucun musicien disponible pour %', p_pack_type; end if;
    v_rarity := case when p_format = 'small' then public.draw_rarity_small() else public.draw_rarity(p_pack_type) end;
    -- carte secrète : remplace la carte tirée, une seule fois
    if v_celine and random() < v_celine_odds then v_musician := 'celine'; v_rarity := 'legendaire'; v_celine := false; end if;

    insert into public.inventory as inv (user_id, musician_id, rarity, copies, placed)
      values (v_user, v_musician, v_rarity, 1, false)
      on conflict (user_id, musician_id, rarity) do update set copies = inv.copies + 1, updated_at = now()
      returning (xmax = 0) into v_new;               -- vrai si la ligne vient d'être créée

    insert into public.pack_opening_cards (opening_id, position, musician_id, rarity, is_new)
      values (v_opening, i, v_musician, v_rarity, v_new);
  end loop;

  return query select c.position, c.musician_id, c.rarity, c.is_new from public.pack_opening_cards c where c.opening_id = v_opening order by c.rarity, c.position;
end $function$;

revoke execute on function public.open_pack(text, uuid, text) from public, anon;
grant execute on function public.open_pack(text, uuid, text) to authenticated;
