import Foundation
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
        // Kopplingen mått → position (BESLUT B32), som test_katalog.py.
        XCTAssertEqual(try fel("sway_topp").positioner, ["P4"])
        XCTAssertEqual(try fel("over_the_top").positioner, ["P5"])
        XCTAssertEqual(try fel("tempo").positioner, [])
        XCTAssertEqual(try fel("backens_resa_framat").positioner, [])       // resan visas vid P5
        XCTAssertEqual(k.matt.first { $0.matt == "backen_sway_p3" }?.fel, "sway_topp")
        XCTAssertEqual(k.matt.first { $0.matt == "backen_resa_p5" }?.fel, "backens_resa_framat")
        XCTAssertNil(k.matt.first { $0.matt == "stans_bredd" }?.fel)
        // Tilläggen mot Sportsbox (PLAN S1b, METOD M30–M37): 23 mått, två följer ett fel.
        XCTAssertEqual(k.matt.count, 33)
        XCTAssertEqual(k.matt.first { $0.matt == "bakre_kna_sway_topp" }?.fel, "sway_topp")
        XCTAssertNil(k.matt.first { $0.matt == "backen_bojning_traff" }?.fel)     // visar inte early extension
        XCTAssertEqual(k.matt.first { $0.matt == "framre_arm_vinkelfart_max" }?.positioner, ["P5"])
        // Farterna är oprövade på telefonen och märks så (METOD M35–M37, BESLUT B11).
        XCTAssertEqual(Set(k.matt.filter { $0.status == "oprovad" }.map { $0.matt }),
                       ["handfart_max", "handfart_max_fore_traff_ms", "framre_arm_vinkelfart_max"])
        XCTAssertEqual(k.matt.first { $0.matt == "handfart_max" }.map { Markning.fran($0) }, .oprovad)
        XCTAssertEqual(k.matt.first { $0.matt == "stans_bredd" }.map { Markning.fran($0) }, .egen)
        for m in k.matt {
            let vy = try XCTUnwrap(Vy(rawValue: m.vy), m.matt)
            XCTAssertTrue(Matt.namn(vy).contains(m.matt), m.matt)
        }
        let alla = Set(k.fel.flatMap { $0.positioner } + k.matt.flatMap { $0.positioner })
        XCTAssertEqual(alla, Set(Positioner.namn))
    }

    /// Katalogen med en ändring (första förekomsten).
    func andrad(_ fran: String, _ till: String) -> String {
        let k = Fixturer.katalog
        guard let r = k.range(of: fran) else {
            XCTFail("finns inte i katalogen: \(fran)")
            return k
        }
        return k.replacingCharacters(in: r, with: till)
    }

    /// Samma fall som test_katalog.py (Formen.test_formfelen_hittas).
    static let formfel: [(fran: String, till: String, vantat: String)] = [
        ("\"matt\": \"backen_sway_topp\"", "\"matt\": \"finns_inte\"", "sway_topp: måttet finns inte i vyn"),
        ("\"vy\": \"bada\"", "\"vy\": \"sida\"", "tempo: vy ska vara"),
        ("\"status\": \"tillverkare\"", "\"status\": \"rykte\"", "sway_topp: status ska vara"),
        ("\"samre\": \"-\"", "\"samre\": \"x\"", "sway_topp: samre ska vara"),
        ("\"gront\": [0, null]", "\"gront\": null", "sway_topp: gult utan gront"),
        ("\"id\": \"tempo\"", "\"id\": \"sway_topp\"", "sway_topp: id finns två gånger"),
        ("\"gront\": [2.5, 3.1]", "\"gront\": [2.5]", "tempo: gront ska vara"),
        ("\"positioner\": [\"P4\"]", "\"positioner\": [\"P2\"]", "sway_topp: positioner ska vara"),
        ("\"positioner\": [\"P4\"]", "\"positioner\": [\"P4\", \"P1\"]", "sway_topp: positioner ska vara"),
        ("\"positioner\": [\"P4\"]", "\"positioner\": [\"P4\", \"P4\"]", "sway_topp: positioner ska vara"),
        ("{\"matt\": \"backen_sway_p3\", \"vy\": \"fo\"", "{\"matt\": \"backen_sway_p3\", \"vy\": \"dtl\"",
         "matt backen_sway_p3: måttet finns inte i vyn"),
        ("{\"matt\": \"stans_bredd\"", "{\"matt\": \"backen_sway_topp\"", "matt backen_sway_topp: står redan i katalogen"),
        ("\"positioner\": [\"P10\"]", "\"positioner\": []", "matt huvud_backen_finish: positioner ska vara"),
        ("{\"matt\": \"stans_bredd\", \"vy\": \"fo\"", "{\"matt\": \"stans_bredd\", \"vy\": \"bada\"",
         "matt stans_bredd: vy ska vara"),
        ("\"fel\": \"sway_topp\"}", "\"fel\": \"finns_inte\"}", "matt backen_sway_p3: fel ska vara ett fel i katalogen"),
        ("{\"matt\": \"stans_bredd\", \"vy\": \"fo\",", "{\"matt\": \"stans_bredd\", \"x\": 1, \"vy\": \"fo\",",
         "matt stans_bredd: ska ha matt, vy och positioner, och får ha fel"),
        ("\"status\": \"oprovad\"}", "\"status\": \"provad\"}",
         "matt framre_arm_vinkelfart_max: status ska vara oprovad"),
    ]

    func testKontrollernaSomPython() throws {
        let hel = try katalog()
        XCTAssertEqual(Katalog.kontrollera(hel), [])
        for f in Self.formfel {
            let k = try Katalog.avkoda(Data(andrad(f.fran, f.till).utf8))
            let fel = Katalog.kontrollera(k)
            XCTAssertTrue(fel.contains { $0.hasPrefix(f.vantat) }, "\(f.vantat): \(fel)")
            XCTAssertThrowsError(try Katalog.las(json: andrad(f.fran, f.till)), f.vantat)
        }
    }

    func testEttFaltSomSaknasFalls() {
        // samre får vara null men måste stå med, som i Python.
        XCTAssertThrowsError(try Katalog.las(json: andrad("\"samre\": \"-\",", ""))) { e in
            XCTAssertTrue("\(e)".contains("samre"), "\(e)")
        }
        XCTAssertThrowsError(try Katalog.las(json: andrad("\"ovning\":", "\"ovn\":"))) { e in
            XCTAssertTrue("\(e)".contains("ovning"), "\(e)")
        }
        XCTAssertThrowsError(try Katalog.las(json: andrad("\"positioner\": [\"P4\"],", ""))) { e in
            XCTAssertTrue("\(e)".contains("positioner"), "\(e)")
        }
        XCTAssertThrowsError(try Katalog.las(json: andrad("\"matt\": [\n", "\"mått\": [\n"))) { e in
            XCTAssertTrue("\(e)".contains("matt"), "\(e)")
        }
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
