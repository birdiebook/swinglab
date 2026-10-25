import Foundation
import XCTest
@testable import Swing

/// Första intrycket (PLAN S4h, BESLUT B94, METOD M63): passet börjar med det viktiga, korten står
/// efter läget, de som inte kan säga bra eller dåligt ligger under "More measures", bandet har en
/// rad med bra-området och en nyckel, och axeln mot den egna baslinjen zoomar inte in på bruset.
final class ForstaIntrycketTests: XCTestCase {
    static let rot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    func katalog() throws -> Katalog {
        try Katalog.las(Data(contentsOf: Self.rot.appendingPathComponent("katalog.json")))
    }

    /// `n` svingar per vy med värdena ± 0,1.
    func pass(_ dag: Int, fo: [String: Double], dtl: [String: Double], klubba: String = "7i", n: Int = 9) -> Pass {
        func svingar(_ vy: Vy, _ m: [String: Double]) -> [SvingMatt] {
            (0..<n).map { i in SvingMatt(vy: vy, matt: m.mapValues { $0 + Double(i % 3 - 1) * 0.1 }) }
        }
        return Pass(datum: Tal.dag(2027, 1, dag), klubba: klubba, svingar: svingar(.fo, fo) + svingar(.dtl, dtl))
    }

    /// FO: swayen grön, resan gul, sway gap röd; armbågen mot den egna baslinjen utan avvikelse.
    let fo: [String: Double] = ["backen_sway_topp": -1.0, "tempo": 2.8, "backen_resa_framat": 9.0,
                                "sway_gap_traff": 3.0, "sidbojning_topp": 4.0, "framre_armbage_efter_traff": 20,
                                "framre_armbage_topp": 14]
    /// DTL: thrusten röd, händernas bana gul, tappet rött mot den egna baslinjen.
    let dtl: [String: Double] = ["backen_thrust_traff": 7.5, "handbana": 1.0, "tempo": 2.8,
                                 "brost_bojning_adress": 40, "brost_bojning_traff": 31, "brost_bojning_tapp": 9.0,
                                 "bakre_armbage_topp": 60]

    func visning(ovas: Set<String> = []) throws -> Passvisning {
        let tidigare = (0..<3).map { i -> Pass in
            var d = dtl
            d["brost_bojning_tapp"] = 2.0 + Double(i) * 0.3
            return pass(3 + i, fo: fo, dtl: d)
        }
        return Passvisning(katalog: try katalog(), pass: tidigare + [pass(9, fo: fo, dtl: dtl)], ovas: ovas)
    }

    func testKortenEfterLagetOchDetDoldaUnderFler() throws {
        let v = try visning()
        for vy in [Vy.fo, .dtl] {
            let l = v.lista(i: vy)
            // Rött, gult, grönt; inget utan läge bland de visade (inget övas).
            let grupper = l.kort.map { Lageordning.grupp($0.lage) }
            XCTAssertEqual(grupper, grupper.sorted(), "\(vy): \(l.kort.map(\.id))")
            XCTAssertFalse(l.kort.contains { $0.lage.lage == .ingen }, "\(vy)")
            // Inom gruppen i katalogens ordning.
            let alla = v.kort(i: vy)
            for g in 0...2 {
                let ids = l.kort.filter { Lageordning.grupp($0.lage) == g }.map(\.id)
                XCTAssertEqual(ids, alla.filter { Lageordning.grupp($0.lage) == g && Passlista.visas($0) }.map(\.id))
            }
            // Inget försvinner: de visade och de dolda är alla kort.
            XCTAssertEqual(Set(l.kort.map(\.id) + l.fler.map(\.id)), Set(alla.map(\.id)))
            XCTAssertEqual(l.kort.count + l.fler.count, alla.count)
            XCTAssertTrue(l.fler.allSatisfy { $0.lage.lage == .ingen || $0.varde == "—" || $0.markning == .oprovad })
            XCTAssertEqual(l.flerRad, l.fler.isEmpty ? nil : "More measures (\(l.fler.count))")
        }
        let f = v.lista(i: .fo), d = v.lista(i: .dtl)
        // Överst de röda måtten när inget övas.
        XCTAssertEqual(f.topp, .roda(f.kort.filter { $0.lage.lage == .rod }))
        XCTAssertEqual(f.topp?.kort.map(\.id), ["sway_gap"])
        XCTAssertEqual(f.kort.first?.id, "sway_gap")
        // "Your usual" som blir rött åt det sämre hållet visas, med rött läge; utan avvikelse döljs det.
        XCTAssertEqual(d.kort.prefix(2).map(\.id), ["early_extension", "tappad_hallning"])
        XCTAssertEqual(d.kort.first { $0.id == "tappad_hallning" }?.lage, Bandlage(.rod, pil: .over))
        XCTAssertTrue(f.fler.contains { $0.id == "chicken_wing" })
        XCTAssertFalse(f.kort.contains { $0.id == "chicken_wing" })
        XCTAssertTrue(d.topp?.rubrik == "Outside range")
        XCTAssertTrue(d.toppUpplasning?.hasPrefix("Outside range: Hips toward ball +7.5 cm, above range") ?? false,
                      d.toppUpplasning ?? "")
    }

