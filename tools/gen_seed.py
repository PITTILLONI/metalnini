#!/usr/bin/env python3
"""Génère backend/supabase/seed.sql à partir du catalogue Swift (ios/Packages/MetalniniKit/.../Catalog.swift),
pour que l'app et la base partent exactement des mêmes musiciens, classeurs et paquets.

Usage : python3 tools/gen_seed.py
"""
import re

SRC = "ios/Packages/MetalniniKit/Sources/MetalniniKit/Catalog.swift"
OUT = "backend/supabase/seed.sql"
RARITIES = ["commune", "rare", "holo", "signature", "legendaire"]
ODDS = {"commune": 60, "rare": 25, "holo": 10, "signature": 4, "legendaire": 1}

src = open(SRC, encoding="utf-8").read()
q = lambda v: "'" + v.replace("'", "''") + "'"

musicians = re.findall(r'\.init\(id: "([^"]+)", name: "([^"]+)", band: "([^"]+)", arcanaTitle: "([^"]+)", arcanaNumber: "([^"]+)", instruments: \[([^\]]*)\], subgenre: "([^"]+)"\)', src)
binders = re.findall(r'\.init\(id: "([^"]+)", kind: \.(\w+), label: "([^"]+)", musicianIDs: (\[[^\]]*\]|musicians\.map\(\\\.id\))\)', src)
packs = re.findall(r'\.init\(id: "([^"]+)", label: "([^"]+)"(?:, binderID: "([^"]+)")?\)', src)
fusion = re.search(r"fusionCost = (\d+)", src).group(1)
assert len(musicians) >= 1 and binders and packs, "catalogue introuvable"

out = ["-- Généré par tools/gen_seed.py depuis Catalog.swift : ne pas modifier à la main.", "begin;", ""]
out.append("insert into public.musicians (id, name, band, arcana_title, arcana_number, instruments, subgenre) values")
out.append(",\n".join(f"  ({q(i)}, {q(n)}, {q(b)}, {q(t)}, {q(a)}, array[{', '.join(q(x.strip().lstrip('.')) for x in ins.split(',') if x.strip())}]::text[], {q(g)})"
                      for i, n, b, t, a, ins, g in musicians) + "\non conflict (id) do nothing;\n")
out.append("insert into public.cards (musician_id, rarity, image_path) values")
out.append(",\n".join(f"  ({q(m[0])}, '{r}', {q(f'cards/{m[0]}-{r}.jpg')})" for m in musicians for r in RARITIES) + "\non conflict do nothing;\n")
out.append("insert into public.binders (id, kind, label, sort) values")
out.append(",\n".join(f"  ({q(i)}, '{k}', {q(l)}, {n})" for n, (i, k, l, _) in enumerate(binders)) + "\non conflict (id) do nothing;\n")
rows = []
for i, k, l, ids in binders:
    members = [m[0] for m in musicians] if ids.startswith("musicians") else re.findall(r'"([^"]+)"', ids)
    rows += [f"  ({q(i)}, {q(m)})" for m in members]
out.append("insert into public.binder_members (binder_id, musician_id) values")
out.append(",\n".join(rows) + "\non conflict do nothing;\n")
out.append("insert into public.pack_types (id, label, size, binder_id) values")
out.append(",\n".join(f"  ({q(i)}, {q(l)}, 5, {q(b) if b else 'null'})" for i, l, b in packs) + "\non conflict (id) do nothing;\n")
out.append("insert into public.pack_odds (pack_type_id, rarity, weight) values")
out.append(",\n".join(f"  ({q(i)}, '{r}', {ODDS[r]})" for i, _, _ in packs for r in RARITIES) + "\non conflict do nothing;\n")
out.append("insert into public.settings (key, value) values")
out.append(f"  ('fusion_cost', '{fusion}'),\n  ('packs_per_day', '20')\non conflict (key) do nothing;\n")
out.append("commit;")
open(OUT, "w", encoding="utf-8").write("\n".join(out) + "\n")
print(f"{len(musicians)} musiciens, {len(musicians) * 5} cartes, {len(binders)} classeurs, {len(packs)} paquets -> {OUT}")
