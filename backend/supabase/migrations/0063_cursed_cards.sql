-- Metalnini — cartes maudites : des artistes aux faits établis par la justice ou reconnus publiquement (jamais une accusation),
-- chaque fait cité avec sa source (export/artistes-verifications.md, partie 3). Glissées rarement dans les paquets (réglage
-- cursed_odds, 0,07 par paquet), hors classeurs ; les déchirer lève la malédiction et rapporte une récompense tirée au hasard
-- (table « maudite » de objective_loot). Image unique, rangée comme rareté « commune ».

alter table public.musicians add column if not exists cursed boolean not null default false;
insert into public.settings (key, value) values ('cursed_odds', '0') on conflict (key) do nothing;   -- 0 à l'installation, 0,07 une fois l'app et les images en ligne
update public.settings set value = value || '{"maudite":[{"w":35,"kind":"pack"}, {"w":30,"kind":"new_commune"}, {"w":25,"kind":"card"}, {"w":10,"kind":"ticket"}]}'::jsonb
 where key = 'objective_loot' and not (value ? 'maudite');

create table if not exists public.cursed_facts (
  musician_id text primary key references public.musicians (id) on delete cascade,
  facts   jsonb not null,
  sources jsonb not null
);
alter table public.cursed_facts enable row level security;
drop policy if exists cursed_facts_read on public.cursed_facts;
create policy cursed_facts_read on public.cursed_facts for select to authenticated using (true);

create table if not exists public.cursed_tears (
  user_id     uuid not null references auth.users (id) on delete cascade,
  musician_id text not null,
  torn_at     timestamptz not null default now()
);
create index if not exists cursed_tears_user on public.cursed_tears (user_id);
alter table public.cursed_tears enable row level security;

-- les cartes maudites (fiche, faits, sources) : connues de l'app pour la révélation et la fiche
create or replace function public.cursed_cards() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', m.id, 'who', m.name, 'band', m.band, 'genre', m.subgenre, 'facts', f.facts, 'sources', f.sources) order by m.name), '[]'::jsonb)
    from public.musicians m join public.cursed_facts f on f.musician_id = m.id where m.cursed and auth.uid() is not null
$$;
revoke execute on function public.cursed_cards() from public, anon;
grant execute on function public.cursed_cards() to authenticated;

