// INSPELNINGENS SKÄRM RITAD TILL PNG (PLAN S2j, BESLUT B85, METOD MS32). Skissens fyra lägen
// (kopplad och redo, spelar in, lutningen, en varning) och kugghjulets blad, för Lead och för en
// ensam telefon, och med största textstorlekarna (Dynamisk text). Lagret ritas på en grå yta i
// kamerans ställe, 390 × 844 punkter som skissen, med telefonens marginaler överst och nederst.
//
// Formspråket prövas med undantaget i B85: utöver gråskalan bara inspelningens färger, grönt
// (#30D158) för "Connected", rött (#D70015, #FF3B30) för inspelningen och gult (#F5B54A) för
// varningens ikon, och exakt de färger som läget ska ha. Kulören prövas, inte ljusheten: en färg
// blandad med grått (kanterna, den halvgenomskinliga ringen) behåller sin kulör.
//
// DATAN ÄR PÅHITTAD: tiden, svingarna, lutningen och kugghjulets värden.

import XCTest
import SwiftUI
import UIKit
import Swing
import Capture
@testable import SwingLab

extension SwingLabProvVyer {
    enum Statusfarg: String, Hashable, CustomStringConvertible {
        case rod, gron, gul
        var description: String { rawValue }
    }

    func provLutning(_ grader: Double) -> Lutning {
        let v = grader * .pi / 180
        return Lutning(gravity: [sin(v), -cos(v), 0])!
    }

    func testInspelningensSkarm() throws {
        var visare = LutningsVisare()
        let sex = provLutning(6)
        XCTAssertTrue(visare.uppdatera(sex))
        XCTAssertFalse(LutningsVisare().visas)

        // Lead: skissens fyra lägen, och söker och tappad.
        try skarm(InspelningsLager(status: .kopplad, varning: nil), "insp-lead-kopplad", farger: [.rod, .gron])
        try skarm(InspelningsLager(status: .spelarIn(sekunder: 42), varning: .andraStoppade),
                  "insp-lead-spelar-in", farger: [.rod, .gul])
        try skarm(InspelningsLager(status: .kopplad, varning: nil, lutning: sex), "insp-lead-lutning", farger: [.rod, .gron])
        try skarm(InspelningsLager(status: .kopplad, varning: .sammaVy(.dtl, kanByta: true)), "insp-lead-varning",
                  farger: [.rod, .gron, .gul])
        try skarm(InspelningsLager(status: .soker, varning: nil), "insp-lead-soker", farger: [.rod])
        try skarm(InspelningsLager(status: .tappad, varning: nil), "insp-lead-tappad", farger: [.rod, .gul])

        // Ensam: ingen statuspill, REC under serien, lutningen och en varning.
        try skarm(InspelningsLager(status: .ingen, varning: nil), "insp-ensam-redo", farger: [.rod])
        try skarm(InspelningsLager(status: .spelarIn(sekunder: 75), varning: nil), "insp-ensam-spelar-in",
                  farger: [.rod])
        try skarm(InspelningsLager(status: .ingen, varning: nil, lutning: sex), "insp-ensam-lutning", farger: [.rod])
        try skarm(InspelningsLager(status: .ingen, varning: .bildfrekvens(120)), "insp-ensam-varning", farger: [.rod, .gul])

        // Över 45°: med två telefoner också "Tilt too large for 3D"; ensam bara talet (B85). Rakt åt
        // sidan men 50° framåt: talet är 50°, inte 0°, och linjen ligger på bildens vågräta (MS32).
        let p = 50.0 * .pi / 180
        let framat = try XCTUnwrap(Lutning(gravity: [0, -cos(p), -sin(p)]))
        XCTAssertEqual(abs(framat.sida), 0, accuracy: 1e-9)
        XCTAssertEqual(LutningsVisare.text(framat), "50°")
        try skarm(InspelningsLager(status: .kopplad, varning: nil, lutning: framat), "insp-lead-lutning-for-stor",
                  farger: [.rod, .gron])
        try skarm(InspelningsLager(status: .ingen, varning: nil, lutning: framat, lutning3D: false),
                  "insp-ensam-lutning-for-stor", farger: [.rod])

        // Dynamisk text: pillen och varningen bryts i stället för att kortas.
        try skarm(InspelningsLager(status: .kopplad, varning: .sammaVy(.dtl, kanByta: true)), "insp-lead-varning-stor",
                  farger: [.rod, .gron, .gul], textstorlek: .accessibility3)
        try skarm(InspelningsLager(status: .spelarIn(sekunder: 42), varning: .andraStoppade),
                  "insp-lead-spelar-in-stor", farger: [.rod, .gul], textstorlek: .accessibility3)
        try skarm(InspelningsLager(status: .ingen, varning: nil, lutning: sex), "insp-ensam-lutning-stor", farger: [.rod],
                  textstorlek: .accessibility3)
    }

