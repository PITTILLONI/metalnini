# Metalnini — règles de travail

Projet perso (hors United Heroes) : collection de cartes de musiciens metal et rock. Prototype web `proto/`, admin `admin/`, back-end Supabase `backend/`, app iOS `ios/`.

## Code propre, toujours
- Après chaque changement, retirer le code mort : CSS, fonctions, éléments HTML et textes qui ne servent plus. Pas de code commenté laissé « au cas où » (l'historique git suffit).
- Suivre le style du fichier : vanilla JS en IIFE dans `proto/index.html`, commentaires courts en français, noms explicites.
- Pas de doublon de règles CSS ni de keyframes du même nom.

## Avant chaque push
- Tests du prototype : `node tools/test_proto.js` (tous OK, aucune erreur JS) ; tests iOS : `cd ios/Packages/MetalniniKit && swift test`.
- Toute modification d'interface est vérifiée en capture à taille téléphone (390 × 664 et 430 × 932) : rien de rogné, rien sous la barre d'onglets.
- Migrations SQL : un fichier numéroté dans `backend/supabase/migrations/`, appliqué puis vérifié.

## Design
- Référence : `design-system/metalnini/MASTER.md` (jetons, composants, checklist). La lire avant toute modification d'interface.
- Utiliser le skill `.claude/skills/ui-ux-pro-max` pour toute décision d'interface (accessibilité, tailles tactiles, typographie, mouvement). Ses recommandations génériques ne remplacent pas la DA des cartes.
- DA : celle des cartes (tarot gravé : noir d'encre, or chaud, os, rouge sang ; titres Big Shoulders Display, interface Inter ; filets simples, jamais de double bordure). Moderne, sobre et élégant, jamais « site web » générique.
- Ton : UX writing rock'n'roll, drôle et clair (guide dans `concept.html`, onglet Direction artistique, Ligne édito). Une vanne par écran au plus ; l'action reste lisible.

## Sécurité
- Secrets uniquement dans le Trousseau macOS (`krea-api-perso`, `supabase-token`, `supabase-db-password`, `resend-api-key`, `gmail-smtp`). Jamais dans le dépôt, jamais affichés.
- Côté client : seulement la clé publique Supabase. Toute règle de jeu est vérifiée côté serveur (RLS, fonctions `security definer`).

## Reprendre sur une autre machine
1. `git clone https://github.com/PITTILLONI/metalnini.git && cd metalnini`
2. Tests du prototype : `npm --prefix tools install`, puis `node tools/test_proto.js`.
3. Serveur local pour les vérifications visuelles : `python3 -m http.server 8765`, puis http://localhost:8765/proto/ (Chrome requis pour les captures).
4. Secrets (Trousseau macOS, jamais dans le dépôt) : `tools/store_secret.sh <service>` pour `supabase-token`, `supabase-db-password`, `krea-api-perso`, `resend-api-key`, `gmail-smtp` (clé copiée dans le presse-papiers, à lancer dans un vrai Terminal). Seuls ceux dont on a besoin : `supabase-token` pour la base, `krea-api-perso` pour générer des cartes.
5. iOS : Xcode, puis `brew install xcodegen` (ou équivalent), `cd ios && xcodegen generate`.
6. Non versionné : le moodboard (`assets/da/moodboard/`, illustrations de tiers), les sons bruts (`sounds-raw/`).

## Où en est le projet
- En ligne : prototype https://pittilloni.github.io/metalnini/proto/, admin https://pittilloni.github.io/metalnini/admin/, concept https://pittilloni.github.io/metalnini/concept.html.
- Back-end Supabase `mdnevzmczljycmgbsrsu` : migrations 0001 à 0016 appliquées ; 38 musiciens, 190 cartes.
- Cartes : recette Krea (Nano Banana Pro, photo de référence + style « The Priest ») ; raretés avec `tools/krea_rarities.sh` ; images allégées avec `tools/build_proto_cards.py`, galerie avec `tools/build_gallery.py`, seed avec `tools/gen_seed.py`.
- En attente : TestFlight (inscription Apple Developer), inscription par e-mail dans l'app iOS, domaine d'e-mail dédié, paquets dédiés aux nouveaux styles, musique de fond (piste libre de droits à choisir), sons de révélation (cris enregistrés ou banques CC0, jamais d'extraits de morceaux).
- Backlog : « Blind test des growls » (retrouver des growls célèbres), sous réserve de licences ou de réinterprétations ; carte en fond d'écran de téléphone ; détail dans le README.
