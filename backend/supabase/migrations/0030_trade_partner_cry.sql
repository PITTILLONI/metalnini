-- Metalnini — le cri du partenaire retentit quand un échange se conclut.

-- état de la session : + le cri du partenaire (chemin du fichier, lisible par tout joueur connecté), joué quand l'échange se conclut
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
    'partner_cry', (select cry_path from public.profiles where id = v_partner),
    'bonus', (select jsonb_build_object('m', b.musician_id, 'r', b.rarity) from public.trade_bonuses b where b.trade_id = t.id and b.user_id = v_user));
end $$;

revoke execute on function public.trade_state(uuid) from public, anon;
grant execute on function public.trade_state(uuid) to authenticated;