    func testFocusOverstOchSynsAlltid() throws {
        let v = try visning(ovas: ["chicken_wing"])
        let f = v.lista(i: .fo)
        // Det som övas visas fast det inte har något läge, och står överst.
        XCTAssertEqual(f.topp, .focus(f.kort.filter(\.ovas)))
        XCTAssertEqual(f.topp?.kort.map(\.id), ["chicken_wing"])
        XCTAssertEqual(f.topp?.rubrik, "Focus")
        XCTAssertEqual(f.kort.last?.id, "chicken_wing")                 // utan läge sist
        XCTAssertFalse(f.fler.contains { $0.id == "chicken_wing" })
    }

    func testAlltGrontGerIngenTopp() {
        func kort(_ id: String, _ l: Bandlage) -> Mattkort {
            var k = Mattkort(id: id, matt: id, namn: id, rubrik: "", vy: .fo, markning: nil, varde: "1.0", enhet: "cm",
                             skillnad: nil, spann: nil, geometri: nil)
            k.lage = l
            return k
        }
        let l = Passlista([kort("a", Bandlage(.gul)), kort("b", Bandlage(.gron)), kort("c", .ingen)])
        XCTAssertNil(l.topp)
        XCTAssertEqual(l.kort.map(\.id), ["a", "b"])
        XCTAssertEqual(l.fler.map(\.id), ["c"])
        // Ett kort utan tal och ett oprövat döljs, också med ett läge.
        var tomt = Mattkort(id: "d", matt: "d", namn: "d", rubrik: "", vy: .fo, markning: nil, varde: "—", enhet: "cm",
                        skillnad: nil, spann: nil, geometri: nil)
        tomt.lage = Bandlage(.gron)
        var oprovad = Mattkort(id: "e", matt: "e", namn: "e", rubrik: "", vy: .fo, markning: .oprovad, varde: "7.0",
                               enhet: "m/s", skillnad: nil, spann: nil, geometri: nil)
        oprovad.lage = Bandlage(.rod, pil: .under)
        XCTAssertFalse(Passlista.visas(tomt))
        XCTAssertFalse(Passlista.visas(oprovad))
    }

    func testSorteringenArStabil() {
        let l: [Bandlage] = [.ingen, Bandlage(.gron), Bandlage(.rod, pil: .over), Bandlage(.gul), Bandlage(.rod, pil: .under),
                             Bandlage(.gron)]
        let ut = Lageordning.sortera(Array(l.enumerated())) { $0.element }.map { $0.offset }
        XCTAssertEqual(ut, [2, 4, 3, 1, 5, 0])
    }

    func testGranskningensRaderEfterLaget() throws {
        let k = try katalog()
        let p4 = Positionsmatt.rader(k, vy: .dtl, position: "P4",
                                     varden: ["brost_lyft_topp": -1.0, "huvud_mot_bollen_topp": -1.1,
                                              "skaft_riktning_topp": 14.0],
                                     baslinje: ["huvud_mot_bollen_topp": (0..<9).map { Double($0) * 0.2 - 1 }], klubba: "j7")
        XCTAssertEqual(Lageordning.sortera(p4).map(\.matt), ["skaft_riktning_topp", "brost_lyft_topp", "huvud_mot_bollen_topp"])
    }

    // MARK: bandet

