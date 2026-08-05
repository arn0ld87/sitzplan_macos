import SwiftUI

/// Farbrollen aus dem Designsystem.
///
/// Semantisch uebertragen, nicht pixelgenau. Jede Farbe hat **eine** Rolle;
/// eine Rolle hat eine Farbe. Wer Terrakotta fuer eine Auswahl benutzt oder
/// Petrol fuer eine Primaeraktion, hat das Designsystem nicht verletzt, sondern
/// unlesbar gemacht.
public enum Farbe {
    /// Primaeraktion. **Genau eine je Ansicht.**
    public static let primaeraktion = Color(red: 0xA8 / 255, green: 0x50 / 255, blue: 0x1F / 255)
    public static let primaeraktionAktiv = Color(red: 0x8E / 255, green: 0x42 / 255, blue: 0x18 / 255)

    /// Auswahl und Fokus. Nie Rot — das bedeutet hier etwas anderes.
    public static let auswahl = Color(red: 0x2F / 255, green: 0x5D / 255, blue: 0x73 / 255)
    public static let auswahlWeich = Color(red: 0xE1 / 255, green: 0xEC / 255, blue: 0xF1 / 255)

    /// Loeschen und Fehler — und nur dafuer.
    public static let gefahr = Color(red: 0xA3 / 255, green: 0x2E / 255, blue: 0x24 / 255)
}

extension View {
    /// Schliesst Dark Mode aus.
    ///
    /// Das Designsystem verbietet ihn. Auf macOS muss der Ausschluss **aktiv**
    /// gesetzt werden, sonst schaltet das System um und die Farbrollen stimmen
    /// nicht mehr — Petrol auf dunklem Grund ist kein Petrol mehr.
    public func ohneDarkMode() -> some View {
        preferredColorScheme(.light)
    }
}
