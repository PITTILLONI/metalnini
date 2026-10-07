-- Metalnini — « Ta carte perso » à 4,99 € : le joueur paie, le serveur génère sa carte Légendaire à partir de sa photo de profil
-- (fonction perso-generate : carte de base puis Légendaire, Krea), l'équipe d'admin la valide d'un clic (ou relance, ou refuse),
-- puis elle lui est offerte. Les cartes perso se troquent et se partagent comme les autres : tous les joueurs connectés peuvent
-- voir leur image (le joueur l'accepte avant de payer).

alter table public.purchases drop constraint if exists purchases_offer_check;
alter table public.purchases add constraint purchases_offer_check check (offer in ('pack1', 'pack3', 'artist', 'perso'));
update public.settings set value = value || '{"perso": {"url": null, "cents": 499}}'::jsonb where key = 'shop' and not (value ? 'perso');

create table if not exists public.perso_orders (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  purchase_id uuid references public.purchases (id) on delete set null,
  nickname    text not null check (length(nickname) between 2 and 24),
  avatar_path text not null,
  musician_id text,                       -- p-xxxxxxxx, créé à la fin de la génération
  status      text not null default 'paid' check (status in ('paid', 'base', 'ready', 'approved', 'rejected', 'error')),
  base_url    text,                       -- carte de base (Krea), avant la Légendaire
  error       text,
  tries       int not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists perso_orders_user on public.perso_orders (user_id, created_at desc);
alter table public.perso_orders enable row level security;
drop policy if exists perso_orders_read on public.perso_orders;
create policy perso_orders_read on public.perso_orders for select to authenticated using (user_id = auth.uid() or public.is_admin_account());

-- images perso : visibles par tous les joueurs connectés (troc, partage)
drop policy if exists perso_read on storage.objects;
create policy perso_read on storage.objects for select to authenticated using (bucket_id = 'perso');

-- lancer la génération (ou la relancer) : appel de la fonction serveur, authentifié par le secret partagé
create or replace function public.perso_kick(p_order uuid) returns void
language plpgsql volatile security definer set search_path = public, extensions as $$
begin
  perform net.http_post(
    url := 'https://mdnevzmczljycmgbsrsu.supabase.co/functions/v1/perso-generate',
    headers := jsonb_build_object('Content-Type', 'application/json',
      'x-push-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'push_secret')),
    body := jsonb_build_object('order', p_order), timeout_milliseconds := 5000);
end $$;
revoke execute on function public.perso_kick(uuid) from public, anon, authenticated;

-- achat : la carte perso demande une photo de profil et un surnom ; une commande à la fois
create or replace function public.start_purchase(p_offer text, p_artist text default null, p_note text default null) returns uuid
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_artist text := nullif(trim(coalesce(p_artist, '')), ''); v_note text := nullif(trim(coalesce(p_note, '')), '');
        v_offer jsonb := (select value -> p_offer from public.settings where key = 'shop'); v_look jsonb; v_id uuid;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  if exists (select 1 from public.profiles where id = v_user and blocked) then raise exception 'compte bloqué'; end if;
  if v_offer is null or coalesce(v_offer ->> 'url', '') = '' then raise exception 'boutique fermée pour l''instant'; end if;
  if (select count(*) from public.purchases where user_id = v_user and created_at >= now() - interval '1 hour') >= 10 then
    raise exception 'trop d''achats lancés d''un coup : réessaie dans une heure';
  end if;
  if p_offer = 'artist' then
    if v_artist is null or length(v_artist) < 2 or length(v_artist) > 80 then raise exception 'nom d''artiste : 2 à 80 caractères'; end if;
    if v_note is not null and length(v_note) > 200 then raise exception 'message : 200 caractères au plus'; end if;
    v_look := public.artist_lookup(v_artist);
    if (v_look ->> 'found')::boolean then raise exception '% est déjà dans le jeu', v_look ->> 'name'; end if;
    if (v_look ->> 'funded')::boolean then raise exception 'déjà financé par un autre joueur : il arrive bientôt'; end if;
  elsif p_offer = 'perso' then
    if v_artist is null or length(v_artist) < 2 or length(v_artist) > 24 then raise exception 'surnom : 2 à 24 caractères'; end if;
    if public.username_banned(v_artist) then raise exception 'ce surnom ne passe pas la sécurité : pas de haine dans le pit'; end if;
    if (select avatar_path from public.profiles where id = v_user) is null then raise exception 'mets d''abord ta photo de profil : ta carte part de ton visage'; end if;
    if exists (select 1 from public.perso_orders where user_id = v_user and status in ('paid', 'base', 'ready', 'error')) then
      raise exception 'ta carte perso est déjà en fabrication';
    end if;
    v_note := null;
  else
    v_artist := null; v_note := null;
  end if;
  insert into public.purchases (user_id, offer, artist, note) values (v_user, p_offer, v_artist, v_note) returning id into v_id;
  return v_id;
end $$;

-- paiement confirmé : en plus, la commande de carte perso et sa génération
create or replace function public.apply_purchase(p_id uuid, p_session text, p_cents int) returns text
language plpgsql volatile security definer set search_path = public as $$
declare p public.purchases; v_offer jsonb; v_order uuid;
begin
  select * into p from public.purchases where id = p_id for update;
  if p.id is null then return 'inconnu'; end if;
  if p.status = 'paid' then return 'déjà crédité'; end if;
  v_offer := (select value -> p.offer from public.settings where key = 'shop');
  if p_cents is null or p_cents < (v_offer ->> 'cents')::int then return 'montant inattendu'; end if;
  update public.purchases set status = 'paid', paid_at = now(), amount_cents = p_cents, stripe_session = p_session where id = p_id;
  if p.offer = 'artist' then
    insert into public.artist_requests (user_id, artist, note, priority, paid) values (p.user_id, p.artist, p.note, true, true);
    perform public.send_push(p.user_id, 'Paiement reçu', p.artist || ' passe en tête de la liste du Grand Architecte. Tu seras prévenu à sa sortie.', 'achat',
                             'https://pittilloni.github.io/metalnini/proto/', true);
  elsif p.offer = 'perso' then
    insert into public.perso_orders (user_id, purchase_id, nickname, avatar_path)
      values (p.user_id, p.id, p.artist, (select avatar_path from public.profiles where id = p.user_id)) returning id into v_order;
    perform public.perso_kick(v_order);
    perform public.send_push(p.user_id, 'Paiement reçu', 'Ta carte perso est en fabrication. Le Grand Architecte la vérifie, puis elle t''arrive.', 'achat',
                             'https://pittilloni.github.io/metalnini/proto/', true);
  else
    insert into public.profiles (id, bonus_points) values (p.user_id, 2 * (v_offer ->> 'packs')::int)
      on conflict (id) do update set bonus_points = public.profiles.bonus_points + 2 * (v_offer ->> 'packs')::int;
    perform public.send_push(p.user_id, 'Paiement reçu',
                             case when (v_offer ->> 'packs')::int > 1 then (v_offer ->> 'packs') || ' paquets t''attendent.' else 'Un paquet t''attend.' end,
                             'achat', 'https://pittilloni.github.io/metalnini/proto/', true);
  end if;
  return 'crédité';
end $$;

-- fiches de toutes les cartes perso offertes (troc, partage, classeur) ; l'image vient du stockage privé
create or replace function public.my_perso_cards() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', m.id, 'who', m.name, 'band', m.band, 'title', m.arcana_title, 'num', m.arcana_number,
           'genre', m.subgenre, 'cards', (select jsonb_agg(jsonb_build_object('r', c.rarity, 'path', c.image_path)) from public.cards c where c.musician_id = m.id))), '[]'::jsonb)
    from public.musicians m
   where m.perso and auth.uid() is not null and exists (select 1 from public.inventory i where i.musician_id = m.id and i.copies > 0)
