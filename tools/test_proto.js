// Tests automatiques du prototype (jsdom). Lancer : npm i jsdom@24 (une fois), puis node tools/test_proto.js
// Banc de test du prototype : ouvre des paquets, retourne les cartes, vérifie le classeur.
const { JSDOM } = require('jsdom');
const fs = require('fs');
const ROOT = require('path').join(__dirname, '..', 'proto') + '/';
const manifest = fs.readFileSync(ROOT + 'cards/manifest.js', 'utf8').replace(/window.METALNINI_PACKS = .*/, 'window.METALNINI_PACKS = {"serie":0.58,"metalcore":0.58,"hardcore":0.58};');
const html = fs.readFileSync(ROOT + 'index.html', 'utf8')
  .replace('<script src="cards/manifest.js"></script>', '<script>' + manifest + '</script>');
const errors = [];
const dom = new JSDOM(html, {
  runScripts: 'dangerously', pretendToBeVisual: true, url: 'http://localhost/proto/',
  beforeParse(w) {
    w.matchMedia = () => ({ matches: false }); w.scrollTo = () => {};
    w.HTMLCanvasElement.prototype.getContext = () => new Proxy({}, { get: () => () => {} });
    w.HTMLElement.prototype.setPointerCapture = () => {}; w.HTMLElement.prototype.scrollIntoView = () => {};
    w.AudioContext = undefined; w.webkitAudioContext = undefined;
    w.addEventListener('error', e => errors.push(e.message));
  }
});
const w = dom.window, d = w.document;
const sleep = ms => new Promise(r => setTimeout(r, ms));
const key = (el, k) => el.dispatchEvent(new w.KeyboardEvent('keydown', { key: k, bubbles: true }));
function ptr(el, type, x) { const e = new w.Event(type, { bubbles: true }); e.clientX = x; e.clientY = 100; e.pointerId = 1; el.dispatchEvent(e); }
const state = () => JSON.parse(w.localStorage.getItem('metalnini-proto-v1'));
async function openB(doc, k) {
  if (k === 'all') { doc.querySelector('#binder-kinds [data-kind="Collection"]').click(); await sleep(20); return; }
  for (const chip of doc.querySelectorAll('#binder-kinds button')) { chip.click(); await sleep(15);
    const c = doc.querySelector('#binder-list [data-b="' + k + '"]'); if (c) { c.click(); await sleep(20); return; } }
}
async function binderKeys(doc) { const keys = ['all']; for (const chip of doc.querySelectorAll('#binder-kinds button')) { chip.click(); await sleep(15);
  doc.querySelectorAll('#binder-list [data-b]').forEach(c => keys.push(c.getAttribute('data-b'))); } return keys; }
async function binderCards(doc) { let t = ''; for (const chip of doc.querySelectorAll('#binder-kinds button')) { chip.click(); await sleep(15); t += ' | ' + doc.getElementById('binder-list').textContent; } return t; }

