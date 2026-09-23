#!/usr/bin/env python3
"""Génère une image via l'API REST Krea et l'enregistre localement.

La clé est lue dans le Trousseau macOS (service « krea-api-perso »), jamais en argument ni en clair.

Usage :
  python3 tools/krea_generate.py --out assets/da/creas/artiste-commune.jpg \
      --prompt "..." [--model krea/krea-2/medium] [--ratio 2:3] [--resolution 1K]
"""
import argparse, json, os, subprocess, sys, time, urllib.error, urllib.request

API = "https://api.krea.ai"


def api_key():
    try:
        return subprocess.check_output(
            ["security", "find-generic-password", "-s", "krea-api-perso", "-w"], text=True
        ).strip()
    except subprocess.CalledProcessError:
        sys.exit("Clé introuvable dans le Trousseau (service « krea-api-perso »).")


def call(method, path, key, body=None):
    req = urllib.request.Request(
        API + path, method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:300]
        if e.code == 402:
            sys.exit("Solde API Krea insuffisant (HTTP 402) : recharger le compte.")
        sys.exit(f"Erreur Krea HTTP {e.code} sur {path} : {detail}")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--prompt", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--model", default="krea/krea-2/medium")
    p.add_argument("--ratio", default="2:3")
    p.add_argument("--resolution", default="1K")
    p.add_argument("--timeout", type=int, default=300)
    p.add_argument("--creativity", choices=["raw", "low", "medium", "high"],
                   help="Krea 2 : raw désactive la réécriture automatique du prompt")
    p.add_argument("--style-ref", action="append", default=[], metavar="URL[@FORCE]",
                   help="Krea 2 : image de référence de style (URL publique), force 0-1, ex. URL@0.6")
    p.add_argument("--image-url", action="append", default=[], metavar="URL",
                   help="Nano Banana : image(s) de référence (visage, style), URL publique")
    a = p.parse_args()

    key = api_key()
    body = {"prompt": a.prompt, "aspect_ratio": a.ratio, "resolution": a.resolution}
    if a.creativity:
        body["creativity"] = a.creativity
    if a.style_ref:
        refs = []
        for r in a.style_ref:
            url, _, force = r.rpartition("@") if "@" in r.rsplit("/", 1)[-1] else (r, "", "")
            refs.append({"url": url or r, "strength": float(force) if force else 0.5})
        body["image_style_references"] = refs
    if a.image_url:
        body["image_urls"] = a.image_url
    job = call("POST", f"/generate/image/{a.model}", key, body)
    job_id = job.get("job_id") or job.get("id")
    if not job_id:
        sys.exit(f"Réponse inattendue : {json.dumps(job)[:300]}")
    print(f"Job {job_id} lancé ({a.model})", flush=True)

    deadline = time.time() + a.timeout
    while time.time() < deadline:
        job = call("GET", f"/jobs/{job_id}", key)
        status = job.get("status")
        if status == "completed":
            urls = (job.get("result") or {}).get("urls") or []
            if not urls:
                sys.exit(f"Job terminé sans image : {json.dumps(job)[:300]}")
            tmp = a.out + ".download"
            urllib.request.urlretrieve(urls[0], tmp)
            subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "92", tmp, "--out", a.out],
                           check=True, stdout=subprocess.DEVNULL)
            os.remove(tmp)
            print(f"Image enregistrée : {a.out}")
            return
        if status in ("failed", "cancelled"):
            sys.exit(f"Job {status} : {json.dumps(job.get('result'))[:300]}")
        time.sleep(3)
    sys.exit(f"Délai dépassé, job {job_id} toujours en cours.")


if __name__ == "__main__":
    main()
