# Circle pit : vrais corps, photos de profil et lumières

Date : 2026-11-14. Statut : validé par le propriétaire le 2026-11-14. Suite de `2026-11-14-circle-pit-moteur-design.md` (branche `pit-moteur`).

## Pourquoi

Le propriétaire a joué au nouveau circle pit (`proto/?pitbanc`) : « c'est vraiment pas mal », mais les coureurs sont « trop moches ».
Il veut, dans ses mots : des silhouettes plus réalistes, des jeux de lumière, et **voir la photo de profil des joueurs posée sur un vrai corps**.

Aujourd'hui (`proto/fosse/pit-view.js`) : vue de dessus, chaque coureur est une même texture (ovale + rond) teintée, sans animation ; à terre = aplati.
Une vue de dessus ne montre pas de visage : la photo de profil impose de changer d'angle.

## Objectifs, non-objectifs, anti-objectifs

- Objectifs : vue de trois-quarts avec coureurs debout ; photo de profil en tête pour moi, les fantômes et les potes au bord ;
  corps animés (courir, trébucher, à terre, se relever, relever quelqu'un, bras levés) ; fosse éclairée comme un concert ; 60 images/s sur iPhone avec 40 coureurs.
- Non-objectifs : vraie 3D ; changement des règles, des commandes, du score, des fantômes ou du serveur ; personnages Rive (plus tard, pour soi).
- Anti-objectifs : un effet « collage » (photo brute sur un dessin) ; un rendu qui rame ou qui chauffe le téléphone ; perdre la lisibilité (où je suis, qui est à terre, où est le bord et le milieu).

## Approches étudiées

| Approche | Pour | Contre | Décision |
|---|---|---|---|
| 1. Vue de dessus, corps dessinés par le code | rapide, fluide | pas de visage : la photo de profil n'y a pas sa place | écartée (demande du propriétaire) |
| 2. Vue de trois-quarts, corps debout | visages et photos visibles, le plus immersif | profondeur à simuler, caméra à refaire | **retenue par le propriétaire** |
| 3. Rive pour les personnages | qualité d'animation, outil connu du propriétaire | trop lourd pour 40 coureurs à la fois | plus tard, pour son propre coureur |

Dans l'approche 2, les corps sont **dessinés par le code** (formes vectorielles articulées) plutôt que générés par Krea : une IA garde mal un même personnage d'une image d'animation à l'autre, et le code donne toutes les poses sans crédits.

## Conception

### Caméra et profondeur (choix du propriétaire : « de dos, comme les vidéos de concert au drone »)
- La simulation ne change pas (positions sur l'anneau). L'affichage projette : le monde est tourné pour que je coure vers le haut de l'écran, puis écrasé verticalement (inclinaison d'un drone en hauteur, l'anneau devient un ovale qui file vers l'horizon) ; plus un coureur est loin, plus il est petit et haut à l'écran ; tri des coureurs par profondeur à chaque image.
- Caméra **derrière moi et en hauteur**, qui suit ma course dans le virage, légère dérive et léger roulis comme un drone. Le pouce garde le même sens (haut = foncer, côtés = bord ou milieu).

### Corps
- Corps articulé dessiné par le code : tête (photo ou tête dessinée), cou, buste (t-shirt), bras en deux segments, jambes en deux segments, chaussures ; cycle de course dont la cadence suit la vitesse.
- Poses : courir, trébucher (déséquilibre bref), à terre (allongé), se relever, tendre la main (relever quelqu'un), bras levés (spectateurs, pote attiré qui entre).
- Variété de la foule : 6 à 8 carrures et coupes de cheveux, t-shirts noirs avec un motif simple de groupe, quelques vestes à patchs ; têtes dessinées sans photo.
- Rendu : chaque pose est précalculée en quelques images (textures) au chargement, puis jouée comme une animation ; c'est ce qui tient 40 coureurs à 60 images/s.

### Photos de profil
- De dos, un visage ne se voit pas : la photo des coureurs vus de dos (moi, les fantômes) est **une pastille ronde au-dessus de la tête**, qui suit le corps. Elle reste visible de loin et sert de repère.
- Les potes au bord regardent vers le pit, donc vers la caméra : leur photo est **leur visage**, posé sur le corps. Il en va de même pour un coureur à terre (allongé sur le dos) et pour moi quand je me retourne pour relever quelqu'un.
- Moi, les fantômes (coureurs de ce pit qui ont couru) et les potes au bord : leur photo de profil (`avatars`, adresse obtenue comme `hydrateAvatars`) découpée en rond, posée en tête, avec un fin liseré or ; sans photo : tête dessinée et initiale.
- Photos passées dans la palette du jeu (bichromie noir et or, légère touche rouge dans l'ombre) pour éviter l'effet collage ; une option `photoStyle: 'naturel'` permet de garder la vraie couleur si le propriétaire le préfère.
- Une photo qui ne se charge pas (réseau, droits d'accès) : tête dessinée, sans erreur.

### Lumières
- Fosse sombre ; 2 à 3 projecteurs de scène (faisceaux en dégradé, mode additif) qui balaient la foule, rouge sang et or.
- Pulsation des faisceaux sur le tempo (événement `beat`), flash bref à une chute, à l'entrée d'un pote et au dernier tour.
- Ombre sous chaque corps, orientée à l'opposé du projecteur le plus proche ; poussière qui s'éclaire en traversant un faisceau ; halo doré autour de moi.
- Mouvement réduit : pas de flash ni de balayage rapide (lumières fixes, pulsation douce).

### Performance
- Viser 60 images/s sur iPhone 12 et plus récents ; plafond de 40 coureurs ; textures de poses générées une fois ; pas de filtre coûteux par image (la bichromie des photos est faite une fois sur la texture).

## Laissé au développeur
- Proportions, couleurs exactes des t-shirts et des faisceaux, nombre d'images par pose, angle d'inclinaison, dans la DA (`design-system/metalnini/MASTER.md`).
- Découpage en fichiers (par exemple `pit-bodies.js` pour les corps et `pit-light.js` pour les lumières, à côté de `pit-view.js`).

## Décisions du propriétaire
- Caméra : de dos et en hauteur, comme les vidéos de concert au drone.
- Photos des coureurs vus de dos : pastille ronde au-dessus de la tête.
- Photos dans la palette du jeu (noir et or) ; `photoStyle: 'naturel'` reste possible.
