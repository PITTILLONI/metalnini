import SwiftUI
import MetalniniKit

/// Révélation carte par carte, depuis une pile : glisser pour retourner la carte du dessus,
/// glisser à nouveau pour la lancer ; la suivante est déjà dessous. Rangée des cartes du paquet en bas.
/// Pas d'effets spéciaux par rareté pour l'instant (à concevoir séparément).
struct RevealView: View {
    let cards: [CardKey]
    let newFlags: [Bool]
    let onDone: (_ goToBinder: Bool) -> Void

    @State private var index = 0
    @State private var angle: Double = 0          // 0 = dos visible, ±180 = face visible
    @State private var flipped = false
    @State private var offset: CGSize = .zero
    @State private var showSummary = false
    @State private var pulled = false

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(red: 0.11, green: 0.05, blue: 0.05), .black], center: .center, startRadius: 20, endRadius: 600).ignoresSafeArea()
            if showSummary { summary } else { reveal }
        }
        .preferredColorScheme(.dark)
    }

    // ---------------------------------------------------------------- révélation
    private var reveal: some View {
        VStack(spacing: 18) {
            HStack {
                Text("Carte \(index + 1) / \(cards.count)").font(.caption.monospaced()).foregroundStyle(Theme.muted)
                Spacer()
                Button("Tout révéler") { withAnimation { showSummary = true } }.font(.caption.monospaced()).foregroundStyle(Theme.muted)
            }
            .padding(.horizontal)

            GeometryReader { geo in
                let size = cardSize(in: geo.size)
                ZStack {
                    // pile : les cartes pas encore retournées, légèrement décalées
                    ForEach(Array((index + 1)..<cards.count).reversed(), id: \.self) { i in
                        let depth = CGFloat(i - index)
                        BundleImage(url: CardImages.back, maxPixel: 700)
                            .frame(width: size.width, height: size.height)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
                            .offset(x: depth * 3, y: depth * 4)
                            .rotationEffect(.degrees(Double(depth) * (i.isMultiple(of: 2) ? -0.8 : 0.8)))
                    }
                    topCard(size: size)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .offset(y: pulled ? 0 : geo.size.height)
                .onAppear {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { pulled = true }
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-demoFlip") { Task { try? await Task.sleep(for: .seconds(2.5)); flip(direction: 1) } }
                    #endif
                }
            }

            info.frame(height: 56)

            Text(flipped ? "Glisse pour \(index < cards.count - 1 ? "la suivante" : "le résumé")" : "Glisse la carte pour la retourner")
                .font(.caption.monospaced()).textCase(.uppercase).foregroundStyle(Theme.muted)

            deckRow.padding(.bottom, 12)
        }
    }

    private func cardSize(in s: CGSize) -> CGSize {
        let w = min(s.width * 0.78, s.height * 0.667, 340)
        return CGSize(width: w, height: w * 1.5)
    }

    private func topCard(size: CGSize) -> some View {
        let key = cards[index]
        let showFront = abs(angle).truncatingRemainder(dividingBy: 360) > 90
        return ZStack {
            BundleImage(url: CardImages.back, maxPixel: 900)
                .opacity(showFront ? 0 : 1)
            BundleImage(url: CardImages.card(key), maxPixel: 1000)
                .scaleEffect(x: -1, y: 1)                     // la face est vue « de dos » pendant la rotation
                .opacity(showFront ? 1 : 0)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .rotation3DEffect(.degrees(angle), axis: (0, 1, 0), perspective: 0.55)
        .shadow(color: .black.opacity(0.6), radius: 16, y: 12)
        .offset(offset)
        .rotationEffect(.degrees(Double(offset.width / 22)))
        .gesture(drag(width: size.width))
        .onTapGesture { flipped ? next(direction: 1) : flip(direction: 1) }
        .accessibilityElement()
        .accessibilityLabel(flipped ? "\(Catalog.musician(key.musicianID)?.name ?? ""), \(Theme.label(key.rarity))" : "Carte face cachée")
        .accessibilityHint(flipped ? "Toucher pour la suivante" : "Toucher pour retourner")
        .id(index)
    }

    private func drag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { v in
                if flipped { offset = CGSize(width: v.translation.width, height: v.translation.height * 0.25) }
                else { angle = max(-78, min(78, v.translation.width / width * 160)) }   // la face ne se montre qu'une fois lâchée
            }
            .onEnded { v in
                if flipped {
                    let fast = abs(v.predictedEndTranslation.width) > width * 0.9
                    if abs(v.translation.width) > width * 0.28 || fast { next(direction: v.translation.width < 0 ? -1 : 1) }
                    else { withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { offset = .zero } }
                } else {
                    if abs(angle) >= 42 { flip(direction: angle > 0 ? 1 : -1) }
                    else { withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { angle = 0 } }
                }
            }
    }

    private func flip(direction: Double) {
        Haptics.shared.flip()
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) { angle = 180 * direction; flipped = true }
        Task { try? await Task.sleep(for: .milliseconds(320)); Haptics.shared.reveal(cards[index].rarity) }
    }

    private func next(direction: CGFloat) {
        Haptics.shared.toss()
        withAnimation(.easeIn(duration: 0.3)) { offset = CGSize(width: direction * 900, height: -40) }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            if index < cards.count - 1 {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { index += 1; angle = 0; flipped = false; offset = .zero }
            } else {
                withAnimation { showSummary = true }
            }
        }
    }

    @ViewBuilder private var info: some View {
        if flipped, let m = Catalog.musician(cards[index].musicianID) {
            let key = cards[index]
            VStack(spacing: 4) {
                Text(Theme.label(key.rarity)).font(.caption.monospaced().weight(.semibold)).textCase(.uppercase).foregroundStyle(Theme.color(key.rarity))
                HStack(spacing: 6) {
                    Text(m.name).font(Theme.display(22)).textCase(.uppercase)
                    let fresh = index < newFlags.count && newFlags[index]
                    Text(fresh ? "Nouveau" : "Doublon").font(.caption2.monospaced().weight(.bold)).textCase(.uppercase)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(fresh ? Theme.gold : Theme.surface, in: RoundedRectangle(cornerRadius: 3))
                        .foregroundStyle(fresh ? .black : Theme.muted)
                }
            }
            .transition(.offset(y: 6).combined(with: .opacity))
        }
    }

    private var deckRow: some View {
        HStack(spacing: 6) {
            ForEach(Array(cards.enumerated()), id: \.offset) { i, key in
                let done = i < index || (i == index && flipped)
                BundleImage(url: done ? CardImages.card(key) : CardImages.back, maxPixel: 160)
                    .frame(width: i == index ? 42 : 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(i == index ? Theme.gold : (done ? Theme.color(key.rarity) : .clear), lineWidth: 2))
                    .offset(y: i == index ? -6 : 0)
                    .animation(.spring(response: 0.3), value: index)
            }
        }
    }

    // ---------------------------------------------------------------- résumé
    private var summary: some View {
        VStack(spacing: 18) {
            Text("Ton paquet").font(Theme.display(28)).textCase(.uppercase)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(Array(cards.enumerated()), id: \.offset) { _, key in
                    VStack(spacing: 4) {
                        BundleImage(url: CardImages.card(key), maxPixel: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.color(key.rarity), lineWidth: 2))
                        Text(Theme.label(key.rarity)).font(.system(size: 9).monospaced()).foregroundStyle(Theme.color(key.rarity))
                    }
                }
            }
            .padding(.horizontal)
            HStack(spacing: 12) {
                Button("Ranger mes cartes") { onDone(true) }.buttonStyle(Pill(filled: true))
                Button("Fermer") { onDone(false) }.buttonStyle(Pill(filled: false))
            }
        }
        .padding()
    }
}

struct Pill: ButtonStyle {
    let filled: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(Theme.display(17)).textCase(.uppercase)
            .padding(.horizontal, 22).padding(.vertical, 12)
            .background(filled ? Theme.accent : Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(filled ? .clear : Theme.muted.opacity(0.3)))
            .foregroundStyle(Theme.text)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}
