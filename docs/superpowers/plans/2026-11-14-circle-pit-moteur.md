# Circle pit : nouveau moteur, plan de mise en œuvre

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** remplacer la course du circle pit par un jeu PixiJS (pouce qui dirige, endurance, chutes, relevés, potes attirés, milieu, rythme, fantômes des potes), sans toucher aux paliers ni aux récompenses.

**Architecture :** trois modules classiques chargés par `<script>` (globals, pas de bundler) : une simulation pure et déterministe (`pit-sim.js`, testée sous Node), une détection de tempo pure (`pit-beat.js`), un affichage PixiJS qui pilote la simulation à pas fixe (`pit-view.js`). `proto/index.html` charge PixiJS à la demande et garde l'ancienne course en repli. Une migration ajoute la trace (fantômes) et la taille commune du cercle.

**Tech Stack :** vanilla JS (ES5 comme `proto/index.html` : `var`, fonctions, IIFE), PixiJS 8.6.6 (`https://cdn.jsdelivr.net/npm/pixi.js@8.6.6/dist/pixi.min.js`, global `PIXI`), Web Audio, Supabase (PL/pgSQL), Node pour les tests.

**Spec :** `docs/superpowers/specs/2026-11-14-circle-pit-moteur-design.md`

## Global Constraints

- Règles de `CLAUDE.md` : commentaires courts en français, code mort retiré, style du fichier, pas de doublon CSS ni de keyframes du même nom.
- `node tools/test_proto.js` : tous OK, aucune erreur JS ; `node tools/test_pit_sim.js` : tous OK.
- Captures 390 × 664 et 430 × 932 (`tools/capture/`) avant tout push ; rien de poussé sans l'accord du propriétaire.
- Score envoyé : entier de 0 à 100. Paliers, points et récompenses inchangés.
- Durée de course : `settings.pit.run_s` = 40.
- Simulation à pas fixe de 1/120 s ; même graine + mêmes entrées = même résultat, au bit près.
- Trace : < 20 000 caractères en JSON pour 40 s.
- Appel d'un pote : `ONLINE.fosseCall('pit', pitId, friendId)`, règles inchangées (une fois par pote et par pit).
- Mouvement réduit (`matchMedia('(prefers-reduced-motion: reduce)')`) : ni secousse ni traînées ; gameplay identique.
- DA : noir d'encre `#0d0b0a`, or chaud, os, rouge sang (jetons de `design-system/metalnini/MASTER.md`) ; Big Shoulders Display pour les chiffres.
- PixiJS indisponible (réseau, WebGL absent) : l'ancienne course (`pitRunLegacy`) démarre, sans message d'erreur.

## Review Focus

1. **App mise en arrière-plan pendant la course** (appel, verrouillage) : au retour, la simulation ne doit pas rattraper des dizaines de secondes d'un coup ; on plafonne le pas accumulé à 250 ms par image (test Task 1).
2. **Pouce levé puis reposé ailleurs** : l'ancre se recale sur le nouveau point, pas de saut de vitesse (test Task 6, entrée simulée).
3. **Pit sans fantôme ni pote à attirer** (premier coureur, joueur sans potes) : la course marche, le score atteint quand même 100 au mieux (test Task 3).
4. **Trace corrompue ou d'un ancien format renvoyée par le serveur** : le fantôme est ignoré, la course continue (test Task 3).
5. **Migration pas encore appliquée** (client poussé avant la base) : `pitRunFinish` à 4 arguments échoue ; le client renvoie alors le score seul (test Task 7).

---

## Fichiers

| Fichier | Rôle |
|---|---|
| `proto/fosse/pit-sim.js` (créé) | `window.PitSim` / `module.exports` : état, pas de simulation, score, trace, rejeu des fantômes. Aucun accès au DOM. |
| `proto/fosse/pit-beat.js` (créé) | `window.PitBeat` / `module.exports` : tempo d'un signal audio. |
| `proto/fosse/pit-view.js` (créé) | `window.PitGame` : PixiJS, commandes, caméra, HUD, sons, boucle à pas fixe. |
| `tools/test_pit_sim.js` (créé) | Tests Node de la simulation et du tempo (sans dépendance). |
| `backend/supabase/migrations/0076_pit_engine.sql` (créé) | Trace, cercle commun, `run_s` 40, réglages du jeu. |
| `proto/index.html` (modifié) | Scripts, `ONLINE.pitRunFinish`, `pitRunGo` → nouveau jeu ou `pitRunLegacy`, `TRACK_BPM`. |
| `tools/test_proto.js` (modifié) | Intégration avec un `PitGame` factice, repli, ancien serveur. |
| `tools/sound_cues.json`, `sons.html` (modifiés) | Sons pas, souffle, foule, chute. |
| `CLAUDE.md` (modifié) | Ligne datée « Où en est le projet ». |

