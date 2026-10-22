import XCTest
@testable import Swing

/// Swift mot Python (BESLUT B12): samma påhittade leder ska ge samma tal.
/// Facit är tools/pc/matt.py, skrivet i Fixturer.swift av tools/pc/generera.py --swift.
final class MattTests: XCTestCase {
    /// Spec: varje mått inom 0,05 från Pythons.
    static let tolerans = 0.05

    func testVarjeSvingGerPythonsTal() throws {
        XCTAssertEqual(Fixturer.svingar.map { $0.namn }, ["fo", "fo_vanster", "dtl", "dtl_lucka"])
        var jamforda = 0
        for f in Fixturer.svingar {
            let sving = try Sving.las(json: f.indata)
            let python = try avkoda(PythonSving.self, f.python)
            let r = try Matt.mat(sving)
            XCTAssertEqual(Set(r.matt.keys), Set(python.matt.keys), "\(f.namn): samma mått")
            for (k, v) in python.matt {
                guard let s = r.matt[k] else { continue }
                XCTAssertEqual(s, v, accuracy: Self.tolerans, "\(f.namn): \(k)")
                jamforda += 1
            }
            XCTAssertEqual(r.cmPerPx, python.cmPerPx, accuracy: 1e-6 * python.cmPerPx, "\(f.namn): skalan")
            XCTAssertEqual(r.faser.topp, python.faser.topp, accuracy: 0.001, "\(f.namn): toppen")
            XCTAssertEqual(r.faser.traff, python.faser.traff, "\(f.namn): träffen")
            XCTAssertEqual(r.faser.start == nil, python.faser.start == nil, "\(f.namn): starten")
            if let a = r.faser.start, let b = python.faser.start {
                XCTAssertEqual(a, b, accuracy: 0.001, "\(f.namn): starten")
            }
        }
        // Kvittot: testet jämförde verkligen måtten (FO 34, DTL 28, luckan 23: 119).
        XCTAssertGreaterThan(jamforda, 110)
    }

    func testDePahittadeFormerna() throws {
        // Figurens bäcken står 6 cm bakom adressen vid toppen och 8 cm framför vid
        // träffen; fixturen har 0,8 px brus, så ±0,5 cm.
        let fo = try Matt.mat(Sving.las(json: Fixturer.svingar[0].indata))
        XCTAssertEqual(fo.matt["backen_sway_topp"]!, -6.0, accuracy: 0.5)
        XCTAssertEqual(fo.matt["backen_resa_framat"]!, 14.0, accuracy: 0.5)
        XCTAssertEqual(fo.matt["stans_bredd"]!, 1.2, accuracy: 0.02)
        XCTAssertEqual(fo.cmPerPx, 0.25, accuracy: 0.005)
        let dtl = try Matt.mat(Sving.las(json: Fixturer.svingar[2].indata))
        XCTAssertEqual(dtl.matt["backen_thrust_traff"]!, 3.0, accuracy: 0.5)
        XCTAssertEqual(dtl.matt["brost_bojning_adress"]!, 40.0, accuracy: 1.0)
        XCTAssertGreaterThan(dtl.matt["handbana"]!, 0)              // + = over the top
    }

    func testVansterspelarenRaknasSomHoger() throws {
        let v = try Matt.mat(Sving.las(json: Fixturer.svingar[1].indata))
        XCTAssertEqual(v.hand, .vanster)
        XCTAssertEqual(v.matt["backen_sway_topp"]!, -6.0, accuracy: 0.5)      // − = bort från målet även här
        XCTAssertEqual(v.matt["sidbojning_traff"]!, 25.0, accuracy: 1.5)
    }

    func testLangLuckaTarBortMattenIFasen() throws {
        let r = try Matt.mat(Sving.las(json: Fixturer.svingar[3].indata))
        XCTAssertNil(r.matt["backen_thrust_topp"])
        XCTAssertNil(r.matt["huvud_lyft_finish"])
        XCTAssertNotNil(r.matt["backen_thrust_traff"])
    }

    func testNamnenPerVy() {
        XCTAssertEqual(Matt.namnFO.count, 34)
        XCTAssertEqual(Matt.namnDTL.count, 28)
        XCTAssertEqual(Set(Matt.namnFO).count, Matt.namnFO.count)
        XCTAssertTrue(Matt.namnDTL.contains("handbana"))
        XCTAssertTrue(Matt.namnFO.contains("backen_resa_framat"))
    }

    func testVinklarna() {
        XCTAssertEqual(Matt.bojning(Punkt(0, -1), Punkt(0, 0), Punkt(0, 1)), 0, accuracy: 1e-12)
        XCTAssertEqual(Matt.bojning(Punkt(0, -1), Punkt(0, 0), Punkt(1, 0)), 90, accuracy: 1e-12)
        XCTAssertTrue(Matt.bojning(Punkt(0, 0), Punkt(0, 0), Punkt(1, 0)).isNaN)
        XCTAssertEqual(Matt.vinkelFranLod(Punkt(0, 0), Punkt(1, -1)), 45, accuracy: 1e-12)     // y nedåt
        XCTAssertEqual(Matt.linjensLutning(fram: Punkt(1, -1), bak: Punkt(0, 0)), 45, accuracy: 1e-12)
    }
}
