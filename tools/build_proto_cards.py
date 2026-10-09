#!/usr/bin/env python3
"""Prépare les images légères (proto/cards/, utilisées par le prototype et la galerie) et la liste des musiciens complets.

Usage : python3 tools/build_proto_cards.py   (depuis la racine du dépôt, sur Mac : sips)
        python3 tools/build_proto_cards.py --musician <id>   (un seul musicien, sans toucher aux paquets ; marche aussi sous Linux avec Pillow)
Un musicien n'entre dans le prototype que si ses 5 raretés existent dans assets/da/creas/.
"""
import json, os, re, shutil, subprocess, sys

CREAS, OUT = "assets/da/creas", "proto/cards"
RARITIES = ["commune", "rare", "holo", "signature", "legendaire"]
OVERRIDES = {("knocked-loose", "holo"): "knocked-loose-holo-v2",
             ("knocked-loose", "legendaire"): "knocked-loose-legendaire-v2"}


def shrink(src, dst, size=720, quality=74):
    # côté le plus long ramené à « size », JPEG ; sips sur Mac, Pillow ailleurs (agent cloud)
    if shutil.which("sips"):
        subprocess.run(["sips", "-Z", str(size), "-s", "format", "jpeg", "-s", "formatOptions", str(quality), src, "--out", dst],
                       check=True, stdout=subprocess.DEVNULL)
    else:
        from PIL import Image
        im = Image.open(src).convert("RGB"); im.thumbnail((size, size), Image.LANCZOS); im.save(dst, "JPEG", quality=quality)


os.makedirs(OUT, exist_ok=True)
only = sys.argv[sys.argv.index("--musician") + 1] if "--musician" in sys.argv else None
ids = [only] if only else sorted({f.rsplit("-", 1)[0] for f in os.listdir(CREAS) if f.endswith("-commune.jpg")})
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
            shrink(p, dst)
    ready.append(aid)
# un seul musicien : il rejoint la liste des musiciens complets, les paquets restent tels quels
if only:
    if only not in ready: sys.exit(f"{only} : il manque des raretés dans {CREAS}")
    m = open(f"{OUT}/manifest.js").read()
    cur = json.loads(re.search(r"METALNINI_READY = (\[.*?\]);", m).group(1))
    m = m.replace(re.search(r"METALNINI_READY = \[.*?\];", m).group(0), "METALNINI_READY = " + json.dumps(sorted(set(cur) | {only})) + ";")
    open(f"{OUT}/manifest.js", "w").write(m)
    sys.exit(f"{only} prêt")
# cartes secrètes (une seule image, hors liste des musiciens complets) : Céline Dion
for sid in ("celine",):
    p, dst = f"{CREAS}/{sid}-legendaire.jpg", f"{OUT}/{sid}-legendaire.jpg"
    if os.path.exists(p) and (not os.path.exists(dst) or os.path.getmtime(dst) < os.path.getmtime(p)):
        shrink(p, dst)
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

packs, minis = {}, {}
for key, name in (("serie", "pack-mosh" if os.path.exists(f"{CREAS}/pack-mosh.jpg") else "pack-a"), ("metalcore", "pack-metalcore"), ("hardcore", "pack-hardcore"), ("numetal", "pack-numetal"),
                  ("poppunk", "pack-poppunk"), ("legendes", "pack-legendes")):
    if os.path.exists(f"{CREAS}/{name}.jpg"):
        packs[key] = crop_pack(f"{CREAS}/{name}.jpg", f"{OUT}/pack-{key}.jpg")
    # petit paquet (« MINI », 2 cartes) : même sachet, étiquette dédiée
    if os.path.exists(f"{CREAS}/{name}-mini.jpg"):
        minis[key] = crop_pack(f"{CREAS}/{name}-mini.jpg", f"{OUT}/pack-{key}-mini.jpg")
if os.path.exists(f"{CREAS}/flames.jpg"):
    shrink(f"{CREAS}/flames.jpg", f"{OUT}/flames.jpg", 1400, 76)
if os.path.exists(f"{CREAS}/card-back.jpg"):
    shrink(f"{CREAS}/card-back.jpg", f"{OUT}/back.jpg")
open(f"{OUT}/manifest.js", "w").write("window.METALNINI_READY = " + repr(ready).replace("'", '"') + ";\n"
                                      + "window.METALNINI_PACKS = " + json.dumps(packs) + ";\n"
                                      + "window.METALNINI_MINIS = " + json.dumps(minis) + ";\n")
print(f"{len(ready)} musiciens prêts : {', '.join(ready)}")
