#!/bin/zsh
# Décline une carte de base en 5 raretés (Nano Banana Pro, édition de l'image de base).
# usage : tools/krea_rarities.sh <id> <url publique de la carte de base> <his|her>
cd "$(dirname "$0")/.."
id=$1; BASE=$2; P=$3
KEEP="Edit this tarot card. Keep the illustration, the musician, $P face, the pose, the props, the layout and all the text exactly as they are. Change ONLY the frame and finishing to show a rarity level: "
KEEP2="Edit this tarot card. Keep the musician, $P face, the pose, the props, the layout and all the text exactly as they are. "
typeset -A R
R[commune]="${KEEP}COMMON rarity. Plain, sober frame: simple thin black border lines instead of ornate flourishes, no gold at all, the halo and accents turned to a flat steel grey, matte uncoated paper. Humble and minimal."
R[rare]="${KEEP}RARE rarity. Same ornate frame, with a thin cold blue metallic inlay line running along the inner border and around the title cartouche; the sun, moon and corner ornaments picked out in cold blue. Everything else unchanged."
R[holo]="${KEEP2}Turn it into a FULL-ART HOLOGRAPHIC trading card: the entire card surface, including the illustration, the background, the halo and the frame, is printed on iridescent prismatic foil. Strong rainbow gradient sweeping diagonally across the whole card (teal, violet, pink, gold), fine sparkle and glitter texture, shimmering light glare streaks, the engraved lines stay dark and crisp on top of the foil. It must look unmistakably like a shiny holo card, far more vivid than a regular card."
R[signature]="${KEEP2}SIGNATURE rarity, dominated by gold: the entire outer frame becomes a thick band of solid, shiny, embossed metallic gold foil (no black left in the frame), gold corner ornaments, gold sun and moon, a gold rim around the red halo, and the title cartouche in gold with dark lettering. Warm golden light reflections across the card. Add a small edition number \"07/50\" in the lower right corner of the frame and a handwritten gold signature stroke across the lower part of the illustration. It must read instantly as the gold card."
R[legendaire]="${KEEP2}Turn it into a LEGENDARY ultra-rare card: invert the engraving into a negative, the whole card is glossy pitch-black foil and every engraved line of the illustration is rendered in glowing crimson red and molten gold ink, keeping the face clearly lit and readable. The halo becomes a burning ring of fire, glowing embers and sparks float around the musician, the ornate frame is black obsidian with blood-red gemstones in the corners, subtle dark holographic sheen. Ominous, precious, unmistakably the rarest card."
for r in commune rare holo signature legendaire; do
  [ -s "assets/da/creas/$id-$r.jpg" ] && { echo "$id-$r : déjà là"; continue; }
  echo -n "$id-$r : "
  python3 tools/krea_generate.py --model google/nano-banana-pro --ratio 2:3 --timeout 600 --image-url "$BASE" --out "assets/da/creas/$id-$r.jpg" --prompt "${R[$r]}" 2>&1 | tail -1 | sed -E 's/ \(source.*//'
done
