// swift-tools-version: 6.0
//
// SitzplanSpeicher — macOS-only, kennt SwiftData.
//
// Bewusst ein eigenes Paket und kein weiteres Target in `SitzplanKern`:
// `swift test` baut immer das ganze Paket, und ein SwiftData-Target ist auf
// Linux nicht baubar. Laege beides zusammen, gaebe es den billigen Linux-Job
// fuer die Fachlogik nicht mehr.

import PackageDescription

let package = Package(
    name: "SitzplanSpeicher",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "Speicher", targets: ["Speicher"]),
    ],
    dependencies: [
        .package(path: "../SitzplanKern"),
    ],
    targets: [
        .target(
            name: "Speicher",
            dependencies: [
                .product(name: "Domain", package: "SitzplanKern"),
                .product(name: "Datenvertrag", package: "SitzplanKern"),
                .product(name: "Core", package: "SitzplanKern"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SpeicherTests",
            dependencies: [
                "Speicher",
                .product(name: "Domain", package: "SitzplanKern"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