$$;

-- ma commande en cours (profil)
create or replace function public.my_perso_order() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('status', o.status, 'nickname', o.nickname, 'created_at', o.created_at)
    from public.perso_orders o where o.user_id = auth.uid() order by o.created_at desc limit 1
$$;
revoke execute on function public.my_perso_order() from public, anon;
grant execute on function public.my_perso_order() to authenticated;

-- admin : les commandes, et la décision (valider : la carte est offerte ; relancer : nouvelle génération ; refuser)
create or replace function public.admin_perso_orders() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'username', coalesce(p.username, 'Sans pseudo'), 'nickname', o.nickname, 'status', o.status,
            'musician_id', o.musician_id, 'error', o.error, 'tries', o.tries, 'created_at', o.created_at,
            'image', (select image_path from public.cards c where c.musician_id = o.musician_id and c.rarity = 'legendaire')) order by o.created_at desc)
          from public.perso_orders o left join public.profiles p on p.id = o.user_id where o.created_at > now() - interval '60 days'), '[]'::jsonb);
end $$;
revoke execute on function public.admin_perso_orders() from public, anon;
grant execute on function public.admin_perso_orders() to authenticated;

create or replace function public.admin_perso_decide(p_order uuid, p_action text, p_reason text default null) returns text
language plpgsql volatile security definer set search_path = public as $$
declare o public.perso_orders;
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  select * into o from public.perso_orders where id = p_order for update;
  if o.id is null then raise exception 'commande introuvable'; end if;
  if p_action = 'approve' then
    if o.status <> 'ready' then raise exception 'la carte n''est pas prête'; end if;
    update public.perso_orders set status = 'approved', updated_at = now() where id = p_order;
    perform public.admin_adjust_card(o.user_id, o.musician_id, 'legendaire', 1, coalesce(p_reason, 'Carte perso validée'), true);
    return 'offerte';
  elsif p_action = 'retry' then
    if o.status in ('approved', 'rejected') then raise exception 'commande close'; end if;
    update public.perso_orders set status = 'paid', base_url = null, error = null, updated_at = now() where id = p_order;
    perform public.perso_kick(p_order);
    return 'relancée';
  elsif p_action = 'reject' then
    update public.perso_orders set status = 'rejected', updated_at = now() where id = p_order;
    perform public.send_push(o.user_id, 'Carte perso', 'Ta carte perso n''a pas pu être faite avec cette photo. Tu es remboursé sous quelques jours : essaie avec une photo de face, bien éclairée.', 'achat',
                             'https://pittilloni.github.io/metalnini/proto/', true);
    return 'refusée';
  end if;
  raise exception 'action inconnue';
