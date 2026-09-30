# Metalnini — système de design (référence)

Source de vérité pour l'interface (prototype web et future app iOS). Les règles d'une page dans `pages/<page>.md` priment sur celles-ci. Établi le 2026-09-25 avec le skill `ui-ux-pro-max` (checklist d'avant livraison) ; les recommandations génériques du skill (vert feutre, Righteous/Poppins, 3D hyperréaliste) ont été écartées car contraires à la DA des cartes.

## Principe
Tarot gravé, moderne et élégant. L'interface est le cadre des cartes : noir d'encre, or, os, rouge sang. Jamais « site web » générique. Les cartes sont les héroïnes ; l'interface s'efface autour.

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
| Raretés | Commune `#c9c3b8`, Rare `#3b82f6`, Holo `#a78bfa`, Signature `#f5c542`, Légendaire `#ef4444` | toujours doublées d'un libellé (jamais la couleur seule) |

## Typographie
- Titres : **Big Shoulders Display** 800, capitales, interligne 0,95.
- Interface et texte : **Inter** 400 à 700 ; surtitres et libellés en capitales Inter 500-600, espacement 0,12-0,24 em.
- Aucun texte sous ~11 px (0,7 rem) ; corps de texte ≥ 14 px ; chiffres en `tabular-nums` (`.num`).

## Composants
- **Boutons** : un seul système, même hauteur (50 px) et même typo partout (Big Shoulders Display 800, capitales, 0,1 em), coins de 6 px.
  - Principal `.btn` « encre et or » (décidé le 2026-09-26, l'aplat jaune détonnait avec la DA des cartes) : fond noir d'encre, filet et lettres or, légère lueur dorée. Un seul par écran. `.btn.block` pour la pleine largeur.
  - Secondaire `.btn.ghost` : fond transparent, filet os fin.
  - Danger `.btn.danger` : rouge plein, toujours derrière une modale de confirmation.
- **Icône seule** `.icon-btn` : rond, filet or fin, `aria-label` obligatoire, 44 px minimum.
- **Bordures** : un seul filet fin (1 px). Pas de double bordure ni de double filet (retour utilisateur du 2026-09-25).
- **Surfaces** (tuiles, objectifs, modales) : `--surface`, filet `--border`, rayon 12-14 px, sans ombre intérieure.
- **Objectifs** : carrousel horizontal (cartes de ~270 px, aimantées, la suivante dépasse) dans Metal Corner ; chaque carte a son illustration (éventail de 3 cartes du classeur avec dos grisé pour les manquantes, carte du musicien, ou icône gravée pour le cri et la photo), puis titre, pourcentage et filet de progression ; les récompenses à récupérer en tête ; chacune mène là où elle se joue.
- **Barre d'onglets** : 3 entrées (Paquets, Classeur, Metal Corner), fond encre, filet or fin ; Réglages en haut à droite. Pastille sur Metal Corner seulement pour une récompense à récupérer (rouge, pulse) ou un nouvel objectif jamais vu (or) ; ouvrir l'onglet marque les objectifs comme vus.
- **En-tête** : musiciens trouvés (« 5/45 ») et maîtrises (couronne Tabler) ; toucher la couronne ouvre la feuille « Tes maîtrises » (couronnés, puis en route avec un repère par rareté ; toucher ouvre la fiche).
- **Icônes** : Tabler Icons (MIT) pour l'interface, copiées en SVG en ligne (aucun chargement externe), trait 1,4-2 px, `currentColor` ; la main « cornes » de Metal Corner est dérivée de `hand-love-you`. Restent maison : le croissant (logo), le sachet de paquet et les glyphes de Safari de la feuille d'installation. Game-icons.net (CC BY 3.0, crédit de l'auteur obligatoire à côté de chaque usage) est réservé aux éléments décoratifs (badges, patchs, titres). Pas d'emoji ni de glyphes Unicode comme icônes.

## Parcours Classeurs
1. **Catégories** en puces : Collection, Styles, Instruments, Groupes.
2. **Cartes de classeur** dans la catégorie (« Collection » : la carte « Toutes les cartes ») : vraie carte au format 2:3, illustrée par la meilleure carte rangée ou le dos Metalnini, nom gravé en bas, « x/N cartes », filet de progression, « Complet ✓ ».
3. **Page du classeur** : « ← catégorie », titre, progression, cases numérotées de 1 à N ; tri et affichage dans une feuille du bas (icône réglages).

## Parcours Paquets (deux temps)
1. **Choisir** : HUD, objectifs (masqués sur écran bas), « Choisis ton paquet du jour », carrousel (flèches sur ordinateur), nom du paquet du centre, format (1 gros de 5 cartes ou 2 petits de 2 cartes aux meilleures chances ; 2 points par jour, gros = 2, petit = 1). Toucher le paquet du centre le sélectionne (médaillon d'encre cerclé d'or avec un check au trait, à cheval sur le haut du sachet, halo or doux) ; « Ta sélection » montre une case (gros) ou deux (petits), chaque paquet avec ✕ pour le retirer ; changer de format garde le choix. Bouton « Ouvrir » dès qu'une case est remplie. Paquet du jour utilisé : « Le merch est fermé » et le temps restant.
2. **Ouvrir** : « ← Changer de paquet », nom et description du paquet, choix du format (1 gros paquet de 5 cartes ou 2 petits de 2 cartes aux meilleures chances ; 2 points par jour, gros = 2, petit = 1), paquet en grand, geste pour déchirer. Un paquet serveur entamé rouvre directement cette étape.

## Parcours Révélation et rangement
- **Révélation** : une carte à la fois ; phrase « combo » en bandeau incliné sur la carte (taille et couleur selon la rareté, ~3 s). La rangée du bas rouvre les cartes déjà vues. À la dernière carte : « Ranger dans le classeur » et partage (pas d'écran de résumé).
- **Bilan de « Tout ranger »** : une ligne par catégorie (médaillon avec icône, nombre, libellé) avec les miniatures des cartes concernées (6 au plus, puis « +N ») ; les classeurs complétés par leur nom.
- **Rangement** : chaque carte s'affiche en grand, bonus en bandeau (lettrage Metal Mania) ; consigne sur deux lignes au-dessus ; un toucher range et passe à la suivante. Transformation proposée quand elle devient possible.

## Parcours Metal Corner et échange
1. **Onglet** : bloc « Échanger » (deux tuiles : « Montrer mon code » en or avec l'icône QR, « Scanner son code » avec l'icône de viseur, dans des médaillons gravés), objectifs (les terminés en tête, cadre or, reflet d'or qui balaie la carte, icône cadeau qui frétille, « Terminé · récompense » et bouton « Récupérer » ; au toucher la carte s'ouvre puis la récompense arrive (paquet, carte révélée ou ticket artiste prioritaire) ; pastille rouge qui pulse sur l'onglet tant qu'il y a une récompense à prendre), progression en deux onglets : « Ton rang » (anneau or vers le prochain titre, icône du titre au centre, trois compteurs illustrés : musiciens 1 pt, classeurs pliés 4 pts, maîtrises 6 pts) et « Titres N/6 » (tous les titres en cartes : débloqués en or, titre actuel encadré, verrouillés en grisé avec leur condition et une jauge ; Metal Corner = titre social).
2. **Montrer mon code** : QR code sur fond os, code à 6 caractères en or (« ABC 234 »), « Envoyer le lien » (feuille de partage, sinon lien copié), « En attente de ton pote… ».
3. **Scanner** : caméra carrée avec cadre or, et toujours le champ « Ou tape son code ».
4. **Composition** : « Tu donnes » (toucher une carte la retire, « + Ajouter » ouvre la feuille des cartes, encart « X te demande N cartes · Voir ») et « Tu reçois » (toucher = plein écran), cote indicative de chaque côté, état de validation du pote, « Valider l'échange ». Toute carte posée ou retirée annule les validations. Donner un dernier exemplaire passe par une confirmation qui cite les classeurs complets touchés.
   **Feuille des cartes**, deux onglets : « Mon classeur », trié par intérêt pour le pote (Demandées par X, Nouvelles pour X, Raretés que X n'a pas, X les a déjà ; doublons d'abord dans chaque groupe) : toucher pose un exemplaire, toucher encore ajoute un doublon, carte posée = cadre or + « Posée ×N » + bouton « − », « Dernière » en rouge si la donner vide sa case, total dans « C'est bon · N posées ». « Son classeur » (Nouvelles pour toi, Raretés qui te manquent, Tu les as déjà) : toucher demande la carte (étiquette « Demandée »), elle remonte en tête chez le pote ; une demande ne change pas l'échange ni les validations.
   **Réduire** : chevron en haut à gauche de l'écran d'échange (la croix à droite quitte) ; l'échange reste ouvert et une pastille d'encre cerclée d'or au-dessus de la barre d'onglets (« Échange avec X · a validé … REPRENDRE ») permet d'y revenir de n'importe quel écran ; retrouvée après un rechargement. Nombre d'exemplaires toujours dans la légende sous la carte (« RARE ×3 »), jamais en surimpression ; filtre « Doublons seulement ».
5. **Conclusion** : écran de troc, sans révélation carte par carte : « Tu donnes » (petites cartes qui partent vers le haut), l'icône d'échange qui pivote, « Tu reçois » (cartes qui tombent, étiquettes « Nouvelle » et « Bonus rencontre ») ; « Ranger dans le classeur », « Suivre X », « Fermer ». Le cri du pote (s'il en a enregistré un) retentit juste après le jingle ; les cartes reçues, puis la carte bonus de première rencontre, se révèlent comme un paquet (« Échange avec … ») et attendent dans « À ranger ».

6. **Social** (Metal Corner) : « On te propose un échange » (Rejoindre), « Mes potes » (médaillon, nombre d'échanges, Profil, Échanger : proposition par notification), « Tes échanges » (historique : date, cartes données ⇄ reçues). Profil d'un pote = même veste à patchs, calculée sur son classeur, plus « Il lui manque, tu l'as en double » et « Lui proposer un échange ».

7. **Blind test** : chaque maîtrise débloque une carte rouge sang « Blind test débloqué · Jouer » dans le carrousel (casque en médaillon). Écran plein cadre : surtitre « Blind test · Maîtrise de X », « Extrait N / 5 », 5 points (or = trouvé, rouge = raté), disque à égaliseur (toucher = écouter / couper), 4 choix d'artiste en 2 × 2 ; après le choix, bonne réponse en or, mauvaise en rouge, titre du morceau, « Bien vu ! » ou « Raté : c'était X » ; score final « N / 5 » puis récompense (3 = Commune nouvelle, 4 = Rare minimum, 5 = Holo minimum). Joué une fois ; quitter en cours ne le consomme pas.

## Autres écrans
- **Profil** : page à part (avatar, pseudo, capacité de metaleux en texte, cri). La capacité se modifie dans une feuille du bas : idées proposées ou texte perso (120 caractères).
- **Format du paquet** : deux choix compacts (~96 px) centrés, sans cadre ni fond (picto et texte seuls, décidé le 2026-09-28), un seul paquet par jour : Standard · 5 cartes (grand sachet marqué « 5 ») ou Mini · 2 cartes, + de chances (petit sachet marqué « 2 » avec une étincelle) ; picto en haut, nom en Big Shoulders ; choisi = lettres or et légèrement grossi (×1,08), l'autre en os discret.
- **Installer l'app** : feuille du bas « Un paquet offert », un seul chemin selon l'appareil : bouton « Installer » (Android, Chrome), trois étapes illustrées par les icônes de Safari (Partager, En savoir plus, Sur l'écran d'accueil) avec « Pas dans Safari ? » en lien, ou « Ouvrir dans Safari » depuis un autre navigateur iPhone. Proposée à la connexion (3 fois au plus, tous les 3 jours) et depuis le bandeau de l'accueil.
- **Profil public** (« veste à patchs ») : médaillon photo cerclé d'or, pseudo, titre gagné en pastille (Groupie → Légende du pit), capacité en citation, bouton « Écouter son cri » ; vitrine de 3 cartes en éventail ; patchs ronds brodés (classeurs complétés, surpiqûre or en pointillés ; manquants en pointillés os) ; pin's de maîtrise ; setlist en tuiles. Plein écran, fermeture en haut à droite.
- **Notifications** : encadré arrondi à marges, en haut de l'écran ; descend et remonte, sans fondu ; une seule à la fois.
- **Fermer** : bouton rond en surimpression en haut à droite, il ne prend pas de place. Dans une feuille, il reste hors de la zone qui défile, et la feuille s'arrête sous la barre d'état (`100dvh - env(safe-area-inset-top)`).
- **Transformer** : toujours une confirmation (« Transformer » / « Garder mes doublons »), puis la forge : les doublons convergent en cercle et fondent dans un éclat de la couleur de la rareté visée (1,5 s), puis la révélation.
- **Accueil** : « N paquets à ouvrir » avec un sachet par paquet (5 au plus) et le détail réserve / cadeaux.
- **Fiche carte** : rareté en surtitre rouge, nom de l'artiste en titre (blanc), groupe dessous, puces, écoute, coup spécial juste sous l'écoute, raretés obtenues, puis « Transformations » : une jauge de crans par palier (un cran par doublon, « 3/3 »), prête = cadre et crans à la couleur de la rareté visée et bouton « Transformer en … », sinon « Encore N doublons ».
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
- Carte non trouvée : ni nom, ni groupe, ni titre ; classeur de groupe « Groupe mystère » tant qu'aucune carte du groupe n'est trouvée.

## Checklist d'avant livraison (extrait du skill, à cocher à chaque changement d'interface)
- [ ] Contraste texte ≥ 4,5:1 (secondaire ≥ 3:1)
- [ ] Cibles ≥ 44 px, retour à l'appui, focus visible
- [ ] Pas de défilement horizontal ; rien sous les barres ; paysage vérifié
- [ ] Mouvement réduit vérifié
- [ ] Champs avec libellé, erreurs près du champ
- [ ] Icônes SVG cohérentes, libellés d'accessibilité
