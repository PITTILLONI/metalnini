// Metalnini — photos de profil dans le circle pit : découpées en rond, liseré or, passées en noir et or (palette du jeu)
// pour ne pas faire « collage ». Une photo absente ou en échec rend null : l'appelant met une tête dessinée ou l'initiale.
(function(){
  var INK = [0x0d, 0x0a, 0x08], GOLD = [0xf4, 0xb2, 0x43], BLOOD = [0xb2, 0x3a, 0x3a];
  // bichromie sur place : luminance 0 → encre, 1 → or, ombres moyennes teintées de rouge (15 % au plus)
  function duotone(px){
    for(var i = 0; i < px.length; i += 4){
      var L = (0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2]) / 255, red = 0.6 * L * (1 - L);   // 0,15 au plus, nul aux extrêmes
      for(var c = 0; c < 3; c++){ var v = INK[c] + (GOLD[c] - INK[c]) * L; px[i + c] = Math.round(v + (BLOOD[c] - v) * red); }
    }
  }
  function canvas(size){ var c = document.createElement('canvas'); c.width = c.height = size; return c; }
  function ring(ctx, size){ ctx.globalCompositeOperation = 'source-over'; ctx.lineWidth = 2; ctx.strokeStyle = '#eb9a26';
    ctx.beginPath(); ctx.arc(size / 2, size / 2, size / 2 - 1, 0, Math.PI * 2); ctx.stroke(); }

  var PitPhoto = { duotone: duotone, _img: function(){ return new Image(); } };
  // photo ronde prête à devenir une texture ; 4 s au plus, jamais de rejet
  PitPhoto.load = function(url, style, size){
    if(!url) return Promise.resolve(null);
    return new Promise(function(ok){
      var im = PitPhoto._img(), done = false, end = function(v){ if(!done){ done = true; ok(v); } };
      setTimeout(function(){ end(null); }, 4000);
      im.onerror = function(){ end(null); };
      im.onload = function(){ try{
        var c = canvas(size), x = c.getContext('2d'), s = Math.min(im.width, im.height);
        x.beginPath(); x.arc(size / 2, size / 2, size / 2, 0, Math.PI * 2); x.clip();
        x.drawImage(im, (im.width - s) / 2, (im.height - s) / 2, s, s, 0, 0, size, size);
        if(style !== 'naturel'){ var d = x.getImageData(0, 0, size, size); duotone(d.data); x.putImageData(d, 0, 0); }
        ring(x, size); end(c);
      }catch(e){ end(null); } };   // image sans droits de lecture (CORS) : getImageData échoue
      im.crossOrigin = 'anonymous'; im.src = url;
    });
  };
  // pastille or avec l'initiale, pour qui n'a pas de photo
  PitPhoto.initial = function(name, size){
    var c = canvas(size), x = c.getContext('2d');
    x.fillStyle = '#15110f'; x.beginPath(); x.arc(size / 2, size / 2, size / 2, 0, Math.PI * 2); x.fill(); ring(x, size);
    x.fillStyle = '#f4b243'; x.font = '800 ' + Math.round(size * 0.5) + 'px "Big Shoulders Display","Arial Narrow",sans-serif';
    x.textAlign = 'center'; x.textBaseline = 'middle'; x.fillText(String(name || '?').trim().charAt(0).toUpperCase() || '?', size / 2, size / 2 + size * 0.03);
    return c;
  };
  if(typeof module !== 'undefined' && module.exports) module.exports = PitPhoto; else window.PitPhoto = PitPhoto;
})();
