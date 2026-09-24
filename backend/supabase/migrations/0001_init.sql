-- Metalnini — modèle de données v1 (phase 0)
-- Principes : le serveur décide de tout ce qui a de la valeur (tirage, inventaire, fusion) ;
-- l'app lit ses propres données et appelle des fonctions, elle n'écrit jamais directement dans les tables.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------- types
create type public.rarity as enum ('commune', 'rare', 'holo', 'signature', 'legendaire');
create type public.binder_kind as enum ('collection', 'style', 'instrument', 'band');

-- ---------------------------------------------------------------- comptes
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  blocked      boolean not null default false,
  created_at   timestamptz not null default now()
);

create table public.admins (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

-- profil créé automatiquement à l'inscription
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id) values (new.id) on conflict do nothing;
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------- catalogue (géré depuis l'admin)
create table public.musicians (
  id            text primary key,
  name          text not null,
  band          text not null,
  arcana_title  text not null,
  arcana_number text not null,
  instruments   text[] not null default '{}',
  subgenre      text not null,
  active        boolean not null default true
);

create table public.cards (
  musician_id text not null references public.musicians (id) on delete cascade,
  rarity      public.rarity not null,
  image_path  text not null,
  primary key (musician_id, rarity)
);

create table public.binders (
  id    text primary key,
  kind  public.binder_kind not null,
  label text not null,
  sort  int not null default 0
);

create table public.binder_members (
  binder_id   text not null references public.binders (id) on delete cascade,
  musician_id text not null references public.musicians (id) on delete cascade,
  primary key (binder_id, musician_id)
);

create table public.pack_types (
  id        text primary key,
  label     text not null,
  size      int  not null default 5 check (size between 1 and 10),
  binder_id text references public.binders (id),   -- null = tout le catalogue
  active    boolean not null default true
);

create table public.pack_odds (
  pack_type_id text not null references public.pack_types (id) on delete cascade,
  rarity       public.rarity not null,
  weight       numeric not null check (weight >= 0),
  primary key (pack_type_id, rarity)
);

create table public.settings (
  key   text primary key,
  value jsonb not null
);

-- ---------------------------------------------------------------- données joueur
create table public.inventory (
  user_id     uuid not null references auth.users (id) on delete cascade,
  musician_id text not null,
  rarity      public.rarity not null,
  copies      int  not null default 0 check (copies >= 0),
  placed      boolean not null default false,   -- rangée dans le classeur
  updated_at  timestamptz not null default now(),
  primary key (user_id, musician_id, rarity),
  foreign key (musician_id, rarity) references public.cards (musician_id, rarity)
);
create index inventory_user_idx on public.inventory (user_id);

create table public.pack_openings (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  pack_type_id text not null references public.pack_types (id),
  request_id   uuid not null,                    -- idempotence : un même appel rejoué renvoie le même paquet
  created_at   timestamptz not null default now(),
  unique (user_id, request_id)
);
create index pack_openings_user_day_idx on public.pack_openings (user_id, created_at);

create table public.pack_opening_cards (
  opening_id  uuid not null references public.pack_openings (id) on delete cascade,
  position    int  not null,
  musician_id text not null,
  rarity      public.rarity not null,
  is_new      boolean not null,
  primary key (opening_id, position)
);

-- ---------------------------------------------------------------- journal admin
create table public.admin_audit_log (
  id          bigint generated always as identity primary key,
  admin_id    uuid not null references auth.users (id),
  action      text not null,
  target_user uuid,
  payload     jsonb not null default '{}',
  reason      text not null check (length(trim(reason)) > 0),
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------- droits d'accès (RLS)
alter table public.profiles           enable row level security;
alter table public.admins             enable row level security;
alter table public.musicians          enable row level security;
alter table public.cards              enable row level security;
alter table public.binders            enable row level security;
alter table public.binder_members     enable row level security;
alter table public.pack_types         enable row level security;
alter table public.pack_odds          enable row level security;
alter table public.settings           enable row level security;
alter table public.inventory          enable row level security;
alter table public.pack_openings      enable row level security;
alter table public.pack_opening_cards enable row level security;
alter table public.admin_audit_log    enable row level security;

-- catalogue : lisible par tout joueur connecté (les probabilités sont publiques, par transparence)
create policy catalog_read on public.musicians      for select to authenticated using (active or public.is_admin());
create policy catalog_read on public.cards          for select to authenticated using (true);
create policy catalog_read on public.binders        for select to authenticated using (true);
create policy catalog_read on public.binder_members for select to authenticated using (true);
create policy catalog_read on public.pack_types     for select to authenticated using (active or public.is_admin());
create policy catalog_read on public.pack_odds      for select to authenticated using (true);
create policy settings_read on public.settings      for select to authenticated using (true);

-- catalogue et réglages : modifiables par l'admin uniquement
create policy catalog_admin on public.musicians      for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy catalog_admin on public.cards          for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy catalog_admin on public.binders        for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy catalog_admin on public.binder_members for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy catalog_admin on public.pack_types     for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy catalog_admin on public.pack_odds      for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy settings_admin on public.settings      for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- données joueur : chacun lit les siennes, l'admin lit tout ; aucune écriture directe (fonctions seulement)
create policy own_profile   on public.profiles  for select to authenticated using (id = auth.uid() or public.is_admin());
create policy own_profile_u on public.profiles  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
-- un joueur ne peut modifier que son pseudo (jamais « blocked »)
revoke update on public.profiles from authenticated;
grant update (display_name) on public.profiles to authenticated;
create policy own_inventory on public.inventory for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy own_openings  on public.pack_openings for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy own_opening_cards on public.pack_opening_cards for select to authenticated
  using (exists (select 1 from public.pack_openings o where o.id = opening_id and (o.user_id = auth.uid() or public.is_admin())));
create policy admins_read   on public.admins    for select to authenticated using (public.is_admin());
create policy audit_read    on public.admin_audit_log for select to authenticated using (public.is_admin());

-- ---------------------------------------------------------------- fonctions de jeu
create or replace function public.setting_int(p_key text, p_default int) returns int
language sql stable security definer set search_path = public as $$
  select coalesce((select (value #>> '{}')::int from public.settings where key = p_key), p_default);
$$;

-- tire une rareté selon les poids du type de paquet (chaque carte indépendamment)
create or replace function public.draw_rarity(p_pack_type text) returns public.rarity
language plpgsql volatile security definer set search_path = public as $$
declare
  v_total numeric; v_x numeric; r record;
begin
  select sum(weight) into v_total from public.pack_odds where pack_type_id = p_pack_type;
  if v_total is null or v_total <= 0 then raise exception 'probabilités invalides pour %', p_pack_type; end if;
  v_x := random() * v_total;
  for r in select rarity, weight from public.pack_odds where pack_type_id = p_pack_type and weight > 0 order by rarity loop
    if v_x < r.weight then return r.rarity; end if;
    v_x := v_x - r.weight;
  end loop;
  return 'commune';
end $$;

-- Ouvre un paquet : tirage serveur, inventaire mis à jour dans la même transaction, résultat tracé.
-- Rejouer le même p_request_id renvoie le même paquet sans en ouvrir un second.
create or replace function public.open_pack(p_pack_type text, p_request_id uuid)
returns table (card_position int, musician_id text, rarity public.rarity, is_new boolean)
language plpgsql volatile security definer set search_path = public as $$
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

  if (select count(*) from public.pack_openings o where o.user_id = v_user and o.created_at > now() - interval '1 day')
     >= public.setting_int('packs_per_day', 20) then
    raise exception 'limite de paquets atteinte pour aujourd''hui';
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
end $$;

-- Range une carte dans le classeur
create or replace function public.place_card(p_musician text, p_rarity public.rarity) returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.inventory set placed = true, updated_at = now()
   where user_id = auth.uid() and musician_id = p_musician and rarity = p_rarity and copies > 0;
end $$;

-- Fusion : N doublons identiques -> 1 exemplaire de la rareté suivante ; on garde toujours un exemplaire
create or replace function public.fuse_cards(p_musician text, p_rarity public.rarity) returns public.rarity
language plpgsql security definer set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_cost int := public.setting_int('fusion_cost', 5);
  v_next public.rarity;
  v_copies int;
begin
  if p_rarity = 'legendaire' then raise exception 'la Légendaire ne se fusionne pas'; end if;
  v_next := (enum_range(p_rarity, null))[2];
  select copies into v_copies from public.inventory where user_id = v_user and musician_id = p_musician and rarity = p_rarity for update;
  if coalesce(v_copies, 0) - 1 < v_cost then raise exception 'pas assez de doublons'; end if;
  update public.inventory set copies = copies - v_cost, updated_at = now() where user_id = v_user and musician_id = p_musician and rarity = p_rarity;
  insert into public.inventory as inv (user_id, musician_id, rarity, copies, placed) values (v_user, p_musician, v_next, 1, false)
    on conflict (user_id, musician_id, rarity) do update set copies = inv.copies + 1, updated_at = now();
  return v_next;
end $$;

-- ---------------------------------------------------------------- fonctions admin (toujours journalisées)
create or replace function public.admin_adjust_card(p_user uuid, p_musician text, p_rarity public.rarity, p_delta int, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  if p_reason is null or length(trim(p_reason)) = 0 then raise exception 'motif obligatoire'; end if;
  insert into public.inventory as inv (user_id, musician_id, rarity, copies, placed) values (p_user, p_musician, p_rarity, greatest(p_delta, 0), true)
    on conflict (user_id, musician_id, rarity) do update set copies = greatest(inv.copies + p_delta, 0), updated_at = now();
  insert into public.admin_audit_log (admin_id, action, target_user, payload, reason)
    values (auth.uid(), 'adjust_card', p_user, jsonb_build_object('musician', p_musician, 'rarity', p_rarity, 'delta', p_delta), p_reason);
end $$;

create or replace function public.admin_set_blocked(p_user uuid, p_blocked boolean, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  if p_reason is null or length(trim(p_reason)) = 0 then raise exception 'motif obligatoire'; end if;
  update public.profiles set blocked = p_blocked where id = p_user;
  insert into public.admin_audit_log (admin_id, action, target_user, payload, reason)
    values (auth.uid(), case when p_blocked then 'block_user' else 'unblock_user' end, p_user, '{}', p_reason);
end $$;

-- les fonctions internes ne sont pas appelables directement depuis l'app
revoke execute on function public.draw_rarity(text) from public, anon, authenticated;
revoke execute on function public.setting_int(text, int) from public, anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
grant execute on function public.open_pack(text, uuid) to authenticated;
grant execute on function public.place_card(text, public.rarity) to authenticated;
grant execute on function public.fuse_cards(text, public.rarity) to authenticated;
grant execute on function public.admin_adjust_card(uuid, text, public.rarity, int, text) to authenticated;
grant execute on function public.admin_set_blocked(uuid, boolean, text) to authenticated;
