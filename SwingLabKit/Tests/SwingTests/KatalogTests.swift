import XCTest
@testable import Swing

/// Katalogen (katalog.json, BESLUT B6) och bedömningen (METOD M27).
final class KatalogTests: XCTestCase {
    func katalog() throws -> Katalog { try Katalog.las(json: Fixturer.katalog) }

    func fel(_ id: String) throws -> Katalog.Fel {
        let k = try katalog()
        return try XCTUnwrap(k.fel.first { $0.id == id }, id)
    }

    func testKatalogenPekarPaMattSomFinns() throws {
        let k = try katalog()
        XCTAssertEqual(k.fel.count, 12)
        for f in k.fel {
            let namn: [String]
            if f.vy == "bada" {
                namn = Matt.namnDTL.filter { Matt.namnFO.contains($0) }
            } else {
                let vy = try XCTUnwrap(Vy(rawValue: f.vy), f.id)
                namn = Matt.namn(vy)
            }
            XCTAssertTrue(namn.contains(f.matt), f.id)
            XCTAssertFalse(f.kontrollerad, f.id)            // BESLUT B10: inget läst i original än
        }
        let axel = try fel("axellutning")
        XCTAssertFalse(axel.aktiv)
    }

    func testSwayVidToppen() throws {
        let f = try fel("sway_topp")
        let fall: [(Double, Bedomningsstatus)] = [(3, .gron), (0, .gron), (-0.1, .gul), (-5, .gul), (-5.01, .rod)]
        for (v, status) in fall {
            XCTAssertEqual(Bedomare.bedom(f, varde: v, baslinje: []).status, status, "\(v)")
        }
    }

    func testTempotBlirAldrigRott() throws {
        let f = try fel("tempo")
        XCTAssertEqual(Bedomare.bedom(f, varde: 2.8, baslinje: []).status, .gron)
        XCTAssertEqual(Bedomare.bedom(f, varde: 3.4, baslinje: []).status, .gul)
        XCTAssertEqual(Bedomare.bedom(f, varde: 1.2, baslinje: []).status, .gul)
    }

    func testBaslinjen() throws {
        let f = try fel("early_extension")                  // samre "+"
        let bas = (0...8).map { Double($0) }                // median 4, spridning 4/1,349
        let spr = 4.0 / 1.349
        XCTAssertEqual(Bedomare.bedom(f, varde: 4 + 0.5 * spr, baslinje: bas).status, .gron)
        XCTAssertEqual(Bedomare.bedom(f, varde: 4 + 1.5 * spr, baslinje: bas).status, .gul)
        XCTAssertEqual(Bedomare.bedom(f, varde: 4 + 2.5 * spr, baslinje: bas).status, .rod)
        let battre = Bedomare.bedom(f, varde: 4 - 2.5 * spr, baslinje: bas)
        XCTAssertEqual(battre.status, .gron)
        XCTAssertEqual(battre.z!, -2.5, accuracy: 1e-12)
        XCTAssertEqual(Bedomare.bedom(f, varde: 9, baslinje: Array(bas.prefix(7))).status, .okand)
        let axel = try fel("axellutning")
        XCTAssertEqual(Bedomare.bedom(axel, varde: 9, baslinje: bas).status, .av)
    }

    func testBedomningenSomPython() throws {
        let py = try avkoda(PythonSession.self, Fixturer.session)
        let k = try katalog()
        let b = Bedomare.bedom(k, nu: py.nu, tidigare: py.forra)
        XCTAssertEqual(b.map { $0.id }, py.bedomning.map { $0.id })
        for (s, p) in zip(b, py.bedomning) {
            XCTAssertEqual(s.status.rawValue, p.status, s.id)
            XCTAssertEqual(s.grund, p.grund, s.id)
            XCTAssertEqual(s.varde == nil, p.varde == nil, s.id)
            if let a = s.varde, let c = p.varde { XCTAssertEqual(a, c, accuracy: 1e-9, s.id) }
            XCTAssertEqual(s.z == nil, p.z == nil, s.id)
            if let a = s.z, let c = p.z { XCTAssertEqual(a, c, accuracy: 1e-9, s.id) }
        }
        // Kvittot: passet prövar flera utfall, inte bara grönt.
        XCTAssertGreaterThanOrEqual(Set(b.map { $0.status }).count, 4)
    }
}
