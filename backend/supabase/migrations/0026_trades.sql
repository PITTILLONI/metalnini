-- Metalnini — échange entre deux fans (v1) : session ouverte par un code (QR ou 6 caractères, à distance autorisé en v1),
-- composition en direct, double validation, échange « tout ou rien » exécuté par le serveur.
-- Carte bonus garantie au premier échange conclu avec un fan donné : une carte que le joueur n'a pas encore (Commune).

create table if not exists public.trades (
  id         uuid primary key default gen_random_uuid(),
  code       text not null,
  host       uuid not null references auth.users (id) on delete cascade,
  guest      uuid references auth.users (id) on delete cascade,
  status     text not null default 'open' check (status in ('open', 'live', 'done', 'cancelled')),
  host_ok    boolean not null default false,
  guest_ok   boolean not null default false,
  version    int not null default 0,                 -- change à chaque carte ajoutée ou retirée : une validation porte sur une version
  left_by    uuid,                                   -- qui a quitté la session (annulation)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  done_at    timestamptz
);
-- un code n'est pris que par une session en cours
create unique index if not exists trades_code_live on public.trades (code) where status in ('open', 'live');
create index if not exists trades_host_idx on public.trades (host);
create index if not exists trades_guest_idx on public.trades (guest);

create table if not exists public.trade_items (
  trade_id    uuid not null references public.trades (id) on delete cascade,
  owner       uuid not null references auth.users (id) on delete cascade,
  musician_id text not null,
  rarity      public.rarity not null,
  copies      int not null check (copies > 0),
  primary key (trade_id, owner, musician_id, rarity),
  foreign key (musician_id, rarity) references public.cards (musician_id, rarity)
);

-- cartes bonus de rencontre : une par joueur et par partenaire
create table if not exists public.trade_bonuses (
  user_id     uuid not null references auth.users (id) on delete cascade,
  partner_id  uuid not null references auth.users (id) on delete cascade,
  trade_id    uuid not null references public.trades (id) on delete cascade,
  musician_id text not null,
  rarity      public.rarity not null,
  created_at  timestamptz not null default now(),
  primary key (user_id, partner_id)
);

alter table public.trades        enable row level security;
alter table public.trade_items   enable row level security;
alter table public.trade_bonuses enable row level security;
-- lecture réservée aux deux participants (nécessaire au temps réel) ; aucune écriture directe
drop policy if exists trades_participants on public.trades;
create policy trades_participants on public.trades for select to authenticated using (auth.uid() in (host, guest));
drop policy if exists trades_admin on public.trades;
create policy trades_admin on public.trades for select to authenticated using (public.is_admin());

-- temps réel : chaque changement de la session (carte, validation, statut) passe par une mise à jour de `trades`
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'trades') then
    alter publication supabase_realtime add table public.trades;
  end if;
end $$;

-- une session sans partenaire expire au bout de 30 minutes ; une session en cours, au bout de 2 heures sans activité
create or replace function public.trade_expire() returns void
language sql security definer set search_path = public as $$
  update public.trades set status = 'cancelled', updated_at = now()
   where (status = 'open' and updated_at < now() - interval '30 minutes')
      or (status = 'live' and updated_at < now() - interval '2 hours');
$$;
revoke execute on function public.trade_expire() from public, anon, authenticated;

