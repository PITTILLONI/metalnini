-- Metalnini — boutique : paquets supplémentaires (1 à 1,49 €, 3 à 2,99 €) et carte d'artiste financée (2,99 €, demande
-- prioritaire). Paiement par lien Stripe (Payment Link) : l'app crée un achat « en attente » (start_purchase), ouvre le
-- lien avec l'identifiant de l'achat (client_reference_id), puis la fonction serveur stripe-webhook, seule à pouvoir
-- appeler apply_purchase, crédite le joueur une fois le paiement confirmé et signé par Stripe.
-- Tant qu'une offre n'a pas de lien (réglage « shop »), elle reste cachée dans l'app.

insert into public.settings (key, value) values ('shop', '{
  "pack1":  {"url": null, "cents": 149, "packs": 1},
  "pack3":  {"url": null, "cents": 299, "packs": 3},
  "artist": {"url": null, "cents": 299}
}'::jsonb) on conflict (key) do nothing;

alter table public.artist_requests add column if not exists paid boolean not null default false;

create table if not exists public.purchases (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users (id) on delete cascade,
  offer          text not null check (offer in ('pack1', 'pack3', 'artist')),
  artist         text check (artist is null or length(artist) between 2 and 80),
  note           text check (note is null or length(note) <= 200),
  status         text not null default 'pending' check (status in ('pending', 'paid')),
  amount_cents   int,
  stripe_session text unique,
  seen           boolean not null default false,
  created_at     timestamptz not null default now(),
  paid_at        timestamptz
);
create index if not exists purchases_user on public.purchases (user_id, created_at);
alter table public.purchases enable row level security;
drop policy if exists purchases_read on public.purchases;
create policy purchases_read on public.purchases for select to authenticated using (user_id = auth.uid() or public.is_admin());

-- nom d'artiste comparable : minuscules, sans accents ni ponctuation
create or replace function public.norm_artist(p text) returns text
language sql immutable as $$
  select regexp_replace(translate(lower(coalesce(p, '')), 'áàâäãåéèêëíìîïóòôöõúùûüçñ', 'aaaaaaeeeeiiiiooooouuuucn'), '[^a-z0-9]', '', 'g')
$$;

-- avant de payer : l'artiste est-il déjà dans le jeu, déjà demandé, déjà financé ? (cartes secrètes jamais trahies)
create or replace function public.artist_lookup(p_artist text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v text := public.norm_artist(p_artist); m record;
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  if length(v) < 3 then return jsonb_build_object('found', false, 'asked', 0, 'funded', false); end if;
  select id, name, band into m from public.musicians
   where active and (public.norm_artist(name) = v or public.norm_artist(band) = v
                     or (length(public.norm_artist(name)) >= 5 and v like '%' || public.norm_artist(name) || '%'))
   order by (public.norm_artist(name) = v) desc limit 1;
  return jsonb_build_object(
    'found', m.id is not null, 'id', m.id, 'name', m.name, 'band', m.band,
    'asked', (select count(distinct user_id) from public.artist_requests where not done and public.norm_artist(artist) = v),
    'funded', exists (select 1 from public.artist_requests where not done and paid and public.norm_artist(artist) = v));
end $$;
revoke execute on function public.artist_lookup(text) from public, anon;
grant execute on function public.artist_lookup(text) to authenticated;

-- le joueur lance un achat : renvoie l'identifiant à passer au lien Stripe
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
  else
    v_artist := null; v_note := null;
  end if;
  insert into public.purchases (user_id, offer, artist, note) values (v_user, p_offer, v_artist, v_note) returning id into v_id;
  return v_id;
end $$;
revoke execute on function public.start_purchase(text, text, text) from public, anon;
grant execute on function public.start_purchase(text, text, text) to authenticated;

-- paiement confirmé par Stripe (fonction stripe-webhook, clé de service) : crédite une seule fois ; renvoie l'état
create or replace function public.apply_purchase(p_id uuid, p_session text, p_cents int) returns text
language plpgsql volatile security definer set search_path = public as $$
declare p public.purchases; v_offer jsonb;
begin
  select * into p from public.purchases where id = p_id for update;
  if p.id is null then return 'inconnu'; end if;
  if p.status = 'paid' then return 'déjà crédité'; end if;
  v_offer := (select value -> p.offer from public.settings where key = 'shop');
  if p_cents is distinct from (v_offer ->> 'cents')::int then return 'montant inattendu'; end if;
  update public.purchases set status = 'paid', paid_at = now(), amount_cents = p_cents, stripe_session = p_session where id = p_id;
  if p.offer = 'artist' then
    insert into public.artist_requests (user_id, artist, note, priority, paid) values (p.user_id, p.artist, p.note, true, true);
    perform public.send_push(p.user_id, 'Paiement reçu', p.artist || ' passe en tête de la liste du Grand Architecte. Tu seras prévenu à sa sortie.', 'achat',
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
revoke execute on function public.apply_purchase(uuid, text, int) from public, anon, authenticated;
grant execute on function public.apply_purchase(uuid, text, int) to service_role;

-- achats payés pas encore annoncés dans l'app (puis marqués vus)
create or replace function public.my_purchase_news() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v jsonb;
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'offer', offer, 'artist', artist) order by paid_at), '[]'::jsonb) into v
    from public.purchases where user_id = auth.uid() and status = 'paid' and not seen;
  update public.purchases set seen = true where user_id = auth.uid() and status = 'paid' and not seen;
  return v;
