// Tests automatiques du prototype (jsdom). Lancer : npm i jsdom@24 (une fois), puis node tools/test_proto.js
// Banc de test du prototype : ouvre des paquets, retourne les cartes, vérifie le classeur.
const { JSDOM } = require('jsdom');
const fs = require('fs');
const ROOT = require('path').join(__dirname, '..', 'proto') + '/';
const html = fs.readFileSync(ROOT + 'index.html', 'utf8')
  .replace('<script src="cards/manifest.js"></script>', '<script>' + fs.readFileSync(ROOT + 'cards/manifest.js', 'utf8') + '</script>');
const errors = [];
const dom = new JSDOM(html, {
  runScripts: 'dangerously', pretendToBeVisual: true, url: 'http://localhost/proto/',
  beforeParse(w) {
    w.matchMedia = () => ({ matches: false }); w.scrollTo = () => {};
    w.HTMLCanvasElement.prototype.getContext = () => new Proxy({}, { get: () => () => {} });
    w.HTMLElement.prototype.setPointerCapture = () => {};
    w.AudioContext = undefined; w.webkitAudioContext = undefined;
    w.addEventListener('error', e => errors.push(e.message));
  }
});
const w = dom.window, d = w.document;
const sleep = ms => new Promise(r => setTimeout(r, ms));
const key = (el, k) => el.dispatchEvent(new w.KeyboardEvent('keydown', { key: k, bubbles: true }));
function ptr(el, type, x) { const e = new w.Event(type, { bubbles: true }); e.clientX = x; e.clientY = 100; e.pointerId = 1; el.dispatchEvent(e); }
const state = () => JSON.parse(w.localStorage.getItem('metalnini-proto-v1'));