    func testRadenUnderBandet() {
        let s = Spann(nu: -1.0, spridning: nil, forra: nil, gront: [-2.5, 0], baslinje: nil, decimaler: 1, enhet: "cm")
        XCTAssertEqual(s.omrade, "Good: \u{2212}2.5 to 0 cm")
        XCTAssertEqual(Spann(nu: 7, spridning: nil, forra: nil, gront: [6.9, nil], baslinje: nil, decimaler: 1, enhet: "cm").omrade,
                       "Good: \u{2265} 6.9 cm")
        XCTAssertEqual(Spann(nu: 7, spridning: nil, forra: nil, gront: [nil, 0], baslinje: nil, decimaler: 1, enhet: "cm").omrade,
                       "Good: \u{2264} 0 cm")
        XCTAssertEqual(Spann(nu: 2.8, spridning: nil, forra: nil, gront: [2.5, 3.1], baslinje: nil, decimaler: 2).omrade,
                       "Good: 2.5 to 3.1")
        XCTAssertEqual(Spann(nu: 9, spridning: nil, forra: nil, gront: nil, baslinje: (2.0, 2.6), decimaler: 1, enhet: "°").omrade,
                       "Your usual: 2.0 to 2.6°")
        XCTAssertNil(Spann(nu: 9, spridning: nil, forra: nil, gront: nil, baslinje: nil, decimaler: 1).omrade)
    }

    func testGolvetSatterAxelnsBreddMotDenEgnaBaslinjen() {
        // Ramen 19,9–20,1° och golvet 5°: axeln rymmer ramen ± golvet, inte ±0,3.
        let s = Spann(nu: 20.0, spridning: (19.95, 20.05), forra: 20.1, gront: nil, baslinje: (19.9, 20.1), decimaler: 1,
                      enhet: "°", golv: 5)
        XCTAssertLessThanOrEqual(s.axel.lo, 14.9)
        XCTAssertGreaterThanOrEqual(s.axel.hi, 25.1)
        // Utan golv som förut.
        let utan = Spann(nu: 20.0, spridning: (19.95, 20.05), forra: 20.1, gront: nil, baslinje: (19.9, 20.1), decimaler: 1)
        XCTAssertLessThan(utan.axel.hi - utan.axel.lo, 2)
        // Bandets axel ändras inte av golvet.
        let band = Spann(nu: -1, spridning: nil, forra: nil, gront: [-2.5, 0], baslinje: nil, decimaler: 1, golv: 2)
        let bandUtan = Spann(nu: -1, spridning: nil, forra: nil, gront: [-2.5, 0], baslinje: nil, decimaler: 1)
        XCTAssertEqual(band.axel, bandUtan.axel)
    }

    func testPassetsKortHarGolvetIAxeln() throws {
        let v = try visning()
        let tapp = try XCTUnwrap(v.kort.first { $0.id == "tappad_hallning" }?.spann)
        guard case let .baslinje(lo, hi)? = tapp.zon else { return XCTFail("ingen baslinje") }
        XCTAssertLessThanOrEqual(tapp.axel.lo, lo - 5 + 1e-9)
        XCTAssertGreaterThanOrEqual(tapp.axel.hi, hi + 5 - 1e-9)
    }

    func testNyckeln() {
        XCTAssertEqual(Bandnyckel.poster.map { $0.tecken }, Bandnyckel.Tecken.allCases)
        XCTAssertEqual(Bandnyckel.text(.nara), "Just outside: may be measurement error")
        XCTAssertEqual(Bandnyckel.text(.ute), "Outside, pointing toward the value")
        let svenska = CharacterSet(charactersIn: "åäöÅÄÖ")
        for p in Bandnyckel.poster {
            XCTAssertFalse(p.text.isEmpty)
            XCTAssertNil(p.text.rangeOfCharacter(from: svenska), p.text)
        }
        XCTAssertNil(Bandnyckel.rubrik.rangeOfCharacter(from: svenska))
    }

    func testPositionenMedNamnetForst() {
        XCTAssertEqual(Texter.positionMedNamn("P4"), "Top of backswing (P4)")
        XCTAssertEqual(Texter.positionMedNamn("P7"), "Impact (P7)")
        XCTAssertEqual(Texter.positionMedNamn("P11"), "P11")
    }
}
