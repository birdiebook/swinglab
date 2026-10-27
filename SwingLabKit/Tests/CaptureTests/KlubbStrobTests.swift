import Foundation
import XCTest
@testable import Capture

// S7-2: stroboskopet (METOD MF7). Samma fall som Stroboskopet i tools/tests/test_formarkare.py
// (BESLUT B12): bara huvudet klistras in, medianen stoppar hålet efter adressen, och ett ensamt
// hopp tas bort. Utsnittet kring händerna som formarkare.utsnitt.

final class KlubbStrobTests: XCTestCase {
    private static func fylld(_ v: UInt8, _ n: Int = 100) -> RGBABild {
        RGBABild(bredd: n, hojd: n, pixlar: [UInt8](repeating: v, count: n * n * 4))
    }

    private static func malad(_ b: inout RGBABild, x: Range<Int>, y: Range<Int>, _ v: UInt8) {
        for yy in y { for xx in x { for c in 0..<3 { b.pixlar[(yy * b.bredd + xx) * 4 + c] = v } } }
    }

    private static func bilder() -> (bas: RGBABild, median: RGBABild, ram: RGBABild) {
        var bas = fylld(120)
        malad(&bas, x: 60..<90, y: 60..<70, 30)          // klubban i adressen, bara i grundbilden
        let median = fylld(120)
        var ram = median
        malad(&ram, x: 20..<30, y: 20..<30, 250)         // huvudet i rutan
        malad(&ram, x: 62..<88, y: 62..<68, 120)         // där klubban stod syns gräset
        return (bas, median, ram)
    }

    private static func lager(_ box: [Double], median: Bool) -> StrobLager? {
        let (bas, med, ram) = bilder()
        guard let r = KlubbStrob.ruta(box, bredd: 100, hojd: 100) else { return nil }
        return KlubbStrob.lager(pixlar: KlubbStrob.del(ram, x0: r.x0, y0: r.y0, bredd: r.bredd, hojd: r.hojd),
                                x0: r.x0, y0: r.y0, bredd: r.bredd, hojd: r.hojd, bas: bas, median: median ? med : nil)
    }

    func testBaraHuvudetKlistrasIn() throws {
        var bild = Self.bilder().bas
        KlubbStrob.lagg(try XCTUnwrap(Self.lager([20, 20, 10, 10], median: true)), i: &bild)
        XCTAssertEqual(Array(bild.pixlar[((25 * 100 + 25) * 4)..<((25 * 100 + 25) * 4 + 3)]), [250, 250, 250])
        XCTAssertEqual(Array(bild.pixlar[((15 * 100 + 15) * 4)..<((15 * 100 + 15) * 4 + 3)]), [120, 120, 120])
    }

    func testMedianenStopparHaletEfterAdressen() {
        XCTAssertNotNil(Self.lager([62, 62, 26, 6], median: false))   // bara mot grundbilden: gräset följer med
        XCTAssertNil(Self.lager([62, 62, 26, 6], median: true))       // mot medianen också: inget
    }

    func testEnsamtHoppTasBort() {
        var huvud = Dictionary(uniqueKeysWithValues: (0..<6).map { ($0, [10.0 * Double($0), 0, 8, 8]) })
        huvud[3] = [30, 200, 8, 8]                                     // handsken i en ruta
        XCTAssertEqual(KlubbStrob.ensamma(huvud), [3])
        let snabb = Dictionary(uniqueKeysWithValues: (0..<4).map { ($0, [40.0 * Double($0), 0, 8, 8]) })
        XCTAssertEqual(KlubbStrob.ensamma(snabb), [])
    }

    func testMedianbilden() throws {
        let m = try XCTUnwrap(KlubbStrob.median([Self.fylld(10, 2), Self.fylld(200, 2), Self.fylld(30, 2)]))
        XCTAssertEqual(m.pixlar[0], 30)
        let jamn = try XCTUnwrap(KlubbStrob.median([Self.fylld(10, 2), Self.fylld(21, 2), Self.fylld(30, 2), Self.fylld(200, 2)]))
        XCTAssertEqual(jamn.pixlar[0], 25)                              // (21 + 30) / 2 nedåt, som numpy → uint8
        XCTAssertEqual(KlubbStrob.medianIndex(forsta: 10, sista: 20, antal: 3), [10, 15, 20])
    }

    func testUtsnittetKringHanderna() throws {
        // Som Kontaktarket i test_formarkare.py: kroppen 1000 px, handlederna (400, 1000) och (440, 1020).
        var leder = [PoseJoint?](repeating: nil, count: 13)
        leder[5] = PoseJoint(x: 400, y: 1000, c: 0.9)
        leder[6] = PoseJoint(x: 440, y: 1020, c: 0.8)
        let f = PoseFrame(t: 0, pts: 0, joints: leder, confidence: 1)
        let kropp = (hojd: 1000.0, x: 510.0, y: 900.0)
        let u = KlubbStrob.utsnitt(f, kropp: kropp, bredd: 1080, hojd: 1920)
        XCTAssertEqual([u.x0, u.y0, u.sida], [-480, 110, 1800])
        leder[6] = PoseJoint(x: 440, y: 1020, c: 0.1)                   // greppregeln: den som syns
        let v = KlubbStrob.utsnitt(PoseFrame(t: 0, pts: 0, joints: leder, confidence: 1), kropp: kropp, bredd: 1080, hojd: 1920)
        XCTAssertEqual([v.x0, v.y0], [-500, 100])
    }

    func testKroppensHojdArRutansEgen() throws {
        func ruta(_ ys: [Double]) -> PoseFrame {
            PoseFrame(t: 0, pts: 0, joints: ys.map { PoseJoint(x: 0, y: $0, c: 0.9) } + [nil], confidence: 1)
        }
        let sta = ruta([0, 100, 200, 300, 400, 1000]), upp = ruta([-500, 100, 200, 300, 400, 1000])
        XCTAssertEqual(try XCTUnwrap(KlubbStrob.kroppen([sta, sta, upp])).hojd, 1000)
    }
}
