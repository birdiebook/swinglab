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
        .library(name: "Capture", targets: ["Capture"]),
    ],
    targets: [
        // Mätningen (METOD M1–M27): formatet, utjämningen och faserna, måtten per vy,
        // sessionen och katalogen. Bara Foundation. Samma tal som tools/pc (BESLUT B12).
        .target(name: "Swing"),
        // Fixturerna är Swift-källa (Fixturer.swift), inga resurser och inget Bundle.module.
        .testTarget(name: "SwingTests", dependencies: ["Swing"]),
        // Inspelningens logik (S2_SPEC §9, METOD MS1–MS10): klicket, rutornas tider, formatet,
        // exponeringen, ljusprovet, orienteringen, lederna, svingdomen, klockorna och parningen.
        // Bara Foundation; App/ fyller i värdena ur AVFoundation och Vision. Passets
        // uppställning (S2c) använder Swings Vy och Hand, så att "dtl|fo" finns på ett ställe.
        .target(name: "Capture", dependencies: ["Swing"]),
        // KlickFixturer.swift är Pythons tal (tools/pc/klickljud.py --swift), BESLUT B12.
        // Swing behövs bara för att pröva att ledernas namn är formatets (docs/FORMAT.md).
        .testTarget(name: "CaptureTests", dependencies: ["Capture", "Swing"]),
    ]
)
