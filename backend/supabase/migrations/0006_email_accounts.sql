-- Metalnini — comptes joueurs par e-mail confirmé (les comptes anonymes ne sont plus créés).

-- vérifier qu'un pseudo est libre avant de créer le compte (ne révèle rien d'autre que libre / pris)
create or replace function public.username_available(p_username text) returns boolean
language sql stable security definer set search_path = public as $$
  select trim(p_username) ~ '^[A-Za-z0-9_.-]{3,20}$'
     and not exists (select 1 from public.profiles where lower(username) = lower(trim(p_username)));
$$;
grant execute on function public.username_available(text) to anon, authenticated;

-- le joueur repart d'une collection vide sans changer de compte (le compteur de paquets du jour est conservé)
create or replace function public.reset_my_collection() returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  delete from public.inventory where user_id = auth.uid();
end $$;
revoke execute on function public.reset_my_collection() from public, anon;
grant execute on function public.reset_my_collection() to authenticated;
