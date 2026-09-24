import Foundation

/// Les cinq raretés, de la plus courante à la plus rare. L'ordre sert aux comparaisons et à la fusion.
public enum Rarity: String, CaseIterable, Codable, Sendable, Comparable {
    case commune, rare, holo, signature, legendaire

    public var rank: Int { Rarity.allCases.firstIndex(of: self)! }

    /// Rareté obtenue en fusionnant des doublons ; la Légendaire ne se fusionne pas.
    public var next: Rarity? {
        let all = Rarity.allCases
        return rank + 1 < all.count ? all[rank + 1] : nil
    }

    public static func < (lhs: Rarity, rhs: Rarity) -> Bool { lhs.rank < rhs.rank }
}

public enum Instrument: String, Codable, Sendable {
    case chant, guitare, basse, batterie, clavier
}

/// Un musicien représenté par une carte « Membre ». Chaque musicien existe dans les cinq raretés.
public struct Musician: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let name: String
    public let band: String
    public let arcanaTitle: String
    public let arcanaNumber: String
    public let instruments: [Instrument]
    public let subgenre: String

    /// Valeur du numéro d'arcane (IV = 4) : sert à ranger les emplacements comme les numéros d'un album.
    public var arcanaValue: Int {
        let v: [Character: Int] = ["I": 1, "V": 5, "X": 10, "L": 50, "C": 100]
        let digits = arcanaNumber.compactMap { v[$0] }
        return digits.indices.reduce(0) { t, i in i + 1 < digits.count && digits[i] < digits[i + 1] ? t - digits[i] : t + digits[i] }
    }

    public var mainInstrument: Instrument? { instruments.first }

    public init(id: String, name: String, band: String, arcanaTitle: String, arcanaNumber: String,
                instruments: [Instrument], subgenre: String) {
        self.id = id; self.name = name; self.band = band; self.arcanaTitle = arcanaTitle
        self.arcanaNumber = arcanaNumber; self.instruments = instruments; self.subgenre = subgenre
    }
}

/// Une carte précise : un musicien dans une rareté.
public struct CardKey: Hashable, Codable, Sendable, CustomStringConvertible {
    public let musicianID: String
    public let rarity: Rarity

    public init(_ musicianID: String, _ rarity: Rarity) { self.musicianID = musicianID; self.rarity = rarity }

    public var description: String { "\(musicianID)|\(rarity.rawValue)" }
}

public enum BinderKind: String, Codable, Sendable {
    case collection, style, instrument, band
}

/// Un classeur : une liste de musiciens à réunir, quelle que soit la rareté.
public struct Binder: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let kind: BinderKind
    public let label: String
    public let musicianIDs: [String]

    public init(id: String, kind: BinderKind, label: String, musicianIDs: [String]) {
        self.id = id; self.kind = kind; self.label = label; self.musicianIDs = musicianIDs
    }
}

/// Probabilités par rareté, tirées carte par carte (aucune rareté garantie).
public struct Odds: Codable, Sendable, Equatable {
    public var weights: [Rarity: Double]

    public init(_ weights: [Rarity: Double]) { self.weights = weights }

    public static let standard = Odds([.commune: 60, .rare: 25, .holo: 10, .signature: 4, .legendaire: 1])

    public var total: Double { Rarity.allCases.reduce(0) { $0 + max(0, weights[$1] ?? 0) } }
}

/// Un type de paquet : le Mosh Pack tire dans tout le catalogue, un paquet de style dans son classeur.
public struct PackType: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let label: String
    public let size: Int
    /// `nil` = tout le catalogue.
    public let binderID: String?

    public init(id: String, label: String, size: Int = 5, binderID: String? = nil) {
        self.id = id; self.label = label; self.size = size; self.binderID = binderID
    }
}
