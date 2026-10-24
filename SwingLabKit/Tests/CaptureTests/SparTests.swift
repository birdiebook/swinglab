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
}
