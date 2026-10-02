-- Metalnini — ajouter en pote un membre de sa bande, sans attendre la validation du talon (dans les deux sens, comme le code de pote) ;
-- il est prévenu ; même plafond que le code de pote (20 nouveaux potes par jour) ; renvoie son pseudo.

create or replace function public.band_add_friend(p_band uuid, p_friend uuid) returns text
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_name text := (select username from public.profiles where id = auth.uid());
begin
  if v_user is null then raise exception 'non connecté'; end if;
  if p_friend = v_user then raise exception 'C''est toi.'; end if;
  if not exists (select 1 from public.concerts where band_id = p_band and user_id = v_user)
     or not exists (select 1 from public.concerts where band_id = p_band and user_id = p_friend) then
    raise exception 'Vous n''êtes pas dans la même bande.';
  end if;
  if (select count(*) from public.follows where user_id = v_user and created_at >= public.paris_day_start()) >= 20 then
    raise exception 'Vingt nouveaux potes par jour, pas plus : reviens demain.';
  end if;
  if public.make_friends(v_user, p_friend) then
    perform public.send_push(p_friend, 'Nouveau pote', coalesce(v_name, 'Un fan') || ' de ta bande t''a ajouté à ses potes.', 'pote',
                             'https://pittilloni.github.io/metalnini/proto/');
  end if;
  return coalesce((select username from public.profiles where id = p_friend), 'Un fan');
end $$;
revoke execute on function public.band_add_friend(uuid, uuid) from public, anon;
grant execute on function public.band_add_friend(uuid, uuid) to authenticated;
