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

  function create(o){
    var cfg = merge(o.cfg), rand = rng(o.seed || 1), sim = { cfg: cfg, rand: rand, n: 0, t: 0, end: Math.round((o.runS || 40) * HZ), over: false, acc: 0,
      me: { a: 0, r: 0.7, v: 0, stamina: 1, zone: 'track', down: false }, npcs: [] };
    for(var i = 0; i < cfg.npc; i++) sim.npcs.push({ a: rand(), r: 0.5 + rand() * 0.38, v: 0.4 + rand() * 0.5, down: false, downT: 0 });
    return sim;
  }

  function step(sim, input){
    if(sim.over) return [];
    var c = sim.cfg, me = sim.me, ev = [], th = clamp(input.throttle || 0, 0, 1);
    me.v += (th * c.vmax - me.v) * Math.min(1, c.accel * DT);
    me.a += me.v * DT;
    me.r = clamp(me.r + clamp(input.lateral || 0, -1, 1) * c.lateral * DT, 0.05, 1);
    me.zone = zoneOf(me.r);
    var st = me.stamina - c.drain * Math.pow(me.v / c.vmax, 2) * (me.zone === 'middle' ? 1.5 : 1) * DT;
    if(me.zone === 'edge') st += c.regen * DT;
    if(me.v < 0.2 * c.vmax) st += c.regenSlow * DT;
    me.stamina = clamp(st, 0, 1);
    for(var i = 0; i < sim.npcs.length; i++){ var p = sim.npcs[i]; if(!p.down) p.a += p.v * DT; }
    sim.n++; sim.t = sim.n * STEP_MS;
    if(sim.n >= sim.end) sim.over = true;
    return ev;
  }

  // temps réel écoulé : autant de pas qu'il en tient (plafonné, pour une app revenue de l'arrière-plan)
  function advance(sim, input, dtMs){
    var ev = []; sim.acc += Math.min(MAX_MS, Math.max(0, dtMs));
    while(sim.acc >= STEP_MS - 1e-9 && !sim.over){ sim.acc -= STEP_MS; ev.push.apply(ev, step(sim, input)); }
    return ev;
  }

  var PitSim = { DEFAULTS: DEFAULTS, HZ: HZ, create: create, step: step, advance: advance };
  if(typeof module !== 'undefined' && module.exports) module.exports = PitSim; else window.PitSim = PitSim;
})();
