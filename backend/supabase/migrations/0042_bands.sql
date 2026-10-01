-- Metalnini — bandes de concert : des joueurs qui vont au même concert partagent le talon et les défis « en bande ».
-- Une bande naît d'un concert (code de 6 caractères, lien ?bande=CODE) ; ses potes y sont invités d'un toucher (notification),
-- n'importe qui la rejoint par le code : il reçoit le même talon. Chacun envoie sa preuve ; quand tous les membres (2 au moins)
-- ont relevé le même défi, chacun touche le bonus de bande (2 points de rang). Après le concert, les membres deviennent potes.

create table if not exists public.bands (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,
  host_id     uuid not null references auth.users (id) on delete cascade,
  artist      text not null,
  musician_id text references public.musicians (id) on delete set null,
  played_on   date not null,
  venue       text,
  city        text,
  created_at  timestamptz not null default now()
);
alter table public.bands enable row level security;   -- lu et écrit par les fonctions ci-dessous

create table if not exists public.band_invites (
  band_id    uuid not null references public.bands (id) on delete cascade,
  user_id    uuid not null references auth.users (id) on delete cascade,
  from_id    uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (band_id, user_id)
);
alter table public.band_invites enable row level security;

alter table public.concerts add column if not exists band_id uuid references public.bands (id) on delete set null;
create index if not exists concerts_band on public.concerts (band_id) where band_id is not null;
alter table public.concert_picks add column if not exists band_bonus boolean not null default false;