(async () => {
  await sleep(200);
  const results = [];
  const check = (name, ok, extra) => results.push((ok ? 'OK   ' : 'FAIL ') + name + (extra ? ' — ' + extra : ''));

  // 1. Ouvrir un paquet au clavier (toucher)
  key(d.getElementById('pack'), 'Enter');
  await sleep(3200);
  check('le reveal s\'ouvre après la déchirure', !d.getElementById('reveal').hidden);
  const st = state();
  check('5 cartes ajoutées à la collection', Object.values(st.owned).reduce((a, b) => a + b, 0) === 5, JSON.stringify(st.owned));
  check('rangée de 5 cartes sous la carte', d.querySelectorAll('#deck i').length === 5);
  check('pile : 4 cartes sous la carte du dessus', d.querySelectorAll('#unders .under').length === 4);

  // 2. Retourner par glissé puis passer par glissé, 5 fois
  const stage = d.getElementById('stage');
  stage.getBoundingClientRect = () => ({ left: 0, top: 0, width: 300, height: 450 });
  for (let i = 0; i < 5; i++) {
    ptr(stage, 'pointerdown', 10); ptr(stage, 'pointermove', 200); ptr(stage, 'pointerup', 200);
    check('pile avant la carte ' + (i + 1) + ' : ' + (4 - i) + ' dessous', d.querySelectorAll('#unders .under').length === 4 - i);
    await sleep(2400);
    check('carte ' + (i + 1) + ' retournée par glissé', d.getElementById('flip').classList.contains('on'));
    ptr(stage, 'pointerdown', 150); ptr(stage, 'pointermove', 280); ptr(stage, 'pointerup', 280);
    await sleep(500);
  }
  check('résumé affiché à la fin', !d.getElementById('summary').hidden);
  check('aucune transparence sur la carte', !/opacity/.test(d.getElementById('stage').getAttribute('style') || ''));

  // 3. Classeur : les emplacements remplis correspondent exactement à la collection
  d.getElementById('to-binder').click();
  await sleep(100);
  const owned = state().owned;
  const ownedIds = new Set(Object.keys(owned).filter(k => owned[k] > 0).map(k => k.split('|')[0]));
  let shown = new Set();
  for (const b of d.querySelectorAll('#binder-tabs button')) { b.click(); await sleep(20);
    d.querySelectorAll('#grid .slot.owned').forEach(s => shown.add(s.getAttribute('data-id'))); }
  const extra = [...shown].filter(x => !ownedIds.has(x)), missing = [...ownedIds].filter(x => !shown.has(x));
  check('classeur = collection (aucun artiste en trop)', extra.length === 0 && missing.length === 0, 'en trop: ' + extra + ' / manquants: ' + missing);
  const emptyText = [...d.querySelectorAll('#grid .slot:not(.owned)')].map(s => s.textContent).join(' | ');
  check('emplacements vides sans nom de groupe', !/Knocked|Slipknot|Korn|Gojira|Blink|Lorna|Heriot|Jinjer|Spiritbox|Landmvrks|Poppy|Hendrix|Rage|Guns|Chili/.test(emptyText), emptyText.slice(0, 160));

  // 4. Vue par rareté : 5 colonnes, une rangée par musicien du classeur
  d.querySelector('.view-toggle [data-mode="matrix"]').click(); await sleep(30);
  const m = d.getElementById('matrix');
  const rows = m.querySelectorAll('.who').length, cells = m.querySelectorAll('.cell').length;
  check('vue par rareté affichée', !m.hidden && d.getElementById('grid').hidden);
  check('grille rangées × 5 colonnes', rows > 0 && cells === rows * 5, rows + ' rangées, ' + cells + ' cases');
  const filled = m.querySelectorAll('.cell img').length, ownedHere = [...m.querySelectorAll('.cell')].filter(c => (state().owned[c.dataset.id + '|' + c.dataset.r] || 0) > 0).length;
  check('cases remplies = variantes possédées', filled === ownedHere, filled + ' / ' + ownedHere);
  d.querySelector('.view-toggle [data-mode="pages"]').click(); await sleep(30);

  // 5. Fusion : 6 exemplaires d'une Commune -> 1 Rare, il en reste 1
  const s0 = state(); s0.owned = { 'korn|commune': 6 }; s0.mastered = {}; w.localStorage.setItem('metalnini-proto-v1', JSON.stringify(s0));
  dom.window.location.reload && 0;
  const dom2 = new JSDOM(html, { runScripts: 'dangerously', pretendToBeVisual: true, url: 'http://localhost/proto/', beforeParse(w2){
    w2.localStorage.setItem('metalnini-proto-v1', JSON.stringify(s0)); w2.matchMedia = () => ({ matches: false }); w2.scrollTo = () => {};
    w2.HTMLCanvasElement.prototype.getContext = () => new Proxy({}, { get: () => () => {} }); w2.HTMLElement.prototype.setPointerCapture = () => {};
    w2.addEventListener('error', e => errors.push(e.message)); } });
  await sleep(150);
  const d2 = dom2.window.document;
  d2.querySelector('.tabbar [data-v="binder"]').click(); await sleep(30);
  d2.querySelector('#binder-tabs [data-b="numetal"]').click(); await sleep(30);
  d2.querySelector('#grid .slot[data-id="korn"]').click(); await sleep(30);
  const fb = d2.querySelector('#detail .fuse button[data-from="commune"]');
  check('bouton de fusion proposé avec 5 doublons', !!fb);
  if (fb) { fb.click(); await sleep(50); }
  const st2 = JSON.parse(dom2.window.localStorage.getItem('metalnini-proto-v1')).owned;
  check('fusion : 1 Commune gardée + 1 Rare obtenue', st2['korn|commune'] === 1 && st2['korn|rare'] === 1, JSON.stringify(st2));
  check('fusion : reveal de la nouvelle carte', !d2.getElementById('reveal').hidden);

  // 6. Remise à zéro en deux touches
  d2.getElementById('reveal').hidden = true; d2.querySelector('.tabbar [data-v="packs"]').click();
  const rq = d2.getElementById('reset-quick'); rq.click(); rq.click(); await sleep(30);
  const st3 = JSON.parse(dom2.window.localStorage.getItem('metalnini-proto-v1'));
  check('remise à zéro : collection vide', Object.keys(st3.owned).length === 0 && st3.opened === 0);

  // 7. Complétion d'un classeur : Pop punk (2 musiciens) complété -> récompense annoncée
  const s4 = { size:5, odds:{commune:60,rare:25,holo:10,signature:4,legendaire:1}, owned:{'blink182|commune':1,'hoppus|commune':1}, opened:1, fresh:{}, binder:'poppunk', sound:false, pending:null, fuse:5, mastered:{}, completed:{} };
  const dom3 = new JSDOM(html, { runScripts: 'dangerously', pretendToBeVisual: true, url: 'http://localhost/proto/', beforeParse(w3){
    w3.localStorage.setItem('metalnini-proto-v1', JSON.stringify(s4)); w3.matchMedia = () => ({ matches: false }); w3.scrollTo = () => {};
    w3.HTMLCanvasElement.prototype.getContext = () => new Proxy({}, { get: () => () => {} }); w3.HTMLElement.prototype.setPointerCapture = () => {};
    w3.addEventListener('error', e => errors.push(e.message)); } });
  await sleep(150);
  const d3 = dom3.window.document;
  key(d3.getElementById('pack'), 'Enter'); await sleep(3200);
  d3.getElementById('skip').click(); await sleep(600);
  const toastTxt = [...d3.querySelectorAll('.toast')].map(t => t.textContent).join(' | ');
  check('complétion du classeur Pop punk annoncée', /Classeur complété.*Pop punk/.test(toastTxt), toastTxt);
  d3.querySelector('.tabbar [data-v="binder"]').click(); await sleep(30);
  check('onglet du classeur complété marqué ✓', /Pop punk ✓/.test(d3.getElementById('binder-tabs').textContent));

  console.log(results.join('\n'));
  console.log(errors.length ? 'ERREURS JS : ' + errors.join(' ; ') : 'aucune erreur JS');
  process.exit(0);
})();
