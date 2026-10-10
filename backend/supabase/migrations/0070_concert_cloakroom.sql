-- Metalnini — ticket de vestiaire (2026-10-10) : la photo du ticket est envoyée dans le stockage privé « concerts » (dossier
-- du joueur), pour que les membres de sa bande pour ce concert puissent l'ouvrir s'il perd son téléphone. Visible par la bande
-- jusqu'à 3 jours après le concert.

alter table public.concerts add column if not exists cloak_path text;

-- lecture des fichiers de concert : en plus, le ticket de vestiaire d'un membre de ma bande
drop policy if exists "concerts: lecture" on storage.objects;
create policy "concerts: lecture" on storage.objects for select to authenticated
  using (bucket_id = 'concerts' and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.is_admin()
    or exists (select 1 from public.concerts c join public.follows f on f.friend_id = c.user_id
                where c.photo_path = name and c.photo_public and f.user_id = auth.uid())
    or exists (select 1 from public.concert_picks p join public.follows f on f.friend_id = p.user_id
                where p.proof_path = name and p.proof_public and not p.cancelled and f.user_id = auth.uid())
    or exists (select 1 from public.concerts c join public.concerts me on me.band_id = c.band_id
                where c.cloak_path = name and c.band_id is not null and me.user_id = auth.uid() and current_date <= c.played_on + 3)));

-- enregistrer (ou retirer, chemin nul) le ticket de vestiaire d'un de mes concerts ; le fichier doit être dans mon dossier
create or replace function public.concert_set_cloak(p_concert uuid, p_path text) returns void
language plpgsql volatile security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  if p_path is not null and split_part(p_path, '/', 1) <> auth.uid()::text then raise exception 'fichier hors de ton dossier'; end if;
  update public.concerts set cloak_path = p_path where id = p_concert and user_id = auth.uid();
  if not found then raise exception 'Ce concert n''est pas dans ta liste.'; end if;
end $$;
revoke execute on function public.concert_set_cloak(uuid, text) from public, anon;
grant execute on function public.concert_set_cloak(uuid, text) to authenticated;

-- bande : en plus, le ticket de vestiaire de chaque membre (jusqu'à 3 jours après le concert)
create or replace function public.band_state(p_band uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v jsonb;
begin
  if not exists (select 1 from public.concerts where band_id = p_band and user_id = auth.uid()) then raise exception 'pas dans cette bande'; end if;
  select jsonb_build_object('id', b.id, 'code', b.code, 'artist', b.artist, 'played_on', b.played_on, 'venue', b.venue, 'city', b.city,
    'members', coalesce((select jsonb_agg(jsonb_build_object('id', c.user_id, 'name', coalesce(pr.username, 'Sans pseudo'), 'me', c.user_id = auth.uid(), 'host', c.user_id = b.host_id,
        'cloak', case when c.cloak_path is not null and current_date <= b.played_on + 3 then c.cloak_path end,
        'done', coalesce((select jsonb_agg(ch.title order by p.done_at) from public.concert_picks p join public.concert_challenges ch on ch.id = p.challenge_id
                           where p.concert_id = c.id and p.done_at is not null and not p.cancelled), '[]'::jsonb)) order by c.created_at)
      from public.concerts c left join public.profiles pr on pr.id = c.user_id where c.band_id = b.id), '[]'::jsonb))
    into v from public.bands b where b.id = p_band;
  return v;
end $$;
