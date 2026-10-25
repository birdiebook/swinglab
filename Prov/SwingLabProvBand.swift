// BANDETS LÄGE RITAT TILL PNG (PLAN S4g, BESLUT B86–B88, METOD M62).
//
// Vad som bevisas här, på PÅHITTADE pass (inga riktiga svingar, CLAUDE.md: Dataregeln):
//   passet     en FO- och en DTL-session med 7i där korten får en grön prick, en gul ring och en
//              röd pil (uppåt eller nedåt bredvid talet, åt sidan på spannet), och ett fel med
//              egen baslinje ("Your usual") som blir rött åt det sämre hållet;
//   driver     samma FO-värden med Dr: de band som klubban flyttar (resan och sway gap) visas inte,
//              de andra (swayen, tempot, reverse spine) visas som på järn (BESLUT B86);
//   granskning raderna vid P4 bakifrån utan dom (b)-måtten (händerna, knäet, huvudets lyft,
//              flying elbow), med läget på raden, och over the top på klubbans plan vid P6 när
//              klubban är markerad;
//   färgerna   bara bandets tre färger utöver gråskalan och accenten, och rätt färger per bild.
// Bilderna: band-passet-fo, band-passet-dtl, band-passet-driver, band-granskning-p4,
// band-granskning-p6-klubba.

import XCTest
import SwiftUI
import UIKit
import Swing
@testable import SwingLab

extension SwingLabProvVyer {
    enum Bandfarg: String, Hashable, CustomStringConvertible {
        case gron, gul, rod
        var description: String { rawValue }
    }

    /// Bandets färg för en punkt (B87): kulören för #30D158, #FFD60A eller #FF3B30, också
    /// blandad med svart, grått eller vitt i kanterna (`mattnad` = minsta skillnad mellan
    /// kanalerna). nil = ingen av dem.
    static func bandfarg(_ r: Int, _ g: Int, _ b: Int, mattnad: Int = 30) -> Bandfarg? {
        let mx = max(r, g, b), mn = min(r, g, b)
        guard mx - mn > mattnad, mx > mn else { return nil }
        let c = Double(mx - mn)
        var hue: Double
        if mx == r {
            hue = 60 * (Double(g - b) / c)
        } else if mx == g {
            hue = 60 * (Double(b - r) / c) + 120
        } else {
            hue = 60 * (Double(r - g) / c) + 240
        }
        if hue < 0 { hue += 360 }
        if abs(hue - 136) <= 20 { return .gron }          // #30D158: 136°
        if hue >= 40 && hue <= 64 { return .gul }         // #FFD60A: 50° (flaggan #B98A4A är 35°)
        if hue <= 14 || hue >= 346 { return .rod }        // #FF3B30: 3°
        return nil
    }

    /// Bandets färger i en bild, med minst `minst` punkter var.
    func bandfarger(_ bild: UIImage, minst: Int = 6) throws -> Set<Bandfarg> {
        let cg = try XCTUnwrap(bild.cgImage)
        let w = cg.width, h = cg.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        _ = px.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        var antal: [Bandfarg: Int] = [:]
        for y in stride(from: 0, to: h, by: 2) {
            for x in stride(from: 0, to: w, by: 2) {
                let i = (y * w + x) * 4
                if let f = Self.bandfarg(Int(px[i]), Int(px[i + 1]), Int(px[i + 2])) { antal[f, default: 0] += 1 }
            }
        }
        return Set(antal.filter { $0.value >= minst }.keys)
    }

    /// Ritar vyn som `rendera` och prövar bandets färger.
    func ritaBand(_ vy: some View, namn: String, farger: Set<Bandfarg>, accent: Bool? = nil) throws {
        try rendera(vy, namn: namn, accent: accent, skala: 2)
        let bild = try XCTUnwrap(UIImage(contentsOfFile: "\(Self.ut)/\(namn).png"))
        let finns = try bandfarger(bild)
        print("PROV: \(namn) bandets färger \(finns.map(\.rawValue).sorted())")
        XCTAssertEqual(finns, farger, "\(namn): bandets färger (B87)")
    }

    /// Ett påhittat pass: `n` svingar per vy med värdena ± en liten spridning.
    func bandpass(_ klubba: String, dag: Int, fo: [String: Double], dtl: [String: Double], n: Int = 9) -> Pass {
        func svingar(_ vy: Vy, _ m: [String: Double]) -> [SvingMatt] {
            (0..<n).map { i in SvingMatt(vy: vy, matt: m.mapValues { $0 + Double(i % 3 - 1) * 0.1 }) }
        }
        return Pass(datum: Tal.dag(2027, 1, dag), klubba: klubba, svingar: svingar(.fo, fo) + svingar(.dtl, dtl))
    }

