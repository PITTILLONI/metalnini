# Metalnini — Direction artistique (DA)

## Principe directeur
**Le chrome de l'app est monochrome. Toute la couleur est réservée aux cartes.**
Aucune couleur vive n'est utilisée dans la navigation, les boutons, les fonds ou les composants UI génériques — ils restent noir/blanc/gris. Ça garantit que l'œil va systématiquement à la carte à l'écran, et ça évite l'écueil "app metal = néon partout" qui fatiguerait vite visuellement.

*Point ouvert depuis le pivot vers une direction carte "tarot vintage" (voir plus bas) :* ce principe suppose une carte qui contraste avec un chrome sombre neutre. Une carte à dominante parchemin/chaude peut très bien fonctionner par contraste sur fond noir (comme une carte de tarot posée sur une table sombre) — mais reste à valider en contexte réel d'écran, pas seulement sur une carte isolée.

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
4. **Le seul asset réellement sur-mesure par carte = le portrait de l'artiste.** Tout le reste (cadre, typo, effets de rareté, accent de genre) est systématique. Ce portrait est **généré par IA à partir de photos réelles** (pas une vraie photo directement) — état actuel du choix noms/portraits détaillé dans `CONCEPT.md`, avec ses risques associés.

**Direction retenue : carte façon tarot vintage.** Deux directions de portrait ont d'abord été testées (illustration caricaturale plate, puis portrait réaliste + traitement graphique duotone/halftone) avant qu'une référence moodboard (tarot occulte vintage) ne remette en cause le cadre de carte lui-même, pas seulement le portrait. C'est cette troisième direction qui est retenue : cadre parchemin aux coins arrondis, linework façon gravure ancienne, palette rétro sourde (moutarde, bleu pétrole, brique, vert sauge), numéro d'édition en chiffre romain, motifs célestes (soleil, étoiles) en zones fixes du gabarit, cartouche de nom en bas — une déclinaison directe du gabarit paramétrique déjà posé (zones fixes, seul le portrait/personnage change).

L'humour de la DA ("drôle", voir positionnement) doit se voir sur le portrait/la carte, pas seulement passer par un nom détourné : un premier test sur "Sleeplot" (clin d'œil à Slipknot, à l'époque où l'option nom détourné était encore envisagée) a validé qu'un gag visuel simple — ici un masque de sommeil brodé "Zzz" à la place du masque effrayant — porte bien le second degré dans ce cadre vintage, à l'image des jeux de mots sur les arcanes du moodboard de référence (ex. "The Iron Maiden"). Un second test avec le vrai nom "Landmvrks" confirme que l'effet "vraie carte de collection" est nettement plus fort avec un vrai nom affiché qu'avec un nom détourné — un des éléments qui a fait pencher la décision vers les vrais noms (voir `CONCEPT.md`). Un troisième test, à partir d'une photo réelle du chanteur (Florent Salfati) utilisée comme référence, montre qu'une vraie ressemblance est atteignable dans ce même cadre tarot sans perdre le style — mais le degré de ressemblance exact du portrait reste un point à faire trancher par un juriste (voir risques dans `CONCEPT.md`).

**Homogénéité de cette direction** : contrairement au rendu réaliste testé avant (où l'homogénéité dépendait d'un filtre de post-traitement fixe), le format tarot est intrinsèquement homogène — bordure, numérotation, motifs célestes et cartouche sont des zones fixes du gabarit au même titre que les autres types de carte, pas un effet à recalibrer à chaque génération.

Concrètement dans Figma : construire ça comme **un composant à variantes** (propriétés : Type × Rareté × Genre), lié aux variables de couleur/typo définies ci-dessus. Ajouter une nouvelle carte devient : déposer une photo + renseigner des métadonnées, jamais redessiner une carte. C'est aussi ce qui permettra, plus tard, une génération automatisée/scriptée des visuels de carte à partir d'une base de données (idée à garder dans `ROADMAP-IDEAS.md`).

## Motion

**Outil retenu : Rive**, sur la base d'une compétence déjà acquise par le porteur de projet — pas de dépendance externe à trouver pour animer l'app. Tous les moments listés ci-dessous restent dans le même principe directeur que le reste de la DA : les effets riches (foil, shimmer, particules) sont réservés à ces moments précis, jamais au chrome d'app autour.

Classement par le soin que chaque moment demande, pas par ordre d'apparition dans l'app (détail des flows dans `ARCHITECTURE-FLOWS.md` et `flows.html`) :

**Niveau 1 — Séquences majeures** (state machine à plusieurs variables exposées à l'app) :
1. **Reveal de pack** (Flow B) — rareté et type de carte pilotent la scène ; le moment le plus chargé émotionnellement de l'app, et le seul endroit où les effets riches sont autorisés.
2. **Évolution de carte** (Flow C) — avant/après, doit rester lisible même joué en rafale pour un utilisateur qui revient avec plusieurs évolutions en attente.
3. **Récompense de complétion / palier avatar** (Flow F) — dans l'esprit du reveal mais plus court : un aboutissement, pas une découverte.
4. **Composition en direct, à deux** (Flow G) — le swap atomique d'un échange vu simultanément sur les deux téléphones ; conclusion physique d'une vraie rencontre, mérite le même soin que le reveal.
5. **Mission complétée** (Flow H) — probablement une variante courte de l'interstitiel du Flow F plutôt qu'un artboard entièrement nouveau, à confirmer une fois le Flow F construit.

**Niveau 2 — Confirmations & feedback courts** (Rive plus simple, timeline ou peu de variables) :
- **Scan de billet réussi** (Flow D) — feedback de détection instantané ; la confiance dans un geste caméra en dépend directement.
- **Barre XP qui se remplit** (Flow D, F, H) — motif réutilisable partout où l'XP change.
- **Carte bonus de connexion "Metal Corner"** (Flow G) — version allégée du reveal, une seule carte.
- **Nouvelle carte qui "atterrit" en Collection**, avec highlight (Flow B).
- **Blips du radar de proximité** (Flow G) — fans qui apparaissent/disparaissent à l'écran ; de l'ambiance plus qu'un moment fort.
- **Waveform du cri enregistré** (profil) — cosmétique, mais colle directement à la ligne édito "drôle" du positionnement (voir `CONCEPT.md`).

**Niveau 3 — Micro-interactions** : sélection de tuiles (onboarding), nudges de classeur presque complet, transitions entre les 5 sections de navigation — du polish d'interface standard, pas de state machine Rive dédiée à prévoir pour ceux-là.

Le détail des state machines de niveau 1 (déclencheurs, variables exposées — rareté, type de carte, palier atteint) est à spécifier une fois le gabarit de carte lui-même stabilisé, puisque l'animation de reveal doit piloter les mêmes zones fixes (bordure, overlay de rareté, portrait) que le gabarit statique.
