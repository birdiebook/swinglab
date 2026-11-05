import Foundation
import XCTest
@testable import Swing

/// Varför ett mått saknas (PLAN S3b lager 1, BESLUT B109, METOD MS21, MS22): mätningens kod blir
/// enkel engelska, granskningens rad säger "Not measured" med orsaken först i infobladet, och
/// passets kort säger hur många svingar som har talet, med orsakerna och antalen i bladet. Ett slag
/// mätt före version 6 har ingen kod och får bara att det saknas. Påhittade svingar (dataregeln).
final class SaknasTests: XCTestCase {
    static let rot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    func katalog() throws -> Katalog {
        try Katalog.las(Data(contentsOf: Self.rot.appendingPathComponent("katalog.json")))
    }

    /// Ett FO-pass med åtta svingar, som simulatorprovet (Prov/SwingLabProvSaknas.swift): tempot i
    /// fem (två där klippet börjar sent), främre armbågen vid toppen i sex (en med armen mot
    /// kameran) och chicken wing i ingen (fem med en punkt fel, två utan punkt). Sving 8 mättes före
    /// version 6: den saknar samma mått, utan koder.
    func foPass(medOrsaker: Bool = true) -> Pass {
        var svingar: [SvingMatt] = []
        var koder: [[String: String]] = []
        for i in 0..<8 {
            var m: [String: Double] = ["backen_sway_topp": -1.0 + Double(i % 3 - 1) * 0.1, "sidbojning_topp": 4.0,
                                       "backen_resa_framat": 9.0, "sway_gap_traff": 3.0, "nedsving_s": 0.28]
            var k: [String: String] = [:]
            if i < 5 { m["tempo"] = 2.8; m["baksving_s"] = 0.84 }
            if i < 6 { m["framre_armbage_topp"] = 14 }
            if i < 7 {
                if i >= 5 { k["tempo"] = "start_osaker"; k["baksving_s"] = "start_osaker" }
                if i == 6 { k["framre_armbage_topp"] = "segment_kort" }
                k["framre_armbage_efter_traff"] = i < 5 ? "segment_langt" : "led_saknas"
            }
            svingar.append(SvingMatt(vy: .fo, matt: m))
            koder.append(k)
        }
        return Pass(datum: Tal.dag(2027, 1, 9), klubba: "7i", svingar: svingar, saknas: medOrsaker ? koder : nil)
    }

    /// Ett DTL-pass med sex svingar utan tempo: fyra med osäker start, två utan start.
    func dtlPass() -> Pass {
        let svingar = (0..<6).map { i in
            SvingMatt(vy: .dtl, matt: ["backen_thrust_traff": 1.0 + Double(i) * 0.1, "handbana": -1.0, "nedsving_s": 0.28])
        }
        let koder = (0..<6).map { i -> [String: String] in
            let o = i < 4 ? "start_osaker" : "start_saknas"
            return ["tempo": o, "baksving_s": o]
        }
        return Pass(datum: Tal.dag(2027, 1, 10), klubba: "7i", svingar: svingar, osakerStart: 4, saknas: koder)
    }

    // MARK: orsakerna i ord

    func testOrsakernaIKlartext() {
        XCTAssertEqual(Saknas.orsak("segment_kort", matt: "framre_armbage_topp", vy: .fo),
                       "the lead arm pointed toward or away from the camera")
        XCTAssertEqual(Saknas.orsak("segment_langt", matt: "framre_armbage_efter_traff", vy: .fo),
                       "a point on the lead arm looked wrong")
        XCTAssertEqual(Saknas.orsak("led_saknas", matt: "framre_armbage_p3", vy: .fo), "a point on the lead arm was not found")
        // Knäna bakifrån (METOD M11, M33): benet, främre och bakre.
        XCTAssertEqual(Saknas.orsak("segment_kort", matt: "bakre_kna_topp", vy: .dtl),
                       "the trail leg pointed toward or away from the camera")
        XCTAssertEqual(Saknas.orsak("led_saknas", matt: "framre_kna_adress", vy: .dtl), "a point on the lead leg was not found")
        // Ett mått som inte är en ledvinkel: den allmänna texten.
        XCTAssertEqual(Saknas.orsak("segment_langt", matt: "nytt_matt", vy: .fo), "a tracked point looked wrong")
        XCTAssertEqual(Saknas.orsak("segment_kort", matt: "nytt_matt", vy: .fo),
                       "an arm or leg pointed toward or away from the camera")
        XCTAssertEqual(Saknas.orsak("led_saknas", matt: "nytt_matt", vy: .dtl), "a tracked point was not found")
        // Starten: framifrån började klippet för sent (METOD M4), bakifrån är den osäker (M40).
        XCTAssertEqual(Saknas.orsak("start_osaker", matt: "tempo", vy: .fo), "the clip starts after the takeaway began")
        XCTAssertEqual(Saknas.orsak("start_osaker", matt: "tempo", vy: .dtl), "the backswing start was unclear from behind")
        XCTAssertEqual(Saknas.orsak("start_saknas", matt: "baksving_s", vy: .fo), "the backswing start was not found")
        XCTAssertEqual(Saknas.orsak("start_saknas", matt: "tempo", vy: .dtl), "the backswing start was not found")
        // Ingen kod (mätt före version 6): ingen orsak. En okänd kod: en allmän text, aldrig koden.
        XCTAssertNil(Saknas.orsak(nil, matt: "tempo", vy: .fo))
        XCTAssertEqual(Saknas.orsak("ny_kod", matt: "tempo", vy: .fo), "the measurement looked unreliable")
    }

