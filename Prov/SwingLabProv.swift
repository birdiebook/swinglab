// SIMULATORPROVET (BESLUT B20, S2_SPEC §10.2). Körs av kompilera.yml vid varje push
// som rör appen, inuti appen (TEST_HOST), aldrig av TestFlight. S2a prövar att appen
// startar och bär det TestFlight och frågorna om tillåtelse kräver; S2c–S2g lägger
// till stegen med den påhittade filmen.
//
// VARFÖR /tmp: simulatorn delar filsystem med Mac-värden, så kompilera.yml hämtar
// bilden därifrån och lägger den på grenen ci-resultat (som Idunns prov).

import XCTest
import UIKit
import Swing
@testable import SwingLab

@MainActor
final class SwingLabProv: XCTestCase {

    static let ut = "/tmp/swinglab_prov"

    /// Appen har startat: ett fönster med startvyn, ritat till en bild.
    func testAppenStartarMedStartvyn() throws {
        let fönster = try XCTUnwrap(väntaPåFönster(sekunder: 20), "inget fönster med en vy efter 20 s")
        let vy = try XCTUnwrap(fönster.rootViewController?.view)
        XCTAssertGreaterThan(vy.bounds.width, 0)

        // Låt SwiftUI rita klart innan bilden tas.
        RunLoop.main.run(until: Date().addingTimeInterval(1))
        let bild = UIGraphicsImageRenderer(bounds: fönster.bounds).image { _ in
            _ = fönster.drawHierarchy(in: fönster.bounds, afterScreenUpdates: true)
        }
        try FileManager.default.createDirectory(atPath: Self.ut, withIntermediateDirectories: true)
        try XCTUnwrap(bild.pngData()).write(to: URL(fileURLWithPath: Self.ut + "/startvy.png"))

        // Botten är svart (B13), och primärknappen är ljus mot den.
        let hörn = try ljushet(bild, x: 0.02, y: 0.5)
        XCTAssertLessThan(hörn, 0.05, "botten är inte svart")
        let ljusast = try (0..<40).map { try ljushet(bild, x: 0.5, y: 0.08 + Double($0) * 0.005) }.max() ?? 0
        XCTAssertGreaterThan(ljusast, 0.2, "ingen ljus primärknapp under rubriken")
    }

    /// Appen är den TestFlight laddar upp: bundle-id, namnet, ikonen och texterna
    /// i frågorna om tillåtelse (saknas en kraschar appen vid frågan).
    func testInfoPlist() throws {
        let info = try XCTUnwrap(Bundle.main.infoDictionary)
        XCTAssertEqual(Bundle.main.bundleIdentifier, "se.birdiebook.swinglab")
        XCTAssertEqual(info["CFBundleDisplayName"] as? String, "SwingLab")
        for nyckel in ["NSCameraUsageDescription", "NSMicrophoneUsageDescription",
                       "NSPhotoLibraryUsageDescription", "NSLocalNetworkUsageDescription"] {
            XCTAssertFalse((info[nyckel] as? String ?? "").isEmpty, "\(nyckel) saknas")
        }
        XCTAssertEqual(info["NSBonjourServices"] as? [String], ["_swinglab._tcp"])
        XCTAssertEqual(info["ITSAppUsesNonExemptEncryption"] as? Bool, false)
        // Ikonen: actool skriver in den när AppIcon finns i Assets.xcassets.
        let ikoner = info["CFBundleIcons"] as? [String: Any]
        let primär = ikoner?["CFBundlePrimaryIcon"] as? [String: Any]
        XCTAssertEqual(primär?["CFBundleIconName"] as? String, "AppIcon", "ikonen saknas i bygget")
    }

    /// SwingLabKit är länkat och svarar som på Linux.
    func testSwingLabKitLankat() {
        XCTAssertFalse(Matt.namn(.dtl).isEmpty)
        XCTAssertFalse(Matt.namn(.fo).isEmpty)
    }

    // MARK: - Hjälp

    private func väntaPåFönster(sekunder: TimeInterval) -> UIWindow? {
        let slut = Date().addingTimeInterval(sekunder)
        while Date() < slut {
            let fönster = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.rootViewController != nil }
            if let fönster { return fönster }
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
        return nil
    }

    /// Ljusheten 0…1 i en punkt, angiven som andel av bildens bredd och höjd.
    private func ljushet(_ bild: UIImage, x: Double, y: Double) throws -> Double {
        let cg = try XCTUnwrap(bild.cgImage)
        let px = min(cg.width - 1, max(0, Int(Double(cg.width) * x)))
        let py = min(cg.height - 1, max(0, Int(Double(cg.height) * y)))
        var rgba = [UInt8](repeating: 0, count: 4)
        let ritat = rgba.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                                      bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: -px, y: -(cg.height - 1 - py), width: cg.width, height: cg.height))
            return true
        }
        XCTAssertTrue(ritat)
        return (Double(rgba[0]) + Double(rgba[1]) + Double(rgba[2])) / (3 * 255)
    }
}
