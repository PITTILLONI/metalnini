-- Metalnini — changer de pseudo (une fois par semaine) et refus des pseudos haineux : racistes, antisémites, sexistes,
-- homophobes, transphobes, apologie du nazisme ou des violences sexuelles. La liste est vérifiée par le serveur, sur le
-- pseudo sans accents ni ponctuation, et aussi lu en « leet » (4 = a, 3 = e, 0 = o…) ; l'admin peut la compléter.

create table if not exists public.username_blocklist (term text primary key check (term ~ '^[a-z0-9]{3,}$'));
alter table public.username_blocklist enable row level security;
drop policy if exists username_blocklist_admin on public.username_blocklist;
create policy username_blocklist_admin on public.username_blocklist for all to authenticated using (public.is_admin()) with check (public.is_admin());

insert into public.username_blocklist (term) values
  -- racisme
  ('nigger'), ('nigga'), ('negro'), ('negre'), ('negresse'), ('bougnoul'), ('bougnoule'), ('bicot'), ('chintok'), ('chinetoque'),
  ('bamboula'), ('sandnigger'), ('chink'), ('gook'), ('wetback'), ('youpin'), ('youtre'), ('kike'),
  -- nazisme, suprémacisme
  ('nazi'), ('hitler'), ('heil'), ('siegheil'), ('1488'), ('14words'), ('kkk'), ('kukluxklan'), ('whitepower'), ('whitepride'), ('aryan'),
  ('aryen'), ('gaschamber'), ('chambreagaz'), ('auschwitz'), ('holocaust'), ('shoah'), ('juden'), ('sieg88'), ('ss88'),
  -- sexisme, violences sexuelles
  ('salope'), ('connasse'), ('pouffiasse'), ('slut'), ('whore'), ('bitch'), ('violeur'), ('rapist'), ('pedophil'), ('pedophile'),
  -- homophobie, transphobie
  ('pede'), ('pedale'), ('tapette'), ('tarlouze'), ('tafiole'), ('fiotte'), ('gouine'), ('travelo'), ('faggot'), ('dyke'), ('tranny'),
  ('shemale')
on conflict do nothing;

-- le pseudo est-il refusé ? (forme brute et forme leet comparées à la liste)
create or replace function public.username_banned(p text) returns boolean
language sql stable security definer set search_path = public as $$
  with n as (select regexp_replace(translate(lower(coalesce(p, '')), 'áàâäãåéèêëíìîïóòôöõúùûüçñ', 'aaaaaaeeeeiiiiooooouuuucn'), '[^a-z0-9]', '', 'g') as raw)
  select exists (select 1 from public.username_blocklist b, n
                  where position(b.term in n.raw) > 0 or position(b.term in translate(n.raw, '013457', 'oieast')) > 0)
$$;
revoke execute on function public.username_banned(text) from public, anon, authenticated;

-- avant l'inscription : pseudo libre et accepté ? null si oui, sinon la raison
create or replace function public.username_problem(p_username text) returns text
language plpgsql stable security definer set search_path = public as $$
declare v text := trim(coalesce(p_username, ''));
begin
  if v !~ '^[A-Za-z0-9_.-]{3,20}$' then return 'pseudo invalide : 3 à 20 caractères, lettres, chiffres, point, tiret ou tiret bas'; end if;
  if public.username_banned(v) then return 'ce pseudo ne passe pas la sécurité : pas de haine dans le pit'; end if;
  if exists (select 1 from public.profiles where lower(username) = lower(v) and id is distinct from auth.uid()) then return 'ce pseudo est déjà pris'; end if;
  return null;
end $$;
revoke execute on function public.username_problem(text) from public;
grant execute on function public.username_problem(text) to anon, authenticated;

alter table public.profiles add column if not exists username_changed_at timestamptz;

-- choisir ou changer son pseudo ; renvoie le pseudo enregistré
create or replace function public.set_username(p_username text) returns text
language plpgsql security definer set search_path = public as $$
declare v text := trim(p_username); v_err text; v_old text; v_at timestamptz;
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  v_err := public.username_problem(v);
  if v_err is not null then raise exception '%', v_err; end if;
  select username, username_changed_at into v_old, v_at from public.profiles where id = auth.uid();
  if v_old = v then return v; end if;
  if v_old is not null and v_at > now() - interval '7 days' then
    raise exception 'un seul changement de pseudo par semaine : prochain possible le %', to_char((v_at + interval '7 days') at time zone 'Europe/Paris', 'DD/MM à HH24"h"MI');
  end if;
  insert into public.profiles (id, username) values (auth.uid(), v)
    on conflict (id) do update set username = excluded.username, username_changed_at = case when public.profiles.username is null then null else now() end;
  return v;
end $$;
grant execute on function public.set_username(text) to authenticated;