    /// Varje kod har en egen text i båda vyerna, utan kod, understreck eller svenska (BESLUT B30, B94).
    func testIngaKoderEllerSvenskaITexterna() {
        let svenska = CharacterSet(charactersIn: "åäöÅÄÖ")
        var texter: [String] = [Texter.ingenOrsak, Texter.ejMattISlagetUtanOrsak, Texter.mattI(5, av: 8),
                                Texter.ejMattIAlla(8), Texter.ejMattIAlla(1)]
        for o in Saknas.Orsak.allCases {
            for matt in ["framre_armbage_topp", "bakre_kna_traff", "framre_kna_topp", "tempo", "nytt_matt"] {
                for vy in [Vy.fo, .dtl] {
                    let t = try? XCTUnwrap(Saknas.orsak(o.rawValue, matt: matt, vy: vy))
                    XCTAssertNotEqual(t, Texter.orsakOkand, "\(o) har ingen egen text")
                    texter += [t ?? "", Saknas.slag(o.rawValue, matt: matt, vy: vy)]
                }
            }
        }
        for t in texter {
            XCTAssertFalse(t.isEmpty)
            XCTAssertFalse(t.contains("_"), t)
            XCTAssertNil(t.rangeOfCharacter(from: svenska), t)
        }
        XCTAssertEqual(Texter.ejMattIAlla(1), "Not measured in the swing")
    }

    // MARK: slaget i granskningen (METOD MS21)

    func testRadenISlagetSagerAttDetSaknas() throws {
        let k = try katalog()
        let varden: [String: Double] = ["backen_sway_topp": -1.0, "sidbojning_topp": 4.0, "brost_lyft_topp": -1.0,
                                        "hoftlinje_lutning_topp": -8.0]
        let rader = Lageordning.sortera(Positionsmatt.rader(k, vy: .fo, position: "P4", varden: varden,
                                                            klubba: "j7", saknas: ["framre_armbage_topp": "segment_kort"]))
        let arm = try XCTUnwrap(rader.first { $0.matt == "framre_armbage_topp" })
        XCTAssertTrue(arm.ejMatt)
        XCTAssertEqual(arm.varde, "—")
        XCTAssertNil(arm.spann)
        XCTAssertEqual(arm.lage, .ingen)
        XCTAssertEqual(arm.orsak, "the lead arm pointed toward or away from the camera")
        XCTAssertEqual(arm.info?.saknas,
                       ["Not measured in this swing: the lead arm pointed toward or away from the camera."])
        XCTAssertEqual(arm.info?.namn, "Lead elbow bend")
        XCTAssertTrue(arm.upplasning.hasPrefix("Lead elbow bend, not measured, the lead arm pointed toward or away"),
                      arm.upplasning)
        XCTAssertTrue(arm.info?.upplasning.hasPrefix("Lead elbow bend. Not measured in this swing: the lead arm") ?? false)
        // Sist bland raderna (inget läge, METOD M63); de mätta som förut.
        XCTAssertEqual(rader.last?.matt, "framre_armbage_topp")
        for r in rader where r.matt != "framre_armbage_topp" {
            XCTAssertFalse(r.ejMatt, r.matt)
            XCTAssertNil(r.orsak)
            XCTAssertEqual(r.info?.saknas, [], r.matt)
            XCTAssertNotEqual(r.varde, "—", r.matt)
        }
    }

