-- Metalnini — onboarding : paquet de bienvenue tiré avant le compte (jeton), réclamé à la création du compte ;
-- récompenses d'installation et d'activation des notifications (un mini chacune, une fois par compte).

create table if not exists public.welcome_previews (
  token      uuid primary key default gen_random_uuid(),
  cards      jsonb not null,
  styles     text[] not null default '{}',
  created_at timestamptz not null default now(),
  claimed_by uuid references auth.users (id) on delete set null,
  claimed_at timestamptz
);
alter table public.welcome_previews enable row level security;   -- aucun accès direct

alter table public.profiles add column if not exists welcome_claimed boolean not null default false;
alter table public.profiles add column if not exists install_rewarded boolean not null default false;
alter table public.profiles add column if not exists push_rewarded boolean not null default false;

-- tire le paquet de bienvenue (5 cartes, 5 musiciens différents) : au moins une Rare, au moins deux cartes des styles choisis.
-- Ouvert aux visiteurs sans compte : le paquet ne vaut rien tant qu'il n'est pas réclamé par un compte.
create or replace function public.preview_welcome_pack(p_styles text[]) returns table (token uuid, card_position int, musician_id text, rarity public.rarity)
language plpgsql volatile security definer set search_path = public as $$
#variable_conflict use_column
declare v_styles text[]; v_pool text[]; v_cards jsonb := '[]'::jsonb; v_taken text[] := '{}'; v_m text; v_r public.rarity; i int; v_token uuid;
begin
  select coalesce(array_agg(b.id), '{}') into v_styles from public.binders b where b.kind = 'style' and b.id = any(coalesce(p_styles, '{}'));
  select coalesce(array_agg(distinct bm.musician_id), '{}') into v_pool from public.binder_members bm join public.musicians m on m.id = bm.musician_id
    where m.active and bm.binder_id = any(v_styles);
  for i in 1..5 loop
    -- cartes 1 et 2 dans les styles choisis (s'il y en a), les suivantes partout
    select m.id into v_m from public.musicians m where m.active and not m.id = any(v_taken)
      and (i > 2 or cardinality(v_pool) = 0 or m.id = any(v_pool)) order by random() limit 1;
    if v_m is null then select m.id into v_m from public.musicians m where m.active and not m.id = any(v_taken) order by random() limit 1; end if;
    v_r := case when i = 1 then 'rare'::public.rarity else public.draw_rarity('mosh') end;
    v_taken := v_taken || v_m;
    v_cards := v_cards || jsonb_build_object('position', i, 'musician_id', v_m, 'rarity', v_r);
  end loop;
  insert into public.welcome_previews (cards, styles) values (v_cards, v_styles) returning welcome_previews.token into v_token;
  return query select v_token, (c ->> 'position')::int, c ->> 'musician_id', (c ->> 'rarity')::public.rarity
    from jsonb_array_elements(v_cards) c order by (c ->> 'rarity')::public.rarity, (c ->> 'position')::int;
end $$;
revoke execute on function public.preview_welcome_pack(text[]) from public;
grant execute on function public.preview_welcome_pack(text[]) to anon, authenticated;

-- le compte réclame son paquet de bienvenue (une fois par compte, jeton de moins de 7 jours) ; p_placed : cartes déjà rangées pendant l'onboarding
create or replace function public.claim_welcome_pack(p_token uuid, p_placed text[]) returns int
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_cards jsonb; c jsonb; n int := 0;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  perform 1 from public.profiles where id = v_user for update;
  if exists (select 1 from public.profiles where id = v_user and welcome_claimed) then return 0; end if;
  select w.cards into v_cards from public.welcome_previews w where w.token = p_token and w.claimed_by is null and w.created_at > now() - interval '7 days' for update;
  if v_cards is null then return 0; end if;
  for c in select * from jsonb_array_elements(v_cards) loop
    insert into public.inventory as inv (user_id, musician_id, rarity, copies, placed)
      values (v_user, c ->> 'musician_id', (c ->> 'rarity')::public.rarity, 1, (c ->> 'musician_id') || '|' || (c ->> 'rarity') = any(coalesce(p_placed, '{}')))
      on conflict (user_id, musician_id, rarity) do update set copies = inv.copies + 1, updated_at = now();
    n := n + 1;
  end loop;
  update public.welcome_previews set claimed_by = v_user, claimed_at = now() where token = p_token;
  update public.profiles set welcome_claimed = true where id = v_user;
  return n;
end $$;
revoke execute on function public.claim_welcome_pack(uuid, text[]) from public, anon;
grant execute on function public.claim_welcome_pack(uuid, text[]) to authenticated;

-- récompense d'installation : un mini (1 point bonus), une fois par compte
create or replace function public.claim_install_reward() returns boolean
language plpgsql volatile security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  update public.profiles set install_rewarded = true, bonus_points = bonus_points + 1 where id = auth.uid() and not install_rewarded;
  return found;
end $$;
revoke execute on function public.claim_install_reward() from public, anon;
grant execute on function public.claim_install_reward() to authenticated;

-- récompense des notifications : un mini, une fois par compte, seulement si un appareil est vraiment abonné
create or replace function public.claim_push_reward() returns boolean
language plpgsql volatile security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  if not exists (select 1 from public.push_subscriptions where user_id = auth.uid()) then return false; end if;
  update public.profiles set push_rewarded = true, bonus_points = bonus_points + 1 where id = auth.uid() and not push_rewarded;
  return found;
end $$;
revoke execute on function public.claim_push_reward() from public, anon;
grant execute on function public.claim_push_reward() to authenticated;
