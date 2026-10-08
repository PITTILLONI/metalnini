// Fausse API en ligne pour les captures (tools/capture/shot.mjs) : un joueur « Antoine » avec quelques cartes, Hendrix maîtrisé, un échange ouvert (__T).

window.__T = { id:'t1', code:'ABC234', status:'open', version:0, host:true, partner:null, left:false, my_ok:false, their_ok:false, give:[], get:[], my_wants:[], their_wants:[], bonus:null };
window.__fake = { async user(){ return { id:'u1', user_metadata:{} }; }, async inventory(){ return [{musician_id:'korn', rarity:'rare', copies:1, placed:true},{musician_id:'korn', rarity:'commune', copies:3, placed:true},{musician_id:'jinjer', rarity:'holo', copies:1, placed:true},{musician_id:'angus', rarity:'signature', copies:2, placed:true},{musician_id:'spiritbox', rarity:'commune', copies:1, placed:true},{musician_id:'hendrix', rarity:'commune', copies:1, placed:true},{musician_id:'hendrix', rarity:'rare', copies:1, placed:true},{musician_id:'hendrix', rarity:'holo', copies:1, placed:true},{musician_id:'hendrix', rarity:'signature', copies:1, placed:true},{musician_id:'hendrix', rarity:'legendaire', copies:1, placed:true}]; },
 async username(){ return 'Antoine'; }, async fusionCosts(){ return {}; }, async media(){ return {}; }, async power(){ return null; }, async packsLeft(){ return 1; }, async bonusPoints(){ return 0; }, async giftNotices(){ return []; }, async requestNews(){ return []; },
 async tradeCount(){ return 0; }, async tradeCreate(){ return JSON.parse(JSON.stringify(__T)); }, async tradeState(){ return JSON.parse(JSON.stringify(__T)); }, tradeWatch(id, cb){ window.__cb = cb; return ()=>{}; },
 async tradeActive(){ return null; }, async claims(){ return []; }, async claimObjective(){ return {kind:'points', points:2}; },
 async tradePartnerCards(){ return []; }, async tradeWant(){ return JSON.parse(JSON.stringify(__T)); } };
__fake.tickets = async function(){ return 1; };
__fake.tradeConfirm = async function(){ __T.status = 'done'; __T.bonus = {m:'hetfield', r:'commune'}; return JSON.parse(JSON.stringify(__T)); };
__fake.tradeInvites = async function(){ return []; }; __fake.friends = async function(){ return []; }; __fake.myTrades = async function(){ return []; }; __fake.mediaUrl = async function(){ return null; };
__fake.presence = async function(){};
__fake.claimBlindtest = async function(){ return {kind:'points', points:2}; };
// concerts : deux talons (un passé avec photo, un à venir), ajout en mémoire
(function(){ var d = new Date(), t = d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
window.__gigs = [{id:'g3', artist:'Spiritbox', musician_id:'spiritbox', played_on:t, venue:'Zénith', city:'Paris', photo_path:null, photo_public:false, claimed:false,
    concert_picks:[{challenge_id:'c4', picked_early:true, done_at:null, cancelled:false, concert_challenges:{title:'Circle pit', points:3, proof:'video'}},
      {challenge_id:'c1', picked_early:true, done_at:t, cancelled:false, concert_challenges:{title:'Photo du pit', points:2, proof:'photo'}}]},
  {id:'g1', artist:'Gojira', musician_id:null, played_on:'2026-06-21', venue:'Hellfest', city:'Clisson', photo_path:'u1/concert-1.jpg', photo_public:true, claimed:true,
    concert_picks:[{challenge_id:'c5', picked_early:false, done_at:'2026-06-21', cancelled:false, concert_challenges:{title:'Slam', points:4, proof:'video'}}]},
  {id:'g2', artist:'Lorna Shore', musician_id:'ramos', played_on:'2027-02-14', venue:'Olympia', city:'Paris', photo_path:null, photo_public:false, claimed:false, concert_picks:[]}]; })();
