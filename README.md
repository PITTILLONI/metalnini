# Metalnini — Récapitulatif du projet

Le "Panini du metal/rock" : une app de collection de cartes d'artistes metal/rock, avec une couche vivante (évolution des cartes liée à l'actu réelle, avatar de fan lié au vécu en concert) et un volet social en troc pur (sans argent réel).

Ce dépôt sert à la fois de page de pitch (`index.html`, publiée via GitHub Pages) et de mémoire de travail pour le concept : chaque décision prise est documentée pour pouvoir reprendre le projet à tout moment sans tout re-discuter.

## Liens en ligne

| Quoi | Lien | Accès |
|---|---|---|
| **Prototype jouable** (ouverture de paquets + classeur) | https://pittilloni.github.io/metalnini/proto/ | Libre, marche sur téléphone (ajout à l'écran d'accueil possible) |
| **Galerie des cartes** (18 musiciens et leurs raretés) | https://pittilloni.github.io/metalnini/export/metalnini-cartes.html | Libre, à partager |
| **Document concept** (Concept, Direction artistique, Architecture, Roadmap) | https://pittilloni.github.io/metalnini/concept.html | Mot de passe |
| Direction artistique des cartes | https://pittilloni.github.io/metalnini/concept.html#da-exemples-crea | Mot de passe |
| Roadmap, architecture et phases | https://pittilloni.github.io/metalnini/concept.html#roadmap-architecture | Mot de passe |
| **User flows** détaillés | https://pittilloni.github.io/metalnini/flows.html | Mot de passe |
| **Page de pitch** (pour les proches) | https://pittilloni.github.io/metalnini/ | Mot de passe |
| **Espace admin** (catalogue, paquets et probabilités, joueurs, statistiques, journal) | https://pittilloni.github.io/metalnini/admin/ | Compte admin + double authentification |
| Dépôt GitHub | https://github.com/PITTILLONI/metalnini | Public |

Le mot de passe n'est qu'un filtre de politesse : le dépôt est public, tout son contenu est lisible sur GitHub.

## Page de pitch

**https://pittilloni.github.io/metalnini/** — page de présentation (vision, mécaniques, craintes, sans jargon) créée pour recueillir les retours de proches (accès protégé par un mot de passe simple — filtre de politesse, pas une vraie confidentialité puisque ce dépôt public existe).

**https://pittilloni.github.io/metalnini/flows.html** — document de travail interne : les 8 user flows détaillés au niveau nécessaire pour wireframer. Volontairement non lié depuis la page de pitch (ce n'est pas un document destiné aux proches). Un bouton "Commenter" permet de laisser un commentaire positionné n'importe où sur la page (envoyé par mail via le même Web3Forms que le formulaire de la page de pitch).

## Documents

**[concept.html](concept.html)** — le document de référence unique, en onglets (même mot de passe que les autres pages) :
- **Concept** — le concept validé pour le MVP : boucle de jeu, système de cartes et raretés, mécanique d'évolution, volet social, avatar de fan/carnet de concerts, missions, monétisation, risques identifiés.
- **Direction artistique** — ligne édito, moodboard, exemples de créa (générés avec Krea), brief de génération, puis le système visuel déjà acté : chrome monochrome, couleur réservée aux raretés, typographie, gabarit paramétrique, motion.
- **Architecture** — navigation, inventaire des écrans, parcours clés, boucles de rétention, budget de notifications, anti-patterns.
- **Roadmap** — tout ce qui est volontairement écarté du MVP, et la stratégie droits à l'image pour l'ouverture publique.

**[flows.html](flows.html)** — les user flows détaillés (A→H) : étapes, embranchements, états limites et décisions encore à trancher, plus les règles transverses, les boucles de rétention et la carte des animations. C'est le document de référence pour passer au wireframing.

Les images de l'onglet Direction artistique se déposent dans `assets/da/moodboard/` et `assets/da/creas/`, sous les noms indiqués sur chaque case : elles s'affichent automatiquement.

**V1 perso des cartes** (décision du 2026-09-23) : artistes reconnaissables, usage strictement perso. Les cartes de `assets/da/creas/` sont publiées dans le dépôt public et s'affichent en ligne (choix du 2026-09-23, pour y accéder depuis plusieurs machines). Le moodboard (`assets/da/moodboard/`) reste local car il contient des illustrations de tiers. `export/metalnini-cartes.html` est la galerie à partager : régénérer les images avec `python3 tools/build_proto_cards.py`, puis la galerie avec `python3 tools/build_gallery.py`. Générées avec `tools/krea_generate.py` (API REST Krea, clé lue dans le Trousseau macOS).

## Où en est-on

