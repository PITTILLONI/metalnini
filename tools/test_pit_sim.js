// Tests de la simulation du circle pit (proto/fosse/pit-sim.js), sans dépendance : node tools/test_pit_sim.js
const path = require('path');
const ROOT = path.join(__dirname, '..', 'proto', 'fosse') + '/';
const PitSim = require(ROOT + 'pit-sim.js');
let fails = 0;
function check(name, ok){ console.log((ok ? 'OK   ' : 'FAIL ') + name); if(!ok) fails++; }
const GAS = { throttle:1, lateral:0, tap:false }, IDLE = { throttle:0, lateral:0, tap:false };
function run(sim, input, s){ const ev = []; for(let i = 0; i < Math.round(s * 120); i++) ev.push.apply(ev, PitSim.step(sim, input)); return ev; }
function fresh(o){ return PitSim.create(Object.assign({ seed:1, runS:40, cfg:{ npc:0 } }, o || {})); }

// ---------- Task 1 : déplacement, endurance, zones ----------
let s = fresh(); run(s, GAS, 5);
check('déplacement : plein gaz 5 s → v proche de vmax', Math.abs(s.me.v - 1.2) < 0.05);
run(s, IDLE, 2);
check('déplacement : lâcher → v décroît', s.me.v < 0.6);
s = fresh(); run(s, GAS, 8); const tired = s.me.stamina;
let k = 0; while(s.me.zone !== 'edge' && k++ < 1200) PitSim.step(s, { throttle:0, lateral:1, tap:false });
run(s, IDLE, 4);
check('endurance : plein gaz 8 s la vide sous 0.2, le bord la remonte', tired < 0.2 && s.me.zone === 'edge' && s.me.stamina > 0.8);
s = fresh(); run(s, { throttle:.5, lateral:-1, tap:false }, 2);
check('zones : lateral -1 mène au milieu', s.me.zone === 'middle');
s = fresh({ runS:1 }); run(s, GAS, 119 / 120); const before = s.over; PitSim.step(s, GAS);
check('fin : sim.over à runS', before === false && s.over === true);
s = fresh(); PitSim.advance(s, GAS, 60000);
check('arrière-plan : advance(…, 60000) ne fait que 30 pas', Math.abs(s.t - 250) < 1e-6);
const d1 = fresh({ cfg:{ npc:24 } }), d2 = fresh({ cfg:{ npc:24 } });
[d1, d2].forEach(x => { run(x, GAS, 3); run(x, { throttle:.6, lateral:-.5, tap:false }, 3); run(x, IDLE, 2); });
check('déterminisme : même graine, mêmes entrées → même état', JSON.stringify(d1.me) === JSON.stringify(d2.me) && JSON.stringify(d1.npcs) === JSON.stringify(d2.npcs));

// ---------- Task 2 : foule, chutes, relevés, potes attirés ----------
const TAP = { throttle:0, lateral:0, tap:true };
function has(ev, type){ return ev.some(e => e.type === type); }
function onlyNpcAhead(seed){ const x = PitSim.create({ seed, runS:40, cfg:{ npc:1, npcFallPerS:0 } }); PitSim.place(x, 0, 0.05, 0.7); x.npcs[0].v = 0; return x; }
let fell = false;
for(let seed = 1; seed <= 3 && !fell; seed++){ s = onlyNpcAhead(seed); s.me.v = 1.2; s.me.stamina = 0; fell = has(run(s, GAS, 3), 'fall'); }
check('chute : choc plein gaz endurance vide → fall dans les 3 s', fell);
s = fresh(); PitSim.knockDown(s); let ev = [];
for(let i = 0; i < 4; i++){ ev = ev.concat(PitSim.step(s, TAP), PitSim.step(s, IDLE)); }
check('relève seul : upTaps touchers → up avant downS', has(ev, 'up') && !s.me.down && s.t < 1500);
s = fresh(); PitSim.knockDown(s); const tDown = s.t; ev = run(s, IDLE, 1.49); const early = has(ev, 'up'); ev = run(s, IDLE, 0.02);
check('relève seul : sans toucher → up à downS', !early && has(ev, 'up'));
const sweep = { v:1, hz:10, p:Array.from({ length:41 }, (_, i) => [Math.round(i / 40 * 1000), 70, 0]), e:[] };
s = fresh({ ghosts:[{ id:'g1', name:'Riffeuse', trace:sweep }] }); s.me.a = 0.25; PitSim.knockDown(s); ev = run(s, IDLE, 1.4);
check('fantôme qui passe relève', has(ev, 'up') && ev.find(e => e.type === 'up').t < 1400);
s = PitSim.create({ seed:1, runS:40, cfg:{ npc:1, npcFallPerS:0 } }); PitSim.place(s, 0, 0.03, 0.7); PitSim.forceNpcDown(s, 0);
ev = []; k = 0; while(k++ < 600 && PitSim.dist(s, 0) > 0.07) ev = ev.concat(PitSim.step(s, { throttle:.3, lateral:0, tap:false }));
ev = ev.concat(run(s, IDLE, 1));
check('relever un npc : ralentir dessus → lift', ev.some(e => e.type === 'lift' && e.id === 0) && !s.npcs[0].down);
s = PitSim.create({ seed:1, runS:40, cfg:{ npc:1, npcFallPerS:0 } }); PitSim.place(s, 0, 0.1, 0.7); PitSim.forceNpcDown(s, 0); s.me.v = 1.2;
check('pas de relevé en passant vite', !has(run(s, GAS, 2), 'lift'));
s = fresh({ friends:[{ id:'f1', name:'Pote' }] }); s.me.r = 0.97; s.me.a = s.friends[0].a; ev = run(s, IDLE, 0.6).concat(run(s, IDLE, 1));
check('attirer un pote : au bord, 0.5 s → pull une seule fois', ev.filter(e => e.type === 'pull' && e.id === 'f1').length === 1 && s.friends[0].pulled && s.friends[0].r === 0.97);
s = fresh(); ev = run(s, GAS, 2);
check('tour : un tour complet → lap', ev.filter(e => e.type === 'lap').length === 1);
let fallsTrack = 0, fallsMid = 0;
for(let seed = 1; seed <= 200; seed++){
  const a = PitSim.create({ seed, runS:40, cfg:{ npcFallPerS:0 } }); if(has(run(a, GAS, 4), 'fall')) fallsTrack++;
  const b = PitSim.create({ seed, runS:40, cfg:{ npcFallPerS:0 } }); if(has(run(b, { throttle:1, lateral:-1, tap:false }, .5).concat(run(b, GAS, 3.5)), 'fall')) fallsMid++;
}
check('milieu plus risqué : plus de chutes au milieu (' + fallsMid + ') que sur la piste (' + fallsTrack + ')', fallsMid > fallsTrack);

