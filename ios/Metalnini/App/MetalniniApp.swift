import SwiftUI

@main
struct MetalniniApp: App {
    @State private var store = GameStore(backend: .shared)

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
                .task {
                    await store.connect()
                    #if DEBUG
                    // Vérification de bout en bout : `-autoOpenPack` ouvre un paquet dès la connexion.
                    if ProcessInfo.processInfo.arguments.contains("-autoOpenPack") { await store.openPack() }
                    #endif
                }
        }
    }
}

struct RootView: View {
    @Environment(GameStore.self) private var store
    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.tab) {
            PacksView()
                .tabItem { Label("Paquets", systemImage: "moon.stars") }.tag(GameStore.Tab.packs)
            BinderView()
                .tabItem { Label("Classeur", systemImage: "square.grid.3x3") }.tag(GameStore.Tab.binder)
            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gearshape") }.tag(GameStore.Tab.settings)
        }
        .tint(Theme.gold)
        .fullScreenCover(isPresented: .constant(store.needsUsername)) { UsernameView() }
    }
}