__fake.challenges = async function(){ return [{id:'c1', title:'Photo du pit', hint:'Le pit vu de l\'intérieur, en plein morceau.', proof:'photo', points:2}, {id:'c2', title:'Crie son nom', hint:'Hurle le nom de l\'artiste entre deux morceaux.', proof:'video', points:2},
  {id:'c3', title:'Headbanging', hint:'Dix secondes de nuque en roue libre.', proof:'video', points:2}, {id:'c4', title:'Circle pit', hint:'Un tour complet dans le cercle.', proof:'video', points:3}, {id:'c5', title:'Slam', hint:'Porté par la foule, en respectant la sécurité de la salle.', proof:'video', points:4}]; };
__fake.concerts = async function(){ return __gigs.slice(); };
__fake.addConcert = async function(c){ var id = 'g' + (__gigs.length + 1); __gigs.unshift({id:id, artist:c.artist, musician_id:c.musician, played_on:c.date, venue:c.venue, city:c.city, photo_path:null, photo_public:false}); return id; };
__fake.concertPhoto = async function(){ return 'u1/p.jpg'; }; __fake.deleteConcert = async function(id){ __gigs = __gigs.filter(function(c){ return c.id !== id; }); };
__fake.friendConcerts = async function(){ return []; };
var __media = __fake.mediaUrl; __fake.mediaUrl = async function(b, p){ return b === 'concerts' ? 'cards/korn-holo.jpg' : __media ? __media(b, p) : null; };
__fake.cryQuiz = async function(){ return []; };
// bandes : une invitation en attente, la bande du concert du jour (2 membres), deux potes à inviter
__gigs[0].band_id = 'b1'; __gigs[0].concert_picks[1].band_bonus = true;
__fake.bandInvites = async function(){ return [{code:'XYZ789', artist:'Ghost', played_on:'2027-03-02', from_name:'Riffeuse'}]; };
__fake.bandState = async function(){ return {id:'b1', code:'ABC234', artist:'Spiritbox', played_on:__gigs[0].played_on, members:[{id:'u1', name:'Antoine', me:true, host:true, done:['Photo du pit']}, {id:'f1', name:'Riffeuse', done:['Photo du pit', 'Circle pit']}]}; };
__fake.friends = async function(){ return [{friend_id:'f1', username:'Riffeuse', trades:2}, {friend_id:'f2', username:'Bob le Slammeur', trades:1}, {friend_id:'f3', username:'Doom', trades:1}]; };
// slam : Riffeuse à porter, Doom porté et atterri (récompense), mon slam en vol (2 porteurs sur 5)
(function(){ var soon = new Date(Date.now() + 4300e3).toISOString();
__fake.slamFeed = async function(){ return {goal:5, window:120, crowd:[{id:'s1', name:'Riffeuse', goal:5, ends_at:soon, count:3}],
  carried:[{id:'s2', name:'Doom', goal:5, ends_at:soon, count:5, landed:true, rewarded:true}],
  mine:{id:'m1', goal:5, ends_at:soon, landed:false, claimed:false, crashed:false, carriers:['Bob le Slammeur', 'Krampus'], people:[{id:'f2', name:'Bob le Slammeur', url:'cards/hetfield-base.jpg'}, {id:'x8', name:'Krampus', url:'cards/amy-lee-base.jpg'}]}}; }; })();
