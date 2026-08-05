import SwiftUI

/// Die Menübefehle.
///
/// Alles, was in der Oberfläche als Schaltfläche existiert, ist auch über das
/// Menü und ein Tastaturkürzel erreichbar — das ist auf macOS keine Kür,
/// sondern die Erwartung, und es ist die Grundlage der Tastaturbedienbarkeit.
struct AppCommands: Commands {
    var body: some Commands {
        // Die App hat keine Dokumente im Sinne von `NSDocument`. Was der
        // Standard hier anbietet — „Neu“, „Öffnen“, „Sichern unter“ —, wäre
        // eine Behauptung, die nicht stimmt.
        CommandGroup(replacing: .newItem) {
            Button("Neue Klasse") {
                NotificationCenter.default.post(name: .neueKlasse, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandGroup(replacing: .help) {
            Button("Sitzplan Studio-Hilfe") {
                NotificationCenter.default.post(name: .zeigeHilfe, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let neueKlasse = Notification.Name("de.alexle135.SitzplanStudio.neueKlasse")
    static let zeigeHilfe = Notification.Name("de.alexle135.SitzplanStudio.zeigeHilfe")
}
