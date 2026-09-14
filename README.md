# Metalnini — Récapitulatif du projet

Le "Panini du metal/rock" : une app de collection de cartes d'artistes metal/rock, avec une couche vivante (évolution des cartes liée à l'actu réelle, avatar de fan lié au vécu en concert) et un volet social en troc pur (sans argent réel).

Ce dépôt sert à la fois de page de pitch (`index.html`, publiée via GitHub Pages) et de mémoire de travail pour le concept : chaque décision prise est documentée pour pouvoir reprendre le projet à tout moment sans tout re-discuter.

## Page de pitch

**https://pittilloni.github.io/metalnini/** — page de présentation (vision, mécaniques, craintes, sans jargon) créée pour recueillir les retours de proches (accès protégé par un mot de passe simple — filtre de politesse, pas une vraie confidentialité puisque ce dépôt public existe).

**https://pittilloni.github.io/metalnini/flows.html** — document de travail interne : les 8 user flows détaillés au niveau nécessaire pour wireframer. Volontairement non lié depuis la page de pitch (ce n'est pas un document destiné aux proches). Un bouton "Commenter" permet de laisser un commentaire positionné n'importe où sur la page (envoyé par mail via le même Web3Forms que le formulaire de la page de pitch).

## Documents

- **[docs/CONCEPT.md](docs/CONCEPT.md)** — le concept validé pour le MVP : boucle de jeu, système de cartes et raretés, mécanique d'évolution, volet social, avatar de fan/carnet de concerts, monétisation, risques identifiés.
- **[docs/DA.md](docs/DA.md)** — la direction artistique : chrome d'app monochrome et sobre, couleur réservée au système de rareté des cartes, typographie, et surtout le principe de gabarit paramétrique qui permet de produire des cartes à l'échelle sans tout redessiner à la main.
- **[docs/ARCHITECTURE-FLOWS.md](docs/ARCHITECTURE-FLOWS.md)** — l'architecture de navigation, l'inventaire des écrans, les parcours utilisateurs clés (onboarding, ouverture de pack, évolution de carte, concert/avatar, échange), les mécaniques d'engagement à pousser et les anti-patterns à éviter.
- **[flows.html](flows.html)** — les user flows détaillés (A→H) : étapes, embranchements, états limites et décisions encore à trancher, plus les règles transverses qui s'appliquent à tous les parcours, les boucles de rétention et la carte des animations. C'est le document de référence pour passer au wireframing.
- **[docs/ROADMAP-IDEAS.md](docs/ROADMAP-IDEAS.md)** — tout ce qui est volontairement écarté du MVP pour ne rien perdre : hybride physique (phase 2), marketplace monétaire écartée, pistes techniques de détection d'ambiance, monétisation future.

## Où en est-on

- Concept et architecture posés, considérés comme une base solide amenée à mûrir.
- Page de pitch en ligne pour recueillir les retours de proches, avec formulaire de réponse (texte + vocal).
- **User flows détaillés** (`flows.html`) : les 8 parcours clés sont écrits étape par étape, avec leurs embranchements, leurs états limites et les décisions non tranchées identifiées.
- **Trois décisions structurantes actées** : l'échange ne se fait qu'en présentiel (via un check-in concert ou un radar de proximité Bluetooth, jamais à distance) ; la détection/preuve de concert se fait par billet importé (électronique ou physique) plutôt que par croisement artistes suivis + agenda externe ; une couche **Missions** traverse désormais toutes les autres boucles pour donner une direction visible à l'utilisateur.
- **Architecture des boucles de rétention** posée (`flows.html` + `docs/ARCHITECTURE-FLOWS.md`, section 4) : 5 boucles à cadences différentes (pack quotidien, classeurs/guilde hebdo, actu artiste, concert, échange), plus un budget de notifications explicite pour éviter que leur cumul ne devienne du spam.
- **Carte des animations** posée (`docs/DA.md` + `flows.html`) : tous les moments clés classés en 3 niveaux — séquences majeures en state machine Rive (reveal, évolution, récompense, échange en direct, mission complétée), confirmations courtes (scan de billet, barre XP, carte bonus, highlight collection, radar, cri signature), micro-interactions standard. Rive retenu comme outil, compétence déjà acquise.
- Aucun écran n'a encore été maquetté.
- **Volet visuel en pause** : la direction tarot ne satisfait pas encore, les crédits de génération d'images sont épuisés, et aucune solution n'est trouvée sur les droits à l'image. La conception avance donc sur ce qui n'en dépend pas (flows, structure, décisions produit).

## Prochaines étapes possibles

- Trancher les décisions listées en fin de `flows.html` — en priorité : le trou laissé dans un classeur par une carte qui évolue, le sort des doublons non échangés, et binder unique vs classeurs par sous-genre.
- Spécifier les state machines Rive des 5 séquences majeures identifiées (niveau 1 de la carte des animations) une fois le gabarit de carte stabilisé.
- Wireframer en basse fidélité les écrans des flows A et B (onboarding et ouverture de pack), qui ne demandent aucun visuel de carte définitif.
- Recueillir et synthétiser les retours des proches sur la page de pitch.
- Reprendre la DA carte quand les droits à l'image et les moyens de génération seront débloqués ; le gabarit paramétrique de `docs/DA.md` reste valable indépendamment du style retenu.
