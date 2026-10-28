import Foundation
import XCTest
@testable import Capture

// S7-2: stroboskopet (METOD MF7). Samma fall som Stroboskopet i tools/tests/test_formarkare.py
// (BESLUT B12): bara huvudet klistras in, inte hålet efter adressen eller kroppen som flyttat sig,
// och ett ensamt hopp tas bort. Utsnittet kring händerna som formarkare.utsnitt.

final class KlubbStrobTests: XCTestCase {
    private static func fylld(_ v: UInt8, _ n: Int = 100) -> RGBABild {
        RGBABild(bredd: n, hojd: n, pixlar: [UInt8](repeating: v, count: n * n * 4))
    }

    private static func malad(_ b: inout RGBABild, x: Range<Int>, y: Range<Int>, _ v: UInt8) {
        for yy in y { for xx in x { for c in 0..<3 { b.pixlar[(yy * b.bredd + xx) * 4 + c] = v } } }
    }

    private static func bilder() -> (fore: RGBABild, efter: RGBABild, median: RGBABild, ram: RGBABild) {
        var fore = fylld(120)
        malad(&fore, x: 60..<90, y: 60..<70, 30)         // klubban i adressen, bara i rutan före
        let median = fylld(120)
        var ram = median
        malad(&ram, x: 20..<30, y: 20..<30, 250)         // huvudet i rutan
        malad(&ram, x: 62..<88, y: 62..<68, 120)         // där klubban stod syns gräset
        return (fore, median, median, ram)
    }

    private static func lager(_ ram: RGBABild, _ box: [Double], _ referenser: [RGBABild?]) -> StrobLager? {
        guard let r = KlubbStrob.ruta(box, bredd: ram.bredd, hojd: ram.hojd) else { return nil }
        func del(_ b: RGBABild) -> [UInt8] { KlubbStrob.del(b, x0: r.x0, y0: r.y0, bredd: r.bredd, hojd: r.hojd) }
        return KlubbStrob.lager(pixlar: del(ram), x0: r.x0, y0: r.y0, bredd: r.bredd, hojd: r.hojd,
                                referenser: referenser.map { $0.map(del) })
    }

    func testBaraHuvudetKlistrasIn() throws {
        let (fore, efter, median, ram) = Self.bilder()
        var bild = fore
        KlubbStrob.lagg(try XCTUnwrap(Self.lager(ram, [20, 20, 10, 10], [fore, efter, median])), i: &bild)
        XCTAssertEqual(Array(bild.pixlar[((25 * 100 + 25) * 4)..<((25 * 100 + 25) * 4 + 3)]), [250, 250, 250])
        XCTAssertEqual(Array(bild.pixlar[((15 * 100 + 15) * 4)..<((15 * 100 + 15) * 4 + 3)]), [120, 120, 120])
    }

    func testHaletEfterAdressenKlistrasInteIn() {
        let (fore, efter, median, ram) = Self.bilder()
        XCTAssertNotNil(Self.lager(ram, [62, 62, 26, 6], [fore]))                  // bara mot rutan före: gräset följer med
        XCTAssertNil(Self.lager(ram, [62, 62, 26, 6], [fore, efter, median]))      // skiljer sig bara från en av tre
    }

    func testKroppenSomFlyttatSigKlistrasInteIn() {
        // Himlen där axeln stod vid adressen (appen, 2026-10-28): bara medianen har jackan.
        let himmel = Self.fylld(200)
        var jacka = himmel
        Self.malad(&jacka, x: 40..<80, y: 40..<80, 20)
        XCTAssertNil(Self.lager(himmel, [50, 50, 10, 10], [himmel, himmel, jacka]))
        XCTAssertNotNil(Self.lager(himmel, [50, 50, 10, 10], [nil, nil, jacka]))
    }

    func testHuvudetOverSkaftetStarKvar() throws {
        let b = Self.bilder()
        var fore = b.fore
        Self.malad(&fore, x: 24..<26, y: 20..<30, 250)    // skaftet genom huvudets plats i rutan före
        let l = try XCTUnwrap(Self.lager(b.ram, [20, 20, 10, 10], [fore, b.efter, b.median]))
        XCTAssertTrue(l.mask[(25 - l.y0) * l.bredd + (25 - l.x0)])
    }

    func testDelenUrMedianbildenIHalvUpplosning() {
        var halv = Self.fylld(0, 4)
        Self.malad(&halv, x: 1..<2, y: 2..<3, 99)                          // pixeln (1, 2) i halv upplösning
        let d = KlubbStrob.del(halv, x0: 2, y0: 4, bredd: 2, hojd: 2, skala: 0.5)
        XCTAssertEqual([d[0], d[4], d[8], d[12]], [99, 99, 99, 99])        // (2…3, 4…5) i hel är (1, 2) i halv
        XCTAssertEqual(KlubbStrob.del(halv, x0: 6, y0: 6, bredd: 4, hojd: 4, skala: 0.5).count, 64)   // utanför: kanten
    }

    func testGrannarnaArRutornaDarHuvudetVarNagonAnnanstans() {
        let huvud: [Int: [Double]] = [0: [0, 0, 10, 10], 1: [4, 0, 10, 10], 2: [8, 0, 10, 10], 3: [30, 0, 10, 10],
                                      4: [60, 0, 10, 10]]
        let g = KlubbStrob.grannar(huvud, bredd: 100, hojd: 100)
        XCTAssertEqual(g[0]?.fore, nil)
        XCTAssertEqual(g[0]?.efter, 3)
        XCTAssertEqual(g[3]?.fore, 2)
        XCTAssertEqual(g[3]?.efter, 4)
        XCTAssertEqual(g[4]?.efter, nil)
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
