// Metalnini — affichage du circle pit (PixiJS 8) : vue de dessus, caméra qui suit le joueur et tourne avec lui,
// pouce qui dirige (glisser vers le haut = foncer, sur les côtés = bord ou milieu), foule, fantômes, potes au bord.
// La simulation (PitSim) avance à pas fixe ; ici on ne fait que lire le doigt, dessiner et rendre les retours.
(function(){
  var GOLD = 0xeb9a26, GOLD_HI = 0xf4b243, BONE = 0xd9cdb8, BLOOD = 0xb23a3a, INK = 0x0d0a08, INK2 = 0x15110f, LINE = 0x2e251d;
  function clamp(x, lo, hi){ return x < lo ? lo : x > hi ? hi : x; }

  // pouce : l'écart à l'ancre donne les commandes (90 px pour le maximum)
  function inputFrom(anchor, point){
    if(!anchor || !point) return { throttle: 0, lateral: 0 };
    return { throttle: clamp((anchor.y - point.y) / 90, 0, 1), lateral: clamp((point.x - anchor.x) / 90, -1, 1) };
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

  // silhouette vue de dessus (épaules + tête), tournée vers le haut ; teintée selon qui court
  function bodyTex(PIXI, app){
    var g = new PIXI.Graphics();
    g.ellipse(0, 4, 15, 9).fill(0xffffff); g.circle(0, 0, 7.5).fill(0xffffff).stroke({ width: 2, color: 0x000000, alpha: .35 });
    var t = app.renderer.generateTexture(g); g.destroy(); return t;
  }
  function dotTex(PIXI, app){ var g = new PIXI.Graphics(); g.circle(0, 0, 6).fill(0xffffff); var t = app.renderer.generateTexture(g); g.destroy(); return t; }

  function start(host, o){
    var PIXI = o.PIXI, PitSim = window.PitSim, stopped = false, app = null, wrap, hud, cue, clock, stBar, scoreEl, st = { down: false },
        tapPending = false, sim, onDown, onMove, onUp, offs = [];
    addCss();
    wrap = document.createElement('div'); wrap.className = 'pg';
    wrap.innerHTML = '<div class="pg-hud"><b class="pg-clock">0:' + String(o.runS).padStart(2, '0') + '</b><div class="pg-st"><i></i></div><b class="pg-score">0</b></div>' +
      '<p class="pg-cue">Pouce vers le haut : fonce. Sur les côtés : bord pour souffler, milieu pour les braves.</p>';
    host.appendChild(wrap);
    hud = wrap.querySelector('.pg-hud'); clock = hud.querySelector('.pg-clock'); stBar = hud.querySelector('.pg-st'); scoreEl = hud.querySelector('.pg-score'); cue = wrap.querySelector('.pg-cue');
    sim = PitSim.create({ seed: o.seed, runS: o.runS, cfg: o.cfg, ghosts: o.ghosts, friends: o.friends, bpm: o.bpm });

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
      var c = sim.cfg, tex = bodyTex(PIXI, app), dot = dotTex(PIXI, app), world = new PIXI.Container(), S = 1, i;
      app.stage.addChild(world);
      var floor = new PIXI.Graphics(), deco = new PIXI.Container(), dust = new PIXI.Container(), crowd = new PIXI.Container(), fx = new PIXI.Container(), streaks = new PIXI.Graphics();
      world.addChild(floor, deco, dust, crowd); app.stage.addChild(streaks, fx);
      function drawFloor(){
        S = Math.max(app.screen.width, app.screen.height) * 0.9;
        floor.clear();
        floor.circle(0, 0, 1.12 * S).fill(INK);
        floor.circle(0, 0, 0.9 * S).fill(INK2);
        floor.circle(0, 0, 0.45 * S).fill({ color: BLOOD, alpha: .16 });
        floor.circle(0, 0, 0.45 * S).stroke({ width: 2, color: BLOOD, alpha: .5 });
        floor.circle(0, 0, 0.9 * S).stroke({ width: 3, color: GOLD, alpha: .55 });
        for(var k = 0; k < 48; k++){ var t = k / 48 * Math.PI * 2; floor.moveTo(Math.cos(t) * .9 * S, Math.sin(t) * .9 * S).lineTo(Math.cos(t) * 1.0 * S, Math.sin(t) * 1.0 * S); }
        floor.stroke({ width: 1, color: LINE, alpha: .9 });
      }
      drawFloor(); app.renderer.on('resize', drawFloor);
      // spectateurs immobiles autour (ils lèvent les bras quand le pit va vite : on les fait grossir au rythme)
      var fans = [];
      for(i = 0; i < 70; i++){ var f = new PIXI.Sprite(tex); f.anchor.set(.5); f.tint = 0x6b6258; var fa = i / 70 + (i % 3) * .004, fr = 1.03 + (i % 4) * .025;
        f._a = fa; f._r = fr; f.rotation = fa * Math.PI * 2 - Math.PI / 2; crowd.addChild(f); fans.push(f); }
      var npcs = sim.npcs.map(function(){ var s = new PIXI.Sprite(tex); s.anchor.set(.5); s.tint = BONE; crowd.addChild(s); return s; });
      var ghosts = sim.ghosts.map(function(g){ var s = new PIXI.Sprite(tex); s.anchor.set(.5); s.tint = GOLD_HI; s.alpha = .55; crowd.addChild(s);
        var lb = new PIXI.Text({ text: (g.name || '').slice(0, 12), style: { fontFamily: 'Barlow', fontSize: 12, fill: GOLD_HI, fontWeight: '700' } }); lb.anchor.set(.5, 1.8); s.addChild(lb); return s; });
      var friends = sim.friends.map(function(fr){ var s = new PIXI.Sprite(tex); s.anchor.set(.5); s.tint = GOLD; s.alpha = .9; deco.addChild(s);
        var lb = new PIXI.Text({ text: fr.name || 'Pote', style: { fontFamily: 'Barlow', fontSize: 13, fill: 0xf3f0ea, fontWeight: '700' } }); lb.anchor.set(.5, 1.7); s.addChild(lb); return s; });
      var me = new PIXI.Sprite(tex); me.anchor.set(.5); me.tint = GOLD; me.scale.set(1.25); crowd.addChild(me);
      var ring = new PIXI.Graphics(); ring.circle(0, 0, 17).stroke({ width: 2, color: GOLD_HI }); me.addChild(ring);
      var pool = []; for(i = 0; i < 120; i++){ var d = new PIXI.Sprite(dot); d.anchor.set(.5); d.tint = 0x8a7d6a; d.visible = false; dust.addChild(d); pool.push(d); }
      var dustI = 0, dustT = 0, shakeT = 0, shakeA = 0, beatT = 0, hudT = 0, streakY = 0, fallen = false;

      function place(spr, a, r, scale){ var t = a * Math.PI * 2; spr.x = Math.cos(t) * r * S; spr.y = Math.sin(t) * r * S; spr.rotation = t + Math.PI; if(scale) spr.scale.set(scale); }
      function puff(a, r){ var d = pool[dustI++ % pool.length], t = a * Math.PI * 2; d.visible = true; d.x = Math.cos(t) * r * S + (Math.random() - .5) * 10; d.y = Math.sin(t) * r * S + (Math.random() - .5) * 10;
        d.alpha = .55; d.scale.set(.5); d._life = 0; }
      function feedback(ev){
        ev.forEach(function(e){
          if(e.type === 'bump'){ if(!o.reduce){ shakeT = 120; shakeA = 4; } o.buzz && o.buzz([12]); o.snd && o.snd('pit-bouscule', .5); }
          else if(e.type === 'fall'){ if(!o.reduce){ shakeT = 220; shakeA = 9; } o.buzz && o.buzz([40, 30, 60]); o.snd && o.snd('pit-chute', .8); }
          else if(e.type === 'up'){ o.snd && o.snd('pit-releve', .6); }
          else if(e.type === 'lift'){ o.buzz && o.buzz([20, 40, 20]); o.snd && o.snd('pit-releve', .7); flash('Relevé !'); }
          else if(e.type === 'pull'){ var fr = sim.friends.filter(function(x){ return x.id === e.id; })[0]; o.onPull && o.onPull(e.id); o.buzz && o.buzz([20, 30, 40]);
            o.snd && o.snd('pit-foule', .8); flash((fr && fr.name ? fr.name : 'Ton pote') + ' entre !'); }
          else if(e.type === 'lap'){ o.buzz && o.buzz([10]); }
          else if(e.type === 'beat'){ beatT = 140; }
        });
      }
      var flashT = 0;
      function flash(txt){ cue.textContent = txt; cue.classList.add('hot'); flashT = 1100; }

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
        var m = sim.me, t = sim.t;
        // caméra : le joueur en bas d'écran, sa course vers le haut, léger recul quand il fonce
        var th = m.a * Math.PI * 2, zoom = 1 - .15 * (m.v / c.vmax), px = Math.cos(th) * m.r * S, py = Math.sin(th) * m.r * S;
        world.pivot.set(px, py); world.rotation = -th - Math.PI; world.scale.set(zoom);
        var sx = 0, sy = 0; if(shakeT > 0){ shakeT -= dt; sx = (Math.random() - .5) * shakeA * 2; sy = (Math.random() - .5) * shakeA * 2; }
        world.position.set(app.screen.width / 2 + sx, app.screen.height * .66 + sy);
        place(me, m.a, m.r); me.alpha = m.down ? .7 : 1; if(m.down){ me.scale.set(1.25, .7); } else me.scale.set(1.25);
        sim.npcs.forEach(function(p, k){ place(npcs[k], p.a, p.r); npcs[k].scale.set(1, p.down ? .55 : 1); npcs[k].tint = p.down ? 0xe0605a : BONE; });
        sim.ghosts.forEach(function(g, k){ var q = PitSim.ghostAt(g.trace, t); if(q){ place(ghosts[k], q.a, q.r); ghosts[k].scale.set(1, q.down ? .55 : 1); } });
        sim.friends.forEach(function(fr, k){ if(fr.pulled){ place(friends[k], fr.a + (t / 1000) * .7, .8); friends[k].tint = GOLD_HI; } else place(friends[k], fr.a, fr.r); });
        var beat = beatT > 0 ? (beatT -= dt, 1 + .12 * beatT / 140) : 1;
        for(var k = 0; k < fans.length; k++){ place(fans[k], fans[k]._a, fans[k]._r, (k % 2 ? beat : 1) * (.9 + .25 * m.v / c.vmax)); }
        // poussière quand le pit est lancé
        dustT += dt; if(m.v >= c.groove * c.vmax && dustT > 30){ dustT = 0; puff(m.a - .004, m.r); }
        for(k = 0; k < pool.length; k++){ var d = pool[k]; if(!d.visible) continue; d._life += dt; d.alpha = .55 * (1 - d._life / 650); d.scale.set(.5 + d._life / 260); if(d._life > 650) d.visible = false; }
        // traînées de vitesse (sauf mouvement réduit)
        streaks.clear();
        if(!o.reduce && m.v > .4 * c.vmax){ streakY = (streakY + dt * m.v * 1.4) % 90; var a = (m.v / c.vmax - .4) * .5;
          for(k = 0; k < 10; k++){ var x = (k * 97) % app.screen.width, y = ((k * 53) % 90 + streakY) + (k % 4) * 180; streaks.rect(x, y % app.screen.height, 2, 40 + 40 * m.v).fill({ color: BONE, alpha: a }); } }
        // texte : rien sous la barre d'onglets, chrono réécrit à la seconde, le reste toutes les 100 ms
        hudT += dt; if(hudT > 100){ hudT = 0; var left = Math.max(0, Math.ceil((sim.end * 1000 / PitSim.HZ - t) / 1000));
          var lc = '0:' + String(left).padStart(2, '0'); if(clock.textContent !== lc) clock.textContent = lc;
          stBar.firstChild.style.transform = 'scaleX(' + m.stamina.toFixed(3) + ')'; stBar.classList.toggle('low', m.stamina < .25);
          var sc = String(PitSim.result(sim).score); if(scoreEl.textContent !== sc) scoreEl.textContent = sc;
          if(flashT > 0){ flashT -= 100; if(flashT <= 0) cue.classList.remove('hot'); }
          else { var msg = m.down ? 'À terre ! Tape vite pour te relever' : m.zone === 'edge' ? 'Au bord : tu souffles' : m.zone === 'middle' ? 'Au milieu : ça compte double' : t < 4000 ? cue.textContent : '';
            if(m.down !== fallen){ fallen = m.down; cue.classList.toggle('hot', m.down); }
            if(cue.textContent !== msg) cue.textContent = msg; } }
        if(sim.over) finish();
      }
    }
    return { stop: stop, ready: ready, sim: sim };
  }

  window.PitGame = { start: start, inputFrom: inputFrom, anchorOn: anchorOn };
})();
