#!/usr/bin/env python3
"""Construit export/metalnini-cartes.html : galerie autonome (images intégrées) à partager.

Usage : python3 tools/build_gallery.py   (depuis la racine du dépôt)
Pour ajouter un artiste : compléter ARTISTS ci-dessous. Fichiers attendus dans assets/da/creas/ :
<id>-base.jpg, <id>-commune.jpg, <id>-rare.jpg, <id>-holo.jpg, <id>-signature.jpg, <id>-legendaire.jpg
(OVERRIDES permet de pointer vers un autre nom de fichier).
"""
import base64, html, os, subprocess, tempfile

CREAS = "assets/da/creas"
OUT = "export/metalnini-cartes.html"
RARITIES = [("Base", "base"), ("Commune", "commune"), ("Rare", "rare"), ("Holo", "holo"),
            ("Signature", "signature"), ("Légendaire", "legendaire")]
# id, groupe, artiste, titre d'arcane, numéro, instrument, sous-genre
ARTISTS = [
    ("knocked-loose", "Knocked Loose", "Bryan Garris", "The Deadringer", "IV", "Chant", "Hardcore"),
    ("isaac-hale", "Knocked Loose", "Isaac Hale", "Counting Worms", "X", "Guitare", "Hardcore"),
    ("jinjer", "Jinjer", "Tatiana Shmayluk", "Pisces", "V", "Chant", "Metalcore progressif"),
    ("spiritbox", "Spiritbox", "Courtney LaPlante", "Holy Roller", "VI", "Chant", "Metalcore"),
    ("blink182", "Blink-182", "Travis Barker", "All the Small Things", "VII", "Batterie", "Pop punk"),
    ("hoppus", "Blink-182", "Mark Hoppus", "What's My Age Again?", "XII", "Basse, chant", "Pop punk"),
    ("landmvrks", "Landmvrks", "Florent Salfati", "Lost in the Waves", "VIII", "Chant", "Metalcore"),
    ("hendrix", "Jimi Hendrix", "Jimi Hendrix", "Purple Haze", "IX", "Guitare", "Rock psychédélique"),
    ("korn", "Korn", "Jonathan Davis", "Freak on a Leash", "XI", "Chant", "Nu metal"),
    ("poppy", "Poppy", "Poppy", "I Disagree", "XIII", "Chant", "Métal expérimental"),
]
OVERRIDES = {
    ("knocked-loose", "base"): "test-knocked-loose-03",
    ("knocked-loose", "holo"): "knocked-loose-holo-v2",
    ("knocked-loose", "legendaire"): "knocked-loose-legendaire-v2",
}


def data_uri(name, tmp):
    out = os.path.join(tmp, name + ".jpg")
    subprocess.run(["sips", "-Z", "900", "-s", "format", "jpeg", "-s", "formatOptions", "78",
                    f"{CREAS}/{name}.jpg", "--out", out], check=True, stdout=subprocess.DEVNULL)
    return "data:image/jpeg;base64," + base64.b64encode(open(out, "rb").read()).decode()


def main():
    btns, panels, n = "", "", 0
    with tempfile.TemporaryDirectory() as tmp:
        for i, (aid, band, who, title, num, inst, genre) in enumerate(ARTISTS):
            e = html.escape
            btns += f'<button type="button" class="ab" data-a="{aid}" aria-selected="{str(i == 0).lower()}">{e(who)}</button>'
            figs = ""
            for label, key in RARITIES:
                name = OVERRIDES.get((aid, key), f"{aid}-{key}")
                figs += (f'<figure data-r="{key}"><button type="button" class="zoom" aria-label="Agrandir {e(who)}, {label}">'
                         f'<img src="{data_uri(name, tmp)}" alt="{e(who)}, {label}" loading="lazy"></button>'
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
