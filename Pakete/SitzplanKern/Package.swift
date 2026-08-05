// swift-tools-version: 6.0
//
// SitzplanKern — plattformneutral. Kein Apple-Framework ausser Foundation.
//
// Dieses Paket muss auf Linux bauen. Das ist keine Marotte: Der Linux-Job ist
// die einzige Stelle, an der die Schichtengrenze zu SwiftData tatsaechlich
// geprueft wird (siehe ADR-0002). Auf einem Mac uebersetzt `import SwiftData`
// hier anstandslos, weil System-Frameworks sich nicht per Paketgrenze
// aussperren lassen.

import PackageDescription

let package = Package(
    name: "SitzplanKern",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Datenvertrag", targets: ["Datenvertrag"]),
        .library(name: "Core", targets: ["Core"]),
    ],
    targets: [
        .target(name: "Domain", swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(
            name: "Datenvertrag",
            dependencies: ["Domain"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(name: "Core", swiftSettings: [.swiftLanguageMode(.v6)]),

        // Paketintern, kein Produkt: findet die Fixtures im Repository-Wurzel-
        // verzeichnis. Sie liegen ausserhalb dieses Pakets und lassen sich
        // deshalb nicht als SPM-Ressource einbinden — sie werden ueber den
        // Quellpfad gefunden. Eine Kopie im Paket waere die zuverlaessigste Art,
        // zwei auseinanderlaufende Wahrheiten zu erzeugen.
        .target(name: "Fixtures", swiftSettings: [.swiftLanguageMode(.v6)]),

        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain", "Fixtures"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "DatenvertragTests",
            dependencies: ["Datenvertrag", "Domain", "Fixtures"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
