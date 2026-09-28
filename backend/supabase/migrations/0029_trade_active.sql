-- Metalnini — reprendre un échange : la session en cours du joueur (en attente ou en composition), retrouvée
-- après un rechargement, une mise à jour ou une réouverture de l'app. Null s'il n'y en a pas.

create or replace function public.trade_active() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_id uuid;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  perform public.trade_expire();
  select id into v_id from public.trades
   where status in ('open', 'live') and v_user in (host, coalesce(guest, host))
   order by updated_at desc limit 1;
  return case when v_id is null then null else public.trade_state(v_id) end;
end $$;
revoke execute on function public.trade_active() from public, anon;
grant execute on function public.trade_active() to authenticated;
