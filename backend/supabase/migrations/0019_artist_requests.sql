-- Metalnini — demandes d'artistes : un joueur propose un musicien ou un groupe, l'admin les voit regroupées dans le catalogue.

create table if not exists public.artist_requests (
  id         bigserial primary key,
  user_id    uuid not null references auth.users (id) on delete cascade,
  artist     text not null check (length(artist) between 2 and 80),
  note       text check (note is null or length(note) <= 200),
  done       boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists artist_requests_user_day on public.artist_requests (user_id, created_at);
alter table public.artist_requests enable row level security;
-- lecture et suivi (« traitée ») réservés à l'admin ; les joueurs passent par request_artist
create policy artist_requests_admin on public.artist_requests for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- le joueur connecté propose un artiste (5 demandes par jour au plus)
create or replace function public.request_artist(p_artist text, p_note text) returns void
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_artist text := trim(coalesce(p_artist, '')); v_note text := nullif(trim(coalesce(p_note, '')), '');
begin
  if v_user is null then raise exception 'non connecté'; end if;
  if length(v_artist) < 2 or length(v_artist) > 80 then raise exception 'nom d''artiste : 2 à 80 caractères'; end if;
  if v_note is not null and length(v_note) > 200 then raise exception 'message : 200 caractères au plus'; end if;
  if (select count(*) from public.artist_requests where user_id = v_user and created_at >= public.paris_day_start()) >= 5 then
    raise exception 'cinq demandes par jour, pas plus : reviens demain';
  end if;
  insert into public.artist_requests (user_id, artist, note) values (v_user, v_artist, v_note);
end $$;
revoke execute on function public.request_artist(text, text) from public, anon;
grant execute on function public.request_artist(text, text) to authenticated;