(async () => {
  await sleep(200);
  const results = [];
  const check = (name, ok, extra) => results.push((ok ? 'OK   ' : 'FAIL ') + name + (extra ? ' — ' + extra : ''));

  // 0. Déchirer à la souris : le sachet reste à plat pendant le geste
  const pk = d.getElementById('pack');
  pk.getBoundingClientRect = () => ({ left: 0, top: 0, width: 200, height: 340 });
  pk.style.transform = 'rotateY(20deg)';
  ptr(pk, 'pointerdown', 10);
  check('sachet figé à plat dès l\'appui', pk.style.transform === '');
  ptr(pk, 'pointermove', 60); ptr(pk, 'pointerup', 60); await sleep(700);
  check('déchirure abandonnée : le sachet revient', parseFloat(pk.style.getPropertyValue('--tear') || '0') < .05 && d.getElementById('reveal').hidden);
  // (le contenu tiré reste le même : abandonner ne relance pas le tirage)
  w.localStorage.setItem('metalnini-proto-v1', JSON.stringify(Object.assign(state(), { pending: null })));

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
    if (i === 0) {
      const o1 = new w.Event('deviceorientation'); o1.gamma = 0; o1.beta = 40; w.dispatchEvent(o1);
      const o2 = new w.Event('deviceorientation'); o2.gamma = 15; o2.beta = 40; w.dispatchEvent(o2);
      await sleep(60);
      const tf = d.getElementById('tilt').style.transform, ix = d.getElementById('pile').style.getPropertyValue('--ix');
      check('parallaxe : le téléphone penché incline la carte', /rotateY\(24deg/.test(tf) && ix.indexOf('-3.6') === 0, tf + ' / --ix ' + ix);
    }
    ptr(stage, 'pointerdown', 150); ptr(stage, 'pointermove', 280); ptr(stage, 'pointerup', 280);
    await sleep(500);
    if (i < 4) check('carte suivante ' + (i + 2) + ' : rien de dévoilé avant retournement', !d.getElementById('flip').classList.contains('on') && d.getElementById('ci-n').textContent === '' && d.getElementById('flip').style.transition !== '' ? true : (!d.getElementById('flip').classList.contains('on') && d.getElementById('ci-n').textContent === ''));
  }
  check('résumé affiché à la fin', !d.getElementById('summary').hidden);
  check('aucune transparence sur la carte', !/opacity/.test(d.getElementById('stage').getAttribute('style') || ''));

  // 3. Ranger : les cartes nouvelles attendent dans le bac, puis rejoignent leur emplacement
  d.getElementById('to-binder').click();
  await sleep(100);
  const nNew = (state().toPlace || []).length;
  check('bac « À ranger » affiché avec les nouvelles cartes', !d.getElementById('tray').hidden && d.querySelectorAll('#tray-cards button').length === nNew && nNew > 0, nNew + ' à ranger');
  check('classeur « Toutes les cartes » ouvert', /Toutes les cartes/.test(d.getElementById('binder-title').textContent));
  d.getElementById('tray-all').click();
  // un doublon passe par le bonus plein écran : on attend que le bac soit vide (30 s au plus)
  for (let t = 0; t < 300 && ((state().toPlace || []).length || !d.getElementById('tray').hidden); t++) await sleep(100);
  await sleep(300);
  check('tout est rangé', (state().toPlace || []).length === 0 && d.getElementById('tray').hidden);
  const owned = state().owned;
  const ownedIds = new Set(Object.keys(owned).filter(k => owned[k] > 0).map(k => k.split('|')[0]));
  let shown = new Set();
  for (const k of await binderKeys(d)) { await openB(d, k);
    d.querySelectorAll('#grid .slot.owned').forEach(s => shown.add(s.getAttribute('data-id'))); }
  const extra = [...shown].filter(x => !ownedIds.has(x)), missing = [...ownedIds].filter(x => !shown.has(x));
  check('classeur = collection (aucun artiste en trop)', extra.length === 0 && missing.length === 0, 'en trop: ' + extra + ' / manquants: ' + missing);
  { const w2 = await binderCards(d); const own = state().owned;
    const slip = ['root','jordison'].some(id => Object.keys(own).some(k => k.startsWith(id + '|') && own[k] > 0));
    check('classeur de groupe : nom caché tant qu\'aucune carte n\'est trouvée', slip ? /Slipknot/.test(w2) : !/Slipknot/.test(w2) && /Groupe mystère/.test(w2), w2); }
  // « Toutes les cartes » : il y reste toujours des cases vides après quelques paquets
  await openB(d, 'all');
  const emptyText = [...d.querySelectorAll('#grid .slot:not(.owned)')].map(s => s.textContent).join(' | ');
  const nums = [...d.querySelectorAll('#grid .slot .cap')].map(c => +(c.textContent.match(/^(\d+)/) || [])[1]);
  check('cases numérotées de 1 à N dans le classeur', nums.length > 0 && nums.every((n, i) => n === i + 1), nums.join(' '));
  check('case vide : numéro et instrument', /N° \d+/.test(d.querySelector('#grid .slot:not(.owned)').textContent));
  { const empty = d.querySelector('#grid .slot:not(.owned)'), c = empty.getAttribute('data-id'); empty.click(); await sleep(30);
    const txt = d.getElementById('detail').textContent;
    check('fiche d\'une carte non trouvée : aucun nom de musicien ni de groupe', !/Knocked|Slipknot|Korn|Gojira|Blink|Lorna|Heriot|Jinjer|Spiritbox|Landmvrks|Poppy|Hendrix|Rage|Guns|Chili|Slash|Garris|Davis|Barker|Hoppus|Frusciante|Root|Jordison|Ramos|Duplantier|Shmayluk|LaPlante|Salfati|Gough|Hale|Rocha/.test(txt), c + ' : ' + txt.slice(0, 80));
    d.getElementById('sheet-close').click(); await sleep(20); }
  check('emplacements vides sans nom de groupe', !/Knocked|Slipknot|Korn|Gojira|Blink|Lorna|Heriot|Jinjer|Spiritbox|Landmvrks|Poppy|Hendrix|Rage|Guns|Chili/.test(emptyText), emptyText.slice(0, 160));

  // 4. Vue par rareté : 5 colonnes, une rangée par musicien du classeur
  d.querySelector('#sort-sheet [data-mode="matrix"]').click(); await sleep(30);
  const m = d.getElementById('matrix');
  const rows = m.querySelectorAll('.who').length, cells = m.querySelectorAll('.cell').length;
  check('vue par rareté affichée', !m.hidden && d.getElementById('grid').hidden);
  check('grille rangées × 5 colonnes', rows > 0 && cells === rows * 5, rows + ' rangées, ' + cells + ' cases');
  const filled = m.querySelectorAll('.cell img').length, ownedHere = [...m.querySelectorAll('.cell')].filter(c => (state().owned[c.dataset.id + '|' + c.dataset.r] || 0) > 0).length;
  check('cases remplies = variantes possédées', filled === ownedHere, filled + ' / ' + ownedHere);
  d.querySelector('#sort-sheet [data-mode="pages"]').click(); await sleep(30);

  // 5. Fusion : 6 exemplaires d'une Commune -> 1 Rare, il en reste 1
  const s0 = state(); s0.owned = { 'korn|commune': 4 }; s0.mastered = {}; w.localStorage.setItem('metalnini-proto-v1', JSON.stringify(s0));
  dom.window.location.reload && 0;
  const dom2 = new JSDOM(html, { runScripts: 'dangerously', pretendToBeVisual: true, url: 'http://localhost/proto/', beforeParse(w2){
    w2.localStorage.setItem('metalnini-proto-v1', JSON.stringify(s0)); w2.matchMedia = () => ({ matches: false }); w2.scrollTo = () => {};
    w2.HTMLCanvasElement.prototype.getContext = () => new Proxy({}, { get: () => () => {} }); w2.HTMLElement.prototype.setPointerCapture = () => {}; w2.HTMLElement.prototype.scrollIntoView = () => {};
    w2.addEventListener('error', e => errors.push(e.message)); } });
  await sleep(150);
  const d2 = dom2.window.document;
  d2.querySelector('.tabbar [data-v="binder"]').click(); await sleep(30);
  await openB(d2, 'numetal');
  d2.querySelector('#grid .slot[data-id="korn"]').click(); await sleep(30);
  const fb = d2.querySelector('#detail .fuse button[data-from="commune"]');
  check('transformation proposée avec 3 doublons Commune (1er palier)', !!fb);
  if (fb) { fb.click(); await sleep(50); }
  const st2 = JSON.parse(dom2.window.localStorage.getItem('metalnini-proto-v1')).owned;
  check('fusion : 1 Commune gardée + 1 Rare obtenue', st2['korn|commune'] === 1 && st2['korn|rare'] === 1, JSON.stringify(st2));
  check('fusion : reveal de la nouvelle carte', !d2.getElementById('reveal').hidden);

  // 6. Remise à zéro depuis les Réglages, après confirmation
  d2.getElementById('reveal').hidden = true; d2.querySelector('.tabbar [data-v="packs"]').click();
  d2.getElementById('reset').click(); await sleep(20);
  check('remise à zéro : modale de confirmation', !d2.getElementById('confirm').hidden);
  d2.getElementById('confirm-yes').click(); await sleep(30);
  const st3 = JSON.parse(dom2.window.localStorage.getItem('metalnini-proto-v1'));
  check('remise à zéro : collection vide', Object.keys(st3.owned).length === 0 && st3.opened === 0);

  // 7. Complétion d'un classeur : Pop punk (2 musiciens) complété -> récompense annoncée
  const s4 = { size:5, odds:{commune:60,rare:25,holo:10,signature:4,legendaire:1}, owned:{'blink182|commune':1,'hoppus|commune':1}, opened:1, fresh:{}, binder:'poppunk', sound:false, pending:null, fuseBase:3, mastered:{}, completed:{} };
  const dom3 = new JSDOM(html, { runScripts: 'dangerously', pretendToBeVisual: true, url: 'http://localhost/proto/', beforeParse(w3){
    w3.localStorage.setItem('metalnini-proto-v1', JSON.stringify(s4)); w3.matchMedia = () => ({ matches: false }); w3.scrollTo = () => {};
    w3.HTMLCanvasElement.prototype.getContext = () => new Proxy({}, { get: () => () => {} }); w3.HTMLElement.prototype.setPointerCapture = () => {}; w3.HTMLElement.prototype.scrollIntoView = () => {};
    w3.addEventListener('error', e => errors.push(e.message)); } });
  await sleep(150);
  const d3 = dom3.window.document;
  const seen = []; new dom3.window.MutationObserver(ms => ms.forEach(m => m.addedNodes.forEach(n => { if (n.classList && n.classList.contains('toast')) seen.push(n.textContent); }))).observe(d3.body, { childList: true });
  key(d3.getElementById('pack'), 'Enter'); await sleep(3200);
  d3.getElementById('skip').click(); await sleep(300);
  d3.getElementById('to-binder').click(); await sleep(100);
  d3.getElementById('tray-all').click(); await sleep(6500);
  const toastTxt = seen.join(' | ');
  check('complétion du classeur Pop punk annoncée', /Classeur complété.*Pop punk/.test(toastTxt), toastTxt);
  d3.querySelector('.tabbar [data-v="binder"]').click(); await sleep(30);
  { d3.querySelector('#binder-kinds [data-kind="Styles"]').click(); await sleep(20);
    const pc = d3.querySelector('#binder-list [data-b="poppunk"]');
    check('carte du classeur complété marquée « Complet »', !!pc && /Complet/.test(pc.textContent), pc && pc.textContent); }

  // 8. Paquet thématique : ne tire que dans son classeur ; prochain objectif affiché
  const s5 = { size:5, odds:{commune:60,rare:25,holo:10,signature:4,legendaire:1}, owned:{'spiritbox|commune':1}, opened:0, fresh:{}, binder:'metalcore', sound:false, pending:null, fuseBase:3, mastered:{}, completed:{}, packType:'metalcore' };
  const dom4 = new JSDOM(html, { runScripts: 'dangerously', pretendToBeVisual: true, url: 'http://localhost/proto/', beforeParse(w4){
    w4.localStorage.setItem('metalnini-proto-v1', JSON.stringify(s5)); w4.matchMedia = () => ({ matches: false }); w4.scrollTo = () => {};
    w4.HTMLCanvasElement.prototype.getContext = () => new Proxy({}, { get: () => () => {} }); w4.HTMLElement.prototype.setPointerCapture = () => {}; w4.HTMLElement.prototype.scrollIntoView = () => {};
    w4.addEventListener('error', e => errors.push(e.message)); } });
  await sleep(150);
  const d4 = dom4.window.document;
  check('sélecteur : 3 paquets proposés', d4.querySelectorAll('#pack-picker button').length === 3);
  check('objectif affiché sur l\'écran paquets', !d4.getElementById('goal').hidden && /Prochain objectif/.test(d4.getElementById('goal').textContent), d4.getElementById('goal').textContent);
  key(d4.getElementById('pack'), 'Enter'); await sleep(3200);
  const got = Object.keys(JSON.parse(dom4.window.localStorage.getItem('metalnini-proto-v1')).owned).map(k => k.split('|')[0]);
  check('paquet Metalcore : uniquement des cartes Metalcore', got.every(id => ['spiritbox','jinjer','landmvrks','heriot'].includes(id)), got.join(','));
  d4.getElementById('skip').click(); await sleep(400);
  check('résumé : bouton partager', !!d4.getElementById('share'));

  // 9. Doublons empilés, onglet Toutes les cartes, ouverture spéciale d'une Légendaire
  const s6 = { size:5, odds:{commune:0,rare:0,holo:0,signature:0,legendaire:100}, owned:{'korn|rare':3}, opened:0, fresh:{}, binder:'all', sound:false, pending:null, fuseBase:3, mastered:{}, completed:{}, packType:'serie', toPlace:[] };
  const dom5 = new JSDOM(html, { runScripts: 'dangerously', pretendToBeVisual: true, url: 'http://localhost/proto/', beforeParse(w5){
    w5.localStorage.setItem('metalnini-proto-v1', JSON.stringify(s6)); w5.matchMedia = () => ({ matches: false }); w5.scrollTo = () => {};
    w5.HTMLCanvasElement.prototype.getContext = () => new Proxy({}, { get: () => () => {} }); w5.HTMLElement.prototype.setPointerCapture = () => {}; w5.HTMLElement.prototype.scrollIntoView = () => {};
    w5.addEventListener('error', e => errors.push(e.message)); } });
  await sleep(150);
  const d5 = dom5.window.document;
  d5.querySelector('.tabbar [data-v="binder"]').click(); await sleep(30);
  check('catégorie « Collection » en premier, qui ouvre toutes les cartes', d5.querySelector('#binder-kinds button').getAttribute('data-kind') === 'Collection' && /Toutes les cartes/.test(d5.getElementById('binder-title').textContent));
  const kslot = d5.querySelector('#grid .slot[data-id="korn"]');
  check('doublons : 3 exemplaires = 2 cartes empilées derrière', kslot && kslot.querySelectorAll('.layers i').length === 2);
  d5.querySelector('.tabbar [data-v="packs"]').click(); await sleep(30);
  key(d5.getElementById('pack'), 'Enter'); await sleep(1400);
  check('paquet avec Légendaire : ouverture spéciale', d5.getElementById('pack').classList.contains('legend') && d5.getElementById('vignette').classList.contains('on'));
  check('paquet avec Légendaire : flammes gravées affichées', d5.getElementById('flames-pack').classList.contains('on'));
  await sleep(2600);
  check('puis la pile de cartes s\'ouvre', !d5.getElementById('reveal').hidden);

  console.log(results.join('\n'));
  console.log(errors.length ? 'ERREURS JS : ' + errors.join(' ; ') : 'aucune erreur JS');
  process.exit(0);
})();
