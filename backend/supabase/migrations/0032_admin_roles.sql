-- Metalnini — équipe d'admin : Propriétaire (tout, y compris nommer et retirer des admins) et Admin (tout le reste).
-- La nomination passe par la fonction serveur admin-invite (compte existant nommé tout de suite, sinon e-mail d'invitation).
-- Garde-fous : on ne se retire pas soi-même, il reste toujours au moins un Propriétaire ; tout est journalisé.

alter table public.admins add column if not exists role text not null default 'admin' check (role in ('owner', 'admin'));
-- les admins déclarés jusqu'ici (à la main) deviennent Propriétaires, une seule fois : tant qu'aucun Propriétaire n'existe
update public.admins set role = 'owner' where not exists (select 1 from public.admins where role = 'owner');

-- Propriétaire, avec la double authentification
create or replace function public.is_owner() returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_admin() and exists (select 1 from public.admins where user_id = auth.uid() and role = 'owner');
$$;
revoke execute on function public.is_owner() from public, anon;
grant execute on function public.is_owner() to authenticated;

-- l'équipe : visible par tout admin
create or replace function public.admin_list_admins()
returns table (user_id uuid, email text, role text, created_at timestamptz, last_sign_in_at timestamptz, mfa boolean, me boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  return query
    select a.user_id, u.email::text, a.role, a.created_at, u.last_sign_in_at,
           exists (select 1 from auth.mfa_factors f where f.user_id = a.user_id and f.status = 'verified'), a.user_id = auth.uid()
      from public.admins a join auth.users u on u.id = a.user_id
     order by (a.role = 'owner') desc, a.created_at;
end $$;
revoke execute on function public.admin_list_admins() from public, anon;
grant execute on function public.admin_list_admins() to authenticated;

-- compte par e-mail : réservé à la fonction serveur admin-invite (clé de service)
create or replace function public.admin_find_user(p_email text) returns uuid
language sql stable security definer set search_path = public as $$
  select id from auth.users where lower(email) = lower(trim(p_email)) limit 1;
$$;
revoke execute on function public.admin_find_user(text) from public, anon, authenticated;

-- retirer un admin
create or replace function public.admin_revoke(p_user uuid, p_reason text) returns void
language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'réservé au Propriétaire'; end if;
  if p_reason is null or length(trim(p_reason)) = 0 then raise exception 'motif obligatoire'; end if;
  if p_user = auth.uid() then raise exception 'tu ne peux pas te retirer toi-même'; end if;
  perform 1 from public.admins where role = 'owner' for update;
  if (select role from public.admins where user_id = p_user) = 'owner' and (select count(*) from public.admins where role = 'owner') <= 1 then
    raise exception 'il faut garder au moins un Propriétaire';
  end if;
  delete from public.admins where user_id = p_user;
  insert into public.admin_audit_log (admin_id, action, target_user, payload, reason) values (auth.uid(), 'revoke_admin', p_user, '{}', p_reason);
end $$;
revoke execute on function public.admin_revoke(uuid, text) from public, anon;
grant execute on function public.admin_revoke(uuid, text) to authenticated;

-- changer le rôle d'un admin
create or replace function public.admin_set_role(p_user uuid, p_role text, p_reason text) returns void
language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'réservé au Propriétaire'; end if;
  if p_role not in ('owner', 'admin') then raise exception 'rôle inconnu'; end if;
  if p_reason is null or length(trim(p_reason)) = 0 then raise exception 'motif obligatoire'; end if;
  perform 1 from public.admins where role = 'owner' for update;
  if p_role = 'admin' and (select role from public.admins where user_id = p_user) = 'owner' and (select count(*) from public.admins where role = 'owner') <= 1 then
    raise exception 'il faut garder au moins un Propriétaire';
  end if;
  update public.admins set role = p_role where user_id = p_user;
  if not found then raise exception 'admin introuvable'; end if;
  insert into public.admin_audit_log (admin_id, action, target_user, payload, reason) values (auth.uid(), 'set_admin_role', p_user, jsonb_build_object('role', p_role), p_reason);
end $$;
revoke execute on function public.admin_set_role(uuid, text, text) from public, anon;
grant execute on function public.admin_set_role(uuid, text, text) to authenticated;
