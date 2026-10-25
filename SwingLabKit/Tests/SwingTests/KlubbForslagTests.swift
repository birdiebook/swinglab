import Foundation
import XCTest
@testable import Swing

// S7d: modellens förslag (BESLUT B93, METOD MF8). Samma kontroll, samma fel och samma
// matchning som tools/pc/klubba_forslag.py på den påhittade filen och dess trasiga varianter
// (KlubbForslagFixturer.swift, BESLUT B12), och källan godkand_forslag i swinglab-klubba.

private struct Fixtur: Decodable {
    struct Matcha: Decodable {
        let slag: String
        let tider: [String: Double?]
        let index: [String: Int?]
    }
    struct Visad: Decodable, Equatable {
        let x: Double
        let y: Double
        let box: [Double]?
    }
    struct Variant: Decodable {
        let namn: String
        let json: String
        let fel: [String]
    }
    let fil: String
    let matcha: Matcha
    let fel_storlek: Int
    let visade: [[String: Visad]]
    let varianter: [Variant]
}

final class KlubbForslagTests: XCTestCase {
    private func fixtur() throws -> Fixtur {
        try JSONDecoder().decode(Fixtur.self, from: Data(KlubbForslagFixturer.json.utf8))
    }

    func testDenPahittadeFilenLases() throws {
        let f = try fixtur()
        XCTAssertEqual(KlubbForslagFil.kontrollera(try JSONVarde.las(f.fil)), [])
        let fil = try KlubbForslagFil.las(Data(f.fil.utf8))
        XCTAssertEqual(fil.pass, "20261024-171500")
        XCTAssertEqual(fil.vy, .dtl)
        XCTAssertEqual(fil.modell, "klubba-golf49 0.1.0")
        XCTAssertEqual(fil.data.first?.licens, "CC BY 4.0")
        XCTAssertEqual(fil.slag.map(\.id), ["s01", "s03"])
        XCTAssertEqual(fil.filnamn, "20261024-171500-dtl.json")
        XCTAssertNil(KlubbForslagFil.filnamn(pass: "../x", vy: .dtl))
    }

    /// Samma fel i samma ordning som Python för varje trasig variant, och felet nämner fältet,
    /// aldrig värdet.
    func testSammaFelSomPython() throws {
        let f = try fixtur()
        XCTAssertGreaterThanOrEqual(f.varianter.count, 20)
        for v in f.varianter {
            XCTAssertEqual(KlubbForslagFil.kontrollera(try JSONVarde.las(v.json)), v.fel, v.namn)
            XCTAssertThrowsError(try KlubbForslagFil.las(Data(v.json.utf8)), v.namn) { e in
                let text = (e as? FormatFel)?.beskrivning ?? ""
                XCTAssertTrue(text.hasPrefix("suggestions: \(v.fel[0])"), "\(v.namn): \(text)")
                for varde in ["../x", "sidan", "1081", "1.5", "1080.5"] { XCTAssertFalse(text.contains(varde), v.namn) }
            }
        }
        XCTAssertThrowsError(try KlubbForslagFil.las(Data("{".utf8))) { e in
            XCTAssertEqual((e as? FormatFel)?.beskrivning, "suggestions: not valid JSON")
        }
    }

    /// Ruta → position: samma index som Python, ingen ruta längre bort än 2 ms, inga förslag för
    /// en bild av en annan storlek, och samma punkter visade (konfidensen).
    func testMatchningenOchDetSomVisas() throws {
        let f = try fixtur()
        let fil = try KlubbForslagFil.las(Data(f.fil.utf8))
        let rutor = fil.rutor(slag: f.matcha.slag, bredd: 1080, hojd: 1920)
        let index = KlubbForslagFil.matcha(rutor, tider: f.matcha.tider)
        XCTAssertEqual(index.count, f.matcha.index.count)
        for (p, i) in f.matcha.index { XCTAssertEqual(index[p] ?? nil, i, p) }
        XCTAssertEqual(fil.rutor(slag: "s01", bredd: 1920, hojd: 1080).count, f.fel_storlek)
        XCTAssertNil(KlubbForslagFil.ruta(rutor, t: -0.3125 - 0.0021))
        XCTAssertEqual(rutor.count, f.visade.count)
        for (r, py) in zip(rutor, f.visade) {
            let v = r.visat(modell: fil.modell)
            func jfr(_ p: KlubbPunkt?, _ q: Fixtur.Visad?, _ namn: String) {
                XCTAssertEqual(p.map { [$0.x, $0.y] }, q.map { [$0.x, $0.y] }, namn)
            }
            jfr(v.grepp, py["grepp"], "grepp")
            jfr(v.hosel, py["hosel"], "hosel")
            jfr(v.huvud, py["huvud"], "huvud")
            XCTAssertEqual(v.huvudBox, py["huvud"]?.box)
        }
    }

    /// Källan i swinglab-klubba (S7d): godkända punkter och förslaget som visades läses ur
    /// Pythons fil och skrivs tillbaka till samma rad.
    func testGodkantOchRattatForslagIFilen() throws {
        let py = try JSONSerialization.jsonObject(with: Data(KlubbFixturer.json.utf8)) as? [String: Any]
        let filData = try JSONSerialization.data(withJSONObject: try XCTUnwrap(py?["fil"]))
        let fil = try KlubbFil.las(filData)
        let m = try XCTUnwrap(fil.markeringar()["s03"])
        XCTAssertEqual(m[1].greppKalla, Klubba.kallaForslag)
        XCTAssertEqual(m[1].hoselKalla, Klubba.kallaForslag)
        XCTAssertEqual(m[1].forslag?.grepp, m[1].grepp)
        XCTAssertEqual(m[1].forslag?.modell, "klubba-golf49 0.1.0")
        XCTAssertNil(m[2].hoselKalla, "rättad: ett tryck")
        XCTAssertNotNil(m[2].forslag?.hosel)
        XCTAssertNotEqual(m[2].forslag?.hosel, m[2].hosel)
        XCTAssertNil(m[3].forslag)
        for i in 0..<4 {
            let r = fil.rutor[i]
            XCTAssertEqual(KlubbFil.ruta(m[i], vy: .dtl, slag: "s03", fil: r.fil, bredd: r.bredd, hojd: r.hojd,
                                         visad: r.visad, tKlipp: nil), r, "rutor[\(i)]")
        }
        XCTAssertEqual(Klubba.kallor, ["klick", "handlederna_bekraftad", "godkand_forslag"])
    }
}
