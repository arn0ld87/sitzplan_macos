import Domain
import Speicher
import SwiftUI

@main
struct SitzplanStudioApp: App {
    @State private var start: Startergebnis

    init() {
        _start = State(initialValue: Startergebnis.ermitteln())
    }

    var body: some Scene {
        WindowGroup {
            inhalt
                .frame(minWidth: 720, minHeight: 460)
                .ohneDarkMode()
        }
        .commands { AppCommands() }
    }

    @ViewBuilder
    private var inhalt: some View {
        switch start {
        case .bereit(let umgebung):
            KlassenListe(
                modell: KlassenModell(repository: umgebung.klassen),
                schuelerRepo: umgebung.schueler,
                sitzregelRepo: umgebung.sitzregeln
            )
        case .gescheitert(let fehler):
            Startfehler(fehler: fehler)
        }
    }
}

/// Das Ergebnis des Starts.
///
/// Der Speicher wird beim Start geoeffnet, und wenn das scheitert, sagt die
/// Anwendung das — statt mit einem Speicher im Arbeitsspeicher weiterzumachen
/// und beim Beenden alles zu vergessen.
@MainActor
enum Startergebnis {
    case bereit(AppEnvironment)
    case gescheitert(Domaenenfehler)

    static func ermitteln() -> Startergebnis {
        // Der Ablageort ist einspeisbar, damit der Neustarttest gegen ein
        // eigenes, temporaeres Verzeichnis laufen kann. Die Datenbank der
        // Lehrkraft bleibt fuer Tests unberuehrt.
        let ort: Speicher.Ort
        if let pfad = ProcessInfo.processInfo.environment["SITZPLAN_SPEICHERORT"] {
            ort = .verzeichnis(URL(fileURLWithPath: pfad, isDirectory: true))
        } else {
            ort = .anwendungsordner
        }

        do {
            let container = try Speicher.container(ort)
            return .bereit(AppEnvironment(
                klassen: KlassenSpeicher(modelContainer: container),
                schueler: SchuelerSpeicher(modelContainer: container),
                sitzregeln: SitzregelSpeicher(modelContainer: container)
            ))
        } catch {
            return .gescheitert(error)
        }
    }
}

/// Was die Lehrkraft sieht, wenn der Speicher nicht zu oeffnen war.
private struct Startfehler: View {
    let fehler: Domaenenfehler

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.trianglebadge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(Farbe.gefahr)
                .accessibilityHidden(true)

            Text(fehler.beschreibung)
                .font(.title3)
                .multilineTextAlignment(.center)

            if let vorschlag = fehler.vorschlag {
                Text(vorschlag)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: 480)
    }
}
