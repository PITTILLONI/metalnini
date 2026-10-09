-- Metalnini — l'équipe d'admin est prévenue de ce qui l'attend : une carte perso prête à valider, un artiste préparé par l'agent
-- (à trancher, prêt à publier ou en erreur). Notification sur chaque appareil abonné d'un admin, hors budget quotidien ;
-- le lien ouvre la bonne section de l'admin.

create or replace function public.notify_admins(p_title text, p_body text, p_url text) returns void
language plpgsql volatile security definer set search_path = public as $$
declare a record;
begin
  for a in select user_id from public.admins loop
    perform public.send_push(a.user_id, p_title, p_body, 'admin', p_url, true);
  end loop;
end $$;
revoke execute on function public.notify_admins(text, text, text) from public, anon, authenticated;

create or replace function public.perso_order_notify() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status in ('ready', 'error') and new.status is distinct from old.status then
    perform public.notify_admins(case when new.status = 'ready' then 'Carte perso à valider' else 'Carte perso en erreur' end,
      'La carte de ' || coalesce(new.nickname, 'un joueur') || case when new.status = 'ready' then ' est prête : à toi de la valider.' else ' n''a pas pu être faite : relance ou refuse.' end,
      'https://pittilloni.github.io/metalnini/admin/#envoyer/perso');
  end if;
  return new;
end $$;
drop trigger if exists perso_order_notify on public.perso_orders;
create trigger perso_order_notify after update of status on public.perso_orders for each row execute function public.perso_order_notify();

create or replace function public.artist_job_notify() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status in ('review', 'ready', 'error') and new.status is distinct from old.status then
    perform public.notify_admins(new.artist || case new.status when 'ready' then ' : prêt à publier' when 'review' then ' : à trancher' else ' : erreur' end,
      case new.status when 'ready' then 'L''agent a préparé les cartes. Relis et publie.'
                      when 'review' then 'L''agent a besoin de ta décision avant de continuer.'
                      else 'L''agent n''a pas pu terminer. Regarde son compte rendu.' end,
      'https://pittilloni.github.io/metalnini/admin/#catalogue/demandes');
  end if;
  return new;
end $$;
drop trigger if exists artist_job_notify on public.artist_jobs;
create trigger artist_job_notify after update of status on public.artist_jobs for each row execute function public.artist_job_notify();
