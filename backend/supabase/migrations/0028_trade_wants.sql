-- Metalnini — échange : voir le classeur de son partenaire pendant la session, et lui demander des cartes.
-- Le classeur n'est lisible que par l'autre participant d'un échange en cours ; une demande ne change pas l'échange
-- (pas de nouvelle version, les validations restent), elle remonte simplement la carte en tête chez le partenaire.

create table if not exists public.trade_wants (
  trade_id    uuid not null references public.trades (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,   -- celui qui demande
  musician_id text not null,
  rarity      public.rarity not null,
  created_at  timestamptz not null default now(),
  primary key (trade_id, user_id, musician_id, rarity),
  foreign key (musician_id, rarity) references public.cards (musician_id, rarity)
);
alter table public.trade_wants enable row level security;   -- aucune lecture directe : tout passe par trade_state

-- classeur du partenaire, pendant un échange en cours uniquement
create or replace function public.trade_partner_cards(p_trade uuid) returns table (musician_id text, rarity public.rarity, copies int)
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := auth.uid(); t public.trades; v_partner uuid;
begin
  select * into t from public.trades where id = p_trade;
  if t.id is null or t.guest is null or v_user not in (t.host, t.guest) then raise exception 'échange introuvable'; end if;
  if t.status <> 'live' then raise exception 'cet échange n''est plus ouvert'; end if;
  v_partner := case when v_user = t.host then t.guest else t.host end;
  return query select i.musician_id, i.rarity, i.copies from public.inventory i where i.user_id = v_partner and i.copies > 0;
end $$;

-- demander (ou ne plus demander) une carte du partenaire ; 20 demandes au plus par session
create or replace function public.trade_want(p_trade uuid, p_musician text, p_rarity public.rarity, p_on boolean) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); t public.trades; v_partner uuid;
begin
  select * into t from public.trades where id = p_trade for update;
  if t.id is null or t.guest is null or v_user not in (t.host, t.guest) then raise exception 'échange introuvable'; end if;
  if t.status <> 'live' then raise exception 'cet échange n''est plus ouvert'; end if;
  v_partner := case when v_user = t.host then t.guest else t.host end;
  if p_on then
    if not exists (select 1 from public.inventory where user_id = v_partner and musician_id = p_musician and rarity = p_rarity and copies > 0) then
      raise exception 'ton pote n''a pas cette carte';
    end if;
    insert into public.trade_wants (trade_id, user_id, musician_id, rarity) values (t.id, v_user, p_musician, p_rarity) on conflict do nothing;
    if (select count(*) from public.trade_wants where trade_id = t.id and user_id = v_user) > 20 then raise exception '20 demandes au plus par échange'; end if;
  else
    delete from public.trade_wants where trade_id = t.id and user_id = v_user and musician_id = p_musician and rarity = p_rarity;
  end if;
  update public.trades set updated_at = now() where id = t.id;   -- réveille le temps réel chez le partenaire
  return public.trade_state(t.id);
end $$;

-- état de la session : + les demandes de chacun
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
    'my_wants', coalesce((select jsonb_agg(jsonb_build_object('m', w.musician_id, 'r', w.rarity) order by w.created_at)
                            from public.trade_wants w where w.trade_id = t.id and w.user_id = v_user), '[]'),
    'their_wants', coalesce((select jsonb_agg(jsonb_build_object('m', w.musician_id, 'r', w.rarity) order by w.created_at)
                               from public.trade_wants w where w.trade_id = t.id and w.user_id = v_partner), '[]'),
    'bonus', (select jsonb_build_object('m', b.musician_id, 'r', b.rarity) from public.trade_bonuses b where b.trade_id = t.id and b.user_id = v_user));
end $$;

do $$ declare f text; begin
  foreach f in array array['trade_partner_cards(uuid)', 'trade_want(uuid, text, public.rarity, boolean)', 'trade_state(uuid)'] loop
    execute 'revoke execute on function public.' || f || ' from public, anon';
    execute 'grant execute on function public.' || f || ' to authenticated';
  end loop;
end $$;
