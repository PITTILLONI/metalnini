-- Metalnini — ajouter en pote quelqu'un croisé dans la fosse : un porteur de mon slam, quelqu'un qui porte le même slam que moi,
-- ou un coureur du même circle pit (7 derniers jours) ; dans les deux sens, il est prévenu ; plafond de 20 nouveaux potes par jour.

create or replace function public.fosse_add_friend(p_friend uuid) returns text
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_name text := (select username from public.profiles where id = auth.uid()); v_since timestamptz := now() - interval '7 days';
begin
  if v_user is null then raise exception 'non connecté'; end if;
  if p_friend = v_user then raise exception 'C''est toi.'; end if;
  if not exists (   -- un slam en commun (slammeur ou porteur, des deux côtés)
       select 1 from public.slams s where s.created_at >= v_since
          and (s.user_id = v_user or exists (select 1 from public.slam_carriers c where c.slam_id = s.id and c.user_id = v_user))
          and (s.user_id = p_friend or exists (select 1 from public.slam_carriers c where c.slam_id = s.id and c.user_id = p_friend)))
     and not exists (   -- ou un circle pit en commun
       select 1 from public.pit_runners a join public.pit_runners b on b.pit_id = a.pit_id
        where a.user_id = v_user and b.user_id = p_friend and a.joined_at >= v_since) then
    raise exception 'Vous ne vous êtes pas croisés dans la fosse.';
  end if;
  if (select count(*) from public.follows where user_id = v_user and created_at >= public.paris_day_start()) >= 20 then
    raise exception 'Vingt nouveaux potes par jour, pas plus : reviens demain.';
  end if;
  if public.make_friends(v_user, p_friend) then
    perform public.send_push(p_friend, 'Nouveau pote', coalesce(v_name, 'Un fan') || ' t''a croisé dans la fosse et t''ajoute à ses potes.', 'pote',
                             'https://pittilloni.github.io/metalnini/proto/');
  end if;
  return coalesce((select username from public.profiles where id = p_friend), 'Un fan');
end $$;
revoke execute on function public.fosse_add_friend(uuid) from public, anon;
grant execute on function public.fosse_add_friend(uuid) to authenticated;
