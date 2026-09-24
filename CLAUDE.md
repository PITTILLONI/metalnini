# Metalnini — règles de travail

Projet perso (hors United Heroes) : collection de cartes de musiciens metal et rock. Prototype web `proto/`, admin `admin/`, back-end Supabase `backend/`, app iOS `ios/`.

## Code propre, toujours
- Après chaque changement, retirer le code mort : CSS, fonctions, éléments HTML et textes qui ne servent plus. Pas de code commenté laissé « au cas où » (l'historique git suffit).
- Suivre le style du fichier : vanilla JS en IIFE dans `proto/index.html`, commentaires courts en français, noms explicites.
- Pas de doublon de règles CSS ni de keyframes du même nom.

## Avant chaque push
- Tests du prototype : `NODE_PATH=<dossier jsdom> node tools/test_proto.js` (tous OK, aucune erreur JS).
- Toute modification d'interface est vérifiée en capture à taille téléphone (390 × 664 et 430 × 932) : rien de rogné, rien sous la barre d'onglets.
- Migrations SQL : un fichier numéroté dans `backend/supabase/migrations/`, appliqué puis vérifié.

## Design
- Utiliser le skill `.claude/skills/ui-ux-pro-max` pour toute décision d'interface (accessibilité, tailles tactiles, typographie, mouvement).
- DA : celle des cartes (tarot gravé : noir d'encre, or, os, rouge sang ; titres Cinzel ; doubles filets or). Moderne et élégant, jamais « site web » générique.
- Ton : UX writing rock'n'roll, drôle et clair (guide dans `concept.html`, onglet Direction artistique, Ligne édito). Une vanne par écran au plus ; l'action reste lisible.

## Sécurité
- Secrets uniquement dans le Trousseau macOS (`krea-api-perso`, `supabase-token`, `supabase-db-password`, `resend-api-key`, `gmail-smtp`). Jamais dans le dépôt, jamais affichés.
- Côté client : seulement la clé publique Supabase. Toute règle de jeu est vérifiée côté serveur (RLS, fonctions `security definer`).
