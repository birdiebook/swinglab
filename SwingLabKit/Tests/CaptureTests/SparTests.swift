import Foundation
import XCTest
import Swing
@testable import Capture

/// S4f: spåren i granskningen på PÅHITTADE leder (CLAUDE.md, Dataregeln). METOD M60, BESLUT B70
final class SparTests: XCTestCase {
    /// Rutor med 240 bilder/s där handlederna går längs en känd linje.
    static func rutor(_ n: Int, utan: Set<Int> = [], svag: Set<Int> = [], enHand: Set<Int> = []) -> [PoseFrame] {
        (0..<n).map { k in
            let t = Double(k) / 240
            var leder = [PoseJoint?](repeating: PoseJoint(x: 500, y: 500, c: 0.9), count: 13)
            let c = svag.contains(k) ? 0.2 : 0.9
            leder[5] = utan.contains(k) ? nil : PoseJoint(x: 100 + Double(k) * 2 + 10, y: 300, c: c)
            leder[6] = utan.contains(k) || enHand.contains(k) ? nil : PoseJoint(x: 100 + Double(k) * 2 - 10, y: 300, c: c)
            leder[1] = PoseJoint(x: 400, y: 200 + Double(k), c: 0.9)
            leder[2] = PoseJoint(x: 300, y: 200 + Double(k), c: 0.9)
            return PoseFrame(t: t, pts: t, joints: leder, confidence: 0.9)
        }
    }

    func testHandernaArHandledernasMittOchGreppregeln() throws {
        let s = Spar.serier(Self.rutor(40, enHand: [20]), val: [.hands])
        XCTAssertEqual(s.count, 1)
        XCTAssertEqual(s[0].id, "hands")
        // En jämn rörelse ändras inte av utjämningen mitt i serien (M3).
        XCTAssertEqual(s[0].p[10].x, 100 + 20, accuracy: 1e-6)
        XCTAssertEqual(s[0].p[10].y, 300, accuracy: 1e-9)
        // En saknad handled: den andra tar dess plats (M1), så rutan finns (10 px från mitten).
        XCTAssertTrue(s[0].p[20].hel)
    }

    func testAxlarnaArTvaSerierOchKlubbanIngen() {
        let s = Spar.serier(Self.rutor(10), val: [.shoulders, .club, .head])
        XCTAssertEqual(s.map(\.id), ["shoulders_v", "shoulders_h", "head"])
        XCTAssertEqual(s[0].p[5].x, 400, accuracy: 1e-9)
    }

    /// En ruta där leden saknas eller är osäker (< 0,3) ger ett avbrott, aldrig en gissning.
    func testAvbrottDarLedenSaknas() {
        let s = Spar.serier(Self.rutor(40, utan: [15], svag: [16]), val: [.hands])[0]
        XCTAssertFalse(s.p[15].hel)
        XCTAssertFalse(s.p[16].hel)
        let d = s.delar(nu: 1)
        XCTAssertEqual(d.count, 2, "två delar runt luckan")
        XCTAssertEqual(d[0].punkter.count, 15)
        XCTAssertEqual(d[1].punkter.count, 23)
        XCTAssertTrue(d.allSatisfy(\.spelad))
    }

    /// Den spelade delen och resten delar punkten vid gränsen.
    func testSpeladOchKvar() throws {
        let s = Spar.serier(Self.rutor(20), val: [.hands])[0]
        let nu = s.t[7]
        let d = s.delar(nu: nu)
        XCTAssertEqual(d.count, 2)
        XCTAssertTrue(d[0].spelad)
        XCTAssertFalse(d[1].spelad)
        XCTAssertEqual(d[0].punkter.count, 8)
        XCTAssertEqual(d[1].punkter.count, 13)
        XCTAssertEqual(d[0].punkter.last, d[1].punkter.first)
        XCTAssertEqual(try XCTUnwrap(s.punkt(nu: nu)), s.p[7])
        // Före första rutan är inget spelat.
        XCTAssertEqual(s.delar(nu: -1).map(\.spelad), [false])
        XCTAssertNil(s.punkt(nu: -1))
    }

    /// En lucka i rutnätet längre än 0,10 s bryter banan (M3).
    func testLangLuckaITidenBryter() {
        let t: [Double] = [0, 0.01, 0.02, 0.2, 0.21]
        let s = SparSerie(id: "x", punkt: .hands, t: t, p: t.map { Punkt($0, $0) })
        XCTAssertEqual(s.delar(nu: 1).map(\.punkter.count), [3, 2])
    }

