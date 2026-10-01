// Tests automatiques du prototype (jsdom). Installer une fois : npm --prefix tools install ; lancer : node tools/test_proto.js
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
async function placeAll(doc, st) {
  doc.getElementById('tray-all').click();
  for (let t = 0; t < 400 && ((st().toPlace || []).length || !doc.getElementById('dupfx').hidden); t++) {
    await sleep(100); const fx = doc.getElementById('dupfx'); if (!fx.hidden && !fx.classList.contains('out')) fx.click();
  }
  await sleep(300);
}
async function openB(doc, k) {
  for (const chip of doc.querySelectorAll('#binder-kinds button')) { chip.click(); await sleep(15);
    const c = doc.querySelector('#binder-list [data-b="' + k + '"]'); if (c) { c.click(); await sleep(20); return; } }
}
async function binderKeys(doc) { const keys = []; for (const chip of doc.querySelectorAll('#binder-kinds button')) { chip.click(); await sleep(15);
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
  // une Légendaire dans le paquet allonge l'ouverture : on attend l'écran de révélation (8 s au plus)
  for (let t = 0; t < 80 && d.getElementById('reveal').hidden; t++) await sleep(100);
  await sleep(800);
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
    // une Légendaire se retourne plus lentement : on attend la face visible (6 s au plus)
    for (let t = 0; t < 60 && !d.getElementById('card-info').classList.contains('on'); t++) await sleep(100);
    await sleep(300);
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
  check('fin du paquet : « Ranger dans le classeur » affiché, sans écran de résumé', !d.getElementById('to-binder').hidden && !d.getElementById('share').hidden && !d.getElementById('summary'));
  { const first = d.querySelector('#deck i[data-i="0"]'); first.click(); await sleep(50);
    check('rangée du bas : une carte déjà vue se réaffiche', d.getElementById('counter').textContent === 'Carte 1 / 5' && d.getElementById('flip').classList.contains('on')); }
  check('aucune transparence sur la carte', !/opacity/.test(d.getElementById('stage').getAttribute('style') || ''));

  // 3. Ranger : les cartes nouvelles attendent dans le bac, puis rejoignent leur emplacement
  d.getElementById('to-binder').click();
  await sleep(100);
  const nNew = (state().toPlace || []).length;
  check('bac « À ranger » affiché avec les nouvelles cartes', !d.getElementById('tray').hidden && d.querySelectorAll('#tray-cards button').length === nNew && nNew > 0, nNew + ' à ranger');
  check('classeur « Toutes les cartes » ouvert', /Toutes les cartes/.test(d.getElementById('binder-title').textContent));
  // une carte touchée dans le bac : rangement pas à pas, la carte en grand attend un toucher
  d.querySelector('#tray-cards button').click(); await sleep(700);
  check('rangement à l\'unité : la carte s\'affiche en grand et attend un toucher', !d.getElementById('dupfx').hidden && /Touche la carte/.test(d.getElementById('df-skip').textContent), d.getElementById('df-skip').textContent);
  await sleep(1500);
  check('rangement à l\'unité : rien ne part tout seul', !d.getElementById('dupfx').hidden);
  d.getElementById('dupfx').click(); await sleep(1400);
  // « Tout ranger d'un coup » : distribution automatique, sans écran par carte
  const left0 = (state().toPlace || []).length;
  d.getElementById('tray-all').click(); await sleep(400);
  check('tout ranger : distribution sans écran par carte', d.getElementById('dupfx').hidden);
  for (let t = 0; t < 100 && (state().toPlace || []).length; t++) await sleep(100);
  await sleep(300);
  check('tout ranger : ' + left0 + ' cartes distribuées en quelques secondes', (state().toPlace || []).length === 0);
  check('tout est rangé', (state().toPlace || []).length === 0 && d.getElementById('tray').hidden);
  const owned = state().owned;
  const ownedIds = new Set(Object.keys(owned).filter(k => owned[k] > 0).map(k => k.split('|')[0]));
  let shown = new Set();
  for (const k of await binderKeys(d)) { await openB(d, k);
    d.querySelectorAll('#grid .slot.owned').forEach(s => shown.add(s.getAttribute('data-id'))); }
  const extra = [...shown].filter(x => !ownedIds.has(x)), missing = [...ownedIds].filter(x => !shown.has(x));
  check('classeur = collection (aucun artiste en trop)', extra.length === 0 && missing.length === 0, 'en trop: ' + extra + ' / manquants: ' + missing);
  { const w2 = await binderCards(d); const own = state().owned;
    const slip = ['root','jordison','corey'].some(id => Object.keys(own).some(k => k.startsWith(id + '|') && own[k] > 0));
    check('classeur de groupe : nom caché tant qu\'aucune carte n\'est trouvée', slip ? /Slipknot/.test(w2) : !/Slipknot/.test(w2) && /Groupe mystère/.test(w2), w2); }
  // un grand classeur (les guitaristes) : il y reste toujours des cases vides après quelques paquets
  await openB(d, 'guitaristes');
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
  const fb = d2.querySelector('#detail .fzv.ready[data-from="commune"]');
  check('transformation proposée avec 3 doublons Commune (1er palier)', !!fb);
  if (fb) { fb.click(); await sleep(30); }
  check('transformer : on demande d\'abord (on peut garder ses doublons)', !d2.getElementById('confirm').hidden && /Garder mes doublons/.test(d2.getElementById('confirm-no').textContent) && JSON.parse(dom2.window.localStorage.getItem('metalnini-proto-v1')).owned['korn|commune'] > 1);
  d2.getElementById('confirm-yes').click(); await sleep(50);
  const st2 = JSON.parse(dom2.window.localStorage.getItem('metalnini-proto-v1')).owned;
  check('fusion : 1 Commune gardée + 1 Rare obtenue', st2['korn|commune'] === 1 && st2['korn|rare'] === 1, JSON.stringify(st2));
  check('fusion : reveal de la nouvelle carte', !d2.getElementById('reveal').hidden);
  { d2.getElementById('reveal').hidden = true; d2.querySelector('#grid .slot[data-id="korn"]').click(); await sleep(30);
    check('fiche : coup spécial affiché pour une carte possédée', /Coup spécial.*Cornemuse/.test(d2.getElementById('detail').textContent)); d2.getElementById('sheet-close').click(); await sleep(20); }

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
  const seen = []; new dom3.window.MutationObserver(ms => ms.forEach(m => m.addedNodes.forEach(n => { if (n.classList && (n.classList.contains('toast') || n.classList.contains('box'))) seen.push(n.textContent); }))).observe(d3.body, { childList: true, subtree: true });
  key(d3.getElementById('pack'), 'Enter'); await sleep(3200);
  d3.getElementById('skip').click(); await sleep(300);
  d3.getElementById('to-binder').click(); await sleep(100);
  await placeAll(d3, () => JSON.parse(dom3.window.localStorage.getItem('metalnini-proto-v1'))); await sleep(2600);
  const toastTxt = seen.join(' | ');
  check('complétion du classeur Blink-182 annoncée', /Classeur complété.*Blink-182/.test(toastTxt), toastTxt);
  check('tout ranger : bilan en grand à la fin', !d3.getElementById('deal-recap').hidden && /nouvelle/.test(d3.getElementById('recap-rows').textContent), d3.getElementById('recap-rows').textContent);
  d3.querySelector('.tabbar [data-v="binder"]').click(); await sleep(30);
  { d3.querySelector('#binder-kinds [data-kind="Groupes"]').click(); await sleep(20);
    const pc = d3.querySelector('#binder-list [data-b="g-blink"]');
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
  d4.getElementById('tab-corner').click(); await sleep(20);
  check('Metal Corner : objectifs listés ; déjà vus, ils ne font pas de pastille', !d4.getElementById('v-corner').hidden && d4.querySelectorAll('#quest-list .goal').length > 0 && d4.getElementById('quest-n').hidden, d4.getElementById('quest-list').textContent);
  d4.getElementById('tr-host').click(); await sleep(20);
  check('échange hors ligne : il faut un compte, rien ne s\'ouvre', d4.getElementById('trade').hidden && /Connecte-toi/.test((d4.querySelector('.toast') || {}).textContent || ''));
  d4.querySelector('#quest-list .goal').click(); await sleep(20);
  check('objectif touché : on arrive là où il se joue', !d4.getElementById('v-binder').hidden && d4.getElementById('v-corner').hidden);
  d4.getElementById('ask-artist').click(); await sleep(20);
  check('demande d\'artiste : feuille ouverte, hors ligne il faut un compte', !d4.getElementById('artist-sheet').hidden && d4.getElementById('as-send').disabled && /Connecte-toi/.test(d4.getElementById('as-err').textContent));
  d4.getElementById('as-cancel').click(); await sleep(20);
  check('demande d\'artiste : Annuler ferme la feuille', d4.getElementById('artist-sheet').hidden);
  key(d4.getElementById('pack'), 'Enter'); await sleep(3200);
  const got = Object.keys(JSON.parse(dom4.window.localStorage.getItem('metalnini-proto-v1')).owned).map(k => k.split('|')[0]);
  check('paquet Hardcore & metalcore : uniquement des cartes du classeur', got.every(id => ['knocked-loose','isaac-hale','spiritbox','jinjer','landmvrks','heriot','sykes'].includes(id)), got.join(','));
  d4.getElementById('skip').click(); await sleep(400);
  check('« Tout révéler » : partage et rangement proposés', !d4.getElementById('share').hidden && !d4.getElementById('to-binder').hidden);

  // 9. Doublons empilés, catégories sans « Collection », ouverture spéciale d'une Légendaire
  const s6 = { size:5, odds:{commune:0,rare:0,holo:0,signature:0,legendaire:100}, owned:{'korn|rare':3}, opened:0, fresh:{}, binder:'all', sound:false, pending:null, fuseBase:3, mastered:{}, completed:{}, packType:'serie', toPlace:[] };
  const dom5 = new JSDOM(html, { runScripts: 'dangerously', pretendToBeVisual: true, url: 'http://localhost/proto/', beforeParse(w5){
    w5.localStorage.setItem('metalnini-proto-v1', JSON.stringify(s6)); w5.matchMedia = () => ({ matches: false }); w5.scrollTo = () => {};
    w5.HTMLCanvasElement.prototype.getContext = () => new Proxy({}, { get: () => () => {} }); w5.HTMLElement.prototype.setPointerCapture = () => {}; w5.HTMLElement.prototype.scrollIntoView = () => {};
    w5.addEventListener('error', e => errors.push(e.message)); } });
  await sleep(150);
  const d5 = dom5.window.document;
  d5.querySelector('.tabbar [data-v="binder"]').click(); await sleep(30);
  d5.querySelector('#binder-kinds button').click(); await sleep(15);
  check('une seule collection : puce « Toutes » en premier, qui ouvre directement toutes les cartes', d5.querySelector('#binder-kinds button').textContent === 'Toutes' && !d5.getElementById('binder-page').hidden && /Toutes les cartes/.test(d5.getElementById('binder-title').textContent) && d5.getElementById('binder-back').hidden);
  await openB(d5, 'numetal');
  const kslot = d5.querySelector('#grid .slot[data-id="korn"]');
  check('doublons : 3 exemplaires = 2 cartes empilées derrière', kslot && kslot.querySelectorAll('.layers i').length === 2);
  d5.querySelector('.tabbar [data-v="packs"]').click(); await sleep(30);
  key(d5.getElementById('pack'), 'Enter'); await sleep(1400);
  check('paquet avec Légendaire : ouverture spéciale', d5.getElementById('pack').classList.contains('legend') && d5.getElementById('vignette').classList.contains('on'));
  check('paquet avec Légendaire : flammes gravées affichées', d5.getElementById('flames-pack').classList.contains('on'));
  await sleep(2600);
  check('puis la pile de cartes s\'ouvre', !d5.getElementById('reveal').hidden);

  // 10. Échange en ligne (faux serveur en mémoire) : code, pote qui rejoint, cartes posées, alerte du dernier exemplaire, double validation, révélation
  const s7 = { size:5, odds:{commune:60,rare:25,holo:10,signature:4,legendaire:1}, owned:{'korn|rare':1,'korn|commune':2}, opened:0, fresh:{}, binder:'all', sound:false, pending:null, fuseBase:3, mastered:{}, onbSeen:true, toPlace:[], shared:true };
  const dom6 = new JSDOM(html, { runScripts: 'dangerously', pretendToBeVisual: true, url: 'http://localhost/proto/', beforeParse(w6){
    w6.localStorage.setItem('metalnini-proto-v1', JSON.stringify(s7)); w6.HTMLMediaElement.prototype.play = () => Promise.resolve(); w6.matchMedia = () => ({ matches: false }); w6.scrollTo = () => {};
    w6.HTMLCanvasElement.prototype.getContext = () => new Proxy({}, { get: () => () => {} }); w6.HTMLElement.prototype.setPointerCapture = () => {}; w6.HTMLElement.prototype.scrollIntoView = () => {};
    w6.addEventListener('error', e => errors.push(e.message)); } });
  await sleep(150);
  const w6 = dom6.window, d6 = w6.document;
  let pals = [];
  let inv = [{musician_id:'korn', rarity:'rare', copies:1, placed:true}, {musician_id:'korn', rarity:'commune', copies:2, placed:true}], watchCb = null;
  const T = { id:'t1', code:'ABC234', partner_id:'u2', status:'open', version:0, host:true, partner:null, left:false, my_ok:false, their_ok:false, give:[], get:[], my_wants:[], their_wants:[], bonus:null };
  const snap = () => JSON.parse(JSON.stringify(T));
  const fake = { async user(){ return { id:'u1', user_metadata:{} }; }, async inventory(){ return inv; }, async username(){ return 'moi'; }, async fusionCosts(){ return {}; },
    async media(){ return {}; }, async power(){ return null; }, async packsLeft(){ return 1; }, async bonusPoints(){ return 0; }, async giftNotices(){ return []; },
    async tradeCount(){ return T.status === 'done' ? 1 : 0; }, async tradeActive(){ return null; }, async claims(){ return []; }, async tickets(){ return 0; }, async presence(){}, async cryQuiz(){ return []; }, async cryStatus(){ return null; }, async newCryBonus(){ return null; }, async tradeInvites(){ return []; }, async friends(){ return pals; }, async myTrades(){ return T.status === 'done' ? [{id:'t1', done_at:'2026-09-30T10:00:00Z', partner:'Riffeuse', gave:T.give, got:T.get}] : []; }, async follow(id){ pals = [{friend_id:id, username:'Riffeuse', trades:1, last_trade:'2026-09-30T10:00:00Z'}]; }, async mediaUrl(){ return 'data:audio/wav;base64,'; }, async claimObjective(k){ inv = inv.concat([{musician_id:'hetfield', rarity:'commune', copies:1, placed:false}]); return {kind:'card', m:'hetfield', r:'commune', new:true}; }, async tradeCreate(){ return snap(); }, async tradeState(){ return snap(); }, async tradeCancel(){},
    tradeWatch(id, cb){ watchCb = cb; return () => { watchCb = null; }; },
    async tradePartnerCards(){ return [{musician_id:'jinjer', rarity:'holo', copies:1}, {musician_id:'korn', rarity:'commune', copies:1}]; },
    async tradeWant(id, m, r, on){ T.my_wants = T.my_wants.filter(x => !(x.m === m && x.r === r)); if(on) T.my_wants.push({m, r}); return snap(); },
    async tradeSetItem(id, m, r, n){ T.give = T.give.filter(x => !(x.m === m && x.r === r)); if(n) T.give.push({m, r, n}); T.version++; T.my_ok = T.their_ok = false; return snap(); },
    async tradeConfirm(id, ok, v){ if(v !== T.version) throw new Error('changé'); T.my_ok = ok; if(T.my_ok && T.their_ok){ T.status = 'done'; T.bonus = {m:'spiritbox', r:'commune'};
      inv = [{musician_id:'korn', rarity:'commune', copies:2, placed:true}, {musician_id:'jinjer', rarity:'holo', copies:1, placed:false}, {musician_id:'spiritbox', rarity:'commune', copies:1, placed:false}]; } return snap(); } };
  await w6.metalniniOnline(fake); await sleep(100);
  d6.getElementById('tab-corner').click(); await sleep(20);
  check('objectif terminé : en tête de Metal Corner, pastille rouge sur l\'onglet', !!d6.querySelector('#quest-list .goal.claim') && d6.getElementById('quest-n').classList.contains('claim'));
  d6.querySelector('#quest-list .goal.claim').click(); await sleep(700);
  check('objectif touché : le coffre du butin s\'ouvre', !d6.getElementById('loot').hidden && /Objectif atteint/.test(d6.getElementById('loot-k').textContent));
  d6.getElementById('loot-go').click(); await sleep(50);
  check('objectif touché : la récompense se révèle, l\'objectif disparaît', !d6.getElementById('reveal').hidden && /Objectif atteint/.test(d6.getElementById('counter').textContent) && !d6.querySelector('#quest-list .goal.claim'));
  d6.getElementById('reveal').hidden = true;
  d6.getElementById('tr-host').click(); await sleep(50);
  check('échange : code affiché en attendant le pote', !d6.getElementById('trade').hidden && /ABC 234/.test(d6.getElementById('trade-in').textContent));
  Object.assign(T, { status:'live', partner:'Riffeuse', get:[{m:'jinjer', r:'holo', n:1}] }); watchCb(); await sleep(50);
  check('échange : le pote arrive, sa carte s\'affiche côté « Tu reçois »', /Riffeuse/.test(d6.getElementById('trade-in').textContent) && d6.querySelectorAll('#tr-get .tr-card').length === 1);
  const imgBefore = d6.querySelector('#tr-get .tr-card img'); T.their_ok = true; watchCb(); await sleep(50);
  check('mise à jour ciblée : le pote valide, sa carte n\'est pas recréée (rien ne saute)', d6.querySelector('#tr-get .tr-card img') === imgBefore && /Riffeuse a validé/.test(d6.getElementById('trade-in').textContent));
  T.their_ok = false; watchCb(); await sleep(50);
  d6.getElementById('trade-min').click(); await sleep(20);
  check('réduire : l\'échange reste ouvert, une pastille pour y revenir', d6.getElementById('trade').hidden && !d6.getElementById('trade-pill').hidden && /Riffeuse/.test(d6.getElementById('trade-pill').textContent));
  d6.querySelector('.tabbar [data-v="binder"]').click(); await sleep(20);
  T.their_ok = true; watchCb(); await sleep(50);
  check('réduit : la pastille suit l\'échange (le pote a validé)', /a validé/.test(d6.getElementById('trade-pill').textContent));
  T.their_ok = false; d6.getElementById('trade-pill').click(); await sleep(20);
  check('pastille touchée : retour dans l\'échange', !d6.getElementById('trade').hidden && d6.getElementById('trade-pill').hidden);
  d6.getElementById('trade-min').click(); d6.getElementById('tab-corner').click(); await sleep(20); d6.getElementById('tr-host').click(); await sleep(20);
  check('échange réduit : « Mon code » y revient au lieu d\'en ouvrir un autre', !d6.getElementById('trade').hidden && /Riffeuse/.test(d6.getElementById('trade-in').textContent));
  d6.getElementById('tr-add').click(); await sleep(20);
  check('doublons : le nombre d\'exemplaires reste visible sous la carte, même avec une étiquette', /×2/.test(d6.querySelector('#tp-body .tr-card[data-m="korn"][data-r="commune"] small').textContent));
  d6.getElementById('tp-dup').click(); await sleep(20);
  check('filtre « Doublons seulement »', d6.querySelectorAll('#tp-body .tr-card').length === 1 && d6.querySelector('#tp-body .tr-card').getAttribute('data-r') === 'commune');
  d6.getElementById('tp-dup').click(); await sleep(20);
  const lastKorn = d6.querySelector('#tp-body .tr-card[data-r="rare"]');
  check('choix des cartes : en tête, la rareté que le pote n\'a pas (Korn Rare avant la Commune qu\'il a)', (() => { const ks = [...d6.querySelectorAll('#tp-body .tr-card[data-m="korn"]')].map(b => b.getAttribute('data-r')); return ks[0] === 'rare' && ks[1] === 'commune'; })() && /Raretés que Riffeuse/.test(d6.getElementById('tp-body').textContent));
  lastKorn.click(); await sleep(50);
  check('carte posée : elle passe côté « Tu donnes »', d6.querySelectorAll('#tr-give .tr-card').length === 1 && T.version === 1);
  d6.querySelector('#tp-body .tr-card[data-r="commune"]').click(); await sleep(50); d6.querySelector('#tp-body .tr-card[data-r="commune"]').click(); await sleep(50);
  check('toutes les Korn posées : « Dernière » signalé sur la dernière', !!d6.querySelector('#tp-body .last') || d6.querySelectorAll('#tp-body .tr-card:disabled').length === 2);
  check('carte posée : marquée « Posée » avec un bouton − ; total dans le bouton', !!d6.querySelector('#tp-body .tp-item.on .tp-minus') && /2 posées|3 posées/.test(d6.getElementById('tp-ok').textContent));
  check('mon classeur : trié selon le classeur du pote', /Riffeuse les a déjà|Raretés que Riffeuse|Nouvelles pour Riffeuse/.test(d6.getElementById('tp-body').textContent));
  d6.querySelector('.tp-tabs [data-t="theirs"]').click(); await sleep(30);
  check('son classeur : celles qui me manquent en tête', /Nouvelles pour toi/.test(d6.getElementById('tp-body').textContent) && d6.querySelector('#tp-body .tr-card').getAttribute('data-m') === 'jinjer');
  d6.querySelector('#tp-body .tr-card[data-m="jinjer"]').click(); await sleep(50);
  check('demander une de ses cartes : étiquette « Demandée »', T.my_wants.length === 1 && /Demandée/.test(d6.querySelector('#tp-body .tr-card[data-m="jinjer"]').textContent));
  T.their_wants = [{m:'korn', r:'rare'}]; watchCb(); await sleep(50);
  d6.querySelector('.tp-tabs [data-t="mine"]').click(); await sleep(20);
  d6.getElementById('tp-ok').click(); d6.getElementById('tr-ok').click(); await sleep(30);
  check('valider en donnant son dernier exemplaire : alerte avant', !d6.getElementById('confirm').hidden && /dernier/i.test(d6.getElementById('confirm-t').textContent));
  d6.getElementById('confirm-no').click();
  d6.querySelector('#tr-give .tr-card[data-r="commune"]').click(); await sleep(50);
  T.their_ok = true; T.partner_cry = 'u2/cry.webm'; watchCb(); await sleep(50);
  d6.getElementById('tr-ok').click(); await sleep(1500);
  check('double validation : écran de troc (je donne / je reçois, bonus de rencontre), pas de révélation', d6.getElementById('trade').hidden && !d6.getElementById('troc').hidden && d6.getElementById('reveal').hidden && /Riffeuse/.test(d6.getElementById('troc-t').textContent) && /Bonus rencontre/.test(d6.getElementById('troc-get').textContent));
  check('échange conclu : le cri du pote retentit', [...d6.querySelectorAll('.toast')].some(t => /Le cri de/.test(t.textContent)));
  check('troc : bouton « Suivre » le pote', !d6.getElementById('troc-follow').hidden && /Suivre Riffeuse/.test(d6.getElementById('troc-follow').textContent));
  d6.getElementById('troc-follow').click(); await sleep(50);
  d6.getElementById('troc-close').click(); d6.getElementById('tab-corner').click(); await sleep(80);
  check('Metal Corner : Riffeuse dans « Mes potes », l\'échange dans l\'historique', !d6.getElementById('friends-sec').hidden && /Riffeuse/.test(d6.getElementById('friends').textContent) && !d6.getElementById('history-sec').hidden);
  const st7 = JSON.parse(w6.localStorage.getItem('metalnini-proto-v1'));
  check('après l\'échange : cartes reçues à ranger, Korn Rare partie', st7.toPlace.includes('jinjer|holo') && st7.toPlace.includes('spiritbox|commune') && !st7.owned['korn|rare']);

  // 11. Onboarding : groupes favoris après les univers (facultatif, 5 au plus), gardés jusqu'au compte
  const dom7 = new JSDOM(html, { runScripts: 'dangerously', pretendToBeVisual: true, url: 'http://localhost/proto/', beforeParse(w7){
    w7.matchMedia = () => ({ matches: false }); w7.scrollTo = () => {};
    w7.HTMLCanvasElement.prototype.getContext = () => new Proxy({}, { get: () => () => {} }); w7.HTMLElement.prototype.setPointerCapture = () => {}; w7.HTMLElement.prototype.scrollIntoView = () => {};
    w7.addEventListener('error', e => errors.push(e.message)); } });
  await sleep(150);
  const w7 = dom7.window, d7 = w7.document; let asked = null;
  await w7.metalniniOnline({ async user(){ return null; }, async previewWelcome(st){ asked = st; return [{token:'tk', musician_id:'korn', rarity:'commune'}]; } }); await sleep(50);
  d7.getElementById('onb-go').click(); await sleep(20);
  d7.querySelector('.tile[data-s]:not([data-s=""])').click(); d7.getElementById('onb-pack').click(); await sleep(20);
  check('onboarding : écran des groupes favoris après les univers', !!d7.getElementById('fav-in'));
  ['Gojira', 'gojira', 'Ghost'].forEach(v => { d7.getElementById('fav-in').value = v; d7.getElementById('fav-form').dispatchEvent(new w7.Event('submit', { cancelable: true })); });
  check('groupes favoris : ajoutés en pastilles, sans doublon', d7.querySelectorAll('.fav-chip').length === 2);
  d7.getElementById('fav-in').value = 'Mastodon'; d7.getElementById('onb-pack').click(); await sleep(50);
  check('onboarding : étape du cri, avec l\'enregistreur du profil', !!d7.querySelector('#onb-cry .pf-cry #pf-rec') && /Pousse ton cri/.test(d7.getElementById('onb').textContent));
  d7.getElementById('onb-skip').click(); await sleep(50);
  check('cri passé : l\'enregistreur retourne dans le profil', !!d7.querySelector('#v-profile .pf-cry'));
  const st8 = JSON.parse(w7.localStorage.getItem('metalnini-proto-v1'));
  check('groupes favoris : gardés (même le dernier tapé), puis le paquet de bienvenue', st8.favBands.join() === 'Gojira,Ghost,Mastodon' && !st8.favSent && !!asked);

  // 12. Mise à jour : nouvelle version publiée → rechargement, mais jamais pendant une révélation
  const htmlV = html.replace("BUILD = '__BUILD__'", "BUILD = 'aaa1111'");
  const dom8 = new JSDOM(htmlV, { runScripts: 'dangerously', pretendToBeVisual: true, url: 'http://localhost/proto/?v=aaa1111', beforeParse(w8){
    w8.localStorage.setItem('metalnini-proto-v1', JSON.stringify({ onbSeen:true, owned:{}, toPlace:[] })); w8.matchMedia = () => ({ matches: false }); w8.scrollTo = () => {};
    w8.HTMLCanvasElement.prototype.getContext = () => new Proxy({}, { get: () => () => {} }); w8.HTMLElement.prototype.setPointerCapture = () => {}; w8.HTMLElement.prototype.scrollIntoView = () => {};
    w8.fetch = async u => /version\.json/.test(u) ? { ok: true, json: async () => ({ v: 'bbb2222' }) } : { ok: false, json: async () => null };
    w8.addEventListener('error', e => errors.push(e.message)); } });
  await sleep(150);
  const w8 = dom8.window, d8 = w8.document;
  check('mise à jour : ?v= retiré de l\'adresse au chargement', w8.location.search === '');
  d8.getElementById('auth').hidden = true; d8.getElementById('reveal').hidden = false;
  d8.dispatchEvent(new w8.Event('visibilitychange')); await sleep(100);
  check('mise à jour : attend la fin de la révélation', ![...d8.querySelectorAll('.toast')].some(t => /Nouvelle version/.test(t.textContent)));
  d8.getElementById('reveal').hidden = true; await sleep(3200);
  check('mise à jour : rechargement annoncé une fois au calme', [...d8.querySelectorAll('.toast')].some(t => /Nouvelle version/.test(t.textContent)));

  // 13. Blind test : débloqué par une maîtrise, 5 extraits, 4 choix, score puis récompense (une fois)
  const own9 = {}; ['commune','rare','holo','signature','legendaire'].forEach(r => own9['korn|' + r] = 1); ['jinjer','spiritbox','hendrix','slash','hayley'].forEach(id => own9[id + '|commune'] = 1);
  const dom9 = new JSDOM(html, { runScripts: 'dangerously', pretendToBeVisual: true, url: 'http://localhost/proto/', beforeParse(w9){
    w9.localStorage.setItem('metalnini-proto-v1', JSON.stringify({ onbSeen:true, owned:own9, toPlace:[], instAsk:{n:3,t:0} })); w9.matchMedia = () => ({ matches: false }); w9.scrollTo = () => {};
    w9.HTMLCanvasElement.prototype.getContext = () => new Proxy({}, { get: () => () => {} }); w9.HTMLElement.prototype.setPointerCapture = () => {}; w9.HTMLElement.prototype.scrollIntoView = () => {};
    w9.HTMLMediaElement.prototype.play = () => Promise.resolve(); w9.HTMLMediaElement.prototype.pause = () => {};
    w9.fetch = async () => ({ json: async () => ({ results: [{ previewUrl: 'data:audio/wav;base64,', trackName: 'Morceau', trackViewUrl: '#' }] }) });
    w9.addEventListener('error', e => errors.push(e.message)); } });
  await sleep(150);
  const w9 = dom9.window, d9 = w9.document; let played = null, guessed = null;
  const inv9 = Object.keys(own9).map(k => ({ musician_id:k.split('|')[0], rarity:k.split('|')[1], copies:1, placed:true }));
  const fake9 = new Proxy({ async user(){ return { id:'u1', user_metadata:{} }; }, async inventory(){ return inv9; }, async username(){ return 'moi'; }, async fusionCosts(){ return {}; },
    async media(){ return {}; }, async power(){ return null; }, async packsLeft(){ return 0; }, async bonusPoints(){ return 0; }, async giftNotices(){ return []; }, async claims(){ return ['mastery:korn']; },
    async claimBlindtest(m, sc){ played = {m, sc}; return { kind:'points', points:2 }; }, tradeWatch(){ return () => {}; },
    async cryQuiz(){ return guessed ? [] : [{ friend_id:'f1', cry_path:'f1/cri.webm', choices:[{id:'f2', name:'Bob'}, {id:'f1', name:'Riffeuse'}, {id:'f3', name:'Zed'}] }]; },
    async mediaUrl(){ return 'data:audio/wav;base64,'; }, async cryGuess(f, pick){ guessed = {f, pick}; return f === pick ? { correct:true, reward:{ kind:'points', points:2 } } : { correct:false }; } }, { get: (o, k) => k in o ? o[k] : async () => (k === 'tradeActive' ? null : k === 'tickets' ? 0 : []) });
  await w9.metalniniOnline(fake9); await sleep(100);
  d9.getElementById('tab-corner').click(); await sleep(30);
  check('blind test : débloqué par la maîtrise, dans le carrousel', [...d9.querySelectorAll('#quest-list .quizgo')].some(b => /Maîtrise de Jonathan Davis/.test(b.textContent)));
  [...d9.querySelectorAll('#quest-list .quizgo')].find(b => /Maîtrise de Jonathan Davis/.test(b.textContent)).click(); await sleep(150);
  check('blind test : extrait 1/5, 4 choix', !d9.getElementById('quiz').hidden && /Extrait 1/.test(d9.getElementById('quiz-in').textContent) && d9.querySelectorAll('.qz-opt').length === 4);
  for (let i = 0; i < 5; i++) { d9.querySelector('.qz-opt').click(); await sleep(10); d9.getElementById('qz-next').click(); await sleep(10); }
  check('blind test : score sur 5 à la fin', /\d \/ 5/.test(d9.getElementById('qz-t').textContent));
  d9.getElementById('qz-end').click(); await sleep(50);
  check('blind test : score envoyé une fois, écran fermé, plus proposé', played && played.m === 'korn' && played.sc >= 0 && d9.getElementById('quiz').hidden && ![...d9.querySelectorAll('#quest-list .quizgo')].some(b => /Maîtrise de Jonathan/.test(b.textContent)));
  // extrait du style : toucher un style lance son hymne ; il s'arrête quand on quitte les classeurs
  let styleSrc = null; const play9 = w9.HTMLMediaElement.prototype.play;
  w9.HTMLMediaElement.prototype.play = function(){ if (/^data:audio/.test(this.src)) styleSrc = this.src; return Promise.resolve(); };
  d9.querySelector('.tabbar [data-v="binder"]').click(); await sleep(30);
  await openB(d9, 'numetal'); await sleep(40);
  const sl9 = d9.getElementById('si-listen'), lp9 = () => sl9.querySelector('.lp');
  check('extrait du style : lancé au toucher du style, avec son lecteur', !sl9.hidden && sl9.getAttribute('data-id') === 'korn' && !!styleSrc && lp9() && lp9().getAttribute('aria-pressed') === 'true');
  d9.querySelector('.tabbar [data-v="packs"]').click(); await sleep(20);
  check('extrait du style : arrêté en quittant les classeurs', lp9() && lp9().getAttribute('aria-pressed') === 'false');
  w9.HTMLMediaElement.prototype.play = play9;
  d9.querySelector('.tabbar [data-v="packs"]').click(); d9.getElementById('tab-corner').click(); await sleep(80);
  const cryCard = [...d9.querySelectorAll('#quest-list .quizgo')].find(b => /Qui a poussé ce cri/.test(b.textContent));
  check('blind test des cris : proposé dans le carrousel', !!cryCard);
  if (cryCard) { cryCard.click(); await sleep(100); }
  const good = [...d9.querySelectorAll('.qz-opt')].find(b => /Riffeuse/.test(b.textContent)); if (good) { good.click(); await sleep(50); }
  check('cri démasqué : la réponse part au serveur, « Bien vu »', guessed && guessed.pick === 'f1' && /Bien vu/.test(d9.getElementById('quiz-in').textContent));
  d9.getElementById('qz-next').click(); await sleep(20);
  check('fin du blind test des cris : 1 / 1 et gains à récupérer', /1 \/ 1/.test(d9.getElementById('qz-t').textContent) && /Récupérer mes gains/.test(d9.getElementById('qz-end').textContent));
  d9.getElementById('qz-end').click(); await sleep(50);
  d9.querySelector('.tabbar [data-v="binder"]').click(); await sleep(30); await openB(d9, 'numetal');
  d9.querySelector('#grid .slot[data-id="korn"]').click(); await sleep(40);
  d9.getElementById('d-trade').click(); await sleep(40);
  check('échanger depuis une carte : feuille ouverte, la carte proposée', !d9.getElementById('trade-start').hidden && /Jonathan Davis/.test(d9.getElementById('ts-card').textContent));

  // 14. Concerts : « J'y étais » enregistre un concert (musicien du jeu reconnu), talon dans Metal Corner et sur le profil
  let added = null; const gigs9 = [];
  fake9.concerts = async () => gigs9.slice();
  fake9.addConcert = async c => { added = c; gigs9.unshift({ id:'g1', artist:c.artist, musician_id:c.musician, played_on:c.date, venue:c.venue, city:c.city, photo_path:null, photo_public:false }); return 'g1'; };
  d9.querySelector('.tabbar [data-v="packs"]').click(); d9.getElementById('tab-corner').click(); await sleep(60);
  check('concerts : bouton « J\'y étais » dans Metal Corner', !!d9.getElementById('gig-open'));
  d9.getElementById('gig-open').click(); await sleep(10);
  check('concerts : feuille ouverte, artistes du jeu proposés', !d9.getElementById('gig-sheet').hidden && d9.querySelectorAll('#gig-artists option').length > 10);
  d9.getElementById('gig-send').click(); await sleep(10);
  check('concerts : artiste et date exigés', /artiste/.test(d9.getElementById('gig-err').textContent) && !added);
  d9.getElementById('gig-artist').value = 'Korn'; d9.getElementById('gig-date').value = '2026-06-20'; d9.getElementById('gig-venue').value = 'Hellfest';
  d9.getElementById('gig-send').click(); await sleep(80);
  check('concerts : enregistré avec le musicien du jeu, talon affiché', added && added.musician === 'korn' && added.date === '2026-06-20' && d9.getElementById('gig-sheet').hidden && /Korn/.test(d9.querySelector('#gigs .talon').textContent));
  d9.getElementById('pf-pub-open').click(); await sleep(20);
  check('concerts : talon sur le profil public', /Les talons · 1 concert/.test(d9.getElementById('pub-in').textContent));
  d9.getElementById('pub-x').click();

  // 15. Défis de concert : talon passé à valider (carte bonus), défi choisi pour un concert du jour, puis bouton de preuve
  let claimedId = null, picked = null; const now9 = new Date();
  const iso9 = now9.getFullYear() + '-' + String(now9.getMonth() + 1).padStart(2, '0') + '-' + String(now9.getDate()).padStart(2, '0');
  fake9.claimConcert = async id => { claimedId = id; return null; };
  fake9.challenges = async () => [{ id:'c1', title:'Circle pit', hint:'Un tour complet.', proof:'video', points:3, band_only:false }, { id:'c2', title:'Slam en bande', proof:'video', points:5, band_only:true }];
  fake9.pickChallenge = async (c, ch) => { picked = ch; gigs9.find(g => g.id === c).concert_picks = [{ challenge_id:ch, picked_early:false, done_at:null, cancelled:false, concert_challenges:{ title:'Circle pit', points:3, proof:'video' } }]; };
  d9.querySelector('#gigs [data-act="claim"]').click(); await sleep(30);
  check('défis : talon passé validé', claimedId === 'g1');
  fake9.addConcert = async c => { gigs9.unshift({ id:'g2', artist:c.artist, musician_id:null, played_on:c.date, venue:null, city:null, photo_path:null, photo_public:false, claimed:false, concert_picks:[] }); return 'g2'; };
  d9.getElementById('gig-open').click(); await sleep(10);
  d9.getElementById('gig-artist').value = 'Gojira'; d9.getElementById('gig-date').value = iso9;
  d9.getElementById('gig-send').click(); await sleep(80);
  d9.querySelector('.tl-acts[data-id="g2"] [data-act="pick"]').click(); await sleep(30);
  check('défis : liste de l\'admin, sans les défis en bande', !d9.getElementById('df-sheet').hidden && d9.querySelectorAll('#df-list .df-opt').length === 1);
  d9.querySelector('#df-list .df-opt').click(); await sleep(80);
  const prove9 = d9.querySelector('.tl-acts[data-id="g2"] [data-act="prove"]');
  check('défis : choisi, puis bouton de preuve le jour du concert', picked === 'c1' && d9.getElementById('df-sheet').hidden && prove9 && /Filmer · Circle pit/.test(prove9.textContent));

  console.log(results.join('\n'));
  console.log(errors.length ? 'ERREURS JS : ' + errors.join(' ; ') : 'aucune erreur JS');
  process.exit(0);
})();
