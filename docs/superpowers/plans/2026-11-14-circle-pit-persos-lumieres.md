# Circle pit : vrais corps, photos et lumières, plan de mise en œuvre

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** remplacer l'affichage vue de dessus du circle pit par une vue drone de dos, avec des corps animés dessinés par le code, les photos de profil des joueurs et des lumières de concert, sans toucher à la simulation ni au serveur.

**Architecture :** quatre petits modules à côté de `pit-view.js`, chacun avec une partie pure testée sous Node et une partie PixiJS : projection et caméra (`pit-proj.js`), corps et poses (`pit-bodies.js`), photos (`pit-photo.js`), lumières (`pit-light.js`). `pit-view.js` les assemble ; `proto/index.html` fournit les adresses des photos.

**Tech Stack :** vanilla JS (style ES5 de `proto/index.html`, export `module.exports` ou `window.X`), PixiJS 8.6.6, Canvas 2D pour la bichromie, Node pour les tests.

**Spec :** `docs/superpowers/specs/2026-11-14-circle-pit-persos-lumieres-design.md` (suite de `2026-11-14-circle-pit-moteur-design.md`)

## Global Constraints

- Simulation (`pit-sim.js`), commandes (`inputFrom`, `anchorOn`), score, fantômes et serveur inchangés.
- Caméra de dos et en hauteur (drone), le joueur court vers le haut de l'écran.
- Photos : pastille ronde liseré or au-dessus de la tête pour les coureurs vus de dos (moi, fantômes) ; visage posé sur le corps pour les potes au bord, un coureur à terre, et moi quand je relève quelqu'un ; bichromie noir et or par défaut (`photoStyle: 'palette'`), `'naturel'` possible ; sans photo ou photo en échec : tête dessinée, aucune erreur.
- Lumières : rouge sang `#b23a3a` et or `#eb9a26` sur fond `#0d0a08` ; mouvement réduit = ni flash ni balayage rapide.
- 40 coureurs au plus, 60 images/s visées sur iPhone 12 et plus ; poses précalculées en textures au chargement ; bichromie faite une fois par photo.
- `node tools/test_pit_sim.js` et `node tools/test_proto.js` verts ; rien poussé sans l'accord du propriétaire ; vérification visuelle sur `proto/?pitbanc` par le propriétaire (serveur local refusé à Claude) ou par Claude s'il l'autorise.

## Review Focus

1. **Photo qui ne charge pas** (adresse expirée, accès refusé, réseau) : tête dessinée, la course continue (test Task 3).
2. **Coureur derrière la caméra ou tout près d'elle** : il n'est pas dessiné en géant ni à l'envers (test Task 1).
3. **Écran qui change de taille ou d'orientation en pleine course** : la caméra se recale, le joueur reste au même endroit de l'écran (test Task 1).
4. **Joueur sans photo de profil, pote sans photo** : pastille avec initiale, pas de trou (test Task 3).
5. **Tempo absent** (`bpm: null`) : les lumières balaient sans pulsation, sans erreur (test Task 4).

---

## Fichiers

| Fichier | Rôle |
|---|---|
| `proto/fosse/pit-proj.js` (créé) | `PitProj` : caméra drone et projection anneau → écran (pur). |
| `proto/fosse/pit-bodies.js` (créé) | `PitBodies` : allures de la foule, poses articulées (pur), cuisson des poses en textures (PixiJS). |
| `proto/fosse/pit-photo.js` (créé) | `PitPhoto` : bichromie (pur), chargement d'une photo en canevas rond. |
| `proto/fosse/pit-light.js` (créé) | `PitLight` : faisceaux et pulsations (pur), dessin additif (PixiJS). |
| `proto/fosse/pit-view.js` (modifié) | Assemble le tout ; garde `start`, `inputFrom`, `anchorOn`. |
| `proto/index.html` (modifié) | Scripts, adresses des photos (moi, fantômes, potes), banc `?pitbanc` avec photos d'essai. |
| `tools/test_pit_sim.js` (modifié) | Tests purs des quatre modules. |

### Task 1 : caméra drone et projection

**Files :** Create `proto/fosse/pit-proj.js` ; Modify `tools/test_pit_sim.js`

**Interfaces :**
- Produces : `PitProj.camera(me:{a,r}, w:number, h:number) -> Cam` ; `PitProj.project(cam, a, r) -> { x, y, scale, depth, visible }`.
  Repère : le monde est tourné pour que je coure vers le haut ; le joueur est projeté en `(w/2, h*0.78)` avec `scale = 1` ; profondeur = distance devant la caméra le long de ma direction de course ; `visible = false` si `depth < 0.08` (derrière ou contre la caméra) ; `scale` entre 0.25 et 1.4.