    /// Klubbans interpolerade rutor blir egna delar (S7b).
    func testInterpoleradeDelar() {
        let t = (0..<6).map { Double($0) / 240 }
        let s = SparSerie(id: "club", punkt: .club, t: t, p: t.map { Punkt($0, 1) },
                          interpolerad: [false, false, true, true, false, false])
        let d = s.delar(nu: 1)
        XCTAssertEqual(d.map(\.interpolerad), [false, true, false])
        XCTAssertEqual(d.map(\.punkter.count), [2, 3, 3])
    }

    /// En lucka mitt i en snabb rörelse drar inte punkterna bredvid åt ett håll: fönstret
    /// krymper symmetriskt (M60). Mätningens utjämning (M3) drar dem.
    func testLuckaISnabbRorelse() {
        let t = (0..<30).map { Double($0) / 240 }
        var p = t.map { Punkt(2000 * $0, 100) }            // 2 000 px/s
        p[15] = .saknad
        let s = Spar.jamna(t, p)
        for k in [13, 14, 16, 17] {
            XCTAssertEqual(s[k].x, 2000 * t[k], accuracy: 1e-9, "ruta \(k)")
        }
        XCTAssertFalse(s[15].hel)
        let m = Faser.jamna(t, p)
        XCTAssertGreaterThan(abs(m[14].x - 2000 * t[14]), 0.5, "mätningens fönster är ensidigt vid luckan")
    }

    /// En vändning (händerna vid toppen) står kvar på samma ruta och nästan samma ställe.
    func testVandningenStarKvar() throws {
        let t = (0..<60).map { Double($0) / 240 }
        let t0 = t[30]
        let p = t.map { Punkt(300, 400 + 2000 * ($0 - t0) * ($0 - t0)) }   // högst i bilden (minst y) vid t0
        let s = Spar.jamna(t, p)
        let topp = try XCTUnwrap(s.indices.min { s[$0].y < s[$1].y })
        XCTAssertEqual(topp, 30)
        XCTAssertEqual(s[30].y, 400, accuracy: 0.5)
    }

    /// Där greppregeln byter handled bryts banan (punkten hoppar en halv handledsbredd).
    func testGreppregelnBryter() {
        let s = Spar.serier(Self.rutor(40, enHand: Set(20..<30)), val: [.hands])[0]
        XCTAssertEqual(s.brott, [20, 30])
        XCTAssertEqual(s.delar().map(\.punkter.count), [20, 10, 10])
        // Ingen utjämning över brottet: rutan före är exakt mitten.
        XCTAssertEqual(s.p[19].x, 100 + 38, accuracy: 1e-9)
    }

    /// Punkten i rutan saknas när leden saknas där, och gränsen hittas med binärsökning.
    func testPunktenSaknasDarLedenSaknas() {
        let s = Spar.serier(Self.rutor(20, utan: [7]), val: [.hands])[0]
        XCTAssertNil(s.punkt(nu: s.t[7]))
        XCTAssertNotNil(s.punkt(nu: s.t[8]))
        XCTAssertEqual(s.grans(nu: s.t[7] + 0.001), 7)
        XCTAssertNil(s.grans(nu: -1))
        let d = s.delar()
        XCTAssertEqual(SparSerie.spelade(d, till: 10).map(\.punkter.count), [7, 3])
        XCTAssertEqual(SparSerie.spelade(d, till: nil), [])
    }

    /// Lederna och spåren går genom samma avbildning till ytan, också med ett snett utsnitt.
    func testSammaYtaSomLederna() throws {
        let crop = CropRect(x: 0.37, y: 0.03, width: 0.55, height: 0.33)
        var f = Self.rutor(1)[0]
        f.joints[0] = PoseJoint(x: 700, y: 300, c: 0.9)
        let serie = JointSeries(width: 1080, height: 1920, frames: [f])
        let review = ShotReview(series: serie, crop: crop)
        let led = try XCTUnwrap(review.overlay(0).points[0])
        let y = ShotReview.yta(x: 700, y: 300, bredd: 1080, hojd: 1920, crop: review.crop)
        XCTAssertEqual(led.x, y.x, accuracy: 1e-12)
        XCTAssertEqual(led.y, y.y, accuracy: 1e-12)
        XCTAssertEqual(y.x, (700.0 / 1080 - review.crop.x) / review.crop.width, accuracy: 1e-12)
        XCTAssertEqual(y.y, (300.0 / 1920 - review.crop.y) / review.crop.height, accuracy: 1e-12)
    }
}
