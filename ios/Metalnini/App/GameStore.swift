import SwiftUI
import MetalniniKit

/// État de jeu côté app. En phase 0, le tirage est local (miroir des règles serveur) ;
/// en phase 1, `openPack` appellera la fonction serveur `open_pack` et ce store ne fera qu'afficher.
@MainActor
@Observable
final class GameStore {
    private(set) var collection = PlayerCollection()
    private(set) var lastPack: [CardKey] = []
    var odds: Odds = .standard
    var packType: PackType = Catalog.packTypes[0]

    private var rng = SystemRandomNumberGenerator()

    func openPack() {
        let pool = Catalog.pool(for: packType)
        guard let cards = try? PackDraw.pack(size: packType.size, pool: pool, odds: odds, using: &rng) else { return }
        for c in cards { collection.add(c) }
        lastPack = PackDraw.revealOrder(cards)
    }

    func place(_ key: CardKey) { collection.place(key) }
    func placeAll() { for k in collection.toPlace { collection.place(k) } }
    func reset() { collection = PlayerCollection(); lastPack = [] }
}
