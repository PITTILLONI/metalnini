-- Metalnini — la capacité de metaleux peut être un texte perso (anecdote de concert) : jusqu'à 120 caractères.
alter table public.profiles drop constraint if exists metal_power_len;
alter table public.profiles add constraint metal_power_len check (metal_power is null or char_length(metal_power) between 2 and 120);

create or replace function public.set_metal_power(p_power text) returns text
language plpgsql security definer set search_path = public as $$
declare v text := nullif(trim(p_power), '');
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  if v is not null and char_length(v) not between 2 and 120 then raise exception 'capacité : 2 à 120 caractères'; end if;
  insert into public.profiles (id, metal_power) values (auth.uid(), v) on conflict (id) do update set metal_power = excluded.metal_power;
  return v;
end $$;