// ---------- Task 3 : score, cercle, trace, fantômes ----------
const C = PitSim.DEFAULTS;
check('score : formule', PitSim.score({ laps:5, lifts:2, pulls:1, middleS:6, rhythm:.5 }, C) === 61);
check('score : plafonné à 100', PitSim.score({ laps:50, lifts:0, pulls:0, middleS:0, rhythm:1 }, C) === 100);
s = fresh({ runS:4, bpm:null }); run(s, GAS, 2); run(s, IDLE, 2); let r3 = PitSim.result(s);
check('rythme sans tempo : part du temps lancé', r3.stats.rhythm > 0.4 && r3.stats.rhythm < 0.52);
s = fresh({ runS:4, bpm:120 }); run(s, GAS, 2); run(s, IDLE, 2); r3 = PitSim.result(s);
check('rythme avec tempo : battements tenus', Math.abs(r3.stats.rhythm - 0.5) < 0.01);
s = fresh({ runS:40, cfg:{ npc:24 }, friends:[{ id:'f1', name:'P' }] }); const path3 = [];
for(let i = 0; i < 40 * 120; i++){ PitSim.step(s, i % 900 < 600 ? GAS : { throttle:.3, lateral:(i % 1800 < 900 ? 1 : -1), tap:i % 7 === 0 }); path3.push({ t:s.t, a:s.me.a, r:s.me.r }); }
r3 = PitSim.result(s);
check('cercle : laps + 2 × relevés + 3 × potes', r3.circle === r3.stats.laps + 2 * r3.stats.lifts + 3 * r3.stats.pulls && r3.stats.laps > 10);
check('trace : 40 s de course < 20 000 caractères (' + JSON.stringify(r3.trace).length + ')', JSON.stringify(r3.trace).length < 20000);
const at = path3[147], g3 = PitSim.ghostAt(r3.trace, at.t);
check('fantôme : ghostAt rejoue la trace', !!g3 && Math.abs(g3.a - at.a) < 0.01 && Math.abs(g3.r - at.r) < 0.02);
check('fantôme : trace invalide → null', [null, {}, { v:2, hz:10, p:[[0, 70, 0]] }, { v:1, hz:10, p:'x' }, { v:1, hz:10, p:[] }].every(t => PitSim.ghostAt(t, 0) === null)
  && PitSim.create({ seed:1, runS:40, ghosts:[{ id:'g', trace:{ v:2 } }, { id:'h', trace:r3.trace }] }).ghosts.length === 1);
s = fresh({ runS:40, bpm:null }); run(s, GAS, 40); r3 = PitSim.result(s);
check('sans fantôme ni pote, 100 atteignable', r3.score === 100 && s.over);

// ---------- Task 4 : tempo ----------
const PitBeat = require(ROOT + 'pit-beat.js');
function clicks(bpm, sec, sr){ const x = new Float32Array(sec * sr), step = Math.round(sr * 60 / bpm);
  for(let i = 0; i < x.length; i += step) for(let j = 0; j < 200 && i + j < x.length; j++) x[i + j] = Math.sin(j * 0.6) * (1 - j / 200); return x; }
const SR = 22050; let b4 = PitBeat.detect(clicks(120, 10, SR), SR);
check('tempo : clics à 120 → ' + b4, b4 >= 118 && b4 <= 122);
b4 = PitBeat.detect(clicks(90, 10, SR), SR);
check('tempo : clics à 90 → ' + b4, b4 >= 88 && b4 <= 92);
let seed4 = 7; const noise = new Float32Array(10 * SR).map(() => { seed4 ^= seed4 << 13; seed4 ^= seed4 >>> 17; seed4 ^= seed4 << 5; return (seed4 >>> 0) / 2147483648 - 1; });   // xorshift32
check('tempo : bruit blanc → null', PitBeat.detect(noise, SR) === null);
check('tempo : silence → null', PitBeat.detect(new Float32Array(10 * SR), SR) === null);

console.log(fails ? fails + ' échec(s)' : 'tous OK');
process.exit(fails ? 1 : 0);
