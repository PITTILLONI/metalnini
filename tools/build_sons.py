#!/usr/bin/env python3
"""Fiche des sons : tools/sound_cues.json → tableau de sons.html et liste du banc d'essai (proto/index.html, ?sons).
Lancer après chaque modification de sound_cues.json : python3 tools/build_sons.py"""
import html, json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
cues = json.loads((ROOT / 'tools' / 'sound_cues.json').read_text())
e = lambda s: html.escape(s, quote=False)

# sons.html : tableau trié par priorité puis dans l'ordre de la source, et compteurs dans l'en-tête
order = sorted(cues, key=lambda c: c['priorite'])
rows = '\n'.join(
    f"<tr><td><code>{c['id']}</code></td><td>{c['priorite']}</td><td>{e(c['famille'])}</td><td>{e(c['moment'])}</td><td>{e(c['duree'])}</td><td>{e(c['intention'])}</td></tr>"
    for c in order)
p = ROOT / 'sons.html'
s = p.read_text()
s = re.sub(r'<thead>.*?</thead>', '<thead><tr><th>Son</th><th>Priorité</th><th>Famille</th><th>Moment dans le jeu</th><th>Durée</th><th>Intention</th></tr></thead>', s, flags=re.S)
s = re.sub(r'<tbody>.*?</tbody>', '<tbody>\n' + rows + '\n</tbody>', s, flags=re.S)
p1 = sum(c['priorite'] == 'P1' for c in cues)
s = re.sub(r'<h2>Liste des sons.*?</h2>', f'<h2>Liste des sons ({len(cues)}, dont {p1} en priorité P1)</h2>', s)
p.write_text(s)

# banc d'essai : même liste, dans l'ordre de la source
p = ROOT / 'proto' / 'index.html'
s = p.read_text()
s, n = re.subn(r'var CUE_LIST = \[[^\]]*\];', 'var CUE_LIST = ' + json.dumps([c['id'] for c in cues], ensure_ascii=False) + ';', s)
assert n == 1, 'CUE_LIST introuvable dans proto/index.html'
p.write_text(s)
print(f'{len(cues)} sons ({p1} P1) : sons.html et banc d\'essai à jour')
