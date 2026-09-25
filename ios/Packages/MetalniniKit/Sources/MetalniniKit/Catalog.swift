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
        .init(id: "dickinson", name: "Bruce Dickinson", band: "Iron Maiden", arcanaTitle: "The Trooper", arcanaNumber: "XXII", instruments: [.chant], subgenre: "Heavy metal"),
        .init(id: "halford", name: "Rob Halford", band: "Judas Priest", arcanaTitle: "Breaking the Law", arcanaNumber: "XXIII", instruments: [.chant], subgenre: "Heavy metal"),
        .init(id: "ozzy", name: "Ozzy Osbourne", band: "Black Sabbath", arcanaTitle: "Paranoid", arcanaNumber: "XXIV", instruments: [.chant], subgenre: "Heavy metal"),
        .init(id: "lemmy", name: "Lemmy Kilmister", band: "Motörhead", arcanaTitle: "Ace of Spades", arcanaNumber: "XXV", instruments: [.basse, .chant], subgenre: "Heavy metal"),
        .init(id: "hetfield", name: "James Hetfield", band: "Metallica", arcanaTitle: "Master of Puppets", arcanaNumber: "XXVI", instruments: [.chant, .guitare], subgenre: "Thrash metal"),
        .init(id: "mustaine", name: "Dave Mustaine", band: "Megadeth", arcanaTitle: "Symphony of Destruction", arcanaNumber: "XXVII", instruments: [.guitare, .chant], subgenre: "Thrash metal"),
        .init(id: "araya", name: "Tom Araya", band: "Slayer", arcanaTitle: "Raining Blood", arcanaNumber: "XXVIII", instruments: [.basse, .chant], subgenre: "Thrash metal"),
        .init(id: "scott-ian", name: "Scott Ian", band: "Anthrax", arcanaTitle: "Madhouse", arcanaNumber: "XXIX", instruments: [.guitare], subgenre: "Thrash metal"),
        .init(id: "cobain", name: "Kurt Cobain", band: "Nirvana", arcanaTitle: "Smells Like Teen Spirit", arcanaNumber: "XXX", instruments: [.chant, .guitare], subgenre: "Grunge"),
        .init(id: "cornell", name: "Chris Cornell", band: "Soundgarden", arcanaTitle: "Black Hole Sun", arcanaNumber: "XXXI", instruments: [.chant], subgenre: "Grunge"),
        .init(id: "staley", name: "Layne Staley", band: "Alice in Chains", arcanaTitle: "Man in the Box", arcanaNumber: "XXXII", instruments: [.chant], subgenre: "Grunge"),
        .init(id: "grohl", name: "Dave Grohl", band: "Foo Fighters", arcanaTitle: "Everlong", arcanaNumber: "XXXIII", instruments: [.chant, .guitare], subgenre: "Rock alternatif"),
        .init(id: "keenan", name: "Maynard James Keenan", band: "Tool", arcanaTitle: "Schism", arcanaNumber: "XXXIV", instruments: [.chant], subgenre: "Metal progressif"),
        .init(id: "white-gluz", name: "Alissa White-Gluz", band: "Arch Enemy", arcanaTitle: "The Eagle Flies Alone", arcanaNumber: "XXXV", instruments: [.chant], subgenre: "Death metal mélodique"),
        .init(id: "corpsegrinder", name: "George Fisher", band: "Cannibal Corpse", arcanaTitle: "Hammer Smashed Face", arcanaNumber: "XXXVI", instruments: [.chant], subgenre: "Death metal"),
        .init(id: "tankian", name: "Serj Tankian", band: "System of a Down", arcanaTitle: "Toxicity", arcanaNumber: "XXXVII", instruments: [.chant], subgenre: "Metal alternatif"),
        .init(id: "sykes", name: "Oli Sykes", band: "Bring Me the Horizon", arcanaTitle: "Throne", arcanaNumber: "XXXVIII", instruments: [.chant], subgenre: "Metalcore"),
        .init(id: "hayley", name: "Hayley Williams", band: "Paramore", arcanaTitle: "Misery Business", arcanaNumber: "XXXIX", instruments: [.chant], subgenre: "Pop punk"),
        .init(id: "armstrong", name: "Billie Joe Armstrong", band: "Green Day", arcanaTitle: "Boulevard of Broken Dreams", arcanaNumber: "XL", instruments: [.chant, .guitare], subgenre: "Punk rock"),
        .init(id: "angus", name: "Angus Young", band: "AC/DC", arcanaTitle: "Highway to Hell", arcanaNumber: "XLI", instruments: [.guitare], subgenre: "Hard rock"),
        .init(id: "dio", name: "Ronnie James Dio", band: "Dio", arcanaTitle: "Holy Diver", arcanaNumber: "XLII", instruments: [.chant], subgenre: "Heavy metal"),
        .init(id: "doro", name: "Doro Pesch", band: "Warlock", arcanaTitle: "All We Are", arcanaNumber: "XLIII", instruments: [.chant], subgenre: "Heavy metal"),
        .init(id: "hammett", name: "Kirk Hammett", band: "Metallica", arcanaTitle: "Enter Sandman", arcanaNumber: "XLIV", instruments: [.guitare], subgenre: "Thrash metal"),
        .init(id: "mercury", name: "Freddie Mercury", band: "Queen", arcanaTitle: "Bohemian Rhapsody", arcanaNumber: "XLV", instruments: [.chant], subgenre: "Rock"),
        .init(id: "gerard-way", name: "Gerard Way", band: "My Chemical Romance", arcanaTitle: "Welcome to the Black Parade", arcanaNumber: "XLVI", instruments: [.chant], subgenre: "Emo"),
        .init(id: "bennington", name: "Chester Bennington", band: "Linkin Park", arcanaTitle: "Numb", arcanaNumber: "XLVII", instruments: [.chant], subgenre: "Nu metal"),
        .init(id: "prince", name: "Prince", band: "Prince", arcanaTitle: "Purple Rain", arcanaNumber: "XLVIII", instruments: [.chant, .guitare], subgenre: "Funk rock"),
    ]

    public static let binders: [Binder] = [
        .init(id: "all", kind: .collection, label: "Toutes les cartes", musicianIDs: musicians.map(\.id)),
        .init(id: "metalcore", kind: .style, label: "Metalcore", musicianIDs: ["spiritbox", "jinjer", "landmvrks", "heriot", "sykes"]),
        .init(id: "hardcore", kind: .style, label: "Hardcore & extrême", musicianIDs: ["knocked-loose", "isaac-hale", "ramos", "duplantier", "white-gluz", "corpsegrinder"]),
        .init(id: "numetal", kind: .style, label: "Nu metal & alternatif", musicianIDs: ["korn", "root", "jordison", "zack", "poppy", "tankian", "bennington"]),
        .init(id: "poppunk", kind: .style, label: "Pop punk", musicianIDs: ["blink182", "hoppus", "hayley", "armstrong", "gerard-way"]),
        .init(id: "legendes", kind: .style, label: "Légendes du rock", musicianIDs: ["hendrix", "slash", "frusciante", "angus", "mercury", "prince"]),
        .init(id: "heavy", kind: .style, label: "Heavy metal", musicianIDs: ["dickinson", "halford", "ozzy", "lemmy", "dio", "doro"]),
        .init(id: "thrash", kind: .style, label: "Thrash", musicianIDs: ["hetfield", "mustaine", "araya", "scott-ian", "hammett"]),
        .init(id: "grunge", kind: .style, label: "Grunge & alternatif", musicianIDs: ["cobain", "cornell", "staley", "grohl", "keenan"]),
        .init(id: "batteurs", kind: .instrument, label: "Les batteurs", musicianIDs: ["blink182", "duplantier", "jordison"]),
        .init(id: "guitaristes", kind: .instrument, label: "Les guitaristes", musicianIDs: ["isaac-hale", "hendrix", "slash", "frusciante", "root", "mustaine", "scott-ian", "angus", "hammett", "prince"]),
        .init(id: "bassistes", kind: .instrument, label: "Les bassistes", musicianIDs: ["hoppus", "lemmy", "araya"]),
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

    /// Doublons consommés pour transformer une rareté en la suivante : paliers ×2 (3, 6, 12, 24), réglables depuis l'admin.
    public static func fusionCost(from rarity: Rarity) -> Int {
        let tier = Rarity.allCases.firstIndex(of: rarity) ?? 0
        return 3 << tier
    }

    public static func musician(_ id: String) -> Musician? { musicians.first { $0.id == id } }
    public static func binder(_ id: String) -> Binder? { binders.first { $0.id == id } }

    /// Musiciens dans lesquels tire un type de paquet.
    public static func pool(for pack: PackType) -> [String] {
        guard let id = pack.binderID, let b = binder(id) else { return musicians.map(\.id) }
        return b.musicianIDs
    }
}
