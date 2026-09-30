-- Metalnini — blind test débloqué par un classeur complété (clé quiz:b-<classeur>), en plus de celui des maîtrises.
-- Mêmes paliers de récompense (quiz3 / quiz4 / quiz5), joué une seule fois.

create or replace function public.claim_blindtest_binder(p_binder text, p_score int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_key text := 'quiz:b-' || p_binder; v_reward jsonb;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  if p_score is null or p_score < 0 or p_score > 5 then raise exception 'score invalide'; end if;
  if not exists (select 1 from public.binders where id = p_binder) then raise exception 'classeur inconnu'; end if;
  perform 1 from public.profiles where id = v_user for update;
  if exists (select 1 from public.objective_claims where user_id = v_user and key = v_key) then raise exception 'blind test déjà joué'; end if;
  if exists (select 1 from public.musicians m
              where m.active and (p_binder = 'all' or m.id in (select musician_id from public.binder_members where binder_id = p_binder))
                and not public.card_placed(v_user, m.id)) then
    raise exception 'blind test débloqué quand le classeur est complet';
  end if;
  v_reward := case when p_score >= 3 then public.objective_reward(v_user, 'quiz' || p_score) else jsonb_build_object('kind', 'none') end;
  insert into public.objective_claims (user_id, key, reward) values (v_user, v_key, v_reward || jsonb_build_object('score', p_score));
  return v_reward;
end $$;
revoke execute on function public.claim_blindtest_binder(text, int) from public, anon;
grant execute on function public.claim_blindtest_binder(text, int) to authenticated;
