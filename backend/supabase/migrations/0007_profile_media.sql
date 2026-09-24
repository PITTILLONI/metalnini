-- Metalnini — photo de profil et cri enregistré (cosmétique, sans effet de jeu).
-- Fichiers privés : chaque joueur n'écrit que dans son dossier <id>/, les joueurs connectés peuvent les lire.

alter table public.profiles add column if not exists avatar_path text;
alter table public.profiles add column if not exists cry_path text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('avatars', 'avatars', false, 524288,  array['image/jpeg','image/png','image/webp']),
  ('cries',   'cries',   false, 1048576, array['audio/webm','audio/mp4','audio/mpeg','audio/ogg','audio/wav','audio/x-m4a'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "media: lecture joueurs" on storage.objects;
create policy "media: lecture joueurs" on storage.objects for select to authenticated
  using (bucket_id in ('avatars', 'cries'));
drop policy if exists "media: dépôt dans son dossier" on storage.objects;
create policy "media: dépôt dans son dossier" on storage.objects for insert to authenticated
  with check (bucket_id in ('avatars', 'cries') and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "media: remplacement dans son dossier" on storage.objects;
create policy "media: remplacement dans son dossier" on storage.objects for update to authenticated
  using (bucket_id in ('avatars', 'cries') and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id in ('avatars', 'cries') and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "media: suppression dans son dossier" on storage.objects;
create policy "media: suppression dans son dossier" on storage.objects for delete to authenticated
  using (bucket_id in ('avatars', 'cries') and (storage.foldername(name))[1] = auth.uid()::text);

-- enregistre (ou efface avec null) le chemin de sa photo ou de son cri ; le chemin doit être dans son dossier
create or replace function public.set_profile_media(p_kind text, p_path text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  if p_path is not null and split_part(p_path, '/', 1) <> auth.uid()::text then raise exception 'chemin invalide'; end if;
  insert into public.profiles (id) values (auth.uid()) on conflict (id) do nothing;
  if p_kind = 'avatar' then update public.profiles set avatar_path = p_path where id = auth.uid();
  elsif p_kind = 'cry' then update public.profiles set cry_path = p_path where id = auth.uid();
  else raise exception 'type inconnu'; end if;
end $$;
revoke execute on function public.set_profile_media(text, text) from public, anon;
grant execute on function public.set_profile_media(text, text) to authenticated;