    /// Ett slag mätt före version 6 (ingen kod): "Not measured" utan orsak.
    func testSlagUtanKodSagerBaraAttDetSaknas() throws {
        let k = try katalog()
        for saknas in [nil, [:]] as [[String: String]?] {
            let rader = Positionsmatt.rader(k, vy: .fo, position: "P9", varden: [:], saknas: saknas)
            let r = try XCTUnwrap(rader.first { $0.matt == "framre_armbage_efter_traff" })
            XCTAssertTrue(r.ejMatt)
            XCTAssertNil(r.orsak)
            XCTAssertEqual(r.info?.saknas, ["Not measured in this swing."])
            XCTAssertTrue(r.upplasning.hasPrefix("Lead arm fold, not measured, after impact"), r.upplasning)
        }
        // Bakifrån: knäets orsak följer inte med till en annan rad, och ett avstängt mått märks inte.
        let p4 = Positionsmatt.rader(k, vy: .dtl, position: "P4", varden: ["brost_lyft_topp": -1.0],
                                     saknas: ["framre_kna_topp": "segment_kort"])
        XCTAssertFalse(p4.contains { $0.matt == "framre_kna_topp" })              // dom (b), BESLUT B86
        XCTAssertEqual(p4.first { $0.matt == "brost_lyft_topp" }?.ejMatt, false)
        let av = Positionsmatt.rader(k, vy: .fo, position: "P7", varden: [:], ovas: ["axellutning"])
        let axel = try XCTUnwrap(av.first { $0.matt == "axellinje_lutning_traff" })
        XCTAssertFalse(axel.ejMatt)                                                 // avstängt: "—" som förut
        XCTAssertEqual(axel.varde, "—")
    }

    // MARK: passets kort (METOD MS22)

    func testRakningen() throws {
        let p = foPass()
        let tempo = try XCTUnwrap(Saknas.pass(p, matt: "tempo", grupp: "alla"))
        XCTAssertEqual(tempo.matt, 5)
        XCTAssertEqual(tempo.av, 8)
        XCTAssertEqual(tempo.utanOrsak, 1)
        XCTAssertEqual(tempo.rad, "Measured in 5 of 8 swings")
        XCTAssertEqual(tempo.blad, ["Measured in 5 of 8 swings.", "2 swings: the clip starts after the takeaway began.",
                                    "1 swing: no reason recorded."])
        let cw = try XCTUnwrap(Saknas.pass(p, matt: "framre_armbage_efter_traff", grupp: "fo"))
        XCTAssertEqual(cw.rad, "Not measured in any of the 8 swings")
        XCTAssertEqual(cw.blad, ["Not measured in any of the 8 swings.", "5 swings: a point on the lead arm looked wrong.",
                                 "2 swings: a point on the lead arm was not found.", "1 swing: no reason recorded."])
        // Lika antal: kodernas ordning (mot kameran före "utan kod", som alltid står sist).
        let arm = try XCTUnwrap(Saknas.pass(p, matt: "framre_armbage_topp", grupp: "fo"))
        XCTAssertEqual(arm.blad, ["Measured in 6 of 8 swings.", "1 swing: the lead arm pointed toward or away from the camera.",
                                  "1 swing: no reason recorded."])
        // Alla har talet, gruppen saknar svingar, eller passet bär inte orsakerna: inget att säga.
        XCTAssertNil(Saknas.pass(p, matt: "backen_sway_topp", grupp: "fo"))
        XCTAssertNil(Saknas.pass(p, matt: "tempo", grupp: "dtl"))
        XCTAssertNil(Saknas.pass(foPass(medOrsaker: false), matt: "tempo", grupp: "alla"))
        var fel = p
        fel.saknas = Array(p.saknas!.prefix(7))
        XCTAssertNil(Saknas.pass(fel, matt: "tempo", grupp: "alla"), "orsakerna i en annan ordning än svingarna")
        // Utan någon kod: bara raden.
        var utan = p
        utan.saknas = Array(repeating: [:], count: 8)
        XCTAssertEqual(Saknas.pass(utan, matt: "tempo", grupp: "alla")?.blad, ["Measured in 5 of 8 swings."])
    }

