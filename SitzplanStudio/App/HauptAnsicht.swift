import Domain
import SwiftUI

/// Die Wurzelansicht — Umschaltung zwischen Klassen und Räumen.
///
/// Schmale Abschnitts-Liste links (HStack, keine weitere `NavigationSplitView`),
/// rechts der gewählte Abschnitt, der dort jeweils **eigene** innere Split-Views
/// führt (KlassenListe bzw. RaeumeUebersicht).
///
/// Bewusst kein äußerer `NavigationSplitView`: verschachtelte Split-Views
/// kollabieren auf macOS im CI den inneren Detailbereich — die KlassenListe
/// würde ihren Leer-Hinweis nicht zeigen. Mit dem HStack verhält sich die innere
/// Split-View wie eine Root-Split-View (zwei Spalten, Detail sichtbar).
///
/// Die Abschnitts-Liste nutzt `Text` (kein `Label`): in einer Sidebar-Cell
/// würde `Label` zu einem Button mit kombinierter Accessibility — der Text
/// „Räume" wäre dann nicht als `staticText` auffindbar. `Text` bleibt ein
/// `staticText`, den die UITests klicken können.
///
/// `AppCommands` bleibt unberührt: Der Menübefehl `.neueKlasse` wirkt weiter,
/// weil er als Notification in `KlassenListe` ankommt, unabhängig davon, welche
/// Ansicht gerade rechts steht.
public struct HauptAnsicht: View {
    let umgebung: AppEnvironment
    @State private var abschnitt: Abschnitt? = .klassen

    enum Abschnitt: String, CaseIterable, Identifiable {
        case klassen = "Klassen"
        case raeume = "Räume"

        var id: String { rawValue }
    }

    public init(umgebung: AppEnvironment) {
        self.umgebung = umgebung
    }

    public var body: some View {
        HStack(spacing: 0) {
            seitenleiste
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ohneDarkMode()
    }

    // MARK: - Abschnitts-Liste

    private var seitenleiste: some View {
        List(selection: $abschnitt) {
            ForEach(Abschnitt.allCases) { abschnitt in
                Text(abschnitt.rawValue)
                    .tag(abschnitt)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Sitzplan Studio")
        .frame(width: 170)
    }

    // MARK: - Detail

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