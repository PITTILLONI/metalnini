-- Metalnini — une carte comme photo de profil (2026-10-10) : le joueur peut prendre une de ses cartes comme photo de profil.
-- L'app en recadre le portrait et l'envoie comme une photo (rien ne change pour les potes, les danses, l'admin) ; avatar_card
-- retient la carte choisie. Une carte perso part du visage : elle est refusée tant que la photo de profil est une carte.

alter table public.profiles add column if not exists avatar_card text;

-- la carte choisie (« musicien|rareté », possédée), ou nul pour une vraie photo
create or replace function public.set_avatar_card(p_card text) returns void
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'non connecté'; end if;
  if p_card is not null and not exists (select 1 from public.inventory where user_id = v_user and musician_id = split_part(p_card, '|', 1)
                                          and rarity::text = split_part(p_card, '|', 2) and copies > 0) then
    raise exception 'Cette carte n''est pas dans ta collection.';
  end if;
  update public.profiles set avatar_card = p_card where id = v_user;
end $$;
revoke execute on function public.set_avatar_card(text) from public, anon;
grant execute on function public.set_avatar_card(text) to authenticated;

-- carte perso achetée : refusée si la photo de profil est une carte
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
    if (select avatar_card from public.profiles where id = v_user) is not null then raise exception 'ta photo de profil est une carte du jeu : mets une vraie photo de toi, ta carte part de ton visage'; end if;
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

-- cartes perso lancées par l'admin : les joueurs dont la photo de profil est une carte sont sautés
create or replace function public.admin_perso_create(p_users uuid[], p_nickname text default null, p_reason text default null) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare u record; n int := 0; skipped text[] := '{}'; v_order uuid;
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  if p_reason is null or length(trim(p_reason)) = 0 then raise exception 'motif obligatoire'; end if;
  for u in select p.id, p.username, p.avatar_path, p.avatar_card from public.profiles p where p.id = any(p_users) loop
    if u.avatar_path is null or u.avatar_card is not null or exists (select 1 from public.perso_orders o where o.user_id = u.id and o.status in ('paid', 'base', 'ready', 'error')) then
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
