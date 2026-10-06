-- Metalnini — un admin peut jouer comme un joueur standard (paquets comptés, compte à rebours, écran « merch fermé »,
-- boutique) puis revenir aux paquets illimités, depuis les réglages de l'app. Réservé aux membres de l'équipe d'admin (sans double authentification : seul leur propre compte change).

create or replace function public.my_admin_mode() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('admin', public.is_admin_account(),
           'unlimited', coalesce((select unlimited_packs from public.profiles where id = auth.uid()), false))
$$;
revoke execute on function public.my_admin_mode() from public, anon;
grant execute on function public.my_admin_mode() to authenticated;

create or replace function public.set_my_unlimited(p_on boolean) returns boolean
language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.is_admin_account() then raise exception 'réservé à l''équipe d''admin'; end if;
  update public.profiles set unlimited_packs = coalesce(p_on, false) where id = auth.uid();
  return coalesce(p_on, false);
end $$;
revoke execute on function public.set_my_unlimited(boolean) from public, anon;
grant execute on function public.set_my_unlimited(boolean) to authenticated;
