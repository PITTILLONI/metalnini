# Circle pit : moteur de jeu, sensation et gameplay

Date : 2026-11-14. Statut : validé par le propriétaire le 2026-11-14.

## Pourquoi

La course du circle pit (Fosse, `proto/index.html`, `pitRunGo`) déçoit le propriétaire sur cinq points, dans ses mots :
la sensation de jeu et la latence, le manque d'immersion, le manque de précision, le manque de gameplay, le manque de réalisme.

Ce que le code d'aujourd'hui explique :
- latence voulue : la vitesse est lissée (`go.v += (… - go.v) * .25`), le pit suit le doigt avec plusieurs images de retard ;
  `getBoundingClientRect()` relu à chaque mouvement ;
- précision perdue : un seul point de toucher lu par événement (les points intermédiaires de l'iPhone sont ignorés), zone morte au centre ;
- rendu en éléments de page : photo fixe (`fosse/pit.jpg`), silhouettes de page, une particule de poussière = un élément + une animation GSAP ;
- une seule règle : garder sa vitesse dans la zone dorée pendant 20 s.

## Ce que le joueur doit vivre (demandé par le propriétaire)

1. **La vitesse** : on court dans le cercle, ça défile.
2. **Trébucher**.
3. **Relever des gens** tombés.
4. **Faire grossir le cercle**.
5. **Se reposer** (sortir souffler, revenir).
6. **Attirer des potes dans le cercle**.
7. **Se mettre au milieu**, pour les plus courageux : plus risqué, plus payant.

## Objectifs, non-objectifs, anti-objectifs

- Objectifs : réponse au doigt sans retard perceptible ; 60 images/s tenues sur iPhone (120 sur écran ProMotion si possible) ;
  les 7 points ci-dessus jouables dans une course ; la foule et les potes présents à l'écran.
- Non-objectifs (cette fois) : pit en direct à plusieurs (prévu plus tard, voir « Multijoueur ») ; slam, pogo et autres danses ;
  app iOS native ; refonte des récompenses.
- Anti-objectifs : une page qui met plusieurs secondes à charger le jeu ; un jeu illisible au pouce sur un écran de téléphone ;
  casser les pits en cours, les notifications, Rameuter ou les récompenses existantes ; un style graphique qui sort de la DA (tarot gravé, rouge sombre, noir, or).

## Contraintes du dépôt
- Règles de `CLAUDE.md` : vanilla JS, commentaires courts en français, code mort retiré, `node tools/test_proto.js` vert,
  captures à 390 × 664 et 430 × 932 avant tout push, rien de poussé sans l'accord du propriétaire (le push sur `main` met en ligne).
- Interface : `design-system/metalnini/MASTER.md` et le skill ui-ux-pro-max (cibles tactiles, mouvement réduit).
- Animations réduites (`prefers-reduced-motion`) : pas de secousse ni de traînées, jeu identique.
- iPhone : pas d'API de vibration dans Safari, `buzz()` a déjà un repli ; `body.playing` masque l'appli pendant la course (à garder).

## Décisions prises avec le propriétaire

- **Multijoueur** : en différé d'abord, avec les « fantômes » des courses des potes ; le passage au direct vient plus tard,
  et la conception doit le préparer (option C).
- **Moteur** : PixiJS (rendu 2D WebGL), physique et gameplay écrits pour le pit, dans la page actuelle (option A).

## Approches étudiées

| Approche | Pour | Contre | Décision |
|---|---|---|---|
| A. PixiJS + physique maison | léger (~200 Ko), très rapide, s'insère dans la page, physique taillée pour une foule sur un anneau | physique à écrire (simple : des disques sur un anneau) | **retenue** |
| B. Phaser | moteur complet (physique, scènes, sons) | ~1 Mo, physique générique à contourner pour une foule qui tourne | écartée |
| SpriteKit natif | le plus fluide | l'app iOS n'a pas de Fosse ; le jeu vit sur le web | écartée pour l'instant |
| Unity / Godot exportés en web | puissants | > 10 Mo, démarrage lent sur Safari iPhone | écartée |
| Rive seul | animation de qualité, connue du propriétaire | ni physique ni gameplay | plus tard, pour les personnages et l'entrée dans le pit |

## Conception

### Intégration
- PixiJS v8, version exacte, chargé à la demande depuis cdn.jsdelivr.net au moment d'ouvrir la salle du pit (comme GSAP aujourd'hui) ;
  si le chargement échoue, l'ancienne course reste disponible (repli).
- Le jeu vit dans un module à part (`proto/fosse/pit-game.js`), appelé par `pitRunGo` ; tout ce qui entoure la course
  (rameuter, palier, récompense, `pitRunEnd`) reste en place.
- Le moteur tourne au rythme de l'écran ; la simulation avance à pas fixe (1/120 s) pour rester identique d'un téléphone à l'autre
  et pour que les fantômes rejouent exactement.

