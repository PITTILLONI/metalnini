-- Metalnini — déchirer une carte : un exemplaire détruit, définitivement.
create or replace function public.tear_card(p_musician text, p_rarity public.rarity) returns int
language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_left int;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  update public.inventory set copies = copies - 1, updated_at = now()
   where user_id = v_user and musician_id = p_musician and rarity = p_rarity and copies > 0
   returning copies into v_left;
  if v_left is null then raise exception 'carte introuvable dans ta collection'; end if;
  if v_left = 0 then delete from public.inventory where user_id = v_user and musician_id = p_musician and rarity = p_rarity; end if;
  return v_left;   -- exemplaires restants
end $$;
revoke execute on function public.tear_card(text, public.rarity) from public, anon;
grant execute on function public.tear_card(text, public.rarity) to authenticated;
