-- Metalnini — blind test des cris : entendre le cri d'un pote suivi et deviner qui c'est parmi 4 pseudos (un essai par cri).
-- Trouvé : bonus (table cryguess de objective_loot) ; le cri du pote est « démasqué » (notification) : il en enregistre un nouveau
-- pour redevenir mystère et gagne un petit bonus (table remask).

alter table public.profiles add column if not exists cry_unmasked_by uuid references auth.users (id) on delete set null;
alter table public.profiles add column if not exists cry_unmasked_path text;

create table if not exists public.cry_guesses (
  user_id    uuid not null references auth.users (id) on delete cascade,
  friend_id  uuid not null references auth.users (id) on delete cascade,
  cry_path   text not null,
  correct    boolean not null,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id, cry_path)
);
alter table public.cry_guesses enable row level security;   -- tout passe par les fonctions ci-dessous

update public.settings set value = value || '{"cryguess":[{"w":60,"kind":"new_commune"}, {"w":25,"kind":"pack"}, {"w":15,"kind":"ticket"}], "remask":[{"w":70,"kind":"new_commune"}, {"w":30,"kind":"pack"}]}'::jsonb
 where key = 'objective_loot' and not value ? 'cryguess';

-- cris à deviner : potes suivis qui ont un cri pas encore tenté ; 4 choix (le pote, d'autres potes, puis d'autres joueurs), mélangés
create or replace function public.cry_quiz()
returns table (friend_id uuid, cry_path text, choices jsonb)
language plpgsql volatile security definer set search_path = public as $$
declare f record; v_choices jsonb;
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  for f in select p.id, p.cry_path from public.follows w join public.profiles p on p.id = w.friend_id
            where w.user_id = auth.uid() and p.cry_path is not null
              and not exists (select 1 from public.cry_guesses g where g.user_id = auth.uid() and g.friend_id = p.id and g.cry_path = p.cry_path)
            order by random() limit 5 loop
    select jsonb_agg(jsonb_build_object('id', c.id, 'name', c.username) order by random()) into v_choices from (
      (select id, username from public.profiles where id = f.id)
      union all
      (select id, username from (
         select p.id, p.username, case when exists (select 1 from public.follows w where w.user_id = auth.uid() and w.friend_id = p.id) then 0 else 1 end k
           from public.profiles p where p.id not in (f.id, auth.uid()) and p.username is not null order by k, random() limit 3) d)) c;
    friend_id := f.id; cry_path := f.cry_path; choices := v_choices; return next;
  end loop;
end $$;
revoke execute on function public.cry_quiz() from public, anon;
grant execute on function public.cry_quiz() to authenticated;

-- deviner : un essai par cri ; trouvé = bonus pour moi, cri démasqué (notification) pour le pote
create or replace function public.cry_guess(p_friend uuid, p_pick uuid) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_path text; v_ok boolean; v_reward jsonb; v_name text := (select username from public.profiles where id = auth.uid());
begin
  if v_user is null then raise exception 'non connecté'; end if;
  if not exists (select 1 from public.follows where user_id = v_user and friend_id = p_friend) then raise exception 'pas dans tes potes'; end if;
  select cry_path into v_path from public.profiles where id = p_friend for update;
  if v_path is null then raise exception 'ce pote n''a pas de cri'; end if;
  if exists (select 1 from public.cry_guesses where user_id = v_user and friend_id = p_friend and cry_path = v_path) then raise exception 'cri déjà tenté'; end if;
  v_ok := p_pick = p_friend;
  insert into public.cry_guesses (user_id, friend_id, cry_path, correct) values (v_user, p_friend, v_path, v_ok);
  if not v_ok then return jsonb_build_object('correct', false); end if;
  v_reward := public.objective_reward(v_user, 'cryguess');
  if (select cry_unmasked_path from public.profiles where id = p_friend) is distinct from v_path then
    update public.profiles set cry_unmasked_by = v_user, cry_unmasked_path = v_path where id = p_friend;
    perform public.send_push(p_friend, 'Cri démasqué', coalesce(v_name, 'Un pote') || ' a reconnu ton cri. Enregistre-en un nouveau pour redevenir mystère.', 'autre',
                             'https://pittilloni.github.io/metalnini/proto/');
  end if;
  return jsonb_build_object('correct', true, 'reward', v_reward);
end $$;
revoke execute on function public.cry_guess(uuid, uuid) from public, anon;
grant execute on function public.cry_guess(uuid, uuid) to authenticated;

-- mon cri : démasqué par qui (tant que je ne l'ai pas refait)
create or replace function public.my_cry_status() returns text
language sql stable security definer set search_path = public as $$
  select u.username from public.profiles p join public.profiles u on u.id = p.cry_unmasked_by
   where p.id = auth.uid() and p.cry_unmasked_path is not null and p.cry_unmasked_path = p.cry_path;
$$;
revoke execute on function public.my_cry_status() from public, anon;
grant execute on function public.my_cry_status() to authenticated;

-- nouveau cri après un démasquage : petit bonus, une fois par démasquage
create or replace function public.claim_new_cry_bonus() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); p record;
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select * into p from public.profiles where id = v_user for update;
  if p.cry_unmasked_path is null or p.cry_path is null or p.cry_path = p.cry_unmasked_path then return null; end if;
  update public.profiles set cry_unmasked_path = null, cry_unmasked_by = null where id = v_user;
  return public.objective_reward(v_user, 'remask');
end $$;
revoke execute on function public.claim_new_cry_bonus() from public, anon;
grant execute on function public.claim_new_cry_bonus() to authenticated;
