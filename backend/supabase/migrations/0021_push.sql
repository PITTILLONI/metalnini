-- Metalnini — notifications push : abonnements des appareils, envoi par la fonction serveur « send-push », premier déclencheur = les cadeaux de l'admin.
-- Le secret partagé avec la fonction est rangé dans Vault sous le nom « push_secret » (créé à part, jamais dans le dépôt).

create extension if not exists pg_net with schema extensions;

create table if not exists public.push_subscriptions (
  endpoint   text primary key,
  user_id    uuid not null references auth.users (id) on delete cascade,
  p256dh     text not null,
  auth       text not null,
  created_at timestamptz not null default now()
);
create index if not exists push_subscriptions_user on public.push_subscriptions (user_id);
-- aucun accès direct : les fonctions ci-dessous et la fonction serveur (clé de service) seulement
alter table public.push_subscriptions enable row level security;

-- l'appareil du joueur connecté s'abonne (un appareil passé à un autre compte change de propriétaire)
create or replace function public.save_push_subscription(p_endpoint text, p_p256dh text, p_auth text) returns void
language plpgsql volatile security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  if p_endpoint !~ '^https://' or length(p_endpoint) > 1000 then raise exception 'abonnement invalide'; end if;
  insert into public.push_subscriptions (endpoint, user_id, p256dh, auth) values (p_endpoint, auth.uid(), p_p256dh, p_auth)
    on conflict (endpoint) do update set user_id = auth.uid(), p256dh = excluded.p256dh, auth = excluded.auth, created_at = now();
end $$;
revoke execute on function public.save_push_subscription(text, text, text) from public, anon;
grant execute on function public.save_push_subscription(text, text, text) to authenticated;

create or replace function public.delete_push_subscription(p_endpoint text) returns void
language sql volatile security definer set search_path = public as $$
  delete from public.push_subscriptions where endpoint = p_endpoint and user_id = auth.uid();
$$;
revoke execute on function public.delete_push_subscription(text) from public, anon;
grant execute on function public.delete_push_subscription(text) to authenticated;

-- envoi (usage interne) : appel asynchrone de la fonction serveur, seulement si le joueur a un appareil abonné
create or replace function public.send_push(p_user uuid, p_title text, p_body text, p_url text default null) returns void
language plpgsql volatile security definer set search_path = public, extensions as $$
begin
  if not exists (select 1 from public.push_subscriptions where user_id = p_user) then return; end if;
  perform net.http_post(
    url := 'https://mdnevzmczljycmgbsrsu.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object('Content-Type', 'application/json',
      'x-push-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'push_secret')),
    body := jsonb_build_object('user_id', p_user, 'title', p_title, 'body', p_body, 'url', p_url));
end $$;
revoke execute on function public.send_push(uuid, text, text, text) from public, anon, authenticated;

-- premier déclencheur : un cadeau de l'admin (carte ou points de paquet)
create or replace function public.gift_notice_push() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.send_push(new.user_id, 'Cadeau du Grand Architecte',
    case when new.musician_id is not null then 'Une carte t''attend. Viens voir qui c''est.'
         when new.points = 1 then 'Un mini t''attend, en plus de tes cartes du jour.'
         else 'Un paquet standard t''attend, en plus de tes cartes du jour.' end);
  return new;
end $$;
drop trigger if exists gift_notice_push on public.gift_notices;
create trigger gift_notice_push after insert on public.gift_notices for each row execute function public.gift_notice_push();

-- l'admin envoie une notification de test à un joueur ; renvoie le nombre d'appareils abonnés
create or replace function public.admin_test_push(p_user uuid) returns int
language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  perform public.send_push(p_user, 'Test Metalnini', 'Si tu lis ça, les notifications marchent. Le pit peut t''appeler.');
  return (select count(*) from public.push_subscriptions where user_id = p_user);
end $$;
revoke execute on function public.admin_test_push(uuid) from public, anon;
grant execute on function public.admin_test_push(uuid) to authenticated;
