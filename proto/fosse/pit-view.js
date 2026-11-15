// Metalnini — affichage du circle pit (PixiJS 8) : vue drone, de dos et en hauteur, comme les vidéos de concert.
// Corps articulés (fosse/pit-bodies.js), photos de profil (fosse/pit-photo.js), projecteurs (fosse/pit-light.js),
// projection de l'anneau (fosse/pit-proj.js). Pouce qui dirige : vers le haut = foncer, à droite = le bord, à gauche = le milieu.
// La simulation (PitSim) avance à pas fixe ; ici on ne fait que lire le doigt, dessiner et rendre les retours.
(function(){
  var GOLD = 0xeb9a26, GOLD_HI = 0xf4b243, BONE = 0xd9cdb8, BLOOD = 0xb23a3a, LINE = 0x2e251d;
  var CROWD_LOOKS = 10, MAX_GHOSTS = 8, FANS = 60;
  function clamp(x, lo, hi){ return x < lo ? lo : x > hi ? hi : x; }

  // pouce : vers le haut = vitesse (90 px pour le maximum) ; sur le côté = voie, avec 25 px de marge pour ne pas dévier en courant
  function inputFrom(anchor, point){
    if(!anchor || !point) return { throttle: 0, lateral: 0 };
    var dx = point.x - anchor.x;
    return { throttle: clamp((anchor.y - point.y) / 90, 0, 1), lateral: Math.abs(dx) <= 25 ? 0 : clamp((dx - (dx > 0 ? 25 : -25)) / 65, -1, 1) };
  }
  // pouce posé (ou reposé ailleurs) : l'ancre se recale, pas de saut de vitesse
  function anchorOn(st, pt){ st.anchor = { x: pt.x, y: pt.y }; st.point = { x: pt.x, y: pt.y }; st.down = true; return st; }

  var CSS = '.pg{position:absolute;inset:0;touch-action:none;user-select:none;-webkit-user-select:none;overflow:hidden;background:#0d0a08}' +
    '.pg canvas{position:absolute;inset:0;width:100%;height:100%}' +
    '.pg-hud{position:absolute;left:16px;right:16px;top:calc(12px + env(safe-area-inset-top));display:flex;align-items:center;gap:12px;pointer-events:none;color:#f3f0ea;font:600 .8rem/1 "Barlow",system-ui,sans-serif}' +
    '.pg-hud b{font:800 1.6rem/1 "Big Shoulders Display","Arial Narrow",sans-serif;font-variant-numeric:tabular-nums}' +
    '.pg-st{flex:1;height:8px;border:1px solid #2e251d;border-radius:4px;background:#15110f;overflow:hidden}.pg-st i{display:block;height:100%;background:#eb9a26;transform-origin:left;transition:background .2s}' +
    '.pg-st.low i{background:#b23a3a}' +
    '.pg-cue{position:absolute;left:16px;right:16px;bottom:calc(24px + env(safe-area-inset-bottom));text-align:center;pointer-events:none;color:#f3f0ea;font:600 .95rem/1.35 "Barlow",system-ui,sans-serif;text-shadow:0 1px 3px #000}' +
    '.pg-cue.hot{color:#f4b243;font:800 1.5rem/1 "Big Shoulders Display","Arial Narrow",sans-serif;letter-spacing:.02em}';
  function addCss(){ if(document.getElementById('pg-css')) return; var s = document.createElement('style'); s.id = 'pg-css'; s.textContent = CSS; document.head.appendChild(s); }
  function dotTex(PIXI, app){ var g = new PIXI.Graphics(); g.circle(0, 0, 6).fill(0xffffff); var t = app.renderer.generateTexture(g); g.destroy(); return t; }

  function start(host, o){
    var PIXI = o.PIXI, PitSim = window.PitSim, stopped = false, app = null, wrap, hud, cue, clock, stBar, scoreEl, st = { down: false },
        tapPending = false, sim, onDown, onMove, onUp;
    addCss();
    wrap = document.createElement('div'); wrap.className = 'pg';
    wrap.innerHTML = '<div class="pg-hud"><b class="pg-clock">0:' + String(o.runS).padStart(2, '0') + '</b><div class="pg-st"><i></i></div><b class="pg-score">0</b></div>' +
      '<p class="pg-cue">Pouce vers le haut : fonce. À droite : le bord pour souffler. À gauche : le milieu, pour les braves.</p>';
    host.appendChild(wrap);
    hud = wrap.querySelector('.pg-hud'); clock = hud.querySelector('.pg-clock'); stBar = hud.querySelector('.pg-st'); scoreEl = hud.querySelector('.pg-score'); cue = wrap.querySelector('.pg-cue');
    sim = PitSim.create({ seed: o.seed, runS: o.runS, cfg: o.cfg, ghosts: (o.ghosts || []).slice(0, MAX_GHOSTS), friends: o.friends, bpm: o.bpm });

    // commandes : on lit tous les points du doigt (getCoalescedEvents), on ne relit jamais le DOM pendant la course
    onDown = function(e){ e.preventDefault(); try{ wrap.setPointerCapture(e.pointerId); }catch(_){}
      anchorOn(st, { x: e.clientX, y: e.clientY }); st.id = e.pointerId; if(sim.me.down) tapPending = true; };
    onMove = function(e){ if(!st.down || e.pointerId !== st.id) return; var l = e.getCoalescedEvents ? e.getCoalescedEvents() : null, p = l && l.length ? l[l.length - 1] : e;
      st.point = { x: p.clientX, y: p.clientY }; };
    onUp = function(e){ if(e.pointerId === st.id) st.down = false; };
    wrap.addEventListener('pointerdown', onDown); wrap.addEventListener('pointermove', onMove);
    wrap.addEventListener('pointerup', onUp); wrap.addEventListener('pointercancel', onUp);

    // fin de course, une seule fois : score acquis rendu à l'appli
    var ended = false;
    function finish(){ if(ended) return; ended = true; var res = PitSim.result(sim); stop(); if(o.onEnd) o.onEnd(res); }
    function stop(){ if(stopped) return; stopped = true;
      wrap.removeEventListener('pointerdown', onDown); wrap.removeEventListener('pointermove', onMove);
      wrap.removeEventListener('pointerup', onUp); wrap.removeEventListener('pointercancel', onUp);
      if(app){ try{ app.destroy(true, { children: true, texture: true }); }catch(_){} app = null; }
      wrap.remove(); }

    var ready = Promise.resolve().then(function(){ app = new PIXI.Application();
      return app.init({ resizeTo: wrap, backgroundAlpha: 0, antialias: true, resolution: Math.min(window.devicePixelRatio || 1, 2), autoDensity: true }); })
      .then(function(){ if(stopped) return; wrap.insertBefore(app.canvas, hud); build(); });

    function build(){
      var c = sim.cfg, Proj = window.PitProj, Bodies = window.PitBodies, Photo = window.PitPhoto, Light = window.PitLight, style = o.photoStyle || 'palette', i;
      var dot = dotTex(PIXI, app), light = Light.layer(PIXI, app);
      var floor = new PIXI.Graphics(), shadows = new PIXI.Container(), bodies = new PIXI.Container(), dust = new PIXI.Container(), badges = new PIXI.Container();
      bodies.sortableChildren = true;
      var upRing = new PIXI.Graphics();   // à terre : anneau doré qui se remplit jusqu'à la relève
      app.stage.addChild(floor, shadows, dust, bodies, light.container, badges, upRing);

      // allures : foule (10 allures cuites, partagées), moi, fantômes et potes (une chacun)
      var crowdLooks = Bodies.looks(o.seed ^ 0x5eed, CROWD_LOOKS), crowdBaked = crowdLooks.map(function(l){ return Bodies.bake(PIXI, app, l); });
      var fanBaked = crowdLooks.slice(0, 4).map(function(l){ return Bodies.bake(PIXI, app, l, { front: true }); });
      var ownLooks = Bodies.looks(o.seed ^ 0xface, 2 + sim.ghosts.length + sim.friends.length);
      // un coureur affiché : son sprite, son ombre, sa phase de course ; pastille photo pour moi, les fantômes et les potes entrés
      function runner(baked, badgeTex, badgeSize){
        var s = new PIXI.Sprite(baked.run[0]); s.anchor.set(0.5, 1); bodies.addChild(s);
        var sh = new PIXI.Sprite(light.glow); sh.anchor.set(0.5); sh.tint = 0x000000; shadows.addChild(sh);
        var b = null; if(badgeTex){ b = new PIXI.Sprite(badgeTex); b.anchor.set(0.5, 1); badges.addChild(b); }
        return { s: s, sh: sh, b: b, baked: baked, phase: Math.random(), bs: badgeSize || 30 };
      }
      function initialTex(name){ return PIXI.Texture.from(Photo.initial(name, 96)); }
      function withPhoto(url, r){ Photo.load(url, style, 96).then(function(cv){ if(cv && !stopped && r.b) r.b.texture = PIXI.Texture.from(cv); }); }
      var meR = runner(Bodies.bake(PIXI, app, ownLooks[0]), initialTex((o.me && o.me.name) || 'Moi'), 36); withPhoto(o.me && o.me.avatar, meR);
      var npcR = sim.npcs.map(function(p, k){ return runner(crowdBaked[k % CROWD_LOOKS]); });
      var ghostR = sim.ghosts.map(function(g, k){ var r = runner(Bodies.bake(PIXI, app, ownLooks[1 + k]), initialTex(g.name)); r.s.alpha = 0.85; withPhoto(g.avatar, r); return r; });
      // potes au bord : vus de face, leur photo en visage ; une fois attirés, ils courent avec une pastille
      var friendR = sim.friends.map(function(f, k){ var src = o.friends[k] || {}, look = ownLooks[1 + sim.ghosts.length + k];
        var r = runner(Bodies.bake(PIXI, app, look, { front: true }), initialTex(f.name)); r.back = Bodies.bake(PIXI, app, look); r.front = r.baked;
        Photo.load(src.avatar, style, 96).then(function(cv){ if(!cv || stopped) return; var t = PIXI.Texture.from(cv);
          r.front = Bodies.bake(PIXI, app, look, { front: true, face: t }); if(r.b) r.b.texture = t; });
        return r; });
      var fans = []; for(i = 0; i < FANS; i++){ var fb = fanBaked[i % fanBaked.length], fs = new PIXI.Sprite(fb.cheer[i % 2]); fs.anchor.set(0.5, 1); bodies.addChild(fs);
        fans.push({ s: fs, baked: fb, a: i / FANS + (i % 3) * 0.004, r: 1.05 + (i % 3) * 0.035 }); }
      var pool = []; for(i = 0; i < 90; i++){ var d = new PIXI.Sprite(dot); d.anchor.set(.5); d.tint = 0x8a7d6a; d.visible = false; dust.addChild(d); pool.push(d); }
      var dustI = 0, dustT = 0, shakeT = 0, shakeA = 0, beatAt = null, flashAt = null, hudT = 0, fallen = false, flashT = 0;

      function flash(txt){ cue.textContent = txt; cue.classList.add('hot'); flashT = 1100; }
      function feedback(ev){
        ev.forEach(function(e){
          if(e.type === 'bump'){ if(!o.reduce){ shakeT = 120; shakeA = 4; } if(o.buzz) o.buzz([12]); if(o.snd) o.snd('pit-bouscule', .5); }
          else if(e.type === 'fall'){ if(!o.reduce){ shakeT = 220; shakeA = 9; } flashAt = sim.t; if(o.buzz) o.buzz([40, 30, 60]); if(o.snd) o.snd('pit-chute', .8); }
          else if(e.type === 'up'){ if(o.snd) o.snd('pit-releve', .6); }
          else if(e.type === 'lift'){ if(o.buzz) o.buzz([20, 40, 20]); if(o.snd) o.snd('pit-releve', .7); flash('Relevé !'); }
          else if(e.type === 'pull'){ var fr = sim.friends.filter(function(x){ return x.id === e.id; })[0]; if(o.onPull) o.onPull(e.id); if(o.buzz) o.buzz([20, 30, 40]);
            flashAt = sim.t; if(o.snd) o.snd('pit-foule', .8); flash((fr && fr.name ? fr.name : 'Ton pote') + ' entre !'); }
          else if(e.type === 'lap'){ if(o.buzz) o.buzz([10]); if(sim.end * 1000 / PitSim.HZ - sim.t < 8000) flashAt = sim.t; }
          else if(e.type === 'beat'){ beatAt = sim.t; }
        });
      }

      // sol : l'anneau projeté (milieu rouge, bord or, repères qui défilent quand on court)
      function ringPath(cam, r, n){ var pts = [], k, p, a0 = sim.me.a; for(k = 0; k <= n; k++){ p = Proj.project(cam, a0 - 0.06 + k / n, r); if(p.visible) pts.push(p); } return pts; }
      function drawFloor(cam, w, h){
        floor.clear(); floor.rect(0, 0, w, h).fill(0x0d0a08);
        var edge = ringPath(cam, 1.0, 64), mid = ringPath(cam, 0.45, 64), inner = ringPath(cam, 0.9, 64);
        if(edge.length > 2){ floor.poly([].concat.apply([], edge.map(function(p){ return [p.x, p.y]; })).concat([w, h, 0, h])).fill(0x15110f); }
        var xy = function(pts){ return [].concat.apply([], pts.map(function(p){ return [p.x, p.y]; })); };
        // voies : piste légèrement éclairée, bord teinté d'or, milieu de rouge
        if(inner.length > 2 && mid.length > 2) floor.poly(xy(inner).concat(xy(mid.slice().reverse()))).fill({ color: BONE, alpha: .05 });
        if(edge.length > 2 && inner.length > 2) floor.poly(xy(edge).concat(xy(inner.slice().reverse()))).fill({ color: GOLD, alpha: .09 });
        if(mid.length > 2){ floor.poly(xy(mid)).fill({ color: BLOOD, alpha: .14 }); }
        [[inner, GOLD, .55, 3], [mid, BLOOD, .5, 2]].forEach(function(l){ var pts = l[0]; if(pts.length < 2) return;
          floor.moveTo(pts[0].x, pts[0].y); for(var k = 1; k < pts.length; k++) floor.lineTo(pts[k].x, pts[k].y); floor.stroke({ width: l[3], color: l[1], alpha: l[2] }); });
        // repères au sol tous les 1/48 de tour : ils défilent sous les pieds, d'où la vitesse
        for(var k = 0; k < 48; k++){ var a = Math.floor(sim.me.a * 48) / 48 + k / 48 - 0.06, p1 = Proj.project(cam, a, 0.9), p2 = Proj.project(cam, a, 1.0);
          if(p1.visible && p2.visible) floor.moveTo(p1.x, p1.y).lineTo(p2.x, p2.y); }
        floor.stroke({ width: 1, color: LINE, alpha: .9 });
      }
      function show(r, a, rr, cam, kind, frameI, baseH, zBoost){
        var p = Proj.project(cam, a, rr), h = app.screen.height;
        if(!p.visible || p.y < h * 0.12 || p.y > h * 1.15){ r.s.visible = r.sh.visible = false; if(r.b) r.b.visible = false; return p; }
        var tex = r.baked[kind][frameI % r.baked[kind].length], sc = p.scale * baseH / 80;
        r.s.visible = r.sh.visible = true; r.s.texture = tex; r.s.position.set(p.x, p.y); r.s.scale.set(sc); r.s.zIndex = Math.round(p.y) + (zBoost || 0);
        r.sh.position.set(p.x, p.y); r.sh.width = 70 * sc; r.sh.height = 18 * sc; r.sh.alpha = .5;
        if(r.b){ r.b.visible = true; var bh = r.bs * p.scale * (baseH / 120); r.b.width = r.b.height = Math.max(14, bh);
          r.b.position.set(p.x, p.y - r.s.height - 4 * p.scale); }
        return p;
      }
      function step(r, v, dt){ r.phase = (r.phase + v * dt / 1000 * 2.2) % 1; return Math.floor(r.phase * 8); }

      app.ticker.add(function(tk){
        if(stopped) return;
        try{ frame(tk); }catch(err){ finish(); }   // jamais de jeu figé : on termine la course avec ce qui est acquis
      });
      function frame(tk){
        var dt = tk.deltaMS, inp = st.down ? inputFrom(st.anchor, st.point) : { throttle: 0, lateral: 0 }, ev = [];
        inp.tap = false;
        if(tapPending){ tapPending = false; ev = ev.concat(PitSim.step(sim, { throttle: 0, lateral: 0, tap: true })); dt = Math.max(0, dt - 1000 / PitSim.HZ); }
        ev = ev.concat(PitSim.advance(sim, inp, dt));
        feedback(ev);
        var m = sim.me, t = sim.t, w = app.screen.width, h = app.screen.height, cam = Proj.camera(m, w, h), baseH = h * 0.2, k;
        drawFloor(cam, w, h);
        // drone : légère dérive et léger roulis, secousse aux chocs (sauf mouvement réduit)
        var sx = 0, sy = 0; if(shakeT > 0){ shakeT -= dt; sx = (Math.random() - .5) * shakeA * 2; sy = (Math.random() - .5) * shakeA * 2; }
        app.stage.position.set(sx + (o.reduce ? 0 : Math.sin(t / 1700) * 4), sy + (o.reduce ? 0 : Math.sin(t / 2300) * 3));
        app.stage.rotation = o.reduce ? 0 : Math.sin(t / 2900) * 0.008;
        var meKind = m.down ? 'down' : sim.npcs.some(function(p){ return p.down && p.hold > 0; }) ? 'lift' : m.v < 0.05 * c.vmax ? 'up' : 'run';
        var meP = show(meR, m.a, m.r, cam, meKind, meKind === 'run' ? step(meR, m.v, dt) : meKind === 'up' ? 1 : Math.floor(t / 250), baseH, 1);
        sim.npcs.forEach(function(p, k2){ show(npcR[k2], p.a, p.r, cam, p.down ? 'down' : 'run', step(npcR[k2], p.down ? 0 : p.v, dt), baseH); });
        sim.ghosts.forEach(function(g, k2){ var q = PitSim.ghostAt(g.trace, t); if(q) show(ghostR[k2], q.a, q.r, cam, q.down ? 'down' : 'run', step(ghostR[k2], 0.9, dt), baseH); });
        sim.friends.forEach(function(f, k2){ var r = friendR[k2];
          if(f.pulled){ r.baked = r.back; show(r, f.a + (t / 1000) * .7, .8, cam, 'run', step(r, 0.7, dt), baseH); }
          else { r.baked = r.front; var near = Math.abs(((m.a - f.a) % 1 + 1.5) % 1 - .5) < .08; if(r.b) r.b.visible = false;
            var keepB = r.b; r.b = null; show(r, f.a, f.r, cam, near ? 'cheer' : 'up', near ? Math.floor(t / 300) : 1, baseH); r.b = keepB; } });
        var pulse = beatAt == null ? 1 : 1 + .1 * Math.exp(-(t - beatAt) / 140);
        for(k = 0; k < fans.length; k++){ var fn = fans[k], fp = Proj.project(cam, fn.a, fn.r);   // spectateurs fixes autour du pit : ils défilent quand on court
          fn.s.visible = fp.visible && fp.y > h * 0.12; if(!fn.s.visible) continue;
          fn.s.texture = fn.baked.cheer[(Math.floor(t / 320) + k) % 2]; fn.s.position.set(fp.x, fp.y); fn.s.scale.set(fp.scale * baseH / 80 * (k % 2 ? pulse : 1)); fn.s.zIndex = Math.round(fp.y); }
        // poussière aux pieds quand le pit est lancé
        dustT += dt; if(m.v >= c.groove * c.vmax && dustT > 40 && meP.visible){ dustT = 0; var dd = pool[dustI++ % pool.length]; dd.visible = true;
          dd.position.set(meP.x + (Math.random() - .5) * 30 * meP.scale, meP.y - 4); dd._life = 0; }
        for(k = 0; k < pool.length; k++){ var d2 = pool[k]; if(!d2.visible) continue; d2._life += dt; d2.y += dt * 0.05; d2.alpha = .5 * (1 - d2._life / 600); d2.scale.set(.5 + d2._life / 240); if(d2._life > 600) d2.visible = false; }
        upRing.clear();
        if(m.down && meP.visible){ var ur = 46 * meP.scale, uy = meP.y - 30 * meP.scale;
          upRing.circle(meP.x, uy, ur).stroke({ width: 5, color: 0x15110f, alpha: .8 });
          upRing.arc(meP.x, uy, ur, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(.02, m.upProgress)).stroke({ width: 5, color: GOLD_HI, cap: 'round' }); }
        light.draw(Light.beams(t, { beatT: beatAt == null ? null : t - beatAt, flashT: flashAt == null ? null : t - flashAt, reduce: !!o.reduce }), w, h, meP.visible ? meP : null);
        // texte : chrono réécrit à la seconde, le reste toutes les 100 ms
        hudT += dt; if(hudT > 100){ hudT = 0; var left = Math.max(0, Math.ceil((sim.end * 1000 / PitSim.HZ - t) / 1000));
          var lc = Math.floor(left / 60) + ':' + String(left % 60).padStart(2, '0'); if(clock.textContent !== lc) clock.textContent = lc;
          stBar.firstChild.style.transform = 'scaleX(' + m.stamina.toFixed(3) + ')'; stBar.classList.toggle('low', m.stamina < .25);
          var sc = String(PitSim.result(sim).score); if(scoreEl.textContent !== sc) scoreEl.textContent = sc;
          if(flashT > 0){ flashT -= 100; if(flashT <= 0) cue.classList.remove('hot'); }
          else { var msg = m.down ? 'À terre ! Pousse vers le haut !' : m.zone === 'edge' ? 'Au bord : tu souffles' : m.zone === 'middle' ? 'Au milieu : ça compte double' : t < 4000 ? cue.textContent : '';
            if(m.down !== fallen){ fallen = m.down; cue.classList.toggle('hot', m.down); }
            if(cue.textContent !== msg) cue.textContent = msg; } }
        if(sim.over) finish();
      }
    }
    return { stop: stop, ready: ready, sim: sim };
  }

  window.PitGame = { start: start, inputFrom: inputFrom, anchorOn: anchorOn };
})();
