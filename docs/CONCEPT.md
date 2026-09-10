# Metalnini — Concept produit (MVP)

## Positionnement
Le "Panini du metal/rock" : une collection de cartes numériques d'artistes, à ouvrir en packs, collectionner et échanger — avec une couche vivante connectée à l'actualité réelle des artistes et à l'expérience vécue en concert. Cible : la communauté metal/rock, soudée, nerd, très attachée à l'authenticité et au vécu live.

**Ligne édito : humour, fun, moderne, gamifié.** Ce ton n'est pas décoratif, il traverse plusieurs décisions déjà actées : le format carte (tarot vintage — voir `DA.md`) qui porte l'humour par le jeu de mots et le gag visuel plutôt que par l'exagération, et un système de progression assumé comme du jeu plutôt qu'une simulation sérieuse (classeurs, paliers, récompenses garanties — voir `Classeurs & récompenses`).

**État actuel (provisoire) sur les noms et portraits** : après hésitation entre noms détournés (parodiques) et vrais noms, le choix pour l'instant est d'utiliser **directement les vrais noms de groupes/musiciens**, avec des cartes façon tarot dont l'apparence se rapproche des vrais musiciens (à partir de photos) — cf. test "Landmvrks". Raison du choix : l'authenticité d'un vrai groupe pèse plus lourd sur l'engagement qu'une parodie, aussi réussie soit-elle, pour une communauté dont le positionnement repose justement sur l'authenticité et le vécu réel.

**Ce choix n'est tenable que tant que l'usage reste privé** (pas de diffusion publique ni commerciale) — voir le risque détaillé plus bas. Une solution doit être trouvée (accords de licence, ou autre approche) avant toute ouverture publique, même limitée ; jusque-là, aucune évolution de carte n'a besoin d'un mapping caché : le "vrai groupe" et le "groupe affiché" sont un seul et même groupe (voir `Mécanique d'évolution des cartes`).

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
Les cartes changent d'état suite à un flux d'actualité artiste réel — directement celle du vrai groupe affiché sur la carte (plus de mapping caché tant que noms et portraits sont ceux du vrai groupe) :
- Carte "Artiste" → devient carte "Album" à la sortie d'un nouvel album.
- Carte "Live" → variante spéciale débloquée si l'utilisateur était présent au concert concerné (scan/check-in géolocalisé).
- Événements calendaires (anniversaire d'un album culte, reformation, etc.) déclenchent des drops commémoratifs limités dans le temps.

**Suivi de l'actualité réelle** : un travail éditorial continu (curation manuelle et/ou flux externe — RSS metal news, API type Songkick/Bandsintown pour les dates de concert — à cadrer) reste nécessaire pour détecter ces événements. C'est aussi ce qui conditionne le rythme de contenu.

## Volet social (troc, pas de marché)
- Échange carte contre carte (1-to-1 ou en lot), avec éventuellement une valeur symbolique de rareté pour équilibrer les échanges — **jamais convertible en argent réel**.
- Guildes/clans par groupe ou sous-genre.
- Classements de collection (par artiste, par festival, global).
- Vitrine de profil public (le "book" à montrer), incluant les classeurs personnalisés mis en avant (voir `Classeurs & récompenses`).

## Rencontres en concert (présence partagée)
Le check-in concert (voir `Avatar de fan & carnet de concerts`) devient aussi un **levier social en direct**, pas seulement un marqueur pour l'avatar — c'est le pendant "IRL" du troc à distance déjà décrit dans `Volet social` :
- **Présence partagée, opt-in et réciproque** : au moment du check-in, l'utilisateur peut choisir d'apparaître dans une liste éphémère "Fans présents ce soir", visible uniquement par les autres fans ayant eux aussi activé cette option pour ce même concert. Pas de liste publique par défaut, pas d'historique de localisation conservé au-delà de l'événement — cohérent avec l'anti-pattern déjà posé sur la géolocalisation continue.
- **Échange en direct** : depuis cette liste, un fan peut proposer un échange de cartes à un autre fan présent, sans repasser par la recherche globale de `Communauté` — même mécanique de confirmation mutuelle que l'échange classique, juste plus rapide d'accès sur place.
- **Carte bonus de connexion** : la première rencontre confirmée mutuellement avec un autre fan lors d'un même concert (échange conclu, ou simple "on s'est croisés" confirmé des deux côtés) débloque une **carte bonus garantie, non aléatoire** — même logique de récompense que les classeurs/paliers (voir `Classeurs & récompenses`). Ça donne enfin un contenu concret au titre "Metal Corner" déjà prévu dans la progression d'avatar, qui restait jusque-là un intitulé sans mécanique derrière.

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
- **Droits à l'image / musicaux** : usage actuel de **vrais noms de groupes/musiciens et de portraits IA dont l'apparence se rapproche des vrais visages** (à partir de photos). Deux risques distincts et cumulatifs : (1) le **droit à l'image** porte sur la personne reconnaissable, indépendamment du fait que l'image soit une photo ou une illustration originale — un style original ne suffit pas à s'en affranchir ; (2) si l'IA s'appuie sur une photo précise, la question de l'**œuvre dérivée** (droits du photographe) se pose selon ce qui subsiste de ses choix créatifs (cadrage, pose, lumière) — terrain juridiquement disputé (cf. le litige de l'affiche "Hope" de Shepard Fairey, basée sur une photo AP précise). **Ce choix n'est acceptable que tant que l'usage reste strictement privé** (pas de diffusion publique/commerciale, pas de mise en avant à grande échelle) — y compris sur la page de pitch, qui est techniquement publique (hébergée sur un repo GitHub public, mot de passe = filtre de politesse et non une vraie confidentialité) : décision assumée et actée pour l'instant par le porteur de projet en connaissance de ce risque, à réévaluer avant toute diffusion plus large. À faire trancher par un juriste avant toute ouverture publique, même limitée — accord de licence ou autre solution (voir `ROADMAP-IDEAS.md`).
- **Fiabilité de la détection capteur** : à valider par un spike technique avant de committer sur la jauge d'ambiance automatique ; le déclaratif doit rester le socle robuste dans tous les cas.
- **Sécurité de la présence partagée en concert** : rendre visible qu'un utilisateur est physiquement présent à un endroit peut créer un risque de repérage/harcèlement s'il n'est pas encadré. Garde-fous déjà posés dans le concept (opt-in réciproque, éphémère, jamais de liste publique par défaut) — à faire challenger par un tiers compétent sur la sécurité/vie privée avant lancement, au même titre que les autres risques listés ici.

## Statut
Concept validé comme base de travail pour la suite (direction visuelle, puis maquettage). Les idées écartées du MVP ou à explorer plus tard sont conservées dans `ROADMAP-IDEAS.md` pour ne rien perdre.
