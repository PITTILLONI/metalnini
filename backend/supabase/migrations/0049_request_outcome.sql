-- Metalnini — demandes d'artistes suivies jusqu'au bout : l'admin voit qui demande (pseudo, ticket prioritaire ou non) et
-- traite une demande en « ajouté » ou « refusé » ; chaque demandeur est prévenu (notification, et message à la prochaine
-- ouverture de l'app s'il n'a pas les notifications) ; un ticket prioritaire est rendu si l'artiste est refusé.

alter table public.artist_requests add column if not exists outcome text check (outcome in ('added', 'refused'));
alter table public.artist_requests add column if not exists handled_at timestamptz;
alter table public.artist_requests add column if not exists seen boolean not null default false;

-- demandes en attente, avec le pseudo du demandeur
create or replace function public.admin_requests() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'artist', r.artist, 'note', r.note, 'priority', r.priority, 'created_at', r.created_at,
                                                       'user_id', r.user_id, 'username', coalesce(p.username, 'Sans pseudo')) order by r.created_at desc)
                     from public.artist_requests r left join public.profiles p on p.id = r.user_id where not r.done), '[]'::jsonb);
end $$;
revoke execute on function public.admin_requests() from public, anon;
grant execute on function public.admin_requests() to authenticated;

-- traiter des demandes (un même artiste demandé par plusieurs joueurs) ; renvoie le nombre de joueurs prévenus
create or replace function public.admin_request_handle(p_ids bigint[], p_outcome text) returns int
language plpgsql volatile security definer set search_path = public as $$
declare r record; n int := 0; v_body text;
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  if p_outcome not in ('added', 'refused') then raise exception 'issue inconnue'; end if;
  for r in update public.artist_requests set done = true, outcome = p_outcome, handled_at = now(), seen = false
            where id = any(p_ids) and not done returning user_id, artist, priority loop
    if p_outcome = 'refused' and r.priority then
      update public.profiles set priority_tickets = priority_tickets + 1 where id = r.user_id;
    end if;
    v_body := case
      when p_outcome = 'added' and r.priority then 'Ton ticket prioritaire a payé : ' || r.artist || ' débarque dans les paquets.'
      when p_outcome = 'added' then r.artist || ' débarque dans les paquets. Merci pour la demande.'
      when r.priority then 'Pas de ' || r.artist || ' dans Metalnini pour l''instant. Ton ticket prioritaire t''est rendu.'
      else 'Pas de ' || r.artist || ' dans Metalnini pour l''instant. Merci pour la demande.' end;
    -- un ticket utilisé mérite sa réponse : notification hors budget quotidien
    perform public.send_push(r.user_id, case when p_outcome = 'added' then 'Demande exaucée' else 'Demande traitée' end, v_body, 'demande',
                             'https://pittilloni.github.io/metalnini/proto/', r.priority);
    n := n + 1;
  end loop;
  return n;
end $$;
revoke execute on function public.admin_request_handle(bigint[], text) from public, anon;
grant execute on function public.admin_request_handle(bigint[], text) to authenticated;

-- réponses à mes demandes pas encore vues dans l'app (puis marquées vues)
create or replace function public.my_request_news() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v jsonb;
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('artist', artist, 'outcome', outcome, 'priority', priority) order by handled_at), '[]'::jsonb) into v
    from public.artist_requests where user_id = auth.uid() and outcome is not null and not seen;
  update public.artist_requests set seen = true where user_id = auth.uid() and outcome is not null and not seen;
  return v;
end $$;
revoke execute on function public.my_request_news() from public, anon;
grant execute on function public.my_request_news() to authenticated;
