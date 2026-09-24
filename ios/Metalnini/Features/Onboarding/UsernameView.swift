import SwiftUI

/// Premier lancement : choix du pseudo (l'onboarding complet viendra plus tard).
struct UsernameView: View {
    @Environment(GameStore.self) private var store
    @State private var name = ""
    @State private var error: String?
    @State private var saving = false
    @FocusState private var focused: Bool

    private var valid: Bool { name.range(of: "^[A-Za-z0-9_.-]{3,20}$", options: .regularExpression) != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text("Bienvenue dans le pit").font(.caption.monospaced()).textCase(.uppercase).foregroundStyle(Theme.accent)
            Text("Choisis ton pseudo").font(Theme.display(34)).textCase(.uppercase)
            Text("C'est le nom que verront les autres fans. Tu pourras le changer plus tard.").foregroundStyle(Theme.muted)
            TextField("ex. Roi_du_pogo", text: $name)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .font(.title3).padding(14)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                .focused($focused)
                .submitLabel(.go).onSubmit { save() }
            Text("3 à 20 caractères : lettres, chiffres, point, tiret ou tiret bas.").font(.footnote).foregroundStyle(Theme.muted)
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
            Button(saving ? "Enregistrement…" : "C'est parti") { save() }
                .buttonStyle(Pill(filled: true))
                .disabled(!valid || saving)
                .opacity(valid ? 1 : 0.5)
            Spacer(); Spacer()
        }
        .padding(24)
        .background(Theme.background.ignoresSafeArea())
        .interactiveDismissDisabled()
        .onAppear { focused = true }
        .preferredColorScheme(.dark)
    }

    private func save() {
        guard valid, !saving else { return }
        saving = true
        Task {
            error = await store.chooseUsername(name.trimmingCharacters(in: .whitespaces))
            saving = false
            if error == nil { Haptics.shared.land() }
        }
    }
}
