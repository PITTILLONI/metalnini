import SwiftUI

@main
struct MetalniniApp: App {
    @State private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
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
