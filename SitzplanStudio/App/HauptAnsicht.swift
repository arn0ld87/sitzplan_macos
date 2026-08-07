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
/// Die Abschnitts-Umschaltung läuft über Buttons, nicht über
/// `List(selection:)`: ein Selection-Binding würde `abschnitt` beim ersten
/// Render auf `nil` überschreiben (frische UI ohne visuelle Selection synced
/// das Binding zurück) — der Detail würde „Wählen Sie einen Abschnitt."
/// zeigen statt KlassenListe. Buttons setzen `abschnitt` nur bei Klick, der
/// Default `.klassen` bleibt stabil. Der `Text` im Button-Label ist als
/// `staticText` auffindbar, was die UITests brauchen.
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