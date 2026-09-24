-- Metalnini — transformation des doublons à paliers exponentiels (×2 par rareté).
-- Commune → Rare : 3 doublons, Rare → Holo : 6, Holo → Signature : 12, Signature → Légendaire : 24.
-- Depuis des Communes, une Légendaire demande 3 × 6 × 12 × 24 = 5 184 Communes : elle reste rarissime.

insert into public.settings (key, value) values
  ('fusion_cost_commune', '3'), ('fusion_cost_rare', '6'), ('fusion_cost_holo', '12'), ('fusion_cost_signature', '24')
on conflict (key) do nothing;
delete from public.settings where key = 'fusion_cost';

create or replace function public.fuse_cards(p_musician text, p_rarity public.rarity) returns public.rarity
language plpgsql security definer set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_tier int := array_position(enum_range(null::public.rarity), p_rarity) - 1;   -- 0 pour Commune
  v_cost int := public.setting_int('fusion_cost_' || p_rarity::text, (3 * power(2, v_tier))::int);
  v_next public.rarity;
  v_copies int;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  if p_rarity = 'legendaire' then raise exception 'la Légendaire ne se transforme pas'; end if;
  v_next := (enum_range(p_rarity, null))[2];
  select copies into v_copies from public.inventory where user_id = v_user and musician_id = p_musician and rarity = p_rarity for update;
  -- on garde toujours un exemplaire : il faut v_cost doublons en plus de lui
  if coalesce(v_copies, 0) - 1 < v_cost then raise exception 'pas assez de doublons : % nécessaires', v_cost; end if;
  update public.inventory set copies = copies - v_cost, updated_at = now() where user_id = v_user and musician_id = p_musician and rarity = p_rarity;
  insert into public.inventory as inv (user_id, musician_id, rarity, copies, placed) values (v_user, p_musician, v_next, 1, false)
    on conflict (user_id, musician_id, rarity) do update set copies = inv.copies + 1, updated_at = now();
  return v_next;
end $$;
