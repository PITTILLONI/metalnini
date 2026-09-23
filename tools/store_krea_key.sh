#!/bin/bash
# Enregistre la clé API Krea (compte perso) dans le Trousseau macOS, sans l'afficher.
read -r -p "Copie ta clé Krea (Cmd+C) sur krea.ai, puis reviens ici et appuie sur Entrée… " _
key="$(pbpaste | tr -d '[:space:]')"
if [[ -z "$key" || "$key" =~ [^A-Za-z0-9_.:-] ]]; then
  echo "Le presse-papiers ne contient pas une clé valide (vide ou texte de commande). Recopie la clé et relance."
  exit 1
fi
security add-generic-password -U -a "$USER" -s krea-api-perso -w "$key" && pbcopy < /dev/null
echo "Clé enregistrée (${#key} caractères). Presse-papiers vidé."