-- bonus de bande d'un défi : posé quand tous les membres (2 au moins) l'ont relevé sans annulation, retiré sinon
create or replace function public.band_recheck(p_band uuid, p_challenge uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
declare v_n int; v_done int;
begin
  select count(*) into v_n from public.concerts where band_id = p_band;
  select count(*) into v_done from public.concerts c join public.concert_picks p on p.concert_id = c.id
   where c.band_id = p_band and p.challenge_id = p_challenge and p.done_at is not null and not p.cancelled;
  update public.concert_picks p set band_bonus = (v_n >= 2 and v_done = v_n)
    from public.concerts c where c.id = p.concert_id and c.band_id = p_band and p.challenge_id = p_challenge;
end $$;
revoke execute on function public.band_recheck(uuid, uuid) from public, anon, authenticated;

-- état d'une bande pour un de ses membres : code, concert, membres et défis qu'ils ont relevés
create or replace function public.band_state(p_band uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v jsonb;
begin
  if not exists (select 1 from public.concerts where band_id = p_band and user_id = auth.uid()) then raise exception 'pas dans cette bande'; end if;
  select jsonb_build_object('id', b.id, 'code', b.code, 'artist', b.artist, 'played_on', b.played_on, 'venue', b.venue, 'city', b.city,
    'members', coalesce((select jsonb_agg(jsonb_build_object('id', c.user_id, 'name', coalesce(pr.username, 'Sans pseudo'), 'me', c.user_id = auth.uid(), 'host', c.user_id = b.host_id,
        'done', coalesce((select jsonb_agg(ch.title order by p.done_at) from public.concert_picks p join public.concert_challenges ch on ch.id = p.challenge_id
                           where p.concert_id = c.id and p.done_at is not null and not p.cancelled), '[]'::jsonb)) order by c.created_at)
      from public.concerts c left join public.profiles pr on pr.id = c.user_id where c.band_id = b.id), '[]'::jsonb))
    into v from public.bands b where b.id = p_band;
  return v;
end $$;

-- monter une bande à partir d'un de ses concerts (ou retrouver celle qui existe)
create or replace function public.band_create(p_concert uuid) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_c record; v_code text; v_id uuid; v_abc text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; i int;
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  select * into v_c from public.concerts where id = p_concert and user_id = auth.uid() for update;
  if not found then raise exception 'concert introuvable'; end if;
  if v_c.band_id is not null then return public.band_state(v_c.band_id); end if;
  loop
    v_code := '';
    for i in 1..6 loop v_code := v_code || substr(v_abc, 1 + floor(random() * length(v_abc))::int, 1); end loop;
    begin
      insert into public.bands (code, host_id, artist, musician_id, played_on, venue, city)
      values (v_code, auth.uid(), v_c.artist, v_c.musician_id, v_c.played_on, v_c.venue, v_c.city) returning id into v_id;
      exit;
    exception when unique_violation then end;
  end loop;
  update public.concerts set band_id = v_id where id = p_concert;
  return public.band_state(v_id);
end $$;

-- rejoindre une bande par son code : le même talon est créé (ou le sien, s'il a déjà noté ce concert, y est rattaché)
create or replace function public.band_join(p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_b record; v_c record; v_cap int; v_name text := (select username from public.profiles where id = auth.uid());
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  select * into v_b from public.bands where code = upper(btrim(p_code));
  if not found then raise exception 'Bande introuvable : vérifie le code.'; end if;
  if v_b.played_on < current_date - 2 then raise exception 'Trop tard : ce concert est passé depuis plus de 2 jours.'; end if;
  select * into v_c from public.concerts where user_id = auth.uid() and lower(btrim(artist)) = lower(btrim(v_b.artist)) and played_on = v_b.played_on for update;
  if found then
    if v_c.band_id = v_b.id then return public.band_state(v_b.id); end if;
    if v_c.band_id is not null then raise exception 'Tu es déjà dans une autre bande pour ce concert.'; end if;
    update public.concerts set band_id = v_b.id where id = v_c.id;
  else
    select coalesce((select value::int from public.settings where key = 'concerts_per_month'), 8) into v_cap;
    if (select count(*) from public.concerts where user_id = auth.uid() and created_at >= date_trunc('month', now())) >= v_cap then
      raise exception 'Déjà % concerts ce mois-ci : reviens le mois prochain.', v_cap;
    end if;
    insert into public.concerts (user_id, artist, musician_id, played_on, venue, city, band_id)
    values (auth.uid(), v_b.artist, v_b.musician_id, v_b.played_on, v_b.venue, v_b.city, v_b.id);
  end if;
  delete from public.band_invites where band_id = v_b.id and user_id = auth.uid();
  perform public.send_push(v_b.host_id, 'Ta bande grandit', coalesce(v_name, 'Un fan') || ' rejoint ta bande pour ' || v_b.artist || '.', 'bande',
                           'https://pittilloni.github.io/metalnini/proto/');
  return public.band_state(v_b.id);
end $$;

-- inviter un pote dans sa bande : notification et invitation en attente
create or replace function public.band_invite(p_band uuid, p_friend uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
declare v_b record; v_name text := (select username from public.profiles where id = auth.uid());
begin
  if not exists (select 1 from public.concerts where band_id = p_band and user_id = auth.uid()) then raise exception 'pas dans cette bande'; end if;
  if not exists (select 1 from public.follows where user_id = auth.uid() and friend_id = p_friend) then raise exception 'pas dans tes potes'; end if;
  if exists (select 1 from public.concerts where band_id = p_band and user_id = p_friend) then raise exception 'déjà dans la bande'; end if;
  select * into v_b from public.bands where id = p_band;
  insert into public.band_invites (band_id, user_id, from_id) values (p_band, p_friend, auth.uid()) on conflict (band_id, user_id) do update set from_id = excluded.from_id, created_at = now();
  perform public.send_push(p_friend, 'Invitation dans une bande', coalesce(v_name, 'Un pote') || ' t''invite dans sa bande pour ' || v_b.artist || ' le ' || to_char(v_b.played_on, 'DD/MM') || '.', 'bande',
                           'https://pittilloni.github.io/metalnini/proto/?bande=' || v_b.code);
end $$;

create or replace function public.my_band_invites()
returns table (code text, artist text, played_on date, from_name text)
language sql stable security definer set search_path = public as $$
  select b.code, b.artist, b.played_on, coalesce(p.username, 'Un pote') from public.band_invites i
    join public.bands b on b.id = i.band_id left join public.profiles p on p.id = i.from_id
   where i.user_id = auth.uid() and b.played_on >= current_date - 2
     and not exists (select 1 from public.concerts c where c.band_id = b.id and c.user_id = auth.uid())
   order by i.created_at desc;
$$;

create or replace function public.band_leave(p_concert uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  update public.concerts set band_id = null where id = p_concert and user_id = auth.uid() and band_id is not null;
  if not found then raise exception 'pas de bande pour ce concert'; end if;
  update public.concert_picks set band_bonus = false where concert_id = p_concert;
end $$;

-- défis : ceux « en bande » demandent une bande d'au moins 2 membres
create or replace function public.pick_challenge(p_concert uuid, p_challenge uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_c record; v_max int; v_band boolean;
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  select * into v_c from public.concerts where id = p_concert and user_id = auth.uid();
  if not found then raise exception 'concert introuvable'; end if;
  if current_date > v_c.played_on + 2 then raise exception 'Trop tard : les défis se choisissent jusqu''à 2 jours après le concert.'; end if;
  select band_only into v_band from public.concert_challenges where id = p_challenge and active;
  if v_band is null then raise exception 'défi indisponible'; end if;
  if v_band and (v_c.band_id is null or (select count(*) from public.concerts where band_id = v_c.band_id) < 2) then
    raise exception 'Défi en bande : il faut au moins un autre membre dans ta bande.';
  end if;
  select coalesce((select value::int from public.settings where key = 'concert_challenges_max'), 3) into v_max;
  if (select count(*) from public.concert_picks where concert_id = p_concert) >= v_max then raise exception 'Déjà % défis pour ce concert.', v_max; end if;
  insert into public.concert_picks (concert_id, challenge_id, user_id, picked_early)
  values (p_concert, p_challenge, auth.uid(), current_date < v_c.played_on) on conflict do nothing;
end $$;

-- preuve : + bonus de bande quand le dernier membre relève le défi ; renvoie les points gagnés par le joueur
create or replace function public.complete_challenge(p_concert uuid, p_challenge uuid, p_path text, p_kind text, p_public boolean)
returns int language plpgsql security definer set search_path = public as $$
declare v_c record; v_pick record; v_points int;
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  if p_path is null or split_part(p_path, '/', 1) <> auth.uid()::text then raise exception 'chemin invalide'; end if;
  select * into v_c from public.concerts where id = p_concert and user_id = auth.uid();
  if not found then raise exception 'concert introuvable'; end if;
  if current_date < v_c.played_on then raise exception 'Patience : la preuve s''envoie le jour du concert.'; end if;
  if current_date > v_c.played_on + 2 then raise exception 'Trop tard : la preuve s''envoie dans les 2 jours qui suivent le concert.'; end if;
  select * into v_pick from public.concert_picks where concert_id = p_concert and challenge_id = p_challenge and user_id = auth.uid() for update;
  if not found then raise exception 'choisis d''abord ce défi'; end if;
  if v_pick.done_at is not null then raise exception 'défi déjà relevé'; end if;
  if p_kind is distinct from (select proof from public.concert_challenges where id = p_challenge) then raise exception 'mauvais type de preuve'; end if;
  update public.concert_picks set proof_path = p_path, proof_kind = p_kind, proof_public = coalesce(p_public, false), done_at = now()
   where concert_id = p_concert and challenge_id = p_challenge;
  if v_c.band_id is not null then perform public.band_recheck(v_c.band_id, p_challenge); end if;
  select ch.points + case when v_pick.picked_early then 1 else 0 end + case when p.band_bonus then 2 else 0 end into v_points
    from public.concert_challenges ch join public.concert_picks p on p.challenge_id = ch.id and p.concert_id = p_concert where ch.id = p_challenge;
  return v_points;
end $$;

create or replace function public.admin_cancel_challenge(p_concert uuid, p_challenge uuid, p_cancel boolean) returns void
language plpgsql security definer set search_path = public as $$
declare v_band uuid;
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  update public.concert_picks set cancelled = p_cancel where concert_id = p_concert and challenge_id = p_challenge and done_at is not null;
  if not found then raise exception 'preuve introuvable'; end if;
  select band_id into v_band from public.concerts where id = p_concert;
  if v_band is not null then perform public.band_recheck(v_band, p_challenge); end if;
end $$;

-- talon validé : en plus, les membres de sa bande deviennent ses potes (dans les deux sens)
create or replace function public.claim_concert(p_concert uuid) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_c record;
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  select * into v_c from public.concerts where id = p_concert and user_id = auth.uid() for update;
  if not found then raise exception 'concert introuvable'; end if;
  if v_c.played_on > current_date then raise exception 'Le concert n''a pas encore eu lieu.'; end if;
  if v_c.claimed then raise exception 'talon déjà validé'; end if;
  update public.concerts set claimed = true where id = p_concert;
  if v_c.band_id is not null then
    insert into public.follows (user_id, friend_id) select auth.uid(), c.user_id from public.concerts c where c.band_id = v_c.band_id and c.user_id <> auth.uid() on conflict do nothing;
    insert into public.follows (user_id, friend_id) select c.user_id, auth.uid() from public.concerts c where c.band_id = v_c.band_id and c.user_id <> auth.uid() on conflict do nothing;
  end if;
  if v_c.musician_id is not null and exists (select 1 from public.musicians where id = v_c.musician_id and active)
     and not exists (select 1 from public.concert_bonuses where user_id = auth.uid() and musician_id = v_c.musician_id) then
    insert into public.concert_bonuses (user_id, musician_id, concert_id) values (auth.uid(), v_c.musician_id, p_concert);
    return public.give_card(auth.uid(), v_c.musician_id, 'rare');
  end if;
  return null;
end $$;

-- talons d'un pote : points des défis avec le bonus de bande
create or replace function public.friend_concerts(p_friend uuid)
returns table (id uuid, artist text, musician_id text, played_on date, venue text, city text, photo_path text, picks jsonb)
language plpgsql stable security definer set search_path = public as $$
begin
  if not exists (select 1 from public.follows where user_id = auth.uid() and friend_id = p_friend) then raise exception 'pas dans tes potes'; end if;
  return query select c.id, c.artist, c.musician_id, c.played_on, c.venue, c.city, case when c.photo_public then c.photo_path end,
    coalesce((select jsonb_agg(jsonb_build_object('title', ch.title, 'points', ch.points + case when p.picked_early then 1 else 0 end + case when p.band_bonus then 2 else 0 end,
                'band', p.band_bonus, 'proof_path', case when p.proof_public then p.proof_path end, 'proof_kind', p.proof_kind))
                from public.concert_picks p join public.concert_challenges ch on ch.id = p.challenge_id
               where p.concert_id = c.id and p.done_at is not null and not p.cancelled), '[]'::jsonb)
    from public.concerts c where c.user_id = p_friend order by c.played_on desc;
end $$;

-- un premier défi « en bande », seulement s'il n'y en a aucun
insert into public.concert_challenges (title, hint, proof, points, band_only, sort)
select 'Photo de bande', 'Toute la bande sur la même photo, au premier rang ou dans le pit.', 'photo', 3, true, 6
where not exists (select 1 from public.concert_challenges where band_only);

revoke execute on function public.band_state(uuid) from public, anon;
revoke execute on function public.band_create(uuid) from public, anon;
revoke execute on function public.band_join(text) from public, anon;
revoke execute on function public.band_invite(uuid, uuid) from public, anon;
revoke execute on function public.my_band_invites() from public, anon;
revoke execute on function public.band_leave(uuid) from public, anon;
revoke execute on function public.pick_challenge(uuid, uuid) from public, anon;
revoke execute on function public.complete_challenge(uuid, uuid, text, text, boolean) from public, anon;
revoke execute on function public.admin_cancel_challenge(uuid, uuid, boolean) from public, anon;
revoke execute on function public.claim_concert(uuid) from public, anon;
revoke execute on function public.friend_concerts(uuid) from public, anon;
grant execute on function public.band_state(uuid) to authenticated;
grant execute on function public.band_create(uuid) to authenticated;
grant execute on function public.band_join(text) to authenticated;
grant execute on function public.band_invite(uuid, uuid) to authenticated;
grant execute on function public.my_band_invites() to authenticated;
grant execute on function public.band_leave(uuid) to authenticated;
grant execute on function public.pick_challenge(uuid, uuid) to authenticated;
grant execute on function public.complete_challenge(uuid, uuid, text, text, boolean) to authenticated;
grant execute on function public.admin_cancel_challenge(uuid, uuid, boolean) to authenticated;
grant execute on function public.claim_concert(uuid) to authenticated;
grant execute on function public.friend_concerts(uuid) to authenticated;
