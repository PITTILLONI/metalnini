import SwiftUI
import MetalniniKit

/// Écran Paquets, phase 0 : choix du paquet et ouverture simple.
/// La mise en scène (déchirure, pile, retournement, raretés) arrive en phase 1, en Rive.
struct PacksView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    BundleImage(url: CardImages.pack(store.packType.id))
                        .frame(maxWidth: 220)
                        .shadow(color: .black.opacity(0.8), radius: 20, y: 18)
                        .accessibilityLabel("Paquet \(store.packType.label)")

                    Picker("Paquet", selection: $store.packType) {
                        ForEach(Catalog.packTypes) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.menu)

                    Button {
                        store.openPack()
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    } label: {
                        Text("Ouvrir un paquet").font(Theme.display(20)).textCase(.uppercase)
                            .padding(.horizontal, 28).padding(.vertical, 14)
                            .background(Theme.accent, in: Capsule())
                    }
                    .foregroundStyle(Theme.text)

                    if !store.lastPack.isEmpty {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                            ForEach(Array(store.lastPack.enumerated()), id: \.offset) { _, key in
                                VStack(spacing: 4) {
                                    BundleImage(url: CardImages.card(key))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.color(key.rarity), lineWidth: 2))
                                    Text(Theme.label(key.rarity)).font(.caption2.monospaced()).foregroundStyle(Theme.color(key.rarity))
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background)
            .navigationTitle("Metalnini")
        }
    }
}

#Preview { PacksView().environment(GameStore()).preferredColorScheme(.dark) }
