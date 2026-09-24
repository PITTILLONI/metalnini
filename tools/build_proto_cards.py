#!/usr/bin/env python3
"""Prépare les images légères (proto/cards/, utilisées par le prototype et la galerie) et la liste des musiciens complets.

Usage : python3 tools/build_proto_cards.py   (depuis la racine du dépôt)
Un musicien n'entre dans le prototype que si ses 5 raretés existent dans assets/da/creas/.
"""
import json, os, subprocess

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
# paquets : rognés automatiquement au ras du sachet (bords non noirs), puis allégés
def crop_pack(src, dst):
    import struct, tempfile
    with tempfile.TemporaryDirectory() as t:
        bmp = f"{t}/p.bmp"
        subprocess.run(["sips", "-Z", "300", "-s", "format", "bmp", src, "--out", bmp], check=True, stdout=subprocess.DEVNULL)
        b = open(bmp, "rb").read()
    off = struct.unpack("<I", b[10:14])[0]; w, hh = struct.unpack("<ii", b[18:26]); bpp = struct.unpack("<H", b[28:30])[0] // 8
    row, H = (w * bpp + 3) // 4 * 4, abs(hh)
    xs, ys = [], []
    for y in range(H):
        yy = (H - 1 - y) if hh > 0 else y
        for x in range(w):
            i = off + yy * row + x * bpp
            if max(b[i], b[i + 1], b[i + 2]) > 40: xs.append(x); ys.append(y)
    sw = int(subprocess.check_output(["sips", "-g", "pixelWidth", src], text=True).split()[-1])
    sh = int(subprocess.check_output(["sips", "-g", "pixelHeight", src], text=True).split()[-1])
    k = sw / w
    x0, x1, y0, y1 = max(0, int(min(xs) * k) - 6), min(sw, int((max(xs) + 1) * k) + 6), max(0, int(min(ys) * k) - 6), min(sh, int((max(ys) + 1) * k) + 6)
    subprocess.run(["sips", "-c", str(y1 - y0), str(x1 - x0), "--cropOffset", str(y0), str(x0), "-s", "format", "jpeg",
                    "-s", "formatOptions", "80", src, "--out", dst], check=True, stdout=subprocess.DEVNULL)
    return round((x1 - x0) / (y1 - y0), 4)

packs = {}
for key, name in (("serie", "pack-a"), ("metalcore", "pack-metalcore"), ("hardcore", "pack-hardcore"), ("numetal", "pack-numetal"),
                  ("poppunk", "pack-poppunk"), ("legendes", "pack-legendes")):
    if os.path.exists(f"{CREAS}/{name}.jpg"):
        packs[key] = crop_pack(f"{CREAS}/{name}.jpg", f"{OUT}/pack-{key}.jpg")
if os.path.exists(f"{CREAS}/card-back.jpg"):
    subprocess.run(["sips", "-Z", "720", "-s", "format", "jpeg", "-s", "formatOptions", "74", f"{CREAS}/card-back.jpg",
                    "--out", f"{OUT}/back.jpg"], check=True, stdout=subprocess.DEVNULL)
open(f"{OUT}/manifest.js", "w").write("window.METALNINI_READY = " + repr(ready).replace("'", '"') + ";\n"
                                      + "window.METALNINI_PACKS = " + json.dumps(packs) + ";\n")
print(f"{len(ready)} musiciens prêts : {', '.join(ready)}")
