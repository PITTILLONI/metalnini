-- Metalnini — groupes favoris déclarés à l'onboarding (5 au plus) : l'admin les voit regroupés pour choisir les prochaines cartes.

alter table public.profiles add column if not exists fav_bands text[] not null default '{}';

-- le joueur connecté enregistre ses groupes favoris (remplace la liste précédente)
create or replace function public.set_fav_bands(p_bands text[]) returns void
language plpgsql volatile security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v text[];
begin
  if v_user is null then raise exception 'non connecté'; end if;
  select coalesce(array_agg(b order by n), '{}') into v from (
    select min(n) n, (array_agg(b order by n))[1] b from (
      select trim(x) b, n from unnest(coalesce(p_bands, '{}')) with ordinality as u(x, n) where length(trim(x)) between 2 and 60) s
    group by lower(b)) d;
  if cardinality(v) > 5 then v := v[1:5]; end if;
  update public.profiles set fav_bands = v where id = v_user;
end $$;
revoke execute on function public.set_fav_bands(text[]) from public, anon;
grant execute on function public.set_fav_bands(text[]) to authenticated;

-- admin : groupes cités, les plus cités d'abord, avec leur présence au catalogue
create or replace function public.admin_fav_bands() returns table (band text, fans int, in_catalog boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'réservé à l''admin'; end if;
  return query
    select (array_agg(b))[1], count(distinct p.id)::int,
           exists (select 1 from public.musicians m where lower(m.band) = lower(min(b)) or lower(m.name) = lower(min(b)))
      from public.profiles p, unnest(p.fav_bands) b
     group by lower(b) order by 2 desc, 1;
end $$;
revoke execute on function public.admin_fav_bands() from public, anon;
grant execute on function public.admin_fav_bands() to authenticated;
