#!/usr/bin/env python3
"""Construit export/metalnini-cartes.html : galerie à partager, qui charge les images allégées de proto/cards/.

Lancer d'abord tools/build_proto_cards.py.

Usage : python3 tools/build_gallery.py   (depuis la racine du dépôt)
Pour ajouter un artiste : compléter ARTISTS ci-dessous ; ses images sont lues dans proto/cards/.
"""
import html, os

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
    ("ramos", "Lorna Shore", "Will Ramos", "To the Hellfire", "XIV", "Chant", "Deathcore"),
    ("slash", "Guns N' Roses", "Slash", "Welcome to the Jungle", "XV", "Guitare", "Hard rock"),
    ("duplantier", "Gojira", "Mario Duplantier", "Flying Whales", "XVI", "Batterie", "Death metal progressif"),
    ("zack", "Rage Against the Machine", "Zack de la Rocha", "Bulls on Parade", "XVII", "Chant", "Rap metal"),
    ("heriot", "Heriot", "Debbie Gough", "Devoured by the Mouth of Hell", "XVIII", "Chant, guitare", "Metalcore"),
    ("frusciante", "Red Hot Chili Peppers", "John Frusciante", "Under the Bridge", "XIX", "Guitare", "Funk rock"),
    ("root", "Slipknot", "Jim Root", "Duality", "XX", "Guitare", "Nu metal"),
    ("jordison", "Slipknot", "Joey Jordison", "Wait and Bleed", "XXI", "Batterie", "Nu metal"),
]


def src(aid, key):
    return f"../proto/cards/{aid}-{key}.jpg"


def main():
    btns, panels, n = "", "", 0
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
