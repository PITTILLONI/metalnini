-- Metalnini — « Rameuter » : depuis un circle pit, un pogo ou un slam, appeler un pote précis de l'app (notification directe,
-- hors budget, une fois par pote et par événement). Réservé à qui participe ; le pote appelé voit ensuite l'événement dans sa Fosse.

create table if not exists public.fosse_calls (
  kind       text not null check (kind in ('pit', 'pogo', 'slam')),
  event_id   uuid not null,
  from_id    uuid not null references auth.users (id) on delete cascade,
  to_id      uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (kind, event_id, from_id, to_id)
);
alter table public.fosse_calls enable row level security;   -- tout passe par les fonctions ci-dessous

create or replace function public.fosse_call(p_kind text, p_event uuid, p_to uuid) returns boolean
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_name text := (select username from public.profiles where id = auth.uid()); v_ok boolean; v_in boolean;
        v_title text; v_body text;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  if p_to = v_user or not public.are_friends(v_user, p_to) then raise exception 'Ce n''est pas un de tes potes.'; end if;
  if p_kind = 'pit' then
    v_ok := exists (select 1 from public.pits where id = p_event and not cancelled and now() < ends_at)
            and exists (select 1 from public.pit_runners where pit_id = p_event and user_id = v_user);
    v_in := exists (select 1 from public.pit_runners where pit_id = p_event and user_id = p_to);
    v_title := 'Circle pit !'; v_body := coalesce(v_name, 'Un pote') || ' t''appelle dans son circle pit. Viens faire ta course !';
  elsif p_kind = 'pogo' then
    v_ok := exists (select 1 from public.pogos where id = p_event and not cancelled and now() < ends_at)
            and exists (select 1 from public.pogo_players where pogo_id = p_event and user_id = v_user);
    v_in := exists (select 1 from public.pogo_players where pogo_id = p_event and user_id = p_to);
    v_title := 'Pogo !'; v_body := coalesce(v_name, 'Un pote') || ' t''appelle dans le pogo. Viens te faire bousculer !';
  elsif p_kind = 'slam' then
    v_ok := exists (select 1 from public.slams where id = p_event and landed_at is null and now() < ends_at
                      and (user_id = v_user or exists (select 1 from public.slam_carriers where slam_id = p_event and user_id = v_user)));
    v_in := exists (select 1 from public.slams where id = p_event and user_id = p_to) or exists (select 1 from public.slam_carriers where slam_id = p_event and user_id = p_to);
    v_title := 'Slam !'; v_body := coalesce(v_name, 'Un pote') || ' plane au-dessus de la foule et compte sur toi. Viens le porter !';
  else raise exception 'Danse inconnue.';
  end if;
  if not v_ok then raise exception 'Tu ne peux plus rameuter pour celui-ci.'; end if;
  if v_in then raise exception 'Ton pote y est déjà.'; end if;
  insert into public.fosse_calls (kind, event_id, from_id, to_id) values (p_kind, p_event, v_user, p_to) on conflict do nothing;
  if not found then raise exception 'Déjà appelé.'; end if;
  if p_kind = 'pit' then insert into public.pit_notified (pit_id, user_id) values (p_event, p_to) on conflict do nothing;
  elsif p_kind = 'pogo' then insert into public.pogo_notified (pogo_id, user_id) values (p_event, p_to) on conflict do nothing; end if;
  perform public.send_push(p_to, v_title, v_body, p_kind,
    'https://pittilloni.github.io/metalnini/proto/?' || p_kind || '=' || p_event, true);
  return true;
end $$;
revoke execute on function public.fosse_call(text, uuid, uuid) from public, anon;
grant execute on function public.fosse_call(text, uuid, uuid) to authenticated;

-- les potes que j'ai déjà appelés pour cet événement
create or replace function public.fosse_called(p_kind text, p_event uuid) returns uuid[]
language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(to_id), '{}') from public.fosse_calls where kind = p_kind and event_id = p_event and from_id = auth.uid()
$$;
revoke execute on function public.fosse_called(text, uuid) from public, anon;
grant execute on function public.fosse_called(text, uuid) to authenticated;
