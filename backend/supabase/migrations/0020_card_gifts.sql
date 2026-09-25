-- Metalnini — cartes offertes par l'admin : le joueur les découvre à l'écran de révélation (« Cadeau du Grand Architecte »), puis les range.

alter table public.gift_notices alter column points drop not null;
alter table public.gift_notices drop constraint if exists gift_notices_points_check;
alter table public.gift_notices add column if not exists musician_id text references public.musicians (id) on delete cascade;
alter table public.gift_notices add column if not exists rarity public.rarity;
alter table public.gift_notices add column if not exists copies int check (copies is null or copies > 0);
-- un avis porte soit des points de paquet, soit une carte
alter table public.gift_notices add constraint gift_notices_kind check (
  (points > 0 and musician_id is null and rarity is null and copies is null)
  or (points is null and musician_id is not null and rarity is not null and copies > 0));

-- ajuster l'inventaire d'un joueur (journalisé) ; p_notify : c'est un cadeau, le joueur le découvre et la carte neuve attend d'être rangée
drop function if exists public.admin_adjust_card(uuid, text, public.rarity, int, text);
create or replace function public.admin_adjust_card(p_user uuid, p_musician text, p_rarity public.rarity, p_delta int, p_reason text, p_notify boolean default false)
returns void language plpgsql security definer set search_path = public as $$
declare v_gift boolean := coalesce(p_notify, false) and p_delta > 0;
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  if p_reason is null or length(trim(p_reason)) = 0 then raise exception 'motif obligatoire'; end if;
  insert into public.inventory as inv (user_id, musician_id, rarity, copies, placed) values (p_user, p_musician, p_rarity, greatest(p_delta, 0), not v_gift)
    on conflict (user_id, musician_id, rarity) do update set copies = greatest(inv.copies + p_delta, 0), updated_at = now();
  if v_gift then insert into public.gift_notices (user_id, musician_id, rarity, copies) values (p_user, p_musician, p_rarity, p_delta); end if;
  insert into public.admin_audit_log (admin_id, action, target_user, payload, reason)
    values (auth.uid(), 'adjust_card', p_user, jsonb_build_object('musician', p_musician, 'rarity', p_rarity, 'delta', p_delta, 'gift', v_gift), p_reason);
end $$;
revoke execute on function public.admin_adjust_card(uuid, text, public.rarity, int, text, boolean) from public, anon;
grant execute on function public.admin_adjust_card(uuid, text, public.rarity, int, text, boolean) to authenticated;

-- cadeaux pas encore vus : points de paquet ou cartes
drop function if exists public.my_gift_notices();
create or replace function public.my_gift_notices() returns table (id bigint, points int, musician_id text, rarity public.rarity, copies int, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select g.id, g.points, g.musician_id, g.rarity, g.copies, g.created_at from public.gift_notices g
  where g.user_id = auth.uid() and g.seen_at is null order by g.created_at;
$$;
revoke execute on function public.my_gift_notices() from public, anon;
grant execute on function public.my_gift_notices() to authenticated;
