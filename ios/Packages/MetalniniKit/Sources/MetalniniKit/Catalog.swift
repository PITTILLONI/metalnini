import Foundation

/// Catalogue de la Série I. En production il vient du serveur (géré depuis l'admin) ;
/// cette copie locale sert aux aperçus SwiftUI, aux tests et au mode hors ligne.
/// Elle doit rester alignée sur `backend/supabase/seed.sql`.
public enum Catalog {
    public static let musicians: [Musician] = [
        .init(id: "knocked-loose", name: "Bryan Garris", band: "Knocked Loose", arcanaTitle: "The Deadringer", arcanaNumber: "IV", instruments: [.chant], subgenre: "Hardcore"),
        .init(id: "isaac-hale", name: "Isaac Hale", band: "Knocked Loose", arcanaTitle: "Counting Worms", arcanaNumber: "X", instruments: [.guitare], subgenre: "Hardcore"),
        .init(id: "jinjer", name: "Tatiana Shmayluk", band: "Jinjer", arcanaTitle: "Pisces", arcanaNumber: "V", instruments: [.chant], subgenre: "Metalcore progressif"),
        .init(id: "spiritbox", name: "Courtney LaPlante", band: "Spiritbox", arcanaTitle: "Holy Roller", arcanaNumber: "VI", instruments: [.chant], subgenre: "Metalcore"),
        .init(id: "landmvrks", name: "Florent Salfati", band: "Landmvrks", arcanaTitle: "Lost in the Waves", arcanaNumber: "VIII", instruments: [.chant], subgenre: "Metalcore"),
        .init(id: "ramos", name: "Will Ramos", band: "Lorna Shore", arcanaTitle: "To the Hellfire", arcanaNumber: "XIV", instruments: [.chant], subgenre: "Deathcore"),
        .init(id: "heriot", name: "Debbie Gough", band: "Heriot", arcanaTitle: "Devoured by the Mouth of Hell", arcanaNumber: "XVIII", instruments: [.chant, .guitare], subgenre: "Metalcore"),
        .init(id: "duplantier", name: "Mario Duplantier", band: "Gojira", arcanaTitle: "Flying Whales", arcanaNumber: "XVI", instruments: [.batterie], subgenre: "Death metal progressif"),
        .init(id: "blink182", name: "Travis Barker", band: "Blink-182", arcanaTitle: "All the Small Things", arcanaNumber: "VII", instruments: [.batterie], subgenre: "Pop punk"),
        .init(id: "hoppus", name: "Mark Hoppus", band: "Blink-182", arcanaTitle: "What's My Age Again?", arcanaNumber: "XII", instruments: [.basse, .chant], subgenre: "Pop punk"),
        .init(id: "hendrix", name: "Jimi Hendrix", band: "Jimi Hendrix", arcanaTitle: "Purple Haze", arcanaNumber: "IX", instruments: [.guitare], subgenre: "Rock psychédélique"),
        .init(id: "korn", name: "Jonathan Davis", band: "Korn", arcanaTitle: "Freak on a Leash", arcanaNumber: "XI", instruments: [.chant], subgenre: "Nu metal"),
        .init(id: "poppy", name: "Poppy", band: "Poppy", arcanaTitle: "I Disagree", arcanaNumber: "XIII", instruments: [.chant], subgenre: "Métal expérimental"),
        .init(id: "slash", name: "Slash", band: "Guns N' Roses", arcanaTitle: "Welcome to the Jungle", arcanaNumber: "XV", instruments: [.guitare], subgenre: "Hard rock"),
        .init(id: "zack", name: "Zack de la Rocha", band: "Rage Against the Machine", arcanaTitle: "Bulls on Parade", arcanaNumber: "XVII", instruments: [.chant], subgenre: "Rap metal"),
        .init(id: "frusciante", name: "John Frusciante", band: "Red Hot Chili Peppers", arcanaTitle: "Under the Bridge", arcanaNumber: "XIX", instruments: [.guitare], subgenre: "Funk rock"),
        .init(id: "root", name: "Jim Root", band: "Slipknot", arcanaTitle: "Duality", arcanaNumber: "XX", instruments: [.guitare], subgenre: "Nu metal"),
        .init(id: "jordison", name: "Joey Jordison", band: "Slipknot", arcanaTitle: "Wait and Bleed", arcanaNumber: "XXI", instruments: [.batterie], subgenre: "Nu metal"),
    ]

    public static let binders: [Binder] = [
        .init(id: "all", kind: .collection, label: "Toutes les cartes", musicianIDs: musicians.map(\.id)),
        .init(id: "metalcore", kind: .style, label: "Metalcore", musicianIDs: ["spiritbox", "jinjer", "landmvrks", "heriot"]),
        .init(id: "hardcore", kind: .style, label: "Hardcore & extrême", musicianIDs: ["knocked-loose", "isaac-hale", "ramos", "duplantier"]),
        .init(id: "numetal", kind: .style, label: "Nu metal & alternatif", musicianIDs: ["korn", "root", "jordison", "zack", "poppy"]),
        .init(id: "poppunk", kind: .style, label: "Pop punk", musicianIDs: ["blink182", "hoppus"]),
        .init(id: "legendes", kind: .style, label: "Légendes du rock", musicianIDs: ["hendrix", "slash", "frusciante"]),
        .init(id: "batteurs", kind: .instrument, label: "Les batteurs", musicianIDs: ["blink182", "duplantier", "jordison"]),
        .init(id: "guitaristes", kind: .instrument, label: "Les guitaristes", musicianIDs: ["isaac-hale", "hendrix", "slash", "frusciante", "root"]),
        .init(id: "g-kl", kind: .band, label: "Knocked Loose", musicianIDs: ["knocked-loose", "isaac-hale"]),
        .init(id: "g-blink", kind: .band, label: "Blink-182", musicianIDs: ["blink182", "hoppus"]),
        .init(id: "g-slipknot", kind: .band, label: "Slipknot", musicianIDs: ["root", "jordison"]),
    ]

    public static let packTypes: [PackType] = [
        .init(id: "mosh", label: "Mosh Pack"),
        .init(id: "metalcore", label: "Metalcore", binderID: "metalcore"),
        .init(id: "hardcore", label: "Hardcore & extrême", binderID: "hardcore"),
        .init(id: "numetal", label: "Nu metal & alternatif", binderID: "numetal"),
        .init(id: "poppunk", label: "Pop punk", binderID: "poppunk"),
        .init(id: "legendes", label: "Légendes du rock", binderID: "legendes"),
    ]

    /// Nombre de doublons identiques nécessaires pour une fusion (réglable depuis l'admin).
    public static let fusionCost = 5

    public static func musician(_ id: String) -> Musician? { musicians.first { $0.id == id } }
    public static func binder(_ id: String) -> Binder? { binders.first { $0.id == id } }

    /// Musiciens dans lesquels tire un type de paquet.
    public static func pool(for pack: PackType) -> [String] {
        guard let id = pack.binderID, let b = binder(id) else { return musicians.map(\.id) }
        return b.musicianIDs
    }
}
