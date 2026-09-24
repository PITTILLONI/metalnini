# Metalnini — app iOS

App native **SwiftUI**, **iOS 17 minimum**. Phase 0 (fondations) : squelette de l'app, logique de jeu testée, catalogue de la Série I.

## Ouvrir le projet

```sh
brew install xcodegen      # une seule fois
cd ios && xcodegen         # génère Metalnini.xcodeproj depuis project.yml
open Metalnini.xcodeproj
```

Le projet Xcode n'est pas versionné : `project.yml` est la source. Pour installer l'app sur un iPhone, choisir une équipe dans *Signing & Capabilities* (un identifiant Apple gratuit suffit pour son propre téléphone, l'app expire alors au bout de 7 jours).

## Organisation

| Dossier | Rôle |
|---|---|
| `Packages/MetalniniKit` | Logique de jeu sans interface : modèles, tirage, fusion, rangement, complétion, maîtrise, catalogue. `swift test` depuis ce dossier. |
| `Metalnini/App` | Point d'entrée, thème (couleurs de la DA), `GameStore` (état de jeu) |
| `Metalnini/Features` | Écrans : Paquets, Classeur, Réglages |
| `MetalniniTests` | Tests de l'app |
| `../proto/cards` | Visuels des cartes, du dos et des paquets, partagés avec le prototype web |

## Tests

```sh
cd Packages/MetalniniKit && swift test
cd ../.. && xcodebuild -project Metalnini.xcodeproj -scheme Metalnini -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test
```

En phase 0 le tirage est local ; en phase 1 il passera par la fonction serveur `open_pack` (voir `../backend`).