## Modèle de la simulation (référence pour les Tasks 1 à 3)

- Repère : angle `a` en tours (0 à 1, sens inverse des aiguilles = positif), rayon `r` normalisé : milieu `r < 0.45`, piste `0.45 ≤ r ≤ 0.9`, bord (repos) `r > 0.9`, `r` borné à [0.05, 1].
- Réglages par défaut `PitSim.DEFAULTS` (écrasés par `settings.pit.game`) :
  `{ npc: 24, vmax: 1.2, accel: 2.5, lateral: 0.9, drain: 0.12, regen: 0.25, regenSlow: 0.05, body: 0.035,
     fallBase: 0.15, fallTired: 0.6, middleRisk: 2, downS: 1.5, upTaps: 4, npcFallPerS: 0.02, npcDownS: 4,
     liftHoldS: 0.4, liftMaxV: 0.4, pullHoldS: 0.5, pullAngle: 10 / 360, groove: 0.6,
     pts: { lap: 4, lift: 6, pull: 8, middleS: 1, rhythm: 30 }, circle: { lap: 1, lift: 2, pull: 3 } }`
  (`vmax` en tours/s ; `liftMaxV` et `groove` en fraction de `vmax`).
- Entrée par pas : `{ throttle: 0..1, lateral: -1..1, tap: bool }` (lateral < 0 = vers le milieu).
- Hasard : générateur mulberry32 seedé (`seed` entier) ; jamais `Math.random` dans la simulation.

### Task 1 : simulation, déplacement et endurance

**Files :** Create `proto/fosse/pit-sim.js`, `tools/test_pit_sim.js`

**Interfaces :**
- Produces : `PitSim.DEFAULTS` ; `PitSim.create({ seed:int, runS:number, cfg?:object, ghosts?:Ghost[], friends?:{id,name}[], bpm?:number|null }) -> Sim` ;
  `PitSim.step(sim, input) -> Event[]` (avance de 1/120 s ; `Event = { t:ms, type:string, id?:string }`) ;
  `PitSim.advance(sim, input, dtMs) -> Event[]` (fait autant de pas que `dtMs` en contient, `dtMs` plafonné à 250) ;
  `sim.me = { a, r, v, stamina, zone:'middle'|'track'|'edge', down:bool }`, `sim.t` (ms), `sim.over` (bool, vrai à `runS`).

- [ ] **Step 1 : tests qui échouent** dans `tools/test_pit_sim.js` (petit `check(nom, cond)` comme `test_proto.js`, code de sortie 1 si un échec) :
  - `déplacement : plein gaz 5 s → v proche de vmax` : `Math.abs(sim.me.v - 1.2) < 0.05`.
  - `déplacement : lâcher → v décroît` : après 5 s plein gaz puis 2 s à `throttle:0`, `v < 0.6`.
  - `endurance : plein gaz 8 s la vide sous 0.2, le bord la remonte` : stamina < 0.2 puis, `lateral:1` jusqu'à `zone==='edge'` et 4 s à `throttle:0`, stamina > 0.8.
  - `zones : lateral -1 mène au milieu` : `zone==='middle'` après 2 s.
  - `fin : sim.over à runS` : `runS:1` → `over` vrai après 120 pas, faux après 119.
  - `arrière-plan : advance(…, 60000) ne fait que 30 pas` : `sim.t === 250`.
  - `déterminisme : deux sims de même graine, même suite d'entrées → JSON identique de sim.me`.
