import Domain
import SwiftUI

/// Die Wurzelansicht — Umschaltung zwischen Klassen und Räumen.
///
/// Schmale Abschnitts-Liste links (HStack-Panel), rechts der gewählte
/// Abschnitt, der dort jeweils **eigene** innere `NavigationSplitView`s
/// führt (KlassenListe bzw. RaeumeUebersicht). Ein äußeres `NavigationSplitView`
/// ist nicht nötig: die inneren Split-Views expandieren in den Detailbereich
/// dieses HStacks, und das Panel ist einfacher als eine dritte Spalte.
///
/// Die Abschnitts-Umschaltung läuft über Buttons, nicht über
/// `List(selection:)`: der `Text` im Button-Label ist als `staticText`
/// auffindbar, was die RaeumeAblaufTests brauchen (`staticTexts["Räume"]`).
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
        VStack(spacing: 2) {
            ForEach(Abschnitt.allCases) { eintrag in
                Button {
                    abschnitt = eintrag
                } label: {
                    Text(eintrag.rawValue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.plain)
                .background(abschnitt == eintrag ? Color.accentColor.opacity(0.15) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            Spacer()
        }
        .padding(8)
        .frame(width: 170)
        .background(.regularMaterial)
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