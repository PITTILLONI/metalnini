#!/usr/bin/env python3
"""Construit export/metalnini-cartes.html : galerie à partager, qui charge les images allégées de proto/cards/.

Lancer d'abord tools/build_proto_cards.py.

Usage : python3 tools/build_gallery.py   (depuis la racine du dépôt)
Les artistes viennent du catalogue du prototype (tableau CARDS de proto/index.html) ; images lues dans proto/cards/.
"""
import html, os, re

CREAS = "assets/da/creas"
OUT = "export/metalnini-cartes.html"
RARITIES = [("Base", "base"), ("Commune", "commune"), ("Rare", "rare"), ("Holo", "holo"),
            ("Signature", "signature"), ("Légendaire", "legendaire")]
# le catalogue vient du prototype (proto/index.html, tableau CARDS) : une seule source, triée par numéro d'arcane
def roman(n):
    v = {"I": 1, "V": 5, "X": 10, "L": 50, "C": 100}; t = 0
    for i, c in enumerate(n): t += -v[c] if i + 1 < len(n) and v[c] < v[n[i + 1]] else v[c]
    return t


def load_artists():
    src_html = open("proto/index.html", encoding="utf-8").read()
    block = src_html[src_html.index("var CARDS = ["):src_html.index("].map(function(c){ return {id:c[0]")]
    rows = re.findall(r"\['([^']+)','((?:[^'\\]|\\.)*)','((?:[^'\\]|\\.)*)','((?:[^'\\]|\\.)*)','([IVXLC]+)','([^']+)','([^']+)'\]", block)
    rows += re.findall(r"\['([^']+)','((?:[^'\\]|\\.)*)',\"([^\"]+)\",'((?:[^'\\]|\\.)*)','([IVXLC]+)','([^']+)','([^']+)'\]", block)
    rows += re.findall(r"\['([^']+)','((?:[^'\\]|\\.)*)','((?:[^'\\]|\\.)*)',\"([^\"]+)\",'([IVXLC]+)','([^']+)','([^']+)'\]", block)
    ready = [a for a in {r[0] for r in rows} if os.path.exists(f"proto/cards/{a}-commune.jpg")]
    arts = [(i, band.replace("\\'", "'"), who.replace("\\'", "'"), title.replace("\\'", "'"), num, inst, genre)
            for i, who, band, title, num, inst, genre in rows if i in ready]
    return sorted(arts, key=lambda a: roman(a[4]))


def src(aid, key):
    return f"../proto/cards/{aid}-{key}.jpg"


def main():
    btns, panels, n = "", "", 0
    ARTISTS = load_artists()
    for i, (aid, band, who, title, num, inst, genre) in enumerate(ARTISTS):
        e = html.escape
        btns += f'<button type="button" class="ab" data-a="{aid}" aria-selected="{str(i == 0).lower()}">{e(who)}</button>'
        figs = ""
        for label, key in RARITIES:
            figs += (f'<figure data-r="{key}"><button type="button" class="zoom" aria-label="Agrandir {e(who)}, {label}">'
                     f'<img src="{src(aid, key)}" alt="{e(who)}, {label}" loading="lazy"></button>'
                     f'<figcaption>{label}</figcaption></figure>')
            n += 1
        panels += (f'<section class="panel" data-a="{aid}"{"" if i == 0 else " hidden"}>'
                   f'<h2>{e(who)} <span>· {e(band)}</span></h2>'
                   f'<p class="meta">« {e(title)} » · arcane {num} · {e(inst)} · {e(genre)}</p>'
                   f'<div class="grid">{figs}</div></section>')
    tpl = open(os.path.join(os.path.dirname(__file__), "gallery_template.html"), encoding="utf-8").read()
    os.makedirs("export", exist_ok=True)
    open(OUT, "w", encoding="utf-8").write(tpl.replace("<!--BUTTONS-->", btns).replace("<!--PANELS-->", panels))
    print(f"{n} cartes, {len(ARTISTS)} artistes, {os.path.getsize(OUT) / 1e6:.1f} Mo -> {OUT}")


if __name__ == "__main__":
    main()
