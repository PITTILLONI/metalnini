# Metalnini — Concept produit (MVP)

## Positionnement
Le "Panini du metal/rock" : une collection de cartes numériques d'artistes, à ouvrir en packs, collectionner et échanger — avec une couche vivante connectée à l'actualité réelle des artistes et à l'expérience vécue en concert. Cible : la communauté metal/rock, soudée, nerd, très attachée à l'authenticité et au vécu live.

## Ce que Metalnini n'est pas
- Pas un jeu de combat/versus.
- Pas une marketplace monétaire (aucune revente de carte contre argent réel).
- Pas un produit physique au lancement (packs physiques, merch, NFC/QR sur objet : reporté, voir `ROADMAP-IDEAS.md`).

## Boucle de jeu centrale (MVP)
1. Ouvrir un pack (gratuit régulier + payant + gagné en event) → reveal animé.
2. Compléter des collections thématiques (par artiste, sous-genre, époque, festival).
3. Une carte peut **évoluer** quand un événement réel se produit chez l'artiste (sortie d'album, clip, date de concert, anniversaire).
4. Échanger des cartes avec d'autres fans (troc pur, sans argent réel).
5. Vivre un concert → nourrir son **avatar de fan** et son **carnet de concerts**.

## Système de cartes
- **Types** : Artiste, Live, Album, Riff/Moment culte (clip, extrait), Collector (édition limitée événement).
- **Rareté** : Commune → Rare → Holo/Prisme → Signature (numérotée) → Légendaire (série ultra-limitée).
- Traitement graphique différencié par rareté (texture, foil, bordure), identité graphique déclinée par sous-genre.

## Mécanique d'évolution des cartes
Les cartes changent d'état suite à un flux d'actualité artiste réel :
- Carte "Artiste" → devient carte "Album" à la sortie d'un nouvel album.
- Carte "Live" → variante spéciale débloquée si l'utilisateur était présent au concert concerné (scan/check-in géolocalisé).
- Événements calendaires (anniversaire d'un album culte, reformation, etc.) déclenchent des drops commémoratifs limités dans le temps.

## Volet social (troc, pas de marché)
- Échange carte contre carte (1-to-1 ou en lot), avec éventuellement une valeur symbolique de rareté pour équilibrer les échanges — **jamais convertible en argent réel**.
- Guildes/clans par groupe ou sous-genre.
- Classements de collection (par artiste, par festival, global).
- Vitrine de profil public (le "book" à montrer).

## Avatar de fan & carnet de concerts
Chaque utilisateur a un avatar personnel qui évolue avec son vécu live, en plus de sa collection de cartes.

**Captation de l'expérience (double mécanisme)**
- **Jauge d'ambiance semi-automatique** : si la précision technique le permet, utilisation de l'accéléromètre/gyroscope du téléphone pendant le concert pour estimer un niveau d'énergie/intensité vécu (à valider par un spike technique — la détection fine d'un pogo vs un wall of death n'est pas garantie, mais un niveau d'intensité global est plausible).
- **Déclaratif (toujours disponible, socle du MVP)** : après le concert, l'utilisateur note son expérience — ambiance, musique, sono, intensité du mosh pit, etc. Ce carnet de concerts a une valeur en soi (journal de ses shows vécus), indépendamment de l'avatar.

**Progression de l'avatar**
Traits visuels et titres/achievements déblocables selon le vécu cumulé, par exemple (liste ouverte, à affiner) :
- Titres d'ambiance : "Roi du pogo", "As des airs" (air guitar), etc.
- Titres sociaux : "Metal Corner" (a échangé/discuté avec d'autres fans sur place).
- Titres de fidélité/découverte : nombre de concerts vus, diversité de sous-genres/artistes vus, ancienneté sur un artiste.

## Monétisation (MVP)
- Vente de packs digitaux (achat direct + monnaie in-app).
- Partenariats labels/artistes/festivals pour du contenu exclusif sponsorisé.
- **Aucune commission sur échange/revente** (le troc n'est pas un marché monétaire).

## Risques / points à faire trancher par des tiers compétents
- **Cadre légal loot-box** : mécaniques de pack aléatoire payant régulées dans certains pays — à valider par un juriste avant tout modèle payant.
- **Droits à l'image / musicaux** : chaque carte artiste nécessite un accord de licence, ce qui conditionne le rythme de contenu.
- **Fiabilité de la détection capteur** : à valider par un spike technique avant de committer sur la jauge d'ambiance automatique ; le déclaratif doit rester le socle robuste dans tous les cas.

## Statut
Concept validé comme base de travail pour la suite (direction visuelle, puis maquettage). Les idées écartées du MVP ou à explorer plus tard sont conservées dans `ROADMAP-IDEAS.md` pour ne rien perdre.
