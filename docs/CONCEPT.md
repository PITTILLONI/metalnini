# Metalnini — Concept produit (MVP)

## Positionnement
Le "Panini du metal/rock" : une collection de cartes numériques d'artistes, à ouvrir en packs, collectionner et échanger — avec une couche vivante connectée à l'actualité réelle des artistes et à l'expérience vécue en concert. Cible : la communauté metal/rock, soudée, nerd, très attachée à l'authenticité et au vécu live.

**En V1, les groupes/artistes ne sont pas les vrais noms/vraies photos** : noms détournés (parodiques, humoristiques) et portraits générés par IA dans un style homogène, le temps de sécuriser de vrais accords de licence (voir risques ci-dessous et `ROADMAP-IDEAS.md`). Les noms restent **volontairement reconnaissables** — jeu de mots proche du vrai nom plutôt qu'univers totalement abstrait (ex. "Sleeplot" pour Slipknot, "Knocked Foot" pour Bigfoot… liste à étoffer) — ce qui maximise l'effet clin d'œil pour la communauté mais renforce d'autant le risque de confusion évoqué plus bas. Chaque groupe fictif est **calqué en coulisses sur un vrai groupe/scène réel** (mapping interne, jamais exposé au joueur) dont Metalnini suit l'actualité réelle, pour que la mécanique d'évolution de carte reste basée sur de vrais événements et non sur un calendrier fabriqué (voir `Mécanique d'évolution des cartes`).

## Ce que Metalnini n'est pas
- Pas un jeu de combat/versus.
- Pas une marketplace monétaire (aucune revente de carte contre argent réel).
- Pas un produit physique au lancement (packs physiques, merch, NFC/QR sur objet : reporté, voir `ROADMAP-IDEAS.md`).

## Boucle de jeu centrale (MVP)
1. Ouvrir un pack (gratuit régulier + payant + gagné en event) → reveal animé.
2. Compléter des collections thématiques (par artiste, sous-genre, époque, festival) — et transversalement par musicien ou par instrument.
3. Une carte peut **évoluer** quand un événement réel se produit chez l'artiste (sortie d'album, clip, date de concert, anniversaire).
4. Échanger des cartes avec d'autres fans (troc pur, sans argent réel).
5. Vivre un concert → nourrir son **avatar de fan** et son **carnet de concerts**.

## Système de cartes
- **Types** : Artiste, Membre (musicien), Live, Album, Riff/Moment culte (clip, extrait), Collector (édition limitée événement).
- **Rareté** : Commune → Rare → Holo/Prisme → Signature (numérotée) → Légendaire (série ultra-limitée).
- Traitement graphique différencié par rareté (texture, foil, bordure), identité graphique déclinée par sous-genre.

**Carte Membre (musicien)** — dédiée à un membre précis d'un groupe (nom, instrument, rôle). Elle porte une métadonnée `instrument` (guitare, basse, batterie, chant, clavier, etc.) et peut être rattachée à plusieurs groupes (side-projects, supergroupes, remplacements — fréquent dans le metal). Elle ouvre un axe de collection **transversal**, indépendant du regroupement par groupe :
- Collection "par musicien" : retrouver toutes les cartes liées à un même musicien à travers ses différents groupes.
- Collection "par instrument" : par exemple, collectionner les batteurs ou les bassistes suivis, tous groupes confondus.

## Classeurs & récompenses
- **Classeurs officiels (thématiques)** — les collections de la boucle de jeu (par artiste, sous-genre, époque, festival). Compléter un classeur officiel déclenche une récompense **garantie, non aléatoire** : carte Collector cosmétique dédiée + badge de complétion visible sur le profil. Aucun avantage compétitif ni monétaire — uniquement cosmétique/statutaire, cohérent avec l'absence de marketplace.
- **Paliers d'avatar (niveaux)** — franchir un palier d'XP avatar (cumulé sur les 3 sources : collection, vécu concert, profil de spectateur) débloque un nouveau trait/emplacement de personnalisation cosmétique de l'avatar, et occasionnellement un pack gratuit. Nombre de paliers et coût XP à calibrer en phase de game design, hors scope de ce document.
- **Classeurs personnalisés** — en plus des classeurs officiels, chaque utilisateur peut créer ses propres classeurs libres : sélection manuelle parmi les cartes qu'il possède déjà, nommage libre, réordonnancement (ex. "Mes riffs cultes", "Ma tournée 2025"). Ils alimentent la vitrine de profil public (voir Volet social) mais ne déclenchent **aucune récompense de complétion propre** — un classeur custom étant défini par l'utilisateur lui-même (parfois réduit à une seule carte), le récompenser créerait une boucle triviale à exploiter. Seuls les classeurs officiels comptent pour les récompenses.

