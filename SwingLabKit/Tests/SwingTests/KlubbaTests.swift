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
        let pinne: [[Double]]?
        let markeringar: [M]
        let matt: [String: Double]
        let sd: [String: Double]
    }
    struct Forslag: Decodable {
        let position: String
        let positioner: [String: Double?]
        let tid: Double?
    }
    struct Skaft: Decodable {
        let position: String
        let x_tecken: Double
        let start: Double?
        let markeringar: [Fall.M]
        let tid: Double?
    }
    struct Yta: Decodable {
        let utsnitt: [Double]?
        let bredd: Int
        let hojd: Int
        let u: Double
        let v: Double
        let visad: [Int]
        let punkt: [Double]
    }
    let fall: [Fall]
    let fil: KlubbFil
    let forslag: [Forslag]
    let forslag_skaft: [Skaft]
    let yta: [Yta]
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
            let pinne = fall.pinne.map { $0.map { KlubbPunkt(x: $0[0], y: $0[1]) } }
            let swift = Klubba.matMedSD(marks, vy: sv.vy, xTecken: sv.xTecken, bredd: fall.bredd, hojd: fall.hojd,
                                        sving: sv, pinne: pinne)
            XCTAssertEqual(Set(swift.matt.keys), Set(fall.matt.keys), fall.sving)
            for (k, v) in fall.matt {
                XCTAssertEqual(swift.matt[k] ?? .nan, v, accuracy: 1e-6, "\(fall.sving) \(k)")
                XCTAssertEqual(swift.sd[k] ?? .nan, fall.sd[k] ?? .nan, accuracy: 1e-6, "\(fall.sving) sd \(k)")
            }
            // Utan svingen saknas bara armens mått (FO).
            let utan = Klubba.mat(marks, vy: sv.vy, xTecken: sv.xTecken, bredd: fall.bredd, hojd: fall.hojd, pinne: pinne)
            XCTAssertEqual(Set(utan.keys), Set(fall.matt.keys).subtracting(["skaft_arm_p5", "skaft_arm_p6"]))
        }
        XCTAssertNotNil(f.fall.first { $0.sving == "fo" }?.matt["skaft_arm_p5"], "armen prövas")
        XCTAssertNotNil(f.fall.first { $0.sving == "dtl" }?.matt["skaft_riktning_topp"], "toppen prövas")
    }

    func testForslagetForP2P6P8() throws {
        for c in try fixtur().forslag {
            let pos = c.positioner.compactMapValues { $0 }
            let t = Klubba.forslagTid(c.position, positioner: pos)
            if let v = c.tid { XCTAssertEqual(t ?? .nan, v, accuracy: 1e-12, c.position) } else { XCTAssertNil(t) }
        }
    }

    /// Framifrån: rutan där skaftets vinkel mellan positionerna före och efter går genom vågrätt
    /// (METOD M45, P2 från baksvingens start), samma tid som Python; ingen när vinkeln inte når
    /// dit eller går åt fel håll.
    func testForslagetUrSkaftetFramifran() throws {
        let fall = try fixtur().forslag_skaft
        XCTAssertEqual(fall.count, 9)
        XCTAssertEqual(fall.filter { $0.tid == nil }.count, 3, "kort baksving och fel håll två gånger")
        XCTAssertEqual(fall.filter { $0.x_tecken < 0 && $0.tid != nil }.count, 3, "vänsterspelarens P2, P6 och P8")
        for c in fall {
            let marks = c.markeringar.map { m in
                KlubbMarkering(position: m.position, t: m.t, grepp: m.grepp.map { KlubbPunkt(x: $0[0], y: $0[1]) },
                               hosel: m.hosel.map { KlubbPunkt(x: $0[0], y: $0[1]) },
                               hoppad: m.grepp == nil ? true : nil)
            }
            let t = Klubba.forslagTidSkaft(c.position, marks: marks, xTecken: c.x_tecken, start: c.start)
            if let v = c.tid { XCTAssertEqual(t ?? .nan, v, accuracy: 1e-9, c.position) } else { XCTAssertNil(t, c.position) }
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
        XCTAssertEqual(m[0].greppKalla, Klubba.kallaRing, "ringen ur handlederna, bekräftad")
        XCTAssertNil(m[1].greppKalla)
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
        let kort = KlubbMarkering(position: "P7", t: 0, grepp: g, hosel: KlubbPunkt(x: 500, y: 959))
        let hoppad = KlubbMarkering(position: "P1", t: -1, grepp: g, hosel: KlubbPunkt(x: 900, y: 1300), hoppad: true)
        XCTAssertTrue(Klubba.mat([kort, hoppad], vy: .dtl, xTecken: 1, bredd: 1080, hojd: 1920).isEmpty)
        let r = Klubba.matMedSD([KlubbMarkering(position: "P4", t: 0, grepp: g, hosel: KlubbPunkt(x: 500, y: 962))],
                                vy: .dtl, xTecken: 1, bredd: 1080, hojd: 1920)
        XCTAssertEqual(r.sd["skaft_vinkel_p4"] ?? .nan, 2.0.squareRoot() * 3 / 62 * 180 / .pi, accuracy: 1e-3)   // centrala differenser
        XCTAssertFalse(hoppad.markerad)
        XCTAssertEqual(Klubba.nyckel("skaft_vinkel", "P10"), "skaft_vinkel_p10")
        XCTAssertEqual(Klubba.namn(.dtl).count, 13)
        // Flyktpunkten ur riktpinnen, och antagen utan den.
        XCTAssertTrue(Klubba.flyktpunkt(nil, bredd: 1080, hojd: 1920).antagen)
        let f = Klubba.flyktpunkt([KlubbPunkt(x: 600, y: 1800), KlubbPunkt(x: 580, y: 1400)], bredd: 1080, hojd: 1920)
        XCTAssertFalse(f.antagen)
        XCTAssertEqual(f.punkt.x, 600 - 20.0 * 840 / 400, accuracy: 1e-9)
    }

    /// Katalogen visar skaftets vinkel vid varje position med positionens värde (METOD M46).
    func testGranskningensRadVidEnPosition() throws {
        let k = try Katalog.las(json: Fixturer.katalog)
        let rader = Positionsmatt.rader(k, vy: .dtl, position: "P2", varden: ["skaft_vinkel_p2": -35.04])
        XCTAssertEqual(rader.map(\.matt), ["skaft_vinkel_p2"])
        XCTAssertEqual(rader[0].namn, "Shaft angle")
        XCTAssertEqual(rader[0].varde, "−35.0")
        XCTAssertEqual(rader[0].enhet, "°")
        // Bakifrån utan riktpinne säger källraden att flyktpunkten är antagen (METOD M48).
        let topp = Positionsmatt.rader(k, vy: .dtl, position: "P4", varden: ["skaft_riktning_topp": 12],
                                       flyktpunktAntagen: true).first { $0.matt == "skaft_riktning_topp" }
        XCTAssertTrue(topp?.info?.kalla.hasSuffix(Texter.flyktpunktAntagen) == true)
    }
}