### Commandes et latence
- Lecture de tous les points de toucher (`getCoalescedEvents`) ; rectangle de l'anneau mis en cache (recalculé au redimensionnement seulement).
- Pas de lissage sur la position : le coureur suit le doigt dans la même image. Le lissage, s'il en faut, porte seulement sur l'affichage de la vitesse.
- Geste (choix du propriétaire) : le pouce dirige. Poser le pouce n'importe où sur l'écran, glisser vers l'avant = accélérer,
  sur les côtés = aller vers le bord (repos) ou vers le milieu ; lâcher = ralentir. Relever, attirer un pote : passer dessus en ralentissant.
  La sensation de vitesse vient de l'image et du son, plus de l'effort du doigt. L'ancien geste (dessiner des cercles) disparaît avec la nouvelle course.

### Le coureur et la foule
- Le pit est un anneau vu de dessus, caméra qui suit le joueur et tourne avec lui pour qu'il coure toujours « vers le haut ».
- Foule simulée : 20 à 40 coureurs (disques avec silhouette), qui se bousculent (collisions disque-disque), changent de vitesse,
  tombent parfois. Spectateurs immobiles autour (bord de l'anneau), qui crient et lèvent les bras quand le pit accélère.
- Fantômes des potes : les courses déjà faites dans ce pit sont rejouées en même temps que la mienne, avec leur avatar.

### Mécaniques
- **Vitesse et sensation** : traînées de mouvement, poussière en particules (un seul système de particules), foule qui défile,
  léger zoom arrière quand on accélère, secousse à l'impact, sons de pas et de foule, vibration (`buzz`).
- **Endurance** : jauge qui baisse quand on court vite, remonte au repos. Basse = démarche moins sûre, trébuche plus.
- **Trébucher** : un choc trop fort (vitesse élevée contre un coureur, ou endurance vide) fait tomber ; se relever = quelques touchers rapides,
  ou un coureur (fantôme de pote) qui passe te relève. Temps perdu, pas de course finie.
- **Relever quelqu'un** : un coureur tombé sur la trajectoire ; ralentir et maintenir le doigt sur lui une fraction de seconde le relève.
  Coûte de la vitesse, rapporte des points et fait grossir le cercle.
- **Se reposer** : glisser vers le bord extérieur, on sort de l'anneau ; l'endurance remonte, le cercle continue sans nous.
- **Attirer des potes** : les potes qui ne courent pas encore apparaissent au bord ; passer près d'eux et les « tirer » dans l'anneau
  les fait entrer comme coureurs et leur envoie l'appel Rameuter existant (`fosse_call`, une fois par pote et par pit, règles inchangées).
- **Le milieu** : on peut couper vers le centre. Les coureurs y traversent plus souvent, on y tombe plus, mais chaque seconde y vaut double.
- **Le cercle grossit** : sa taille à l'écran suit une valeur commune au pit (tours, relevés, potes attirés, de toutes les courses).
- **Le rythme** : l'extrait du morceau joue déjà ; courir dans le tempo donne un bonus. Tempo (choix du propriétaire) : détecté à l'écoute de l'extrait par Web Audio ; si l'extrait ne peut pas être analysé (accès refusé par Apple), tempo saisi une fois par morceau (`TRACK_BPM` dans `proto/index.html`), et en dernier recours pas de bonus de rythme.

### Score, serveur, compatibilité
- Durée d'une course : réglage `run_s` existant (aujourd'hui 20 s) ; 40 s (choix du propriétaire), pour laisser le temps de se reposer : `settings.pit.run_s` passe à 40 dans la migration.
- Le score envoyé reste un entier de 0 à 100 (`pit_run_finish`), pour garder paliers, points et récompenses inchangés ;
  il combine tours, temps dans le tempo, relevés, potes attirés et bonus du milieu, plafonné à 100.
- Nouvelle migration : `pit_runners.trace` (jsonb, la course compressée : positions échantillonnées à 10 Hz et événements) et
  `pits.circle` (taille commune), renvoyés par `pit_state` ; `pit_run_finish` accepte la trace (taille plafonnée).
- Le score reste calculé par l'app, comme aujourd'hui (le serveur vérifie la durée) ; triche possible, acceptée à ce stade.

### Multijoueur (plus tard)
- Même simulation, mêmes traces : en direct, les positions des autres arrivent par Supabase Realtime au lieu d'être rejouées.
  Rien à écrire maintenant, sauf garder la simulation déterministe et séparée de l'affichage.

### Graphismes et sons
- Silhouettes et décor dessinés dans la DA (gravure, rouge sombre, noir, or) ; une première version en formes simples,
  remplacées par des sprites ou des animations Rive ensuite.
- Sons : ceux de `proto/sounds/` ; pas, souffle, foule à ajouter (fiche dans `sons.html`).

### Tests
- Banc jsdom existant (`tools/test_proto.js`) : la salle s'ouvre, la course démarre et finit, repli sans PixiJS.
- Simulation testée seule (déterministe : même trace = même score).
- Réglage du ressenti sur iPhone par le propriétaire (latence, difficulté, lisibilité).

## Laissé au développeur
- Valeurs de réglage (vitesses, chances de trébucher, poids du score), à exposer dans `settings.pit` pour l'admin.
- Format exact de la trace, tant qu'elle reste petite (< 20 Ko).
- Découpage interne du module.

## Questions ouvertes
Aucune : geste, durée et tempo tranchés le 2026-11-14.
