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
4. Échanger des cartes avec d'autres fans, **en présentiel uniquement** (troc pur, sans argent réel) — voir `Volet social`.
5. Vivre un concert → nourrir son **avatar de fan** et son **carnet de concerts**.
6. Suivre des **missions** qui donnent une direction concrète à tout ce qui précède — voir `Missions`.

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
- Carte "Live" → variante spéciale débloquée si l'utilisateur était présent au concert concerné (preuve par billet importé, voir `Avatar de fan & carnet de concerts`).
- Événements calendaires (anniversaire d'un album culte, reformation, etc.) déclenchent des drops commémoratifs limités dans le temps.

**Suivi de l'actualité réelle** : un travail éditorial continu (curation manuelle et/ou flux externe — RSS metal news, API type Songkick/Bandsintown pour les dates de concert — à cadrer) reste nécessaire pour détecter ces événements. C'est aussi ce qui conditionne le rythme de contenu.

## Volet social (troc, pas de marché)
**Décision actée : l'échange ne se fait qu'en présentiel, jamais à distance.** Pas de proposition envoyée à un inconnu puis acceptée des heures plus tard ailleurs dans le pays — un échange exige que les deux fans soient physiquement au même endroit au même moment. Conséquence assumée : ça réduit la liquidité des échanges par rapport à un système d'échange à distance (moins de partenaires potentiels accessibles à tout moment) — c'est un choix délibéré, pas un oubli, qui rapproche l'app du vécu réel de collection (comme échanger des Panini dans la cour de récré) plutôt que d'une marketplace déguisée, et qui simplifie fortement la confiance/anti-fraude (pas de colis à expédier, pas de litige à distance).

- **Découverte à distance, exécution en présentiel** : `Communauté` reste consultable à distance (qui possède quoi, qui recherche quoi, classements, guildes) — c'est une vitrine et une liste de souhaits, pas un canal de transaction. La transaction elle-même ne s'ouvre que lorsque deux fans sont détectés physiquement proches (voir `Échanges & rencontres en présentiel` ci-dessous).
- **Composition en direct, à deux** : une fois la session d'échange ouverte entre deux fans proches, les deux téléphones affichent le même écran de composition en temps réel (chacun ajoute ses cartes offertes), avec une confirmation simultanée des deux côtés — pas d'offre envoyée puis attente d'une réponse asynchrone, l'échange se conclut dans l'instant, comme un vrai troc à la main.
- Valeur symbolique de rareté affichée pendant la composition pour équilibrer les échanges, purement indicative — **jamais convertible en argent réel**.
- Guildes/clans par groupe ou sous-genre.
- Classements de collection (par artiste, par festival, global).
- Vitrine de profil public (le "book" à montrer), incluant les classeurs personnalisés mis en avant (voir `Classeurs & récompenses`).
- **Cri enregistré** : un court enregistrement audio de son propre cri/growl metal, affiché comme signature vocale sur son profil public — purement cosmétique et social, sans aucune mécanique de jeu dessus. Dans la même veine "drôle" que la ligne édito (voir positionnement).

## Échanges & rencontres en présentiel (concert et proximité)
Puisque l'échange n'existe qu'en présentiel, il faut un moyen simple de trouver qui échanger avec, sur place. Deux mécanismes complémentaires, tous deux dérivés du même principe de présence partagée opt-in :

- **Présence partagée en concert** : au moment du check-in (voir `Avatar de fan & carnet de concerts`), l'utilisateur peut choisir d'apparaître dans une liste éphémère "Fans présents ce soir", visible uniquement par les autres fans ayant eux aussi activé cette option pour ce même concert. Pas de liste publique par défaut, pas d'historique de localisation conservé au-delà de l'événement.
- **Radar de proximité, hors concert aussi** : généralisation du même principe à n'importe quel moment (avant/après un concert, un festival, chez un pote, dans un disquaire) — détection des autres utilisateurs de l'app à quelques mètres via Bluetooth basse consommation (pas de GPS, portée radio de quelques mètres seulement), opt-in et désactivable à tout instant, jamais de position exacte affichée, aucune trace conservée une fois hors de portée ou l'option désactivée. C'est la réponse concrète à « qui a l'app autour de moi » : un radar de courte portée, pas un suivi de localisation.
- **Ouverture de session** : depuis l'une ou l'autre liste, un tap propose une session d'échange à la personne choisie ; elle doit l'accepter pour que la composition en direct démarre (voir `Volet social`) — jamais de session imposée à sens unique.
- **Carte bonus de connexion** : la première rencontre confirmée mutuellement avec un autre fan (échange conclu, ou simple "on s'est croisés" confirmé des deux côtés) débloque une **carte bonus garantie, non aléatoire** — même logique de récompense que les classeurs/paliers (voir `Classeurs & récompenses`). Ça donne un contenu concret au titre "Metal Corner" de la progression d'avatar.

Les garde-fous déjà posés pour la présence partagée en concert (opt-in, réciproque, éphémère, pas de position exacte) s'appliquent identiquement au radar de proximité généralisé — c'est la même mécanique, juste plus disponible dans le temps.

## Missions
Les classeurs et paliers (voir `Classeurs & récompenses`) disent *ce qui existe à collectionner* ; les missions disent **quoi faire maintenant**. C'est la couche qui donne une direction concrète, visible et renouvelée à un utilisateur qui ne saurait pas spontanément quoi faire de sa prochaine session.

**Principe** : une mission a toujours un objectif clair, une progression visible, et une récompense garantie à l'accomplissement (XP avatar systématique, et selon la mission un pack gratuit ou un cosmétique) — jamais de tirage aléatoire en récompense de mission, ce serait rouvrir la question loot-box pour une mécanique qui doit au contraire renforcer le sentiment de maîtrise (même logique que `Classeurs & récompenses`).

**Catégories (liste volontairement large, à cribler en game design)** :
- **Collection** — obtenir une carte d'une rareté donnée, compléter un thème précis, réunir des cartes Membre dans N instruments différents, obtenir une carte de chaque type sur un même artiste.
- **Échange (en présentiel)** — conclure un échange, échanger avec 3 fans différents dans le mois, faire un échange pendant un concert, faire un échange avec un membre de sa guilde.
- **Concert / vécu réel** — check-in à un concert (billet importé), remplir son carnet le lendemain, assister à deux concerts d'un même sous-genre, activer la présence partagée et confirmer une rencontre ("on s'est croisés").
- **Social / communauté** — rejoindre une guilde, participer au classement hebdomadaire, enregistrer son cri signature, créer un classeur personnalisé.
- **Découverte** — consulter l'évolution d'une carte suite à une actu réelle, suivre un nouveau sous-genre ou artiste.
- **Achat réel (album, billet, merch)** — acheter un album ou un billet de concert via un lien partenaire, acheter du merch d'un artiste suivi. Catégorie liée à `Monétisation` : elle suppose soit un partenariat marchand permettant une confirmation d'achat fiable, soit à défaut une preuve déclarative (photo de reçu) — moins fiable, à traiter comme telle plutôt que comme une vérification forte.

**Cadence, pour rester cohérent avec `ARCHITECTURE-FLOWS.md` (boucles de rétention)** : quelques missions actives en parallèle plutôt qu'une liste illimitée, à cadences mêlées — une mission courte (quotidienne/légère), une mission de la semaine, et occasionnellement une mission saisonnière liée à un événement réel (tournée, sortie d'album majeure, festival). Une mission accomplie est remplacée, pas accumulée à l'infini.

