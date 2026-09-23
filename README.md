# Metalnini — Récapitulatif du projet

Le "Panini du metal/rock" : une app de collection de cartes d'artistes metal/rock, avec une couche vivante (évolution des cartes liée à l'actu réelle, avatar de fan lié au vécu en concert) et un volet social en troc pur (sans argent réel).

Ce dépôt sert à la fois de page de pitch (`index.html`, publiée via GitHub Pages) et de mémoire de travail pour le concept : chaque décision prise est documentée pour pouvoir reprendre le projet à tout moment sans tout re-discuter.

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

**V1 perso des cartes** (décision du 2026-09-23) : artistes reconnaissables, usage strictement perso. Les cartes de `assets/da/creas/` sont publiées dans le dépôt public et s'affichent en ligne (choix du 2026-09-23, pour y accéder depuis plusieurs machines). Le moodboard (`assets/da/moodboard/`) reste local car il contient des illustrations de tiers. `export/metalnini-cartes.html` est une galerie autonome à envoyer directement. Générées avec `tools/krea_generate.py` (API REST Krea, clé lue dans le Trousseau macOS).

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

## Prochaines étapes possibles

- **Feature 1 à développer : ouverture de paquet + visualisation du classeur** (décision du 2026-09-23, détail dans l'onglet Roadmap de `concept.html`). Avant de coder : trancher taille de paquet, probabilités par rareté, statut de la carte « de base », composition des deux classeurs de test et stack du prototype.
- Compléter le catalogue de test : 10 à 12 artistes déclinés sur les 5 raretés (8 générés et déclinés à ce jour).
- Trancher les décisions listées en fin de `flows.html` — en priorité : le trou laissé dans un classeur par une carte qui évolue, le sort des doublons non échangés, et binder unique vs classeurs par sous-genre.
- Spécifier les state machines Rive des 5 séquences majeures identifiées (niveau 1 de la carte des animations) une fois le gabarit de carte stabilisé.
- Wireframer en basse fidélité les écrans de la feature 1 (Flow B et Collection), puis ceux du Flow A.
- Recueillir et synthétiser les retours des proches sur la page de pitch.
- Identifier une première liste de têtes d'affiche "ancres" et de leurs contacts professionnels (label, management) pour amorcer la stratégie droits à l'image posée dans l'onglet Roadmap de `concept.html`.
