-- Metalnini — récompenses d'objectifs variées : chaque objectif tire sa récompense dans une table pondérée (réglage objective_loot) :
--   pack    1 paquet au choix (2 points de paquet)
--   card    1 carte : Rare minimum (cotes du cadeau du cri) ou Commune d'un musicien pas encore trouvé (new_commune)
--   ticket  1 ticket « artiste prioritaire » : la prochaine demande d'artiste remonte en tête dans l'admin
-- Le cri enregistré devient un objectif comme les autres (sa carte cadeau se récupère dans Metal Corner).

alter table public.profiles add column if not exists priority_tickets int not null default 0 check (priority_tickets >= 0);
alter table public.artist_requests add column if not exists priority boolean not null default false;

insert into public.settings (key, value) values ('objective_loot', '{
  "binder":  [{"w":50,"kind":"pack"}, {"w":30,"kind":"card"}, {"w":20,"kind":"ticket"}],
  "mastery": [{"w":50,"kind":"card"}, {"w":30,"kind":"pack"}, {"w":20,"kind":"ticket"}],
  "cry":     [{"w":100,"kind":"card"}],
  "small":   [{"w":70,"kind":"new_commune"}, {"w":15,"kind":"pack"}, {"w":15,"kind":"ticket"}]
}') on conflict (key) do nothing;

-- le cri devient une clé d'objectif ; ceux qui ont déjà eu la carte cadeau du cri l'ont récupérée
alter table public.objective_claims drop constraint if exists objective_claims_key_check;
alter table public.objective_claims add constraint objective_claims_key_check check (key ~ '^(binder|mastery):[a-z0-9-]+$' or key in ('avatar', 'share', 'cry'));
insert into public.objective_claims (user_id, key, reward)
  select id, 'cry', '{"kind":"card","legacy":true}' from public.profiles where cry_gift_claimed on conflict do nothing;

