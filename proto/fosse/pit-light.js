// Metalnini — lumières du circle pit : 3 projecteurs de scène (2 rouges, 1 or) qui balaient la fosse, pulsent sur le tempo
// et flashent aux moments forts ; voile sombre sur les bords et halo doré autour du joueur. Mouvement réduit : ni flash, balayage lent.
(function(){
  var RED = 0xb23a3a, GOLD = 0xeb9a26, W = 0.0004;
  var BEAMS = [{ x: 0.2, phase: 0, color: RED, amp: 0.55 }, { x: 0.5, phase: 2.1, color: GOLD, amp: 0.35 }, { x: 0.8, phase: 4.2, color: RED, amp: 0.55 }];
  function beams(tMs, o){
    var sp = o.reduce ? 0.25 : 1, pulse = o.beatT == null ? 0 : 0.35 * Math.exp(-o.beatT / 120), flash = o.reduce || o.flashT == null ? 0 : 0.4 * Math.exp(-o.flashT / 150);
    return BEAMS.map(function(b){ return { x: b.x, angle: b.amp * Math.sin(tMs * W * sp + b.phase), width: 0.18, color: b.color, intensity: Math.min(1, 0.55 + pulse + flash) }; });
  }

  // dessin : faisceaux en cône (dégradé fait une fois sur un canevas), mode additif
  function coneCanvas(){ var c = document.createElement('canvas'), w = 128, h = 512, x; c.width = w; c.height = h; x = c.getContext('2d');
    var g = x.createLinearGradient(0, 0, 0, h); g.addColorStop(0, 'rgba(255,255,255,.9)'); g.addColorStop(1, 'rgba(255,255,255,0)');
    x.fillStyle = g; x.beginPath(); x.moveTo(w / 2 - 6, 0); x.lineTo(w / 2 + 6, 0); x.lineTo(w, h); x.lineTo(0, h); x.closePath(); x.fill(); return c; }
  function glowCanvas(){ var c = document.createElement('canvas'), s = 256, x; c.width = c.height = s; x = c.getContext('2d');
    var g = x.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2); g.addColorStop(0, 'rgba(255,255,255,.8)'); g.addColorStop(1, 'rgba(255,255,255,0)');
    x.fillStyle = g; x.fillRect(0, 0, s, s); return c; }
  function vignetteCanvas(){ var c = document.createElement('canvas'), s = 256, x; c.width = c.height = s; x = c.getContext('2d');
    var g = x.createRadialGradient(s / 2, s * 0.62, s * 0.2, s / 2, s * 0.62, s * 0.75); g.addColorStop(0, 'rgba(13,10,8,0)'); g.addColorStop(1, 'rgba(13,10,8,.85)');
    x.fillStyle = g; x.fillRect(0, 0, s, s); return c; }

  function layer(PIXI, app){
    var cont = new PIXI.Container(), cone = PIXI.Texture.from(coneCanvas()), glow = PIXI.Texture.from(glowCanvas()), vig = new PIXI.Sprite(PIXI.Texture.from(vignetteCanvas()));
    var rays = BEAMS.map(function(){ var s = new PIXI.Sprite(cone); s.anchor.set(0.5, 0); s.blendMode = 'add'; cont.addChild(s); return s; });
    var halo = new PIXI.Sprite(glow); halo.anchor.set(0.5); halo.blendMode = 'add'; halo.tint = GOLD; cont.addChild(halo, vig);
    return { container: cont, glow: glow,
      draw: function(list, w, h, me){
        list.forEach(function(b, i){ var s = rays[i]; s.position.set(b.x * w, -h * 0.05); s.rotation = b.angle; s.tint = b.color;
          s.width = b.width * w * 3; s.height = h * 1.25; s.alpha = 0.22 * b.intensity; });
        if(me){ halo.position.set(me.x, me.y - 30 * me.scale); halo.width = halo.height = 170 * me.scale; halo.alpha = 0.35; }
        vig.width = w; vig.height = h; } };
  }

  var PitLight = { beams: beams, layer: layer };
  if(typeof module !== 'undefined' && module.exports) module.exports = PitLight; else window.PitLight = PitLight;
})();
