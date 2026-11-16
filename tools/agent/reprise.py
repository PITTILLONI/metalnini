#!/usr/bin/env python3
"""Reprise automatique d'une branche d'artiste sur main (lancée par « Publier » quand GitHub refuse la fusion).

Depuis la branche artiste/<id> : python3 tools/agent/reprise.py [base]   (base : origin/main par défaut)
Fusionne la base, résout les conflits « chacun ajoute en fin de liste » (catalogue, classeurs, crédits, bios),
reprend la seed et la galerie de main puis les régénère, réunit les listes de musiciens prêts, refuse deux cartes
au même numéro d'arcane, puis committe. Sortie 0 : reprise faite ; 2 : à reprendre à la main (raison sur la sortie).
"""
import json, re, subprocess, sys

BASE = sys.argv[1] if len(sys.argv) > 1 else "origin/main"
REGEN = ["backend/supabase/seed.sql", "export/metalnini-cartes.html"]   # générés : ceux de main, puis régénérés
MANIFEST = "proto/cards/manifest.js"

def git(*a, check=True): return subprocess.run(["git", *a], check=check, capture_output=True, text=True).stdout
def stop(msg): print(msg); subprocess.run(["git", "reset", "-q", "--hard", "HEAD"], capture_output=True); sys.exit(2)   # annule la fusion entamée

# --- conflits « ajout en fin de liste » : main d'abord, puis ce que la branche ajoute ---
def union_any_list(t, o):
    pat = re.compile(r"(ids:|musicianIDs:)\s*\[([^\]]*)\]")
    mt, mo = pat.search(t), pat.search(o)
    if not (mt and mo) or t[:mt.start()] != o[:mo.start()]:
        return None
    sep = ", " if ", " in mt.group(2) else ","
    ti = [x.strip() for x in mt.group(2).split(",") if x.strip()]
    oi = [x.strip() for x in mo.group(2).split(",") if x.strip()]
    merged = ti + [x for x in oi if x not in ti]
    return t[:mt.start(2)] + sep.join(merged) + t[mt.end(2):]

def union_tracks(t, o):
    if "var TRACKS = {" not in t:
        return None
    pairs = re.compile(r"('?[\w-]+'?)\s*:\s*(\d+)")
    tk = {k.strip("'") for k, _ in pairs.findall(t)}
    extra = [f"{k}:{v}" for k, v in pairs.findall(o) if k.strip("'") not in tk]
    return t.replace("var TRACKS = {", "var TRACKS = {" + "".join(e + ", " for e in extra), 1)

def resolve(theirs, ours):
    if len(theirs) == len(ours):
        res = []
        for t1, o1 in zip(theirs, ours):
            r = union_any_list(t1, o1)
            if r is None: r = union_tracks(t1, o1)
            if r is None: break
            res.append(r)
        else:
            return res
    # sinon : main puis la branche ; virgule finale ajoutée si main finissait une liste sans virgule
    t = list(theirs)
    if t and ours and re.match(r"\s*\[", t[-1]) and not t[-1].rstrip().endswith(","):
        t[-1] = t[-1].rstrip("\n") + ",\n"
    return t + [l for l in ours if l not in t]

def unmark(path):
    lines = open(path, encoding="utf-8").read().splitlines(keepends=True); out, i = [], 0
    while i < len(lines):
        if lines[i].startswith("<<<<<<< "):
            j = i + 1; ours = []
            while not lines[j].startswith("======="): ours.append(lines[j]); j += 1
            j += 1; theirs = []
            while not lines[j].startswith(">>>>>>> "): theirs.append(lines[j]); j += 1
            out += resolve(theirs, ours); i = j + 1   # ours = la branche, theirs = main
        else: out.append(lines[i]); i += 1
    open(path, "w", encoding="utf-8").write("".join(out))

def ready(text): return json.loads(re.search(r"METALNINI_READY = (\[.*?\]);", text, re.S).group(1))

def arcana(src):
    rows = re.findall(r"^\s*\['([\w-]+)','(?:[^'\\]|\\.)*','(?:[^'\\]|\\.)*','(?:[^'\\]|\\.)*','([IVXLC]+)'", src, re.M)
    seen, dup = {}, []
    for i, n in rows:
        if n in seen and seen[n] != i: dup.append(f"{n} ({seen[n]} et {i})")
        seen.setdefault(n, i)
    return dup

before = arcana(git("show", f"{BASE}:proto/index.html"))
r = subprocess.run(["git", "merge", "--no-commit", "--no-ff", BASE], capture_output=True, text=True)
if "Already up to date" in r.stdout: print("déjà à jour"); sys.exit(0)
for path in [p for p in git("diff", "--name-only", "--diff-filter=U").split("\n") if p]:
    if path in REGEN: git("checkout", "--theirs", "--", path)
    elif path == MANIFEST:
        main_m = git("show", f":3:{path}"); ids = sorted(set(ready(main_m)) | set(ready(git("show", f":2:{path}"))))
        open(path, "w").write(re.sub(r"METALNINI_READY = \[.*?\];", lambda _: "METALNINI_READY = " + json.dumps(ids) + ";", main_m, count=1, flags=re.S))
    else: unmark(path)
    if "<<<<<<< " in open(path, encoding="utf-8", errors="replace").read(): stop(f"conflit non résolu dans {path}")
    git("add", "--", path)
subprocess.run([sys.executable, "tools/gen_seed.py"], check=True, capture_output=True)
subprocess.run([sys.executable, "tools/build_gallery.py"], check=True, capture_output=True)
dup = [d for d in arcana(open("proto/index.html", encoding="utf-8").read()) if d not in before]
if dup: stop("numéro d'arcane déjà pris : " + ", ".join(dup) + " ; « Retoucher » la demande avec un nouveau numéro (images à refaire)")
git("add", "-u")   # fichiers suivis seulement (générés compris)
git("commit", "-m", f"Reprise automatique : {BASE} fusionnée dans {git('rev-parse', '--abbrev-ref', 'HEAD').strip()} (listes réunies, seed et galerie régénérées)")
print("reprise faite")