- [ ] **Step 2 :** `node tools/test_pit_sim.js` → échecs (module absent).
- [ ] **Step 3 : implémenter** `create`, `step`, `advance`. Vitesse : `v += (throttle*vmax - v) * min(1, accel*dt)` ; `a += v*dt` ; `r += lateral*lateral_cfg*dt` (borné) ; endurance : `- drain*(v/vmax)^2*(middle ? 1.5 : 1)*dt`, `+ regen*dt` au bord, `+ regenSlow*dt` si `v < 0.2*vmax`, bornée [0, 1]. Export UMD : `if(typeof module!=='undefined') module.exports = PitSim; else window.PitSim = PitSim;`
- [ ] **Step 4 :** `node tools/test_pit_sim.js` → tous OK.
- [ ] **Step 5 : commit** `Circle pit : simulation (déplacement, endurance, zones), testée sous Node`.

### Task 2 : foule, chutes, relevés, potes attirés

**Files :** Modify `proto/fosse/pit-sim.js`, `tools/test_pit_sim.js`

**Interfaces :**
- Consumes : Task 1.
- Produces : `sim.npcs = [{ a, r, v, down:bool, downT:ms }]` ; `sim.friends = [{ id, name, a, pulled:bool }]` (placés au bord, `r = 0.97`, angles répartis par la graine) ;
  événements `type` : `'bump'`, `'fall'`, `'up'`, `'lift'` (avec `id` = index de npc), `'pull'` (avec `id` = id du pote), `'lap'`, `'beat'`.
  `PitSim.forceNpcDown(sim, i)` et `PitSim.place(sim, i, a, r)` (aides de test, exportées).

- [ ] **Step 1 : tests qui échouent :**
  - `chute : choc plein gaz endurance vide → fall dans les 3 s` avec un npc placé juste devant (`place`) et graine fixée (choisir une graine qui tombe, la noter dans le test).
  - `relève seul : upTaps touchers → up avant downS`, et sans toucher → `up` à `downS` (1,5 s).
  - `fantôme qui passe relève` : un fantôme dont la trace passe sur moi pendant que je suis à terre → événement `up` immédiat.
  - `relever un npc : ralentir dessus 0.4 s → lift`, et le npc n'est plus `down`.
  - `pas de relevé en passant vite` : à `vmax`, aucun `lift`.
  - `attirer un pote : au bord, à moins de pullAngle, 0.5 s → pull` une seule fois par pote.
  - `tour : un tour complet → lap`.
  - `milieu plus risqué` : sur 200 graines, taux de `fall` au milieu > taux sur la piste (mêmes entrées).
- [ ] **Step 2 :** lancer, échecs attendus.
- [ ] **Step 3 : implémenter.** Collisions disque contre disque (`body`) en coordonnées cartésiennes, repoussement symétrique ; `fall` si vitesse relative > `0.5*vmax` et tirage < `(fallBase + (1-stamina)*fallTired) * (middle ? middleRisk : 1)`. À terre : `v = 0`, entrées ignorées sauf `tap`. Npcs : vitesses tirées entre 0.4 et 0.9 tour/s, tombent au hasard (`npcFallPerS`, ×`middleRisk` au milieu), se relèvent seuls à `npcDownS`. Fantômes : voir Task 3 (`ghostAt`).
- [ ] **Step 4 :** tous OK.
- [ ] **Step 5 : commit** `Circle pit : foule, chutes, relevés et potes attirés dans la simulation`.

### Task 3 : score, cercle, trace et fantômes

**Files :** Modify `proto/fosse/pit-sim.js`, `tools/test_pit_sim.js`

**Interfaces :**
- Consumes : Tasks 1 et 2.
- Produces : `PitSim.result(sim) -> { score:int 0..100, circle:int, trace:Trace, stats:{ laps, lifts, pulls, middleS, rhythm:0..1 } }` ;
  `Trace = { v:1, hz:10, p:[[aMillièmes:int, rCentièmes:int, down:0|1], …], e:[[tMs, type], …] }` ;
  `PitSim.ghostAt(trace, tMs) -> { a, r, down } | null` (interpolé ; `null` si trace invalide ou `v !== 1`) ;
  `Ghost = { id, name, avatar, trace }`.

