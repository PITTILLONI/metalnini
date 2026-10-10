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
  check('carte secrète : aucun objectif ne la trahit', !/Céleste|Céline/.test(d4.getElementById('quest-list').textContent));
  d4.getElementById('tr-host').click(); await sleep(20);
  check('échange hors ligne : il faut un compte, rien ne s\'ouvre', d4.getElementById('trade').hidden && /Connecte-toi/.test((d4.querySelector('.toast') || {}).textContent || ''));
  d4.querySelector('#quest-list .goal').click(); await sleep(20);
  check('objectif touché : on arrive là où il se joue', !d4.getElementById('v-binder').hidden && d4.getElementById('v-corner').hidden);
  d4.getElementById('ask-artist').click(); await sleep(20);
  check('demande d\'artiste : feuille ouverte, hors ligne il faut un compte', !d4.getElementById('artist-sheet').hidden && d4.getElementById('as-send').disabled && /Connecte-toi/.test(d4.getElementById('as-err').textContent));
  d4.getElementById('as-cancel').click(); await sleep(20);
  check('demande d\'artiste : Annuler ferme la feuille', d4.getElementById('artist-sheet').hidden);
  d4.getElementById('pack').click(); await sleep(3200);   // clic sans pointeur (commande vocale) : ouvre comme un toucher
  const got = Object.keys(JSON.parse(dom4.window.localStorage.getItem('metalnini-proto-v1')).owned).map(k => k.split('|')[0]);
  check('paquet Hardcore & metalcore : uniquement des cartes du classeur', got.every(id => ['knocked-loose','isaac-hale','spiritbox','jinjer','landmvrks','heriot','sykes','sam-carter','brendan-murphy','mccall','heafy','yates','honeycutt'].includes(id)), got.join(','));
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
  check('carte secrète pas trouvée : pas de classeur Céleste', !d5.querySelector('#binder-kinds [data-kind="Céleste"]'));
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
    async media(){ return {}; }, async power(){ return null; }, async packsLeft(){ return 1; }, async bonusPoints(){ return 0; }, async giftNotices(){ return []; }, async requestNews(){ return []; },
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
  d6.getElementById('tr-host').click(); await sleep(20);
  check('« Mon QR » : on choisit d\'abord (troc, pote, bande)', !d6.getElementById('qr-sheet').hidden && d6.getElementById('trade').hidden && d6.querySelectorAll('#qr-sheet .qr-op').length === 3);
  d6.getElementById('qr-bande').click(); await sleep(20);
  check('« Mon QR » · bande : les concerts proposés, ou comment en ajouter un', d6.getElementById('qr-bands').textContent.length > 0);
  d6.getElementById('qr-troc').click(); await sleep(50);
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
  d6.getElementById('trade-min').click(); d6.getElementById('tab-corner').click(); await sleep(20); d6.getElementById('tr-host').click(); d6.getElementById('qr-troc').click(); await sleep(20);
  check('échange réduit : « Mon QR » · troc y revient au lieu d\'en ouvrir un autre', !d6.getElementById('trade').hidden && /Riffeuse/.test(d6.getElementById('trade-in').textContent));
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
  check('double validation : écran de troc (je donne / je reçois, bonus de rencontre), pas de révélation', d6.getElementById('trade').hidden && !d6.getElementById('troc').hidden && d6.getElementById('reveal').hidden && /Riffeuse/.test(d6.getElementById('troc-t').textContent) && /Bonus/.test(d6.getElementById('troc-get').textContent));
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
    async media(){ return {}; }, async power(){ return null; }, async packsLeft(){ return 0; }, async bonusPoints(){ return 0; }, async giftNotices(){ return []; }, async requestNews(){ return [{ artist:'Lofofora', outcome:'added', priority:true }]; }, async claims(){ return ['mastery:korn']; },
    async claimBlindtest(m, sc){ played = {m, sc}; return { kind:'points', points:2 }; }, tradeWatch(){ return () => {}; },
    async cryQuiz(){ return guessed ? [] : [{ friend_id:'f1', cry_path:'f1/cri.webm', choices:[{id:'f2', name:'Bob'}, {id:'f1', name:'Riffeuse'}, {id:'f3', name:'Zed'}] }]; },
    async mediaUrl(){ return 'data:audio/wav;base64,'; }, async cryGuess(f, pick){ guessed = {f, pick}; return f === pick ? { correct:true, reward:{ kind:'points', points:2 } } : { correct:false }; } }, { get: (o, k) => k in o ? o[k] : async () => (k === 'tradeActive' ? null : k === 'tickets' ? 0 : []) });
  await w9.metalniniOnline(fake9); await sleep(100);
  check('demande d\'artiste exaucée : message à l\'ouverture', /ticket prioritaire a payé.*Lofofora/.test((d9.querySelector('.toast') || {}).textContent || ''));
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

  // 14. Concerts : « J'y étais, j'y vais » enregistre un concert (musicien du jeu reconnu), talon dans Metal Corner et sur le profil
  let added = null; const gigs9 = [];
  fake9.concerts = async () => gigs9.slice();
  fake9.addConcert = async c => { added = c; gigs9.unshift({ id:'g1', artist:c.artist, musician_id:c.musician, played_on:c.date, venue:c.venue, city:c.city, photo_path:null, photo_public:false }); return 'g1'; };
  d9.querySelector('.tabbar [data-v="packs"]').click(); d9.getElementById('tab-corner').click(); await sleep(60);
  check('concerts : bouton « Ajouter un concert » dans Metal Corner', !!d9.getElementById('gig-open'));
  d9.getElementById('gig-open').click(); await sleep(10);
  check('concerts : feuille ouverte, artistes du jeu proposés', !d9.getElementById('gig-sheet').hidden && d9.querySelectorAll('#gig-artists option').length > 10);
  d9.getElementById('gig-send').click(); await sleep(10);
  check('concerts : artiste et date exigés', /artiste/.test(d9.getElementById('gig-err').textContent) && !added);
  d9.getElementById('gig-artist').value = 'Korn'; d9.getElementById('gig-date').value = '2026-06-20'; d9.getElementById('gig-venue').value = 'Hellfest';
  d9.getElementById('gig-send').click(); await sleep(80);
  check('concerts : enregistré avec le musicien du jeu, talon affiché', added && added.musician === 'korn' && added.date === '2026-06-20' && d9.getElementById('gig-sheet').hidden && /Korn/.test(d9.querySelector('#gigs .talon').textContent));
  d9.getElementById('pf-pub-open').click(); await sleep(20);
  check('concerts : talon sur le profil public', /Les talons · 1 concert/.test(d9.getElementById('pub-in').textContent));
  d9.querySelector('#pub-in [data-pg="0"]').click(); await sleep(30);
  check('concerts : sur le profil, le talon ouvre ses souvenirs partagés', !d9.getElementById('pubgig-sheet').hidden && !!d9.querySelector('#pubgig-in .talon'));
  d9.getElementById('pubgig-close').click();
  d9.getElementById('pub-x').click();

  // 15. Défis de concert : talon passé à valider (carte bonus), défi choisi pour un concert du jour, puis bouton de preuve
  let claimedId = null, picked = null; const now9 = new Date();
  const iso9 = now9.getFullYear() + '-' + String(now9.getMonth() + 1).padStart(2, '0') + '-' + String(now9.getDate()).padStart(2, '0');
  fake9.claimConcert = async id => { claimedId = id; return null; };
  fake9.challenges = async () => [{ id:'c1', title:'Circle pit', hint:'Un tour complet.', proof:'video', points:3, band_only:false }, { id:'c2', title:'Slam en bande', proof:'video', points:5, band_only:true }];
  fake9.pickChallenge = async (c, ch) => { picked = ch; gigs9.find(g => g.id === c).concert_picks = [{ challenge_id:ch, picked_early:false, done_at:null, cancelled:false, concert_challenges:{ title:'Circle pit', points:3, proof:'video' } }]; };
  d9.querySelector('#gigs [data-open="g1"]').click(); await sleep(30);
  check('concerts : la fiche du concert s\'ouvre (objectifs, souvenirs)', !d9.getElementById('gigd-sheet').hidden && /Tes objectifs/.test(d9.getElementById('gigd-in').textContent) && /Tes souvenirs/.test(d9.getElementById('gigd-in').textContent));
  d9.querySelector('#gigd-in [data-act="claim"]').click(); await sleep(30);
  d9.getElementById('gigd-close').click();
  check('défis : talon passé validé', claimedId === 'g1');
  fake9.addConcert = async c => { gigs9.unshift({ id:'g2', artist:c.artist, musician_id:null, played_on:c.date, venue:null, city:null, photo_path:null, photo_public:false, claimed:false, concert_picks:[] }); return 'g2'; };
  d9.getElementById('gig-open').click(); await sleep(10);
  d9.getElementById('gig-artist').value = 'Gojira'; d9.getElementById('gig-date').value = iso9;
  const gf9 = d9.getElementById('gig-file');
  Object.defineProperty(gf9, 'files', { configurable:true, value:[new w9.File(['%PDF-1.4'], 'billet.pdf', { type:'application/pdf' })] });
  gf9.onchange(); await sleep(30);
  check('billet : à l\'import, proposé à garder dans l\'app', !d9.getElementById('gig-keep-l').hidden && d9.getElementById('gig-keep').checked);
  let tkAdd = null; fake9.setTicket = async (c, blob, kind) => { tkAdd = { c, kind }; return 'u1/ticket-new.pdf'; };
  d9.getElementById('gig-send').click(); await sleep(80);
  check('billet : gardé à l\'enregistrement du concert', tkAdd && tkAdd.c === 'g2' && tkAdd.kind === 'pdf');
  d9.querySelector('#gigs [data-open="g2"]').click(); await sleep(30);
  check('concerts : concert du jour, ticket de vestiaire proposé', /Photographier mon ticket/.test(d9.getElementById('gigd-in').textContent));
  check('billet : proposé dans la fiche du concert', /Ajouter mon billet/.test(d9.getElementById('gigd-in').textContent));
  let tk9 = null, tkCleared = null;
  fake9.setTicket = async (c, blob, kind, old) => { tk9 = { c, kind, size:blob.size }; return 'u1/ticket-g2.pdf'; };
  fake9.clearTicket = async (c, path) => { tkCleared = path; };
  const tkIn = d9.getElementById('ticket-file');
  Object.defineProperty(tkIn, 'files', { configurable:true, value:[new w9.File(['%PDF-1.4'], 'billet.pdf', { type:'application/pdf' })] });
  tkIn.onchange(); await sleep(60);
  check('billet : PDF envoyé, puis affiché dans la fiche', tk9 && tk9.c === 'g2' && tk9.kind === 'pdf' && !!d9.querySelector('#gigd-in .tk-pdf') && !!d9.querySelector('#gigd-in [data-tk-del]'));
  d9.querySelector('#gigd-in [data-tk-del]').click(); await sleep(30); d9.getElementById('confirm-yes').click(); await sleep(30);
  check('billet : retiré', tkCleared === 'u1/ticket-g2.pdf' && /Ajouter mon billet/.test(d9.getElementById('gigd-in').textContent));
  d9.querySelector('.tl-acts[data-id="g2"] [data-act="pick"]').click(); await sleep(30);
  check('défis : liste de l\'admin, sans les défis en bande', !d9.getElementById('df-sheet').hidden && d9.querySelectorAll('#df-list .df-opt').length === 1);
  d9.querySelector('#df-list .df-opt').click(); await sleep(80);
  const prove9 = d9.querySelector('.tl-acts[data-id="g2"] [data-act="prove"]');
  check('défis : choisi, puis bouton de preuve le jour du concert', picked === 'c1' && d9.getElementById('df-sheet').hidden && prove9 && /Filmer · Circle pit/.test(prove9.textContent));

  // 16. Bandes : monter une bande depuis un talon (code, pote à inviter), rejoindre par lien
  let invited = null, joined = null;
  const band9 = { id:'b1', code:'ABC234', artist:'Gojira', played_on:iso9, members:[{ id:'u1', name:'moi', me:true, host:true, done:[] }] };
  fake9.bandCreate = async c => { gigs9.find(g => g.id === c).band_id = 'b1'; return band9; };
  fake9.bandState = async () => band9;
  fake9.friends = async () => [{ friend_id:'f1', username:'Riffeuse' }];
  fake9.bandInvite = async (b, f) => { invited = f; };
  fake9.bandJoin = async code => { joined = code; return { ...band9, members:[...band9.members, { id:'h2', name:'Bob', host:true, done:[] }] }; };
  d9.querySelector('.tl-acts[data-id="g2"] [data-act="band"]').click(); await sleep(60);
  check('bandes : bande montée, code affiché', !d9.getElementById('band-sheet').hidden && /ABC 234/.test(d9.getElementById('band-in').textContent));
  d9.querySelector('#band-in [data-f]').click(); await sleep(20);
  check('bandes : pote invité', invited === 'f1');
  // un membre de la bande qui n'est pas encore un pote : « + Pote » l'ajoute
  let befriended = null; fake9.bandAddFriend = async (b, f) => { befriended = b + '/' + f; return 'Zoé'; };
  band9.members.push({ id:'z3', name:'Zoé', done:[] }); d9.getElementById('band-close').click();
  d9.querySelector('.tl-acts[data-id="g2"] [data-act="band"]').click(); await sleep(60);
  check('bandes : « + Pote » seulement pour un membre qui n\'est pas pote', d9.querySelectorAll('#band-in [data-p]').length === 1);
  d9.querySelector('#band-in [data-p]').click(); await sleep(20);
  check('bandes : membre ajouté en pote', befriended === 'b1/z3' && !d9.querySelector('#band-in [data-p]') && /Pote/.test(d9.getElementById('band-in').textContent) && !!d9.querySelector('#band-in span.df svg'));
  band9.members.pop();
  d9.getElementById('band-close').click();
  d9.getElementById('band-open').click(); await sleep(10);
  d9.getElementById('band-code-in').value = 'https://x/proto/?bande=XYZ789';
  d9.getElementById('band-join').dispatchEvent(new w9.Event('submit', { cancelable:true })); await sleep(60);
  check('bandes : rejointe par lien ou code', joined === 'XYZ789' && d9.getElementById('band-sheet').hidden);

  // 17. Metal Corner en rubriques : 4 puces, une seule rubrique visible, choix gardé, l'anneau de rang ouvre Rang
  const ctOff = sel => d9.querySelector(sel).classList.contains('ct-off');
  [...d9.querySelectorAll('#corner-tabs button')].find(b => b.dataset.ctGo === 'fosse').click(); await sleep(10);
  check('Metal Corner : 4 rubriques, Fosse seule visible (slam et concerts)', d9.querySelectorAll('#corner-tabs button').length === 4 && !ctOff('#gigs-sec') && !ctOff('#slam-sec') && ctOff('#friends-sec') && ctOff('#prog-sec') && ctOff('#v-corner [data-ct="epreuves"]') && JSON.parse(w9.localStorage.getItem('metalnini-proto-v1')).cornerTab === 'fosse');
  d9.getElementById('corner-hud').click(); await sleep(10);
  check('Metal Corner : l\'anneau de rang ouvre la rubrique Rang', !ctOff('#prog-sec') && ctOff('#gigs-sec'));

  // 18. Slam : porter le slam d'un pote (atterrissage, récompense de porteur), puis plonger soi-même
  let launched = false, carried = null, sclaimed = null; const soon9 = new Date(Date.now() + 3600e3).toISOString();
  const feed9 = { mine:null, crowd:[{ id:'s1', name:'Riffeuse', goal:5, ends_at:soon9, count:4 }], carried:[], goal:5, window:120 };
  fake9.slamFeed = async () => JSON.parse(JSON.stringify(feed9));
  fake9.slamCarry = async id => { carried = id; feed9.crowd = []; feed9.carried = [{ id:'s1', name:'Riffeuse', goal:5, ends_at:soon9, count:5, landed:true, rewarded:true }]; return { count:5, goal:5, landed:true, rewarded:true }; };
  fake9.slamClaim = async id => { sclaimed = id; feed9.carried = []; return { kind:'points', points:2 }; };
  fake9.slamLaunch = async () => { launched = true; feed9.mine = { id:'m1', goal:5, ends_at:soon9, landed:false, claimed:false, crashed:false, carriers:[] }; return JSON.parse(JSON.stringify(feed9)); };
  d9.querySelector('.tabbar [data-v="packs"]').click(); d9.getElementById('tab-corner').click(); await sleep(80);
  [...d9.querySelectorAll('#corner-tabs button')].find(b => b.dataset.ctGo === 'fosse').click(); await sleep(10);
  check('slam : le slam d\'un pote à porter, pastille sur Fosse', !d9.getElementById('slam-sec').hidden && !!d9.querySelector('#slam [data-carry="s1"]') && +((d9.querySelector('[data-ct-go="fosse"] .ct-dot') || {}).textContent || 0) >= 1 && !!d9.getElementById('slam-go'));
  d9.querySelector('#slam [data-carry="s1"]').click(); await sleep(60);
  check('slam : porté jusqu\'à l\'atterrissage, récompense de porteur à récupérer', carried === 's1' && !!d9.querySelector('#slam [data-sclaim="s1"]'));
  d9.querySelector('#slam [data-sclaim="s1"]').click(); await sleep(80);
  check('slam : récompense de porteur récupérée', sclaimed === 's1' && !d9.querySelector('#slam [data-sclaim]'));
  // un slam que je porte et qui n'a pas encore atterri : « Renfort » relaie son lien
  feed9.carried = [{ id:'s2', name:'Bob', goal:5, ends_at:soon9, count:2, landed:false }];
  d9.querySelector('.tabbar [data-v="packs"]').click(); d9.getElementById('tab-corner').click(); await sleep(80);
  d9.querySelector('#slam [data-reinf="s2"]').click(); await sleep(20);
  check('slam : renfort, le lien du slam porté part', /\?slam=s2/.test((d9.querySelector('.toast') || {}).textContent || ''));
  feed9.carried = [];
  d9.getElementById('slam-go').click(); await sleep(60);
  check('slam : plongée lancée, compteur de porteurs', launched && /Tu planes/.test(d9.getElementById('slam').textContent) && d9.querySelectorAll('#slam .pit-crowd li').length === 5 && !!d9.querySelector('#slam .pit-rider.dive'));
  check('slam : « Appeler la foule » pendant le vol', !!d9.getElementById('slam-call'));

  // 18 bis. Circle pit : rejoindre celui d'un pote, faire sa course (3, 2, 1, repère qui tourne), score envoyé, fin du pit, points récupérés
  let pitStarted = 0, pitScore = null, pitClaimed = null; const pitEnd = new Date(Date.now() + 600e3).toISOString();
  const pitSt = { id:'p1', track:'morello', ends_at:pitEnd, over:false, host:false, host_name:'Riffeuse', in:true, rewarded:true, claimed:false, rps:.35, run_s:1,
    runners:[{ id:'f1', name:'Riffeuse', score:72, rps:.3 }, { id:'u1', name:'Moi', score:null, me:true }], tier:{ runners:1, aim:72, size:-1, aim_tier:1, size_label:null, aim_label:'Carré', points:0 } };
  const pitCopy = () => JSON.parse(JSON.stringify(pitSt));
  fake9.pitFeed = async () => ({ live:[{ id:'p1', name:'Riffeuse', track:'morello', ends_at:pitEnd, runners:1, in:false, ran:false }], done:[], opened_today:false, duration:900, run_s:20 });
  fake9.pitJoin = async () => pitCopy();
  fake9.pitRunStart = async () => { pitStarted++; pitSt.runners[1].rps = .35; return pitCopy(); };
  fake9.pitRunFinish = async (id, sc) => { pitScore = sc; pitSt.runners[1].score = sc; pitSt.tier = { runners:2, aim:40, size:0, aim_tier:0, size_label:'Petit cercle', aim_label:'Brouillon', points:1 }; return pitCopy(); };
  fake9.pitClaim = async id => { pitClaimed = id; return { points:1, tier:pitSt.tier, loot:null }; };
  d9.querySelector('.tabbar [data-v="packs"]').click(); d9.getElementById('tab-corner').click(); await sleep(80);
  check('circle pit : le pit d\'un pote à rejoindre, et « Ouvrir le pit »', !d9.getElementById('pit-sec').hidden && !!d9.querySelector('#pits [data-pit="p1"]') && !!d9.getElementById('pit-go'));
  d9.querySelector('#pits [data-pit="p1"]').click(); await sleep(60);
  check('circle pit : salle d\'attente, coureurs en cercle (pas encore couru en grisé), 15 minutes', !d9.getElementById('pit').hidden && d9.querySelectorAll('#pit-orbit .pit-slot').length === 2 && d9.querySelectorAll('#pit-orbit .pit-slot.wait').length === 1 && /^(9|10):\d\d$/.test(d9.getElementById('pit-clock').textContent) && /À toi/.test(d9.getElementById('pit-run').textContent) && /Démarrer/.test(d9.getElementById('pit-start').textContent));
  d9.getElementById('pit-start').click(); await sleep(60);
  check('circle pit : course lancée, décompte et repère', pitStarted === 1 && d9.getElementById('pit-count').textContent === '3' && !!d9.getElementById('pit-mark'));
  await sleep(3400);
  check('circle pit : score de précision envoyé, course faite, plus de bouton Démarrer', pitScore !== null && pitScore >= 0 && pitScore <= 100 && /ta course/.test(d9.getElementById('pit-run').textContent) && d9.getElementById('pit-run').classList.contains('off') && !d9.getElementById('pit-start'));
  pitSt.over = true; pitSt.ends_at = new Date(Date.now() - 1000).toISOString();
  d9.getElementById('pit-x').click(); await sleep(20); d9.querySelector('#pits [data-pit="p1"]').click(); await sleep(60);
  d9.getElementById('pit-claim').click(); await sleep(60);
  check('circle pit : fin, points récupérés, écran fermé', pitClaimed === 'p1' && d9.getElementById('pit').hidden);

  // 18 quater. Pogo : un pote à terre à relever, entrer en misant, danser, ramassage, mission récupérée
  let pogoJoined = 0, pogoRun = null, pogoLifted = null, pogoClaimed = 0, pogoMission = null; const pogoEnd = new Date(Date.now() + 500e3).toISOString();
  const pogoSt = { id:'g1', rarity:'commune', track:'morello', ends_at:pogoEnd, over:false, cancelled:false, host:false, host_name:'Riffeuse', heat:2, run_s:1, hits:4, min_players:3,
    in:false, can_lift:false, stake:null, result:null, won:[], claimed:false,
    players:[{ id:'f1', name:'Riffeuse', energy:12, fell:false, lifted:false, friend:true }, { id:'f2', name:'Bob', energy:3, fell:true, lifted:false, friend:true }, { id:'f3', name:'Moshzilla', energy:2, fell:true, lifted:false, friend:false }] };
  const pogoCopy = () => JSON.parse(JSON.stringify(pogoSt));
  const pogoMissions = [{ key:'week:2026-41', title:'Pogo de la semaine', hint:'Danse 3 pogos cette semaine', reward:'1 paquet', goal:3, n:1, weekly:true, claimed:false },
    { key:'first', title:'Premier pogo', hint:'Danse ta première manche de pogo', reward:'Une Commune pas encore trouvée', goal:1, n:1, weekly:false, claimed:false }];
  fake9.pogoFeed = async () => ({ live:[{ id:'g1', name:'Riffeuse', rarity:'commune', ends_at:pogoEnd, players:2, in:pogoSt.in, ran:false }], done:[], down:[{ pogo:'g1', id:'f2', name:'Bob', ends_at:pogoEnd }],
    limit_reached:false, missions:pogoMissions, duration:600, run_s:15 });
  fake9.pogoState = async () => pogoCopy();
  fake9.pogoJoin = async () => { pogoJoined++; pogoSt.in = true; pogoSt.stake = 'morello'; pogoSt.players.push({ id:'u1', name:'Moi', energy:null, fell:null, lifted:false, me:true, friend:false }); return pogoCopy(); };
  fake9.pogoRunStart = async () => pogoCopy();
  fake9.pogoRunFinish = async (id, e, f) => { pogoRun = { e, f }; pogoSt.players[3].energy = e; pogoSt.players[3].fell = f; pogoSt.can_lift = !f; return pogoCopy(); };
  fake9.pogoLift = async (id, u) => { pogoLifted = u; pogoSt.players[1].lifted = true; pogoSt.players[1].lifter = 'Moi'; return pogoCopy(); };
  fake9.pogoClaim = async () => { pogoClaimed++; return { result:'won', stake:{ m:'morello', r:'commune' }, won:[{ m:'morello', r:'commune', prime:true }], points:2, energy:5, fell:false, lifter:null }; };
  fake9.pogoMission = async k => { pogoMission = k; pogoMissions[1].claimed = true; return { kind:'points', points:2 }; };
  d9.querySelector('.tabbar [data-v="packs"]').click(); d9.getElementById('tab-corner').click(); await sleep(80);
  check('pogo : pote à terre, pogo ouvert, mission de la semaine', !d9.getElementById('pogo-sec').hidden && !!d9.querySelector('#pogos [data-lift="g1|f2"]') && !!d9.querySelector('#pogos [data-pogo="g1"]') && /Pogo de la semaine : 1\/3/.test(d9.getElementById('pogos').textContent));
  check('fosse : « En ce moment » réunit les gestes en attente (relever, entrer, courir)', !d9.getElementById('now-sec').hidden && !!d9.querySelector('#now [data-now-lift="g1|f2"]') && !!d9.querySelector('#now [data-now-pogo="g1"]'));
  check('danses : trois cartes illustrées, pastille sur le pogo', d9.querySelectorAll('#dance-row .dance-t').length === 3 && !!d9.querySelector('#dance-row [data-dance-go="pogo"] img[src="fosse/pogo.jpg"]') && !!d9.querySelector('#dance-row [data-dance-go="pogo"] .dance-n'));
  d9.querySelector('#dance-row [data-dance-go="pit"]').click(); await sleep(20);
  check('danses : la carte ouvre la salle du circle pit (illustration, pit seul visible)', !d9.getElementById('salle').hidden && /pit\.jpg$/.test(d9.getElementById('salle-img').src) && d9.getElementById('pit-sec').classList.contains('on') && !d9.getElementById('pogo-sec').classList.contains('on'));
  d9.getElementById('salle-x').click(); await sleep(20);
  check('danses : la salle se referme', d9.getElementById('salle').hidden);
  check('pogo : missions dans les épreuves (à ouvrir, puis en cours)', !d9.getElementById('pogo-quests-sec').hidden && !!d9.querySelector('#pogo-quests [data-pm="first"]') && /1\/3/.test(d9.getElementById('pogo-quests').textContent));
  d9.querySelector('#pogos [data-lift="g1|f2"]').click(); await sleep(60);
  check('pogo : relever un pote à terre', pogoLifted === 'f2');
  d9.querySelector('#pogos [data-pogo="g1"]').click(); await sleep(60);
  check('pogo : avant d\'entrer, les gains sont annoncés (prime, cartes en jeu)', /La prime/.test(d9.getElementById('pogo-in').textContent) && /cartes? en jeu/.test(d9.getElementById('pogo-in').textContent));
  check('pogo : avant d\'entrer, la mise est annoncée', !d9.getElementById('pogo').hidden && /miser une Commune/.test(d9.getElementById('pogo-join').textContent) && pogoJoined === 0);
  d9.getElementById('pogo-join').click(); await sleep(60);
  check('pogo : pas encore dansé, pas de bouton Relever', !d9.querySelector('#pogo-in [data-up]'));
  check('pogo : entré, carte dans la poche, bouton Danser', pogoJoined === 1 && /Dans ta poche/.test(d9.getElementById('pogo-in').textContent) && !!d9.getElementById('pogo-run'));
  let called9 = null; fake9.fosseCalled = async () => []; fake9.fosseCall = async (k, id, to) => { called9 = k + '|' + id + '|' + to; return true; };
  d9.getElementById('pogo-call').click(); await sleep(60);
  check('rameuter : la feuille liste les potes de l\'app, ceux déjà dans le pogo marqués « Déjà là »', !d9.getElementById('call-sheet').hidden && d9.querySelectorAll('#call-list .call-row').length === 1 && /Déjà là/.test(d9.getElementById('call-list').textContent) && !d9.querySelector('#call-list [data-call]'));
  d9.getElementById('call-close').click(); await sleep(20);
  d9.getElementById('pogo-run').click(); await sleep(60);
  check('pogo : manche lancée, arène et décompte', !!d9.getElementById('pogo-arena') && d9.getElementById('pogo-count').textContent === '3' && d9.querySelectorAll('#pogo-bal i').length === 4);
  await sleep(3700);
  check('pogo : resté debout, je peux relever le danseur à terre', !!d9.querySelector('#pogo-in [data-up="f3"]'));
  check('pogo : manche finie, énergie et chute envoyées', pogoRun && pogoRun.f === false && pogoRun.e >= 0 && /Debout jusqu'au bout/.test(d9.getElementById('pogo-in').textContent));
  pogoSt.over = true; pogoSt.ends_at = new Date(Date.now() - 1000).toISOString();
  d9.getElementById('pogo-x').click(); await sleep(20); d9.querySelector('#pogos [data-pogo="g1"]').click(); await sleep(60);
  d9.getElementById('pogo-claim').click(); await sleep(80);
  check('pogo : ramassage, mise rendue et prime remportée', pogoClaimed === 1 && /Tu remportes la prime/.test(d9.getElementById('pogo-in').textContent) && [].some.call(d9.querySelectorAll('.pogo-lc small'), function(x){ return x.textContent === 'La prime'; }) && d9.querySelectorAll('.pogo-loot .pogo-c').length === 2);
  d9.getElementById('pogo-done').click(); await sleep(20);
  d9.querySelector('#pogo-quests [data-pm="first"]').click(); await sleep(80);
  check('pogo : mission récupérée', pogoMission === 'first');
  d9.querySelectorAll('#loot button, .loot button').forEach(b => { if(/Plus tard|Fermer/.test(b.textContent)) b.click(); });

  // 18 ter. Tout ouvrir : de retour après plusieurs jours, 3 paquets ouverts en série, toutes les cartes d'un coup
  let bulkCalls = 0;
  fake9.packsLeft = async () => 6 - 2 * bulkCalls;
  fake9.openPack = async () => { bulkCalls++; return ['korn','jinjer','slash','hetfield','ozzy'].map((m, i) => ({ musician_id:m, rarity:i === 0 ? 'holo' : 'commune', is_new:i === 1 })); };
  fake9.purchaseNews = async () => [{ id:'x', offer:'pack3' }];
  d9.querySelector('.tabbar [data-v="packs"]').click(); w9.document.dispatchEvent(new w9.Event('visibilitychange')); await sleep(120);
  fake9.purchaseNews = async () => [];
  check('tout ouvrir : bouton visible avec 3 paquets', !d9.getElementById('bulk-go').hidden && /3 paquets/.test(d9.getElementById('bulk-go').textContent));
  d9.getElementById('bulk-go').click(); await sleep(200);
  check('tout ouvrir : 3 paquets tirés, 15 cartes d\'un coup, la plus rare en premier', bulkCalls === 3 && d9.querySelectorAll('#bulk-grid figure').length === 5 && /×3/.test(d9.getElementById('bulk-grid').textContent) && /Holo/.test(d9.querySelector('#bulk-grid img').alt) && /15 cartes/.test(d9.getElementById('bulk-t').textContent));
  d9.getElementById('bulk-close').click();
  fake9.packsLeft = async () => 0;

  // 19. Potes par code : mon code affiché, ajout par lien collé
  let addedCode = null;
  fake9.friendCode = async () => 'QWE789';
  fake9.addFriend = async c => { addedCode = c; return 'Bob'; };
  d9.getElementById('pote-open').click(); await sleep(30);
  check('potes : feuille ouverte, mon code affiché', !d9.getElementById('pote-sheet').hidden && /QWE 789/.test(d9.getElementById('pote-code').textContent));
  d9.getElementById('pote-in').value = 'https://x/proto/?pote=zxc456';
  d9.getElementById('pote-join').dispatchEvent(new w9.Event('submit', { cancelable:true })); await sleep(40);
  check('potes : ajouté par lien, feuille fermée', addedCode === 'ZXC456' && d9.getElementById('pote-sheet').hidden);

  // 20. Pastille du slam : hors de Metal Corner, le slam d'un pote se porte d'un toucher
  let carried2 = null;
  feed9.crowd = [{ id:'s3', name:'Doom', goal:5, ends_at:soon9, count:1 }];
  fake9.slamCarry = async id => { carried2 = id; feed9.crowd = []; return { count:2, goal:5, landed:false, rewarded:true }; };
  d9.getElementById('tab-corner').click(); await sleep(60);
  d9.querySelector('.tabbar [data-v="binder"]').click(); await sleep(20);
  const pill9 = d9.getElementById('slam-pill');
  check('slam : pastille hors de Metal Corner', !pill9.hidden && /Doom/.test(pill9.textContent) && /Porter/.test(pill9.textContent));
  pill9.click(); await sleep(60);
  check('slam : porté depuis la pastille, pastille retirée', carried2 === 's3' && pill9.hidden);

  // 22. « Porte-moi » : pendant mon slam, demander à un pote de me porter (une fois)
  let asked9 = null;
  feed9.mine = { id:'m1', goal:5, ends_at:soon9, landed:false, claimed:false, crashed:false, carriers:[], carrier_ids:[], asked_ids:[] };
  fake9.slamAsk = async f => { asked9 = f; };
  d9.getElementById('tab-corner').click(); await sleep(80);
  const ask9 = d9.querySelector('#friends [data-fa]');
  check('slam : « Porte-moi » sous les bulles des potes pendant le slam', !!ask9 && /Porte-moi/.test(ask9.textContent) && !!d9.querySelector('#friends .car-h [data-fp]'));
  ask9.click(); await sleep(40);
  check('slam : pote sollicité, « Demandé » sous sa bulle', asked9 === 'f1' && !d9.querySelector('#friends [data-fa]') && /Demandé/.test(d9.getElementById('friends').textContent));

  // 21. Lien de slam ouvert sans être connecté (navigateur) : explication, code de pote à taper dans l'app
  const dom10 = new JSDOM(html, { runScripts: 'dangerously', pretendToBeVisual: true, url: 'http://localhost/proto/?slam=0f8b8c2e-1d2a-4c5e-9f00-123456789abc&pote=qwe789', beforeParse(w){
    w.matchMedia = () => ({ matches: false }); w.scrollTo = () => {};
    w.HTMLCanvasElement.prototype.getContext = () => new Proxy({}, { get: () => () => {} }); w.HTMLElement.prototype.setPointerCapture = () => {}; w.HTMLElement.prototype.scrollIntoView = () => {};
    w.addEventListener('error', e => errors.push(e.message)); } });
  await sleep(150);
  const w10 = dom10.window, d10 = w10.document;
  await w10.metalniniOnline({ async user(){ return null; } }); await sleep(2200);
  check('lien hors de l\'app : explication et code de pote', !d10.getElementById('confirm').hidden && /QWE 789/.test(d10.getElementById('confirm-d').textContent) && /Me connecter/.test(d10.getElementById('confirm-yes').textContent));

  console.log(results.join('\n'));
  console.log(errors.length ? 'ERREURS JS : ' + errors.join(' ; ') : 'aucune erreur JS');
  process.exit(0);
})();
