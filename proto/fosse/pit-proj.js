// Metalnini — caméra drone du circle pit : derrière le joueur et en hauteur, il court vers le haut de l'écran.
// Projection d'un point de l'anneau (a en tours, r normalisé) vers l'écran ; plus loin = plus haut et plus petit.
(function(){
  var BACK = 0.35, NEAR = 0.08, ME_Y = 0.78, HORIZON = 0.18;
  function clamp(x, lo, hi){ return x < lo ? lo : x > hi ? hi : x; }
  function camera(me, w, h){
    var t = me.a * Math.PI * 2, c = Math.cos(t), s = Math.sin(t);
    return { w: w, h: h, tx: -s, ty: c, nx: c, ny: s, cx: me.r * c + BACK * s, cy: me.r * s - BACK * c };   // tangente, normale, position de la caméra
  }
  function project(cam, a, r){
    var t = a * Math.PI * 2, dx = r * Math.cos(t) - cam.cx, dy = r * Math.sin(t) - cam.cy;
    var depth = dx * cam.tx + dy * cam.ty, lat = dx * cam.nx + dy * cam.ny;
    if(depth < NEAR) return { x: 0, y: 0, scale: 0, depth: depth, visible: false };
    var k = BACK / depth, hz = HORIZON * cam.h;
    return { x: cam.w / 2 + lat * k * cam.w * 0.9, y: clamp(hz + (ME_Y * cam.h - hz) * k, 0, cam.h * 1.2), scale: clamp(k, 0.25, 1.4), depth: depth, visible: true };
  }
  var PitProj = { camera: camera, project: project, ME_Y: ME_Y, HORIZON: HORIZON };
  if(typeof module !== 'undefined' && module.exports) module.exports = PitProj; else window.PitProj = PitProj;
})();
