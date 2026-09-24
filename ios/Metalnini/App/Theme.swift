import SwiftUI
import MetalniniKit

/// Couleurs et typographie de la DA : chrome d'app sombre et sobre, couleur réservée aux raretés.
enum Theme {
    static let background = Color(red: 0.047, green: 0.043, blue: 0.039)
    static let surface = Color(red: 0.086, green: 0.078, blue: 0.071)
    static let text = Color(red: 0.953, green: 0.941, blue: 0.918)
    static let muted = Color(red: 0.643, green: 0.620, blue: 0.580)
    static let accent = Color(red: 0.698, green: 0.227, blue: 0.227)
    static let gold = Color(red: 0.831, green: 0.686, blue: 0.216)

    static func color(_ rarity: Rarity) -> Color {
        switch rarity {
        case .commune: Color(red: 0.54, green: 0.54, blue: 0.57)
        case .rare: Color(red: 0.23, green: 0.51, blue: 0.96)
        case .holo: Color(red: 0.65, green: 0.55, blue: 0.98)
        case .signature: gold
        case .legendaire: Color(red: 0.86, green: 0.15, blue: 0.15)
        }
    }

    static func label(_ rarity: Rarity) -> String {
        switch rarity {
        case .commune: "Commune"
        case .rare: "Rare"
        case .holo: "Holo"
        case .signature: "Signature"
        case .legendaire: "Légendaire"
        }
    }

    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .default).width(.condensed) }
}

/// Visuels embarqués (dossier `cards` partagé avec le prototype web).
enum CardImages {
    static func url(_ name: String) -> URL? { Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: "cards") }
    static func card(_ key: CardKey) -> URL? { url("\(key.musicianID)-\(key.rarity.rawValue)") }
    static var back: URL? { url("back") }
    static func pack(_ id: String) -> URL? { url("pack-\(id == "mosh" ? "serie" : id)") }
}

/// Image locale chargée depuis le bundle, avec un fond neutre tant qu'elle n'est pas prête.
struct BundleImage: View {
    let url: URL?
    var body: some View {
        if let url, let img = UIImage(contentsOfFile: url.path) {
            Image(uiImage: img).resizable().scaledToFit()
        } else {
            Rectangle().fill(Theme.surface)
        }
    }
}
