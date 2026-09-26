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
| Or (accent, actif) | `--gold`, `--gold-hi`, `--gold-lo` | `#eb9a26`, `#f4b243`, `#b56c16` | 8,6:1 (réchauffé le 2026-09-25) |
| Rouge (fonds, pastilles) | `--accent` | `#b23a3a` | réservé aux fonds (texte blanc dessus 5,9:1) |
| Rouge (texte, surtitres) | `--accent-text` | `#e0605a` | 5,6:1 |
| Raretés | Commune `#c9c3b8`, Rare `#3b82f6`, Holo `#a78bfa`, Signature `#f5c542`, Légendaire `#ef4444` | toujours doublées d'un libellé (jamais la couleur seule) |

## Typographie
- Titres : **Big Shoulders Display** 800, capitales, interligne 0,95.
- Interface et texte : **Inter** 400 à 700 ; surtitres et libellés en capitales Inter 500-600, espacement 0,12-0,24 em.
- Aucun texte sous ~11 px (0,7 rem) ; corps de texte ≥ 14 px ; chiffres en `tabular-nums` (`.num`).

## Composants
- **Boutons** : un seul système, même hauteur (50 px) et même typo partout (Big Shoulders Display 800, capitales, 0,1 em), coins de 6 px.
  - Principal `.btn` « encre et or » (décidé le 2026-09-26, l'aplat jaune détonnait avec la DA des cartes) : fond noir d'encre, filet et lettres or, légère lueur dorée. Un seul par écran. `.btn.block` pour la pleine largeur.
  - Secondaire `.btn.ghost` : fond transparent, filet os fin.
  - Danger `.btn.danger` : rouge plein, toujours derrière une modale de confirmation.
- **Icône seule** `.icon-btn` : rond, filet or fin, `aria-label` obligatoire, 44 px minimum.
- **Bordures** : un seul filet fin (1 px). Pas de double bordure ni de double filet (retour utilisateur du 2026-09-25).
- **Surfaces** (tuiles, objectifs, modales) : `--surface`, filet `--border`, rayon 12-14 px, sans ombre intérieure.
- **Objectifs** : une ligne par objectif (texte, pourcentage, filet de progression de 3 px), à glisser, un point par objectif.
- **Barre d'onglets** : 2 entrées (Paquets, Classeur), fond encre, filet or fin, icônes SVG maison ; Réglages en haut à droite.
- **Icônes** : SVG au trait 1,4-2 px, `currentColor`. Pas d'emoji ni de glyphes Unicode comme icônes.

## Parcours Classeurs
1. **Catégories** en puces : Collection, Styles, Instruments, Groupes.
2. **Cartes de classeur** dans la catégorie (« Collection » : la carte « Toutes les cartes ») : vraie carte au format 2:3, illustrée par la meilleure carte rangée ou le dos Metalnini, nom gravé en bas, « x/N cartes », filet de progression, « Complet ✓ ».
3. **Page du classeur** : « ← catégorie », titre, progression, cases numérotées de 1 à N ; tri et affichage dans une feuille du bas (icône réglages).

## Parcours Paquets (deux temps)
1. **Choisir** : HUD, objectifs (masqués sur écran bas), « Choisis ton paquet du jour », carrousel (flèches sur ordinateur), nom du paquet du centre, format (1 gros de 5 cartes ou 2 petits de 2 cartes aux meilleures chances ; 2 points par jour, gros = 2, petit = 1). Toucher le paquet du centre le sélectionne ; « Ta sélection » montre une case (gros) ou deux (petits), chaque paquet avec ✕ pour le retirer ; changer de format garde le choix. Bouton « Ouvrir » dès qu'une case est remplie. Paquet du jour utilisé : « Le merch est fermé » et le temps restant.
2. **Ouvrir** : « ← Changer de paquet », nom et description du paquet, choix du format (1 gros paquet de 5 cartes ou 2 petits de 2 cartes aux meilleures chances ; 2 points par jour, gros = 2, petit = 1), paquet en grand, geste pour déchirer. Un paquet serveur entamé rouvre directement cette étape.

## Parcours Révélation et rangement
- **Révélation** : une carte à la fois ; phrase « combo » en bandeau incliné sur la carte (taille et couleur selon la rareté, ~3 s). La rangée du bas rouvre les cartes déjà vues. À la dernière carte : « Ranger dans le classeur » et partage (pas d'écran de résumé).
- **Rangement** : chaque carte s'affiche en grand, bonus en bandeau (lettrage Metal Mania) ; consigne sur deux lignes au-dessus ; un toucher range et passe à la suivante. Transformation proposée quand elle devient possible.

## Autres écrans
- **Profil** : page à part (avatar, pseudo, capacité de metaleux en texte, cri). La capacité se modifie dans une feuille du bas : idées proposées ou texte perso (120 caractères).
- **Format du paquet** : deux « mises » côte à côte (Standard · 5 cartes / Mini · 2 × 2, + de chances), picto de sachet à gauche, nom en Big Shoulders ; choisie = filet et lettres or avec lueur, l'autre en os discret.
- **Profil public** (« veste à patchs ») : médaillon photo cerclé d'or, pseudo, titre gagné en pastille (Groupie → Légende du pit), capacité en citation, bouton « Écouter son cri » ; vitrine de 3 cartes en éventail ; patchs ronds brodés (classeurs complétés, surpiqûre or en pointillés ; manquants en pointillés os) ; pin's de maîtrise ; setlist en tuiles. Plein écran, fermeture en haut à droite.
- **Notifications** : encadré arrondi à marges, en haut de l'écran ; descend et remonte, sans fondu ; une seule à la fois.
- **Fermer** : bouton rond en surimpression en haut à droite, il ne prend pas de place.

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
