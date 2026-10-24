import Foundation
import XCTest
import Swing
import SwingDemo
@testable import Capture

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
                                   ankare: f.ankare, bildBredd: KlubbFilm.bredd, bildHojd: KlubbFilm.hojd)
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

    /// Glesa ankare: bara grannar i svingens ordning ger en bana, som Python (METOD M61).
    func testGlesaAnkareSomPython() throws {
        let d = try Self.fixtur()
        let f = Self.film()
        let glesa = try XCTUnwrap(d["glesa"] as? [String: [Any]])
        XCTAssertEqual(glesa.count, 3)
        for (namn, py) in glesa {
            let keep = Set(namn.split(separator: ",").map(String.init))
            let bana = KlubbSpar.spara(f.rutor, bredd: KlubbFilm.rutBredd, hojd: KlubbFilm.rutHojd, skala: KlubbFilm.skala,
                                       ankare: f.ankare.filter { keep.contains($0.position) },
                                       bildBredd: KlubbFilm.bredd, bildHojd: KlubbFilm.hojd)
            XCTAssertEqual(bana.count, py.count)
            for (k, (a, b)) in zip(bana, py).enumerated() {
                guard let b = b as? [String: Any] else {
                    XCTAssertNil(a, "\(namn) ruta \(k)")
                    continue
                }
                let a = try XCTUnwrap(a, "\(namn) ruta \(k)")
                XCTAssertEqual(a.kalla, b["kalla"] as? String, "\(namn) ruta \(k)")
                XCTAssertEqual(a.x, b["x"] as! Double, accuracy: 1e-6)
                XCTAssertEqual(a.y, b["y"] as! Double, accuracy: 1e-6)
            }
        }
        // P1, P4, P7 och P10: bara ankarna.
        let p = KlubbSpar.spara(f.rutor, bredd: KlubbFilm.rutBredd, hojd: KlubbFilm.rutHojd, skala: KlubbFilm.skala,
                                ankare: f.ankare.filter { ["P1", "P4", "P7", "P10"].contains($0.position) })
        XCTAssertEqual(p.compactMap { $0 }.map(\.kalla), ["klick", "klick", "klick", "klick"])
        XCTAssertEqual(KlubbSpar.segment(["P1", "P2", "P4", "P5", "P10"]).map { [$0.0, $0.1] }, [[0, 1], [2, 3]])
    }

    /// Felet mot sanningen (METOD M61): spårade rutor median ≤ 2 % och p95 ≤ 5 % av skaftet,
    /// interpolerade högst 20 %, och högst hälften av rutorna interpolerade.
    func testFeletMotSanningen() {
        let f = Self.film()
        let bana = KlubbSpar.spara(f.rutor, bredd: KlubbFilm.rutBredd, hojd: KlubbFilm.rutHojd, skala: KlubbFilm.skala,
                                   ankare: f.ankare, bildBredd: KlubbFilm.bredd, bildHojd: KlubbFilm.hojd)
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

/// S7b: datamodellen för banan och formatets version 3 (BESLUT B71).
final class KlubbBanaTests: XCTestCase {
    static let marks = [
        KlubbMarkering(position: "P4", t: -0.25, grepp: KlubbPunkt(x: 10, y: 10), hosel: KlubbPunkt(x: 20, y: 0)),
        KlubbMarkering(position: "P1", t: -0.9, grepp: KlubbPunkt(x: 10, y: 50), hosel: KlubbPunkt(x: 12, y: 90),
                       greppKalla: Klubba.kallaRing),
        KlubbMarkering(position: "P2", t: -0.6, grepp: nil, hosel: nil, hoppad: true),
    ]

    static func bana() -> KlubbBana {
        KlubbBana([KlubbSpar.BanPunkt(t: -0.9, x: 12, y: 90, kalla: "klick"),
                   KlubbSpar.BanPunkt(t: -0.5, x: 30, y: 60, kalla: "spar"),
                   KlubbSpar.BanPunkt(t: -0.4, x: 31, y: 40, kalla: "interpolerad"),
                   KlubbSpar.BanPunkt(t: -0.25, x: 20, y: 0, kalla: "klick")], ankare: marks)
    }

    func testAnkarnaOchAktuell() {
        let b = Self.bana()
        XCTAssertEqual(b.ankare.map(\.position), ["P1", "P4"], "bara markerade, i tidsordning")
        XCTAssertTrue(b.aktuell(Self.marks))
        XCTAssertTrue(b.aktuell(Array(Self.marks.reversed())), "greppets källa och ordningen spelar ingen roll")
        var m = Self.marks
        m[0].hosel = KlubbPunkt(x: 21, y: 0)
        XCTAssertFalse(b.aktuell(m), "en flyttad markering ger en ny bana")
        XCTAssertFalse(KlubbBana.mojlig([Self.marks[0]]))
        XCTAssertTrue(KlubbBana.mojlig(Self.marks))
        XCTAssertEqual(b.andelInterpolerade, 0.25)
    }

    func testGodkannOchRatta() {
        var b = Self.bana()
        b.godkann(1)
        XCTAssertEqual(b.punkter[1].granskning, KlubbBanPunkt.godkand)
        b.godkann(0)
        XCTAssertNil(b.punkter[0].granskning, "ett ankare godkänns inte här")
        b.ratta(2, till: KlubbPunkt(x: 33, y: 41))
        XCTAssertEqual(b.punkter[2].kalla, "klick")
        XCTAssertEqual(b.punkter[2].granskning, KlubbBanPunkt.rattad)
        XCTAssertEqual(b.punkter[2].fore, KlubbPunkt(x: 31, y: 40))
        XCTAssertEqual(b.punkter[2].foreKalla, "interpolerad")
        b.ratta(0, till: KlubbPunkt(x: 1, y: 1))
        XCTAssertEqual(b.punkter[0].x, 12, "ett ankare rättas i märkningen")
    }

    func testFilensVersion3() throws {
        var b = Self.bana()
        b.ratta(2, till: KlubbPunkt(x: 33, y: 41))
        let rutor = KlubbFil.banrutor(b, vy: .dtl, slag: "s01", fil: "f.zip", bredd: 100, hojd: 100,
                                      visad: [0, 0, 100, 100], tKlipp: { $0 + 1 })
        XCTAssertEqual(rutor.map(\.val), ["bana", "bana"], "ankarna står som markeringar, inte i banan")
        var fil = KlubbFil(pass: "20261103-180000", kalla: ["f.zip"], andrad: "2026-11-03T21:15:00+01:00",
                           rutor: Self.marks.map { KlubbFil.ruta($0, vy: .dtl, slag: "s01", fil: "f.zip", bredd: 100,
                                                                 hojd: 100, visad: [0, 0, 100, 100], tKlipp: nil) }
                               + rutor)
        fil.format = KlubbFil.format3
        let data = try JSONEncoder().encode(fil)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertEqual(text.components(separatedBy: "\"granskning\"").count - 1, 2, "granskning bara i banans rutor")
        let las = try KlubbFil.las(data)
        XCTAssertEqual(las.format, KlubbFil.format3)
        XCTAssertEqual(las.markeringar()["s01"]?.count, 3, "banans rutor är inga markeringar")
        let banan = try XCTUnwrap(las.banor()["s01"])
        XCTAssertEqual(banan.map(\.kalla), ["spar", "klick"])
        XCTAssertEqual(banan[1].granskning, "rattad")
        XCTAssertEqual(banan[1].fore, KlubbPunkt(x: 31, y: 40))
        XCTAssertEqual(banan[1].foreKalla, "interpolerad")
        XCTAssertEqual(rutor[1].forslag["klubbhuvud"]?.kalla, "interpolerad")
        XCTAssertEqual(rutor[0].tKlipp, 0.5)
    }

    func testSparSerienUrBanan() {
        let s = SparSerie(bana: Self.bana())
        XCTAssertEqual(s.punkt, .club)
        XCTAssertEqual(s.interpolerad, [false, false, true, false])
        XCTAssertEqual(s.p[1], Punkt(30, 60))
    }
}

/// S7b: rutorna ur det lagrade Y-planet, vridna upprätt som lederna (METOD MS7, M61).
final class KlubbRutorTests: XCTestCase {
    func testVridningenSomLederna() {
        let W = 6, H = 4, rad = 8
        let plan = (0..<(rad * H)).map { UInt8($0 % 256) }
        for exif: UInt32 in [1, 3, 6, 8] {
            let r = plan.withUnsafeBufferPointer { KlubbRutor.upratt($0, radBytes: rad, width: W, height: H, exif: exif, skala: 1) }
            let upp = Orientation.uprightSize(width: W, height: H, exif: exif)
            XCTAssertEqual(r.bredd, upp.width)
            XCTAssertEqual(r.hojd, upp.height)
            for v in 0..<r.hojd {
                for u in 0..<r.bredd {
                    // Pixelns mitt genom den normaliserade avbildningen (MS7) ger samma lagrade pixel.
                    let s = Orientation.stored(x: (Double(u) + 0.5) / Double(r.bredd), y: (Double(v) + 0.5) / Double(r.hojd),
                                               exif: exif)
                    let bx = Int(s.x * Double(W)), by = Int(s.y * Double(H))
                    XCTAssertEqual(r.bild[v * r.bredd + u], plan[by * rad + bx], "exif \(exif) (\(u), \(v))")
                }
            }
        }
    }

    func testSkalanOchSpannet() {
        XCTAssertEqual(KlubbRutor.skala(uprightWidth: 1080, uprightHeight: 1920), 320.0 / 1080.0)
        XCTAssertEqual(KlubbRutor.skala(uprightWidth: 200, uprightHeight: 300), 1)
        let frames = (0..<100).map { PoseFrame(t: Double($0) / 240, pts: Double($0) / 240, joints: [], confidence: 0.9) }
        let a = [KlubbMarkering(position: "P1", t: 10.0 / 240, grepp: KlubbPunkt(x: 0, y: 0), hosel: KlubbPunkt(x: 1, y: 1)),
                 KlubbMarkering(position: "P4", t: 50.0 / 240, grepp: KlubbPunkt(x: 0, y: 0), hosel: KlubbPunkt(x: 1, y: 1))]
        XCTAssertEqual(KlubbRutor.spann(frames, ankare: a), 7...53)
        XCTAssertNil(KlubbRutor.spann(frames, ankare: [a[0]]))
    }
}
