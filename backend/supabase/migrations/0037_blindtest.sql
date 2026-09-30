-- Metalnini — blind test : chaque maîtrise débloque un blind test (5 extraits des musiciens du joueur, 4 choix), joué une seule fois.
-- Récompense selon le score (tables quiz3 / quiz4 / quiz5 du réglage objective_loot) : 3 = Commune nouvelle, 4 = Rare minimum, 5 = Holo minimum.
-- Le score est compté par l'app (non vérifiable côté serveur) : l'enjeu reste limité à un blind test par maîtrise.

insert into public.settings (key, value) values ('holo_min_odds', '{"holo":80,"signature":17,"legendaire":3}') on conflict (key) do nothing;
update public.settings set value = value || '{"quiz3":[{"w":100,"kind":"new_commune"}], "quiz4":[{"w":100,"kind":"card"}], "quiz5":[{"w":100,"kind":"holo"}]}'::jsonb
 where key = 'objective_loot' and not value ? 'quiz3';

alter table public.objective_claims drop constraint if exists objective_claims_key_check;
alter table public.objective_claims add constraint objective_claims_key_check check (key ~ '^(binder|mastery|quiz):[a-z0-9-]+$' or key in ('avatar', 'share', 'cry'));

-- tirage : + « holo » (Holo minimum, cotes holo_min_odds)
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
  elsif v_kind = 'holo' then
    v_odds := (select value from public.settings where key = 'holo_min_odds');
    select sum((v_odds ->> x::text)::numeric) into v_total from unnest(enum_range(null::public.rarity)) x where v_odds ? x::text;
    v_x := random() * coalesce(v_total, 0); v_r := 'holo';
    foreach r in array enum_range(null::public.rarity) loop
      if v_odds ? r::text then
        if v_x < (v_odds ->> r::text)::numeric then v_r := r; exit; end if;
        v_x := v_x - (v_odds ->> r::text)::numeric;
      end if;
    end loop;
    select m.id into v_m from public.musicians m where m.active order by random() limit 1;
    return public.give_card(p_user, v_m, v_r);
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

create or replace function public.claim_blindtest(p_musician text, p_score int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_key text := 'quiz:' || p_musician; v_reward jsonb;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  if p_score is null or p_score < 0 or p_score > 5 then raise exception 'score invalide'; end if;
  perform 1 from public.profiles where id = v_user for update;
  if exists (select 1 from public.objective_claims where user_id = v_user and key = v_key) then raise exception 'blind test déjà joué'; end if;
  if (select count(distinct rarity) from public.inventory where user_id = v_user and musician_id = p_musician and placed and copies > 0) < 5 then
    raise exception 'blind test débloqué par la maîtrise de ce musicien';
  end if;
  v_reward := case when p_score >= 3 then public.objective_reward(v_user, 'quiz' || p_score) else jsonb_build_object('kind', 'none') end;
  insert into public.objective_claims (user_id, key, reward) values (v_user, v_key, v_reward || jsonb_build_object('score', p_score));
  return v_reward;
end $$;
revoke execute on function public.claim_blindtest(text, int) from public, anon;
grant execute on function public.claim_blindtest(text, int) to authenticated;
