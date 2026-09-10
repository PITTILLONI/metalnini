# Metalnini — Backlog d'idées & échelonnage produit

But de ce document : conserver toutes les idées évoquées qui ne font pas partie du MVP, pour ne rien perdre, sans polluer le concept de lancement (`CONCEPT.md`).

## Phase 2 — Ouverture publique (droits à l'image/musicaux)
Le concept utilise dès maintenant les vrais noms de groupes/musiciens et des portraits IA ressemblants, tolérable uniquement en usage privé (voir risques dans `CONCEPT.md`). Avant toute ouverture publique ou commerciale, il faut une solution sur ce point — pistes possibles à explorer avec un juriste : accords de licence par artiste/label (à envisager progressivement, pas en un seul big bang), ou repli sur des noms/portraits détournés (parodiques) si les accords ne sont pas atteignables à temps.

## Phase 2 — Hybride physique/digital
- Packs physiques vendus en merch stand / disquaires / festival.
- QR code ou tag NFC sur le pack physique → scan pour débloquer le jumeau numérique (la carte physique devient un objet d'affichage collector, la valeur "jeu" reste dans l'app).
- Bornes ou scan géolocalisé sur site (festival/concert) débloquant des cartes exclusives non obtenables ailleurs.
- "Passeport festival" agrégeant les scans d'une tournée/édition.
- Objets physiques réellement liés à des cartes Légendaires (médiator, ticket, setlist signée) pour les éditions ultra-limitées.

## Idées sociales à explorer plus tard
- Marketplace monétaire (revente contre argent réel) — **écarté pour l'instant** pour des raisons de cadre légal (loot-box) et de dérive spéculative ; à ne reconsidérer qu'avec un avis juridique dédié.
- Système de valeur symbolique de rareté pour équilibrer les échanges (sorte de "cote" indicative, non monétaire).
- Fonctionnalités "Metal Corner" approfondies : rencontres IRL facilitées entre fans présents au même événement, forums par guilde/sous-genre.
- Duels/mini-jeux entre avatars (sans dénaturer le positionnement "pas un jeu de combat" — à cadrer si exploré).

## Avatar & détection d'ambiance — pistes techniques
- Jauge d'ambiance automatique via accéléromètre/gyroscope : nécessite un spike technique pour valider la précision réelle (distinction pogo / wall of death / simple headbanging).
- Corroboration sociale : d'autres fans présents au même moment/lieu peuvent confirmer un moment vécu (renforce la fiabilité du déclaratif sans capteur).
- Liste de titres/achievements à étoffer au fil du temps (ambiance, social, fidélité, découverte) — conçue comme un système évolutif, pas figé au lancement.

## Production de cartes — pistes de scalabilité technique
- Pipeline de génération automatisée/scriptée des visuels de carte à partir d'une base de données (métadonnées artiste + photo → composition automatique sur le gabarit défini dans `DA.md`), une fois le template validé en design.

## Monétisation — pistes futures
- Bundle billetterie x festival (carte exclusive incluse dans certains billets).
- Extensions de contenu sponsorisées par labels/artistes au-delà du MVP.

## Rappel de cadrage
Toute mécanique impliquant de l'argent réel en lien avec des packs aléatoires ou la revente de cartes doit être validée par un juriste avant développement (risque loot-box / réglementation jeux d'argent selon les pays).
