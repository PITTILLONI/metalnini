# Captures du prototype

Vérifier une interface à taille téléphone sans téléphone (Chrome sans interface).

1. À la racine du dépôt : `python3 -m http.server 8765`
2. Capture simple de l'accueil hors ligne :
   `node tools/capture/shot.mjs 390 664 /tmp/accueil.png`
3. Capture « en ligne » avec la fausse API (joueur, cartes, échange) puis un écran précis, ici Metal Corner :

```sh
export SEED="localStorage.setItem('metalnini-proto-v1', JSON.stringify({onbSeen:true, owned:{}, toPlace:[], instAsk:{n:3,t:0}, shared:true})); $(cat tools/capture/fake_online.js)"
node tools/capture/shot.mjs 390 844 /tmp/corner.png "(async()=>{const w=ms=>new Promise(r=>setTimeout(r,ms)); await window.metalniniOnline(__fake); await w(400); document.querySelectorAll('.onb,#auth').forEach(e=>e.hidden=true); document.getElementById('tab-corner').click(); await w(300); return 1 })()"
```

Tailles à vérifier avant un push : 390 × 664 et 430 × 932 (plus 390 × 844 au besoin). Pour simuler un iPhone, passer un user-agent Safari iOS en dernier argument.
