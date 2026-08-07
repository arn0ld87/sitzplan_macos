import Domain
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

    /// Die acht Schülerfarben. Entsprechen `STUDENT_COLORS` im Web-Client
    /// (`src/data/types.ts`). Index 0–7, identische Hex-Werte.
    public static let schuelerPalette: [Color] = [
        Color(red: 0xE0 / 255, green: 0x8A / 255, blue: 0x6B / 255), // 0 Terrakotta
        Color(red: 0x9D / 255, green: 0xBF / 255, blue: 0xA8 / 255), // 1 Salbei
        Color(red: 0xE3 / 255, green: 0xB5 / 255, blue: 0x6B / 255), // 2 Gold
        Color(red: 0xA9 / 255, green: 0x9C / 255, blue: 0xCB / 255), // 3 Lavendel
        Color(red: 0x7C / 255, green: 0xA9 / 255, blue: 0xC2 / 255), // 4 Petrol
        Color(red: 0xD8 / 255, green: 0x8B / 255, blue: 0xA0 / 255), // 5 Altrosa
        Color(red: 0xB8 / 255, green: 0x99 / 255, blue: 0x70 / 255), // 6 Beige
        Color(red: 0x82 / 255, green: 0xB7 / 255, blue: 0xA5 / 255), // 7 Mint
    ]

    public static func schuelerFarbe(farbIndex: Int) -> Color {
        let i = ((farbIndex % schuelerPalette.count) + schuelerPalette.count) % schuelerPalette.count
        return schuelerPalette[i]
    }

    /// Möbelfarbe je Typ. Einzeltisch und Doppeltisch teilen sich Holzbeige —
    /// sie unterscheiden sich durch Größe, nicht durch Farbe.
    public static func fuerMoebeltyp(_ typ: Moebeltyp) -> Color {
        switch typ {
        case .einzeltisch, .doppeltisch:
            Color(red: 0xC8 / 255, green: 0xA9 / 255, blue: 0x6E / 255) // Holzbeige
        case .pult:
            Color(red: 0x8B / 255, green: 0x69 / 255, blue: 0x14 / 255) // Dunkelholz
        case .tafel:
            Color(red: 0x2D / 255, green: 0x5A / 255, blue: 0x3D / 255) // Schiefergrün
        case .tuer:
            Color(red: 0xD4 / 255, green: 0xC5 / 255, blue: 0xA9 / 255) // Beige
        case .fenster:
            Color(red: 0x87 / 255, green: 0xCE / 255, blue: 0xEB / 255) // Hellblau
        }
    }
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