__fake.friendCode = async function(){ return 'QWE789'; }; __fake.addFriend = async function(){ return 'Bob'; }; __fake.slamJoin = async function(){ return null; };
__fake.artistLookup = async function(a){ return /morello/i.test(a) ? {found:true, id:'morello', name:'Tom Morello', band:'Rage Against the Machine', asked:0, funded:false} : {found:false, asked:/deftones/i.test(a) ? 2 : 0, funded:false}; };
__fake.shop = async function(){ return {pack1:{url:'https://buy.stripe.com/test_x', cents:149, packs:1}, pack3:{url:'https://buy.stripe.com/test_y', cents:299, packs:3}, artist:{url:'https://buy.stripe.com/test_z', cents:299}}; };
__fake.purchaseNews = async function(){ return []; };
__fake.slamPoints = async function(){ return 4; };
// circle pit : celui de Riffeuse attend du monde (2 courses faites, la mienne à faire), le mien n'est pas encore lancé
(function(){ var end = new Date(Date.now() + 617e3).toISOString();
__pitState = {id:'p1', track:'morello', ends_at:end, over:false, host:false, host_name:'Riffeuse', in:true, rewarded:true, claimed:false, rps:.4, run_s:20,
  runners:[{id:'f1', name:'Riffeuse', url:'cards/amy-lee-base.jpg', score:81, rps:.3}, {id:'f2', name:'Bob le Slammeur', url:'cards/hetfield-base.jpg', score:64, rps:.35}, {id:'x9', name:'Moshzilla', score:null}, {id:'u1', name:'Antoine', score:null, me:true}],
  tier:{runners:2, aim:73, size:0, aim_tier:1, size_label:'Petit cercle', aim_label:'Carré', points:2}};
__fake.pitFeed = async function(){ return {live:[{id:'p1', name:'Riffeuse', track:'morello', ends_at:end, runners:2, in:false, ran:false}], done:[], opened_today:false, duration:900, run_s:20}; };
__fake.pitJoin = async function(){ return __pitState; }; __fake.pitOpen = async function(){ return __pitState; };
__fake.pitRunStart = async function(){ __pitState.runners[3].rps = .4; return __pitState; }; __fake.pitRunFinish = async function(id, sc){ __pitState.runners[3].score = sc; return __pitState; };
__fake.pitClaim = async function(){ return {points:2, tier:__pitState.tier, loot:null}; }; })();
// pogo : celui de Riffeuse (mise Rare), Bob à terre à relever, missions en cours
(function(){ var end = new Date(Date.now() + 412e3).toISOString();
__pogoState = {id:'g1', rarity:'rare', track:'morello', ends_at:end, over:false, cancelled:false, host:false, host_name:'Riffeuse', heat:3, run_s:15, hits:4, min_players:3, in:true, stake:'morello', result:null, won:[], claimed:false,
  players:[{id:'f1', name:'Riffeuse', url:'cards/amy-lee-base.jpg', energy:14, fell:false, lifted:false, friend:true}, {id:'f2', name:'Bob le Slammeur', url:'cards/hetfield-base.jpg', energy:4, fell:true, lifted:false, friend:true},
           {id:'x9', name:'Moshzilla', energy:9, fell:true, lifted:true, lifter:'Riffeuse', friend:false}, {id:'u1', name:'Antoine', energy:null, fell:null, lifted:false, me:true}]};
var missions = [{key:'week:2026-41', title:'Pogo de la semaine', hint:'Danse 3 pogos cette semaine', reward:'1 paquet', goal:3, n:1, weekly:true, claimed:false},
  {key:'first', title:'Premier pogo', hint:'Danse ta première manche de pogo', reward:'Une Commune pas encore trouvée', goal:1, n:1, claimed:false},
  {key:'lift5', title:'On relève les copains', hint:'Relève 5 potes à terre', reward:'Une carte Rare ou mieux', goal:5, n:2, claimed:false},
  {key:'king', title:'Roi du pogo', hint:'Danse 25 pogos', reward:'3 paquets', goal:25, n:1, claimed:false}];
__fake.pogoFeed = async function(){ return {live:[{id:'g1', name:'Riffeuse', rarity:'rare', ends_at:end, players:4, in:true, ran:false}], done:[], down:[{pogo:'g1', id:'f2', name:'Bob le Slammeur', url:'cards/hetfield-base.jpg', ends_at:end}],
  limit_reached:false, missions:missions, duration:600, run_s:15}; };
__fake.pogoState = async function(){ return __pogoState; }; __fake.pogoJoin = async function(){ return __pogoState; }; __fake.pogoRunStart = async function(){ return __pogoState; };
__fake.pogoRunFinish = async function(id, e, f){ __pogoState.players[3].energy = e; __pogoState.players[3].fell = f; return __pogoState; };
__fake.pogoLift = async function(){ return __pogoState; }; __fake.pogoMission = async function(){ return {kind:'points', points:2}; };
__fake.pogoClaim = async function(){ return {result:'won', stake:{m:'morello', r:'rare'}, won:[{m:'hetfield', r:'rare'}, {m:'amy-lee', r:'rare'}], points:3, energy:16, fell:false, lifter:null}; }; })();
