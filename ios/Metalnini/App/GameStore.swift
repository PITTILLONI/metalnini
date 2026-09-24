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
    private(set) var lastPackNew: [Bool] = []
    /// Paquet demandé au serveur mais pas encore révélé.
    private(set) var pending: (cards: [CardKey], isNew: [Bool])?
    enum Tab: Hashable { case packs, binder, settings }
    var tab: Tab = .packs
    private(set) var username: String?
    /// Connecté mais sans pseudo : l'app le demande avant tout.
    var needsUsername: Bool { isOnline && username == nil }
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
            username = try await backend.username()
            mode = .online(playerID: id)
        } catch {
            mode = .offline(reason: error.localizedDescription)
        }
    }

    /// Renvoie un message d'erreur à afficher, ou nil si le pseudo est enregistré.
    func chooseUsername(_ name: String) async -> String? {
        guard let backend else { username = name; return nil }
        do { username = try await backend.setUsername(name); return nil }
        catch { return Backend.message(error) }
    }

    /// Demande le contenu du paquet (au serveur si connecté), dès le début de la déchirure.
    /// Le tirage est figé à ce moment : abandonner le geste ne relance rien.
    func prepareOpening() async {
        guard pending == nil, !busy else { return }
        busy = true; errorMessage = nil
        defer { busy = false }
        if let backend, isOnline {
            do {
                let got = try await backend.openPack(packType.id, requestID: UUID())
                pending = (got.map(\.key), got.map(\.isNew))
                collection = try await backend.collection()
            } catch { errorMessage = "Ouverture impossible : \(error.localizedDescription)" }
        } else {
            let pool = Catalog.pool(for: packType)
            guard let cards = try? PackDraw.pack(size: packType.size, pool: pool, odds: odds, using: &rng) else { return }
            let ordered = PackDraw.revealOrder(cards)
            pending = (ordered, ordered.map { collection.add($0) })
        }
    }

    /// Paquet révélé : il devient le dernier paquet ouvert.
    func finishOpening() {
        guard let p = pending else { return }
        lastPack = p.cards; lastPackNew = p.isNew; pending = nil
    }

    /// Ouverture sans mise en scène (tests, accessibilité).
    func openPack() async {
        await prepareOpening()
        finishOpening()
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
                username = nil
                mode = .online(playerID: id)
            } catch { errorMessage = error.localizedDescription }
        } else {
            collection = PlayerCollection()
        }
    }
}
