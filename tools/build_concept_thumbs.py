#!/usr/bin/env python3
"""Vignettes WebP des images de concept.html (assets/da/thumbs/, 520 px de large, qualité 78).

Usage : python3 tools/build_concept_thumbs.py   (depuis la racine du dépôt)
- Chaque <img> de concept.html qui pointe sur un original d'assets/da/ passe sur sa vignette
  assets/da/thumbs/<même chemin>.webp, avec width/height ; l'original reste dans le dépôt.
- Une vignette déjà citée est refaite si elle manque ou si l'original est plus récent.
- Le moodboard (illustrations de tiers, hors dépôt) n'est jamais converti.
Outil : cwebp s'il est installé (brew install webp), sinon Pillow.
"""
import os, re, shutil, struct, subprocess, sys

PAGE, ROOT, THUMBS = "concept.html", "assets/da", "assets/da/thumbs"
WIDTH, QUALITY = 520, 78
SKIP = ("assets/da/moodboard/",)
EXTS = (".jpg", ".jpeg", ".png", ".webp")


def original_of(thumb):
    # assets/da/thumbs/creas/x.webp -> assets/da/creas/x.jpg (première extension trouvée)
    stem = ROOT + thumb[len(THUMBS):-len(".webp")]
    return next((stem + e for e in EXTS if os.path.exists(stem + e)), None)


def thumb_of(src):
    return THUMBS + os.path.splitext(src[len(ROOT):])[0] + ".webp"


def make(src, dst):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    if shutil.which("cwebp"):
        subprocess.run(["cwebp", "-quiet", "-q", str(QUALITY), "-m", "6", "-resize", str(WIDTH), "0", src, "-o", dst], check=True)
    else:
        from PIL import Image
        im = Image.open(src).convert("RGB")
        im.resize((WIDTH, round(im.height * WIDTH / im.width)), Image.LANCZOS).save(dst, "WEBP", quality=QUALITY, method=6)


def webp_size(path):
    # largeur et hauteur lues dans l'en-tête WebP (VP8, VP8L ou VP8X)
    with open(path, "rb") as f:
        head = f.read(30)
    kind = head[12:16]
    if kind == b"VP8 ":
        w, h = struct.unpack("<HH", head[26:30])
        return w & 0x3FFF, h & 0x3FFF
    if kind == b"VP8L":
        b = head[21:25]
        return 1 + (((b[1] & 0x3F) << 8) | b[0]), 1 + (((b[3] & 0xF) << 10) | (b[2] << 2) | ((b[1] & 0xC0) >> 6))
    if kind == b"VP8X":
        return 1 + int.from_bytes(head[24:27], "little"), 1 + int.from_bytes(head[27:30], "little")
    sys.exit(f"WebP illisible : {path}")


def set_attr(tag, name, value):
    if re.search(rf'\s{name}="[^"]*"', tag):
        return re.sub(rf'(\s{name}=)"[^"]*"', rf'\1"{value}"', tag)
    return tag[:-1].rstrip() + f' {name}="{value}">'


html = open(PAGE, encoding="utf-8").read()
pairs, missing = {}, []


def fix(m):
    tag = m.group(0)
    src = re.search(r'\ssrc="([^"]+)"', tag).group(1)
    if not src.startswith(ROOT + "/") or src.startswith(SKIP):
        return tag
    thumb = src if src.startswith(THUMBS + "/") else thumb_of(src)
    orig = original_of(thumb) if src == thumb else src
    if not orig or not os.path.exists(orig):
        missing.append(src)
        return tag
    if not os.path.exists(thumb) or os.path.getmtime(thumb) < os.path.getmtime(orig):
        make(orig, thumb)
    pairs[orig] = thumb
    w, h = webp_size(thumb)
    return set_attr(set_attr(set_attr(tag, "src", thumb), "width", w), "height", h)


new = re.sub(r"<img\s[^>]*>", fix, html)
if new != html:
    open(PAGE, "w", encoding="utf-8").write(new)
before = sum(os.path.getsize(o) for o in pairs)
after = sum(os.path.getsize(t) for t in pairs.values())
print(f"{len(pairs)} vignettes : {before / 1048576:.1f} Mo d'originaux -> {after / 1048576:.1f} Mo de vignettes")
for s in missing:
    print("introuvable :", s)
