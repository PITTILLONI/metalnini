import SwiftUI
import MetalniniKit

/// Classeur, phase 0 : choix du classeur, grille en 3 colonnes, progression, bac « à ranger ».
struct BinderView: View {
    @Environment(GameStore.self) private var store
    @State private var binderID = "all"

    private var binder: Binder { Catalog.binder(binderID) ?? Catalog.binders[0] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Catalog.binders) { b in
                                Button(b.label + (store.collection.isComplete(b) ? " ✓" : "")) { binderID = b.id }
                                    .font(.caption.monospaced()).textCase(.uppercase)
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(b.id == binderID ? Theme.accent.opacity(0.25) : Theme.surface, in: Capsule())
                                    .foregroundStyle(b.id == binderID ? Theme.text : Theme.muted)
                            }
                        }
                    }
                    let have = binder.musicianIDs.count - store.collection.missing(in: binder).count
                    ProgressView(value: Double(have), total: Double(max(1, binder.musicianIDs.count))) {
                        Text("\(have)/\(binder.musicianIDs.count)").font(.caption.monospaced()).foregroundStyle(Theme.muted)
                    }
                    .tint(Theme.gold)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                        ForEach(binder.musicianIDs, id: \.self) { id in slot(id) }
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle(binder.label)
            .safeAreaInset(edge: .bottom) { tray }
        }
    }

    @ViewBuilder private func slot(_ id: String) -> some View {
        let m = Catalog.musician(id)
        if let r = store.collection.placedBest(of: id) {
            VStack(alignment: .leading, spacing: 4) {
                BundleImage(url: CardImages.card(CardKey(id, r)))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.color(r), lineWidth: 2))
                    .overlay(alignment: .topTrailing) {
                        let n = store.collection.total(of: id)
                        if n > 1 { Text("×\(n)").font(Theme.display(16)).padding(5).background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 6)).padding(5) }
                    }
                Text(m?.name ?? id).font(.caption2.monospaced()).foregroundStyle(Theme.muted).lineLimit(1)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                BundleImage(url: CardImages.back).opacity(0.18)
                    .overlay(Text(m?.arcanaNumber ?? "?").font(Theme.display(22)).foregroundStyle(Theme.text.opacity(0.5)))
                Text("???").font(.caption2.monospaced()).foregroundStyle(Theme.muted)
            }
        }
    }

    @ViewBuilder private var tray: some View {
        if !store.collection.toPlace.isEmpty {
            HStack {
                Text("À ranger · \(store.collection.toPlace.count)").font(.caption.monospaced()).foregroundStyle(Theme.gold)
                Spacer()
                Button("Tout ranger") { withAnimation(.spring) { store.placeAll() } }
                    .font(Theme.display(15)).padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Theme.accent, in: Capsule()).foregroundStyle(Theme.text)
            }
            .padding(.horizontal).padding(.vertical, 10)
            .background(Theme.surface)
        }
    }
}

#Preview { BinderView().environment(GameStore()).preferredColorScheme(.dark) }