**Anti-pattern à respecter** : une mission ne doit jamais pousser à une action qui n'a pas de valeur en soi si elle échouait à débloquer la récompense — "va à un concert" reste une bonne expérience même sans la carte bonus, "envoie un message à 10 inconnus" ne le serait pas. Écarter toute mission dont le seul but perçu serait la récompense.

## Avatar de fan & carnet de concerts
Chaque utilisateur a un avatar personnel qui évolue selon **trois sources combinées**, pas seulement le vécu live : sa collection de cartes, son vécu de concerts réels, et son profil de spectateur déclaré.

**Source 1 — Collection de cartes**
Diversité de sous-genres/groupes suivis, rareté moyenne possédée, thèmes complétés, diversité d'instruments collectionnés via les cartes Membre : nourrit des traits d'identité de collectionneur sur l'avatar (ex. sous-genre dominant affiché).

**Détection et preuve de concert — par billet, pas par suivi d'artiste**
Croiser les artistes suivis avec un agenda de concerts externe a été écarté : ça dépend d'une intégration d'agenda tierce (Songkick/Bandsintown ou équivalent) à maintenir, pour un résultat qui reste probabiliste (l'utilisateur suit-il vraiment l'artiste dont il va voir le concert ce soir-là ?). Le **billet, électronique ou physique, sert directement de preuve** — plus simple et plus fiable :
- **Billet électronique** : scan du QR/code-barres du billet (affiché sur le téléphone) via l'appareil photo. Si le code n'est pas exploitable directement (pas de partenariat billetterie établi), l'utilisateur confirme/complète manuellement artiste, date et lieu à partir de ce qui a été lu.
- **Billet physique** : même mécanique de scan sur le billet imprimé.
- **Repli** : photo du billet (avec tentative de lecture automatique) ou saisie manuelle complète, pour les cas sans code scannable (accès guestlist, billet au nom d'un tiers).
- **Deux niveaux de preuve** : le billet scanné suffit pour le carnet de concert et l'XP avatar (niveau "standard"). Une **géolocalisation ponctuelle le jour même**, optionnelle, apporte un niveau de preuve renforcé — c'est cette version renforcée qui conditionne la carte Live exclusive (voir `Mécanique d'évolution des cartes`), pour limiter (sans l'exclure complètement) le cas d'un billet scanné sans y être allé.
- Cette approche supprime le besoin de maintenir un catalogue d'artistes suivis pour la détection : le billet dit déjà tout (quel artiste, quelle date, quel lieu).

**Vécu de concert (double mécanisme de captation)**
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
- **Sécurité de la présence partagée et du radar de proximité** : rendre visible qu'un utilisateur est physiquement présent ou à proximité peut créer un risque de repérage/harcèlement s'il n'est pas encadré — risque désormais plus large qu'au lancement du concept puisque le radar de proximité (voir `Échanges & rencontres en présentiel`) n'est plus limité aux concerts. Garde-fous déjà posés (opt-in réciproque, éphémère, jamais de position exacte, jamais de liste publique par défaut) — à faire challenger par un tiers compétent sur la sécurité/vie privée avant lancement, au même titre que les autres risques listés ici.
- **Données du billet importé** : le scan ou la photo d'un billet peut contenir des données personnelles (nom de l'acheteur, parfois un moyen de contact). À traiter comme une donnée personnelle standard (minimisation, pas de conservation au-delà du besoin de preuve de concert) plutôt que comme une simple métadonnée technique.
- **Preuve d'achat déclarative (missions "achat réel")** : en l'absence de partenariat marchand vérifiable, une preuve par photo de reçu reste falsifiable — à ne jamais associer à une récompense dont la valeur perçue inciterait à la triche, et à documenter comme un socle "best effort", pas une vérification forte.

## Statut
Concept validé comme base de travail pour la suite (direction visuelle, puis maquettage), enrichi d'une décision structurante (échange en présentiel uniquement), d'un mécanisme de détection/preuve de concert simplifié (billet plutôt que suivi d'artiste + agenda), et d'une couche Missions. Les idées écartées du MVP ou à explorer plus tard sont conservées dans `ROADMAP-IDEAS.md` pour ne rien perdre.