- [ ] **Step 1 : tests qui échouent :**
  - `projection : le joueur est en bas au centre` : `project(cam, me.a, me.r)` → `x === w/2`, `|y - 0.78*h| < 1`, `|scale - 1| < 1e-6`.
  - `projection : un coureur devant est plus haut et plus petit` : `a = me.a + 0.05` → `y < 0.78*h` et `scale < 1`.
  - `projection : le bord à droite, le milieu à gauche` : même `a`, `r = 0.97` → `x > w/2` ; `r = 0.3` → `x < w/2`.
  - `projection : derrière la caméra, invisible` : `a = me.a - 0.08` → `visible === false`.
  - `projection : changement de taille d'écran` : `camera(me, 430, 932)` → joueur en `(215, 0.78*932)`.
- [ ] **Step 2 :** `node tools/test_pit_sim.js` → échecs (module absent).
- [ ] **Step 3 : implémenter.** Coordonnées monde `(r cos 2πa, r sin 2πa)` ; caméra placée à `0.35` derrière moi le long de la tangente, regardant dans le sens de course ; pour un point : `depth` = distance devant la caméra (moi : 0.35), `lateral` = décalage vers l'extérieur de l'anneau ; `k = 0.35 / depth` ; `scale = clamp(k, 0.25, 1.4)` ; `x = w/2 + lateral * k * w * 0.9` ; `y = horizon + (0.78*h - horizon) * k` avec `horizon = 0.18*h` (borné à l'écran) ; `visible = depth >= 0.08`.
- [ ] **Step 4 :** tous OK.
- [ ] **Step 5 : commit** `Circle pit : caméra drone et projection de l'anneau`.

### Task 2 : corps et poses

**Files :** Create `proto/fosse/pit-bodies.js` ; Modify `tools/test_pit_sim.js`

**Interfaces :**
- Produces : `PitBodies.looks(seed:int, n:int) -> Look[]` avec `Look = { build:0..5, hair:0..7, skin:int couleur, shirt:int couleur, print:0..3, jacket:bool }` ;
  `PitBodies.pose(kind:'run'|'stumble'|'down'|'up'|'lift'|'cheer', phase:0..1) -> { head:[x,y], neck, hip, lHand, rHand, lElbow, rElbow, lKnee, rKnee, lFoot, rFoot }` (unités du corps : hauteur 1, sol à y = 0, vu de dos) ;
  `PitBodies.bake(PIXI, app, look, opts:{ face:Texture|null }) -> { run:Texture[8], stumble:Texture[4], down:Texture, up:Texture[4], lift:Texture[4], cheer:Texture[4] }`.

- [ ] **Step 1 : tests qui échouent :**
  - `allures : même graine, mêmes allures ; 40 allures, au moins 5 carrures et 6 coupes différentes`.
  - `course : les pieds alternent` : `pose('run', 0).lFoot[1] > pose('run', 0).rFoot[1]` (pied gauche levé) et l'inverse à `0.5`.
  - `à terre : tout près du sol` : toutes les articulations de `pose('down', 0)` ont `y < 0.25`.
  - `relever : une main tendue vers l'avant et vers le bas` ; `bras levés : les deux mains au-dessus de la tête` (`cheer`).
- [ ] **Step 2 :** échecs attendus.
- [ ] **Step 3 : implémenter** `looks` (mulberry32 comme `pit-sim.js`), `pose` (cycle de course en sinus, cinématique simple), `bake` (Graphics : membres en traits arrondis, buste en t-shirt avec motif, cheveux, puis `renderer.generateTexture` par image).
- [ ] **Step 4 :** tous OK.
- [ ] **Step 5 : commit** `Circle pit : corps articulés et poses`.

### Task 3 : photos de profil

**Files :** Create `proto/fosse/pit-photo.js` ; Modify `tools/test_pit_sim.js`

**Interfaces :**
- Produces : `PitPhoto.duotone(px:Uint8ClampedArray) -> void` (sur place : luminance 0 → `#0d0a08`, 1 → `#f4b243`, ombres teintées de `#b23a3a` à 15 %) ;
  `PitPhoto.load(url:string|null, style:'palette'|'naturel', size:number) -> Promise<HTMLCanvasElement|null>` (rond, liseré or de 2 px ; `null` si pas d'adresse ou en échec, jamais de rejet) ;
  `PitPhoto.initial(name:string, size:number) -> HTMLCanvasElement` (pastille or avec l'initiale, pour qui n'a pas de photo).

- [ ] **Step 1 : tests qui échouent :** `bichromie : noir → encre, blanc → or, gris moyen entre les deux` ; `photo : adresse vide → null sans erreur` ; `photo : chargement en échec → null` (dans Node, `load` reçoit un faux `Image` qui déclenche `onerror`, injecté par `PitPhoto._img`).
- [ ] **Step 2 :** échecs attendus.
- [ ] **Step 3 : implémenter.** `crossOrigin = 'anonymous'` sur l'image ; bichromie une seule fois par photo ; délai maximal de 4 s puis `null`.
- [ ] **Step 4 :** tous OK.
- [ ] **Step 5 : commit** `Circle pit : photos de profil en bichromie, repli sans photo`.

### Task 4 : lumières

**Files :** Create `proto/fosse/pit-light.js` ; Modify `tools/test_pit_sim.js`

**Interfaces :**
- Produces : `PitLight.beams(tMs:number, opts:{ beatT:number|null, flashT:number|null, reduce:bool }) -> [{ x:0..1, angle:rad, width:0..1, color:int, intensity:0..1 }]` (3 faisceaux : 2 rouges, 1 or ; `beatT` = ms depuis le dernier battement, `flashT` = ms depuis le dernier flash) ;
  `PitLight.layer(PIXI, app) -> { container, draw(beams, w, h) }` (dégradés en mode additif, voile sombre, halo autour du joueur).

- [ ] **Step 1 : tests qui échouent :** `lumières : 3 faisceaux, couleurs rouge et or` ; `lumières : ils balaient (angles différents à 0 et 2000 ms)` ; `lumières : pulsation juste après un battement (intensité plus forte à beatT 0 qu'à 400)` ; `lumières : sans tempo, pas d'erreur et intensité stable` ; `mouvement réduit : pas de flash (intensité identique avec et sans flashT) et balayage 4 fois plus lent`.
- [ ] **Step 2 :** échecs attendus.
- [ ] **Step 3 : implémenter.**
- [ ] **Step 4 :** tous OK.
- [ ] **Step 5 : commit** `Circle pit : projecteurs, pulsation sur le tempo et flashs`.

### Task 5 : nouvel affichage

**Files :** Modify `proto/fosse/pit-view.js`

**Interfaces :**
- Consumes : `PitProj` (Task 1), `PitBodies` (Task 2), `PitPhoto` (Task 3), `PitLight` (Task 4).
- Produces : `PitGame.start(host, opts)` inchangé, plus `opts.me.avatar`, `opts.ghosts[i].avatar`, `opts.friends[i].avatar` = **adresses** d'images (ou `null`) et `opts.photoStyle` (`'palette'` par défaut).

- [ ] **Step 1 : tests :** les tests `commandes` et `pouce levé…` restent verts ; nouveau test `affichage : chargé sans PixiJS ni DOM, PitGame expose start, inputFrom, anchorOn` (vm).
- [ ] **Step 2 :** lancer, vérifier.
- [ ] **Step 3 : implémenter.** Au démarrage : allures (`looks`, 40 au plus avec moi, fantômes et potes), cuisson des poses, chargement des photos en parallèle (la course démarre sans attendre ; la photo remplace l'initiale dès qu'elle arrive). À chaque image : caméra (`camera`), projection et tri par profondeur, choix de la pose et de l'image d'animation (cadence = vitesse), ombre au sol, pastille photo au-dessus de la tête (moi, fantômes), visage sur le corps (potes au bord, coureur à terre, moi en train de relever), lumières (`beams` + `layer.draw`), poussière, HUD inchangé. Retirer le code de la vue de dessus devenu inutile (sol vu de dessus, texture ovale, rotation du monde, traînées si remplacées).
- [ ] **Step 4 :** `node tools/test_pit_sim.js` → tous OK.
- [ ] **Step 5 : commit** `Circle pit : vue drone de dos, corps animés, photos et lumières`.

### Task 6 : photos fournies par l'appli, banc, vérification

**Files :** Modify `proto/index.html` (`pitRunGame`, `pitGameFriends`, banc `?pitbanc`, scripts) ; Modify `tools/test_proto.js`

**Interfaces :**
- Consumes : `ONLINE.mediaUrl('avatars', path)`, `MEDIA.avatar` (ma photo), `r.avatar` (chemin, coureurs du pit), le chemin de photo des potes renvoyé par `my_friends` (s'il existe ; sinon `null`).

- [ ] **Step 1 : test qui échoue** (section 18 ter) : `circle pit : adresses des photos passées au jeu` → `gameOpts.ghosts[0].avatar` est l'adresse résolue du chemin `avatar` du coureur (fausse `mediaUrl` qui renvoie `'u:' + path`), `gameOpts.me.avatar === MEDIA.avatar`.
- [ ] **Step 2 :** échec attendu.
- [ ] **Step 3 : implémenter.** Résoudre les chemins en adresses pendant le décompte de 3 s (`Promise.all`, 2 s au plus ; ce qui n'est pas prêt part à `null`). Scripts `pit-proj.js`, `pit-bodies.js`, `pit-photo.js`, `pit-light.js` avant `pit-view.js`. Banc : photos d'essai = visages recadrés des cartes du jeu (`cards/<id>-base.jpg`, même origine), 3 fantômes et 2 potes.
- [ ] **Step 4 :** `node tools/test_proto.js` → tous OK, aucune erreur JS ; puis vérification visuelle sur `proto/?pitbanc` (ordinateur et iPhone, par le propriétaire ou par Claude avec serveur autorisé) : corps lisibles, photos en pastille et en visage, lumières, fluidité.
- [ ] **Step 5 : commit** `Circle pit : photos de profil des joueurs dans la course, banc avec photos d'essai`, puis ligne datée dans `CLAUDE.md`.
