// Metalnini — tempo d'un extrait (BPM) : énergie par fenêtres, montées d'énergie, autocorrélation entre 70 et 200 BPM.
// null quand aucun pic ne se détache (bruit, silence, extrait sans pulsation nette).
(function(){
  var WIN = 1024, HOP = 256;
  function detect(x, sr){
    var n = Math.floor((x.length - WIN) / HOP); if(n < 8) return null;
    var e = new Float64Array(n), f = new Float64Array(n), i, j, k, sum, mean = 0;
    for(k = 0; k < n; k++){ sum = 0; for(j = k * HOP, i = j + WIN; j < i; j++) sum += x[j] * x[j]; e[k] = sum; }
    for(k = 1; k < n; k++){ f[k] = Math.max(0, e[k] - e[k - 1]); mean += f[k]; }
    mean /= n; for(k = 0; k < n; k++) f[k] -= mean;
    var fps = sr / HOP, lo = Math.floor(fps * 60 / 200), hi = Math.ceil(fps * 60 / 70), ac = [], best = -1, bestLag = 0;
    for(var lag = lo; lag <= hi && lag < n; lag++){ sum = 0; for(k = 0; k + lag < n; k++) sum += f[k] * f[k + lag]; ac.push(sum / (n - lag));
      if(ac[ac.length - 1] > best){ best = ac[ac.length - 1]; bestLag = lag; } }
    if(!(best > 0) || ac.length < 3) return null;
    var v0 = 0; for(k = 0; k < n; k++) v0 += f[k] * f[k]; v0 /= n;
    if(best < 0.25 * v0) return null;   // pic trop faible devant la variance : pas de pulsation
    // pic affiné entre deux retards (parabole)
    var idx = bestLag - lo, y0 = ac[idx - 1], y2 = ac[idx + 1], off = 0;
    if(y0 !== undefined && y2 !== undefined){ var d = y0 - 2 * best + y2; if(d) off = 0.5 * (y0 - y2) / d; }
    return Math.round(60 * fps / (bestLag + off));
  }
  var PitBeat = { detect: detect };
  if(typeof module !== 'undefined' && module.exports) module.exports = PitBeat; else window.PitBeat = PitBeat;
})();
