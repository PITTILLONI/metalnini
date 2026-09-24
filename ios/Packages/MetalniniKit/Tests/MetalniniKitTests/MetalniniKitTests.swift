import Testing
@testable import MetalniniKit

@Suite("Catalogue")
struct CatalogTests {
    @Test func everyBinderMemberExists() {
        for b in Catalog.binders { for id in b.musicianIDs { #expect(Catalog.musician(id) != nil, "\(b.id) → \(id)") } }
    }

    @Test func styleBindersCoverEachMusicianExactlyOnce() {
        let styles = Catalog.binders.filter { $0.kind == .style }.flatMap(\.musicianIDs)
        #expect(styles.count == Catalog.musicians.count)
        #expect(Set(styles) == Set(Catalog.musicians.map(\.id)))
    }

    @Test func arcanaNumbersParseAndAreUnique() {
        #expect(Catalog.musician("knocked-loose")!.arcanaValue == 4)
        #expect(Catalog.musician("ramos")!.arcanaValue == 14)
        #expect(Catalog.musician("heriot")!.arcanaValue == 18)
        #expect(Catalog.musician("jordison")!.arcanaValue == 21)
        #expect(Set(Catalog.musicians.map(\.arcanaValue)).count == Catalog.musicians.count)
    }

    @Test func stylePackPoolIsItsBinder() {
        let pack = Catalog.packTypes.first { $0.id == "metalcore" }!
        #expect(Set(Catalog.pool(for: pack)) == Set(Catalog.binder("metalcore")!.musicianIDs))
        #expect(Catalog.pool(for: pack).contains("spiritbox") && !Catalog.pool(for: pack).contains("korn"))
        #expect(Catalog.pool(for: Catalog.packTypes[0]).count == Catalog.musicians.count)
    }
}

@Suite("Tirage")
struct DrawTests {
    @Test func packHasRequestedSizeAndStaysInPool() throws {
        var rng = SeededGenerator(seed: 42)
        let pool = ["korn", "root"]
        let cards = try PackDraw.pack(size: 5, pool: pool, odds: .standard, using: &rng)
        #expect(cards.count == 5)
        #expect(cards.allSatisfy { pool.contains($0.musicianID) })
    }

    @Test func sameSeedSameDraw() throws {
        var a = SeededGenerator(seed: 7), b = SeededGenerator(seed: 7)
        #expect(try PackDraw.pack(size: 5, pool: Catalog.musicians.map(\.id), odds: .standard, using: &a)
                == PackDraw.pack(size: 5, pool: Catalog.musicians.map(\.id), odds: .standard, using: &b))
    }

    /// Sur 200 000 tirages, chaque rareté doit tomber à moins de 0,5 point de sa probabilité.
    @Test func observedRatesMatchOdds() throws {
        var rng = SeededGenerator(seed: 2026)
        let n = 200_000
        var counts: [Rarity: Int] = [:]
        for _ in 0..<n { counts[try PackDraw.rarity(.standard, using: &rng), default: 0] += 1 }
        for r in Rarity.allCases {
            let observed = Double(counts[r, default: 0]) / Double(n) * 100
            #expect(abs(observed - Odds.standard.weights[r]!) < 0.5, "\(r): \(observed) %")
        }
    }

    @Test func certainOddsAlwaysGiveThatRarity() throws {
        var rng = SeededGenerator(seed: 1)
        let odds = Odds([.legendaire: 100])
        for _ in 0..<100 { #expect(try PackDraw.rarity(odds, using: &rng) == .legendaire) }
    }

    @Test func invalidOddsOrEmptyPoolAreRejected() {
        var rng = SeededGenerator(seed: 1)
        #expect(throws: PackDraw.DrawError.invalidOdds) { try PackDraw.rarity(Odds([:]), using: &rng) }
        #expect(throws: PackDraw.DrawError.emptyPool) { try PackDraw.pack(size: 5, pool: [], odds: .standard, using: &rng) }
    }

    @Test func revealGoesFromCommonToRarest() {
        let cards = [CardKey("a", .legendaire), CardKey("b", .commune), CardKey("c", .holo), CardKey("d", .commune)]
        #expect(PackDraw.revealOrder(cards).map(\.rarity) == [.commune, .commune, .holo, .legendaire])
        #expect(PackDraw.revealOrder(cards).prefix(2).map(\.musicianID) == ["b", "d"])
    }
}

@Suite("Collection")
struct CollectionTests {
    @Test func newVariantsWaitToBePlaced() {
        var c = PlayerCollection()
        let first = c.add(CardKey("korn", .rare)), second = c.add(CardKey("korn", .rare))
        #expect(first)
        #expect(!second)
        #expect(c.count(CardKey("korn", .rare)) == 2)
        #expect(c.toPlace == [CardKey("korn", .rare)])
        #expect(c.placedBest(of: "korn") == nil)
        c.place(CardKey("korn", .rare))
        #expect(c.placedBest(of: "korn") == .rare)
    }

    @Test func binderCompletesWhenEveryMusicianIsPlaced() {
        let b = Catalog.binder("g-blink")!   // Travis Barker et Mark Hoppus
        var c = PlayerCollection()
        c.add(CardKey("blink182", .commune)); c.place(CardKey("blink182", .commune))
        #expect(!c.isComplete(b)); #expect(c.missing(in: b) == ["hoppus"])
        c.add(CardKey("hoppus", .holo))
        #expect(!c.isComplete(b), "pas encore rangée")
        c.place(CardKey("hoppus", .holo))
        #expect(c.isComplete(b))
    }

    @Test func fusionKeepsOneCopyAndGivesNextRarity() throws {
        var c = PlayerCollection(copies: [CardKey("korn", .commune): 6])
        let got = try c.fuse(CardKey("korn", .commune), cost: 5)
        #expect(got == CardKey("korn", .rare))
        #expect(c.count(CardKey("korn", .commune)) == 1)
        #expect(c.count(CardKey("korn", .rare)) == 1)
        #expect(c.toPlace.contains(CardKey("korn", .rare)))
    }

    @Test func fusionRules() {
        var c = PlayerCollection(copies: [CardKey("korn", .commune): 5, CardKey("korn", .legendaire): 9])
        #expect(throws: PlayerCollection.FusionError.notEnoughDuplicates) { try c.fuse(CardKey("korn", .commune), cost: 5) }
        #expect(throws: PlayerCollection.FusionError.maxRarity) { try c.fuse(CardKey("korn", .legendaire), cost: 5) }
    }

    @Test func masteryNeedsAllFiveRaritiesPlaced() {
        var c = PlayerCollection()
        for r in Rarity.allCases { c.add(CardKey("slash", r)) }
        #expect(!c.isMastered("slash"))
        for r in Rarity.allCases { c.place(CardKey("slash", r)) }
        #expect(c.isMastered("slash"))
    }
}
