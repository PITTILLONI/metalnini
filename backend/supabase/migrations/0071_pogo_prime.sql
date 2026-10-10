-- Metalnini — prime du pogo (2026-10-10) : il y a toujours quelque chose à gagner. Dès 3 danseurs, le meilleur danseur resté
-- debout (non relevé) gagne une carte de la rareté misée, tirée au hasard, en plus des cartes ramassées (marquée « prime »).

-- ramassage : la prime au meilleur danseur resté debout (3 danseurs au moins), puis les cartes tombées au premier tiers ; un relevé ne ramasse pas
create or replace function public.pogo_settle(p_pogo uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
declare p record; n int; w int; v_winners uuid[]; s record; i int := 0; v_prime text; cfg jsonb := (select value from public.settings where key = 'pogo');
begin
  select * into p from public.pogos where id = p_pogo for update;
  if p.settled or now() < p.ends_at then return; end if;
  select count(*) into n from public.pogo_players where pogo_id = p_pogo and energy is not null;
  if p.cancelled or n < (cfg ->> 'min_players')::int then
    update public.pogo_players set result = 'kept', points = 0 where pogo_id = p_pogo;
  else
    update public.pogo_players set result = 'lost' where pogo_id = p_pogo and energy is not null and fell and lifted_by is null;
    update public.pogo_players set result = 'kept' where pogo_id = p_pogo and result is null;
    w := ceil(n / 3.0);
    update public.pogo_players set result = 'won' where pogo_id = p_pogo and user_id in
      (select user_id from public.pogo_players where pogo_id = p_pogo and energy is not null and result <> 'lost' and lifted_by is null order by energy desc, joined_at limit w);
    select array_agg(user_id order by energy desc, joined_at) into v_winners from public.pogo_players where pogo_id = p_pogo and result = 'won';
    -- la prime : le meilleur danseur resté debout gagne toujours une carte de la rareté misée, tirée au hasard
    if v_winners is not null then
      select id into v_prime from public.musicians where active and not cursed and not perso order by random() limit 1;
      if v_prime is not null then
        update public.pogo_players set won = won || jsonb_build_array(jsonb_build_object('m', v_prime, 'r', p.rarity, 'prime', true))
         where pogo_id = p_pogo and user_id = v_winners[1];
      end if;
      for s in select stake_m from public.pogo_players where pogo_id = p_pogo and result = 'lost' order by random() loop
        update public.pogo_players set won = won || jsonb_build_array(jsonb_build_object('m', s.stake_m, 'r', p.rarity))
         where pogo_id = p_pogo and user_id = v_winners[1 + i % array_length(v_winners, 1)];
        i := i + 1;
      end loop;
    end if;
    update public.pogo_players set points = case when energy is null then 0
      else 1 + case when result = 'won' then 1 else 0 end + case when user_id = p.user_id then 1 else 0 end end where pogo_id = p_pogo;
  end if;
  update public.pogos set settled = true where id = p_pogo;
end $$;
