-- Metalnini — messages de l'admin aussi par e-mail : aux joueurs ciblés dont l'adresse est confirmée et qui n'ont pas coupé
-- les e-mails (réglage de l'app « Recevoir les nouvelles par e-mail »). L'envoi part de la fonction serveur send-mail
-- (SMTP Gmail, ~500 par jour), appelée par la base avec le secret partagé des notifications.

alter table public.profiles add column if not exists mail_optout boolean not null default false;

-- le joueur coupe ou rallume les e-mails de nouvelles
create or replace function public.set_mail_optout(p_off boolean) returns boolean
language plpgsql volatile security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  update public.profiles set mail_optout = coalesce(p_off, false) where id = auth.uid();
  return coalesce(p_off, false);
end $$;
revoke execute on function public.set_mail_optout(boolean) from public, anon;
grant execute on function public.set_mail_optout(boolean) to authenticated;

-- audience : en plus, combien d'adresses e-mail joignables
create or replace function public.admin_audience(p_filter jsonb) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  return (select jsonb_build_object('players', count(*),
            'push', count(*) filter (where exists (select 1 from public.push_subscriptions s where s.user_id = t.id)),
            'mail', count(*) filter (where u.email_confirmed_at is not null and u.email is not null and not p.mail_optout))
            from public.admin_targets(coalesce(p_filter, '{}'::jsonb)) t(id) join auth.users u on u.id = t.id join public.profiles p on p.id = t.id);
end $$;

-- envoyer : notification si possible, sinon message dans l'app ; et, si p_mail, un e-mail aux adresses joignables
drop function if exists public.admin_send_message(text, text, text, jsonb, text, boolean);
create or replace function public.admin_send_message(p_title text, p_body text, p_url text, p_filter jsonb, p_reason text, p_force boolean default false, p_mail boolean default false) returns jsonb
language plpgsql volatile security definer set search_path = public, extensions as $$
declare u uuid; n_push int := 0; n_inbox int := 0; v_url text := nullif(trim(coalesce(p_url, '')), ''); v_mail jsonb := '[]'::jsonb;
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  if p_reason is null or length(trim(p_reason)) = 0 then raise exception 'motif obligatoire'; end if;
  if length(trim(coalesce(p_title, ''))) not between 3 and 60 then raise exception 'titre : 3 à 60 caractères'; end if;
  if length(trim(coalesce(p_body, ''))) not between 3 and 160 then raise exception 'message : 3 à 160 caractères'; end if;
  if v_url is not null and v_url !~ '^https://pittilloni\.github\.io/metalnini/proto/' then raise exception 'le lien doit mener dans l''app'; end if;
  for u in select * from public.admin_targets(coalesce(p_filter, '{}'::jsonb)) loop
    if public.send_push(u, trim(p_title), trim(p_body), 'annonce', coalesce(v_url, 'https://pittilloni.github.io/metalnini/proto/'), coalesce(p_force, false)) then n_push := n_push + 1;
    else insert into public.player_messages (user_id, title, body, url) values (u, trim(p_title), trim(p_body), v_url); n_inbox := n_inbox + 1; end if;
  end loop;
  if p_mail then
    select coalesce(jsonb_agg(jsonb_build_object('email', au.email, 'name', p.username)), '[]'::jsonb) into v_mail
      from public.admin_targets(coalesce(p_filter, '{}'::jsonb)) t(id) join auth.users au on au.id = t.id join public.profiles p on p.id = t.id
     where au.email_confirmed_at is not null and au.email is not null and not p.mail_optout;
    if jsonb_array_length(v_mail) > 0 then
      perform net.http_post(
        url := 'https://mdnevzmczljycmgbsrsu.supabase.co/functions/v1/send-mail',
        headers := jsonb_build_object('Content-Type', 'application/json',
          'x-push-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'push_secret')),
        body := jsonb_build_object('to', v_mail, 'title', trim(p_title), 'body', trim(p_body), 'url', coalesce(v_url, 'https://pittilloni.github.io/metalnini/proto/')),
        timeout_milliseconds := 60000);
    end if;
  end if;
  insert into public.admin_audit_log (admin_id, action, payload, reason)
    values (auth.uid(), 'targeted_message', jsonb_build_object('title', trim(p_title), 'body', trim(p_body), 'url', v_url, 'filter', p_filter,
                                                              'push', n_push, 'inbox', n_inbox, 'mail', jsonb_array_length(v_mail)), p_reason);
  return jsonb_build_object('push', n_push, 'inbox', n_inbox, 'mail', jsonb_array_length(v_mail));
end $$;
revoke execute on function public.admin_send_message(text, text, text, jsonb, text, boolean, boolean) from public, anon;
grant execute on function public.admin_send_message(text, text, text, jsonb, text, boolean, boolean) to authenticated;
