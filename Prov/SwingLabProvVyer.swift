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
// botten svart. Vyerna ritas med svensk region (sv_SE), som Johannes telefon: texten
// ska ändå bli engelsk med decimalpunkt och engelska datum (BESLUT B30, B33).

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
        let v = Passvisning(katalog: try katalog(), pass: Demo.pass, ovas: Demo.attJobbaPa.ovas)
        // @2x: med spridningens kort (METOD M44) blir hela passet högre än 8192 px i @3x, och då
        // skriver ImageRenderer ingen PNG.
        try rendera(PassetVy(visning: v), namn: "passet", skala: 2)
        try rendera(PassetVy(visning: v, filter: .dtl), namn: "passet-dtl")
        // Största textstorleken (Dynamisk text): inget klipps, raderna bryts.
        try rendera(PassetVy(visning: v, filter: .dtl), namn: "passet-dtl-stor", textstorlek: .accessibility5)
    }

    // Today, Focus och Progress ritas inte sedan S4e (BESLUT B64): de är dolda, koden är kvar.

    func testGranskning() throws {
        func visning(_ vy: Vy) throws -> Granskningsvisning {
            let s = Demo.sving(vy), f = Demo.sving(vy, forra: true)
            var g = Granskningsvisning(yta: Matyta(sving: s, resultat: try Matt.mat(s)),
                                       forra: Matyta(sving: f, resultat: try Matt.mat(f)),
                                       forraDatum: Demo.datum[Demo.datum.count - 2], pass: Demo.pass.last!,
                                       matt: Granskningsvisning.matt(vy))
            // Swayen övas (FO), thrusten inte (DTL): bara FO:s uppmätta linje bär accenten.
            g.ovas = Demo.attJobbaPa.saker.contains { $0.matt == Granskningsvisning.matt(vy) }
            return g
        }
        let fo = try visning(.fo), dtl = try visning(.dtl)
        try rendera(GranskningVy(fo: fo, dtl: dtl, vy: .fo, fas: .topp), namn: "granskning-fo", accent: true)
        try rendera(GranskningVy(fo: fo, dtl: dtl, vy: .dtl, fas: .traff, visaForra: true), namn: "granskning-dtl",
                    accent: false)
        try rendera(GranskningVy(fo: fo, dtl: dtl, vy: .fo, fas: .topp), namn: "granskning-fo-stor", textstorlek: .accessibility5)
    }

    // MARK: - Hjälp

    /// ImageRenderer: innehållet i full längd, mörkt läge, @3x, och prövat mot formspråket.
    /// `accent`: om bilden ska bära accenten (det du övar på, BESLUT B31); nil = prövas inte.
    func rendera(_ vy: some View, namn: String, textstorlek: DynamicTypeSize = .large,
                         accent: Bool? = true, skala: CGFloat? = nil) throws {
        let innehall = vy
            .environment(\.dynamicTypeSize, textstorlek)
            .padding(.vertical, 16)
            .frame(width: Self.bredd)
            .fixedSize(horizontal: false, vertical: true)
            .background(Theme.ground)
            .environment(\.colorScheme, .dark)
            .environment(\.locale, Locale(identifier: "sv_SE"))
        let r = ImageRenderer(content: innehall)
        // De största textstorlekarna blir mycket långa; i @1x ryms de i en PNG.
        r.scale = skala ?? (textstorlek.isAccessibilitySize ? 1 : 3)
        r.proposedSize = ProposedViewSize(width: Self.bredd, height: nil)
        let bild = try XCTUnwrap(r.uiImage, "kunde inte rita \(namn)")
        let png = try XCTUnwrap(bild.pngData())
        try FileManager.default.createDirectory(atPath: Self.ut, withIntermediateDirectories: true)
        try png.write(to: URL(fileURLWithPath: "\(Self.ut)/\(namn).png"))
        print("PROV: skrev \(namn).png (\(Int(bild.size.width * bild.scale))×\(Int(bild.size.height * bild.scale)) px)")
        try provaFormspraket(bild, namn: namn, accent: accent)
    }

    /// Gråskala och den enda accenten (B13 regel 6, B31), botten svart, och något ljust ritat.
    /// En punkt räknas som accent när den ligger på linjen mellan grått och isblått
    /// (#6FD3F7: blått över grönt över rött); allt annat färgat är ett fel.
    func provaFormspraket(_ bild: UIImage, namn: String, accent: Bool?) throws {
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
        var farg = 0, isbla = 0, ljust = 0
        var y = 0
        while y < h {
            var x = 0
            while x < w {
                let i = (y * w + x) * 4
                let r = Int(px[i]), g = Int(px[i + 1]), b = Int(px[i + 2])
                if max(abs(r - g), abs(g - b), abs(r - b)) > 6 {
                    if b > r + 6 && g > r && b + 8 >= g { isbla += 1 } else { farg += 1 }
                }
                if r > 200 && g > 200 { ljust += 1 }
                x += 3
            }
            y += 3
        }
        XCTAssertEqual(farg, 0, "\(namn): \(farg) färgade punkter (B13: gråskala och en accent)")
        if let accent {
            if accent {
                XCTAssertGreaterThan(isbla, 0, "\(namn): accenten saknas för det du övar på (B31)")
            } else {
                XCTAssertEqual(isbla, 0, "\(namn): accenten där inget övas (B31)")
            }
        }
        XCTAssertGreaterThan(ljust, 0, "\(namn): inget vitt ritat")
        XCTAssertLessThan(Int(px[0]) + Int(px[1]) + Int(px[2]), 15, "\(namn): botten är inte svart")
    }
}
