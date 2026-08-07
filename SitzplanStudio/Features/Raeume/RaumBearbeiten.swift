import Domain
import SwiftUI

/// Anlegen und Bearbeiten eines Raums — dieselbe Maske, zwei Beschriftungen.
///
/// Genau **eine** Primäraktion: „Sichern". Abbrechen auf Escape, Sichern auf
/// Enter. Fachliche Pruefung der Masse vor dem Sichern — die Masse sind Vertrag
/// (`docs/datenvertrag.md`).
struct RaumBearbeiten: View {
    let titel: String
    @State private var name: String
    @State private var breiteCm: Double
    @State private var laengeCm: Double
    @State private var rasterCm: Double
    private let sichern: (String, Double, Double, Double) async -> String?

    @Environment(\.dismiss) private var schliessen
    @FocusState private var imFeld: Bool
    @State private var arbeitet = false
    @State private var fehlermeldung: String?

    init(
        titel: String,
        name: String = "",
        breiteCm: Double = 800,
        laengeCm: Double = 600,
        rasterCm: Double = Raster.standard,
        sichern: @escaping (String, Double, Double, Double) async -> String?
    ) {
        self.titel = titel
        _name = State(initialValue: name)
        _breiteCm = State(initialValue: breiteCm)
        _laengeCm = State(initialValue: laengeCm)
        _rasterCm = State(initialValue: rasterCm)
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

            TextField("Name des Raums", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($imFeld)
                .accessibilityLabel("Name des Raums")
                .onChange(of: name) { _, neu in
                    // migration.md: Name auf 80 Zeichen begrenzt.
                    if neu.count > 80 { name = String(neu.prefix(80)) }
                }
                .onSubmit { if eingabeGueltig { starteSichern() } }

            Text("Zum Beispiel: Raum 101 oder Fachraum Naturwissenschaften.")
                .font(.caption)
                .foregroundStyle(.secondary)

            masseFeld("Breite", wert: $breiteCm, hilfe: "In Zentimetern.")
            masseFeld("Länge", wert: $laengeCm, hilfe: "In Zentimetern.")
            masseFeld("Raster", wert: $rasterCm, hilfe: "Rasterweite in Zentimetern, selten geändert.")

            if let fehlermeldung {
                Text(fehlermeldung)
                    .font(.callout)
                    .foregroundStyle(Farbe.gefahr)
                    .accessibilityLabel("Fehler: \(fehlermeldung)")
            }

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
        .frame(minWidth: 420)
        .onAppear { imFeld = true }
        .ohneDarkMode()
    }

    private func masseFeld(_ bezeichnung: String, wert: Binding<Double>, hilfe: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(bezeichnung)
                    .frame(width: 80, alignment: .leading)
                    .accessibilityHidden(true)
                TextField(bezeichnung, value: wert, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("\(bezeichnung) in Zentimetern. \(hilfe)")
                Text("cm")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            Text(hilfe)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }

    private func starteSichern() {
        guard eingabeGueltig, !arbeitet else { return }
        // Fachliche Pruefung vor dem Sichern. Die Speicherschicht prueft noch
        // einmal — aber hier kommt die Fehlermeldung inline an die Lehrkraft,
        // bevor ein Speichernversuch unternommen wird.
        do {
            try Raum.pruefeMasse(breiteCm: breiteCm, laengeCm: laengeCm, rasterCm: rasterCm)
        } catch let fehler as Domaenenfehler {
            fehlermeldung = fehler.beschreibung
            return
        }
        fehlermeldung = nil
        arbeitet = true
        Task {
            let fehler = await sichern(name, breiteCm, laengeCm, rasterCm)
            arbeitet = false
            // Bei Erfolg schliessen, bei Misserfolg die Meldung inline zeigen
            // — nicht hinter dem Sheet, das die Lehrkraft gerade sieht.
            if let fehler {
                fehlermeldung = fehler
            } else {
                schliessen()
            }
        }
    }
}