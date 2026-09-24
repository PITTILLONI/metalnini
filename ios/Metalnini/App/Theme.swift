import SwiftUI
import ImageIO
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

    static func label(_ instrument: Instrument) -> String {
        switch instrument {
        case .chant: "Chant"
        case .guitare: "Guitare"
        case .basse: "Basse"
        case .batterie: "Batterie"
        case .clavier: "Clavier"
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

/// Image locale du bundle, réduite à la taille d'affichage et mise en cache : décodée une seule fois,
/// hors du fil principal, pour que les grilles de cartes restent fluides.
struct BundleImage: View {
    let url: URL?
    var maxPixel: CGFloat = 600
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else { Rectangle().fill(Theme.surface).aspectRatio(2/3, contentMode: .fit) }
        }
        .task(id: url) { image = await ImageCache.shared.image(url, maxPixel: maxPixel) }
    }
}

actor ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    func image(_ url: URL?, maxPixel: CGFloat) -> UIImage? {
        guard let url else { return nil }
        let key = "\(url.lastPathComponent)@\(Int(maxPixel))" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: maxPixel,
                  kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return nil }
        let img = UIImage(cgImage: cg)
        cache.setObject(img, forKey: key)
        return img
    }
}
