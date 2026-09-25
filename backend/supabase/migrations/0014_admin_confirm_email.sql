-- Metalnini — l'admin voit si l'adresse d'un joueur est confirmée, et peut la confirmer à la main (mail non reçu).

drop function if exists public.admin_list_players();
create function public.admin_list_players()
returns table (id uuid, username text, email text, is_anonymous boolean, email_confirmed boolean, created_at timestamptz, last_sign_in_at timestamptz,
               blocked boolean, cards bigint, variants bigint, openings bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  return query
    select u.id, p.username, u.email::text, u.is_anonymous, u.email_confirmed_at is not null, u.created_at, u.last_sign_in_at, coalesce(p.blocked, false),
           coalesce((select sum(i.copies) from public.inventory i where i.user_id = u.id), 0)::bigint,
           (select count(*) from public.inventory i where i.user_id = u.id and i.copies > 0)::bigint,
           (select count(*) from public.pack_openings o where o.user_id = u.id)::bigint
      from auth.users u left join public.profiles p on p.id = u.id
     order by u.created_at desc;
end $$;
grant execute on function public.admin_list_players() to authenticated;

-- confirmation manuelle d'une adresse, toujours journalisée avec son motif
create or replace function public.admin_confirm_email(p_user uuid, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  if p_reason is null or length(trim(p_reason)) = 0 then raise exception 'motif obligatoire'; end if;
  update auth.users set email_confirmed_at = coalesce(email_confirmed_at, now()) where id = p_user and email is not null;
  if not found then raise exception 'joueur introuvable ou sans adresse e-mail'; end if;
  insert into public.admin_audit_log (admin_id, action, target_user, payload, reason)
    values (auth.uid(), 'confirm_email', p_user, '{}'::jsonb, p_reason);
end $$;
revoke execute on function public.admin_confirm_email(uuid, text) from public, anon;
grant execute on function public.admin_confirm_email(uuid, text) to authenticated;
