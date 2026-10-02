-- Metalnini — ajouter un pote sans troc : chaque joueur a un code de pote (6 caractères, lien ?pote=CODE) ; l'utiliser rend
-- les deux joueurs potes l'un de l'autre (notification à celui qui a donné son code). Et « Appeler la foule » : ouvrir le lien
-- d'un slam en cours (?slam=ID) rend potes avec le slammeur, pour pouvoir le porter tout de suite.

alter table public.profiles add column if not exists friend_code text;
create unique index if not exists profiles_friend_code on public.profiles (friend_code) where friend_code is not null;

-- mon code de pote, tiré à la première demande
create or replace function public.my_friend_code() returns text
language plpgsql volatile security definer set search_path = public as $$
declare v_code text := (select friend_code from public.profiles where id = auth.uid()); v_abc text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; i int;
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  while v_code is null loop
    v_code := '';
    for i in 1..6 loop v_code := v_code || substr(v_abc, 1 + floor(random() * length(v_abc))::int, 1); end loop;
    begin
      update public.profiles set friend_code = v_code where id = auth.uid();
    exception when unique_violation then v_code := null; end;   -- code déjà pris : on en tire un autre
  end loop;
  return v_code;
end $$;
revoke execute on function public.my_friend_code() from public, anon;
grant execute on function public.my_friend_code() to authenticated;

-- devenir potes dans les deux sens ; renvoie vrai si c'est nouveau
create or replace function public.make_friends(a uuid, b uuid) returns boolean
language plpgsql volatile security definer set search_path = public as $$
declare n int;
begin
  insert into public.follows (user_id, friend_id) values (a, b), (b, a) on conflict do nothing;
  get diagnostics n = row_count;
  return n > 0;
end $$;
revoke execute on function public.make_friends(uuid, uuid) from public, anon, authenticated;

-- ajouter un pote par son code (20 par jour au plus) ; il est prévenu ; renvoie son pseudo
create or replace function public.add_friend(p_code text) returns text
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_friend uuid; v_name text := (select username from public.profiles where id = auth.uid());
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select id into v_friend from public.profiles where friend_code = upper(replace(replace(trim(coalesce(p_code, '')), '-', ''), ' ', ''));
  if v_friend is null then raise exception 'Code inconnu : vérifie les 6 caractères.'; end if;
  if v_friend = v_user then raise exception 'C''est ton propre code. Envoie-le plutôt à tes potes.'; end if;
  if (select count(*) from public.follows where user_id = v_user and created_at >= public.paris_day_start()) >= 20 then
    raise exception 'Vingt nouveaux potes par jour, pas plus : reviens demain.';
  end if;
  if public.make_friends(v_user, v_friend) then
    perform public.send_push(v_friend, 'Nouveau pote', coalesce(v_name, 'Un fan') || ' t''a ajouté à ses potes. Il pourra te porter quand tu slammes.', 'pote',
                             'https://pittilloni.github.io/metalnini/proto/');
  end if;
  return coalesce((select username from public.profiles where id = v_friend), 'Un fan');
end $$;
revoke execute on function public.add_friend(text) from public, anon;
grant execute on function public.add_friend(text) to authenticated;

-- lien d'un slam ouvert : potes avec le slammeur s'il est encore en l'air ; renvoie son pseudo (null si rien à faire)
create or replace function public.slam_join(p_slam uuid) returns text
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); s record; v_name text := (select username from public.profiles where id = auth.uid());
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select * into s from public.slams where id = p_slam;
  if not found or s.user_id = v_user or s.landed_at is not null or now() >= s.ends_at then return null; end if;
  if public.make_friends(v_user, s.user_id) then
    perform public.send_push(s.user_id, 'La foule grossit', coalesce(v_name, 'Un fan') || ' a suivi ton lien et rejoint la foule.', 'slam',
                             'https://pittilloni.github.io/metalnini/proto/?slam=' || p_slam);
  end if;
  return coalesce((select username from public.profiles where id = s.user_id), 'Ton pote');
end $$;
revoke execute on function public.slam_join(uuid) from public, anon;
grant execute on function public.slam_join(uuid) to authenticated;
