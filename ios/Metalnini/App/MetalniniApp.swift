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
    var body: some View {
        TabView {
            PacksView()
                .tabItem { Label("Paquets", systemImage: "moon.stars") }
            BinderView()
                .tabItem { Label("Classeur", systemImage: "square.grid.3x3") }
            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gearshape") }
        }
        .tint(Theme.gold)
    }
}
