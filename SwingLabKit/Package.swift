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
        // Påhittade pass och svingar för vyernas prov (Prov/). Appen länkar inte in det.
        .library(name: "SwingDemo", targets: ["SwingDemo"]),
        // 3D ur två telefoner (S6c, BESLUT B48): Python-kedjan i tools/pc/tva_kameror.py på telefonen.
        .library(name: "TreD", targets: ["TreD"]),
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
        // SwingDemo ger de påhittade lederna som analysens kedja prövas med (S2e, DemoLeder).
        .testTarget(name: "CaptureTests", dependencies: ["Capture", "Swing", "SwingDemo"]),
        // Vyernas data (S4): Swing/Visning räknar texten och lägena, SwingDemo är provets påhittade pass.
        // Capture för DemoLeder: påhittade Vision-leder till simulatorprovet av slagens kedja (S2e).
        .target(name: "SwingDemo", dependencies: ["Swing", "Capture"]),
        .testTarget(name: "VisningTests", dependencies: ["Swing", "SwingDemo"]),
        // 3D (S6c-1, METOD MK1–MK7, M50): parningen, självkalibreringen, synken, trianguleringen och
        // måtten, med egen linjär algebra (bara Foundation). Capture för lederna (JointSeries) och
        // parningen av klicken (ClickPairing), Swing för vyerna, faserna och sessionen.
        .target(name: "TreD", dependencies: ["Swing", "Capture"]),
        // Pythons tal för påhittade pass står i tools/tests/fixturer/tre_d/ (generera_tre_d.py), BESLUT B12.
        .testTarget(name: "TreDTests", dependencies: ["TreD", "Capture", "Swing"]),
    ]
)
