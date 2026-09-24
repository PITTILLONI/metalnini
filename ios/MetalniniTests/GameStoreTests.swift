import Testing
import MetalniniKit
@testable import Metalnini

@MainActor
@Suite("GameStore")
struct GameStoreTests {
    @Test func openingAPackAddsFiveCardsToPlace() {
        let store = GameStore()
        store.openPack()
        #expect(store.lastPack.count == 5)
        #expect(store.collection.toPlace.count >= 1)
        store.placeAll()
        #expect(store.collection.toPlace.isEmpty)
    }

    @Test func stylePackOnlyDrawsItsBinder() {
        let store = GameStore()
        store.packType = Catalog.packTypes.first { $0.id == "poppunk" }!
        for _ in 0..<10 { store.openPack() }
        #expect(store.lastPack.allSatisfy { ["blink182", "hoppus"].contains($0.musicianID) })
    }

    @Test func bundledCardImagesExist() {
        for m in Catalog.musicians { for r in Rarity.allCases { #expect(CardImages.card(CardKey(m.id, r)) != nil, "\(m.id)-\(r)") } }
        #expect(CardImages.back != nil)
    }
}
