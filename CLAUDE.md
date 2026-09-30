# Metalnini — règles de travail

Projet perso (hors United Heroes) : collection de cartes de musiciens metal et rock. Prototype web `proto/`, admin `admin/`, back-end Supabase `backend/`, app iOS `ios/`.

## Code propre, toujours
- Après chaque changement, retirer le code mort : CSS, fonctions, éléments HTML et textes qui ne servent plus. Pas de code commenté laissé « au cas où » (l'historique git suffit).
- Suivre le style du fichier : vanilla JS en IIFE dans `proto/index.html`, commentaires courts en français, noms explicites.
- Pas de doublon de règles CSS ni de keyframes du même nom.

## Avant chaque push
- Tests du prototype : `node tools/test_proto.js` (tous OK, aucune erreur JS) ; tests iOS : `cd ios/Packages/MetalniniKit && swift test`.
- Toute modification d'interface est vérifiée en capture à taille téléphone (390 × 664 et 430 × 932) : rien de rogné, rien sous la barre d'onglets. Outil : `tools/capture/` (voir son README, fausse API en ligne incluse).
- Rien n'est poussé sans l'accord explicite du propriétaire ; le push sur `main` déploie tout seul (GitHub Pages) et les téléphones se mettent à jour d'eux-mêmes.
- Migrations SQL : un fichier numéroté dans `backend/supabase/migrations/`, appliqué puis vérifié.

## Design
- Référence : `design-system/metalnini/MASTER.md` (jetons, composants, checklist). La lire avant toute modification d'interface.
- Utiliser le skill `.claude/skills/ui-ux-pro-max` pour toute décision d'interface (accessibilité, tailles tactiles, typographie, mouvement). Ses recommandations génériques ne remplacent pas la DA des cartes.
- DA : celle des cartes (tarot gravé : noir d'encre, or chaud, os, rouge sang ; signature « collector arcade » : gothique Pirata One et gravure côté cartes, relief et crans côté jeu, Big Shoulders Display pour chiffres et boutons, Barlow pour le texte ; filets simples, jamais de double bordure). Moderne, sobre et élégant, jamais « site web » générique.
- Ton : UX writing rock'n'roll, drôle et clair (guide dans `concept.html`, onglet Direction artistique, Ligne édito). Une vanne par écran au plus ; l'action reste lisible.

## Sécurité
- Secrets uniquement dans le Trousseau macOS (`krea-api-perso`, `supabase-token`, `supabase-db-password`, `resend-api-key`, `gmail-smtp`, `vapid-private`, `push-secret`). Jamais dans le dépôt, jamais affichés.
- Côté client : seulement la clé publique Supabase. Toute règle de jeu est vérifiée côté serveur (RLS, fonctions `security definer`).

## Reprendre sur une autre machine
1. `git clone https://github.com/PITTILLONI/metalnini.git && cd metalnini`
2. Tests du prototype : `npm --prefix tools install`, puis `node tools/test_proto.js`.
3. Serveur local pour les vérifications visuelles : `python3 -m http.server 8765`, puis http://localhost:8765/proto/ ; captures à taille téléphone avec `tools/capture/shot.mjs` (Google Chrome requis, mode d'emploi dans `tools/capture/README.md`).
4. Secrets (Trousseau macOS, jamais dans le dépôt) : `tools/store_secret.sh <service>` pour `supabase-token`, `supabase-db-password`, `krea-api-perso`, `resend-api-key`, `gmail-smtp` (clé copiée dans le presse-papiers, à lancer dans un vrai Terminal). Seuls ceux dont on a besoin : `supabase-token` pour la base, `krea-api-perso` pour générer des cartes.
5. iOS : Xcode, puis `brew install xcodegen` (ou équivalent), `cd ios && xcodegen generate`.
6. Non versionné : le moodboard (`assets/da/moodboard/`, illustrations de tiers), les sons bruts (`sounds-raw/`).
7. La mémoire de Claude est propre à chaque machine : ce fichier, le README et `design-system/metalnini/MASTER.md` font foi. Les lire en premier.

## Où en est le projet
- En ligne : prototype https://pittilloni.github.io/metalnini/proto/, admin https://pittilloni.github.io/metalnini/admin/, concept https://pittilloni.github.io/metalnini/concept.html.
- Back-end Supabase `mdnevzmczljycmgbsrsu` : migrations 0001 à 0039 appliquées (0026 : échanges, 0027 : groupes favoris, 0028 : classeur du partenaire et demandes, 0029 : reprise d'un échange en cours, 0030 : cri du partenaire à la conclusion, 0031 : récompenses d'objectifs `claim_objective`, vérifiées par le serveur : classeur complété = 2 points de paquet, maîtrise = 1 Rare minimum, photo ou partage = 1 Commune nouvelle, 0032 : rôles d'admin Propriétaire / Admin, 0033 : récompenses variées tirées dans le réglage `objective_loot` (paquet, carte, ticket artiste prioritaire), le cri devient un objectif, 0034 : historique des échanges, potes `follows` (seulement après un échange), classeur d'un pote, échange proposé par notification `trade_invite`, 0035 : `partner_id` dans l'état d'un échange, 0036 : présence `touch_presence` (dernière visite, app installée, appareil) pour l'admin, 0037 : blind test `claim_blindtest` débloqué par chaque maîtrise, récompense selon le score (tables quiz3 / quiz4 / quiz5 de `objective_loot`), 0038 : blind test d'un classeur complété `claim_blindtest_binder`, 0039 : blind test des cris des potes `cry_quiz` / `cry_guess`, cri démasqué à refaire `claim_new_cry_bonus`) (depuis 0006, par l'API de gestion avec le seul `supabase-token` : `POST https://api.supabase.com/v1/projects/mdnevzmczljycmgbsrsu/database/query`, l'historique de la CLI s'arrête donc à 0005) ; 45 musiciens, 225 cartes.
- Cartes : 45 musiciens × 5 raretés. Recette Krea : Nano Banana Pro, photo de référence et style « The Priest ». Les raretés se déclinent avec `tools/krea_rarities.sh` ; `tools/build_proto_cards.py` fait les images allégées, `tools/build_gallery.py` la galerie, `tools/gen_seed.py` la seed. L'API Krea perso fonctionne sur un solde prépayé en dollars ; aucun point d'API ne donne ce solde, et une génération refusée en HTTP 402 veut dire qu'il faut recharger.
- Ajouter un artiste :
  1. Photo de référence publique, créditée dans `assets/da/CREDITS-photos.md`.
  2. Carte de base avec `tools/krea_generate.py` (Nano Banana Pro, photo + style The Priest).
  3. Les 5 raretés avec `tools/krea_rarities.sh <id> <url de la base> <his|her>`.
  4. `python3 tools/build_proto_cards.py`.
  5. Dans `proto/index.html` : `CARDS` (id, nom, groupe, titre d'arcane, numéro, instrument, sous-genre), `BINDERS` (style, et au besoin instrument et groupe), la bio courte `BIOS`, la bio longue `BIOS_LONG`, le coup spécial `MOVES` (titre et phrase) et l'extrait `TRACKS` (identifiant iTunes).
  6. Dans `ios/Packages/MetalniniKit/Sources/MetalniniKit/Catalog.swift`, puis `python3 tools/gen_seed.py` et application de la seed.
  7. Ajouter l'artiste à `export/bios-artistes-a-relire.md`.
  Les demandes des joueurs (`artist_requests`, priorité d'abord) et leurs groupes favoris (`profiles.fav_bands`) sont visibles dans l'admin ; il n'y en avait aucun le 2026-09-30.
- Interface (2026-09-30) : signature « collector arcade » appliquée à tous les écrans. Côté cartes : gothique, cadres gravés, sceaux, cierge. Côté jeu : relief, crans, coffre du butin. Détail et classes dans `design-system/metalnini/MASTER.md` ; maquettes de direction sur le canvas claude.ai https://claude.ai/artifact/14q1ykMpYActHdFWuuSt1W (privé, compte du propriétaire). Classeurs : la catégorie « Collection » est masquée tant qu'il n'y a qu'une collection ; « Toutes les cartes » reste la page de rangement.
- À confirmer sur iPhone (app installée) : la barre d'onglets reste en place sur Classeur (correctif `7099579`), et le joueur peut écouter son propre cri (correctif `d01df29`). À relire par le propriétaire : `export/bios-artistes-a-relire.md` (45 bios et 11 textes de style).
- En attente : TestFlight (inscription Apple Developer), inscription par e-mail dans l'app iOS, domaine d'e-mail dédié, paquets dédiés aux nouveaux styles, sons (en préparation par un ami : fiche `sons.html`, 46 sons nommés dont les variantes, PDF avec cases « Fait » dans `export/metalnini-sons.pdf`).
- Notifications : app installable (`proto/app.webmanifest`, `proto/sw.js`, push seulement, aucun cache hors ligne) ; abonnements dans `push_subscriptions`, envoi par la fonction serveur `send-push` (`backend/supabase/functions/`, déploiement `npx supabase functions deploy send-push --project-ref mdnevzmczljycmgbsrsu --no-verify-jwt --use-api`), appelée par la base (`send_push`, secret partagé dans Vault « push_secret » et en secret de fonction `PUSH_SECRET`, clés `VAPID_PUBLIC` / `VAPID_PRIVATE`). Déclencheurs : cadeaux de l'admin, rappel du paquet du jour (tâche pg_cron horaire « metalnini-daily-pack-push », heure réglée dans l'admin), annonces de l'admin (tableau de bord) ; budget par joueur et par jour (`push_daily_budget`, journal `push_log`, les tests ne comptent pas) ; bouton « Notification de test » sur la fiche joueur. Sur iPhone, seulement une fois l'app ajoutée à l'écran d'accueil.
- Sons : moteur Web Audio dans `proto/index.html` (musique de fond qui baisse pendant les révélations et se coupe pendant les extraits, jingles par rareté, sons de jeu et d'interface) ; fichiers MP3 dans `proto/sounds/`, déclarés dans `proto/sounds/manifest.js` (un son non déclaré reste muet, la vibration reste) ; liste et specs dans `sons.html` (source unique : `tools/sound_cues.json`, puis `python3 tools/build_sons.py` régénère la fiche, le banc d'essai et le PDF ; 46 sons, P1 d'abord ; variantes `nom-1`, `nom-2`… tirées au hasard par `sndPick`) ; banc d'essai `proto/?sons` ; réglages Musique et Effets sonores séparés. Jamais d'extrait de morceau existant.
- Extraits audio : aperçus officiels de 30 s via l'API iTunes (`TRACKS` dans `proto/index.html`, identifiant de morceau par carte), lecture automatique en fin de révélation (désactivable dans les réglages, « Extrait audio auto en fin de paquet »), à la main dans la fiche du classeur, toujours avec le lien Apple Music. Jamais de fichier audio hébergé.
- Échange (v1, onglet Metal Corner) : session par code de 6 caractères (QR ou lien, à distance autorisé), fonctions `trade_*` (tout ou rien, validation liée à une version), temps réel sur `trades` (canal `postgres_changes`, sondage toutes les 4 s en secours), carte bonus au premier échange avec un fan (`trade_bonuses`). QR : `qrcode-generator`, lecture : `BarcodeDetector` sinon `jsQR` (jsDelivr, chargés à la demande).
- Mises à jour : le workflow Pages remplace `BUILD = '__BUILD__'` par le commit et publie `proto/version.json` ; l'app compare au lancement, au retour au premier plan et toutes les 10 min, puis se recharge seule dès que rien n'est en cours (adresse `?v=…` pour contourner les caches). Rien à faire à la main : chaque push est propagé.
- Équipe d'admin : onglet « Admins » de l'admin ; rôles `owner` (tout, y compris nommer et retirer) et `admin` (le reste) ; nomination par la fonction serveur `admin-invite` (compte existant nommé tout de suite, sinon invitation Supabase avec le modèle `backend/supabase/templates/invite.html`, l'invité choisit son mot de passe puis active la double authentification) ; déploiement `npx supabase functions deploy admin-invite --project-ref mdnevzmczljycmgbsrsu --no-verify-jwt --use-api` (la fonction vérifie elle-même `is_owner`).
- Icônes : Tabler Icons (MIT) copiées en SVG dans la page ; Game-icons.net (CC BY 3.0, crédit obligatoire) pour le décoratif.
- Backlog : « Blind test des growls » (retrouver des growls célèbres), sous réserve de licences ou de réinterprétations ; carte en fond d'écran de téléphone ; détail dans le README.
