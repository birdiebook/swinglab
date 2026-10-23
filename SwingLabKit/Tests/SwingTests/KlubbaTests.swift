import Foundation
import XCTest
@testable import Swing

// Klubbans mått ur markeringarna (PLAN S7a, METOD M45–M49): samma tal som Python på samma
// påhittade markeringar (KlubbFixturer.swift, BESLUT B12), och filen swinglab-klubba/2
// som PC:n skrev läst här.

private struct Fixtur: Decodable {
    struct Fall: Decodable {
        struct M: Decodable {
            let position: String
            let t: Double
            let grepp: [Double]?
            let hosel: [Double]?
        }
        let sving: String
        let bredd: Int
        let hojd: Int
        let markeringar: [M]
        let matt: [String: Double]
        let osakerhet: [String: Double]
    }
    struct Forslag: Decodable {
        let position: String
        let positioner: [String: Double?]
        let start: Double?
        let tid: Double?
    }
    let fall: [Fall]
    let fil: KlubbFil
    let forslag: [Forslag]
}

final class KlubbaTests: XCTestCase {
    private func fixtur() throws -> Fixtur {
        try JSONDecoder().decode(Fixtur.self, from: Data(KlubbFixturer.json.utf8))
    }

    private func sving(_ namn: String) throws -> Sving {
        let indata = try XCTUnwrap(Fixturer.svingar.first { $0.namn == namn }?.indata, namn)
        return try Sving.las(json: indata)
    }

    /// Samma tal som Python inom 1e-6 (BESLUT B12), och samma mått saknas.
    func testSammaTalSomPython() throws {
        let f = try fixtur()
        XCTAssertEqual(f.fall.count, 4)
        for fall in f.fall {
            let sv = try sving(fall.sving)
            let marks = fall.markeringar.map { m in
                KlubbMarkering(position: m.position, t: m.t, grepp: m.grepp.map { KlubbPunkt(x: $0[0], y: $0[1]) },
                               hosel: m.hosel.map { KlubbPunkt(x: $0[0], y: $0[1]) },
                               hoppad: m.grepp == nil ? true : nil)
            }
            let swift = Klubba.mat(marks, vy: sv.vy, xTecken: sv.xTecken, bredd: fall.bredd, hojd: fall.hojd, sving: sv)
            XCTAssertEqual(Set(swift.keys), Set(fall.matt.keys), fall.sving)
            for (k, v) in fall.matt {
                XCTAssertEqual(swift[k] ?? .nan, v, accuracy: 1e-6, "\(fall.sving) \(k)")
            }
            for (l, v) in fall.osakerhet {
                XCTAssertEqual(Klubba.osakerhet(Double(l)!), v, accuracy: 1e-9)
            }
            // Utan svingen saknas bara armens mått (FO).
            let utan = Klubba.mat(marks, vy: sv.vy, xTecken: sv.xTecken, bredd: fall.bredd, hojd: fall.hojd)
            XCTAssertEqual(Set(utan.keys), Set(fall.matt.keys).subtracting(["skaft_arm_p5", "skaft_arm_p6"]))
        }
        XCTAssertNotNil(f.fall.first { $0.sving == "fo" }?.matt["skaft_arm_p5"], "armen prövas")
        XCTAssertNotNil(f.fall.first { $0.sving == "dtl" }?.matt["skaft_riktning_topp"], "toppen prövas")
    }

    func testForslagetForP2P6P8() throws {
        for c in try fixtur().forslag {
            let pos = c.positioner.compactMapValues { $0 }
            let t = Klubba.forslagTid(c.position, positioner: pos, start: c.start)
            if let v = c.tid { XCTAssertEqual(t ?? .nan, v, accuracy: 1e-12, c.position) } else { XCTAssertNil(t) }
        }
    }

    /// Filen som Python skrev (version 2, telefonens form) läses, markeringarna kommer ut per
    /// slag, och Swift skriver tillbaka samma JSON.
    func testFilenAtBadaHall() throws {
        let f = try fixtur()
        let data = try JSONEncoder().encode(f.fil)
        let las = try KlubbFil.las(data)
        XCTAssertEqual(las, f.fil)
        let m = try XCTUnwrap(las.markeringar()["s03"])
        XCTAssertEqual(m.map(\.position), Klubba.positioner)
        // Samma JSON (som objekt) som Python skrev.
        let python = try JSONSerialization.jsonObject(with: Data(KlubbFixturer.json.utf8)) as? [String: Any]
        let pyFil = try XCTUnwrap(python?["fil"] as? NSDictionary)
        let swiftFil = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? NSDictionary)
        XCTAssertEqual(swiftFil, pyFil)
        // En ruta byggd ur markeringen blir samma rad som Pythons.
        let r0 = KlubbFil.ruta(m[0], vy: .dtl, slag: "s03", fil: f.fil.rutor[0].fil, bredd: f.fil.rutor[0].bredd,
                               hojd: f.fil.rutor[0].hojd, visad: f.fil.rutor[0].visad, tKlipp: nil)
        XCTAssertEqual(r0, f.fil.rutor[0])
        // Version 1 uppgraderas; fel format eller punkter fälls utan värden.
        var v1 = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        v1["format"] = KlubbFil.format1
        XCTAssertEqual(try KlubbFil.las(JSONSerialization.data(withJSONObject: v1)).format, KlubbFil.format)
        v1["format"] = "swinglab-klubba/9"
        XCTAssertThrowsError(try KlubbFil.las(JSONSerialization.data(withJSONObject: v1)))
    }

    func testSparrenOchHoppade() {
        let g = KlubbPunkt(x: 500, y: 900)
        let kort = KlubbMarkering(position: "P7", t: 0, grepp: g, hosel: KlubbPunkt(x: 500, y: 900 + Klubba.minSkaftPx - 1))
        let hoppad = KlubbMarkering(position: "P1", t: -1, grepp: g, hosel: KlubbPunkt(x: 900, y: 1300), hoppad: true)
        XCTAssertTrue(Klubba.mat([kort, hoppad], vy: .dtl, xTecken: 1, bredd: 1080, hojd: 1920).isEmpty)
        XCTAssertFalse(hoppad.markerad)
        XCTAssertEqual(Klubba.nyckel("skaft_vinkel", "P10"), "skaft_vinkel_p10")
        XCTAssertEqual(Klubba.namn(.dtl).count, 14)
    }

    /// Katalogen visar skaftets vinkel vid varje position med positionens värde (METOD M46).
    func testGranskningensRadVidEnPosition() throws {
        let k = try Katalog.las(json: Fixturer.katalog)
        let rader = Positionsmatt.rader(k, vy: .dtl, position: "P2", varden: ["skaft_vinkel_p2": -35.04,
                                                                               "skaft_mot_plan_p2": -25.0])
        XCTAssertEqual(rader.map(\.matt), ["skaft_vinkel_p2", "skaft_mot_plan_p2"])
        XCTAssertEqual(rader[0].namn, "Shaft angle")
        XCTAssertEqual(rader[0].varde, "−35.0")
        XCTAssertEqual(rader[0].enhet, "°")
    }
}
