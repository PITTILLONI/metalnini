-- Metalnini — billet de concert (2026-10-10) : le joueur peut garder son billet (PDF ou photo) dans l'app, pour le retrouver à
-- l'entrée. Le fichier va dans son dossier du stockage privé « concerts » ; lui seul peut l'ouvrir (ni ses potes, ni sa bande,
-- ni l'admin : un billet porte un nom et un code-barres). Avant, le billet était lu sur le téléphone puis oublié : c'est
-- désormais un choix du joueur, à l'import ou depuis la fiche du concert.

alter table public.concerts add column if not exists ticket_path text;
alter table public.concerts add column if not exists ticket_kind text check (ticket_kind in ('pdf', 'photo'));

-- les billets PDF s'ajoutent aux formats acceptés
update storage.buckets set allowed_mime_types = array['image/jpeg','image/png','image/webp','video/mp4','video/quicktime','video/webm','application/pdf']
  where id = 'concerts';

-- lecture : l'admin ne lit plus les billets (fichiers « ticket-… ») ; le reste ne change pas
drop policy if exists "concerts: lecture" on storage.objects;
create policy "concerts: lecture" on storage.objects for select to authenticated
  using (bucket_id = 'concerts' and (
    (storage.foldername(name))[1] = auth.uid()::text
    or (public.is_admin() and storage.filename(name) not like 'ticket-%')
    or exists (select 1 from public.concerts c join public.follows f on f.friend_id = c.user_id
                where c.photo_path = name and c.photo_public and f.user_id = auth.uid())
    or exists (select 1 from public.concert_picks p join public.follows f on f.friend_id = p.user_id
                where p.proof_path = name and p.proof_public and not p.cancelled and f.user_id = auth.uid())
    or exists (select 1 from public.concerts c join public.concerts me on me.band_id = c.band_id
                where c.cloak_path = name and c.band_id is not null and me.user_id = auth.uid() and current_date <= c.played_on + 3)));

-- enregistrer (ou retirer, chemin nul) le billet d'un de mes concerts ; le fichier doit être un « ticket-… » de mon dossier
create or replace function public.concert_set_ticket(p_concert uuid, p_path text, p_kind text) returns void
language plpgsql volatile security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  if p_path is not null and (split_part(p_path, '/', 1) <> auth.uid()::text or split_part(p_path, '/', 2) not like 'ticket-%') then
    raise exception 'fichier hors de ton dossier'; end if;
  if p_path is not null and p_kind not in ('pdf', 'photo') then raise exception 'format de billet inconnu'; end if;
  update public.concerts set ticket_path = p_path, ticket_kind = case when p_path is null then null else p_kind end
    where id = p_concert and user_id = auth.uid();
  if not found then raise exception 'Ce concert n''est pas dans ta liste.'; end if;
end $$;
revoke execute on function public.concert_set_ticket(uuid, text, text) from public, anon;
grant execute on function public.concert_set_ticket(uuid, text, text) to authenticated;
