import Foundation
import XCTest
@testable import Swing

/// Läget mot bandet (METOD M62, BESLUT B86–B88): Python är facit (BESLUT B12).
/// tools/tests/fixturer/bandlage.json skrivs av `python3 tools/pc/katalog.py --swift`: läget för
/// påhittade värden, för varje post i katalogen med järn och driver, järnen, vad sessionen visar
/// per vy och felens källa med och utan klubban.
final class BandlageTests: XCTestCase {
    static let rot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    func facit() throws -> JSONVarde {
        let url = Self.rot.appendingPathComponent("tools/tests/fixturer/bandlage.json")
        return try JSONVarde.las(try String(contentsOf: url, encoding: .utf8))
    }

    func katalog() throws -> Katalog {
        try Katalog.las(Data(contentsOf: Self.rot.appendingPathComponent("katalog.json")))
    }

    /// [min, max] med null i en ände, eller nil.
    func spann(_ x: JSONVarde?) -> [Double?]? {
        x?.somLista.map { $0.map(\.somTal) }
    }

    func ut(_ x: JSONVarde?) -> Bandlage {
        let lage = Bandlage.Lage(rawValue: x?["lage"]?.somText ?? "") ?? .ingen
        return Bandlage(lage, pil: x?["pil"]?.somText.flatMap(Bandlage.Riktning.init(rawValue:)))
    }

    func tal(_ x: JSONVarde?) throws -> Double { try XCTUnwrap(x?.somTal) }
    func lista(_ x: JSONVarde?) throws -> [JSONVarde] { try XCTUnwrap(x?.somLista) }
    func bool(_ x: JSONVarde?) -> Bool? { if case let .bool(b)? = x { return b } else { return nil } }

    func testLagetMotBandetSomPython() throws {
        let f = try facit()
        let lagen = try lista(f["lage"])
        XCTAssertGreaterThan(lagen.count, 40)
        for p in lagen {
            let v = try tal(p["varde"]), golv = try tal(p["golv"])
            XCTAssertEqual(Bandlage.lage(v, gront: spann(p["gront"]), golv: golv), ut(p["ut"]), "\(p)")
        }
        for p in try lista(f["baslinje"]) {
            let v = try tal(p["varde"])
            let b = try lista(p["baslinje"]).compactMap(\.somTal)
            XCTAssertEqual(Bandlage.lage(v, baslinje: Baslinje.spann(b), samre: p["samre"]?.somText,
                                         golv: p["golv"]?.somTal), ut(p["ut"]), "\(p)")
        }
    }

    func testVarjePostIKatalogenSomPython() throws {
        let f = try facit(), k = try katalog()
        let poster = try lista(f["poster"])
        XCTAssertGreaterThan(poster.count, 300)
        var sedda = Set<Bandlage.Lage>()
        for p in poster {
            let namn = p["namn"]?.somText, vy = p["vy"]?.somText
            let v = try tal(p["varde"]), kl = p["klubba"]?.somText
            let b = try lista(p["baslinje"]).compactMap(\.somTal)
            let svar: Bandlage
            switch p["lista"]?.somText ?? "" {
            case "fel":
                svar = Bandlage.lage(try XCTUnwrap(k.fel.first { $0.id == namn }), v, baslinje: b, klubba: kl)
            case "matt":
                svar = Bandlage.lage(try XCTUnwrap(k.matt.first { $0.matt == namn && $0.vy == vy }), v, baslinje: b,
                                     klubba: kl)
            default:
                svar = Bandlage.lage(try XCTUnwrap(k.spridning.first { $0.matt == namn && $0.vy == vy }), v,
                                     baslinje: b, klubba: kl)
            }
            XCTAssertEqual(svar, ut(p["ut"]), "\(p)")
            sedda.insert(svar.lage)
        }
        XCTAssertEqual(sedda, [.gron, .gul, .rod, .ingen])
    }

    func testJarnenSomPython() throws {
        let f = try facit()
        let jarnen = try lista(f["jarn"])
        XCTAssertGreaterThan(jarnen.count, 10)
        for p in jarnen {
            XCTAssertEqual(Bandlage.jarn(p["klubba"]?.somText), bool(p["jarn"]), "\(p)")
        }
    }

    /// Dom (b) visas inte i sessionen, dom (c) finns inte (BESLUT B86), som Python.
    func testVadSessionenVisarSomPython() throws {
        let f = try facit(), k = try katalog()
        XCTAssertEqual(k.visade(i: .dtl), try lista(f["visade"]?["dtl"]).compactMap(\.somText))
        XCTAssertEqual(k.visade(i: .fo), try lista(f["visade"]?["fo"]).compactMap(\.somText))
        XCTAssertFalse(k.visade(i: .dtl).contains("hand_lyft_topp"))
        XCTAssertFalse(k.visade(i: .fo).contains("sidbojning_finish"))
    }

    /// Over the top med och utan klubban (BESLUT B88), som `kalla_for`.
    func testFeletsKallaSomPython() throws {
        let f = try facit(), k = try katalog()
        let kallor = try XCTUnwrap(f["kallor"]?.somObjekt?.par)
        XCTAssertEqual(kallor.count, 2)
        for (nyckel, p) in kallor {
            let delar = nyckel.split(separator: "/").map(String.init)
            let fel = try XCTUnwrap(k.fel.first { $0.id == delar[0] }).medKalla(klubbaMarkerad: delar[1] == "klubba")
            XCTAssertEqual(fel.matt, p["matt"]?.somText, nyckel)
            XCTAssertEqual(fel.positioner, try lista(p["positioner"]).compactMap(\.somText), nyckel)
            XCTAssertEqual(fel.gront, spann(p["gront"]), nyckel)
            XCTAssertEqual(fel.golv, p["golv"]?.somTal, nyckel)
            XCTAssertEqual(fel.kalla, p["kalla"]?.somText, nyckel)
            XCTAssertEqual(fel.status, p["status"]?.somText, nyckel)
            XCTAssertEqual(fel.kontrollerad, bool(p["kontrollerad"]), nyckel)
            XCTAssertEqual(fel.gransHarledd, bool(p["grans_harledd"]), nyckel)
            XCTAssertEqual(fel.vad, p["vad"]?.somText, nyckel)
            XCTAssertEqual(fel.tecken, p["tecken"]?.somText, nyckel)
        }
    }

