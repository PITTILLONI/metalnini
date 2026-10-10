#!/usr/bin/env python3
"""Fiche des sons : tools/sound_cues.json → tableau de sons.html, liste du banc d'essai (proto/index.html, ?sons) et PDF (export/metalnini-sons.pdf, via Chrome).
Lancer après chaque modification de sound_cues.json : python3 tools/build_sons.py"""
import html, json, re, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
cues = json.loads((ROOT / 'tools' / 'sound_cues.json').read_text())
e = lambda s: html.escape(s, quote=False)

# sons livrés : déclarés dans proto/sounds/manifest.js (case « Fait » cochée d'office)
done = set(re.findall(r"^\s*'([a-z0-9-]+)'\s*:", (ROOT / 'proto' / 'sounds' / 'manifest.js').read_text(), re.M))
box = lambda ok: '<span class="box on" role="img" aria-label="Fait">✓</span>' if ok else '<span class="box" role="img" aria-label="À faire"></span>'

# sons.html : tableau trié par priorité puis dans l'ordre de la source, et compteurs dans l'en-tête
order = sorted(cues, key=lambda c: c['priorite'])
rows = '\n'.join(
    f"<tr><td>{box(c['id'] in done)}</td><td><code>{c['id']}</code></td><td>{c['priorite']}</td><td>{e(c['famille'])}</td><td>{e(c['moment'])}</td><td>{e(c['duree'])}</td><td>{e(c['intention'])}</td></tr>"
    for c in order)
p = ROOT / 'sons.html'
s = p.read_text()
s = re.sub(r'<thead>.*?</thead>', '<thead><tr><th>Fait</th><th>Son</th><th>Priorité</th><th>Famille</th><th>Moment dans le jeu</th><th>Durée</th><th>Intention</th></tr></thead>', s, flags=re.S)
s = re.sub(r'<tbody>.*?</tbody>', '<tbody>\n' + rows + '\n</tbody>', s, flags=re.S)
p1 = sum(c['priorite'] == 'P1' for c in cues)
nd = sum(c['id'] in done for c in cues)
s = re.sub(r'<h2>Liste des sons.*?</h2>', f'<h2>Liste des sons ({len(cues)}, dont {p1} en priorité P1 · {nd} faits)</h2>', s)
p.write_text(s)

# banc d'essai : même liste, dans l'ordre de la source
p = ROOT / 'proto' / 'index.html'
s = p.read_text()
s, n = re.subn(r'var CUE_LIST = \[[^\]]*\];', 'var CUE_LIST = ' + json.dumps([c['id'] for c in cues], ensure_ascii=False) + ';', s)
assert n == 1, 'CUE_LIST introuvable dans proto/index.html'
p.write_text(s)
# PDF pour la sonorisation (version impression de sons.html : A4 paysage, fond clair, cases « Fait »)
chrome = Path('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')
pdf = ROOT / 'export' / 'metalnini-sons.pdf'
if chrome.exists():
    subprocess.run([str(chrome), '--headless=new', '--disable-gpu', '--no-pdf-header-footer', '--virtual-time-budget=8000',
                    f'--print-to-pdf={pdf}', (ROOT / 'sons.html').as_uri()], check=True, capture_output=True)
print(f'{len(cues)} sons ({p1} P1, {nd} faits) : sons.html, banc d\'essai' + (' et PDF' if chrome.exists() else ' (PDF : Chrome absent)') + ' à jour')
