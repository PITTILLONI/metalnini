import Foundation

/// Règles de tirage d'un paquet.
/// En production, le tirage est fait par le serveur (fonction `open_pack`) : ce code en est le miroir,
/// utilisé pour les tests, la simulation des probabilités et l'aperçu hors ligne.
public enum PackDraw {
    public enum DrawError: Error, Equatable { case emptyPool, invalidOdds }

    /// Tire une rareté selon les poids ; chaque carte est tirée indépendamment.
    public static func rarity<G: RandomNumberGenerator>(_ odds: Odds, using rng: inout G) throws -> Rarity {
        let total = odds.total
        guard total > 0 else { throw DrawError.invalidOdds }
        var x = Double.random(in: 0..<total, using: &rng)
        for r in Rarity.allCases {
            let w = max(0, odds.weights[r] ?? 0)
            if x < w { return r }
            x -= w
        }
        return .commune
    }

    /// Tire le contenu d'un paquet dans une liste de musiciens.
    public static func pack<G: RandomNumberGenerator>(size: Int, pool: [String], odds: Odds,
                                                      using rng: inout G) throws -> [CardKey] {
        guard !pool.isEmpty else { throw DrawError.emptyPool }
        return try (0..<size).map { _ in
            CardKey(pool.randomElement(using: &rng)!, try rarity(odds, using: &rng))
        }
    }

    /// Ordre de révélation : de la moins rare à la plus rare, pour finir en apothéose.
    public static func revealOrder(_ cards: [CardKey]) -> [CardKey] {
        cards.enumerated().sorted { ($0.element.rarity, $0.offset) < ($1.element.rarity, $1.offset) }.map(\.element)
    }
}

/// Générateur déterministe (SplitMix64), pour des tests et des simulations reproductibles.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
