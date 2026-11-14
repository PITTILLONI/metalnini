// Metalnini — simulation du circle pit : pure et déterministe (aucun accès au DOM, hasard seedé), à pas fixe de 1/120 s.
// Repère : angle a en tours (sens inverse des aiguilles positif), rayon r normalisé (milieu < 0.45, piste, bord > 0.9).
(function(){
  var HZ = 120, DT = 1 / HZ, STEP_MS = 1000 / HZ, MAX_MS = 250;
  var DEFAULTS = { npc: 24, vmax: 1.2, accel: 2.5, lateral: 0.9, drain: 0.12, regen: 0.25, regenSlow: 0.05, body: 0.035,
    fallBase: 0.15, fallTired: 0.6, middleRisk: 2, downS: 1.5, upTaps: 4, npcFallPerS: 0.02, npcDownS: 4,
    liftHoldS: 0.4, liftMaxV: 0.4, pullHoldS: 0.5, pullAngle: 10 / 360, groove: 0.6,
    pts: { lap: 4, lift: 6, pull: 8, middleS: 1, rhythm: 30 }, circle: { lap: 1, lift: 2, pull: 3 } };

  // générateur mulberry32 : même graine, même suite
  function rng(seed){ var s = seed >>> 0; return function(){ s = (s + 0x6D2B79F5) >>> 0; var t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
  function merge(cfg){ var c = JSON.parse(JSON.stringify(DEFAULTS)); if(cfg) for(var k in cfg){
    if(cfg[k] && typeof cfg[k] === 'object' && c[k] && typeof c[k] === 'object') for(var j in cfg[k]) c[k][j] = cfg[k][j]; else c[k] = cfg[k]; } return c; }
  function clamp(x, lo, hi){ return x < lo ? lo : x > hi ? hi : x; }
  function zoneOf(r){ return r < 0.45 ? 'middle' : r > 0.9 ? 'edge' : 'track'; }

  function frac(x){ return x - Math.floor(x); }
  function angDiff(a, b){ var d = frac(a - b); return d > 0.5 ? 1 - d : d; }
  function distAR(a1, r1, a2, r2){ var t1 = a1 * 2 * Math.PI, t2 = a2 * 2 * Math.PI, dx = r1 * Math.cos(t1) - r2 * Math.cos(t2), dy = r1 * Math.sin(t1) - r2 * Math.sin(t2);
    return Math.sqrt(dx * dx + dy * dy); }

  // trace d'une course : { v:1, hz:10, p:[[a en millièmes de tour (cumulé), r en centièmes, à terre 0|1], …], e:[[t ms, type], …] }
  // trace utilisable : chaque point est un tableau de 3 nombres finis (une trace abîmée est ignorée en entier)
  function validTrace(tr){ return !!tr && tr.v === 1 && tr.hz > 0 && Array.isArray(tr.p) && tr.p.length > 0 && tr.p.every(function(q){
    return Array.isArray(q) && q.length >= 3 && isFinite(q[0]) && isFinite(q[1]) && isFinite(q[2]) && q[0] !== null && q[1] !== null && q[2] !== null; }); }
  function ghostAt(tr, tMs){
    if(!tr || tr.v !== 1 || !(tr.hz > 0) || !Array.isArray(tr.p) || !tr.p.length) return null;
    var x = tMs * tr.hz / 1000, i = Math.floor(x), p = tr.p, n = p.length;
    if(!Array.isArray(p[0]) || p[0].length < 3) return null;
    if(i >= n - 1) return { a: p[n - 1][0] / 1000, r: p[n - 1][1] / 100, down: !!p[n - 1][2] };
    if(i < 0) i = 0;
    var f = x - i, q = p[i], w = p[i + 1];
    if(!Array.isArray(w)) return null;
    return { a: (q[0] + (w[0] - q[0]) * f) / 1000, r: (q[1] + (w[1] - q[1]) * f) / 100, down: !!q[2] };
  }

  function create(o){
    var cfg = merge(o.cfg), rand = rng(o.seed || 1), sim = { cfg: cfg, rand: rand, n: 0, t: 0, end: Math.round((o.runS || 40) * HZ), over: false, acc: 0,
      me: { a: 0, r: 0.7, v: 0, stamina: 1, zone: 'track', down: false, downT: 0, taps: 0, laps: 0 }, npcs: [], friends: [], ghosts: [],
      bpm: o.bpm > 0 ? o.bpm : null, beats: 0, beatBase: 0, beatHits: 0, groove: 0, lifts: 0, pulls: 0, middleN: 0, trace: { v: 1, hz: 10, p: [], e: [] } };
    for(var i = 0; i < cfg.npc; i++) sim.npcs.push({ a: rand(), r: 0.5 + rand() * 0.38, v: 0.4 + rand() * 0.5, down: false, downT: 0, touch: false, hold: 0 });
    (o.friends || []).forEach(function(f){ sim.friends.push({ id: f.id, name: f.name, a: rand(), r: 0.97, pulled: false, hold: 0 }); });
    (o.ghosts || []).forEach(function(g){ if(g && validTrace(g.trace)) sim.ghosts.push(g); });
    record(sim);
    return sim;
  }

  var KEEP = { fall: 1, up: 1, lift: 1, pull: 1, lap: 1 };
  function record(sim){ var me = sim.me; sim.trace.p.push([Math.round(me.a * 1000), Math.round(me.r * 100), me.down ? 1 : 0]); }

  function knockDown(sim){ var me = sim.me; me.down = true; me.downT = sim.t; me.taps = 0; me.v = 0; }
  function fallChance(c, me){ return Math.min(1, (c.fallBase + (1 - me.stamina) * c.fallTired) * (me.zone === 'middle' ? c.middleRisk : 1)); }

  function step(sim, input){
    if(sim.over) return [];
    var c = sim.cfg, me = sim.me, ev = [], rand = sim.rand, body2 = 2 * c.body, t = (sim.n + 1) * STEP_MS, i, p;
    var add = function(type, id){ var e = { t: t, type: type }; if(id !== undefined) e.id = id; ev.push(e); };
    if(me.down){
      if(input.tap) me.taps++;
      var helped = sim.ghosts.some(function(g){ var q = ghostAt(g.trace, t); return q && !q.down && distAR(q.a, q.r, me.a, me.r) < body2; });
      if(me.taps >= c.upTaps || t - me.downT >= c.downS * 1000 - 1e-6 || helped){ me.down = false; add('up'); }
    } else {
      var th = clamp(input.throttle || 0, 0, 1);
      me.v += (th * c.vmax - me.v) * Math.min(1, c.accel * DT);
      me.r = clamp(me.r + clamp(input.lateral || 0, -1, 1) * c.lateral * DT, 0.05, 1);
    }
    me.zone = zoneOf(me.r);
    var st = me.stamina - c.drain * Math.pow(me.v / c.vmax, 2) * (me.zone === 'middle' ? 1.5 : 1) * DT;
    if(me.zone === 'edge') st += c.regen * DT;
    if(me.v < 0.2 * c.vmax) st += c.regenSlow * DT;
    me.stamina = clamp(st, 0, 1);

    for(i = 0; i < sim.npcs.length; i++){
      p = sim.npcs[i];
      if(p.down){ if(t - p.downT >= c.npcDownS * 1000) p.down = false; continue; }
      p.a += p.v * DT;
      if(rand() < c.npcFallPerS * DT){ p.down = true; p.downT = t; p.hold = 0; }
    }
    if(!me.down){
      for(i = 0; i < sim.npcs.length; i++){
        p = sim.npcs[i]; var d = distAR(me.a, me.r, p.a, p.r);
        if(p.down){
          // relever : lent tout près, on freine pour l'aider, liftHoldS plus tard il est debout
          if(d < body2 * 1.5 && me.v < c.liftMaxV * c.vmax){ me.v *= 0.85; p.hold += DT;
            if(p.hold >= c.liftHoldS - 1e-9){ p.down = false; p.hold = 0; add('lift', i); } }
          else p.hold = 0;
          continue;
        }
        if(d < body2){
          if(!p.touch){ p.touch = true; add('bump', i);
            if(Math.abs(me.v - p.v) > 0.5 * c.vmax && rand() < fallChance(c, me)){ knockDown(sim); me.downT = t; add('fall'); break; }
            me.v *= 0.6; }
          p.a += (frac(p.a - me.a) < 0.5 ? 1 : -1) * (body2 - d) / (2 * Math.PI * Math.max(0.1, p.r));   // on le pousse hors de soi
        } else p.touch = false;
      }
    }
    // milieu : des coureurs le traversent, un choc lancé à pleine vitesse peut faire tomber
    if(!me.down && me.zone === 'middle' && rand() < 0.5 * c.middleRisk * DT && me.v >= c.groove * c.vmax){
      add('bump'); if(rand() < fallChance(c, me)){ knockDown(sim); me.downT = t; add('fall'); } }
    if(!me.down) me.a += me.v * DT;
    if(Math.floor(me.a) > me.laps){ me.laps = Math.floor(me.a); add('lap'); }

    sim.friends.forEach(function(f){ if(f.pulled) return;
      if(!me.down && me.zone === 'edge' && angDiff(me.a, f.a) < c.pullAngle){ f.hold += DT; if(f.hold >= c.pullHoldS - 1e-9){ f.pulled = true; add('pull', f.id); } }
      else f.hold = 0; });

    // rythme : dans le groove = lancé (v ≥ groove × vmax) et debout ; avec un tempo, on compte les battements tenus
    var grooving = !me.down && me.v >= c.groove * c.vmax;
    if(grooving) sim.groove++;
    if(sim.bpm){ var beatMs = 60000 / sim.bpm; if(Math.floor((t + 1e-6) / beatMs) > sim.beats){ sim.beats++; if(grooving) sim.beatHits++; add('beat'); } }
    if(!me.down && me.zone === 'middle') sim.middleN++;
    ev.forEach(function(e){ if(e.type === 'lift') sim.lifts++; else if(e.type === 'pull') sim.pulls++;
      if(KEEP[e.type]) sim.trace.e.push([Math.round(e.t), e.type]); });

    sim.n++; sim.t = sim.n * STEP_MS;
    if(sim.n % (HZ / sim.trace.hz) === 0) record(sim);
    if(sim.n >= sim.end) sim.over = true;
    return ev;
  }

  // tempo arrivé pendant la course (écoute de l'extrait plus lente que le décompte) : battements comptés à partir de là
  function setBpm(sim, bpm){ if(sim.bpm || !(bpm > 0) || sim.over) return false;
    sim.bpm = bpm; sim.beats = sim.beatBase = Math.floor((sim.t + 1e-6) / (60000 / bpm)); return true; }

  // score sur 100 : tours, relevés, potes attirés, secondes au milieu, rythme (0 à 1)
  function score(st, c){ var w = (c || DEFAULTS).pts;
    return Math.min(100, Math.round(st.laps * w.lap + st.lifts * w.lift + st.pulls * w.pull + st.middleS * w.middleS + st.rhythm * w.rhythm)); }
  function result(sim){
    var st = { laps: sim.me.laps, lifts: sim.lifts, pulls: sim.pulls, middleS: Math.round(sim.middleN / HZ),
      rhythm: sim.bpm ? (sim.beats > sim.beatBase ? sim.beatHits / (sim.beats - sim.beatBase) : 0) : (sim.n ? sim.groove / sim.n : 0) }, k = sim.cfg.circle;
    return { score: score(st, sim.cfg), circle: st.laps * k.lap + st.lifts * k.lift + st.pulls * k.pull, trace: sim.trace, stats: st };
  }

  // aides (tests et banc) : placer un coureur de la foule, le mettre à terre, distance au joueur
  function place(sim, i, a, r){ sim.npcs[i].a = a; sim.npcs[i].r = r; }
  function forceNpcDown(sim, i){ var p = sim.npcs[i]; p.down = true; p.downT = sim.t + 1e9; p.hold = 0; }
  function dist(sim, i){ var p = sim.npcs[i]; return distAR(sim.me.a, sim.me.r, p.a, p.r); }

  // temps réel écoulé : autant de pas qu'il en tient (plafonné, pour une app revenue de l'arrière-plan)
  function advance(sim, input, dtMs){
    var ev = []; sim.acc += Math.min(MAX_MS, Math.max(0, dtMs));
    while(sim.acc >= STEP_MS - 1e-9 && !sim.over){ sim.acc -= STEP_MS; ev.push.apply(ev, step(sim, input)); }
    return ev;
  }

  var PitSim = { DEFAULTS: DEFAULTS, HZ: HZ, create: create, step: step, advance: advance, ghostAt: ghostAt, score: score, result: result, setBpm: setBpm,
    knockDown: knockDown, place: place, forceNpcDown: forceNpcDown, dist: dist };
  if(typeof module !== 'undefined' && module.exports) module.exports = PitSim; else window.PitSim = PitSim;
})();
