-- Metalnini — souvenirs de concert partagés (2026-10-10) : quand un joueur ajoute un souvenir visible par ses potes (photo
-- souvenir publique ou preuve de défi publique), ses potes sont prévenus (« X a ajouté un souvenir du concert de … »), dans la
-- limite quotidienne de notifications ; au plus une notification par concert toutes les 6 heures. Le lien ouvre son profil.

create table if not exists public.souvenir_pushes (
  concert_id uuid primary key references public.concerts (id) on delete cascade,
  last_at    timestamptz not null default now()
);
alter table public.souvenir_pushes enable row level security;

create or replace function public.souvenir_spread(p_concert uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
declare c record; f record; v_name text;
begin
  select * into c from public.concerts where id = p_concert;
  if not found then return; end if;
  if exists (select 1 from public.souvenir_pushes where concert_id = p_concert and last_at > now() - interval '6 hours') then return; end if;
  insert into public.souvenir_pushes (concert_id, last_at) values (p_concert, now()) on conflict (concert_id) do update set last_at = now();
  v_name := coalesce((select username from public.profiles where id = c.user_id), 'Un pote');
  for f in select distinct user_id from public.follows where friend_id = c.user_id and user_id <> c.user_id loop
    perform public.send_push(f.user_id, 'Nouveau souvenir', v_name || ' a ajouté un souvenir du concert de ' || c.artist || '.', 'souvenir',
      'https://pittilloni.github.io/metalnini/proto/?profil=' || c.user_id);
  end loop;
end $$;
revoke execute on function public.souvenir_spread(uuid) from public, anon, authenticated;

-- photo souvenir publique ajoutée ou changée
create or replace function public.souvenir_on_concert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.photo_path is not null and new.photo_public and (old.photo_path is distinct from new.photo_path or not old.photo_public) then
    perform public.souvenir_spread(new.id);
  end if;
  return new;
end $$;
drop trigger if exists souvenir_on_concert on public.concerts;
create trigger souvenir_on_concert after update of photo_path, photo_public on public.concerts for each row execute function public.souvenir_on_concert();

-- preuve de défi publique déposée
create or replace function public.souvenir_on_pick() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.proof_path is not null and new.proof_public and not new.cancelled and (old.proof_path is distinct from new.proof_path or not old.proof_public) then
    perform public.souvenir_spread(new.concert_id);
  end if;
  return new;
end $$;
drop trigger if exists souvenir_on_pick on public.concert_picks;
create trigger souvenir_on_pick after update of proof_path, proof_public on public.concert_picks for each row execute function public.souvenir_on_pick();
