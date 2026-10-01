// Fausse API en ligne pour les captures (tools/capture/shot.mjs) : un joueur « Antoine » avec quelques cartes, Hendrix maîtrisé, un échange ouvert (__T).

window.__T = { id:'t1', code:'ABC234', status:'open', version:0, host:true, partner:null, left:false, my_ok:false, their_ok:false, give:[], get:[], my_wants:[], their_wants:[], bonus:null };
window.__fake = { async user(){ return { id:'u1', user_metadata:{} }; }, async inventory(){ return [{musician_id:'korn', rarity:'rare', copies:1, placed:true},{musician_id:'korn', rarity:'commune', copies:3, placed:true},{musician_id:'jinjer', rarity:'holo', copies:1, placed:true},{musician_id:'angus', rarity:'signature', copies:2, placed:true},{musician_id:'spiritbox', rarity:'commune', copies:1, placed:true},{musician_id:'hendrix', rarity:'commune', copies:1, placed:true},{musician_id:'hendrix', rarity:'rare', copies:1, placed:true},{musician_id:'hendrix', rarity:'holo', copies:1, placed:true},{musician_id:'hendrix', rarity:'signature', copies:1, placed:true},{musician_id:'hendrix', rarity:'legendaire', copies:1, placed:true}]; },
 async username(){ return 'Antoine'; }, async fusionCosts(){ return {}; }, async media(){ return {}; }, async power(){ return null; }, async packsLeft(){ return 1; }, async bonusPoints(){ return 0; }, async giftNotices(){ return []; },
 async tradeCount(){ return 0; }, async tradeCreate(){ return JSON.parse(JSON.stringify(__T)); }, async tradeState(){ return JSON.parse(JSON.stringify(__T)); }, tradeWatch(id, cb){ window.__cb = cb; return ()=>{}; },
 async tradeActive(){ return null; }, async claims(){ return []; }, async claimObjective(){ return {kind:'points', points:2}; },
 async tradePartnerCards(){ return []; }, async tradeWant(){ return JSON.parse(JSON.stringify(__T)); } };
__fake.tickets = async function(){ return 1; };
__fake.tradeConfirm = async function(){ __T.status = 'done'; __T.bonus = {m:'hetfield', r:'commune'}; return JSON.parse(JSON.stringify(__T)); };
__fake.tradeInvites = async function(){ return []; }; __fake.friends = async function(){ return []; }; __fake.myTrades = async function(){ return []; }; __fake.mediaUrl = async function(){ return null; };
__fake.presence = async function(){};
__fake.claimBlindtest = async function(){ return {kind:'points', points:2}; };
// concerts : deux talons (un passé avec photo, un à venir), ajout en mémoire
window.__gigs = [{id:'g1', artist:'Gojira', musician_id:null, played_on:'2026-06-21', venue:'Hellfest', city:'Clisson', photo_path:'u1/concert-1.jpg', photo_public:true},
  {id:'g2', artist:'Spiritbox', musician_id:'spiritbox', played_on:'2027-02-14', venue:'Zénith', city:'Paris', photo_path:null, photo_public:false}];
__fake.concerts = async function(){ return __gigs.slice(); };
__fake.addConcert = async function(c){ var id = 'g' + (__gigs.length + 1); __gigs.unshift({id:id, artist:c.artist, musician_id:c.musician, played_on:c.date, venue:c.venue, city:c.city, photo_path:null, photo_public:false}); return id; };
__fake.concertPhoto = async function(){ return 'u1/p.jpg'; }; __fake.deleteConcert = async function(id){ __gigs = __gigs.filter(function(c){ return c.id !== id; }); };
__fake.friendConcerts = async function(){ return []; };
var __media = __fake.mediaUrl; __fake.mediaUrl = async function(b, p){ return b === 'concerts' ? 'cards/korn-holo.jpg' : __media ? __media(b, p) : null; };
__fake.cryQuiz = async function(){ return []; };
