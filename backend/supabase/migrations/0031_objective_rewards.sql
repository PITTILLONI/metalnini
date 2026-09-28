-- Metalnini — récompenses d'objectifs : le joueur vient les toucher dans Metal Corner, le serveur vérifie puis donne, une seule fois.
--   binder:<id>     classeur complété (toutes ses cartes rangées)        → 1 paquet au choix (2 points de paquet)
--   mastery:<id>    maîtrise d'un musicien (5 raretés rangées)           → 1 carte Rare minimum (cotes du cadeau du cri)
--   avatar          photo de profil ajoutée                              → 1 Commune d'un musicien pas encore trouvé
--   share           plus belle carte partagée (non vérifiable, faible valeur) → 1 Commune d'un musicien pas encore trouvé

create table if not exists public.objective_claims (
  user_id    uuid not null references auth.users (id) on delete cascade,
  key        text not null check (key ~ '^(binder|mastery):[a-z0-9-]+$' or key in ('avatar', 'share')),
  reward     jsonb not null,
  created_at timestamptz not null default now(),
  primary key (user_id, key)
);
alter table public.objective_claims enable row level security;
drop policy if exists objective_claims_own on public.objective_claims;
create policy objective_claims_own on public.objective_claims for select to authenticated using (user_id = auth.uid() or public.is_admin());

-- une carte rangée (au moins un exemplaire placé dans le classeur)
create or replace function public.card_placed(p_user uuid, p_musician text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.inventory where user_id = p_user and musician_id = p_musician and placed and copies > 0);
$$;
revoke execute on function public.card_placed(uuid, text) from public, anon, authenticated;

-- une carte donnée au joueur (à ranger), renvoyée pour la révélation
create or replace function public.give_card(p_user uuid, p_musician text, p_rarity public.rarity) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_new boolean;
begin
  insert into public.inventory as inv (user_id, musician_id, rarity, copies, placed) values (p_user, p_musician, p_rarity, 1, false)
    on conflict (user_id, musician_id, rarity) do update set copies = inv.copies + 1, updated_at = now()
    returning (xmax = 0) into v_new;
  return jsonb_build_object('kind', 'card', 'm', p_musician, 'r', p_rarity, 'new', v_new);
end $$;
revoke execute on function public.give_card(uuid, text, public.rarity) from public, anon, authenticated;

create or replace function public.claim_objective(p_key text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_kind text := split_part(p_key, ':', 1); v_id text := split_part(p_key, ':', 2);
        v_reward jsonb; v_m text; v_odds jsonb; v_total numeric; v_x numeric; v_r public.rarity := 'rare'; r public.rarity;
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
    update public.profiles set bonus_points = bonus_points + 2 where id = v_user;
    v_reward := jsonb_build_object('kind', 'points', 'points', 2);

  elsif v_kind = 'mastery' then
    if (select count(distinct rarity) from public.inventory where user_id = v_user and musician_id = v_id and placed and copies > 0) < 5 then
      raise exception 'maîtrise pas encore atteinte';
    end if;
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
    v_reward := public.give_card(v_user, v_m, v_r);

  elsif p_key in ('avatar', 'share') then
    if p_key = 'avatar' and not exists (select 1 from public.profiles where id = v_user and avatar_path is not null) then
      raise exception 'ajoute d''abord ta photo';
    end if;
    select m.id into v_m from public.musicians m
     where m.active and not exists (select 1 from public.inventory i where i.user_id = v_user and i.musician_id = m.id)
     order by random() limit 1;
    if v_m is null then select m.id into v_m from public.musicians m where m.active order by random() limit 1; end if;
    v_reward := public.give_card(v_user, v_m, 'commune');

  else
    raise exception 'objectif inconnu';
  end if;

  insert into public.objective_claims (user_id, key, reward) values (v_user, p_key, v_reward);
  return v_reward;
end $$;
revoke execute on function public.claim_objective(text) from public, anon;
grant execute on function public.claim_objective(text) to authenticated;
