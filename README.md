# Metalnini — Récapitulatif du projet

Le "Panini du metal/rock" : une app de collection de cartes d'artistes metal/rock, avec une couche vivante (évolution des cartes liée à l'actu réelle, avatar de fan lié au vécu en concert) et un volet social en troc pur (sans argent réel).

Ce dépôt sert à la fois de page de pitch (`index.html`, publiée via GitHub Pages) et de mémoire de travail pour le concept : chaque décision prise est documentée pour pouvoir reprendre le projet à tout moment sans tout re-discuter.

## Liens en ligne

| Quoi | Lien | Accès |
|---|---|---|
| **Prototype jouable** (paquets, classeurs, Metal Corner, échanges) | https://pittilloni.github.io/metalnini/proto/ | Libre, marche sur téléphone (ajout à l'écran d'accueil possible) |
| **Galerie des cartes** (45 musiciens et leurs raretés) | https://pittilloni.github.io/metalnini/export/metalnini-cartes.html | Libre, à partager |
| **Document concept** (Concept, Direction artistique, Architecture, Roadmap) | https://pittilloni.github.io/metalnini/concept.html | Mot de passe |
| Direction artistique des cartes | https://pittilloni.github.io/metalnini/concept.html#da-exemples-crea | Mot de passe |
| Roadmap, architecture et phases | https://pittilloni.github.io/metalnini/concept.html#roadmap-architecture | Mot de passe |
| **User flows** détaillés | https://pittilloni.github.io/metalnini/flows.html | Mot de passe |
| **Page de pitch** (pour les proches) | https://pittilloni.github.io/metalnini/ | Mot de passe |
| **Espace admin** (catalogue, paquets et probabilités, joueurs, statistiques, journal) | https://pittilloni.github.io/metalnini/admin/ | Compte admin + double authentification |
| Maquettes des directions d'interface (canvas) | https://claude.ai/artifact/14q1ykMpYActHdFWuuSt1W | Privé, compte claude.ai du propriétaire |
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

**[design-system/metalnini/MASTER.md](design-system/metalnini/MASTER.md)** — le système de design de l'interface : jetons, typo, composants, signature « collector arcade », liste « À ne pas faire », parcours écran par écran.

**[tools/capture/](tools/capture/README.md)** — captures du prototype à taille téléphone, avec une fausse API en ligne.

**[flows.html](flows.html)** — les user flows détaillés (A→H) : étapes, embranchements, états limites et décisions encore à trancher, plus les règles transverses, les boucles de rétention et la carte des animations. C'est le document de référence pour passer au wireframing.

Les images de l'onglet Direction artistique se déposent dans `assets/da/moodboard/` et `assets/da/creas/`, sous les noms indiqués sur chaque case : elles s'affichent automatiquement.

**V1 perso des cartes** (décision du 2026-09-23) : artistes reconnaissables, usage strictement perso. Les cartes de `assets/da/creas/` sont publiées dans le dépôt public et s'affichent en ligne (choix du 2026-09-23, pour y accéder depuis plusieurs machines). Le moodboard (`assets/da/moodboard/`) reste local car il contient des illustrations de tiers. `export/metalnini-cartes.html` est la galerie à partager : régénérer les images avec `python3 tools/build_proto_cards.py`, puis la galerie avec `python3 tools/build_gallery.py`. Générées avec `tools/krea_generate.py` (API REST Krea, clé lue dans le Trousseau macOS).

## Où en est-on

État au 2026-09-30. Le détail technique à jour est dans `CLAUDE.md`, section « Où en est le projet ».

- **Prototype jouable en ligne** : https://pittilloni.github.io/metalnini/proto/, installable sur l'écran d'accueil, avec comptes, tirage côté serveur et mise à jour automatique.
  - Paquets du jour (Standard 5 cartes, Mini 2 cartes).
  - Révélation et rangement dans les classeurs (styles, instruments, groupes).
  - Fiche de chaque carte : maîtrise des 5 raretés, transformation des doublons, bio, coup spécial, extrait audio.
- **Metal Corner** :
  - échanges entre potes, par QR code, lien ou code, à distance autorisé ;
  - potes suivis et historique des échanges ;
  - objectifs à récompenses variées : paquet, carte, ticket artiste prioritaire ;
  - blind tests (par maîtrise, par classeur, et sur les cris des potes) ;
  - chemin des titres.
- **Interface** : signature « collector arcade », validée le 2026-09-30.
  - Côté cartes : gothique, cadres gravés, sceaux et cierge.
  - Côté jeu : boutons en relief, jauges à crans, coffre du butin.
  - Référence : `design-system/metalnini/MASTER.md`.
- **Admin** (https://pittilloni.github.io/metalnini/admin/) : joueurs, échanges, demandes d'artistes, groupes favoris, équipe d'admins (rôles Propriétaire et Admin, invitation par e-mail).
- **Catalogue** : 45 musiciens × 5 raretés, générés avec Krea (Nano Banana Pro, style « The Priest »), pour un usage strictement perso (décision du 2026-09-23).
- **Sons** : 46 sons spécifiés (`sons.html`, PDF dans `export/`), en préparation par un ami musicien ; le moteur les joue dès qu'ils sont déposés dans `proto/sounds/`.
- **App iOS native** (`ios/`, SwiftUI) : logique de jeu testée, en retard sur le prototype web.
- **Documents de conception** : concept, architecture et roadmap dans `concept.html`, parcours dans `flows.html`. Certaines décisions d'origine ont évolué avec le prototype, par exemple l'échange à distance, désormais autorisé.

## Prochaines étapes possibles

- **À confirmer sur iPhone** :
  - la barre d'onglets reste en place sur Classeur, dans l'app installée ;
  - le joueur peut écouter son propre cri.
- **À relire** : `export/bios-artistes-a-relire.md` (45 bios et 11 textes de style).
- **Ajouter des artistes** : si le solde Krea le permet ; marche à suivre dans `CLAUDE.md`.
- **Réglages** : remplacer les cases à cocher natives par des interrupteurs dans la DA.
- **Sons** : intégrer les fichiers de l'ami musicien au fur et à mesure (cocher « Fait » dans la fiche).
- **App iOS** : inscription par e-mail (ou Sign in with Apple), puis TestFlight après l'inscription Apple Developer.
- **Avant d'ouvrir à plus de monde** : expéditeur d'e-mails dédié. Les e-mails partent aujourd'hui du Gmail perso, avec une limite d'environ 500 par jour.
- **Paquets dédiés aux nouveaux styles.**
- **Backlog** :
  - carte en fond d'écran de téléphone ;
  - « Blind test des growls », sous réserve de licences.