    /// Flest först, samma text slås ihop över vyerna, och starten framifrån och bakifrån är två
    /// texter (samma kod: i bokstavsordning).
    func testOrsakernasOrdningOchVyerna() throws {
        let svingar = [SvingMatt(vy: .fo, matt: [:]), SvingMatt(vy: .dtl, matt: [:]), SvingMatt(vy: .fo, matt: [:]),
                       SvingMatt(vy: .dtl, matt: [:]), SvingMatt(vy: .dtl, matt: ["tempo": 2.9])]
        let koder: [[String: String]] = [["tempo": "start_saknas"], ["tempo": "start_saknas"], ["tempo": "start_osaker"],
                                         ["tempo": "start_osaker"], [:]]
        let p = Pass(datum: Tal.dag(2027, 1, 11), klubba: "7i", svingar: svingar, saknas: koder)
        let r = try XCTUnwrap(Saknas.pass(p, matt: "tempo", grupp: "alla"))
        XCTAssertEqual(r.orsaker, [Saknas.Rakning.Post(text: "the backswing start was not found", n: 2),
                                   Saknas.Rakning.Post(text: "the backswing start was unclear from behind", n: 1),
                                   Saknas.Rakning.Post(text: "the clip starts after the takeaway began", n: 1)])
        // Lika antal och olika koder: kodernas ordning i `Saknas.Orsak` (punkten fel före punkten borta).
        let lika = Pass(datum: Tal.dag(2027, 1, 11), klubba: "7i",
                        svingar: [SvingMatt(vy: .fo, matt: [:]), SvingMatt(vy: .fo, matt: [:])],
                        saknas: [["framre_armbage_topp": "led_saknas"], ["framre_armbage_topp": "segment_langt"]])
        XCTAssertEqual(Saknas.pass(lika, matt: "framre_armbage_topp", grupp: "fo")?.orsaker.map(\.text),
                       ["a point on the lead arm looked wrong", "a point on the lead arm was not found"])
        XCTAssertEqual(r.rad, "Measured in 1 of 5 swings")
        let ett = Pass(datum: Tal.dag(2027, 1, 11), klubba: "7i", svingar: [SvingMatt(vy: .fo, matt: [:])],
                       saknas: [["framre_armbage_topp": "led_saknas"]])
        XCTAssertEqual(Saknas.pass(ett, matt: "framre_armbage_topp", grupp: "fo")?.blad,
                       ["Not measured in the swing.", "1 swing: a point on the lead arm was not found."])
    }

    func testPassetsKortSagerHurMangaSvingarSomHarTalet() throws {
        let v = Passvisning(katalog: try katalog(), pass: [foPass()])
        func kort(_ id: String) throws -> Mattkort { try XCTUnwrap(v.kort.first { $0.id == id }, id) }
        let tempo = try kort("tempo")
        XCTAssertEqual(tempo.varde, "2.80")
        XCTAssertEqual(tempo.lage, Bandlage(.gron))                      // medianen av de fem, som förut
        XCTAssertEqual(tempo.saknas, "Measured in 5 of 8 swings")
        XCTAssertFalse(tempo.ejMatt)
        XCTAssertEqual(tempo.info?.saknas.first, "Measured in 5 of 8 swings.")
        XCTAssertEqual(tempo.info?.kalla, "Manufacturer (blastmotion.com)")
        XCTAssertTrue(tempo.upplasning.hasSuffix(", Measured in 5 of 8 swings"), tempo.upplasning)
        let cw = try kort("chicken_wing")
        XCTAssertEqual(cw.varde, "—")
        XCTAssertTrue(cw.ejMatt)
        XCTAssertEqual(cw.saknas, "Not measured in any of the 8 swings")
        XCTAssertEqual(cw.info?.saknas.count, 4)
        XCTAssertTrue(cw.upplasning.hasPrefix("Lead arm fold, Not measured in any of the 8 swings"), cw.upplasning)
        XCTAssertFalse(cw.upplasning.contains(Texter.ejMatt + ","), "inte två gånger: \(cw.upplasning)")
        XCTAssertEqual(try kort("bojd_framre_arm").saknas, "Measured in 6 of 8 swings")
        // Det som alla svingar har säger inget nytt.
        for id in ["sway_topp", "reverse_spine", "sway_gap", "backens_resa_framat"] {
            XCTAssertNil(try kort(id).saknas, id)
            XCTAssertEqual(try kort(id).info?.saknas, [], id)
        }
        // Läsordningen som förut (METOD M63): tempot visas, armbågarna under "More measures".
        let l = v.lista(i: .fo)
        XCTAssertTrue(l.kort.contains { $0.id == "tempo" })
        XCTAssertEqual(Set(l.fler.map(\.id)).intersection(["chicken_wing", "bojd_framre_arm"]),
                       ["chicken_wing", "bojd_framre_arm"])
        // Utan orsakerna (ett äldre eller påhittat pass) som förut: ingen rad på något kort.
        let utan = Passvisning(katalog: try katalog(), pass: [foPass(medOrsaker: false)])
        XCTAssertTrue(utan.kort.allSatisfy { $0.saknas == nil && $0.info?.saknas == [] })
    }

