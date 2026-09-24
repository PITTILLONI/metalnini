import SwiftUI
import MetalniniKit

/// Écran Paquets : choix du paquet, déchirure, puis révélation plein écran.
struct PacksView: View {
    @Environment(GameStore.self) private var store
    @State private var revealing = false
    @State private var tearID = UUID()          // recrée le sachet (neuf) après chaque ouverture

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    PackTearView(packID: store.packType.id,
                                 tease: store.pending.map { PackDraw.revealOrder($0.cards).last?.rarity ?? .commune },
                                 onBegin: { Task { await store.prepareOpening() } },
                                 onTorn: { Task { await presentWhenReady() } })
                        .id(tearID)
                        .frame(maxWidth: 230)
                        .padding(.top, 8)
                        .disabled(store.mode == .connecting)

                    Text(store.busy ? "Ouverture…" : "Glisse le doigt sur le haut du paquet pour le déchirer →")
                        .font(.caption.monospaced()).textCase(.uppercase).foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)

                    Picker("Paquet", selection: $store.packType) {
                        ForEach(Catalog.packTypes) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .disabled(store.pending != nil)

                    if let err = store.errorMessage { Text(err).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center).padding(.horizontal) }
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background)
            .navigationTitle("Metalnini")
        }
        #if DEBUG
        .task(id: store.mode) {
            // démonstration pour captures : `-demoReveal` ouvre un paquet dès la connexion
            guard ProcessInfo.processInfo.arguments.contains("-demoReveal"), store.mode != .connecting, !revealing else { return }
            await store.prepareOpening(); revealing = store.pending != nil
        }
        #endif
        .fullScreenCover(isPresented: $revealing) {
            if let p = store.pending {
                RevealView(cards: p.cards, newFlags: p.isNew) { goToBinder in
                    store.finishOpening(); revealing = false; tearID = UUID()
                    if goToBinder { store.tab = .binder }
                }
            }
        }
    }

    /// Le serveur a souvent déjà répondu pendant la déchirure ; sinon on attend sa réponse.
    private func presentWhenReady() async {
        for _ in 0..<100 where store.pending == nil && store.errorMessage == nil { try? await Task.sleep(for: .milliseconds(100)) }
        if store.pending != nil { revealing = true } else { tearID = UUID() }
    }
}

#Preview { PacksView().environment(GameStore()).preferredColorScheme(.dark) }
