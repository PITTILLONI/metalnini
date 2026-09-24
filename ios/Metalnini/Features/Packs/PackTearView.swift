import SwiftUI
import MetalniniKit

/// Le sachet : on le déchire en glissant le doigt de gauche à droite sur le haut (ou on le touche pour une déchirure automatique).
/// Le contenu est demandé au serveur dès le début du geste ; la lueur de la déchirure annonce la meilleure carte.
struct PackTearView: View {
    let packID: String
    /// Meilleure rareté du paquet, connue dès que le serveur a répondu (sinon la lueur reste dorée).
    let tease: Rarity?
    let onBegin: () -> Void
    let onTorn: () -> Void

    @State private var progress: CGFloat = 0
    @State private var torn = false
    @State private var lastTick = 0

    private let flapRatio: CGFloat = 0.10

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .top) {
                // corps du sachet
                BundleImage(url: CardImages.pack(packID), maxPixel: 900)
                    .frame(width: w, height: h)
                    .mask(Rectangle().padding(.top, h * flapRatio))
                // rabat serti, qui s'arrache
                BundleImage(url: CardImages.pack(packID), maxPixel: 900)
                    .frame(width: w, height: h)
                    .mask(alignment: .top) { Rectangle().frame(height: h * flapRatio) }
                    .rotationEffect(.degrees(torn ? 38 : Double(-progress * 7)), anchor: .bottomTrailing)
                    .offset(x: torn ? w * 1.2 : 0, y: torn ? -h * 0.5 : -progress * 6)
                // ligne de déchirure lumineuse
                Capsule()
                    .fill(glow)
                    .frame(width: max(0, w * progress), height: 4)
                    .shadow(color: glow, radius: 10)
                    .shadow(color: glow, radius: 24)
                    .frame(width: w, alignment: .leading)
                    .offset(y: h * flapRatio - 2)
                    .opacity(torn ? 0 : 1)
            }
            .contentShape(Rectangle())
            .gesture(tearGesture(width: w))
            .onTapGesture { autoTear() }
            .accessibilityElement()
            .accessibilityLabel("Paquet, glisser pour déchirer")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { autoTear() }
        }
        .aspectRatio(0.578, contentMode: .fit)
        .shadow(color: .black.opacity(0.75), radius: 22, y: 20)
        .scaleEffect(torn ? 1.08 : 1)
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: torn)
    }

    private var glow: Color { tease.map(Theme.color) ?? Theme.gold }

    private func tearGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { v in
                guard !torn else { return }
                if progress == 0 { onBegin() }
                progress = min(1, max(0, v.translation.width / (width * 0.75)))
                let step = Int(progress * 10)
                if step != lastTick { lastTick = step; Haptics.shared.tick() }
                if progress >= 1 { finish() }
            }
            .onEnded { _ in
                guard !torn else { return }
                if progress > 0.6 { finish() } else { withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { progress = 0 }; lastTick = 0 }
            }
    }

    private func autoTear() {
        guard !torn else { return }
        onBegin()
        withAnimation(.easeInOut(duration: 0.55)) { progress = 1 }
        Task { try? await Task.sleep(for: .milliseconds(560)); finish() }
    }

    private func finish() {
        guard !torn else { return }
        progress = 1; torn = true
        Haptics.shared.tear()
        Task { try? await Task.sleep(for: .milliseconds(450)); onTorn() }
    }
}