- [ ] **Step 1 : tests qui échouent :**
  - `score : formule` : `stats = { laps:5, lifts:2, pulls:1, middleS:6, rhythm:.5 }` → `min(100, round(5*4 + 2*6 + 1*8 + 6*1 + .5*30))` = 61.
  - `score : plafonné à 100`.
  - `rythme sans tempo` (`bpm:null`) : `rhythm` = part du temps à `v ≥ groove*vmax` hors chute.
  - `rythme avec tempo` (`bpm:120`) : `rhythm` = part des battements (`beat`, toutes les 500 ms) tombés pendant que `v ≥ groove*vmax` et pas à terre.
  - `cercle` : `laps*1 + lifts*2 + pulls*3`.
  - `trace : 40 s de course < 20 000 caractères` (`JSON.stringify(result.trace).length`).
  - `fantôme : ghostAt rejoue la trace` à ±0.01 tour et ±0.02 de rayon d'une course enregistrée.
  - `fantôme : trace invalide` (`null`, `{}`, `{v:2}`, `p` non tableau) → `ghostAt` renvoie `null` et `create` ignore ce fantôme.
  - `sans fantôme ni pote, 100 atteignable` : une suite d'entrées scriptée (plein gaz, relevés, milieu) atteint 100 avec la graine du test.
- [ ] **Step 2 :** échecs attendus.
- [ ] **Step 3 : implémenter** `result`, l'enregistrement de la trace (un point tous les 12 pas) et `ghostAt`.
- [ ] **Step 4 :** tous OK.
- [ ] **Step 5 : commit** `Circle pit : score, cercle commun, trace et fantômes`.

### Task 4 : détection du tempo

**Files :** Create `proto/fosse/pit-beat.js` ; Modify `tools/test_pit_sim.js`

**Interfaces :**
- Produces : `PitBeat.detect(samples:Float32Array, sampleRate:number) -> number|null` (BPM arrondi entre 70 et 200, `null` si aucun pic net).

- [ ] **Step 1 : tests qui échouent :** clics synthétiques à 120 BPM (10 s, 22 050 Hz) → entre 118 et 122 ; à 90 → entre 88 et 92 ; bruit blanc seedé → `null` ; silence → `null`.
- [ ] **Step 2 :** échecs attendus.
- [ ] **Step 3 : implémenter.** Enveloppe d'énergie par fenêtres de 1024 échantillons (pas 512), flux positif, autocorrélation sur les retards de 70 à 200 BPM ; `null` si le pic est < 1,5 fois la médiane. Aucune dépendance.
- [ ] **Step 4 :** tous OK.
- [ ] **Step 5 : commit** `Circle pit : détection du tempo de l'extrait`.

### Task 5 : migration 0076

**Files :** Create `backend/supabase/migrations/0076_pit_engine.sql` ; Modify `proto/index.html:2146`

**Prérequis :** jeton `supabase-token` valide (refusé le 2026-11-14) : le propriétaire lance `! zsh tools/store_secret.sh supabase-token` dans un vrai Terminal.

