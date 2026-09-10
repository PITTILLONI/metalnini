# Metalnini — Architecture, parcours utilisateurs & mécaniques d'engagement

## 1. Architecture de navigation (IA)

Navigation basse à 5 entrées max :

1. **Accueil** — feed : nouvelles évolutions de cartes débloquées, actu des artistes suivis, événements à venir près de l'utilisateur, rappels de pack disponible.
2. **Collection** — l'album/binder : organisé par artiste, sous-genre, époque, festival. Barres de complétion par thème. Vues transversales par musicien et par instrument, indépendantes du regroupement par groupe.
3. **Packs** — ouverture de pack (gratuit régulier + payant) et boutique.
4. **Live** — carnet de concerts, avatar de fan, check-in événement, jauge d'ambiance, titres/achievements.
5. **Communauté** — échanges (troc), guildes par sous-genre/artiste, classements, profils publics d'autres fans.

Le profil personnel et les réglages sont accessibles depuis l'avatar en header (pas un onglet dédié), pour ne pas saturer la barre.

## 2. Inventaire d'écrans (par section)

**Onboarding**
- Choix des genres/artistes favoris
- Pack de bienvenue (offert) + premier reveal
- Intro courte à la boucle centrale (collection / évolution / concert)

**Accueil**
- Feed chronologique (évolutions, actu artiste, events à venir)
- Bannière pack disponible
- Accès rapide "prochain concert suivi"

**Collection**
- Vue d'ensemble par thème (grille + % complétion)
- Vue transversale "par musicien" — toutes les cartes Membre d'un même musicien, tous groupes confondus (side-projects, supergroupes)
- Vue transversale "par instrument" — ex. tous les batteurs ou bassistes suivis, tous groupes confondus
- Détail carte (recto/verso, historique d'évolution, rareté, origine d'obtention)
- Vue "collections en cours" vs "complétées"

*Point ouvert à trancher* : faut-il un binder unique filtrable par thème (structure actuelle), ou plusieurs classeurs distincts par sous-genre (ex. un classeur "Black metal", un classeur "Nu-metal") ? Un classeur par genre renforcerait l'identité de niche (cohérent avec les guildes par sous-genre) mais fragmenterait la vue d'ensemble et la lisibilité de la progression globale — à trancher avant maquettage de cet écran.

**Packs**
- Sélection de pack (gratuit du jour/semaine, payant, événementiel)
- Écran de reveal (le moment le plus chargé émotionnellement de l'app)
- Résumé post-ouverture (nouvelles cartes, doublons, suggestion d'échange si doublon)

**Live**
- Carnet de concerts (liste chronologique des shows vécus)
- Check-in concert (avant/pendant/après)
- Fiche avatar (traits débloqués, titres, XP par catégorie)
- Détail d'un concert passé (note d'ambiance, carte exclusive obtenue le cas échéant)

**Communauté**
- Recherche/liste de fans (par carte recherchée, par guilde)
- Fiche d'échange (proposition, cartes offertes/demandées, confirmation)
- Guilde (fil, classement interne, membres)
- Classements globaux (collection, avatar, guildes)

**Profil (perso)**
- Vitrine publique de collection
- Réglages, notifications, comptes liés

## 3. Parcours clés

### Flow A — Onboarding → premier pack
1. Choix de 3 à 5 artistes/sous-genres favoris.
2. Ouverture du pack de bienvenue (reveal immédiat, sans friction).
3. Landing sur Collection avec la/les cartes obtenues déjà placées → sentiment de progression instantané.
4. Prompt doux vers Live ("dis-nous le prochain concert que tu vas voir") — optionnel, non bloquant.

### Flow B — Ouverture de pack (boucle la plus fréquente)
1. Entrée depuis bannière Accueil ou onglet Packs.
2. Sélection du pack → animation de reveal (moment fort, à traiter en priorité en motion design plus tard).
3. Si nouvelle carte : ajout direct à la Collection avec highlight.
4. Si doublon : proposition immédiate "proposer en échange" (relie directement à Communauté, sans étape supplémentaire).
5. Si la carte obtenue déclenche une collection presque complète : nudge visible ("plus qu'1 carte pour compléter Sepultura — Early Years").

### Flow C — Évolution de carte (déclenché par une actu réelle artiste)
1. Trigger externe : sortie d'album / clip / date de concert / anniversaire.
2. Notification push ciblée uniquement aux détenteurs de la carte concernée.
3. Ouverture app → écran d'évolution dédié (avant/après animé) → carte mise à jour dans la Collection.
4. Optionnel : partage social du moment d'évolution (capture, pas de mécanique intrusive).

### Flow D — Concert / Live (check-in → avatar)
1. Avant le concert : check-in géolocalisé sur site (ou saisie manuelle si géoloc indisponible/refusée).
2. Pendant : jauge d'ambiance semi-automatique si fiable techniquement (sinon rien à faire pendant le show — pas de friction pendant l'expérience live réelle).
3. Après : écran "carnet de concert" — note déclarative (ambiance, son, mosh pit, moment marquant), attribution d'XP avatar, déblocage éventuel d'une carte exclusive liée à cette date/lieu.
4. Mise à jour du carnet de concerts + progression des titres avatar visible immédiatement.

### Flow E — Échange entre fans
1. Recherche d'un fan possédant la carte recherchée (via Communauté ou via un doublon proposé par un tiers).
2. Proposition d'échange (carte(s) contre carte(s), pas d'argent réel).
3. Acceptation/refus par l'autre fan.
4. Confirmation → mise à jour synchrone des deux collections + notification aux deux parties.

## 4. Mécaniques d'engagement (à pousser)

- **FOMO authentique, pas artificiel** : les triggers d'évolution/urgence viennent de vrais événements (sortie d'album, concert réel), jamais de timers fabriqués — cohérent avec une communauté qui déteste le marketing malhonnête.
- **Progression à deux axes** : collection de cartes (objet) + avatar/carnet de concerts (vécu). Un utilisateur qui a "fini" de collectionner un artiste garde une raison de revenir via son avatar, et inversement.
- **Scarcité liée à la présence réelle**, pas au paiement : les cartes exclusives de concert récompensent le fait d'y être, pas de payer plus.
- **Reconnaissance sociale par la niche** : guildes par sous-genre (le fan de black metal norvégien et le fan de nu-metal n'ont pas la même culture) → appartenance forte, classements internes valorisants même sans être "le meilleur" à l'échelle globale.
- **Nudges de complétion** : mise en avant discrète des collections presque terminées, sans notification agressive.
- **Réciprocité sociale immédiate** : un doublon obtenu propose tout de suite l'échange, réduisant la friction du flow E.

## 5. Anti-patterns à éviter explicitement
- Pas de compte à rebours artificiel sur les packs ("plus que 2h !") sans événement réel derrière.
- Pas de mécanique de perte punitive (streak qui pénalise fort une absence) — la communauté cible réagit mal à la pression commerciale.
- Pas de notification spam sur les évolutions : un artiste suivi = pertinent, le reste doit rester silencieux par défaut.
- Pas de mécanique de check-in concert qui capte des données de localisation en continu — check-in ponctuel et consenti uniquement.

## Statut
Architecture et parcours posés comme base de travail. Prochaine étape suggérée : détailler un flow en particulier (wireframes bas-fidélité) ou challenger/amender cette structure avant tout maquettage visuel.
