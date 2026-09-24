# Metalnini — back-end (Supabase)

Base Postgres gérée par Supabase. Le serveur décide de tout ce qui a de la valeur : l'app lit ses propres données et appelle des fonctions, elle n'écrit jamais directement dans les tables.

| Fichier | Contenu |
|---|---|
| `supabase/migrations/0001_init.sql` | Schéma v1 : comptes et admins, catalogue (musiciens, cartes, classeurs, types de paquets, probabilités, réglages), inventaire, ouvertures de paquets tracées, journal admin ; droits d'accès (RLS) ; fonctions `open_pack` (tirage serveur, idempotent, limite quotidienne), `place_card`, `fuse_cards`, `admin_adjust_card`, `admin_set_blocked` (motif obligatoire, journalisées). |
| `supabase/seed.sql` | Données de départ générées depuis le catalogue Swift : `python3 tools/gen_seed.py` (ne pas modifier à la main). |

## Mise en place (à faire)

1. Créer un projet sur supabase.com (région UE), récupérer l'URL et la clé publique (`anon`) — la clé `service_role` ne doit jamais aller dans l'app ni dans ce dépôt public.
2. Appliquer la migration puis le seed (éditeur SQL de Supabase, ou `supabase db push` avec la CLI).
3. Activer Sign in with Apple et l'e-mail dans l'authentification.
4. Se déclarer admin : `insert into public.admins (user_id) values ('<ton id utilisateur>');`

## Statut (2026-09-24)

Projet Supabase **METALNINI** (`mdnevzmczljycmgbsrsu`, région eu-central-1, Postgres 17), relié au dépôt avec la CLI (`npx supabase`). Migration `0001_init.sql` et seed **appliqués** (`supabase db push --include-seed`).

Vérifié sur la vraie base, avec deux joueurs fictifs dans une transaction annulée :

| Contrôle | Résultat |
|---|---|
| Catalogue | 18 musiciens, 90 cartes, 11 classeurs, 6 paquets, probabilités |
| Droits d'accès | RLS active sur toutes les tables |
| `open_pack` | 5 cartes tirées, inventaire mis à jour |
| Rejeu du même appel | même paquet renvoyé, une seule ouverture enregistrée |
| Écriture directe dans l'inventaire | refusée (RLS) |
| Fonction admin appelée par un joueur | refusée |
| Fusion d'une Légendaire | refusée |
| Un joueur qui se débloque lui-même | refusé |
| Profil créé à l'inscription, rangement | OK |
| Un joueur voit l'inventaire d'un autre | non (0 ligne) |

## Espace admin

Application web statique (`admin/index.html`, publiée sur GitHub Pages), qui n'utilise que la clé publique : toute la sécurité est côté serveur.

- **Accès** : compte e-mail + mot de passe, **double authentification TOTP obligatoire**, et présence dans `public.admins`. `is_admin()` exige une session de niveau `aal2` (migration `0002_admin.sql`).
- **Écrans** : tableau de bord (joueurs, paquets ouverts, raretés observées ou réglées), joueurs (inventaire, ajustement de cartes, blocage), paquets et probabilités, réglages (coût de fusion, paquets par jour), catalogue, journal.
- **Journal** : chaque écriture admin exige un motif et s'inscrit dans `admin_audit_log` ; les éditions du catalogue sont journalisées par déclencheur ; les probabilités et réglages ne se modifient que par fonction.

Vérifié sur la base : admin sans double authentification refusé ; réglage des probabilités journalisé ; motif vide refusé ; écriture directe sur les probabilités sans effet ; statistiques disponibles ; non-admin refusé.

## Commandes

Les secrets sont dans le Trousseau macOS (jamais dans le dépôt) :

```sh
cd backend
export SUPABASE_ACCESS_TOKEN="$(security find-generic-password -s supabase-token -w)"
export SUPABASE_DB_PASSWORD="$(security find-generic-password -s supabase-db-password -w)"
npx supabase migration list          # état des migrations
npx supabase db push                 # appliquer les nouvelles migrations
```

Pour enregistrer ou changer un secret : `tools/store_secret.sh supabase-token` (ou `supabase-db-password`).
