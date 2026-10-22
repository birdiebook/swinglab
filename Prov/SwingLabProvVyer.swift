// VYERNA I S4 RITADE TILL PNG (BESLUT B20, PLAN S4). Körs av kompilera.yml i
// simulatorn, som startvyn i SwingLabProv.swift. Varje skärm i App/Vyer ritas med
// ImageRenderer i full längd, 390 punkter bred (som skissen), och sparas i
// /tmp/swinglab_prov/<namn>.png; kompilera.yml lägger dem på grenen ci-resultat
// som resultat/<sha>.<namn>.png.
//
// DATAN ÄR PÅHITTAD (SwingDemo, CLAUDE.md §Dataregeln): 16 pass med skissens tal,
// räknade samma väg som i appen (Session, Bedomare och Swing/Visning), och
// demosvingar som Matt.mat mäter för granskningens mätyta. Katalogen är repots
// katalog.json, läst från källträdet (simulatorn delar filsystem med Mac-värden).
//
// Varje bild prövas mot formspråket (BESLUT B13, regel 6): bara gråskala, och
// botten svart.

import XCTest
import SwiftUI
import UIKit
import Swing
import SwingDemo
@testable import SwingLab

@MainActor
final class SwingLabProvVyer: XCTestCase {

    static let ut = "/tmp/swinglab_prov"
    static let bredd: CGFloat = 390

    func katalog() throws -> Katalog {
        let rot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try Katalog.las(Data(contentsOf: rot.appendingPathComponent("katalog.json")))
    }

    func testPasset() throws {
        let v = Passvisning(katalog: try katalog(), pass: Demo.pass)
        try rendera(PassetVy(visning: v), namn: "passet")
        try rendera(PassetVy(visning: v, filter: .dtl), namn: "passet-dtl")
        // Största textstorleken (Dynamisk text): inget klipps, raderna bryts.
        try rendera(PassetVy(visning: v, filter: .dtl), namn: "passet-dtl-stor", textstorlek: .accessibility5)
    }

    func testIdag() throws {
        let v = Idagvisning(idag: Tal.dag(2027, 1, 13), katalog: try katalog(), pass: Demo.pass,
                            attJobbaPa: Demo.attJobbaPa)
        try rendera(IdagVy(visning: v), namn: "idag")
        try rendera(IdagVy(visning: v), namn: "idag-stor", textstorlek: .accessibility5)
    }

    func testAttJobbaPa() throws {
        let v = AttJobbaPaVisning(Demo.attJobbaPa, katalog: try katalog())
        try rendera(AttJobbaPaVy(visning: v), namn: "jobba")
        try rendera(AttJobbaPaVy(visning: v), namn: "jobba-stor", textstorlek: .accessibility5)
    }

    func testUtveckling() throws {
        let v = Utvecklingsvisning(katalog: try katalog(), pass: Demo.pass, block: Demo.block)
        try rendera(UtvecklingVy(visning: v), namn: "utveckling")
        try rendera(UtvecklingVy(visning: v, valt: "backens_resa_framat"), namn: "utveckling-resa")
        try rendera(UtvecklingVy(visning: v, valt: "tempo"), namn: "utveckling-tempo")
    }

    func testGranskning() throws {
        func visning(_ vy: Vy) throws -> Granskningsvisning {
            let s = Demo.sving(vy), f = Demo.sving(vy, forra: true)
            return Granskningsvisning(yta: Matyta(sving: s, resultat: try Matt.mat(s)),
                                      forra: Matyta(sving: f, resultat: try Matt.mat(f)),
                                      forraDatum: Demo.datum[Demo.datum.count - 2], pass: Demo.pass.last!,
                                      matt: Granskningsvisning.matt(vy))
        }
        let fo = try visning(.fo), dtl = try visning(.dtl)
        try rendera(GranskningVy(fo: fo, dtl: dtl, vy: .fo, fas: .topp), namn: "granskning-fo")
        try rendera(GranskningVy(fo: fo, dtl: dtl, vy: .dtl, fas: .traff, visaForra: true), namn: "granskning-dtl")
    }

    // MARK: - Hjälp

    /// ImageRenderer: innehållet i full längd, mörkt läge, @3x, och prövat mot formspråket.
    private func rendera(_ vy: some View, namn: String, textstorlek: DynamicTypeSize = .large) throws {
        let innehall = vy
            .environment(\.dynamicTypeSize, textstorlek)
            .padding(.vertical, 16)
            .frame(width: Self.bredd)
            .fixedSize(horizontal: false, vertical: true)
            .background(Theme.ground)
            .environment(\.colorScheme, .dark)
            .environment(\.locale, Locale(identifier: "sv_SE"))
        let r = ImageRenderer(content: innehall)
        r.scale = 3
        r.proposedSize = ProposedViewSize(width: Self.bredd, height: nil)
        let bild = try XCTUnwrap(r.uiImage, "kunde inte rita \(namn)")
        let png = try XCTUnwrap(bild.pngData())
        try FileManager.default.createDirectory(atPath: Self.ut, withIntermediateDirectories: true)
        try png.write(to: URL(fileURLWithPath: "\(Self.ut)/\(namn).png"))
        print("PROV: skrev \(namn).png (\(Int(bild.size.width * bild.scale))×\(Int(bild.size.height * bild.scale)) px)")
        try provaFormspraket(bild, namn: namn)
    }

    /// Bara gråskala (ingen accentfärg, B13 regel 6), botten svart, och något ljust ritat.
    private func provaFormspraket(_ bild: UIImage, namn: String) throws {
        let cg = try XCTUnwrap(bild.cgImage)
        let w = cg.width, h = cg.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let ritat = px.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        XCTAssertTrue(ritat, namn)
        var farg = 0, ljust = 0
        var y = 0
        while y < h {
            var x = 0
            while x < w {
                let i = (y * w + x) * 4
                let r = Int(px[i]), g = Int(px[i + 1]), b = Int(px[i + 2])
                if max(abs(r - g), abs(g - b), abs(r - b)) > 6 { farg += 1 }
                if r > 200 { ljust += 1 }
                x += 3
            }
            y += 3
        }
        XCTAssertEqual(farg, 0, "\(namn): \(farg) färgade punkter (B13: svart, vitt och gråskala)")
        XCTAssertGreaterThan(ljust, 0, "\(namn): inget vitt ritat")
        XCTAssertLessThan(Int(px[0]) + Int(px[1]) + Int(px[2]), 15, "\(namn): botten är inte svart")
    }
}
