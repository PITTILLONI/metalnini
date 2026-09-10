# Metalnini — Direction artistique (DA)

## Principe directeur
**Le chrome de l'app est monochrome. Toute la couleur est réservée aux cartes.**
Aucune couleur vive n'est utilisée dans la navigation, les boutons, les fonds ou les composants UI génériques — ils restent noir/blanc/gris. Ça garantit que l'œil va systématiquement à la carte à l'écran, et ça évite l'écueil "app metal = néon partout" qui fatiguerait vite visuellement.

## Palette
**Chrome UI (neutre, sobre)** — inspiré d'une DA "photo studio" pur noir/blanc :
- Background : `#000000` (noir OLED)
- Surface/carte de fond (hors carte-jeu) : `#0C0C0C` / `#121212`
- Foreground : `#FAFAFA`
- Muted foreground : `#94A3B8`
- Border : `#3F3F46` (rgba(255,255,255,0.08) en overlay)
- Destructive : `#EF4444` (usage fonctionnel uniquement — erreurs)

**Couleur = système de rareté** (seule source de couleur saturée de l'app, portée par les cartes) :
- Commune : gris acier `#71717A`
- Rare : bleu froid `#3B82F6`
- Holo/Prisme : dégradé iridescent (teal → violet → rose, effet shimmer animé)
- Signature : or métallique `#D4AF37`
- Légendaire : rouge sombre profond + foil noir `#7F1D1D` / holo noir

**Accent de sous-genre** (discret, limité au liseré de cadre + tag, jamais au fond) :
- Black metal : bleu glacial
- Death metal : rouge sang
- Thrash : jaune/orange
- Nu-metal : orange industriel
- Prog : violet
- Rock/hard rock classique : ambre/bronze

## Typographie
- **Display** (titres, noms d'artiste/groupe) : condensée, bold, esprit affiche de concert — ex. Barlow Condensed ou Oswald.
- **Corps/UI** : sans-serif neutre et très lisible — Inter.
- **Meta cartes** (numéro d'édition, stats, code de rareté) : monospace — JetBrains Mono ou IBM Plex Mono, esprit "fine print" de carte à collectionner.

## Style
Dark mode sobre, content-first, chrome plat sans effet (pas de skeuomorphisme, pas de glow décoratif hors carte). Les seuls effets visuels riches (texture foil, grain, shimmer holographique) sont réservés aux cartes elles-mêmes — jamais à l'interface autour.

## Le vrai enjeu : générer des cartes à l'échelle, de façon homogène
La réponse n'est pas "designer chaque carte à la main", c'est un **système de template paramétrique** :

1. **Un gabarit fixe par type de carte** (Artiste / Live / Album / Riff / Collector) — 5 layouts maximum, avec des zones fixes : image, nom, artiste, tag genre, marqueur de rareté, numéro d'édition, ligne de contexte.
2. **La rareté = une couche d'overlay appliquée sur le même gabarit**, pas un redesign : bordure, texture, effet foil/shimmer changent, la structure ne change jamais. 5 presets de rareté, réutilisables sur tous les types.
3. **Le sous-genre = un accent de cadre** (couleur de liseré + tag), pas un habillage différent.
4. **Le seul asset réellement sur-mesure par carte = la photo/illustration de l'artiste.** Tout le reste (cadre, typo, effets de rareté, accent de genre) est systématique.

Concrètement dans Figma : construire ça comme **un composant à variantes** (propriétés : Type × Rareté × Genre), lié aux variables de couleur/typo définies ci-dessus. Ajouter une nouvelle carte devient : déposer une photo + renseigner des métadonnées, jamais redessiner une carte. C'est aussi ce qui permettra, plus tard, une génération automatisée/scriptée des visuels de carte à partir d'une base de données (idée à garder dans `ROADMAP-IDEAS.md`).
