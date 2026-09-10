# Metalnini — Récapitulatif du projet

Le "Panini du metal/rock" : une app de collection de cartes d'artistes metal/rock, avec une couche vivante (évolution des cartes liée à l'actu réelle, avatar de fan lié au vécu en concert) et un volet social en troc pur (sans argent réel).

Ce dépôt sert à la fois de page de pitch (`index.html`, publiée via GitHub Pages) et de mémoire de travail pour le concept : chaque décision prise est documentée pour pouvoir reprendre le projet à tout moment sans tout re-discuter.

## Page de pitch

**https://pittilloni.github.io/metalnini/** — page de présentation (vision, mécaniques, craintes, sans jargon) créée pour recueillir les retours de proches (accès protégé par un mot de passe simple — filtre de politesse, pas une vraie confidentialité puisque ce dépôt public existe).

## Documents

- **[docs/CONCEPT.md](docs/CONCEPT.md)** — le concept validé pour le MVP : boucle de jeu, système de cartes et raretés, mécanique d'évolution, volet social, avatar de fan/carnet de concerts, monétisation, risques identifiés.
- **[docs/DA.md](docs/DA.md)** — la direction artistique : chrome d'app monochrome et sobre, couleur réservée au système de rareté des cartes, typographie, et surtout le principe de gabarit paramétrique qui permet de produire des cartes à l'échelle sans tout redessiner à la main.
- **[docs/ARCHITECTURE-FLOWS.md](docs/ARCHITECTURE-FLOWS.md)** — l'architecture de navigation, l'inventaire des écrans, les parcours utilisateurs clés (onboarding, ouverture de pack, évolution de carte, concert/avatar, échange), les mécaniques d'engagement à pousser et les anti-patterns à éviter.
- **[docs/ROADMAP-IDEAS.md](docs/ROADMAP-IDEAS.md)** — tout ce qui est volontairement écarté du MVP pour ne rien perdre : hybride physique (phase 2), marketplace monétaire écartée, pistes techniques de détection d'ambiance, monétisation future.

## Où en est-on

- Concept et architecture posés, considérés comme une base solide amenée à mûrir.
- Page de pitch en ligne pour recueillir les retours de proches.
- Aucun écran n'a encore été maquetté (Figma) : l'étape encore jugée prématurée tant que l'architecture et les mécaniques ne sont pas éprouvées.

## Prochaines étapes possibles

- Recueillir et synthétiser les retours des proches sur la page de pitch.
- Détailler un flow précis en bas-fidélité avant tout maquettage visuel complet.
- Construire le composant carte à variantes (Type × Rareté × Genre) dans Figma une fois le template validé, en s'appuyant sur `docs/DA.md`.