    /// Tempot bakifrån utan start: orsaken står överst i bladet, och M40:s källrad står inte också där.
    func testTempotBakifranMedOrsakerna() throws {
        let k = try katalog()
        let kort = try XCTUnwrap(Passvisning(katalog: k, pass: [dtlPass()]).kort.first { $0.id == "tempo" })
        XCTAssertEqual(kort.varde, "—")
        XCTAssertTrue(kort.ejMatt)
        XCTAssertEqual(kort.saknas, "Not measured in any of the 6 swings")
        XCTAssertEqual(kort.info?.saknas, ["Not measured in any of the 6 swings.",
                                           "4 swings: the backswing start was unclear from behind.",
                                           "2 swings: the backswing start was not found."])
        XCTAssertEqual(kort.info?.kalla, "Manufacturer (blastmotion.com)")
        XCTAssertFalse(kort.info?.kalla.contains(Texter.startOsakerKalla) ?? true)
        XCTAssertEqual(kort.upplasning, "Swing tempo, Not measured in any of the 6 swings")
        // Samma pass utan orsakerna: M40 som förut (VisningTests.testTempotUtanSakerStartBakifran).
        var gammal = dtlPass()
        gammal.saknas = nil
        let g = try XCTUnwrap(Passvisning(katalog: k, pass: [gammal]).kort.first { $0.id == "tempo" })
        XCTAssertEqual(g.info?.kalla, "Manufacturer (blastmotion.com), \(Texter.startOsakerKalla)")
        XCTAssertNil(g.saknas)
        XCTAssertEqual(g.upplasning, "Swing tempo, not measured")
    }

    /// Klubbans källa (over the top på klubbans plan, BESLUT B88) och ett avstängt fel räknas inte:
    /// svingarna utan markering saknar inget, och ett avstängt mått mäts inte.
    func testKlubbanOchDetAvstangdaRaknasInte() throws {
        let k = try katalog()
        let svingar = (0..<6).map { i -> SvingMatt in
            var m: [String: Double] = ["backen_thrust_traff": 1.0]
            if i > 0 { m["handbana"] = -1.0 }
            if i < 2 { m["skaft_plan_p6"] = 3.0 }
            return SvingMatt(vy: .dtl, matt: m)
        }
        let p = Pass(datum: Tal.dag(2027, 1, 12), klubba: "7i", svingar: svingar,
                     saknas: Array(repeating: [:], count: 6))
        let ott = try XCTUnwrap(Passvisning(katalog: k, pass: [p]).kort.first { $0.id == "over_the_top" })
        XCTAssertNil(ott.saknas, "klubbans plan i två av sex: de andra är inte markerade")
        // Utan markeringen: händernas bana saknas i en, utan kod.
        let utanKlubba = Pass(datum: p.datum, klubba: "7i", svingar: svingar.map { s in
            SvingMatt(vy: .dtl, matt: s.matt.filter { $0.key != "skaft_plan_p6" })
        }, saknas: p.saknas)
        let hand = try XCTUnwrap(Passvisning(katalog: k, pass: [utanKlubba]).kort.first { $0.id == "over_the_top" })
        XCTAssertEqual(hand.saknas, "Measured in 5 of 6 swings")
        XCTAssertEqual(hand.info?.saknas, ["Measured in 5 of 6 swings."])
        // Ett avstängt fel som övas (axellutningen) visar "—" som förut, utan räkning.
        let fo = Pass(datum: p.datum, klubba: "7i", svingar: [SvingMatt(vy: .fo, matt: [:])], saknas: [[:]])
        let axel = try XCTUnwrap(Passvisning(katalog: k, pass: [fo], ovas: ["axellutning"]).kort.first { $0.id == "axellutning" })
        XCTAssertNil(axel.saknas)
        XCTAssertFalse(axel.ejMatt)
    }
}
