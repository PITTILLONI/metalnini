// Metalnini — coureurs du circle pit : allures variées (carrure, cheveux, t-shirt, veste à patchs) et poses articulées
// vues de dos (hauteur 1, sol à y = 0, y vers le haut). Les poses sont « cuites » en textures PixiJS une fois au chargement.
(function(){
  var SKINS = [0xf1c9a5, 0xe0ac84, 0xc68c64, 0x9a6444, 0x6e4630, 0xf6dcc4];
  var SHIRTS = [0x15110f, 0x1c1714, 0x221b17, 0x2e251d, 0x3a1414, 0x15110f, 0x0f0f12];
  var HAIRS = [0x15110f, 0x3b2a1e, 0x6b4a2b, 0xa8813c, 0xd9cdb8, 0x7a1f1f];
  function rng(seed){ var s = seed >>> 0; return function(){ s = (s + 0x6D2B79F5) >>> 0; var t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
  function pick(r, l){ return l[Math.floor(r() * l.length)]; }

  // allures de la foule : même graine, mêmes allures ; carrures et coupes réparties pour qu'on n'ait pas des clones
  function looks(seed, n){ var r = rng(seed), out = [], i;
    for(i = 0; i < n; i++) out.push({ build: (i + Math.floor(r() * 6)) % 6, hair: (i * 3 + Math.floor(r() * 8)) % 8, skin: pick(r, SKINS), hairColor: pick(r, HAIRS),
      shirt: pick(r, SHIRTS), print: Math.floor(r() * 4), jacket: r() < 0.25 });
    return out; }

  function lerp(a, b, t){ return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]; }
  var DOWN = { head: [-0.42, 0.08], neck: [-0.32, 0.08], hip: [0, 0.07], lElbow: [-0.22, 0.14], rElbow: [-0.12, 0.03], lHand: [-0.1, 0.18], rHand: [0.08, 0.04],
    lKnee: [0.2, 0.1], rKnee: [0.22, 0.05], lFoot: [0.42, 0.06], rFoot: [0.44, 0.03] };
  function stand(){ return { head: [0, 0.92], neck: [0, 0.8], hip: [0, 0.5], lElbow: [-0.15, 0.62], rElbow: [0.15, 0.62], lHand: [-0.17, 0.46], rHand: [0.17, 0.46],
    lKnee: [-0.07, 0.25], rKnee: [0.07, 0.25], lFoot: [-0.08, 0], rFoot: [0.08, 0] }; }

  // pose : kind = run | stumble | down | up | lift | cheer, phase de 0 à 1
  function pose(kind, phase){
    var p = stand(), c = Math.cos(phase * Math.PI * 2), s = Math.sin(phase * Math.PI * 2), k;
    if(kind === 'run'){ var L = 0.14 * Math.max(0, c), R = 0.14 * Math.max(0, -c), bob = 0.02 * Math.abs(c);
      for(k in p) p[k][1] += bob;
      p.lFoot = [-0.08, L]; p.rFoot = [0.08, R]; p.lKnee = [-0.07, 0.25 + L * 0.8]; p.rKnee = [0.07, 0.25 + R * 0.8];
      p.lHand = [-0.18, 0.47 + bob - 0.08 * c]; p.rHand = [0.18, 0.47 + bob + 0.08 * c]; }
    else if(kind === 'stumble'){ var d = 0.12 * phase; for(k in p) p[k][0] += d * p[k][1];
      p.lHand = [-0.32, 0.72]; p.rHand = [0.34, 0.66]; p.lElbow = [-0.24, 0.7]; p.rElbow = [0.25, 0.66]; p.rFoot = [0.16, 0.08]; }
    else if(kind === 'down'){ p = {}; for(k in DOWN) p[k] = DOWN[k].slice(); }
    else if(kind === 'up'){ var st = stand(); p = {}; for(k in DOWN) p[k] = lerp(DOWN[k], st[k], phase); }
    else if(kind === 'lift'){ var b = 0.1 + 0.05 * s;
      p.head = [0.1, 0.72 - b * 0.3]; p.neck = [0.08, 0.63 - b * 0.3]; p.hip = [0, 0.48];
      p.rElbow = [0.22, 0.46]; p.rHand = [0.32, 0.3 - b * 0.3]; p.lElbow = [-0.12, 0.55]; p.lHand = [-0.14, 0.42];
      p.lKnee = [-0.1, 0.22]; p.rKnee = [0.12, 0.22]; }
    else if(kind === 'cheer'){ var w = 0.05 * s; p.lElbow = [-0.2, 0.92]; p.rElbow = [0.2, 0.92]; p.lHand = [-0.18 - w, 1.12]; p.rHand = [0.18 + w, 1.12]; }
    return p;
  }

  // cuisson : une texture par image de chaque pose ; front = vu de face (visage = photo si fournie)
  var FRAMES = { run: 8, stumble: 2, down: 1, up: 2, lift: 2, cheer: 2 };
  function bake(PIXI, app, look, opts){
    opts = opts || {}; var H = 64, out = {}, kind, i, wide = [0.9, 1, 1.12, 1.25, 1.05, 0.95][look.build] || 1;
    for(kind in FRAMES){ out[kind] = [];
      for(i = 0; i < FRAMES[kind]; i++) out[kind].push(frame(PIXI, app, look, pose(kind, i / FRAMES[kind]), H, wide, opts)); }
    return out;
  }
  function frame(PIXI, app, look, p, H, wide, opts){
    var c = new PIXI.Container(), g = new PIXI.Graphics(), X = function(v){ return v[0] * H * wide; }, Y = function(v){ return -v[1] * H; };
    var limb = function(a, b, w, col){ g.moveTo(X(a), Y(a)).lineTo(X(b), Y(b)).stroke({ width: w, color: col, cap: 'round' }); };
    var pants = 0x1a1a1f, skin = look.skin, shirt = look.shirt;
    limb(p.hip, p.lKnee, 6 * wide, pants); limb(p.lKnee, p.lFoot, 5 * wide, pants); limb(p.hip, p.rKnee, 6 * wide, pants); limb(p.rKnee, p.rFoot, 5 * wide, pants);
    g.circle(X(p.lFoot), Y(p.lFoot), 3).fill(0x0d0a08); g.circle(X(p.rFoot), Y(p.rFoot), 3).fill(0x0d0a08);
    // buste : des épaules aux hanches, t-shirt sombre ; motif de groupe au dos ; veste à patchs pour certains
    var sh = 0.16 * H * wide, nx = X(p.neck), ny = Y(p.neck) + 3, hx = X(p.hip), hy = Y(p.hip);
    g.poly([nx - sh, ny, nx + sh, ny, hx + sh * 0.75, hy, hx - sh * 0.75, hy]).fill(look.jacket ? 0x2a2420 : shirt);
    if(!opts.front && look.print) g.circle((nx + hx) / 2, (ny + hy) / 2, 4 + look.print).stroke({ width: 1.5, color: [0xd9cdb8, 0xb23a3a, 0xeb9a26][look.print - 1] });
    if(look.jacket){ g.circle(nx - sh * 0.4, ny + 8, 2).fill(0xb23a3a); g.circle(nx + sh * 0.45, ny + 14, 2).fill(0xeb9a26); }
    limb(p.neck, p.lElbow, 4.5 * wide, look.jacket ? 0x2a2420 : shirt); limb(p.lElbow, p.lHand, 4, skin);
    limb(p.neck, p.rElbow, 4.5 * wide, look.jacket ? 0x2a2420 : shirt); limb(p.rElbow, p.rHand, 4, skin);
    // tête : de dos, les cheveux couvrent tout ; de face, visage (photo ronde si fournie)
    var hr = 7.5, cx = X(p.head), cy = Y(p.head);
    g.circle(cx, cy, hr).fill(skin);
    if(!opts.front){ hair(g, look, cx, cy, hr, false); }
    else if(!opts.face) hair(g, look, cx, cy, hr, true);
    c.addChild(g);
    if(opts.front && opts.face){ var f = new PIXI.Sprite(opts.face); f.anchor.set(0.5); f.width = f.height = hr * 2.3; f.position.set(cx, cy); c.addChild(f); }
    var t = app.renderer.generateTexture({ target: c, resolution: 2 });
    c.destroy({ children: true }); return t;
  }
  // coupes vues de dos ou de face : rasé, court, mi-long, long, dreads, crête, chignon, queue de cheval
  function hair(g, look, cx, cy, r, front){
    var col = look.hairColor, h = look.hair;
    if(h === 0){ g.circle(cx, cy, r).fill({ color: col, alpha: front ? 0.15 : 0.35 }); return; }
    if(front){ g.ellipse(cx, cy - r * 0.55, r, r * 0.5).fill(col); if(h >= 3) { g.rect(cx - r, cy - r * 0.4, 2.5, r * (h === 3 ? 2.2 : 1.6)).fill(col); g.rect(cx + r - 2.5, cy - r * 0.4, 2.5, r * (h === 3 ? 2.2 : 1.6)).fill(col); } return; }
    g.circle(cx, cy, r).fill(col);
    if(h === 2) g.ellipse(cx, cy + r * 0.9, r * 0.9, r * 0.5).fill(col);
    else if(h === 3) g.roundRect(cx - r, cy, r * 2, r * 2.4, r).fill(col);
    else if(h === 4) for(var i = -2; i <= 2; i++) g.roundRect(cx + i * r * 0.38 - 1.5, cy, 3, r * 2, 1.5).fill(col);
    else if(h === 5) g.roundRect(cx - 2.5, cy - r * 1.7, 5, r * 1.4, 2).fill(col);
    else if(h === 6) g.circle(cx, cy - r * 0.9, r * 0.5).fill(col);
    else if(h === 7) g.roundRect(cx - 2.5, cy + r * 0.6, 5, r * 1.8, 2.5).fill(col);
  }

  var PitBodies = { looks: looks, pose: pose, bake: bake, FRAMES: FRAMES };
  if(typeof module !== 'undefined' && module.exports) module.exports = PitBodies; else window.PitBodies = PitBodies;
})();
