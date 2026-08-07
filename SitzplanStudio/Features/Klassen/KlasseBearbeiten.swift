import SwiftUI

/// Anlegen und Umbenennen einer Klasse — dieselbe Maske, zwei Beschriftungen.
///
/// Genau **eine** Primäraktion: „Sichern“. Abbrechen ist eine Sekundäraktion und
/// liegt auf Escape, Sichern auf Enter.
struct KlasseBearbeiten: View {
    let titel: String
    @State private var name: String
    private let sichern: (String) async -> Bool

    @Environment(\.dismiss) private var schliessen
    @FocusState private var imFeld: Bool
    @State private var arbeitet = false

    init(titel: String, name: String, sichern: @escaping (String) async -> Bool) {
        self.titel = titel
        _name = State(initialValue: name)
        self.sichern = sichern
    }

    private var eingabeGueltig: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(titel)
                .font(.title2)
                .accessibilityAddTraits(.isHeader)

            TextField("Name der Klasse", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($imFeld)
                .accessibilityLabel("Name der Klasse")
                .onSubmit { if eingabeGueltig { starteSichern() } }

            Text("Zum Beispiel „7a“ oder „Deutsch Leistungskurs“.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Abbrechen") { schliessen() }
                    .keyboardShortcut(.cancelAction)

                Button("Sichern") { starteSichern() }
                    .buttonStyle(.borderedProminent)
                    .tint(Farbe.primaeraktion)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!eingabeGueltig || arbeitet)
            }
        }
        .padding(20)
        .frame(minWidth: 380)
        .onAppear { imFeld = true }
        .ohneDarkMode()
    }

    private func starteSichern() {
        guard eingabeGueltig, !arbeitet else { return }
        arbeitet = true
        Task {
            let erfolg = await sichern(name)
            arbeitet = false
            // Nur schliessen, wenn es geklappt hat. Sonst bliebe die Eingabe
            // der Lehrkraft auf der Strecke, waehrend die Fehlermeldung ins
            // Leere zeigt.
            if erfolg { schliessen() }
        }
    }
}