-- état complet d'une session, vu par l'un des deux participants
create or replace function public.trade_state(p_trade uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := auth.uid(); t public.trades; v_partner uuid;
begin
  select * into t from public.trades where id = p_trade;
  if t.id is null or v_user not in (t.host, coalesce(t.guest, t.host)) then raise exception 'échange introuvable'; end if;
  v_partner := case when v_user = t.host then t.guest else t.host end;
  return jsonb_build_object(
    'id', t.id, 'code', t.code, 'status', t.status, 'version', t.version, 'host', v_user = t.host,
    'partner', (select username from public.profiles where id = v_partner),
    'left', t.left_by is not null and t.left_by <> v_user,
    'my_ok', case when v_user = t.host then t.host_ok else t.guest_ok end,
    'their_ok', case when v_user = t.host then t.guest_ok else t.host_ok end,
    'give', coalesce((select jsonb_agg(jsonb_build_object('m', i.musician_id, 'r', i.rarity, 'n', i.copies) order by i.musician_id, i.rarity)
                        from public.trade_items i where i.trade_id = t.id and i.owner = v_user), '[]'),
    'get', coalesce((select jsonb_agg(jsonb_build_object('m', i.musician_id, 'r', i.rarity, 'n', i.copies) order by i.musician_id, i.rarity)
                       from public.trade_items i where i.trade_id = t.id and i.owner = v_partner), '[]'),
    'bonus', (select jsonb_build_object('m', b.musician_id, 'r', b.rarity) from public.trade_bonuses b where b.trade_id = t.id and b.user_id = v_user));
end $$;

-- ouvrir une session : un code neuf, les sessions précédentes du joueur sont fermées
create or replace function public.trade_create() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_code text; v_id uuid; v_abc text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; i int;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  perform public.trade_expire();
  update public.trades set status = 'cancelled', left_by = v_user, updated_at = now() where status in ('open', 'live') and v_user in (host, guest);
  loop
    v_code := '';
    for i in 1..6 loop v_code := v_code || substr(v_abc, 1 + floor(random() * length(v_abc))::int, 1); end loop;
    begin
      insert into public.trades (code, host) values (v_code, v_user) returning id into v_id;
      exit;
    exception when unique_violation then end;   -- code déjà pris par une session en cours : on en tire un autre
  end loop;
  return public.trade_state(v_id);
end $$;

-- rejoindre une session par son code
create or replace function public.trade_join(p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); t public.trades;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  perform public.trade_expire();
  select * into t from public.trades where code = upper(replace(trim(p_code), '-', '')) and status in ('open', 'live') for update;
  if t.id is null then raise exception 'code inconnu ou expiré'; end if;
  if t.host = v_user then return public.trade_state(t.id); end if;
  if t.guest is not null and t.guest <> v_user then raise exception 'cet échange a déjà un partenaire'; end if;
  if t.guest is null then
    update public.trades set status = 'cancelled', left_by = v_user, updated_at = now() where status in ('open', 'live') and v_user in (host, guest) and id <> t.id;
    update public.trades set guest = v_user, status = 'live', updated_at = now() where id = t.id;
  end if;
  return public.trade_state(t.id);
end $$;

-- mettre (ou retirer, p_copies = 0) une de ses cartes dans l'échange ; toute modification annule les deux validations
create or replace function public.trade_set_item(p_trade uuid, p_musician text, p_rarity public.rarity, p_copies int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); t public.trades; v_have int;
begin
  select * into t from public.trades where id = p_trade for update;
  if t.id is null or v_user not in (t.host, coalesce(t.guest, t.host)) then raise exception 'échange introuvable'; end if;
  if t.status <> 'live' then raise exception 'cet échange n''est plus ouvert'; end if;
  if p_copies < 0 or p_copies > 99 then raise exception 'nombre invalide'; end if;
  if p_copies = 0 then
    delete from public.trade_items where trade_id = t.id and owner = v_user and musician_id = p_musician and rarity = p_rarity;
  else
    select copies into v_have from public.inventory where user_id = v_user and musician_id = p_musician and rarity = p_rarity;
    if coalesce(v_have, 0) < p_copies then raise exception 'tu n''as pas assez d''exemplaires de cette carte'; end if;
    insert into public.trade_items as ti (trade_id, owner, musician_id, rarity, copies) values (t.id, v_user, p_musician, p_rarity, p_copies)
      on conflict (trade_id, owner, musician_id, rarity) do update set copies = excluded.copies;
  end if;
  if (select count(*) from public.trade_items where trade_id = t.id and owner = v_user) > 20 then raise exception '20 cartes différentes au plus par échange'; end if;
  update public.trades set host_ok = false, guest_ok = false, version = version + 1, updated_at = now() where id = t.id;
  return public.trade_state(t.id);
end $$;

-- valider (ou retirer sa validation) ; quand les deux ont validé la même version, l'échange est exécuté
create or replace function public.trade_confirm(p_trade uuid, p_ok boolean, p_version int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); t public.trades; it record; v_have int; v_to uuid; u uuid; v_other uuid; v_m text;
begin
  select * into t from public.trades where id = p_trade for update;
  if t.id is null or v_user not in (t.host, coalesce(t.guest, t.host)) then raise exception 'échange introuvable'; end if;
  if t.status <> 'live' then raise exception 'cet échange n''est plus ouvert'; end if;
  if p_ok and p_version <> t.version then raise exception 'l''échange vient de changer : relis-le avant de valider'; end if;
  if p_ok and not exists (select 1 from public.trade_items where trade_id = t.id) then raise exception 'mets au moins une carte dans l''échange'; end if;
  if v_user = t.host then update public.trades set host_ok = p_ok, updated_at = now() where id = t.id returning * into t;
  else update public.trades set guest_ok = p_ok, updated_at = now() where id = t.id returning * into t; end if;

  if t.host_ok and t.guest_ok then
    -- inventaires des deux joueurs verrouillés dans un ordre fixe (pas d'interblocage entre deux échanges croisés)
    perform 1 from public.inventory where user_id in (t.host, t.guest) order by user_id, musician_id, rarity for update;
    for it in select * from public.trade_items where trade_id = t.id loop
      select copies into v_have from public.inventory where user_id = it.owner and musician_id = it.musician_id and rarity = it.rarity;
      if coalesce(v_have, 0) < it.copies then
        update public.trades set host_ok = false, guest_ok = false, version = version + 1, updated_at = now() where id = t.id;
        raise exception 'une carte de l''échange n''est plus disponible';
      end if;
      v_to := case when it.owner = t.host then t.guest else t.host end;
      update public.inventory set copies = copies - it.copies, updated_at = now() where user_id = it.owner and musician_id = it.musician_id and rarity = it.rarity;
      delete from public.inventory where user_id = it.owner and musician_id = it.musician_id and rarity = it.rarity and copies = 0;
      insert into public.inventory as inv (user_id, musician_id, rarity, copies, placed) values (v_to, it.musician_id, it.rarity, it.copies, false)
        on conflict (user_id, musician_id, rarity) do update set copies = inv.copies + excluded.copies, updated_at = now();
    end loop;
    -- carte bonus de rencontre : la première fois avec ce partenaire, une carte qu'on n'a pas encore
    foreach u in array array[t.host, t.guest] loop
      v_other := case when u = t.host then t.guest else t.host end;
      if not exists (select 1 from public.trade_bonuses where user_id = u and partner_id = v_other) then
        select m.id into v_m from public.musicians m
         where m.active and not exists (select 1 from public.inventory i where i.user_id = u and i.musician_id = m.id)
         order by random() limit 1;
        if v_m is not null then
          insert into public.inventory (user_id, musician_id, rarity, copies, placed) values (u, v_m, 'commune', 1, false);
          insert into public.trade_bonuses (user_id, partner_id, trade_id, musician_id, rarity) values (u, v_other, t.id, v_m, 'commune');
        end if;
      end if;
    end loop;
    update public.trades set status = 'done', done_at = now(), updated_at = now() where id = t.id;
  end if;
  return public.trade_state(t.id);
end $$;

-- quitter la session
create or replace function public.trade_cancel(p_trade uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid();
begin
  update public.trades set status = 'cancelled', left_by = v_user, updated_at = now()
   where id = p_trade and status in ('open', 'live') and v_user in (host, coalesce(guest, host));
end $$;

-- nombre d'échanges conclus (titre « Metal Corner » dès le premier)
create or replace function public.my_trade_count() returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int from public.trades where status = 'done' and auth.uid() in (host, guest);
$$;

do $$ declare f text; begin
  foreach f in array array['trade_state(uuid)', 'trade_create()', 'trade_join(text)', 'trade_set_item(uuid, text, public.rarity, int)',
                           'trade_confirm(uuid, boolean, int)', 'trade_cancel(uuid)', 'my_trade_count()'] loop
    execute 'revoke execute on function public.' || f || ' from public, anon';
    execute 'grant execute on function public.' || f || ' to authenticated';
  end loop;
end $$;
