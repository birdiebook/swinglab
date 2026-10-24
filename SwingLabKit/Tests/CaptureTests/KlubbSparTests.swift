import Foundation
import XCTest
import Swing
import SwingDemo

/// S7b: klubbhuvudets bana mellan ankarna på den PÅHITTADE filmen (CLAUDE.md, Dataregeln):
/// samma bytes och samma bana som Python (tools/tests/fixturer/klubbspar.json, skriven av
/// tools/pc/klubbfilm.py, BESLUT B12), och felet mot sanningen inom METOD M61:s gräns.
final class KlubbSparTests: XCTestCase {
    static let rot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    static func fixtur() throws -> [String: Any] {
        let url = rot.appendingPathComponent("tools/tests/fixturer/klubbspar.json")
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    nonisolated(unsafe) static var filmen: (rutor: [KlubbSpar.Ruta], ankare: [KlubbMarkering], sanning: [Punkt])?
    static func film() -> (rutor: [KlubbSpar.Ruta], ankare: [KlubbMarkering], sanning: [Punkt]) {
        if let f = filmen { return f }
        let f = KlubbFilm.film()
        filmen = f
        return f
    }

    func testFilmenArPythonsBytes() throws {
        let d = try Self.fixtur()
        let f = Self.film()
        let summor = try XCTUnwrap(d["summa"] as? [NSNumber]).map(\.uint32Value)
        let tider = try XCTUnwrap(d["t"] as? [Double])
        XCTAssertEqual(f.rutor.count, summor.count)
        for (k, r) in f.rutor.enumerated() {
            XCTAssertEqual(r.t, tider[k], accuracy: 1e-12)
            XCTAssertEqual(KlubbFilm.summa(r.bild), summor[k], "ruta \(k)")
        }
        let ank = try XCTUnwrap(d["ankare"] as? [[String: Any]])
        XCTAssertEqual(f.ankare.map(\.position), ank.map { $0["position"] as! String })
        for (a, b) in zip(f.ankare, ank) {
            let g = b["grepp"] as! [Double], h = b["hosel"] as! [Double]
            XCTAssertEqual(a.t, b["t"] as! Double, accuracy: 1e-12)
            XCTAssertEqual(a.grepp!.x, g[0], accuracy: 1e-9)
            XCTAssertEqual(a.grepp!.y, g[1], accuracy: 1e-9)
            XCTAssertEqual(a.hosel!.x, h[0], accuracy: 1e-9)
            XCTAssertEqual(a.hosel!.y, h[1], accuracy: 1e-9)
        }
    }

    func testBananSomPython() throws {
        let d = try Self.fixtur()
        let f = Self.film()
        let bana = KlubbSpar.spara(f.rutor, bredd: KlubbFilm.rutBredd, hojd: KlubbFilm.rutHojd, skala: KlubbFilm.skala,
                                   ankare: f.ankare)
        let py = try XCTUnwrap(d["bana"] as? [Any])
        XCTAssertEqual(bana.count, py.count)
        var olika = 0
        for (k, (a, b)) in zip(bana, py).enumerated() {
            guard let b = b as? [String: Any] else {
                XCTAssertNil(a, "ruta \(k)")
                continue
            }
            let a = try XCTUnwrap(a, "ruta \(k)")
            if a.kalla != b["kalla"] as? String { olika += 1 }
            XCTAssertEqual(a.kalla, b["kalla"] as? String, "ruta \(k)")
            XCTAssertEqual(a.x, b["x"] as! Double, accuracy: 1e-6, "ruta \(k)")
            XCTAssertEqual(a.y, b["y"] as! Double, accuracy: 1e-6, "ruta \(k)")
        }
        XCTAssertEqual(olika, 0)
        let planet = KlubbSpar.planet(bana, ankare: f.ankare, xTecken: 1)
        let pyPlan = try XCTUnwrap(d["planet"] as? [[String: Any]])
        XCTAssertEqual(planet.count, pyPlan.count)
        for (a, b) in zip(planet, pyPlan) {
            XCTAssertEqual(a.t, b["t"] as! Double, accuracy: 1e-12)
            XCTAssertEqual(a.grader, b["grader"] as! Double, accuracy: 1e-6)
        }
    }

    /// Felet mot sanningen (METOD M61): spårade rutor median ≤ 2 % och p95 ≤ 5 % av skaftet,
    /// interpolerade högst 20 %, och högst hälften av rutorna interpolerade.
    func testFeletMotSanningen() {
        let f = Self.film()
        let bana = KlubbSpar.spara(f.rutor, bredd: KlubbFilm.rutBredd, hojd: KlubbFilm.rutHojd, skala: KlubbFilm.skala,
                                   ankare: f.ankare)
        var spar: [Double] = [], interp: [Double] = [], n = 0
        for (b, s) in zip(bana, f.sanning) {
            guard let b else { continue }
            n += 1
            let e = ((b.x - s.x) * (b.x - s.x) + (b.y - s.y) * (b.y - s.y)).squareRoot()
            if b.kalla == KlubbSpar.kallaSpar { spar.append(e) }
            if b.kalla == KlubbSpar.kallaInterpolerad { interp.append(e) }
        }
        spar.sort()
        let median = spar[spar.count / 2], p95 = spar[Int(0.95 * Double(spar.count - 1))]
        print("S7b Swift: \(spar.count) spårade, median \(median) px, p95 \(p95) px; \(interp.count) interpolerade, "
              + "max \(interp.max() ?? 0) px; av \(n)")
        XCTAssertLessThanOrEqual(median, 0.02 * KlubbFilm.skaft)
        XCTAssertLessThanOrEqual(p95, 0.05 * KlubbFilm.skaft)
        XCTAssertLessThanOrEqual(interp.max() ?? 0, 0.20 * KlubbFilm.skaft)
        XCTAssertLessThanOrEqual(Double(interp.count) / Double(n), 0.5)
    }

    func testUtanAnkareIngenBana() {
        let r = KlubbSpar.Ruta(t: 0, bild: [UInt8](repeating: 0, count: 16), leder: Array(repeating: nil, count: 13))
        XCTAssertEqual(KlubbSpar.spara([r, r], bredd: 4, hojd: 4, skala: 1, ankare: []), [nil, nil])
        // Ett ankare: bara ankarets ruta.
        let a = KlubbMarkering(position: "P1", t: 0, grepp: KlubbPunkt(x: 1, y: 1), hosel: KlubbPunkt(x: 2, y: 3))
        let b = KlubbSpar.spara([r], bredd: 4, hojd: 4, skala: 1, ankare: [a])
        XCTAssertEqual(b.first??.kalla, "klick")
        XCTAssertEqual(b.first??.x, 2)
    }
}
