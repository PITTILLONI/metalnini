import Foundation
import Supabase
import MetalniniKit

/// Accès au back-end Supabase. Le serveur décide du contenu des paquets et tient la collection ;
/// l'app ne fait qu'appeler ses fonctions (`open_pack`, `place_card`, `fuse_cards`) et lire son inventaire.
final class Backend: Sendable {
    static let shared = Backend()

    let client = SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.publishableKey)

    /// Compte du joueur : anonyme pour l'instant (Sign in with Apple viendra s'y rattacher).
    func ensureSession() async throws -> UUID {
        if let session = try? await client.auth.session { return session.user.id }
        return try await client.auth.signInAnonymously().user.id
    }

    /// Nouveau compte anonyme : repart d'une collection vide.
    func restartAsNewPlayer() async throws -> UUID {
        try? await client.auth.signOut()
        return try await client.auth.signInAnonymously().user.id
    }

    struct ProfileRow: Decodable, Sendable { let username: String? }

    func username() async throws -> String? {
        let rows: [ProfileRow] = try await client.from("profiles").select("username").limit(1).execute().value
        return rows.first?.username
    }

    /// Enregistre le pseudo (vérifié et rendu unique côté serveur) ; renvoie le pseudo retenu.
    func setUsername(_ name: String) async throws -> String {
        struct Params: Encodable, Sendable { let p_username: String }
        return try await client.rpc("set_username", params: Params(p_username: name)).execute().value
    }

    struct InventoryRow: Decodable, Sendable {
        let musician_id: String
        let rarity: String
        let copies: Int
        let placed: Bool
    }

    func collection() async throws -> PlayerCollection {
        let rows: [InventoryRow] = try await client.from("inventory").select("musician_id, rarity, copies, placed").execute().value
        var copies: [CardKey: Int] = [:], toPlace: [CardKey] = []
        for r in rows {
            guard let rarity = Rarity(rawValue: r.rarity), r.copies > 0 else { continue }
            let key = CardKey(r.musician_id, rarity)
            copies[key] = r.copies
            if !r.placed { toPlace.append(key) }
        }
        return PlayerCollection(copies: copies, toPlace: toPlace)
    }

    struct OpenedCard: Decodable, Sendable {
        let card_position: Int
        let musician_id: String
        let rarity: String
        let is_new: Bool
    }

    /// Ouvre un paquet côté serveur. `requestID` rend l'appel rejouable sans ouvrir deux paquets.
    func openPack(_ packType: String, requestID: UUID) async throws -> [(key: CardKey, isNew: Bool)] {
        struct Params: Encodable, Sendable { let p_pack_type: String; let p_request_id: UUID }
        let rows: [OpenedCard] = try await client.rpc("open_pack", params: Params(p_pack_type: packType, p_request_id: requestID)).execute().value
        return rows.compactMap { r in Rarity(rawValue: r.rarity).map { (CardKey(r.musician_id, $0), r.is_new) } }
    }

    /// Message lisible d'une erreur serveur (celles levées par nos fonctions SQL sont déjà en français).
    static func message(_ error: Error) -> String {
        if let e = error as? PostgrestError { return e.message }
        return error.localizedDescription
    }

    func place(_ key: CardKey) async throws {
        struct Params: Encodable, Sendable { let p_musician: String; let p_rarity: String }
        try await client.rpc("place_card", params: Params(p_musician: key.musicianID, p_rarity: key.rarity.rawValue)).execute()
    }

    func fuse(_ key: CardKey) async throws {
        struct Params: Encodable, Sendable { let p_musician: String; let p_rarity: String }
        try await client.rpc("fuse_cards", params: Params(p_musician: key.musicianID, p_rarity: key.rarity.rawValue)).execute()
    }
}
