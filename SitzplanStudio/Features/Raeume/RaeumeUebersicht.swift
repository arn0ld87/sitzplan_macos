import Domain
import SwiftUI

/// Räume-Übersicht — innere Split-View der HauptAnsicht (Abschnitt „Räume").
///
/// Seitenleiste: Raum-Liste mit Kontextmenü (Bearbeiten, Löschen). Detail: 2D-
/// Editor oder 3D-Ansicht, umschaltbar. `.id(raum.id)` erzwingt einen Reset des
/// Editors beim Raumwechsel, damit keine halbfertige Bearbeitung in den
/// nächsten Raum hinüberblutet.
///
/// Die List-Selection läuft über die Raum-ID (wie `KlassenListe`), nicht über
/// `Raum` selbst — `Raum` ist `Equatable`, nicht `Hashable`, und ein
/// Content-Hash über das `RaumDokument` wäre weder sinnvoll noch nötig.
///
/// **Kein Papierkorb** in dieser Iteration (siehe `RaumModell`). Löschen ist
/// weich — das Repository setzt `geloeschtAm` —, aber die Übersicht blendet
/// Gelöschte aus und bietet keine Wiederherstellung.
struct RaeumeUebersicht: View {
    @State var modell: RaumModell
    @State private var auswahlID: UUID?
    @State private var legtAn = false
    @State private var bearbeitet: Raum?
    @State private var loeschenFuer: Raum?
    @State private var ansicht: Ansicht = .zweiD

    enum Ansicht { case zweiD, dreiD }

    private var auswahl: Raum? {
        modell.raeume.first { $0.id == auswahlID }
    }

    var body: some View {
        NavigationSplitView {
            seitenleiste
                .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            detail
        }
        .task { await modell.laden() }
        .sheet(isPresented: $legtAn) {
            RaumBearbeiten(
                titel: "Neuen Raum anlegen",
                sichern: { name, breite, laenge, raster in
                    let angelegt = await modell.anlegen(
                        name: name,
                        breiteCm: breite,
                        laengeCm: laenge,
                        rasterCm: raster
                    )
                    if let angelegt { auswahlID = angelegt.id }
                    return angelegt != nil
                }
            )
        }
        .sheet(item: $bearbeitet) { raum in
            RaumBearbeiten(
                titel: "Raum bearbeiten",
                name: raum.name,
                breiteCm: raum.breiteCm,
                laengeCm: raum.laengeCm,
                rasterCm: raum.rasterCm,
                sichern: { name, breite, laenge, raster in
                    var neu = raum
                    neu.name = name
                    neu.breiteCm = breite
                    neu.laengeCm = laenge
                    neu.rasterCm = raster
                    let ok = await modell.aktualisieren(neu)
                    if ok { auswahlID = neu.id }
                    return ok
                }
            )
        }
        .alert(item: $modell.meldung) { meldung in
            Alert(
                title: Text(meldung.text),
                message: meldung.vorschlag.map(Text.init),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(item: $loeschenFuer) { raum in
            Alert(
                title: Text("Raum löschen?"),
                message: Text("\(raum.name) wird gelöscht."),
                primaryButton: .destructive(Text("Löschen")) {
                    Task {
                        await modell.loeschen(raum)
                        if auswahlID == raum.id { auswahlID = nil }
                    }
                },
                secondaryButton: .cancel(Text("Abbrechen"))
            )
        }
        .ohneDarkMode()
    }

    // MARK: Seitenleiste

    private var seitenleiste: some View {
        List(modell.raeume, selection: $auswahlID) { raum in
            Label(raum.name, systemImage: "rectangle.group")
                .contextMenu {
                    Button("Bearbeiten…") { bearbeitet = raum }
                    Button("Löschen…", role: .destructive) { loeschenFuer = raum }
                }
        }
        .overlay {
            // Nur bei `.leer` — während `.laedt` wäre die Liste leer, ohne dass
            // schon feststeht, ob Räume existieren (Copilot-Finding).
            if modell.raeume.isEmpty && modell.zustand == .leer {
                LeerHinweis(
                    symbol: "rectangle.group",
                    titel: "Noch keine Räume",
                    text: "Legen Sie Ihren ersten Raum an — mit Breite, Länge und Raster.",
                    aktion: "Neuen Raum anlegen",
                    ausfuehren: { legtAn = true }
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { legtAn = true } label: {
                    Label("Neuer Raum", systemImage: "plus")
                }
                // ⌘N ist global für „Neue Klasse" belegt (AppCommands). ⌘⇧N
                // für Räume vermeidet den Konflikt, ohne AppCommands anzufassen.
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        if let raum = auswahl {
            editorFuer(raum)
        } else {
            LeerHinweis(
                symbol: "rectangle.group",
                titel: "Kein Raum ausgewählt",
                text: "Wählen Sie links einen Raum oder legen Sie einen neuen an.",
                aktion: "Neuen Raum anlegen",
                ausfuehren: { legtAn = true }
            )
        }
    }

    @ViewBuilder
    private func editorFuer(_ raum: Raum) -> some View {
        switch ansicht {
        case .zweiD:
            RaumEditor(
                raum: raum,
                sichern: { neu in await modell.aktualisieren(neu) },
                zeige3D: { ansicht = .dreiD }
            )
            .id(raum.id)

        case .dreiD:
            RaumEditor3D(raum: raum, zeige2D: { ansicht = .zweiD })
                .id(raum.id)
        }
    }
}

/// Leerer Zustand — Symbol, Titel, Erklärung und eine Primäraktion.
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
            Text(titel)
                .font(.title3)
            Text(text)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(aktion, action: ausfuehren)
                .buttonStyle(.borderedProminent)
                .tint(Farbe.primaeraktion)
        }
        .padding(40)
        .frame(maxWidth: 360)
    }
}