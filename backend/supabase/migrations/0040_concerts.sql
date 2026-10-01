-- Metalnini — concerts (« J'y étais ») : le joueur enregistre un concert vu (artiste, date, salle, ville) et une photo souvenir.
-- Le billet d'origine reste sur le téléphone (nom et code-barres) : la base ne garde que ces infos et la photo.
-- Un talon par concert sur le profil ; la photo n'est visible des potes que si le joueur l'a choisi. Récompenses : lot suivant.

create table if not exists public.concerts (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  artist       text not null check (char_length(btrim(artist)) between 2 and 80),
  musician_id  text references public.musicians (id) on delete set null,
  played_on    date not null,
  venue        text check (venue is null or char_length(venue) <= 80),
  city         text check (city is null or char_length(city) <= 60),
  photo_path   text,
  photo_public boolean not null default false,
  created_at   timestamptz not null default now()
);
-- un seul concert par artiste et par jour
create unique index if not exists concerts_once on public.concerts (user_id, lower(btrim(artist)), played_on);
create index if not exists concerts_user on public.concerts (user_id, played_on desc);
alter table public.concerts enable row level security;   -- écritures par les fonctions ci-dessous
drop policy if exists "concerts: les siens et l'admin" on public.concerts;
create policy "concerts: les siens et l'admin" on public.concerts for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

insert into public.settings (key, value) values ('concerts_per_month', '8'::jsonb) on conflict (key) do nothing;

-- photos souvenir : dossier du joueur ; lecture par le joueur, par l'admin, et par ses potes si la photo est rendue visible
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('concerts', 'concerts', false, 2097152, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "concerts: lecture" on storage.objects;
create policy "concerts: lecture" on storage.objects for select to authenticated
  using (bucket_id = 'concerts' and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.is_admin()
    or exists (select 1 from public.concerts c join public.follows f on f.friend_id = c.user_id
                where c.photo_path = name and c.photo_public and f.user_id = auth.uid())));
drop policy if exists "concerts: dépôt dans son dossier" on storage.objects;
create policy "concerts: dépôt dans son dossier" on storage.objects for insert to authenticated
  with check (bucket_id = 'concerts' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "concerts: suppression dans son dossier" on storage.objects;
create policy "concerts: suppression dans son dossier" on storage.objects for delete to authenticated
  using (bucket_id = 'concerts' and (storage.foldername(name))[1] = auth.uid()::text);

-- enregistre un concert ; plafond mensuel (réglage concerts_per_month), date entre 1960 et un an devant
create or replace function public.add_concert(p_artist text, p_musician text, p_date date, p_venue text, p_city text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_cap int;
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  if p_date is null or p_date < date '1960-01-01' or p_date > current_date + 365 then raise exception 'date invalide'; end if;
  if p_musician is not null and not exists (select 1 from public.musicians where id = p_musician) then raise exception 'musicien inconnu'; end if;
  select coalesce((select value::int from public.settings where key = 'concerts_per_month'), 8) into v_cap;
  if (select count(*) from public.concerts where user_id = auth.uid() and created_at >= date_trunc('month', now())) >= v_cap then
    raise exception 'Déjà % concerts ce mois-ci : reviens le mois prochain.', v_cap;
  end if;
  begin
    insert into public.concerts (user_id, artist, musician_id, played_on, venue, city)
    values (auth.uid(), btrim(p_artist), p_musician, p_date, nullif(btrim(p_venue), ''), nullif(btrim(p_city), ''))
    returning id into v_id;
  exception when unique_violation then raise exception 'Ce concert est déjà dans ta liste.';
  end;
  return v_id;
end $$;

-- photo souvenir d'un de ses concerts (null pour l'enlever) et sa visibilité pour les potes
create or replace function public.set_concert_photo(p_id uuid, p_path text, p_public boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  if p_path is not null and split_part(p_path, '/', 1) <> auth.uid()::text then raise exception 'chemin invalide'; end if;
  update public.concerts set photo_path = p_path, photo_public = coalesce(p_public, false) where id = p_id and user_id = auth.uid();
  if not found then raise exception 'concert introuvable'; end if;
end $$;

create or replace function public.delete_concert(p_id uuid)
returns text language plpgsql security definer set search_path = public as $$
declare v_path text;
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  delete from public.concerts where id = p_id and user_id = auth.uid() returning photo_path into v_path;
  if not found then raise exception 'concert introuvable'; end if;
  return v_path;   -- le client efface la photo de son dossier
end $$;

-- talons d'un pote suivi (photo seulement si rendue visible)
create or replace function public.friend_concerts(p_friend uuid)
returns table (artist text, musician_id text, played_on date, venue text, city text, photo_path text)
language plpgsql stable security definer set search_path = public as $$
begin
  if not exists (select 1 from public.follows where user_id = auth.uid() and friend_id = p_friend) then raise exception 'pas dans tes potes'; end if;
  return query select c.artist, c.musician_id, c.played_on, c.venue, c.city, case when c.photo_public then c.photo_path end
                 from public.concerts c where c.user_id = p_friend order by c.played_on desc;
end $$;

revoke execute on function public.add_concert(text, text, date, text, text) from public, anon;
revoke execute on function public.set_concert_photo(uuid, text, boolean) from public, anon;
revoke execute on function public.delete_concert(uuid) from public, anon;
revoke execute on function public.friend_concerts(uuid) from public, anon;
grant execute on function public.add_concert(text, text, date, text, text) to authenticated;
grant execute on function public.set_concert_photo(uuid, text, boolean) to authenticated;
grant execute on function public.delete_concert(uuid) to authenticated;
grant execute on function public.friend_concerts(uuid) to authenticated;
