// swift-tools-version: 6.0
// Logique de jeu partagée par l'app : modèles, règles de tirage, fusion, complétion.
// Aucune dépendance à l'interface ni au réseau, pour être testée isolément (`swift test`).
import PackageDescription

let package = Package(
    name: "MetalniniKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MetalniniKit", targets: ["MetalniniKit"]),
    ],
    targets: [
        .target(name: "MetalniniKit"),
        .testTarget(name: "MetalniniKitTests", dependencies: ["MetalniniKit"]),
    ]
)
