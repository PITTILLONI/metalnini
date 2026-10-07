-- Metalnini — cartes « Perso » : des cartes faites pour un joueur (un collègue, un pote), offertes par l'admin, jamais dans les
-- paquets. L'image n'est pas dans le dépôt public : elle est dans le stockage privé « perso » (dossier = identifiant de la carte),
-- lisible seulement par qui possède la carte (et par l'admin). Le classeur « Perso » n'apparaît que chez qui en a une.

alter table public.musicians add column if not exists perso boolean not null default false;

insert into storage.buckets (id, name, public) values ('perso', 'perso', false) on conflict (id) do nothing;
drop policy if exists perso_read on storage.objects;
create policy perso_read on storage.objects for select to authenticated using (
  bucket_id = 'perso' and (public.is_admin_account()
    or exists (select 1 from public.inventory i where i.user_id = auth.uid() and i.musician_id = (storage.foldername(name))[1] and i.copies > 0)));

-- première carte perso : Fabich' (Fabien), Légendaire, pour voortexxx
insert into public.musicians (id, name, band, arcana_title, arcana_number, instruments, subgenre, active, perso)
values ('fabich', 'Fabich''', 'Fabien', 'Fabich''', 'XIII', array['guitare']::text[], 'Black metal', false, true)
on conflict (id) do update set perso = true, active = false;
insert into public.cards (musician_id, rarity, image_path) values ('fabich', 'legendaire', 'fabich/legendaire.jpg') on conflict do nothing;

-- mes cartes perso : la fiche et le chemin de l'image (le lien signé est demandé par l'app au stockage)
create or replace function public.my_perso_cards() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', m.id, 'who', m.name, 'band', m.band, 'title', m.arcana_title, 'num', m.arcana_number,
           'genre', m.subgenre, 'cards', (select jsonb_agg(jsonb_build_object('r', c.rarity, 'path', c.image_path)) from public.cards c where c.musician_id = m.id))), '[]'::jsonb)
    from public.musicians m
   where m.perso and exists (select 1 from public.inventory i where i.user_id = auth.uid() and i.musician_id = m.id and i.copies > 0)
$$;
revoke execute on function public.my_perso_cards() from public, anon;
grant execute on function public.my_perso_cards() to authenticated;
