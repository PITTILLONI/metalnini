-- Metalnini — plus la bande est grande, plus le concert rapporte : +1 point de rang par membre en plus du joueur, jusqu'à +5.
-- La taille de la bande est figée sur le talon quand le joueur le valide (claim_concert) ; l'app compte les points à partir de band_size.

alter table public.concerts add column if not exists band_size int check (band_size is null or band_size >= 1);

create or replace function public.claim_concert(p_concert uuid) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_c record;
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  select * into v_c from public.concerts where id = p_concert and user_id = auth.uid() for update;
  if not found then raise exception 'concert introuvable'; end if;
  if v_c.played_on > current_date then raise exception 'Le concert n''a pas encore eu lieu.'; end if;
  if v_c.claimed then raise exception 'talon déjà validé'; end if;
  update public.concerts set claimed = true,
    band_size = case when v_c.band_id is null then null else (select count(*) from public.concerts where band_id = v_c.band_id) end
   where id = p_concert;
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

-- talons d'un pote : + taille de sa bande (pour compter son bonus de bande dans son rang)
drop function if exists public.friend_concerts(uuid);
create or replace function public.friend_concerts(p_friend uuid)
returns table (id uuid, artist text, musician_id text, played_on date, venue text, city text, photo_path text, band_size int, picks jsonb)
language plpgsql stable security definer set search_path = public as $$
begin
  if not exists (select 1 from public.follows where user_id = auth.uid() and friend_id = p_friend) then raise exception 'pas dans tes potes'; end if;
  return query select c.id, c.artist, c.musician_id, c.played_on, c.venue, c.city, case when c.photo_public then c.photo_path end, c.band_size,
    coalesce((select jsonb_agg(jsonb_build_object('title', ch.title, 'points', ch.points + case when p.picked_early then 1 else 0 end + case when p.band_bonus then 2 else 0 end,
                'band', p.band_bonus, 'proof_path', case when p.proof_public then p.proof_path end, 'proof_kind', p.proof_kind))
                from public.concert_picks p join public.concert_challenges ch on ch.id = p.challenge_id
               where p.concert_id = c.id and p.done_at is not null and not p.cancelled), '[]'::jsonb)
    from public.concerts c where c.user_id = p_friend order by c.played_on desc;
end $$;

revoke execute on function public.claim_concert(uuid) from public, anon;
revoke execute on function public.friend_concerts(uuid) from public, anon;
grant execute on function public.claim_concert(uuid) to authenticated;
grant execute on function public.friend_concerts(uuid) to authenticated;