    func testBandetsLage() throws {
        let k = try katalog()
        // FO: swayen och tempot innanför, resan inom golvet, sway gap långt under.
        let fo: [String: Double] = ["backen_sway_topp": -1.0, "tempo": 2.8, "backen_resa_framat": 9.0,
                                    "sway_gap_traff": 3.0, "sidbojning_topp": 4.0, "framre_armbage_efter_traff": 20,
                                    "framre_armbage_topp": 14]
        // DTL: thrusten över bandet, händernas bana inom golvet, tappet långt över det vanliga.
        let dtl: [String: Double] = ["backen_thrust_traff": 7.5, "handbana": 1.0, "tempo": 2.8,
                                     "brost_bojning_adress": 40, "brost_bojning_traff": 31, "brost_bojning_tapp": 9.0,
                                     "bakre_armbage_topp": 60]
        // Tidigare pass: tappet runt 2° (egen baslinje), resten som nu.
        let tidigare = (0..<3).map { i -> Pass in
            var d = dtl
            d["brost_bojning_tapp"] = 2.0 + Double(i) * 0.3
            d["brost_bojning_traff"] = 38.0
            return bandpass("7i", dag: 3 + i, fo: fo, dtl: d)
        }
        let nu = bandpass("7i", dag: 9, fo: fo, dtl: dtl)
        let v = Passvisning(katalog: k, pass: tidigare + [nu])
        func lage(_ id: String) -> Bandlage? { v.kort.first { $0.id == id }?.lage }
        XCTAssertEqual(lage("sway_topp"), Bandlage(.gron))
        XCTAssertEqual(lage("tempo"), Bandlage(.gron))
        XCTAssertEqual(lage("backens_resa_framat"), Bandlage(.gul))
        XCTAssertEqual(lage("sway_gap"), Bandlage(.rod, pil: .under))
        XCTAssertEqual(lage("early_extension"), Bandlage(.rod, pil: .over))
        XCTAssertEqual(lage("over_the_top"), Bandlage(.gul))
        XCTAssertEqual(lage("tappad_hallning"), Bandlage(.rod, pil: .over))      // egen baslinje, sämre uppåt
        XCTAssertEqual(lage("chicken_wing"), .ingen)                             // egen baslinje, inom det vanliga
        XCTAssertEqual(v.kort.first { $0.id == "tappad_hallning" }?.markning?.etikett, "Your usual")
        XCTAssertFalse(v.kort.contains { $0.id == "flying_elbow" || $0.id == "axellutning" })   // dom (b)
        print("PROV: band \(v.kort.map { "\($0.id)=\($0.lage.lage.rawValue)\($0.lage.pil.map { "/\($0.rawValue)" } ?? "")" })")
        try ritaBand(PassetVy(visning: v, vy: .fo), namn: "band-passet-fo", farger: [.gron, .gul, .rod])
        try ritaBand(PassetVy(visning: v, vy: .dtl), namn: "band-passet-dtl", farger: [.gron, .gul, .rod])

        // Driver: ett band som klubban flyttar visas inte (utan baslinje inget läge); de andra
        // banden gäller båda klubborna (research 6 §6, BESLUT B86).
        let dr = Passvisning(katalog: k, pass: [bandpass("Dr", dag: 10, fo: fo, dtl: dtl)])
        func drLage(_ id: String) -> Bandlage? { dr.kort.first { $0.id == id }?.lage }
        XCTAssertEqual(drLage("backens_resa_framat"), .ingen)
        XCTAssertEqual(drLage("sway_gap"), .ingen)
        XCTAssertEqual(drLage("sway_topp"), Bandlage(.gron))
        XCTAssertEqual(drLage("tempo"), Bandlage(.gron))
        XCTAssertEqual(drLage("reverse_spine"), Bandlage(.gron))
        print("PROV: driver \(dr.kort.map { "\($0.id)=\($0.lage.lage.rawValue)" })")
        try ritaBand(PassetVy(visning: dr, vy: .fo), namn: "band-passet-driver", farger: [.gron])
    }

    func testBandetIGranskningen() throws {
        let k = try katalog()
        func lista(_ rader: [Positionsrad]) -> some View {
            VStack(spacing: 0) { ForEach(rader) { PositionsradVy(rad: $0) } }.padding(.horizontal, 20)
        }
        // P4 bakifrån: dom (b) syns inte (händerna, knäet, huvudets lyft, flying elbow).
        let p4 = Positionsmatt.rader(k, vy: .dtl, position: "P4",
                                     varden: ["hand_djup_topp": -20, "hand_lyft_topp": 70, "framre_kna_topp": 23,
                                              "huvud_lyft_topp": -0.4, "framre_arm_plan_topp": 6, "bakre_armbage_topp": 60,
                                              "brost_lyft_topp": -1.0, "huvud_mot_bollen_topp": -1.1,
                                              "skaft_riktning_topp": 14.0],
                                     baslinje: ["huvud_mot_bollen_topp": (0..<9).map { Double($0) * 0.2 - 1 }],
                                     klubba: "j7")
        let dolda = ["hand_djup_topp", "hand_lyft_topp", "framre_kna_topp", "huvud_lyft_topp", "framre_arm_plan_topp",
                     "bakre_armbage_topp"]
        XCTAssertFalse(p4.contains { dolda.contains($0.matt) }, "\(p4.map(\.matt))")
        XCTAssertEqual(p4.map(\.matt), ["brost_lyft_topp", "huvud_mot_bollen_topp", "skaft_riktning_topp"])
        XCTAssertEqual(p4.map(\.lage.lage), [.gron, .ingen, .gul])
        print("PROV: granskningen P4 \(p4.map { "\($0.matt)=\($0.lage.lage.rawValue)" })")
        try ritaBand(lista(p4), namn: "band-granskning-p4", farger: [.gron, .gul])

        // P6 med klubban markerad: over the top är klubbans plan, en rad, och över planet är rött.
        let p6 = Positionsmatt.rader(k, vy: .dtl, position: "P6", varden: ["handbana": 1.0, "skaft_plan_p6": 13.0],
                                     klubba: "j7")
        XCTAssertEqual(p6.map(\.matt), ["skaft_plan_p6"])
        XCTAssertEqual(p6.first?.lage, Bandlage(.rod, pil: .over))
        XCTAssertFalse(Positionsmatt.rader(k, vy: .dtl, position: "P5", varden: ["handbana": 1.0, "skaft_plan_p6": 13.0],
                                           klubba: "j7").contains { $0.matt == "handbana" })
        try ritaBand(lista(p6), namn: "band-granskning-p6-klubba", farger: [.rod])
    }
}
