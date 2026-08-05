import Domain
import SwiftUI

/// Die Klassenliste — die erste Ansicht, die eine Lehrkraft sieht.
///
/// Bedienung: Alles ist mit der Tastatur erreichbar. Umbenennen liegt auf ⌘R,
/// Loeschen auf ⌫, Anlegen auf ⌘N. Jede Aktion traegt eine
/// VoiceOver-Beschriftung, die den Namen der Klasse nennt, statt nur „Loeschen“
/// zu sagen.
public struct KlassenListe: View {
    @State private var modell: KlassenModell
    @State private var auswahl: Klasse.ID?
    @State private var legtAn = false
    @State private var benenntUm: Klasse?
    @State private var zeigtPapierkorb = false

    public init(modell: KlassenModell) {
        _modell = State(initialValue: modell)
    }

    public var body: some View {
        NavigationSplitView {
            seitenleiste
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            detail
        }
        .task { await modell.laden() }
        .sheet(isPresented: $legtAn) {
            KlasseBearbeiten(titel: "Neue Klasse", name: "") { name in
                await modell.anlegen(name: name)
            }
        }
        .sheet(item: $benenntUm) { klasse in
            KlasseBearbeiten(titel: "Klasse umbenennen", name: klasse.name) { name in
                await modell.umbenennen(klasse, auf: name)
            }
        }
        .alert(item: $modell.meldung) { meldung in
            Alert(
                title: Text(meldung.text),
                message: meldung.vorschlag.map(Text.init),
                dismissButton: .default(Text("OK"))
            )
        }
        .ohneDarkMode()
    }

    // MARK: - Seitenleiste

    private var seitenleiste: some View {
        List(selection: $auswahl) {
            Section("Klassen") {
                ForEach(modell.klassen) { klasse in
                    Text(klasse.name)
                        .tag(klasse.id)
                        .accessibilityLabel("Klasse \(klasse.name)")
                        .contextMenu {
                            Button("Umbenennen…") { benenntUm = klasse }
                            Button("Löschen", role: .destructive) {
                                Task { await modell.loeschen(klasse) }
                            }
                        }
                }
            }

            if !modell.papierkorb.isEmpty {
                Section {
                    Button {
                        zeigtPapierkorb = true
                    } label: {
                        Label(
                            "Papierkorb (\(modell.papierkorb.count))",
                            systemImage: "trash"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Papierkorb, \(modell.papierkorb.count) Einträge")
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    legtAn = true
                } label: {
                    Label("Neue Klasse", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("Neue Klasse anlegen (⌘N)")
            }
        }
        .sheet(isPresented: $zeigtPapierkorb) {
            Papierkorbansicht(eintraege: modell.papierkorb) { eintrag in
                await modell.wiederherstellen(eintrag)
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch modell.zustand {
        case .laedt:
            ProgressView().accessibilityLabel("Wird geladen")

        case .leer:
            LeerHinweis(
                symbol: "person.3",
                titel: "Noch keine Klasse",
                text: "Legen Sie Ihre erste Klasse an, um zu beginnen.",
                aktion: "Klasse anlegen"
            ) { legtAn = true }

        case .fehler(let text):
            LeerHinweis(
                symbol: "exclamationmark.triangle",
                titel: "Die Daten konnten nicht geladen werden",
                text: text,
                aktion: "Erneut versuchen"
            ) { Task { await modell.laden() } }

        case .gefuellt:
            if let gewaehlt = modell.klassen.first(where: { $0.id == auswahl }) {
                Klassendetail(klasse: gewaehlt) { benenntUm = gewaehlt }
            } else {
                Text("Wählen Sie eine Klasse.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Detailansicht

private struct Klassendetail: View {
    let klasse: Klasse
    let umbenennen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(klasse.name)
                .font(.largeTitle)
                .accessibilityAddTraits(.isHeader)

            if let notizen = klasse.notizen, !notizen.isEmpty {
                Text(notizen).foregroundStyle(.secondary)
            }

            Text("Schüler und Sitzpläne folgen im nächsten Meilenstein.")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Umbenennen…", action: umbenennen)
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}

// MARK: - Leerer Zustand

private struct LeerHinweis: View {
    let symbol: String
    let titel: String
    let text: String
    let aktion: String
    let ausfuehren: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(titel).font(.title2)
            Text(text)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Die eine Primaeraktion dieser Ansicht.
            Button(aktion, action: ausfuehren)
                .buttonStyle(.borderedProminent)
                .tint(Farbe.primaeraktion)
        }
        .padding(32)
        .frame(maxWidth: 420)
    }
}

// MARK: - Papierkorb

private struct Papierkorbansicht: View {
    let eintraege: [Papierkorbeintrag]
    let wiederherstellen: (Papierkorbeintrag) async -> Void

    @Environment(\.dismiss) private var schliessen

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Papierkorb")
                .font(.title2)
                .accessibilityAddTraits(.isHeader)
                .padding([.top, .horizontal], 20)

            List(eintraege) { eintrag in
                HStack {
                    VStack(alignment: .leading) {
                        Text(eintrag.bezeichnung)
                        if eintrag.mitgeloeschteAnzahl > 0 {
                            Text("mit \(eintrag.mitgeloeschteAnzahl) Schülern")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button("Wiederherstellen") {
                        Task { await wiederherstellen(eintrag) }
                    }
                    .accessibilityLabel("\(eintrag.bezeichnung) wiederherstellen")
                }
            }

            HStack {
                Spacer()
                Button("Fertig") { schliessen() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(minWidth: 420, minHeight: 320)
        .ohneDarkMode()
    }
}
