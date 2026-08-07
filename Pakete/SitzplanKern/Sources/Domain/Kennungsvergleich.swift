import Foundation

/// Vergleicht Kennungen, die einmal als `UUID` und einmal als Zeichenkette
/// vorliegen.
///
/// - Important: `UUID.uuidString` liefert **Grossbuchstaben**
///   (`C1C1C1C1-…`). In den Dokumenten und Fixtures stehen dieselben Kennungen
///   in **Kleinbuchstaben** (`c1c1c1c1-…`), weil sie aus JavaScript stammen.
///   Ein direkter Zeichenkettenvergleich findet deshalb nichts — und zwar
///   lautlos: Es gibt keinen Fehler, es passiert nur nichts. Eine Sitzregel wird
///   dann nie verletzt, ein Schueler sitzt scheinbar nirgends.
///
///   Das ist die Sorte Fehler, die durch jeden oberflaechlichen Test kommt, weil
///   der Testcode dieselbe Grossschreibung erzeugt wie der Produktivcode. Nur
///   die Fixtures decken ihn auf.
public enum Kennungsvergleich {
    /// Bringt eine Kennung in die Vergleichsform.
    ///
    /// Ist die Zeichenkette eine UUID, wird sie normalisiert; sonst bleibt sie,
    /// wie sie ist — sie kann eine Sitzplatzkennung oder ein Altbestand sein.
    public static func kanonisch(_ kennung: String) -> String {
        if let uuid = UUID(uuidString: kennung) {
            return uuid.uuidString
        }
        return kennung
    }

    public static func kanonisch(_ kennung: UUID) -> String {
        kennung.uuidString
    }

    /// Bezeichnen beide dieselbe Sache?
    public static func gleich(_ links: String, _ rechts: String) -> Bool {
        kanonisch(links) == kanonisch(rechts)
    }

    public static func gleich(_ links: UUID, _ rechts: String) -> Bool {
        kanonisch(links) == kanonisch(rechts)
    }
}