- Concept et architecture posés, considérés comme une base solide amenée à mûrir.
- Page de pitch en ligne pour recueillir les retours de proches, avec formulaire de réponse (texte + vocal).
- **User flows détaillés** (`flows.html`) : les 8 parcours clés sont écrits étape par étape, avec leurs embranchements, leurs états limites et les décisions non tranchées identifiées.
- **Trois décisions structurantes actées** : l'échange ne se fait qu'en présentiel (via un check-in concert ou un radar de proximité Bluetooth, jamais à distance) ; la détection/preuve de concert se fait par billet importé (électronique ou physique) plutôt que par croisement artistes suivis + agenda externe ; une couche **Missions** traverse désormais toutes les autres boucles pour donner une direction visible à l'utilisateur.
- **Architecture des boucles de rétention** posée (`flows.html` + `concept.html`, onglet Architecture) : 5 boucles à cadences différentes (pack quotidien, classeurs/guilde hebdo, actu artiste, concert, échange), plus un budget de notifications explicite pour éviter que leur cumul ne devienne du spam.
- **Carte des animations** posée (`concept.html`, onglet Direction artistique + `flows.html`) : tous les moments clés classés en 3 niveaux — séquences majeures en state machine Rive (reveal, évolution, récompense, échange en direct, mission complétée), confirmations courtes (scan de billet, barre XP, carte bonus, highlight collection, radar, cri signature), micro-interactions standard. Rive retenu comme outil, compétence déjà acquise.
- Aucun écran n'a encore été maquetté.
- **Stratégie droits à l'image posée** (`concept.html`, onglet Roadmap) : plutôt que viser l'accord de tous les groupes avant d'ouvrir, le plan réduit la ressemblance des portraits par défaut (socle Sleeplot, pas Landmvrks photo-guidé), puis vise un catalogue de lancement construit autour de quelques têtes d'affiche reconnues (le jeu perd son sens sans pointures du metal/rock), atteintes via les canaux professionnels plutôt qu'en démarchage direct. Les vrais noms ne bougent pas dans ce plan. Reste un vrai avis d'avocat à obtenir avant toute ouverture publique, même limitée.
- **Direction artistique des cartes relancée** (2026-09-23) : moodboard Krea, référence principale « The Priest » (gravure gothique), recette validée (Nano Banana Pro + photo de l'artiste + référence de style), déclinaison des 5 raretés testée sur Knocked Loose, cartes Jinjer et Spiritbox. Coûts suivis dans l'onglet Direction artistique de `concept.html` (section « Coûts de génération ») : 0,15 $ par image, environ 0,75 $ par artiste décliné sur 5 raretés.

- **Timeline de la roadmap** (2026-09-25) : frise des 8 phases avec ce qui est fait et ce qui reste, en tête de l'onglet Roadmap de `concept.html` (phase 0 en cours, phases 1 et 2 validées sur le prototype web, à porter en natif).

## Prochaines étapes possibles

- **Backlog : carte en fond d'écran** (idée du 2026-09-25). Depuis la fiche d'une carte possédée, générer une image au format téléphone (9:19,5, marges pour l'horloge et les widgets de l'écran verrouillé) et la proposer au téléchargement ou au partage ; sur iOS natif, ouvrir directement la feuille de partage pour « Utiliser comme fond d'écran ». Même réserve que le partage : usage perso des visuels d'artistes.
- **Backlog : « Blind test des growls »** (idée du 2026-09-25). Une fonctionnalité où le joueur doit reconnaître des growls et cris célèbres (quel chanteur, quel morceau), avec récompense en cartes ou en progression. Prérequis : les extraits de morceaux connus sont protégés, même très courts ; il faut soit des licences (labels, éditeurs), soit des réinterprétations enregistrées pour l'occasion, soit des extraits fournis par les artistes eux-mêmes. À caler avec la stratégie droits de l'onglet Roadmap de `concept.html`.
- **À changer avant d'ouvrir à plus de monde : l'expéditeur des e-mails** (décision du 2026-09-24). Les e-mails de compte (confirmation, mot de passe oublié) partent pour l'instant de l'adresse Gmail perso du créateur via le SMTP de Gmail (limite d'environ 500 e-mails par jour). À remplacer par un domaine dédié (ex. `metalnini.fr`, environ 10 € par an) vérifié dans Resend, dont le SMTP est déjà configuré dans Supabase et la clé rangée dans le Trousseau (`resend-api-key`).
- **App iOS : passer à l'inscription par e-mail** (ou Sign in with Apple) : les comptes anonymes sont désactivés côté serveur depuis le 2026-09-24, une nouvelle installation passe donc en mode hors ligne.
- **Phase 0 démarrée (2026-09-24)** : app iOS native (`ios/`, SwiftUI, iOS 17, logique de jeu testée dans `MetalniniKit`) et back-end Supabase (`backend/`, schéma v1, droits d'accès, tirage serveur). Reste à créer le projet Supabase, y appliquer la migration, puis brancher l'app dessus.
- **Architecture actée (2026-09-24)** : iOS natif (SwiftUI) d'abord, Android ensuite, back-end managé, espace admin web séparé ; 8 phases détaillées dans l'onglet Roadmap de `concept.html`, en commençant par la phase 0 (fondations).
- **Feature 1 à développer : ouverture de paquet + visualisation du classeur** (décision du 2026-09-23, détail dans l'onglet Roadmap de `concept.html`). Avant de coder : trancher taille de paquet, probabilités par rareté, statut de la carte « de base », composition des deux classeurs de test et stack du prototype.
- Compléter le catalogue de test : 10 à 12 artistes déclinés sur les 5 raretés (18 musiciens générés et déclinés, 90 cartes jouables : cible dépassée).
- Trancher les décisions listées en fin de `flows.html` — en priorité : le trou laissé dans un classeur par une carte qui évolue, le sort des doublons non échangés, et binder unique vs classeurs par sous-genre.
- Spécifier les state machines Rive des 5 séquences majeures identifiées (niveau 1 de la carte des animations) une fois le gabarit de carte stabilisé.
- Wireframer en basse fidélité les écrans de la feature 1 (Flow B et Collection), puis ceux du Flow A.
- Recueillir et synthétiser les retours des proches sur la page de pitch.
- Identifier une première liste de têtes d'affiche "ancres" et de leurs contacts professionnels (label, management) pour amorcer la stratégie droits à l'image posée dans l'onglet Roadmap de `concept.html`.
