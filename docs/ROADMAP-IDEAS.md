# Metalnini — Backlog d'idées & échelonnage produit

But de ce document : conserver toutes les idées évoquées qui ne font pas partie du MVP, pour ne rien perdre, sans polluer le concept de lancement (`CONCEPT.md`).

## Phase 2 — Ouverture publique : stratégie droits à l'image

Le concept utilise dès maintenant les vrais noms de groupes/musiciens et des portraits IA ressemblants, tolérable uniquement en usage privé (voir risques dans `CONCEPT.md`). **Recadrage du problème** : viser "l'accord de tous les groupes" avant d'ouvrir n'a jamais été le plan (déjà écarté comme approche "big bang" — voir ci-dessous), mais même une approche progressive groupe par groupe se heurte à un taux de réponse naturellement bas. La stratégie doit donc surtout **réduire le nombre de portes auxquelles il faut frapper**, pas seulement accepter d'en frapper beaucoup.

**Les vrais noms ne bougent pas dans ce plan.** Les 4 leviers ci-dessous portent uniquement sur le portrait et sur *qui* est approché en premier — à aucun moment ils ne demandent de renoncer aux vrais groupes. C'est un choix assumé, pas un oubli : un faux groupe n'a structurellement pas le même impact qu'un vrai (voir `CONCEPT.md`, positionnement — c'est la raison même du choix des vrais noms), et ce plan est construit pour ne pas avoir à y toucher.

**Plan recommandé (produit/business, pas un avis juridique — voir la réserve en bas) :**

1. **Réduire la ressemblance des portraits par défaut, indépendamment de tout accord** — le levier le plus direct, et le seul qui ne dépend d'aucun tiers à convaincre. Le test "Sleeplot" (`DA.md`) a déjà validé qu'un gag visuel stylisé, sans photo-guidage précis, porte bien l'humour et l'effet "vraie carte de collection" recherchés. Le test Landmvrks à ressemblance guidée par photo reste la version la plus exposée testée à ce jour — à réserver aux artistes ayant explicitement donné leur accord, jamais au socle par défaut. Ça ne supprime pas le risque lié au nom réel, mais réduit fortement l'exposition sur le droit à l'image du portrait, qui est le risque le plus tranchant des deux identifiés dans `CONCEPT.md`.
2. **Ne pas viser un catalogue complet au lancement public** — un catalogue restreint aux artistes qui ont dit oui est un vrai produit, pas un MVP dégradé : c'est littéralement l'approche "par artiste/label, progressive" déjà retenue plus bas. Le reste du catalogue grandit ensuite.
3. **Cibler les portes qui s'ouvrent le plus facilement, pas la liste idéale** — des groupes émergents/indépendants en recherche de visibilité répondent structurellement mieux qu'un groupe installé sollicité par une inconnue. Passer par un label, un booker ou un festival qui représente plusieurs artistes réduit aussi le nombre de contacts nécessaires par rapport à un démarchage groupe par groupe.
4. **Présenter l'app comme un bénéfice pour l'artiste, pas une demande de faveur** — passer de « puis-je utiliser votre image » à « voici un outil d'engagement fan gratuit, qu'on aimerait construire avec vous » change la nature de la conversation. Amorce possible, à adapter par artiste : *« On construit une app de cartes à collectionner pour les fans de metal/rock, avec [artiste] déjà représenté dans un prototype privé — on adorerait vous montrer ce que ça donne et voir si ça vous intéresse d'en faire partie officiellement, sans coût de votre côté. »* Une prise de contact, pas un contrat — les termes se négocient après un accord de principe, pas avant.

**Ce qui ne change pas** : usage strictement privé pour l'instant (déjà acté), et validation par un avocat propriété intellectuelle/droit à l'image avant toute diffusion publique même limitée. En particulier, un point que ce document ne tranche pas et qu'il ne faut pas supposer réglé par la stylisation seule : l'**exception de parodie** protège certains usages du **droit d'auteur** en droit français, mais son étendue sur le **droit à l'image** d'une personne reconnaissable est un terrain distinct, régi par d'autres bases juridiques — à faire confirmer par un juriste, pas à assumer par analogie.

**Repli — dernier recours, pas une étape 5** : si, après avoir sérieusement tenté 1 à 4 sur une durée significative, le taux de réponse reste proche de zéro, l'option noms/portraits détournés (parodiques) reste documentée et techniquement viable (test Sleeplot). Elle n'est délibérément pas mise en avant comme suite logique du plan : un faux groupe n'a pas le même impact qu'un vrai — c'est justement pourquoi les vrais noms ont été choisis à l'origine (voir `CONCEPT.md`) — donc ce repli coûte quelque chose de réel à l'engagement, pas seulement une préférence esthétique. À activer en connaissance de ce coût, pas par défaut.

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
