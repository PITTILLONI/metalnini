# Metalnini — système de design (référence)

Source de vérité pour l'interface (prototype web et future app iOS). Les règles d'une page dans `pages/<page>.md` priment sur celles-ci. Établi le 2026-09-25 avec le skill `ui-ux-pro-max` (checklist d'avant livraison) ; les recommandations génériques du skill (vert feutre, Righteous/Poppins, 3D hyperréaliste) ont été écartées car contraires à la DA des cartes.

Mise à jour 2026-10-10 (audit, lots 1 à 6) : contradictions tranchées d'après le code (format du paquet, fiche carte, icônes seules, parcours Paquets, Rang), boutons `.df`, confirmations, palette de rareté unique, pastilles flottantes, ton de la révélation, admin et vitrines dans la DA. Détail des constats dans `AUDIT-2026-10-10.md`.

## Principe
Tarot gravé, moderne et élégant. L'interface est le cadre des cartes : noir d'encre, or, os, rouge sang. Jamais « site web » générique. Les cartes sont les héroïnes ; l'interface s'efface autour.

## Signature Metalnini : « collector arcade » (validée le 2026-09-30)
Deux couches, jamais mélangées sur un même élément :
- **Collector (gravure)** pour tout ce qui touche aux cartes : cadres à coins ornés or, sceaux de cire pour les raretés (C, R, H, S, L), cierge qui se consume pour la transformation, noms et titres en **Pirata One**, rubans rouges pour les titres de section, parchemin pour les textes longs (bios, styles).
- **Arcade** pour la progression et l'action : bandeau de rang (anneau, titre, points en crans), quêtes à jauges segmentées épaisses, boutons en relief (ombre pleine décalée de 5 à 7 px, pas de flou), coffre et butin (rayons, flammes, pastilles « +1 », « +6 XP »).
- Typo : Pirata One (seule police gothique), Big Shoulders Display pour chiffres, libellés et boutons, Barlow pour le texte courant (remplace Inter).
- Classes de `proto/index.html` :
  - `.g-title` : titre d'écran en gothique, avec un ornement de chaque côté.
  - `.g-sub` : titre de section en gothique.
  - `.ribbon` : ruban rouge, pour la section principale de l'écran.
  - `.relief` et `.relief.ink` : boutons en relief, en or ou à l'encre.
  - `notch(pct, n)` : jauge à crans, arrondie vers le bas.
  - `.gframe` : cadre à coins gravés.
  - `.seal` : sceau de rareté.
  - `.fzv-col` : cierge de transformation.
  - `showLoot()` : écran du butin (coffre, récompense, pastilles).
- Écrans passés à la signature :
  - Metal Corner (progression : chemin vertical des titres, trait or jusqu'au titre actuel, « encore N points » sur le suivant, titre social Metal Corner à part, puis « Gagne des points »), fiche carte (maîtrise et sceaux sous la carte ; le nom se touche et déplie bio, coup spécial et fiche), butin des épreuves.
  - Accueil (rang en gothique et crans sous le pseudo, pastille « en ligne » sur l'avatar, compteurs en relief, titre et nom du paquet en gothique, halo de rayons derrière le paquet, billet d'installation, points du carrousel en crans ; choix du format en interrupteur en relief à deux positions, le curseur or glisse sur Standard ou Mini — choisi le 2026-09-30).
  - Classeurs (puces en relief, noms en gothique, progression à crans).
  - Échange (blocs en relief, cote en pastille, QR dans un cadre gravé).
  - Blind test (réponses en relief, progression à crans).
- Globalement : tous les titres `h1`/`h2` sont en Pirata One ; tous les `.btn` sont en relief (or, `.ghost` à l'encre, `.danger` rouge), les actions de ligne en `.df` (relief compact) ; toutes les `.bar` ont 10 crans, et `crans(pct)` arrondit leur largeur au cran inférieur.
- Restent à revoir : les cases à cocher natives des réglages, la barre d'onglets (le losange gravé suffit pour l'instant).
- Maquettes de référence : canvas « Metalnini — directions UI », ligne A+C.

### À ne pas faire
- Pas de carte « SaaS » : fond gris uni, rayon 12 px, filet 1 px, ombre floue, tout aligné au cordeau.
- Pas de dégradé violet-bleu générique, pas de glassmorphism, pas d'emoji.
- Pas de barre de progression lisse et fine : toujours segmentée ou matérielle (cierge, jauge à crans).
- Pas de texte d'interface creux (« Bienvenue ! », « Découvrez… ») : le ton est celui d'un fan de metal.
- Pas de deuxième police gothique ; pas de Pirata One en texte courant.
- Pas de décor collector sur les éléments arcade, ni l'inverse (pas de coffre sur une fiche carte, pas de sceau sur une quête).

## Couleurs (jetons CSS de `proto/index.html`)
| Rôle | Jeton | Valeur | Contraste sur `--bg` |
|---|---|---|---|
| Fond | `--bg` / `--ink` | `#0c0b0a` / `#0d0a08` | — |
| Surfaces | `--surface`, `--surface-2` | `#161412`, `#1e1b18` | — |
| Texte | `--text` | `#f3f0ea` | 17:1 |
| Texte secondaire | `--muted` | `#a49e94` | 7,4:1 |
| Or (accent, actif) | `--gold`, `--gold-hi`, `--gold-lo` | `#eb9a26`, `#f4b243`, `#b56c16` | 8,6:1 (réchauffé le 2026-09-25) |
| Rouge (fonds, pastilles) | `--accent` | `#b23a3a` | réservé aux fonds (texte blanc dessus 5,9:1) |
| Rouge (texte, surtitres) | `--accent-text` | `#e0605a` | 5,6:1 |
| Raretés | `--r-commune`, `--r-rare`, `--r-holo`, `--r-signature`, `--r-legendaire` | `#c9c3b8`, `#3b82f6`, `#a78bfa`, `#f5c542`, `#ef4444` | toujours doublées d'un libellé (jamais la couleur seule) |

- Palette de rareté unique : les jetons `--r-*` de `:root` sont la seule source. Le JS les relit au chargement (`COLORS`, pour la forge, les éclats, les rayons) et `RARITIES` les cite en `var(--r-…)`. Aucune teinte de rareté en dur ailleurs. L'admin et les vitrines reprennent les mêmes valeurs.
- La Signature (`#f5c542`, or pâle) ne se confond pas avec l'or d'action (`--gold`).

## Typographie
- Titres d'écran, noms de cartes, titres de section : **Pirata One** (bas de casse, jamais en texte courant).
- Chiffres, libellés, boutons : **Big Shoulders Display** 800-900, capitales, interligne 0,95.
- Interface et texte : **Barlow** 400 à 700 ; surtitres et libellés en capitales Barlow 500-600, espacement 0,12-0,24 em.
- Aucun texte sous 0,7 rem (11 px), légendes, étiquettes et pastilles comprises ; corps de texte ≥ 14 px ; chiffres en `tabular-nums` (`.num`).

## Composants
- **Boutons** : un seul système en relief, même hauteur (52 px) et même typo partout (Big Shoulders Display 900, capitales, 0,1 em), coins de 12 px, ombre pleine décalée de 6 px.
  - Principal `.btn` : or plein en relief, lettres encre (confirmé le 2026-09-30 avec la maquette A+C ; remplace le bouton « encre et or » du 2026-09-26 : le relief et l'ombre pleine l'intègrent à la signature arcade). Un seul par écran. `.btn.block` pour la pleine largeur.
  - Secondaire `.btn.ghost` : encre en relief, filet et lettres or.
  - Danger `.btn.danger` : rouge plein, toujours derrière une modale de confirmation.
  - Action de ligne `.df` (relever, porter, rejoindre, retirer…) : relief compact, encre `#15110f`, filet or intérieur et ombre pleine noire de 4 px, lettres or en Big Shoulders 800 capitales (0,82 rem), coins de 10 px, 44 px de haut minimum ; à l'appui, il s'enfonce de 3 px.
    - `.df.go` et `.df.claim` : or plein, lettres encre, pour l'action qui fait avancer ou récupérer.
    - `span.df` : étiquette de statut (« Demandé », un pote ajouté avec sa coche), sans fond ni relief, en `--muted` (`.done` en or).
    - `.df.add` : ajouter (« + Défi », « + Bande »), filet or en pointillé. Le « + » de Mes potes et de Tes échanges est une bulle sans relief, le « + » seul en grand.
- **Confirmation** `askConfirm({eyebrow, title, text, yes, no, danger})`, modale du jeu au-dessus des feuilles du bas ; « Non » a le focus, Échap et un toucher à côté annulent. Bouton d'action or par défaut (Transformer, autoriser le micro…). Rouge (`danger:true`) seulement pour ce qui détruit ou fait perdre : déchirer, donner un dernier exemplaire ou la carte secrète, annuler un pit ou un pogo, retirer un concert, un billet ou une photo, quitter une bande, tout brûler. `askYesNo` pour un oui ou non qui n'annule rien. Jamais de `confirm()` natif, ni dans le jeu ni dans l'admin.
- **Icône seule** `.icon-btn` : sans cercle depuis le 2026-10-06, l'icône or (`--gold-hi`) seule dans une zone tactile de 46 px (44 px en `.sm`), `aria-label` obligatoire ; à l'appui, échelle 0,92 et disque clair. Seuls les avatars et les sceaux gardent un cercle. Exception : les croix et chevrons posés sur ce qui défile (`.trade-x`, `.trade-min`, `.pub-x`) ont un disque d'encre translucide pour rester lisibles.
- **Pastilles flottantes** (échange en cours, slam) : au-dessus de la barre d'onglets ; leur hauteur réelle est mesurée en `--pill` et ajoutée au bas de page (`padding-bottom` du `body`), comme `--tb` pour la barre : rien ne reste caché dessous.
- **Bordures** : un seul filet fin (1 px). Pas de double bordure ni de double filet (retour utilisateur du 2026-09-25).
- **Surfaces** (tuiles, objectifs, modales) : `--surface`, filet `--border`, rayon 12-14 px, sans ombre intérieure.
- **Objectifs** : carrousel horizontal (cartes de ~270 px, aimantées, la suivante dépasse) dans Metal Corner ; chaque carte a son illustration (éventail de 3 cartes du classeur avec dos grisé pour les manquantes, carte du musicien, ou icône gravée pour le cri et la photo), puis titre, pourcentage et filet de progression ; les récompenses à récupérer en tête ; chacune mène là où elle se joue.
- **Barre d'onglets** : 3 entrées (Paquets, Classeur, Metal Corner), fond encre, filet or fin ; Réglages en haut à droite. Pastille sur Metal Corner seulement pour une récompense à récupérer (rouge, pulse) ou un nouvel objectif jamais vu (or) ; ouvrir l'onglet marque les objectifs comme vus.
- **En-tête** : musiciens trouvés sur le total du catalogue (« 24/78 » : le total suit le catalogue) et maîtrises (couronne Tabler) ; toucher la couronne ouvre la feuille « Tes maîtrises » (couronnés, puis en route avec un repère par rareté ; toucher ouvre la fiche).
- **Icônes** : Tabler Icons (MIT) pour l'interface, copiées en SVG en ligne (aucun chargement externe), trait 1,4-2 px, `currentColor` ; la main « cornes » de Metal Corner est dérivée de `hand-love-you`. Restent maison : le croissant (logo), le sachet de paquet et les glyphes de Safari de la feuille d'installation. Game-icons.net (CC BY 3.0, crédit de l'auteur obligatoire à côté de chaque usage) est réservé aux éléments décoratifs (badges, patchs, titres). Pas d'emoji ni de glyphes Unicode comme icônes (✕, ✓, ★, ▶, ●, ♪, ‹ ›) : dans le JS, `gl(nom, taille)` donne les icônes Tabler courantes (`x`, `check`, `play`, `rec`, `stop`, `left`, `right`, `swap`, `music`), `icon(chemins, taille)` les autres. La maîtrise se marque toujours par la couronne. Les flèches « ← » des liens de retour restent du texte.

## Parcours Classeurs
1. **Catégories** en puces : Styles, Instruments, Groupes (sous-catégories en petites cartes, trois de front). « Collection » n'apparaît qu'à partir de deux collections ; en attendant, « Toutes les cartes » reste la page où l'on range après un tirage (retour vers Styles).
2. **Cartes de classeur** dans la catégorie (« Collection » : la carte « Toutes les cartes ») : vraie carte au format 2:3, illustrée par la meilleure carte rangée ou le dos Metalnini, nom gravé en bas, « x/N cartes », filet de progression, « Complet » avec une coche Tabler.
3. **Page du classeur** : « ← catégorie », titre, progression, fiche du style repliable (« C'est quoi, le style … ? » : époque, présentation, 3 repères en pastilles, « À écouter » avec les morceaux des cartes du classeur ; ouverte à la première visite, repliée ensuite ; une phrase pour les classeurs d'instruments), cases numérotées de 1 à N ; tri et affichage dans une feuille du bas (icône réglages).
4. **Vue « Par rareté »** (feuille d'affichage : « Par musicien » ou « Par rareté ») : une ligne par musicien et une colonne par rareté ; en-têtes en mini-sceaux C R H S L (lettre dans le sceau, nom entier en `aria-label`), cases vides au dos grisé.

## Parcours Paquets (deux temps)
1. **Choisir** : HUD, titre « Ton paquet est prêt », « N paquets à ouvrir » s'il y en a, format en interrupteur en relief (Standard · 5 cartes ou Mini · 2 cartes, + de chances), carrousel (flèches sur ordinateur), nom et description du paquet du centre. Un seul paquet par jour, Standard ou Mini (2 points = 1 paquet). Toucher le paquet du centre le choisit (médaillon d'encre cerclé d'or avec une coche au trait, à cheval sur le haut du sachet) ; le retoucher le retire ; toucher un voisin le centre. Un seul paquet choisi à la fois, et changer de format le garde. Bouton or « Ouvrir le paquet standard » ou « Ouvrir le mini » sous le carrousel, sa place gardée tant que rien n'est choisi. Paquet déjà tiré sur le serveur : le format est verrouillé, avec « L'ouvrir » ou le mettre de côté. Paquet du jour utilisé : le titre devient « Ouverture dans … » (temps jusqu'à minuit), « Le merch est fermé », offres de la boutique si elle est ouverte, et le lien vers les épreuves.
2. **Ouvrir** : « ← Changer de paquet », nom et description du paquet, paquet en grand, geste pour déchirer (« Glisse pour l'éventrer »). Ni titre, ni format, ni carrousel à cette étape. Un paquet serveur entamé rouvre directement cette étape.

## Parcours Révélation et rangement
- **Révélation** : une carte à la fois ; phrase « combo » en bandeau incliné sur la carte (taille et couleur selon la rareté, ~3 s). La rangée du haut rouvre les cartes déjà vues. À la dernière carte : « Ranger dans le classeur » et partage (pas d'écran de résumé).
- **Ton de la révélation** : mi-argot, mi-lexique de concert (pit, wall of death, rappel, larsen, merch, roadie, balances, setlist, premier rang). Pas d'argot qui date vite (« wallah », « rizz », « aura », « askip », « PNJ »). Listes dans `LINES` (par rareté), `DUP_LINES`, `TWICE_LINES`, `TRIPLE_LINES`.
- **Une seule vanne par écran** : la consigne « Glisse pour la retourner » ne dit « Ça mord pas » qu'à la première carte. Un paquet faible (que des Communes, ou que des doublons) a sa pique (`packJab`, listes `WEAK_PACK` et `DUP_PACK`), qui devient la phrase de la dernière carte (petit format), jamais un toast en plus ; « Tout révéler » l'affiche à la place de la phrase.
- **Bilan de « Tout ranger »** : une ligne par catégorie (médaillon avec icône, nombre, libellé) avec les miniatures des cartes concernées (6 au plus, puis « +N ») ; les classeurs complétés par leur nom. Chaque classeur complété et chaque maîtrise ont un bouton « Récupérer » (cadeau, nom, pastille or) : le bilan se ferme et la récompense arrive.
- **Rangement** : chaque carte s'affiche en grand, bonus en bandeau (lettrage Pirata One) ; consigne sur deux lignes au-dessus ; un toucher range et passe à la suivante. Transformation proposée quand elle devient possible.

## Parcours Metal Corner et échange
1. **Onglet** : en tête, l'anneau de rang (anneau or vers le prochain titre, icône du titre au centre, titre, points et crans ; le toucher ouvre Rang), puis quatre rubriques en puces, une seule visible, avec une pastille quand quelque chose y attend :
   - **Potes** : deux tuiles en relief, « Mon QR » en or et « Scanner » à l'encre, dans des médaillons gravés ; « On te propose un échange », « Mes potes », « Tes échanges ».
   - **Fosse** : « En ce moment », « Les danses », « Tes concerts » (voir 6).
   - **Épreuves** : les objectifs (les terminés en tête, cadre or, reflet d'or qui balaie la carte, icône cadeau qui frétille, « Terminé · récompense » ; au toucher la carte s'ouvre puis la récompense arrive : paquet, carte révélée ou ticket artiste prioritaire ; pastille rouge qui pulse sur l'onglet tant qu'il y a une récompense à prendre), puis les missions de pogo.
   - **Rang** (« Ta progression ») : surtitre « Tes titres · N/10 », chemin vertical des cinq titres (Groupie, Roadie, Première partie, Tête d'affiche, Légende du pit) : passés « Débloqué », actuel avec ses points et un trait or, suivant « Encore N points · dès X », les autres « Dès X points ». Puis deux titres à part : Metal Corner (titre bonus, au premier échange) et le titre de concert (Premier pogo, Habitué du pit, Bête de scène, Vétéran des barrières : 1, 5, 10 et 25 concerts). Puis « Gagne des points » : six compteurs illustrés (musiciens 1 pt, classeurs pliés 4 pts, maîtrises 6 pts, concerts 3 pts plus bande et défis, points de fosse, photo de profil 2 pts).
2. **Montrer mon code** : QR code sur fond os, code à 6 caractères en or (« ABC 234 »), « Envoyer le lien » (feuille de partage, sinon lien copié), « En attente de ton pote… ».
3. **Scanner** : caméra carrée avec cadre or, et toujours le champ « Ou tape son code ».
4. **Composition** : « Tu donnes » (toucher une carte la retire, « + Ajouter » ouvre la feuille des cartes, encart « X te demande N cartes · Voir ») et « Tu reçois » (toucher = plein écran), cote indicative de chaque côté, état de validation du pote, « Valider l'échange ». Toute carte posée ou retirée annule les validations. Donner un dernier exemplaire passe par une confirmation qui cite les classeurs complets touchés.
   **Feuille des cartes**, deux onglets : « Mon classeur », trié par intérêt pour le pote (Demandées par X, Nouvelles pour X, Raretés que X n'a pas, X les a déjà ; doublons d'abord dans chaque groupe) : toucher pose un exemplaire, toucher encore ajoute un doublon, carte posée = cadre or + « Posée ×N » + bouton « − », « Dernière » en rouge si la donner vide sa case, total dans « C'est bon · N posées ». « Son classeur » (Nouvelles pour toi, Raretés qui te manquent, Tu les as déjà) : toucher demande la carte (étiquette « Demandée »), elle remonte en tête chez le pote ; une demande ne change pas l'échange ni les validations.
   **Réduire** : chevron en haut à gauche de l'écran d'échange (la croix à droite quitte) ; l'échange reste ouvert et une pastille d'encre cerclée d'or au-dessus de la barre d'onglets (« Échange avec X · a validé … REPRENDRE ») permet d'y revenir de n'importe quel écran ; retrouvée après un rechargement. Nombre d'exemplaires toujours dans la légende sous la carte (« RARE ×3 »), jamais en surimpression ; filtre « Doublons seulement ».
5. **Conclusion** : écran « Échange conclu », sans révélation carte par carte : « Tu donnes » (petites cartes qui partent vers le haut), l'icône d'échange qui pivote, « Tu reçois » (cartes qui tombent, étiquettes « Nouvelle » et « Bonus rencontre ») ; « Ranger dans le classeur », « Suivre X », « Fermer ». Le cri du pote (s'il en a enregistré un) retentit juste après le jingle ; les cartes reçues, puis la carte bonus de première rencontre, se révèlent comme un paquet (« Échange avec … ») et attendent dans « À ranger ».

6. **Fosse** : « En ce moment » (gestes en attente chez les potes, tous jeux confondus), puis « Les danses » (une carte illustrée par danse : pogo, circle pit, slam), puis « Tes concerts ». Toucher une danse ouvre sa salle plein écran (`#salle`) : illustration, ce qui est en cours, « Comment ça marche » en étapes, bouton principal fixé en bas (`ctaBar()`, avec sa note ; sans potes, « Ajouter des potes pour danser »).
   **Slam** (salle du slam) : slams des potes à porter (ligne d'invitation, point rouge, « plane au-dessus de la foule · 3/5 · encore 1 h 12 », « Porter »), slams portés en cours (« tu le portes · 3/5 · encore … », « Renfort » tant qu'il manque des porteurs) et atterris (« a atterri grâce à toi », « Récompense »). Mon slam : scène animée (`slamScene`, CSS et avatars, plus de dessin SVG de foule) sur fond de scène avec deux faisceaux (or et rouge) et la foule en silhouettes ; en bas, une place par porteur attendu : avatar du porteur cerclé d'or avec bras levés en or, place libre en pointillé « Libre » ; mon avatar, cerclé de rouge, sautille au bord de la scène (prêt), plonge, flotte au-dessus de la foule en avançant d'une place par porteur, atterrit à droite avec un éclat d'or, ou tombe dans la fosse, couché et grisé, les porteurs grisés et sans bras levés. Mouvement réduit : la scène est figée. États : prêt (scène seule, note « 5 porteurs en 2 h pour atterrir », bouton « Slammer »), « Tu planes au-dessus de la foule » (« N/5 porteurs · encore … », « Porté par … » et ajout en pote, « Appeler la foule » en `.ghost`, qui ouvre Rameuter puis le partage du lien), « Atterrissage réussi » (encadré or, « Récupérer ma récompense »), « Slam réussi », « Écrasé dans la fosse ». Pendant le slam, dans Mes potes, « Porte-moi » sous chaque pote, puis « Demandé » ou « Te porte » avec une coche. Hors de Metal Corner, pastille d'encre cerclée d'or au-dessus de la barre d'onglets (même composant que celle de l'échange, qui a la priorité) : « X plane au-dessus de la foule · 3/5 · PORTER » (porte d'un toucher), ou « Slam atterri : récompense à prendre · VOIR ».
   **Ajouter un pote** : bulle « + » à côté du titre « Mes potes » (`aria-label` « Ajouter un pote ») ; feuille « Ajouter un pote » : code de pote en or (« QWE 789 »), « Envoyer mon lien », « Ou tape son code » + « Ajouter » (lien collé accepté).

7. **Social** (Metal Corner) : « On te propose un échange » (Rejoindre), « Mes potes » (médaillon, nombre d'échanges, Profil, Échanger : proposition par notification), « Tes échanges » (historique : date, cartes données ⇄ reçues). Profil d'un pote = même veste à patchs, calculée sur son classeur, plus « Il lui manque, tu l'as en double » et « Lui proposer un échange ».

8. **Blind test des cris** : carte « Qui a poussé ce cri ? » dans le carrousel (jusqu'à 5 cris de potes suivis, un essai par cri, 4 pseudos) ; trouvé = bonus, le pote est « démasqué » (encadré rouge dans son profil, « Pousse-en un nouveau », bonus au nouveau cri) ; gains récupérés ensemble à la fin.
   **Blind test** : chaque maîtrise et chaque classeur complété débloquent une carte rouge sang « Blind test débloqué · Jouer » dans le carrousel (casque en médaillon). Écran plein cadre : surtitre « Blind test · Maîtrise de X », « Extrait N / 5 », 5 points (or = trouvé, rouge = raté), disque à égaliseur (toucher = écouter / couper), 4 choix d'artiste en 2 × 2 ; après le choix, bonne réponse en or, mauvaise en rouge, titre du morceau, « Bien vu ! » ou « Raté : c'était X » ; score final « N / 5 » puis récompense (3 = Commune nouvelle, 4 = Rare minimum, 5 = Holo minimum). Joué une fois ; quitter en cours ne le consomme pas.

9. **Échanger depuis une carte ou un classeur** : bouton « Échanger » dans la fiche carte (entre Partager et Déchirer) et icône d'échange dans l'en-tête d'un classeur ; feuille « Échanger » : la carte proposée (posée dès que le pote rejoint), « Avec un pote » (Proposer = notification), « Ou sur place » (les deux tuiles).

## Autres écrans
- **Profil** : page à part (avatar, pseudo, capacité de metaleux en texte, cri). La capacité se modifie dans une feuille du bas : idées proposées ou texte perso (120 caractères).
- **Installer l'app** : feuille du bas « Un paquet offert », un seul chemin selon l'appareil : bouton « Installer » (Android, Chrome), trois étapes illustrées par les icônes de Safari (Partager, En savoir plus, Sur l'écran d'accueil) avec « Pas dans Safari ? » en lien, ou « Ouvrir dans Safari » depuis un autre navigateur iPhone. Proposée à la connexion (3 fois au plus, tous les 3 jours) et depuis le bandeau de l'accueil.
- **Profil public** (« veste à patchs ») : médaillon photo cerclé d'or, pseudo, titre gagné en pastille (Groupie → Légende du pit), capacité en citation, bouton « Écouter son cri » ; vitrine de 3 cartes en éventail ; patchs ronds brodés (classeurs complétés, surpiqûre or en pointillés ; manquants en pointillés os) ; pin's de maîtrise ; setlist en tuiles. Plein écran, fermeture en haut à droite.
- **Notifications** : encadré arrondi à marges, en haut de l'écran ; descend et remonte, sans fondu ; une seule à la fois.
- **Fermer** : croix en surimpression en haut à droite (icône seule, sans cercle ; disque d'encre quand elle est posée sur ce qui défile), elle ne prend pas de place. Dans une feuille, elle reste hors de la zone qui défile, et la feuille s'arrête sous la barre d'état (`100dvh - env(safe-area-inset-top)`).
- **Transformer** : toujours une confirmation (« Transformer » / « Garder mes doublons »), puis la forge : les doublons convergent en cercle et fondent dans un éclat de la couleur de la rareté visée (1,5 s), puis la révélation.
- **Accueil** : « N paquets à ouvrir » avec un sachet par paquet (5 au plus) et le détail réserve / cadeaux.
- **Fiche carte**, dans cet ordre : la carte dans son cadre gravé et, sur le côté, la jauge de transformation de la rareté affichée vers la suivante (« Transfo », un cran par doublon, rareté visée écrite à la verticale ; pleine = elle brille, la toucher propose la transformation) ; juste sous la carte, le bloc « Maîtrise N/5 » et les 5 sceaux (toucher une rareté change la carte et la jauge ; couronne à 5/5) ; la rareté en surtitre et l'arcane ; l'artiste en titre, « groupe · N exemplaires » : le nom se touche et déplie « Bio et coup spécial » (présentation détaillée, coup spécial avec une icône éclair sans cadre, fiche : arcane, instrument, style, classeurs) ; l'écoute ; enfin les actions en relief Partager (encre) / Échanger (or, au centre, plus large) / Déchirer (encre, lettres rouges, confirmation rouge). Carte perso, secrète ou maudite : une ligne à la place de la maîtrise ; carte maudite : faits sourcés et « Déchirer la carte » seul.
- **Carte en plein écran** : depuis la fiche, toucher la carte ou l'icône d'agrandissement (coin bas droit) ; carte la plus grande possible entre les zones de sécurité, fond noir d'encre ; un toucher, la croix ou Échap referment.

## Interaction et mouvement
- Cibles tactiles ≥ 44 × 44 px, 8 px d'écart minimum ; retour visuel à l'appui (échelle 0,97-0,98 ou opacité).
- Focus clavier visible (`:focus-visible`, filet `--gold-hi`).
- Micro-interactions 150-300 ms ; grands moments (révélation, bonus) jusqu'à 1,6 s, toujours passables d'un toucher.
- N'animer que `transform` et `opacity` ; pas de flou ni de mode de fusion animés (performance mobile).
- `prefers-reduced-motion` : animations décoratives coupées, parcours intact.
- Effets plein écran dans un calque rogné (`#fxlayer`, `overflow:hidden`) : rien ne doit élargir la page.

## Mise en page
- Pensé pour 375-430 px de large ; vérifié en 375 × 560, 390 × 664, 430 × 932, paysage 844 × 390, et bureau.
- Zones de sécurité (`env(safe-area-inset-*)`) respectées en haut et en bas ; aucun contenu sous les barres fixes.
- Écrans qui se mettent à jour en direct (échange) : `morph()` applique le nouveau rendu sans recréer ce qui n'a pas changé (cartes reconnues par `data-m` / `data-r`), jamais `innerHTML` sur un écran déjà affiché.
- Barre d'onglets sur son propre calque (`translateZ(0)`) ; sa hauteur réelle est partagée en `--tb` (bac « À ranger », pastille d'échange).
- Hauteurs calculées sur la place réelle (`dvh`, mesure JS pour le carrousel), jamais sur `100vh`.

## Contenu
- **E-mail de confirmation** : encadré or « Rien dans ta boîte ? » (Spam, Promotions, « Pas un spam ») sur l'écran d'attente.
- **Onboarding** : après les univers, « Tes groupes du moment ? » (5 au plus, pastilles, « Passer »), puis « Pousse ton cri » (l'enregistreur du profil, prêté le temps de l'étape, « Plus tard »), puis le paquet de bienvenue. Groupes et cri partent au serveur à la création du compte.
- Ton rock'n'roll (guide dans `concept.html`, Ligne édito) : clair d'abord, une vanne par écran.
- Vocabulaire : « échange », jamais « troc », dans tous les textes affichés (« troc » ne reste que dans des noms de code et le paramètre de lien `?troc=`).
- Carte non trouvée : ni nom, ni groupe, ni titre ; classeur de groupe « Groupe mystère » tant qu'aucune carte du groupe n'est trouvée. Sa fiche montre le dos gravé (dos Metalnini en filigrane, numéro d'arcane en gothique or, instrument en capitales), le titre « Carte mystère », « Elle t'attend quelque part dans un paquet. » et « 5 raretés à trouver », sans action.

## Admin
- Même DA que le jeu : Pirata One pour les titres, Big Shoulders Display pour les boutons et `h3`, Barlow pour le texte, mêmes jetons (or, rouge, raretés).
- Boutons en relief : or par défaut, `.ghost` à l'encre, `.danger` rouge seulement pour ce qui détruit ; 44 px de haut sous 640 px ; un bouton reste désactivé tant que son appel n'est pas fini (pas de double envoi).
- Confirmation dans la page : `ask(titre, texte, oui, danger, non)`, fenêtre `<dialog>` cerclée d'or, « Annuler » a le focus. Pour les actions sensibles (vider une collection, bloquer, rôles, preuves, agent, cartes perso, réglages). Erreurs sous le bouton concerné.

## Pages vitrines
- `index.html`, `concept.html`, `flows.html`, `sons.html` : mêmes polices (Pirata One, Big Shoulders Display, Barlow), mêmes jetons, or pour l'actif, bouton principal `.btn` or en relief (rideau d'accès compris).
- Pied de page commun `site-nav` (Pitch, Concept, Flows, Sons, Prototype) : liens en Big Shoulders capitales, 44 px de haut, page en cours en or (`aria-current="page"`).

## Checklist d'avant livraison (extrait du skill, à cocher à chaque changement d'interface)
- [ ] Contraste texte ≥ 4,5:1 (secondaire ≥ 3:1)
- [ ] Cibles ≥ 44 px, retour à l'appui, focus visible
- [ ] Pas de défilement horizontal ; rien sous les barres ; paysage vérifié
- [ ] Mouvement réduit vérifié
- [ ] Champs avec libellé, erreurs près du champ
- [ ] Icônes SVG cohérentes, libellés d'accessibilité