    /// Passet: järnets band på järnpass, inget band på driver, och over the top på klubbans plan
    /// när klubban är markerad (BESLUT B86, B88).
    func testPassetMedLaget() throws {
        let k = try katalog()
        func pass(_ klubba: String, _ fo: [String: Double], _ dtl: [String: Double]) -> Pass {
            Pass(datum: Tal.dag(2027, 1, 12), klubba: klubba,
                 svingar: (0..<5).map { _ in SvingMatt(vy: .fo, matt: fo) } + (0..<5).map { _ in SvingMatt(vy: .dtl, matt: dtl) })
        }
        let jarn = pass("7i", ["backen_sway_topp": -3.0, "sway_gap_traff": 2.0, "tempo": 2.8],
                        ["backen_thrust_traff": 1.0, "handbana": 1.5, "tempo": 2.8])
        let v = Passvisning(katalog: k, pass: [jarn])
        func kort(_ id: String) throws -> Mattkort { try XCTUnwrap(v.kort.first { $0.id == id }, id) }
        XCTAssertEqual(try kort("sway_topp").lage, Bandlage(.gul))
        XCTAssertEqual(try kort("sway_gap").lage, Bandlage(.rod, pil: .under))
        XCTAssertEqual(try kort("early_extension").lage, Bandlage(.gron))
        XCTAssertEqual(try kort("over_the_top").lage, Bandlage(.gul))
        XCTAssertEqual(try kort("over_the_top").matt, "handbana")
        let gap = try kort("sway_gap").upplasning
        XCTAssertTrue(gap.contains("below range"), gap)
        XCTAssertFalse(v.kort.contains { $0.id == "flying_elbow" || $0.id == "axellutning" })     // dom (b)
        // Ett fel som övas syns ändå.
        XCTAssertTrue(Passvisning(katalog: k, pass: [jarn], ovas: ["flying_elbow"]).kort.contains { $0.id == "flying_elbow" })
        // Driver: inget band, inget läge utan baslinje.
        let dr = Passvisning(katalog: k, pass: [pass("Dr", ["backen_sway_topp": -3.0], ["handbana": 1.5])])
        XCTAssertEqual(dr.kort.first { $0.id == "sway_topp" }?.lage, .ingen)
        XCTAssertEqual(dr.kort.first { $0.id == "sway_topp" }?.markning, .egen)
        // Klubban markerad: over the top på skaft_plan_p6 och inget eget kort för planet.
        let klubba = pass("7i", [:], ["handbana": 1.5, "skaft_plan_p6": 12.0])
        let kv = Passvisning(katalog: k, pass: [klubba])
        let ott = try XCTUnwrap(kv.kort.first { $0.id == "over_the_top" })
        XCTAssertEqual(ott.matt, "skaft_plan_p6")
        XCTAssertEqual(ott.lage, Bandlage(.rod, pil: .over))
        XCTAssertEqual(ott.markning, .b10)
        XCTAssertFalse(kv.kort.contains { $0.id == "skaft_plan_p6_dtl" })
    }

    /// Granskningen: (b)-måtten syns inte, läget står på raden, och klubbans plan ersätter
    /// händernas bana på ett markerat slag (BESLUT B86–B88).
    func testGranskningensRader() throws {
        let k = try katalog()
        let p4 = Positionsmatt.rader(k, vy: .dtl, position: "P4",
                                     varden: ["hand_djup_topp": -20, "hand_lyft_topp": 3, "brost_lyft_topp": -6.5])
        XCTAssertFalse(p4.contains { $0.matt == "hand_djup_topp" || $0.matt == "hand_lyft_topp" })
        XCTAssertEqual(p4.first { $0.matt == "brost_lyft_topp" }?.lage, Bandlage(.rod, pil: .under))
        let p5 = Positionsmatt.rader(k, vy: .dtl, position: "P5", varden: ["handbana": 3.0])
        XCTAssertEqual(p5.first { $0.matt == "handbana" }?.lage, Bandlage(.rod, pil: .over))
        let markerat = ["handbana": 3.0, "skaft_plan_p6": -2.0]
        XCTAssertFalse(Positionsmatt.rader(k, vy: .dtl, position: "P5", varden: markerat).contains { $0.matt == "handbana" })
        let p6 = Positionsmatt.rader(k, vy: .dtl, position: "P6", varden: markerat)
        XCTAssertEqual(p6.filter { $0.matt == "skaft_plan_p6" }.count, 1)
        XCTAssertEqual(p6.first { $0.matt == "skaft_plan_p6" }?.lage, Bandlage(.gron))
        // Driver: inget band på bröstets lyft.
        let dr = Positionsmatt.rader(k, vy: .dtl, position: "P4", varden: ["brost_lyft_topp": -6.5], klubba: "dr")
        XCTAssertEqual(dr.first { $0.matt == "brost_lyft_topp" }?.lage, .ingen)
    }
}
