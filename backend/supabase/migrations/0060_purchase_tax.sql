-- Metalnini — achat crédité même quand Stripe ajoute la TVA au prix (total payé ≥ prix de l'offre) ; le montant réellement payé
-- est gardé. Cas du 2026-10-06 : le prix « 1 paquet » n'était pas « TVA comprise », 1,49 € + 0,30 € de TVA = 1,79 €, achat refusé
-- (« montant inattendu ») puis crédité à la main ; le prix a été recréé TVA comprise.

create or replace function public.apply_purchase(p_id uuid, p_session text, p_cents int) returns text
language plpgsql volatile security definer set search_path = public as $$
declare p public.purchases; v_offer jsonb;
begin
  select * into p from public.purchases where id = p_id for update;
  if p.id is null then return 'inconnu'; end if;
  if p.status = 'paid' then return 'déjà crédité'; end if;
  v_offer := (select value -> p.offer from public.settings where key = 'shop');
  if p_cents is null or p_cents < (v_offer ->> 'cents')::int then return 'montant inattendu'; end if;
  update public.purchases set status = 'paid', paid_at = now(), amount_cents = p_cents, stripe_session = p_session where id = p_id;
  if p.offer = 'artist' then
    insert into public.artist_requests (user_id, artist, note, priority, paid) values (p.user_id, p.artist, p.note, true, true);
    perform public.send_push(p.user_id, 'Paiement reçu', p.artist || ' passe en tête de la liste du Grand Architecte. Tu seras prévenu à sa sortie.', 'achat',
                             'https://pittilloni.github.io/metalnini/proto/', true);
  else
    insert into public.profiles (id, bonus_points) values (p.user_id, 2 * (v_offer ->> 'packs')::int)
      on conflict (id) do update set bonus_points = public.profiles.bonus_points + 2 * (v_offer ->> 'packs')::int;
    perform public.send_push(p.user_id, 'Paiement reçu',
                             case when (v_offer ->> 'packs')::int > 1 then (v_offer ->> 'packs') || ' paquets t''attendent.' else 'Un paquet t''attend.' end,
                             'achat', 'https://pittilloni.github.io/metalnini/proto/', true);
  end if;
  return 'crédité';
end $$;
revoke execute on function public.apply_purchase(uuid, text, int) from public, anon, authenticated;
grant execute on function public.apply_purchase(uuid, text, int) to service_role;
