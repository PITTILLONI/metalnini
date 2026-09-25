-- Metalnini — points bonus : paquet de bienvenue pour les nouveaux comptes (réglable, 0 = désactivé) et cadeaux de l'admin.
-- Les points bonus ne se périment pas et ne servent qu'une fois le quota du jour épuisé.

alter table public.profiles add column if not exists bonus_points int not null default 0 check (bonus_points >= 0);
alter table public.pack_openings add column if not exists bonus boolean not null default false;
insert into public.settings (key, value) values ('welcome_bonus_points', '2') on conflict (key) do nothing;

-- à la création du compte : profil + paquet de bienvenue s'il est activé
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, bonus_points) values (new.id, public.setting_int('welcome_bonus_points', 0))
    on conflict (id) do update set bonus_points = public.profiles.bonus_points + excluded.bonus_points;
  return new;
end $$;

-- points du quota du jour restants (hors bonus)
create or replace function public.daily_points_left() returns int
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then return 0; end if;
  return greatest(0, public.setting_int('pack_points_per_day', 2)
    - coalesce((select sum(case when o.format = 'small' then 1 else 2 end) from public.pack_openings o
                 where o.user_id = v_user and not o.bonus and o.created_at >= public.paris_day_start()), 0)::int);
end $$;
revoke execute on function public.daily_points_left() from public, anon;
grant execute on function public.daily_points_left() to authenticated;

-- points utilisables maintenant : quota du jour + bonus ; null = illimité
create or replace function public.packs_left_today() returns int
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then return 0; end if;
  if exists (select 1 from public.profiles where id = v_user and unlimited_packs) then return null; end if;
  return public.daily_points_left() + coalesce((select bonus_points from public.profiles where id = v_user), 0);
end $$;

-- points bonus du joueur connecté (pour l'afficher)
create or replace function public.my_bonus_points() returns int
language sql stable security definer set search_path = public as $$
  select coalesce((select bonus_points from public.profiles where id = auth.uid()), 0);
$$;
revoke execute on function public.my_bonus_points() from public, anon;
grant execute on function public.my_bonus_points() to authenticated;

-- l'admin offre des points bonus à un joueur (journalisé)
create or replace function public.admin_give_bonus(p_user uuid, p_points int, p_reason text) returns int
language plpgsql security definer set search_path = public as $$
declare v int;
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  if p_reason is null or length(trim(p_reason)) = 0 then raise exception 'motif obligatoire'; end if;
  if p_points is null or p_points = 0 then raise exception 'nombre de points invalide'; end if;
  insert into public.profiles (id, bonus_points) values (p_user, greatest(0, p_points))
    on conflict (id) do update set bonus_points = greatest(0, public.profiles.bonus_points + p_points) returning bonus_points into v;
  insert into public.admin_audit_log (admin_id, action, target_user, payload, reason)
    values (auth.uid(), 'give_bonus', p_user, jsonb_build_object('points', p_points), p_reason);
  return v;
end $$;
revoke execute on function public.admin_give_bonus(uuid, int, text) from public, anon;
grant execute on function public.admin_give_bonus(uuid, int, text) to authenticated;

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
  v_daily int;
  v_bonus boolean := false;
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
  -- le quota du jour d'abord, puis les points bonus (paquet de bienvenue ou cadeau de l'admin)
  v_left := public.packs_left_today();
  if v_left is not null then
    v_daily := public.daily_points_left();
    if v_daily < v_cost then
      if (select bonus_points from public.profiles where id = v_user) >= v_cost then v_bonus := true;
      elsif v_left = 0 then raise exception 'le merch est fermé : reviens demain pour ton paquet du jour';
      else raise exception 'il ne te reste qu''un petit paquet aujourd''hui';
      end if;
    end if;
  end if;

  select pt.size, pt.binder_id into v_size, v_binder from public.pack_types pt where pt.id = p_pack_type and pt.active;
  if v_size is null then raise exception 'type de paquet inconnu : %', p_pack_type; end if;
  if p_format = 'small' then v_size := public.setting_int('small_pack_size', 2); end if;

  insert into public.pack_openings (user_id, pack_type_id, request_id, format, bonus) values (v_user, p_pack_type, p_request_id, p_format, v_bonus) returning id into v_opening;
  if v_bonus then update public.profiles set bonus_points = bonus_points - v_cost where id = v_user; end if;

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

-- les comptes créés ces derniers jours (testeurs) reçoivent aussi le paquet de bienvenue
update public.profiles set bonus_points = bonus_points + 2
 where not unlimited_packs and bonus_points = 0 and id in (select id from auth.users where created_at > now() - interval '3 days');
