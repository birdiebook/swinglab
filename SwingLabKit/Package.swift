// swift-tools-version:5.9
//
// SwingLabKit — appens logik, fri från kamera och UI så att den går att testa på
// Linux (GitHub Actions) utan Mac och utan telefon. Appen i App/ är ett tunt skal.
import PackageDescription

let package = Package(
    name: "SwingLabKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Swing", targets: ["Swing"]),
    ],
    targets: [
        // Mätningen (METOD M1–M27): formatet, utjämningen och faserna, måtten per vy,
        // sessionen och katalogen. Bara Foundation. Samma tal som tools/pc (BESLUT B12).
        .target(name: "Swing"),
        // Fixturerna är Swift-källa (Fixturer.swift), inga resurser och inget Bundle.module.
        .testTarget(name: "SwingTests", dependencies: ["Swing"]),
    ]
)
