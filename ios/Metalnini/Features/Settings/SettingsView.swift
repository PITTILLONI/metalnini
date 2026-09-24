import SwiftUI
import MetalniniKit

/// Réglages de test (phase 0). En production, les probabilités se règlent dans l'espace admin.
struct SettingsView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section("Probabilités (tirées carte par carte)") {
                    ForEach(Rarity.allCases, id: \.self) { r in
                        Stepper(value: Binding(get: { store.odds.weights[r] ?? 0 }, set: { store.odds.weights[r] = max(0, $0) }), in: 0...100, step: 1) {
                            HStack { Text(Theme.label(r)).foregroundStyle(Theme.color(r)); Spacer(); Text("\(Int(store.odds.weights[r] ?? 0)) %").monospacedDigit() }
                        }
                    }
                    Text("Total : \(Int(store.odds.total)) %").foregroundStyle(store.odds.total == 100 ? Theme.muted : .red)
                }
                Section {
                    Button("Repartir de zéro", role: .destructive) { store.reset() }
                }
            }
            .navigationTitle("Réglages")
        }
    }
}
