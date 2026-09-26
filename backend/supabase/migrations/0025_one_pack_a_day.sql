-- Metalnini — un seul paquet par jour : 1 standard (5 cartes) OU 1 mini (2 cartes, meilleures chances), chacun coûte 2 points.

-- Récompenses et cadeaux passent à 2 points (un paquet au choix) ; les points impairs restants sont arrondis au paquet supérieur.



CREATE OR REPLACE FUNCTION public.open_pack(p_pack_type text, p_request_id uuid, p_format text DEFAULT 'big'::text)
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

    insert into public.inventory as inv (user_id, musician_id, rarity, copies, placed)
      values (v_user, v_musician, v_rarity, 1, false)
      on conflict (user_id, musician_id, rarity) do update set copies = inv.copies + 1, updated_at = now()
      returning (xmax = 0) into v_new;               -- vrai si la ligne vient d'être créée

    insert into public.pack_opening_cards (opening_id, position, musician_id, rarity, is_new)
      values (v_opening, i, v_musician, v_rarity, v_new);
  end loop;

  return query select c.position, c.musician_id, c.rarity, c.is_new from public.pack_opening_cards c where c.opening_id = v_opening order by c.rarity, c.position;
end $function$;

CREATE OR REPLACE FUNCTION public.accrue_daily(p_user uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_today date := (now() at time zone 'Europe/Paris')::date; v_ppd int := public.setting_int('pack_points_per_day', 2);
  v_cap int := v_ppd * greatest(1, public.setting_int('pack_catchup_days', 7)); b int; d date;
begin
  select daily_balance, daily_day into b, d from public.profiles where id = p_user for update;
  if not found then return 0; end if;
  if d is null then   -- premier passage : ce qu'il reste aujourd'hui, comme avant la réserve
    b := greatest(0, v_ppd - coalesce((select count(*) * 2 from public.pack_openings o
                                        where o.user_id = p_user and not o.bonus and o.created_at >= public.paris_day_start()), 0)::int);
  elsif d < v_today then
    b := least(v_cap, b + (v_today - d) * v_ppd);
  else return b;
  end if;
  update public.profiles set daily_balance = b, daily_day = v_today where id = p_user;
  return b;
end $function$;

CREATE OR REPLACE FUNCTION public.gift_notice_push()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.send_push(new.user_id, 'Cadeau du Grand Architecte',
    case when new.musician_id is not null then 'Une carte t''attend. Viens voir qui c''est.'
         else 'Un paquet t''attend, en plus de tes cartes du jour : standard ou mini, à toi de voir.' end, 'cadeau');
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.daily_pack_push()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_hour int := public.setting_int('daily_push_hour', 18); u uuid; n int := 0;
begin
  if v_hour < 0 or extract(hour from now() at time zone 'Europe/Paris')::int <> v_hour then return 0; end if;
  for u in
    select distinct s.user_id from public.push_subscriptions s
    where not exists (select 1 from public.profiles p where p.id = s.user_id and p.blocked)
      and not exists (select 1 from public.push_log l where l.user_id = s.user_id and l.kind = 'paquet' and l.sent_at >= public.paris_day_start())
  loop
    if public.accrue_daily(u) > 0 and public.send_push(u, 'Tes cartes du jour t''attendent', 'Le merch a rouvert : standard ou mini, à toi de choisir.', 'paquet') then n := n + 1; end if;
  end loop;
  return n;
end $function$;

CREATE OR REPLACE FUNCTION public.claim_install_reward()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  update public.profiles set install_rewarded = true, bonus_points = bonus_points + 2 where id = auth.uid() and not install_rewarded;
  return found;
end $function$;

CREATE OR REPLACE FUNCTION public.claim_push_reward()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  if not exists (select 1 from public.push_subscriptions where user_id = auth.uid()) then return false; end if;
  update public.profiles set push_rewarded = true, bonus_points = bonus_points + 2 where id = auth.uid() and not push_rewarded;
  return found;
end $function$;


-- points impairs (anciens minis à 1 point) : arrondis au paquet supérieur
update public.profiles set bonus_points = bonus_points + 1 where bonus_points % 2 = 1;
update public.profiles set daily_balance = daily_balance + 1 where daily_balance % 2 = 1;