end $$;
revoke execute on function public.my_purchase_news() from public, anon;
grant execute on function public.my_purchase_news() to authenticated;

-- l'admin voit les demandes payées
create or replace function public.admin_requests() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'artist', r.artist, 'note', r.note, 'priority', r.priority, 'paid', r.paid, 'created_at', r.created_at,
                                                       'user_id', r.user_id, 'username', coalesce(p.username, 'Sans pseudo')) order by r.created_at desc)
                     from public.artist_requests r left join public.profiles p on p.id = r.user_id where not r.done), '[]'::jsonb);
end $$;

-- refus d'une demande payée : le joueur est prévenu du remboursement (fait à la main dans Stripe)
create or replace function public.admin_request_handle(p_ids bigint[], p_outcome text) returns int
language plpgsql volatile security definer set search_path = public as $$
declare r record; n int := 0; v_body text;
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  if p_outcome not in ('added', 'refused') then raise exception 'issue inconnue'; end if;
  for r in update public.artist_requests set done = true, outcome = p_outcome, handled_at = now(), seen = false
            where id = any(p_ids) and not done returning user_id, artist, priority, paid loop
    if p_outcome = 'refused' and r.priority and not r.paid then
      update public.profiles set priority_tickets = priority_tickets + 1 where id = r.user_id;
    end if;
    v_body := case
      when p_outcome = 'added' and r.paid then 'Ta carte financée est sortie : ' || r.artist || ' débarque dans les paquets.'
      when p_outcome = 'added' and r.priority then 'Ton ticket prioritaire a payé : ' || r.artist || ' débarque dans les paquets.'
      when p_outcome = 'added' then r.artist || ' débarque dans les paquets. Merci pour la demande.'
      when r.paid then 'Pas de ' || r.artist || ' dans Metalnini pour l''instant. Tu es remboursé sous quelques jours.'
      when r.priority then 'Pas de ' || r.artist || ' dans Metalnini pour l''instant. Ton ticket prioritaire t''est rendu.'
      else 'Pas de ' || r.artist || ' dans Metalnini pour l''instant. Merci pour la demande.' end;
    perform public.send_push(r.user_id, case when p_outcome = 'added' then 'Demande exaucée' else 'Demande traitée' end, v_body, 'demande',
                             'https://pittilloni.github.io/metalnini/proto/', r.priority);
    n := n + 1;
  end loop;
  return n;
end $$;

-- message dans l'app : la demande payée et refusée annonce le remboursement
create or replace function public.my_request_news() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v jsonb;
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('artist', artist, 'outcome', outcome, 'priority', priority, 'paid', paid) order by handled_at), '[]'::jsonb) into v
    from public.artist_requests where user_id = auth.uid() and outcome is not null and not seen;
  update public.artist_requests set seen = true where user_id = auth.uid() and outcome is not null and not seen;
  return v;
end $$;
