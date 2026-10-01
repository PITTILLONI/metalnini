#!/bin/zsh
# Exécute un fichier SQL sur la base Supabase de Metalnini (API de gestion), jeton lu dans le Trousseau (« supabase-token »), jamais affiché.
# usage : zsh tools/supa_sql.sh backend/supabase/seed.sql   (ou une migration de backend/supabase/migrations/)
cd "$(dirname "$0")/.."
f=$1
[ -f "$f" ] || { echo "Fichier SQL introuvable : $f"; exit 1; }
TOKEN=$(security find-generic-password -s supabase-token -w 2>/dev/null) || { echo "Jeton introuvable dans le Trousseau (supabase-token)."; exit 1; }
python3 -c "import json,sys; print(json.dumps({'query': open(sys.argv[1], encoding='utf-8').read()}))" "$f" |
  curl -sS -X POST "https://api.supabase.com/v1/projects/mdnevzmczljycmgbsrsu/database/query" \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" --data @-
echo
