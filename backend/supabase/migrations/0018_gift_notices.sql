-- Metalnini — avis de cadeau : chaque cadeau de l'admin laisse une trace que le joueur voit une fois dans l'app (« Le Grand Architecte t'offre… »).

create table if not exists public.gift_notices (
  id         bigserial primary key,
  user_id    uuid not null references auth.users (id) on delete cascade,
  points     int not null check (points > 0),
  created_at timestamptz not null default now(),
  seen_at    timestamptz
);
create index if not exists gift_notices_unseen on public.gift_notices (user_id) where seen_at is null;
-- aucun accès direct : lecture et acquittement passent par les fonctions ci-dessous
alter table public.gift_notices enable row level security;

-- l'admin offre des points bonus à un joueur (journalisé) ; un don positif crée un avis pour le joueur
create or replace function public.admin_give_bonus(p_user uuid, p_points int, p_reason text) returns int
language plpgsql security definer set search_path = public as $$
declare v int;
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  if p_reason is null or length(trim(p_reason)) = 0 then raise exception 'motif obligatoire'; end if;
  if p_points is null or p_points = 0 then raise exception 'nombre de points invalide'; end if;
  insert into public.profiles (id, bonus_points) values (p_user, greatest(0, p_points))
    on conflict (id) do update set bonus_points = greatest(0, public.profiles.bonus_points + p_points) returning bonus_points into v;
  if p_points > 0 then insert into public.gift_notices (user_id, points) values (p_user, p_points); end if;
  insert into public.admin_audit_log (admin_id, action, target_user, payload, reason)
    values (auth.uid(), 'give_bonus', p_user, jsonb_build_object('points', p_points), p_reason);
  return v;
end $$;
revoke execute on function public.admin_give_bonus(uuid, int, text) from public, anon;
grant execute on function public.admin_give_bonus(uuid, int, text) to authenticated;

-- cadeaux pas encore vus par le joueur connecté
create or replace function public.my_gift_notices() returns table (id bigint, points int, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select g.id, g.points, g.created_at from public.gift_notices g
  where g.user_id = auth.uid() and g.seen_at is null order by g.created_at;
$$;
revoke execute on function public.my_gift_notices() from public, anon;
grant execute on function public.my_gift_notices() to authenticated;

-- le joueur a vu ses cadeaux (seulement les siens)
create or replace function public.mark_gifts_seen(p_ids bigint[]) returns void
language sql volatile security definer set search_path = public as $$
  update public.gift_notices set seen_at = now() where user_id = auth.uid() and id = any(p_ids) and seen_at is null;
$$;
revoke execute on function public.mark_gifts_seen(bigint[]) from public, anon;
grant execute on function public.mark_gifts_seen(bigint[]) to authenticated;
