import Domain
import SwiftUI

/// Die Wurzelansicht — Umschaltung zwischen Klassen und Räumen.
///
/// Ein äußerer `NavigationSplitView` mit schmaler Seitenleiste; der Detailbereich
/// zeigt den gewählten Abschnitt, der dort jeweils **eigene** innere Split-Views
/// führt (KlassenListe bzw. RaeumeUebersicht). Verschachtelte Split-Views
/// expandieren auf macOS in ihren Detailbereich — drei Spalten gesamt.
///
/// `AppCommands` bleibt unberührt: Der Menübefehl `.neueKlasse` wirkt weiter,
/// weil er als Notification in `KlassenListe` ankommt, unabhängig davon, welche
/// Ansicht gerade im Detail steht.
public struct HauptAnsicht: View {
    let umgebung: AppEnvironment
    @State private var abschnitt: Abschnitt? = .klassen

    enum Abschnitt: String, CaseIterable, Identifiable {
        case klassen = "Klassen"
        case raeume = "Räume"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .klassen: "person.3"
            case .raeume: "rectangle.group"
            }
        }
    }

    public init(umgebung: AppEnvironment) {
        self.umgebung = umgebung
    }

    public var body: some View {
        NavigationSplitView {
            List(Abschnitt.allCases, selection: $abschnitt) { abschnitt in
                Label(abschnitt.rawValue, systemImage: abschnitt.symbol)
                    .tag(abschnitt)
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: 170)
            .listStyle(.sidebar)
            .navigationTitle("Sitzplan Studio")
        } detail: {
            detail
        }
        .ohneDarkMode()
    }

    @ViewBuilder
    private var detail: some View {
        switch abschnitt {
        case .klassen:
            KlassenListe(
                modell: KlassenModell(repository: umgebung.klassen),
                schuelerRepo: umgebung.schueler,
                sitzregelRepo: umgebung.sitzregeln
            )

        case .raeume:
            RaeumeUebersicht(
                modell: RaumModell(repository: umgebung.raeume)
            )

        case .none:
            Text("Wählen Sie einen Abschnitt.")
                .foregroundStyle(.secondary)
        }
    }
}