    func testInspelningensKugghjul() throws {
        let lead = InspelningsInstallningar.rader(
            roll: .lead, vy: .dtl, andraVy: .fo, fps: 240, lutning: provLutning(0.8), svingar: 3,
            horda: (par: 6, av: 6, rest: 0.0012, osaker: true), minuter: 40, tryck: .nominal, mikrofon: .inbyggd)
        XCTAssertEqual(lead.map(\.varde), ["Lead\u{00A0}\u{00B7} DTL", "Follow\u{00A0}\u{00B7} FO", "240 fps", "0.8°", "~3",
                                           "6 of 6\u{00A0}\u{00B7} 1.2 ms\u{00A0}\u{00B7} uncertain", "about 40 min",
                                           "Normal", "Built-in"])
        let ensam = InspelningsInstallningar.rader(
            roll: .solo, vy: .fo, andraVy: nil, fps: 240, lutning: provLutning(0.8), horda: nil,
            minuter: 40, tryck: .fair, mikrofon: .inbyggd)
        // Rader som inte gäller visas inte: ingen annan telefon och inga svingar hörda av båda.
        XCTAssertEqual(ensam.map(\.varde), ["FO", "240 fps", "0.8°", "about 40 min", "Fair", "Built-in"])

        func blad(_ rader: [InspelningsInstallningar.Rad]) -> some View {
            InspelningsInstallningar(rader: rader, hjalplinjer: .constant(true)).background(Theme.surface)
        }
        try rendera(blad(lead), namn: "insp-installningar-lead", accent: false)
        try rendera(blad(ensam), namn: "insp-installningar-ensam", accent: false)
        try rendera(blad(lead), namn: "insp-installningar-lead-stor", textstorlek: .accessibility5, accent: false)
        try rendera(InspelningsInstallningar(rader: ensam, hjalplinjer: .constant(false)).background(Theme.surface),
                    namn: "insp-installningar-utan-linjer", accent: false)
    }

    // MARK: - Hjälp

    /// Lagret på en grå videoyta, 390 × 844, och färgerna prövade mot B85.
    func skarm(_ lager: InspelningsLager, _ namn: String, farger: Set<Statusfarg>,
               textstorlek: DynamicTypeSize = .large) throws {
        let vy = ZStack {
            LinearGradient(colors: [Color(white: 0.45), Color(white: 0.55), Color(white: 0.32), Color(white: 0.25)],
                           startPoint: .top, endPoint: .bottom)
            GuideLines()
            lager.padding(.top, 47).padding(.bottom, 34)
        }
        .frame(width: Self.bredd, height: 844)
        .environment(\.dynamicTypeSize, textstorlek)
        .environment(\.colorScheme, .dark)
        .environment(\.locale, Locale(identifier: "sv_SE"))
        let r = ImageRenderer(content: vy)
        r.scale = textstorlek.isAccessibilitySize ? 2 : 3
        r.proposedSize = ProposedViewSize(width: Self.bredd, height: 844)
        let bild = try XCTUnwrap(r.uiImage, "kunde inte rita \(namn)")
        try FileManager.default.createDirectory(atPath: Self.ut, withIntermediateDirectories: true)
        try XCTUnwrap(bild.pngData()).write(to: URL(fileURLWithPath: "\(Self.ut)/\(namn).png"))
        let (finns, annan, prov) = try statusfarger(bild)
        print("PROV: skrev \(namn).png, färger \(finns.map(\.rawValue).sorted()) (andra kulörer \(annan) av \(prov))")
        XCTAssertEqual(finns, farger, "\(namn): inspelningens färger (B85)")
        XCTAssertLessThanOrEqual(annan, max(3, prov / 20_000), "\(namn): en kulör utanför B85")
    }

    /// Inspelningens färger i bilden (minst 10 prov var), och antalet prov med en annan kulör.
    func statusfarger(_ bild: UIImage) throws -> (Set<Statusfarg>, Int, Int) {
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
        XCTAssertTrue(ritat)
        var antal: [Statusfarg: Int] = [:]
        var annan = 0, prov = 0
        var y = 0
        while y < h {
            var x = 0
            while x < w {
                let i = (y * w + x) * 4
                let r = Double(px[i]), g = Double(px[i + 1]), b = Double(px[i + 2])
                let mx = max(r, g, b), mn = min(r, g, b)
                prov += 1
                if mx - mn > 40 {
                    let c = mx - mn
                    var hue: Double
                    if mx == r { hue = 60 * ((g - b) / c) } else if mx == g { hue = 60 * ((b - r) / c) + 120 } else { hue = 60 * ((r - g) / c) + 240 }
                    if hue < 0 { hue += 360 }
                    if hue >= 340 || hue <= 14 { antal[.rod, default: 0] += 1 }
                    else if hue >= 25 && hue <= 50 { antal[.gul, default: 0] += 1 }
                    else if hue >= 120 && hue <= 150 { antal[.gron, default: 0] += 1 }
                    else { annan += 1 }
                }
                x += 3
            }
            y += 3
        }
        return (Set(antal.filter { $0.value >= 10 }.keys), annan, prov)
    }
}
