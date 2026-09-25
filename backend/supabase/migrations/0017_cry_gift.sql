-- Metalnini — carte cadeau pour le premier cri enregistré : une seule fois par compte, au moins une Rare.
alter table public.profiles add column if not exists cry_gift_claimed boolean not null default false;
insert into public.settings (key, value) values ('cry_gift_odds', '{"rare":70,"holo":22,"signature":7,"legendaire":1}') on conflict (key) do nothing;

create or replace function public.claim_cry_gift()
returns table (musician_id text, rarity public.rarity, is_new boolean)
language plpgsql volatile security definer set search_path = public as $$
#variable_conflict use_column
declare
  v_user uuid := auth.uid(); v_odds jsonb := (select value from public.settings where key = 'cry_gift_odds');
  v_total numeric; v_x numeric; v_r public.rarity := 'rare'; r public.rarity; v_m text; v_new boolean;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  -- verrou sur la ligne : deux appels simultanés ne donnent pas deux cadeaux
  perform 1 from public.profiles where id = v_user for update;
  if not exists (select 1 from public.profiles where id = v_user and cry_path is not null) then raise exception 'enregistre d''abord ton cri'; end if;
  if exists (select 1 from public.profiles where id = v_user and cry_gift_claimed) then return; end if;
  select sum((v_odds ->> x::text)::numeric) into v_total from unnest(enum_range(null::public.rarity)) x where v_odds ? x::text;
  v_x := random() * coalesce(v_total, 0);
  foreach r in array enum_range(null::public.rarity) loop
    if v_odds ? r::text then
      if v_x < (v_odds ->> r::text)::numeric then v_r := r; exit; end if;
      v_x := v_x - (v_odds ->> r::text)::numeric;
    end if;
  end loop;
  select m.id into v_m from public.musicians m where m.active order by random() limit 1;
  insert into public.inventory as inv (user_id, musician_id, rarity, copies, placed) values (v_user, v_m, v_r, 1, false)
    on conflict (user_id, musician_id, rarity) do update set copies = inv.copies + 1, updated_at = now()
    returning (xmax = 0) into v_new;
  update public.profiles set cry_gift_claimed = true where id = v_user;
  return query select v_m, v_r, v_new;
end $$;
revoke execute on function public.claim_cry_gift() from public, anon;
grant execute on function public.claim_cry_gift() to authenticated;