-- une récompense tirée dans la table du type d'objectif
create or replace function public.objective_reward(p_user uuid, p_table text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_rows jsonb := (select value -> p_table from public.settings where key = 'objective_loot'); v_total numeric; v_x numeric; v_kind text; e jsonb;
        v_odds jsonb; v_r public.rarity := 'rare'; r public.rarity; v_m text;
begin
  select sum((x ->> 'w')::numeric) into v_total from jsonb_array_elements(v_rows) x;
  v_x := random() * coalesce(v_total, 0);
  for e in select * from jsonb_array_elements(v_rows) loop
    v_kind := e ->> 'kind';
    exit when v_x < (e ->> 'w')::numeric;
    v_x := v_x - (e ->> 'w')::numeric;
  end loop;
  if v_kind = 'pack' then
    update public.profiles set bonus_points = bonus_points + 2 where id = p_user;
    return jsonb_build_object('kind', 'points', 'points', 2);
  elsif v_kind = 'ticket' then
    update public.profiles set priority_tickets = priority_tickets + 1 where id = p_user;
    return jsonb_build_object('kind', 'ticket');
  elsif v_kind = 'new_commune' then
    select m.id into v_m from public.musicians m
     where m.active and not exists (select 1 from public.inventory i where i.user_id = p_user and i.musician_id = m.id) order by random() limit 1;
    if v_m is null then select m.id into v_m from public.musicians m where m.active order by random() limit 1; end if;
    return public.give_card(p_user, v_m, 'commune');
  end if;
  -- carte Rare minimum
  v_odds := (select value from public.settings where key = 'cry_gift_odds');
  select sum((v_odds ->> x::text)::numeric) into v_total from unnest(enum_range(null::public.rarity)) x where v_odds ? x::text;
  v_x := random() * coalesce(v_total, 0);
  foreach r in array enum_range(null::public.rarity) loop
    if v_odds ? r::text then
      if v_x < (v_odds ->> r::text)::numeric then v_r := r; exit; end if;
      v_x := v_x - (v_odds ->> r::text)::numeric;
    end if;
  end loop;
  select m.id into v_m from public.musicians m where m.active order by random() limit 1;
  return public.give_card(p_user, v_m, v_r);
end $$;
revoke execute on function public.objective_reward(uuid, text) from public, anon, authenticated;

create or replace function public.claim_objective(p_key text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_kind text := split_part(p_key, ':', 1); v_id text := split_part(p_key, ':', 2); v_reward jsonb;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  perform 1 from public.profiles where id = v_user for update;   -- deux touchers simultanés ne donnent pas deux récompenses
  if exists (select 1 from public.objective_claims where user_id = v_user and key = p_key) then raise exception 'récompense déjà récupérée'; end if;

  if v_kind = 'binder' then
    if not exists (select 1 from public.binders where id = v_id) then raise exception 'classeur inconnu'; end if;
    if exists (select 1 from public.musicians m
                where m.active and (v_id = 'all' or m.id in (select musician_id from public.binder_members where binder_id = v_id))
                  and not public.card_placed(v_user, m.id)) then
      raise exception 'classeur pas encore complet';
    end if;
    v_reward := public.objective_reward(v_user, 'binder');
  elsif v_kind = 'mastery' then
    if (select count(distinct rarity) from public.inventory where user_id = v_user and musician_id = v_id and placed and copies > 0) < 5 then
      raise exception 'maîtrise pas encore atteinte';
    end if;
    v_reward := public.objective_reward(v_user, 'mastery');
  elsif p_key = 'cry' then
    if not exists (select 1 from public.profiles where id = v_user and cry_path is not null) then raise exception 'enregistre d''abord ton cri'; end if;
    update public.profiles set cry_gift_claimed = true where id = v_user;
    v_reward := public.objective_reward(v_user, 'cry');
  elsif p_key in ('avatar', 'share') then
    if p_key = 'avatar' and not exists (select 1 from public.profiles where id = v_user and avatar_path is not null) then
      raise exception 'ajoute d''abord ta photo';
    end if;
    v_reward := public.objective_reward(v_user, 'small');
  else
    raise exception 'objectif inconnu';
  end if;

  insert into public.objective_claims (user_id, key, reward) values (v_user, p_key, v_reward);
  return v_reward;
end $$;
revoke execute on function public.claim_objective(text) from public, anon;
grant execute on function public.claim_objective(text) to authenticated;

-- demande d'artiste : un ticket prioritaire la fait remonter en tête chez l'admin
drop function if exists public.request_artist(text, text);
create or replace function public.request_artist(p_artist text, p_note text, p_priority boolean default false) returns void
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_artist text := trim(coalesce(p_artist, '')); v_note text := nullif(trim(coalesce(p_note, '')), '');
begin
  if v_user is null then raise exception 'non connecté'; end if;
  if length(v_artist) < 2 or length(v_artist) > 80 then raise exception 'nom d''artiste : 2 à 80 caractères'; end if;
  if v_note is not null and length(v_note) > 200 then raise exception 'message : 200 caractères au plus'; end if;
  if (select count(*) from public.artist_requests where user_id = v_user and created_at >= public.paris_day_start()) >= 5 then
    raise exception 'cinq demandes par jour, pas plus : reviens demain';
  end if;
  if p_priority then
    update public.profiles set priority_tickets = priority_tickets - 1 where id = v_user and priority_tickets > 0;
    if not found then raise exception 'plus de ticket prioritaire'; end if;
  end if;
  insert into public.artist_requests (user_id, artist, note, priority) values (v_user, v_artist, v_note, coalesce(p_priority, false));
end $$;
revoke execute on function public.request_artist(text, text, boolean) from public, anon;
grant execute on function public.request_artist(text, text, boolean) to authenticated;

-- tickets prioritaires du joueur connecté
create or replace function public.my_priority_tickets() returns int
language sql stable security definer set search_path = public as $$
  select coalesce((select priority_tickets from public.profiles where id = auth.uid()), 0);
$$;
revoke execute on function public.my_priority_tickets() from public, anon;
grant execute on function public.my_priority_tickets() to authenticated;