**Interfaces :**
- Produces (SQL) : `pit_runners.trace jsonb`, `pits.circle int not null default 0` ;
  `pit_run_finish(p_pit uuid, p_score int, p_trace jsonb default null, p_circle int default 0) returns jsonb` (l'ancienne signature à 2 arguments est supprimée ; mêmes droits) ;
  `pit_state` renvoie en plus `circle`, `game` (`settings.pit.game`, `{}` si absent) et `trace` pour chaque coureur qui a couru.
- Produces (client) : `ONLINE.pitRunFinish(id, score, trace, circle)`.

- [ ] **Step 1 :** écrire la migration : colonnes ; `settings.pit` ← `run_s` 40 et `game` = `PitSim.DEFAULTS` en JSON ; `pit_run_finish` refuse une trace de plus de 20 000 octets (`octet_length(p_trace::text)`, message « Course trop lourde. ») et borne `p_circle` entre 0 et 200 avant `update pits set circle = circle + …` ; contrôles de durée existants inchangés.
- [ ] **Step 2 :** appliquer : `zsh tools/supa_sql.sh backend/supabase/migrations/0076_pit_engine.sql` → pas d'erreur.
- [ ] **Step 3 : vérifier** par un fichier SQL dans le dossier temporaire : `select value->'run_s', value->'game'->'vmax' from settings where key='pit'` → `40`, `1.2` ; `select pg_get_function_identity_arguments(oid) from pg_proc where proname='pit_run_finish'` → une seule ligne à 4 arguments.
- [ ] **Step 4 :** `ONLINE.pitRunFinish(id, score, trace, circle)` envoie `p_trace` et `p_circle`. `node tools/test_proto.js` → tous OK.
- [ ] **Step 5 : commit** `Circle pit : trace des courses, cercle commun, courses de 40 s (migration 0076)`.

### Task 6 : affichage PixiJS et commandes

**Files :** Create `proto/fosse/pit-view.js`

**Interfaces :**
- Consumes : `PitSim` (Tasks 1 à 3), `PIXI` 8.6.6.
- Produces : `PitGame.start(host:HTMLElement, opts) -> { stop() }` avec
  `opts = { PIXI, seed, runS, cfg, me:{ name, avatar }, ghosts:Ghost[], friends:{ id, name, avatar }[], bpm:number|null,
            reduce:bool, buzz(pattern), snd(name, vol), onPull(friendId), onEnd({ score, circle, trace, stats }) }` ;
  `PitGame.inputFrom(anchor:{x,y}, point:{x,y}) -> { throttle, lateral }` (pur, exporté pour les tests) : `throttle = clamp((anchor.y - point.y)/90, 0, 1)`, `lateral = clamp((point.x - anchor.x)/90, -1, 1)`.

- [ ] **Step 1 : test qui échoue** (`tools/test_pit_sim.js`, en chargeant `pit-view.js` dans un `vm` avec `window = {}`) : `inputFrom` ; `pouce levé puis reposé ailleurs` : la fonction d'ancrage (`PitGame.anchorOn(state, pointerdown)`) recale l'ancre sur le nouveau point et l'entrée suivante vaut `{ throttle:0, lateral:0 }`.
- [ ] **Step 2 :** échec attendu.
- [ ] **Step 3 : implémenter.**
  - Application `new PIXI.Application()` puis `await app.init({ resizeTo: host, backgroundAlpha: 0, antialias: true, resolution: min(devicePixelRatio, 2), autoDensity: true })`.
  - Boucle : `app.ticker` → `PitSim.advance(sim, input, ticker.deltaMS)` → événements → retours (buzz, snd, secousse) → dessin. Rien n'est lu dans le DOM pendant la course (rectangle de l'hôte mis en cache, recalculé sur `resize`).
  - Commandes : `pointerdown` sur tout l'hôte fixe l'ancre ; `pointermove` lit `e.getCoalescedEvents()` (sinon l'événement seul) et garde le dernier point ; `pointerup` = `throttle 0` ; un toucher bref (< 200 ms) pendant une chute = `tap`.
  - Monde : vue de dessus, conteneur caméra centré sur moi, tourné de `-a` pour que je coure vers le haut ; zoom de 1 à 0,85 avec la vitesse.
  - Corps : une texture de silhouette (tête et épaules) générée une fois (`app.renderer.generateTexture`), sprites teintés (foule os, moi or, fantômes or pâle avec avatar circulaire si `avatar`, sinon initiale) ; npcs à terre allongés ; potes au bord avec leur nom.
  - Effets : `ParticleContainer` de 200 particules réutilisées (poussière) ; traînées sur la piste proportionnelles à la vitesse ; secousse de 120 ms à `bump` et `fall` ; pas de secousse ni de traînées si `reduce`.
  - HUD en DOM au-dessus du canevas, réécrit au plus toutes les 100 ms : chrono `0:40`, jauge d'endurance, score courant, aide en une ligne au premier lancement (« Pouce vers le haut : fonce. Sur les côtés : bord ou milieu. »).
  - `stop()` détruit l'application (`app.destroy(true, { children: true, texture: true })`) et retire les écouteurs.
- [ ] **Step 4 :** test OK ; puis vérification visuelle : `python3 -m http.server 8765` et une page de banc `proto/?pitbanc` (Task 7) capturée à 390 × 664 : anneau, foule, moi au centre bas, HUD lisible, rien sous la barre d'onglets.
- [ ] **Step 5 : commit** `Circle pit : affichage PixiJS, pouce qui dirige, caméra et HUD`.

### Task 7 : branchement dans le prototype

**Files :** Modify `proto/index.html` (`pitRunGo`, `pitRunEnd`, `pitStop`, scripts en tête, `TRACK_BPM`) ; Modify `tools/test_proto.js`

**Interfaces :**
- Consumes : `PitGame.start` (Task 6), `PitBeat.detect` (Task 4), `ONLINE.pitRunFinish` à 4 arguments (Task 5), `ONLINE.fosseCall`.
- Produces : `pitRunLegacy(st)` (l'actuel corps de `pitRunGo` après `pitRunStart`, inchangé) ; `var PIXI_LIB = 'https://cdn.jsdelivr.net/npm/pixi.js@8.6.6/dist/pixi.min.js'` ; `var TRACK_BPM = {}` (tempo saisi à la main par identifiant de morceau) ; banc `?pitbanc` (course hors ligne avec 3 fantômes et 2 potes factices, pour les captures).

- [ ] **Step 1 : tests qui échouent** dans la section 18 bis de `tools/test_proto.js` :
  - `circle pit : nouveau jeu lancé avec fantômes et potes` : `window.PIXI = {}` et un `window.PitGame` factice qui enregistre `opts` ; après « Démarrer », `opts.runS === st.run_s`, `opts.ghosts` = coureurs du pit qui ont une trace, `opts.friends` = potes de l'app hors coureurs (6 au plus).
  - `circle pit : fin du nouveau jeu` : `opts.onEnd({ score:72, circle:5, trace:{v:1,hz:10,p:[],e:[]}, stats:{} })` → `pitRunFinish` reçoit `(id, 72, trace, 5)`, toast « Ta course : 72 ».
  - `circle pit : pote attiré` : `opts.onPull('f1')` → `fosseCall('pit', 'p1', 'f1')`.
  - `circle pit : repli sans PixiJS` : `PitGame` absent → la course actuelle démarre (`#pit-count` à « 3 », `#pit-mark` présent) ; les tests existants restent verts.
  - `circle pit : ancien serveur` : `pitRunFinish` factice qui rejette quand `trace` est fourni → second appel avec le score seul, course comptée.
- [ ] **Step 2 :** `node tools/test_proto.js` → échecs attendus.
- [ ] **Step 3 : implémenter.**
  - `<script src="fosse/pit-sim.js"></script>`, `pit-beat.js`, `pit-view.js` après `sounds/manifest.js`.
  - `pitRunGo` : après `ONLINE.pitRunStart`, `loadLib(PIXI_LIB, 'PIXI')` puis `PitGame.start(pitIn, …)` ; tout échec (chargement, `app.init`) → `pitRunLegacy(st)`. Graine : somme des codes de caractères de `st.id + monId`. `body.playing` et l'extrait (`pitTrack`) comme aujourd'hui.
  - Tempo : `TRACK_BPM[st.track]` sinon tentative `fetch(url) → decodeAudioData → PitBeat.detect` sur le canal 0, en parallèle du décompte de 3 s ; pas de résultat à temps → `bpm: null`.
  - `onEnd` → `pitRunEnd(result)` : `ONLINE.pitRunFinish(id, score, trace, circle)`, puis en cas d'erreur, un second essai `ONLINE.pitRunFinish(id, score)` ; toast « Ta course : <b>score</b> », plus « +N au cercle » si `circle > 0`.
  - Salle d'attente : la taille du cercle (`st.circle`) agrandit l'anneau dessiné (`--pit-grow`, de 1 à 1,25).
- [ ] **Step 4 :** `node tools/test_proto.js` → tous OK, aucune erreur JS.
- [ ] **Step 5 : commit** `Circle pit : nouveau jeu branché (fantômes, potes attirés, tempo), ancienne course en repli`.

### Task 8 : sons, finitions, vérification sur téléphone

**Files :** Modify `tools/sound_cues.json` (puis `python3 tools/build_sons.py`), `proto/fosse/pit-view.js`, `CLAUDE.md`

- [ ] **Step 1 :** ajouter les sons `pit-pas`, `pit-souffle`, `pit-foule`, `pit-chute`, `pit-releve` (P1) dans `tools/sound_cues.json` ; `python3 tools/build_sons.py` ; un son non fourni reste muet (comportement actuel de `snd`).
- [ ] **Step 2 :** captures à 390 × 664 et 430 × 932 du banc `?pitbanc` (début, chute, repos au bord, milieu, fin) avec user-agent Safari iOS ; mouvement réduit activé : pas de secousse.
- [ ] **Step 3 :** `node tools/test_proto.js` et `node tools/test_pit_sim.js` → tous OK.
- [ ] **Step 4 :** ligne datée dans `CLAUDE.md` (Où en est le projet) : moteur, réglages `settings.pit.game`, migration 0076, banc `?pitbanc`, « à régler sur iPhone : latence, difficulté, lisibilité ».
- [ ] **Step 5 : commit** `Circle pit : sons, finitions et notes`. Pas de push : le propriétaire teste d'abord le banc puis donne son accord.