end $$;
revoke execute on function public.admin_perso_decide(uuid, text, text) from public, anon;
grant execute on function public.admin_perso_decide(uuid, text, text) to authenticated;

-- admin, plusieurs joueurs d'un coup : cartes perso offertes (sans paiement ; surnom = pseudo, sinon celui donné) ;
-- les joueurs sans photo de profil sont sautés ; renvoie le nombre de cartes lancées et les pseudos sautés
create or replace function public.admin_perso_create(p_users uuid[], p_nickname text default null, p_reason text default null) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u record; n int := 0; skipped text[] := '{}'; v_order uuid;
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  if p_reason is null or length(trim(p_reason)) = 0 then raise exception 'motif obligatoire'; end if;
  for u in select p.id, p.username, p.avatar_path from public.profiles p where p.id = any(p_users) loop
    if u.avatar_path is null or exists (select 1 from public.perso_orders o where o.user_id = u.id and o.status in ('paid', 'base', 'ready', 'error')) then
      skipped := skipped || coalesce(u.username, 'Sans pseudo'); continue;
    end if;
    insert into public.perso_orders (user_id, nickname, avatar_path)
      values (u.id, left(coalesce(nullif(trim(p_nickname), ''), u.username, 'Fan'), 24), u.avatar_path) returning id into v_order;
    perform public.perso_kick(v_order);
    n := n + 1;
  end loop;
  insert into public.admin_audit_log (admin_id, action, payload, reason)
    values (auth.uid(), 'perso_create', jsonb_build_object('users', p_users, 'started', n, 'skipped', skipped), p_reason);
  return jsonb_build_object('started', n, 'skipped', skipped);
end $$;
revoke execute on function public.admin_perso_create(uuid[], text, text) from public, anon;
grant execute on function public.admin_perso_create(uuid[], text, text) to authenticated;

-- admin, plusieurs joueurs d'un coup : la même carte offerte à chacun (cadeau, découvert à la prochaine ouverture)
create or replace function public.admin_gift_cards(p_users uuid[], p_musician text, p_rarity public.rarity, p_reason text) returns int
language plpgsql volatile security definer set search_path = public as $$
declare u uuid; n int := 0;
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  if not exists (select 1 from public.cards where musician_id = p_musician and rarity = p_rarity) then raise exception 'cette carte n''existe pas'; end if;
  foreach u in array p_users loop
    perform public.admin_adjust_card(u, p_musician, p_rarity, 1, p_reason, true);
    n := n + 1;
  end loop;
  return n;
end $$;
revoke execute on function public.admin_gift_cards(uuid[], text, public.rarity, text) from public, anon;
grant execute on function public.admin_gift_cards(uuid[], text, public.rarity, text) to authenticated;
