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

console.log(fails ? fails + ' échec(s)' : 'tous OK');
process.exit(fails ? 1 : 0);
