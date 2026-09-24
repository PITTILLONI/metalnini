import SwiftUI
import MetalniniKit

/// État de jeu côté app.
/// Mode connecté : le serveur tire les paquets et tient la collection, l'app affiche.
/// Mode hors ligne (réseau indisponible, aperçus, tests) : tirage local selon les mêmes règles, rien n'est sauvegardé.
@MainActor
@Observable
final class GameStore {
    enum Mode: Equatable { case connecting, online(playerID: UUID), offline(reason: String) }

    private(set) var mode: Mode = .connecting
    private(set) var collection = PlayerCollection()
    private(set) var lastPack: [CardKey] = []
    private(set) var busy = false
    private(set) var errorMessage: String?
    var odds: Odds = .standard
    var packType: PackType = Catalog.packTypes[0]

    private let backend: Backend?
    private var rng = SystemRandomNumberGenerator()

    /// `backend: nil` = hors ligne (aperçus SwiftUI et tests).
    init(backend: Backend? = nil) {
        self.backend = backend
        if backend == nil { mode = .offline(reason: "aperçu") }
    }

    var isOnline: Bool { if case .online = mode { true } else { false } }

    func connect() async {
        guard let backend else { return }
        do {
            let id = try await backend.ensureSession()
            collection = try await backend.collection()
            mode = .online(playerID: id)
        } catch {
            mode = .offline(reason: error.localizedDescription)
        }
    }

    func openPack() async {
        guard !busy else { return }
        busy = true; errorMessage = nil
        defer { busy = false }
        if let backend, isOnline {
            do {
                let cards = try await backend.openPack(packType.id, requestID: UUID())
                lastPack = PackDraw.revealOrder(cards)
                collection = try await backend.collection()
            } catch { errorMessage = "Ouverture impossible : \(error.localizedDescription)" }
        } else {
            let pool = Catalog.pool(for: packType)
            guard let cards = try? PackDraw.pack(size: packType.size, pool: pool, odds: odds, using: &rng) else { return }
            for c in cards { collection.add(c) }
            lastPack = PackDraw.revealOrder(cards)
        }
    }

    func place(_ key: CardKey) async {
        collection.place(key)
        if let backend, isOnline { try? await backend.place(key) }
    }

    func placeAll() async {
        for k in collection.toPlace { await place(k) }
    }

    /// Hors ligne : vide la collection. Connecté : repart avec un nouveau compte anonyme.
    func reset() async {
        lastPack = []
        if let backend, isOnline {
            do {
                let id = try await backend.restartAsNewPlayer()
                collection = try await backend.collection()
                mode = .online(playerID: id)
            } catch { errorMessage = error.localizedDescription }
        } else {
            collection = PlayerCollection()
        }
    }
}
