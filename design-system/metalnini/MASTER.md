# Metalnini — système de design (référence)

Source de vérité pour l'interface (prototype web et future app iOS). Les règles d'une page dans `pages/<page>.md` priment sur celles-ci. Établi le 2026-09-25 avec le skill `ui-ux-pro-max` (checklist d'avant livraison) ; les recommandations génériques du skill (vert feutre, Righteous/Poppins, 3D hyperréaliste) ont été écartées car contraires à la DA des cartes.

## Principe
Tarot gravé, moderne et élégant. L'interface est le cadre des cartes : noir d'encre, or, os, rouge sang. Jamais « site web » générique. Les cartes sont les héroïnes ; l'interface s'efface autour.

## Couleurs (jetons CSS de `proto/index.html`)
| Rôle | Jeton | Valeur | Contraste sur `--bg` |
|---|---|---|---|
| Fond | `--bg` / `--ink` | `#0c0b0a` / `#0d0a08` | — |
| Surfaces | `--surface`, `--surface-2` | `#161412`, `#1e1b18` | — |
| Texte | `--text` | `#f3f0ea` | 17:1 |
| Texte secondaire | `--muted` | `#a49e94` | 7,4:1 |
| Or (accent, actif) | `--gold`, `--gold-hi`, `--gold-lo` | `#d4af37`, `#f1d98a`, `#9c7a2a` | 9,4:1 |
| Rouge (fonds, pastilles) | `--accent` | `#b23a3a` | réservé aux fonds (texte blanc dessus 5,9:1) |
| Rouge (texte, surtitres) | `--accent-text` | `#e0605a` | 5,6:1 |
| Raretés | Commune `#c9c3b8`, Rare `#3b82f6`, Holo `#a78bfa`, Signature `#f5c542`, Légendaire `#ef4444` | toujours doublées d'un libellé (jamais la couleur seule) |

## Typographie
- Titres : **Big Shoulders Display** 800, capitales, interligne 0,95.
- Interface et texte : **Inter** 400 à 700 ; surtitres et libellés en capitales Inter 500-600, espacement 0,12-0,24 em.
- Aucun texte sous ~11 px (0,7 rem) ; corps de texte ≥ 14 px ; chiffres en `tabular-nums` (`.num`).

## Composants
- **Bouton principal** `.btn` : or gravé (dégradé `--gold-hi` → `--gold` → `--gold-lo`), texte encre, filet intérieur. Un seul par écran.
- **Secondaire** `.btn.ghost` : filet or. **Danger** `.btn.danger` : rouge sang, toujours derrière une modale de confirmation.
- **Icône seule** `.icon-btn` : rond, filet or, `aria-label` obligatoire, 44 px minimum.
- **Cartouche** (quêtes, modales) : double filet or (`inset 0 0 0 1px` + `5px` + `6px`), comme le cadre des cartes.
- **Barre d'onglets** : 2 entrées maximum (Paquets, Classeur), bandeau à double filet, icônes SVG maison ; Réglages en haut à droite.
- **Icônes** : SVG au trait 1,4-2 px, `currentColor`. Pas d'emoji ni de glyphes Unicode comme icônes.

## Interaction et mouvement
- Cibles tactiles ≥ 44 × 44 px, 8 px d'écart minimum ; retour visuel à l'appui (échelle 0,97-0,98 ou opacité).
- Focus clavier visible (`:focus-visible`, filet `--gold-hi`).
- Micro-interactions 150-300 ms ; grands moments (révélation, bonus) jusqu'à 1,6 s, toujours passables d'un toucher.
- N'animer que `transform` et `opacity` ; pas de flou ni de mode de fusion animés (performance mobile).
- `prefers-reduced-motion` : animations décoratives coupées, parcours intact.
- Effets plein écran dans un calque rogné (`#fxlayer`, `overflow:hidden`) : rien ne doit élargir la page.

## Mise en page
- Pensé pour 375-430 px de large ; vérifié en 375 × 560, 390 × 664, 430 × 932, paysage 844 × 390, et bureau.
- Zones de sécurité (`env(safe-area-inset-*)`) respectées en haut et en bas ; aucun contenu sous les barres fixes.
- Hauteurs calculées sur la place réelle (`dvh`, mesure JS pour le carrousel), jamais sur `100vh`.

## Contenu
- Ton rock'n'roll (guide dans `concept.html`, Ligne édito) : clair d'abord, une vanne par écran.
- Carte non trouvée : ni nom, ni groupe, ni titre ; classeur de groupe « Groupe mystère » tant qu'aucune carte du groupe n'est trouvée.

## Checklist d'avant livraison (extrait du skill, à cocher à chaque changement d'interface)
- [ ] Contraste texte ≥ 4,5:1 (secondaire ≥ 3:1)
- [ ] Cibles ≥ 44 px, retour à l'appui, focus visible
- [ ] Pas de défilement horizontal ; rien sous les barres ; paysage vérifié
- [ ] Mouvement réduit vérifié
- [ ] Champs avec libellé, erreurs près du champ
- [ ] Icônes SVG cohérentes, libellés d'accessibilité
