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

1. **Un gabarit fixe par type de carte** (Artiste / Membre / Live / Album / Riff / Collector) — 6 layouts maximum, avec des zones fixes : image, nom, artiste, tag genre, marqueur de rareté, numéro d'édition, ligne de contexte. Le gabarit Membre ajoute une zone dédiée à l'instrument (guitare, basse, batterie, chant, clavier, etc.), qui sert aussi de méta pour le tri transversal par instrument.
2. **La rareté = une couche d'overlay appliquée sur le même gabarit**, pas un redesign : bordure, texture, effet foil/shimmer changent, la structure ne change jamais. 5 presets de rareté, réutilisables sur tous les types.
3. **Le sous-genre = un accent de cadre** (couleur de liseré + tag), pas un habillage différent.
4. **Le seul asset réellement sur-mesure par carte = le portrait de l'artiste.** Tout le reste (cadre, typo, effets de rareté, accent de genre) est systématique. En V1, ce portrait est **généré par IA** (pas une vraie photo de musicien réel) — cohérent avec les noms de groupes détournés retenus pour éviter les problèmes de droits (voir `CONCEPT.md`).

**Direction retenue pour le portrait : rendu réaliste + traitement graphique fixe.** Deux tests comparatifs ont été faits (illustration caricaturale plate vs portrait réaliste passé dans un traitement graphique) : c'est le second qui est retenu. Le portrait généré par IA reste réaliste, mais il est systématiquement passé dans un **filtre de post-traitement fixe et identique sur toutes les cartes** : duotone noir + rouge ember (couleur de marque de l'app, indépendante de la rareté et du sous-genre), trame halftone, grain épais, contraste poussé façon affiche sérigraphiée. C'est ce filtre — pas le rendu IA brut, trop variable d'une génération à l'autre — qui est la vraie source d'homogénéité : deux portraits générés séparément se ressemblent parce qu'ils traversent le même traitement, pas parce que l'IA produit un style constant par elle-même.

L'humour de la DA ("drôle", voir positionnement) doit se voir sur le portrait lui-même, pas seulement dans le nom détourné du groupe : un test sur "Sleeplot" (clin d'œil à Slipknot) a validé qu'un gag visuel simple — ici un masque de sommeil brodé "Zzz" à la place du masque effrayant, sur une silhouette par ailleurs reconnaissable (combinaison, patch numéroté, pose bras croisés) — porte bien le second degré même avec un rendu dramatique/réaliste. Le degré de ressemblance exact avec le vrai groupe reste un point à faire trancher par un juriste (voir risques dans `CONCEPT.md`).

Concrètement dans Figma : construire ça comme **un composant à variantes** (propriétés : Type × Rareté × Genre), lié aux variables de couleur/typo définies ci-dessus. Ajouter une nouvelle carte devient : déposer une photo + renseigner des métadonnées, jamais redessiner une carte. C'est aussi ce qui permettra, plus tard, une génération automatisée/scriptée des visuels de carte à partir d'une base de données (idée à garder dans `ROADMAP-IDEAS.md`).