## Mécanique d'évolution des cartes
Les cartes changent d'état suite à un flux d'actualité artiste réel — celle du **vrai groupe mappé** derrière chaque groupe fictif, retranscrite sur la carte sous son identité détournée (nom, portrait IA) :
- Carte "Artiste" → devient carte "Album" à la sortie d'un nouvel album (celui du vrai groupe mappé).
- Carte "Live" → variante spéciale débloquée si l'utilisateur était présent au concert concerné (scan/check-in géolocalisé) — le concert réel de l'utilisateur, indépendant du mapping.
- Événements calendaires (anniversaire d'un album culte, reformation, etc.) déclenchent des drops commémoratifs limités dans le temps.

**Maintien du mapping** : associer et tenir à jour le lien groupe fictif ↔ groupe réel est un travail éditorial continu (curation manuelle et/ou flux externe — RSS metal news, API type Songkick/Bandsintown pour les dates de concert — à cadrer). C'est aussi ce qui conditionne le rythme de contenu, au même titre qu'un accord de licence classique.

## Volet social (troc, pas de marché)
- Échange carte contre carte (1-to-1 ou en lot), avec éventuellement une valeur symbolique de rareté pour équilibrer les échanges — **jamais convertible en argent réel**.
- Guildes/clans par groupe ou sous-genre.
- Classements de collection (par artiste, par festival, global).
- Vitrine de profil public (le "book" à montrer), incluant les classeurs personnalisés mis en avant (voir `Classeurs & récompenses`).

## Avatar de fan & carnet de concerts
Chaque utilisateur a un avatar personnel qui évolue selon **trois sources combinées**, pas seulement le vécu live : sa collection de cartes, son vécu de concerts réels, et son profil de spectateur déclaré.

**Source 1 — Collection de cartes**
Diversité de sous-genres/groupes suivis, rareté moyenne possédée, thèmes complétés, diversité d'instruments collectionnés via les cartes Membre : nourrit des traits d'identité de collectionneur sur l'avatar (ex. sous-genre dominant affiché).

**Source 2 — Vécu de concert (double mécanisme de captation)**
- **Jauge d'ambiance semi-automatique** : si la précision technique le permet, utilisation de l'accéléromètre/gyroscope du téléphone pendant le concert pour estimer un niveau d'énergie/intensité vécu (à valider par un spike technique — la détection fine d'un pogo vs un wall of death n'est pas garantie, mais un niveau d'intensité global est plausible).
- **Déclaratif (toujours disponible, socle du MVP)** : après le concert, l'utilisateur note son expérience — ambiance, musique, sono, intensité du mosh pit, etc. Ce carnet de concerts a une valeur en soi (journal de ses shows vécus), indépendamment de l'avatar.

**Source 3 — Profil de spectateur**
Agrégation dans le temps du comportement déclaré en concert (pogo, calme, air guitar, chanteur, photographe, etc.) en un "type" de spectateur dominant, affiché sur l'avatar et affiné au fil des shows plutôt que figé dès le premier concert.

**Progression de l'avatar**
Traits visuels et titres/achievements déblocables selon le vécu cumulé sur ces trois sources, par exemple (liste ouverte, à affiner) :
- Titres d'ambiance : "Roi du pogo", "As des airs" (air guitar), etc.
- Titres sociaux : "Metal Corner" (a échangé/discuté avec d'autres fans sur place).
- Titres de fidélité/découverte : nombre de concerts vus, diversité de sous-genres/artistes vus, ancienneté sur un artiste.
- Titres de collectionneur : ex. "Puriste" (collection ultra-concentrée sur un seul sous-genre), "Multi-instrumentiste" (cartes Membre collectionnées dans de nombreux instruments différents).

## Monétisation (MVP)
- Vente de packs digitaux (achat direct + monnaie in-app).
- Partenariats labels/artistes/festivals pour du contenu exclusif sponsorisé.
- **Aucune commission sur échange/revente** (le troc n'est pas un marché monétaire).

## Risques / points à faire trancher par des tiers compétents
- **Cadre légal loot-box** : mécaniques de pack aléatoire payant régulées dans certains pays — à valider par un juriste avant tout modèle payant.
- **Droits à l'image / musicaux** : contournés en V1 par des noms de groupes détournés (parodiques) et des portraits générés par IA plutôt que de vraies photos — mais la parodie n'est pas un blanc-seing légal (risque de confusion/évocation trop proche d'un vrai groupe), **d'autant plus que chaque groupe fictif calque 1:1 le calendrier d'actu réel d'un vrai groupe** (mécanique d'évolution) : plus le mapping colle à l'actu réelle, plus l'argument "parodie/œuvre indépendante" s'affaiblit face à un usage non autorisé déguisé. À faire valider par un juriste avant lancement, y compris sur le degré de détournement acceptable. De vrais noms/photos sous licence restent l'objectif une fois des accords labels/artistes sécurisés (voir `ROADMAP-IDEAS.md`).
- **Fiabilité de la détection capteur** : à valider par un spike technique avant de committer sur la jauge d'ambiance automatique ; le déclaratif doit rester le socle robuste dans tous les cas.

## Statut
Concept validé comme base de travail pour la suite (direction visuelle, puis maquettage). Les idées écartées du MVP ou à explorer plus tard sont conservées dans `ROADMAP-IDEAS.md` pour ne rien perdre.