-- déchirer une carte maudite : elle disparaît, une récompense tirée au hasard la remplace
create or replace function public.curse_tear(p_musician text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'non connecté'; end if;
  if not exists (select 1 from public.musicians where id = p_musician and cursed) then raise exception 'ce n''est pas une carte maudite'; end if;
  update public.inventory set copies = copies - 1, updated_at = now() where user_id = v_user and musician_id = p_musician and copies > 0;
  if not found then raise exception 'tu n''as pas cette carte'; end if;
  delete from public.inventory where user_id = v_user and musician_id = p_musician and copies <= 0;
  insert into public.cursed_tears (user_id, musician_id) values (v_user, p_musician);
  return public.objective_reward(v_user, 'maudite');
end $$;
revoke execute on function public.curse_tear(text) from public, anon;
grant execute on function public.curse_tear(text) to authenticated;

create or replace function public.open_pack(p_pack_type text, p_request_id uuid, p_format text DEFAULT 'big'::text)
 RETURNS TABLE(card_position integer, musician_id text, rarity rarity, is_new boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_column
declare
  v_user uuid := auth.uid();
  v_opening uuid;
  v_size int;
  v_binder text;
  v_musician text;
  v_rarity public.rarity;
  v_new boolean;
  v_left int;
  v_daily int;
  v_bonus boolean := false;
  v_cost int := 2;   -- standard ou mini : toute la dotation du jour
  i int;
  v_celine boolean := exists (select 1 from public.profiles where id = auth.uid() and celine_until > now())
                      and not exists (select 1 from public.inventory where user_id = auth.uid() and musician_id = 'celine');
  v_celine_odds numeric := coalesce((select value::numeric from public.settings where key = 'celine_odds'), 0.001);
  v_cursed_at int := 0;   -- position de la carte maudite dans ce paquet (0 : aucune)
begin
  if v_user is null then raise exception 'non connecté'; end if;
  if exists (select 1 from public.profiles where id = v_user and blocked) then raise exception 'compte bloqué'; end if;

  select o.id into v_opening from public.pack_openings o where o.user_id = v_user and o.request_id = p_request_id;
  if v_opening is not null then
    return query select c.position, c.musician_id, c.rarity, c.is_new from public.pack_opening_cards c where c.opening_id = v_opening order by c.position;
    return;
  end if;

  if p_format not in ('big', 'small') then raise exception 'format de paquet inconnu : %', p_format; end if;
  -- le quota du jour d'abord, puis les points bonus (paquet de bienvenue ou cadeau de l'admin)
  v_left := public.packs_left_today();
  if v_left is not null then
    v_daily := public.daily_points_left();
    if v_daily < v_cost then
      if (select bonus_points from public.profiles where id = v_user) >= v_cost then v_bonus := true;
      elsif v_left = 0 then raise exception 'le merch est fermé : reviens demain pour ton paquet du jour';
      else raise exception 'il ne te reste qu''un mini aujourd''hui';
      end if;
    end if;
  end if;

  select pt.size, pt.binder_id into v_size, v_binder from public.pack_types pt where pt.id = p_pack_type and pt.active;
  if v_size is null then raise exception 'type de paquet inconnu : %', p_pack_type; end if;
  if p_format = 'small' then v_size := public.setting_int('small_pack_size', 2); end if;

  insert into public.pack_openings (user_id, pack_type_id, request_id, format, bonus) values (v_user, p_pack_type, p_request_id, p_format, v_bonus) returning id into v_opening;
  if v_bonus then update public.profiles set bonus_points = bonus_points - v_cost where id = v_user; end if;
  -- sinon on puise dans la réserve du jour (hors comptes illimités)
  if not v_bonus and v_left is not null then update public.profiles set daily_balance = greatest(0, daily_balance - v_cost) where id = v_user; end if;

  -- carte maudite : rarement, une carte du paquet est remplacée par une carte maudite (à déchirer)
  if random() < coalesce((select value::numeric from public.settings where key = 'cursed_odds'), 0.07)
     and exists (select 1 from public.musicians where cursed) then v_cursed_at := 1 + floor(random() * v_size)::int; end if;

  for i in 1..v_size loop
    select m.id into v_musician from public.musicians m
      where m.active and (v_binder is null or exists (select 1 from public.binder_members b where b.binder_id = v_binder and b.musician_id = m.id))
      order by random() limit 1;
    if v_musician is null then raise exception 'aucun musicien disponible pour %', p_pack_type; end if;
    v_rarity := case when p_format = 'small' then public.draw_rarity_small() else public.draw_rarity(p_pack_type) end;
    -- carte secrète : remplace la carte tirée, une seule fois
    if v_celine and random() < v_celine_odds then v_musician := 'celine'; v_rarity := 'legendaire'; v_celine := false; end if;
    if i = v_cursed_at then select m.id into v_musician from public.musicians m where m.cursed order by random() limit 1; v_rarity := 'commune'; end if;

    insert into public.inventory as inv (user_id, musician_id, rarity, copies, placed)
      values (v_user, v_musician, v_rarity, 1, false)
      on conflict (user_id, musician_id, rarity) do update set copies = inv.copies + 1, updated_at = now()
      returning (xmax = 0) into v_new;               -- vrai si la ligne vient d'être créée

    insert into public.pack_opening_cards (opening_id, position, musician_id, rarity, is_new)
      values (v_opening, i, v_musician, v_rarity, v_new);
  end loop;

  return query select c.position, c.musician_id, c.rarity, c.is_new from public.pack_opening_cards c where c.opening_id = v_opening order by c.rarity, c.position;
end $function$;

-- les 6 premières cartes maudites (vérifiées le 2026-10-07, validées par le propriétaire)
insert into public.musicians (id, name, band, arcana_title, arcana_number, instruments, subgenre, active, cursed) values
  ('m-varg', 'Varg Vikernes', 'Burzum', 'Carte maudite', '☠', '{}'::text[], 'Black metal', false, true),
  ('m-faust', 'Bård « Faust » Eithun', 'Emperor', 'Carte maudite', '☠', '{}'::text[], 'Black metal', false, true),
  ('m-watkins', 'Ian Watkins', 'Lostprophets', 'Carte maudite', '☠', '{}'::text[], 'Rock alternatif', false, true),
  ('m-schaffer', 'Jon Schaffer', 'Iced Earth', 'Carte maudite', '☠', '{}'::text[], 'Heavy metal', false, true),
  ('m-glitter', 'Gary Glitter', 'Gary Glitter', 'Carte maudite', '☠', '{}'::text[], 'Glam rock', false, true),
  ('m-anselmo', 'Phil Anselmo', 'Pantera', 'Carte maudite', '☠', '{}'::text[], 'Groove metal', false, true)
on conflict (id) do update set cursed = true, active = false;
insert into public.cards (musician_id, rarity, image_path)
select id, 'commune', 'cards/' || id || '-maudite.jpg' from public.musicians where cursed on conflict do nothing;

insert into public.cursed_facts (musician_id, facts, sources) values
('m-varg', '[{"head":"Condamné en 1994 (Norvège)","text":"Meurtre d''Øystein « Euronymous » Aarseth, guitariste de Mayhem, et incendies d''églises : 21 ans de prison."},{"head":"Condamné en 2014 (France)","text":"Incitation à la haine raciale pour des textes antisémites et xénophobes publiés en ligne : 6 mois avec sursis et amende."}]',
 '[{"label":"Wikipédia","url":"https://en.wikipedia.org/wiki/Varg_Vikernes"},{"label":"Loudwire, 2014","url":"https://loudwire.com/burzum-varg-vikernes-guilty-inciting-racial-hatred-exalting-war-crimes/"}]'),
('m-faust', '[{"head":"Condamné en 1994 (Norvège)","text":"Meurtre de Magne Andreassen, poignardé à Lillehammer en 1992 : 14 ans de prison, libéré en 2003."}]',
 '[{"label":"Wikipédia","url":"https://en.wikipedia.org/wiki/Faust_(musician)"},{"label":"Louder","url":"https://www.loudersound.com/news/dani-filth-laughed-off-bard-faust-eithuns-murder-confession-thinking-the-ex-emperor-drummer-was-talking-crap"}]'),
('m-watkins', '[{"head":"Condamné en 2013 (Royaume-Uni)","text":"A plaidé coupable de 13 crimes sexuels sur enfants : 29 ans de prison. Mort en prison en 2025."}]',
 '[{"label":"Washington Times, 2013","url":"https://www.washingtontimes.com/news/2013/dec/18/lostprophets-frontman-ian-watkins-sentenced-child-/"},{"label":"CBS News, 2025","url":"https://www.cbsnews.com/news/ian-watkins-killed-uk-prison-lostprophets-singer-suspects-arrested"}]'),
('m-schaffer', '[{"head":"A plaidé coupable en 2021 (États-Unis)","text":"Assaut du Capitole du 6 janvier 2021 : obstruction d''une procédure officielle et entrée armée dans un bâtiment protégé. 3 ans de mise à l''épreuve. Gracié par Donald Trump en janvier 2025."}]',
 '[{"label":"Rolling Stone","url":"https://www.rollingstone.com/music/music-news/jon-schaffer-jan-6-iced-earth-sentenced-1234701957/"},{"label":"Variety, 2021","url":"https://variety.com/2021/music/news/iced-earth-guitarist-pleads-guilty-capitol-riot-1234953754/"}]'),
('m-glitter', '[{"head":"Condamné en 1999, 2006 et 2015","text":"Détention d''images pédocriminelles (1999) ; actes obscènes sur deux fillettes au Vietnam (2006) ; tentative de viol et agressions sexuelles sur trois fillettes : 16 ans de prison (2015)."}]',
 '[{"label":"NPR, 2015","url":"https://www.npr.org/sections/thetwo-way/2015/02/27/389484520/rocker-gary-glitter-jailed-for-16-years-for-child-sex-abuse"},{"label":"Wikipédia","url":"https://en.wikipedia.org/wiki/Gary_Glitter"}]'),
('m-anselmo', '[{"head":"Fait filmé et reconnu en 2016","text":"Salut nazi et « white power » crié sur scène au Dimebash, à Hollywood. Il s''est excusé publiquement ensuite. Pas de condamnation."}]',
 '[{"label":"Loudwire, 2016","url":"https://loudwire.com/philip-anselmo-white-power-nazi-salute/"},{"label":"NME, 2016","url":"https://www.nme.com/news/music/pantera-6-1206690"}]')
on conflict (musician_id) do update set facts = excluded.facts, sources = excluded.sources;
