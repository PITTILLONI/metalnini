#!/bin/bash
# Enregistre un secret dans le Trousseau macOS sans l'afficher : il est lu dans le presse-papiers.
# Usage : tools/store_secret.sh <nom-du-service>   (ex. supabase-token, supabase-db-password)
set -e
svc="$1"
[ -z "$svc" ] && { echo "Usage : $0 <nom-du-service>"; exit 1; }
read -r -p "Copie le secret « $svc » (Cmd+C), reviens ici et appuie sur Entrée… " _
val="$(pbpaste | tr -d '\n\r')"
if [ -z "$val" ] || [[ "$val" == *"security "* ]] || [[ "$val" == *"store_secret"* ]]; then
  echo "Le presse-papiers ne contient pas le secret (vide ou texte de commande). Recopie-le et relance."; exit 1
fi
security add-generic-password -U -a "$USER" -s "$svc" -w "$val" && pbcopy < /dev/null
echo "Secret « $svc » enregistré (${#val} caractères). Presse-papiers vidé."
