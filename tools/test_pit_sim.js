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
run(s, { throttle:0, lateral:1, tap:false }, 4);
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
s = fresh({ friends:[{ id:'f1', name:'Pote' }] }); s.me.r = 0.97; s.me.a = s.friends[0].a; const EDGE = { throttle:0, lateral:1, tap:false }; ev = run(s, EDGE, 0.6).concat(run(s, EDGE, 1));
check('attirer un pote : au bord, 0.5 s → pull une seule fois', ev.filter(e => e.type === 'pull' && e.id === 'f1').length === 1 && s.friends[0].pulled && s.friends[0].r === 0.97);
s = fresh(); ev = run(s, GAS, 2);
check('tour : un tour complet → lap', ev.filter(e => e.type === 'lap').length === 1);
let fallsTrack = 0, fallsMid = 0;
for(let seed = 1; seed <= 200; seed++){
  const a = PitSim.create({ seed, runS:40, cfg:{ npcFallPerS:0 } }); if(has(run(a, GAS, 4), 'fall')) fallsTrack++;
  const b = PitSim.create({ seed, runS:40, cfg:{ npcFallPerS:0 } }); if(has(run(b, { throttle:1, lateral:-1, tap:false }, 4), 'fall')) fallsMid++;
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

// ---------- Task 6 : commandes de l'affichage ----------
const vm = require('vm'), fs = require('fs'), box = { window:{}, Math, performance:{ now:() => 0 } };
vm.runInNewContext(fs.readFileSync(ROOT + 'pit-view.js', 'utf8'), box);
const PitGame = box.window.PitGame;
check('affichage : chargé sans PixiJS ni DOM, PitGame expose start, inputFrom, anchorOn', typeof PitGame.start === 'function' && typeof PitGame.inputFrom === 'function' && typeof PitGame.anchorOn === 'function');
const in1 = PitGame.inputFrom({ x:100, y:300 }, { x:145, y:210 });
check('commandes : pouce vers le haut = gaz, côté = voie (marge de 25 px)', Math.abs(in1.throttle - 1) < 1e-9 && Math.abs(in1.lateral - 20 / 65) < 1e-9 && PitGame.inputFrom({ x:100, y:300 }, { x:122, y:200 }).lateral === 0);
const in2 = PitGame.inputFrom({ x:100, y:300 }, { x:0, y:400 });
check('commandes : vers le bas = pas de gaz, bornes respectées', in2.throttle === 0 && in2.lateral === -1);
const stt = { anchor:{ x:100, y:300 }, point:{ x:100, y:210 } };
PitGame.anchorOn(stt, { x:300, y:500 }); const in3 = PitGame.inputFrom(stt.anchor, stt.point);
check('pouce levé puis reposé ailleurs : ancre recalée, pas de saut', in3.throttle === 0 && in3.lateral === 0 && stt.down === true);

// ---------- Relecture finale ----------
const badTr = { v:1, hz:10, p:[[0, 70, 0], [1, 70, 0], null], e:[] };
let thrown = null; s = fresh({ ghosts:[{ id:'bad', trace:badTr }] }); PitSim.knockDown(s);
try { run(s, IDLE, 1); } catch(e){ thrown = e; }
check('fantôme : trace abîmée (point null) ignorée, pas d\'erreur', !thrown && s.ghosts.length === 0);
s = PitSim.create({ seed:1, runS:40, cfg:{ npc:1, npcFallPerS:0, fallBase:0, fallTired:0 } }); s.me.a = 5; PitSim.place(s, 0, 0.01, 0.7); s.npcs[0].v = 0; s.me.v = 1.2;
PitSim.step(s, GAS);
check('bousculade après plusieurs tours : le coureur devant est poussé en avant', s.npcs[0].a > 0.01);
s = fresh({ runS:4, bpm:null }); check('tempo arrivé avant le premier battement : pris en compte', PitSim.setBpm(s, 120) === true && s.bpm === 120);
s = fresh({ runS:4, bpm:null }); run(s, GAS, 1); const late = PitSim.setBpm(s, 120); run(s, GAS, 1);
check('tempo arrivé en cours de route : battements comptés à partir de là', late === true && s.beats - s.beatBase === 2 && PitSim.result(s).stats.rhythm === 1);

// ---------- Vue drone : projection ----------
const PitProj = require(ROOT + 'pit-proj.js');
const meP = { a:0.3, r:0.7 }; let cam = PitProj.camera(meP, 390, 664), pp = PitProj.project(cam, meP.a, meP.r);
check('projection : le joueur est en bas au centre', Math.abs(pp.x - 195) < 1e-6 && Math.abs(pp.y - 0.78 * 664) < 1 && Math.abs(pp.scale - 1) < 1e-6 && pp.visible);
pp = PitProj.project(cam, meP.a + 0.05, meP.r);
check('projection : un coureur devant est plus haut et plus petit', pp.y < 0.78 * 664 && pp.scale < 1 && pp.visible);
check('projection : le bord à droite, le milieu à gauche', PitProj.project(cam, meP.a, 0.97).x > 195 && PitProj.project(cam, meP.a, 0.3).x < 195);
check('projection : derrière la caméra, invisible', PitProj.project(cam, meP.a - 0.08, meP.r).visible === false);
cam = PitProj.camera(meP, 430, 932); pp = PitProj.project(cam, meP.a, meP.r);
check('projection : changement de taille d\'écran', Math.abs(pp.x - 215) < 1e-6 && Math.abs(pp.y - 0.78 * 932) < 1);

// ---------- Vue drone : corps et poses ----------
const PitBodies = require(ROOT + 'pit-bodies.js');
const lk1 = PitBodies.looks(7, 40), lk2 = PitBodies.looks(7, 40);
check('allures : même graine, mêmes allures ; variété', JSON.stringify(lk1) === JSON.stringify(lk2) && lk1.length === 40
  && new Set(lk1.map(l => l.build)).size >= 5 && new Set(lk1.map(l => l.hair)).size >= 6);
const r0 = PitBodies.pose('run', 0), r5 = PitBodies.pose('run', 0.5);
check('course : les pieds alternent', r0.lFoot[1] > r0.rFoot[1] && r5.rFoot[1] > r5.lFoot[1]);
const dn = PitBodies.pose('down', 0);
check('à terre : tout près du sol', Object.keys(dn).every(k => dn[k][1] < 0.25));
const lf = PitBodies.pose('lift', 0.5), ch = PitBodies.pose('cheer', 0.3);
check('relever : une main tendue vers l\'avant et vers le bas', lf.rHand[1] < lf.hip[1] && Math.abs(lf.rHand[0] - lf.hip[0]) > 0.15);
check('bras levés : les deux mains au-dessus de la tête', ch.lHand[1] > ch.head[1] && ch.rHand[1] > ch.head[1]);

// ---------- Vue drone : photos ----------
const PitPhoto = require(ROOT + 'pit-photo.js');
const px = new Uint8ClampedArray([0,0,0,255, 255,255,255,255, 128,128,128,255]); PitPhoto.duotone(px);
const inRange = (v, a, b) => v >= Math.min(a, b) && v <= Math.max(a, b);
check('bichromie : noir → encre, blanc → or, gris entre les deux', px[0] === 0x0d && px[1] === 0x0a && px[2] === 0x08 && px[4] === 0xf4 && px[5] === 0xb2 && px[6] === 0x43
  && inRange(px[8], 0x0d, 0xf4) && inRange(px[9], 0x0a, 0xb2) && inRange(px[10], 0x08, 0x43) && px[11] === 255);
// ---------- Vue drone : lumières ----------
const PitLight = require(ROOT + 'pit-light.js');
const bm0 = PitLight.beams(0, { beatT:null, flashT:null, reduce:false }), bm2 = PitLight.beams(2000, { beatT:null, flashT:null, reduce:false });
check('lumières : 3 faisceaux, rouge et or', bm0.length === 3 && bm0.filter(b => b.color === 0xb23a3a).length === 2 && bm0.filter(b => b.color === 0xeb9a26).length === 1);
check('lumières : ils balaient', bm0.some((b, i) => Math.abs(b.angle - bm2[i].angle) > 0.05));
const sumI = l => l.reduce((a, b) => a + b.intensity, 0);
check('lumières : pulsation juste après un battement', sumI(PitLight.beams(1000, { beatT:0, flashT:null, reduce:false })) > sumI(PitLight.beams(1000, { beatT:400, flashT:null, reduce:false })));
check('lumières : sans tempo, intensité stable', Math.abs(sumI(PitLight.beams(1000, { beatT:null, flashT:null, reduce:false })) - sumI(PitLight.beams(1300, { beatT:null, flashT:null, reduce:false }))) < 1e-9);
const rq = { beatT:null, flashT:null, reduce:true }, rqF = { beatT:null, flashT:0, reduce:true };
const dFast = Math.abs(PitLight.beams(500, { beatT:null, flashT:null, reduce:false })[0].angle - bm0[0].angle), dSlow = Math.abs(PitLight.beams(500, rq)[0].angle - PitLight.beams(0, rq)[0].angle);
check('mouvement réduit : pas de flash, balayage 4 fois plus lent', Math.abs(sumI(PitLight.beams(800, rq)) - sumI(PitLight.beams(800, rqF))) < 1e-9 && Math.abs(dFast / dSlow - 4) < 0.05);

// ---------- Jouabilité : voies et relève ----------
s = fresh(); run(s, { throttle:.5, lateral:.3, tap:false }, 2); const rLane = s.me.r; run(s, { throttle:.5, lateral:0, tap:false }, 2);
check('voies : pouce recentré → retour sur la piste', rLane > 0.75 && Math.abs(s.me.r - 0.7) < 0.01 && s.me.zone === 'track');
s = fresh(); run(s, { throttle:.5, lateral:1, tap:false }, 3);
check('voies : pouce à droite → on reste au bord', s.me.zone === 'edge' && Math.abs(s.me.r - 0.96) < 0.01);
s = fresh(); PitSim.knockDown(s); ev = run(s, { throttle:1, lateral:0, tap:false }, 0.5);
check('relève : pouce resté en haut depuis la chute ne relève pas', !has(ev, 'up'));
s = fresh(); PitSim.knockDown(s); run(s, { throttle:.1, lateral:0, tap:false }, .05); ev = run(s, { throttle:.8, lateral:0, tap:false }, .2);
check('relève : poussée franche vers le haut → debout', has(ev, 'up') && s.t < 400 && s.me.v > 0.3);
s = fresh(); PitSim.knockDown(s); run(s, IDLE, .75);
check('relève : progression visible (moitié du temps → 0,5)', Math.abs(s.me.upProgress - 0.5) < 0.02);

// ---------- Relecture vue drone ----------
s = fresh({ friends:[{ id:'f9', name:'Pote' }] }); s.me.r = 0.96; s.me.v = 1.2; s.me.a = 0; s.friends[0].a = 0.42; s.friends[0].r = 0.97;
ev = run(s, { throttle:0, lateral:null, tap:false }, 3);
check('attirer un pote en jeu : au bord, on lâche le pouce un peu avant lui → pull', ev.some(e => e.type === 'pull') && s.me.zone === 'edge');
s = fresh({ friends:[{ id:'f9', name:'Pote' }] }); s.me.r = 0.96; s.me.v = 1.2; s.me.a = 0; s.friends[0].a = 0.1;
check('attirer un pote : en passant à pleine vitesse, rien', !run(s, { throttle:1, lateral:1, tap:false }, 0.5).some(e => e.type === 'pull'));
// cuisson : seulement les poses demandées
let gen = 0; const chain = () => new Proxy(function(){}, { get: (t, k) => k === 'destroy' ? () => {} : () => chain(), apply: () => chain() });
const FAKE = { Container: function(){ this.addChild = () => {}; this.destroy = () => {}; }, Graphics: function(){ return chain(); }, Sprite: function(){ this.anchor = { set(){} }; this.position = { set(){} }; } };
const fakeApp = { renderer: { generateTexture: () => { gen++; return {}; } } };
const bk = PitBodies.bake(FAKE, fakeApp, PitBodies.looks(1, 1)[0], { front:true, only:['stand', 'cheer'] });
check('cuisson : seulement les poses demandées (debout 1 + bras levés 2)', gen === 3 && bk.stand.length === 1 && bk.cheer.length === 2 && !bk.run);
const sd = PitBodies.pose('stand', 0);
check('debout : droit, pas accroupi', Math.abs(sd.head[1] - 0.92) < 1e-9 && sd.lFoot[1] === 0);

(async () => {
  check('photo : adresse vide → null sans erreur', await PitPhoto.load(null, 'palette', 64) === null);
  PitPhoto._img = () => { const im = {}; setTimeout(() => im.onerror && im.onerror(new Error('403')), 5); return im; };
  check('photo : chargement en échec → null', await PitPhoto.load('https://x/y.jpg', 'palette', 64) === null);
  console.log(fails ? fails + ' échec(s)' : 'tous OK'); process.exit(fails ? 1 : 0);
})();
