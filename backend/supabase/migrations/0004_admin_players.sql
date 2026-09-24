-- Metalnini — gestion des joueurs depuis l'admin : vider une collection, supprimer un compte.
-- Toujours : rôle admin + double authentification, motif obligatoire, inscription au journal.

-- vide la collection d'un joueur (cartes et historique d'ouverture conservé pour les statistiques)
create or replace function public.admin_clear_inventory(p_user uuid, p_reason text)
returns int language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare n int;
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  if p_reason is null or length(trim(p_reason)) = 0 then raise exception 'motif obligatoire'; end if;
  select coalesce(sum(copies), 0) into n from public.inventory where user_id = p_user;
  insert into public.admin_audit_log (admin_id, action, target_user, payload, reason)
    values (auth.uid(), 'clear_inventory', p_user,
            jsonb_build_object('cards', n, 'inventory', (select jsonb_agg(jsonb_build_object('m', musician_id, 'r', rarity, 'n', copies)) from public.inventory where user_id = p_user)),
            p_reason);
  delete from public.inventory where user_id = p_user;
  return n;
end $$;

-- supprime un joueur : compte, profil, collection et ouvertures (suppression en cascade)
-- interdit sur soi-même et sur un autre admin
create or replace function public.admin_delete_player(p_user uuid, p_reason text)
returns void language plpgsql security definer set search_path = public, auth as $$
declare v_email text;
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  if p_reason is null or length(trim(p_reason)) = 0 then raise exception 'motif obligatoire'; end if;
  if p_user = auth.uid() then raise exception 'impossible de supprimer son propre compte'; end if;
  if exists (select 1 from public.admins where user_id = p_user) then raise exception 'impossible de supprimer un admin'; end if;
  select email into v_email from auth.users where id = p_user;
  if not found then raise exception 'joueur introuvable'; end if;
  insert into public.admin_audit_log (admin_id, action, target_user, payload, reason)
    values (auth.uid(), 'delete_player', p_user,
            jsonb_build_object('email', v_email, 'cards', (select coalesce(sum(copies), 0) from public.inventory where user_id = p_user),
                               'openings', (select count(*) from public.pack_openings where user_id = p_user)),
            p_reason);
  delete from auth.users where id = p_user;
end $$;

grant execute on function public.admin_clear_inventory(uuid, text) to authenticated;
grant execute on function public.admin_delete_player(uuid, text) to authenticated;
