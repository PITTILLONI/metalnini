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
