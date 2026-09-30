-- Metalnini — après l'échange : historique (app et admin), « Mes potes » (suivre quelqu'un avec qui on a échangé),
-- classeur d'un pote pour voir ce qui lui manque, et échange proposé directement à un pote (notification, sans code à partager).

-- ---------------------------------------------------------------- historique
create or replace function public.trade_items_json(p_trade uuid, p_owner uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('m', musician_id, 'r', rarity, 'n', copies) order by musician_id, rarity), '[]')
    from public.trade_items where trade_id = p_trade and owner = p_owner;
$$;
revoke execute on function public.trade_items_json(uuid, uuid) from public, anon, authenticated;

-- mes échanges conclus, les plus récents d'abord
create or replace function public.my_trades(p_limit int default 20)
returns table (id uuid, done_at timestamptz, partner_id uuid, partner text, gave jsonb, got jsonb, bonus jsonb)
language sql stable security definer set search_path = public as $$
  select t.id, t.done_at, p.id, p.username,
         public.trade_items_json(t.id, auth.uid()), public.trade_items_json(t.id, p.id),
         (select jsonb_build_object('m', b.musician_id, 'r', b.rarity) from public.trade_bonuses b where b.trade_id = t.id and b.user_id = auth.uid())
    from public.trades t join public.profiles p on p.id = case when t.host = auth.uid() then t.guest else t.host end
   where t.status = 'done' and auth.uid() in (t.host, t.guest)
   order by t.done_at desc limit least(coalesce(p_limit, 20), 100);
$$;
revoke execute on function public.my_trades(int) from public, anon;
grant execute on function public.my_trades(int) to authenticated;

-- admin : tous les échanges (ou ceux d'un joueur), avec leur statut
create or replace function public.admin_trades(p_user uuid default null, p_limit int default 100)
returns table (id uuid, status text, created_at timestamptz, done_at timestamptz, host_id uuid, host text, guest_id uuid, guest text, host_gave jsonb, guest_gave jsonb)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  return query
    select t.id, t.status, t.created_at, t.done_at, t.host, coalesce(ph.username, uh.email::text), t.guest, coalesce(pg.username, ug.email::text),
           public.trade_items_json(t.id, t.host), case when t.guest is null then '[]'::jsonb else public.trade_items_json(t.id, t.guest) end
      from public.trades t
      join auth.users uh on uh.id = t.host left join public.profiles ph on ph.id = t.host
      left join auth.users ug on ug.id = t.guest left join public.profiles pg on pg.id = t.guest
     where p_user is null or p_user in (t.host, t.guest)
     order by coalesce(t.done_at, t.updated_at) desc limit least(coalesce(p_limit, 100), 500);
end $$;
revoke execute on function public.admin_trades(uuid, int) from public, anon;
grant execute on function public.admin_trades(uuid, int) to authenticated;

-- ---------------------------------------------------------------- potes
create table if not exists public.follows (
  user_id    uuid not null references auth.users (id) on delete cascade,
  friend_id  uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id),
  check (user_id <> friend_id)
);
alter table public.follows enable row level security;   -- tout passe par les fonctions ci-dessous

create or replace function public.have_traded(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.trades where status = 'done' and ((host = a and guest = b) or (host = b and guest = a)));
$$;
revoke execute on function public.have_traded(uuid, uuid) from public, anon, authenticated;

-- suivre (seulement quelqu'un avec qui on a déjà échangé) ou ne plus suivre
create or replace function public.follow(p_friend uuid, p_on boolean) returns void
language plpgsql volatile security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  if p_on then
    if not public.have_traded(auth.uid(), p_friend) then raise exception 'on ne suit que quelqu''un avec qui on a échangé'; end if;
    insert into public.follows (user_id, friend_id) values (auth.uid(), p_friend) on conflict do nothing;
  else
    delete from public.follows where user_id = auth.uid() and friend_id = p_friend;
  end if;
end $$;
revoke execute on function public.follow(uuid, boolean) from public, anon;
grant execute on function public.follow(uuid, boolean) to authenticated;

-- mes potes : pseudo, photo, cri, dernier échange
create or replace function public.my_friends()
returns table (friend_id uuid, username text, avatar_path text, cry_path text, metal_power text, last_trade timestamptz, trades int)
language sql stable security definer set search_path = public as $$
  select f.friend_id, p.username, p.avatar_path, p.cry_path, p.metal_power,
         (select max(done_at) from public.trades t where t.status = 'done' and ((t.host = auth.uid() and t.guest = f.friend_id) or (t.host = f.friend_id and t.guest = auth.uid()))),
         (select count(*)::int from public.trades t where t.status = 'done' and ((t.host = auth.uid() and t.guest = f.friend_id) or (t.host = f.friend_id and t.guest = auth.uid())))
    from public.follows f join public.profiles p on p.id = f.friend_id
   where f.user_id = auth.uid()
   order by 6 desc nulls last;
$$;
revoke execute on function public.my_friends() from public, anon;
grant execute on function public.my_friends() to authenticated;

-- classeur d'un pote (pour son profil et ce qui lui manque) : seulement un pote suivi
create or replace function public.friend_cards(p_friend uuid)
returns table (musician_id text, rarity public.rarity, copies int, placed boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if not exists (select 1 from public.follows where user_id = auth.uid() and friend_id = p_friend) then raise exception 'pas dans tes potes'; end if;
  return query select i.musician_id, i.rarity, i.copies, i.placed from public.inventory i where i.user_id = p_friend and i.copies > 0;
end $$;
revoke execute on function public.friend_cards(uuid) from public, anon;
grant execute on function public.friend_cards(uuid) to authenticated;

-- ---------------------------------------------------------------- échange proposé à un pote
alter table public.trades add column if not exists invited uuid references auth.users (id) on delete set null;

create or replace function public.trade_invite(p_friend uuid) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare s jsonb; v_name text := (select username from public.profiles where id = auth.uid());
begin
  if not exists (select 1 from public.follows where user_id = auth.uid() and friend_id = p_friend) then raise exception 'pas dans tes potes'; end if;
  s := public.trade_create();
  update public.trades set invited = p_friend where id = (s ->> 'id')::uuid;
  perform public.send_push(p_friend, 'Échange proposé', coalesce(v_name, 'Un pote') || ' te propose un échange. Viens poser tes cartes.', 'echange',
                           'https://pittilloni.github.io/metalnini/proto/?troc=' || (s ->> 'code'));
  return s;
end $$;
revoke execute on function public.trade_invite(uuid) from public, anon;
grant execute on function public.trade_invite(uuid) to authenticated;

-- échanges qu'on me propose (en attente, pas encore rejoints)
create or replace function public.my_trade_invites()
returns table (code text, from_name text, created_at timestamptz)
language plpgsql volatile security definer set search_path = public as $$
begin
  perform public.trade_expire();
  return query select t.code, p.username, t.created_at from public.trades t join public.profiles p on p.id = t.host
    where t.invited = auth.uid() and t.status = 'open' order by t.created_at desc;
end $$;
revoke execute on function public.my_trade_invites() from public, anon;
grant execute on function public.my_trade_invites() to authenticated;
