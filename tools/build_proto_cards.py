#!/usr/bin/env python3
"""Prépare les images légères (proto/cards/, utilisées par le prototype et la galerie) et la liste des musiciens complets.

Usage : python3 tools/build_proto_cards.py   (depuis la racine du dépôt)
Un musicien n'entre dans le prototype que si ses 5 raretés existent dans assets/da/creas/.
"""
import os, subprocess

CREAS, OUT = "assets/da/creas", "proto/cards"
RARITIES = ["commune", "rare", "holo", "signature", "legendaire"]
OVERRIDES = {("knocked-loose", "holo"): "knocked-loose-holo-v2",
             ("knocked-loose", "legendaire"): "knocked-loose-legendaire-v2"}

os.makedirs(OUT, exist_ok=True)
ids = sorted({f.rsplit("-", 1)[0] for f in os.listdir(CREAS) if f.endswith("-commune.jpg")})
ready = []
for aid in ids:
    src = {r: f"{CREAS}/{OVERRIDES.get((aid, r), f'{aid}-{r}')}.jpg" for r in RARITIES}
    if not all(os.path.exists(p) for p in src.values()):
        continue
    base = f"{CREAS}/" + ("test-knocked-loose-03" if aid == "knocked-loose" else f"{aid}-base") + ".jpg"
    if os.path.exists(base):
        src["base"] = base
    for r, p in src.items():
        dst = f"{OUT}/{aid}-{r}.jpg"
        if not os.path.exists(dst) or os.path.getmtime(dst) < os.path.getmtime(p):
            subprocess.run(["sips", "-Z", "720", "-s", "format", "jpeg", "-s", "formatOptions", "74", p, "--out", dst],
                           check=True, stdout=subprocess.DEVNULL)
    ready.append(aid)
if os.path.exists(f"{CREAS}/card-back.jpg"):
    subprocess.run(["sips", "-Z", "720", "-s", "format", "jpeg", "-s", "formatOptions", "74", f"{CREAS}/card-back.jpg",
                    "--out", f"{OUT}/back.jpg"], check=True, stdout=subprocess.DEVNULL)
open(f"{OUT}/manifest.js", "w").write("window.METALNINI_READY = " + repr(ready).replace("'", '"') + ";\n")
print(f"{len(ready)} musiciens prêts : {', '.join(ready)}")
