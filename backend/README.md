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

Statut : migration écrite, **pas encore exécutée sur une vraie base**.
