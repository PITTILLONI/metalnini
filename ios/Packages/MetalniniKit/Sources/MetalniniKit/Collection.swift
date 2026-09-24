import Foundation

/// La collection d'un joueur : exemplaires possédés par carte, et cartes encore « à ranger ».
/// Dans l'app, la source de vérité est le serveur ; ce type sert à l'affichage et aux calculs locaux.
public struct PlayerCollection: Codable, Sendable, Equatable {
    public private(set) var copies: [CardKey: Int]
    public private(set) var toPlace: [CardKey]

    public init(copies: [CardKey: Int] = [:], toPlace: [CardKey] = []) {
        self.copies = copies.filter { $0.value > 0 }
        self.toPlace = toPlace
    }

    public func count(_ key: CardKey) -> Int { copies[key] ?? 0 }

    public func total(of musicianID: String) -> Int {
        Rarity.allCases.reduce(0) { $0 + count(CardKey(musicianID, $1)) }
    }

    /// Ajoute une carte tirée. Une variante jamais possédée part dans le bac « à ranger ».
    @discardableResult
    public mutating func add(_ key: CardKey) -> Bool {
        let isNew = count(key) == 0
        copies[key, default: 0] += 1
        if isNew { toPlace.append(key) }
        return isNew
    }

    /// Range une carte du bac : elle apparaît alors dans les classeurs.
    public mutating func place(_ key: CardKey) { toPlace.removeAll { $0 == key } }

    /// Meilleure rareté rangée d'un musicien (ce que montre son emplacement), ou `nil`.
    public func placedBest(of musicianID: String) -> Rarity? {
        Rarity.allCases.reversed().first { r in
            let key = CardKey(musicianID, r)
            return count(key) > 0 && !toPlace.contains(key)
        }
    }

    /// Un classeur est complet quand chacun de ses musiciens a au moins une carte rangée.
    public func isComplete(_ binder: Binder) -> Bool {
        !binder.musicianIDs.isEmpty && binder.musicianIDs.allSatisfy { placedBest(of: $0) != nil }
    }

    public func missing(in binder: Binder) -> [String] {
        binder.musicianIDs.filter { placedBest(of: $0) == nil }
    }

    /// Maîtrise : les cinq raretés d'un musicien, toutes rangées.
    public func isMastered(_ musicianID: String) -> Bool {
        Rarity.allCases.allSatisfy { r in
            let key = CardKey(musicianID, r)
            return count(key) > 0 && !toPlace.contains(key)
        }
    }

    public enum FusionError: Error, Equatable { case notEnoughDuplicates, maxRarity }

    /// Fusion : `cost` doublons identiques donnent un exemplaire de la rareté suivante.
    /// On garde toujours au moins un exemplaire ; la Légendaire ne se fusionne pas.
    public mutating func fuse(_ key: CardKey, cost: Int) throws -> CardKey {
        guard let next = key.rarity.next else { throw FusionError.maxRarity }
        guard count(key) - 1 >= cost else { throw FusionError.notEnoughDuplicates }
        copies[key]! -= cost
        let target = CardKey(key.musicianID, next)
        add(target)
        return target
    }
}
