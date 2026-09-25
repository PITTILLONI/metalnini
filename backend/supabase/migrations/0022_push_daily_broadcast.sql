-- Metalnini — rappel du paquet du jour et annonces de l'admin, sous budget : au plus N notifications par jour et par joueur (heure de Paris).

create extension if not exists pg_cron;

create table if not exists public.push_log (
  id      bigserial primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  kind    text not null,
  sent_at timestamptz not null default now()
);
create index if not exists push_log_user_day on public.push_log (user_id, sent_at);
alter table public.push_log enable row level security;

insert into public.settings (key, value) values ('daily_push_hour', '18'), ('push_daily_budget', '2') on conflict (key) do nothing;

-- envoi (usage interne) ; false si le joueur n'a pas d'appareil abonné ou a déjà atteint son budget du jour.
-- Les notifications de test (p_force) passent toujours et ne comptent pas dans le budget.
drop function if exists public.send_push(uuid, text, text, text);
create or replace function public.send_push(p_user uuid, p_title text, p_body text, p_kind text default 'autre', p_url text default null, p_force boolean default false)
returns boolean language plpgsql volatile security definer set search_path = public, extensions as $$
begin
  if not exists (select 1 from public.push_subscriptions where user_id = p_user) then return false; end if;
  if not p_force and (select count(*) from public.push_log where user_id = p_user and kind <> 'test' and sent_at >= public.paris_day_start())
       >= public.setting_int('push_daily_budget', 2) then return false; end if;
  perform net.http_post(
    url := 'https://mdnevzmczljycmgbsrsu.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object('Content-Type', 'application/json',
      'x-push-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'push_secret')),
    body := jsonb_build_object('user_id', p_user, 'title', p_title, 'body', p_body, 'url', p_url));
  insert into public.push_log (user_id, kind) values (p_user, case when p_force then 'test' else p_kind end);
  return true;
end $$;
revoke execute on function public.send_push(uuid, text, text, text, text, boolean) from public, anon, authenticated;

create or replace function public.gift_notice_push() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.send_push(new.user_id, 'Cadeau du Grand Architecte',
    case when new.musician_id is not null then 'Une carte t''attend. Viens voir qui c''est.'
         when new.points = 1 then 'Un mini t''attend, en plus de tes cartes du jour.'
         else 'Un paquet standard t''attend, en plus de tes cartes du jour.' end, 'cadeau');
  return new;
end $$;

create or replace function public.admin_test_push(p_user uuid) returns int
language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  perform public.send_push(p_user, 'Test Metalnini', 'Si tu lis ça, les notifications marchent. Le pit peut t''appeler.', 'test', null, true);
  return (select count(*) from public.push_subscriptions where user_id = p_user);
end $$;

-- rappel du paquet du jour : lancé chaque heure, n'agit qu'à l'heure réglée (daily_push_hour, heure de Paris ; -1 = désactivé),
-- une fois par jour et par joueur abonné qui a encore des points du jour
create or replace function public.daily_pack_push() returns int
language plpgsql volatile security definer set search_path = public as $$
declare v_hour int := public.setting_int('daily_push_hour', 18); v_ppd int := public.setting_int('pack_points_per_day', 2); u uuid; n int := 0;
begin
  if v_hour < 0 or extract(hour from now() at time zone 'Europe/Paris')::int <> v_hour then return 0; end if;
  for u in
    select distinct s.user_id from public.push_subscriptions s
    where not exists (select 1 from public.profiles p where p.id = s.user_id and p.blocked)
      and not exists (select 1 from public.push_log l where l.user_id = s.user_id and l.kind = 'paquet' and l.sent_at >= public.paris_day_start())
      and v_ppd > coalesce((select sum(case when o.format = 'small' then 1 else 2 end) from public.pack_openings o
                             where o.user_id = s.user_id and not o.bonus and o.created_at >= public.paris_day_start()), 0)
  loop
    if public.send_push(u, 'Tes cartes du jour t''attendent', 'Le merch a rouvert : 1 standard ou 2 minis, à toi de choisir.', 'paquet') then n := n + 1; end if;
  end loop;
  return n;
end $$;
revoke execute on function public.daily_pack_push() from public, anon, authenticated;
select cron.schedule('metalnini-daily-pack-push', '0 * * * *', 'select public.daily_pack_push()');

-- annonce de l'admin (nouvelles cartes, mise à jour) à tous les joueurs abonnés, sous budget, journalisée
create or replace function public.admin_broadcast_push(p_title text, p_body text, p_reason text) returns int
language plpgsql volatile security definer set search_path = public as $$
declare u uuid; n int := 0;
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  if p_reason is null or length(trim(p_reason)) = 0 then raise exception 'motif obligatoire'; end if;
  if length(trim(coalesce(p_title, ''))) not between 3 and 60 then raise exception 'titre : 3 à 60 caractères'; end if;
  if length(trim(coalesce(p_body, ''))) not between 3 and 160 then raise exception 'message : 3 à 160 caractères'; end if;
  for u in select distinct user_id from public.push_subscriptions loop
    if public.send_push(u, trim(p_title), trim(p_body), 'annonce') then n := n + 1; end if;
  end loop;
  insert into public.admin_audit_log (admin_id, action, payload, reason)
    values (auth.uid(), 'broadcast_push', jsonb_build_object('title', trim(p_title), 'body', trim(p_body), 'sent', n), p_reason);
  return n;
end $$;
revoke execute on function public.admin_broadcast_push(text, text, text) from public, anon;
grant execute on function public.admin_broadcast_push(text, text, text) to authenticated;

-- nombre de joueurs joignables (au moins un appareil abonné), pour l'admin
create or replace function public.admin_push_audience() returns int
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  return (select count(distinct user_id) from public.push_subscriptions);
end $$;
revoke execute on function public.admin_push_audience() from public, anon;
grant execute on function public.admin_push_audience() to authenticated;
