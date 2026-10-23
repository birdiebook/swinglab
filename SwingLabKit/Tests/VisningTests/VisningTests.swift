import XCTest
@testable import Swing
@testable import SwingDemo

/// Vyernas data (S4): texten, spannen och lägena som App/Vyer ritar, räknade på
/// de påhittade passen i SwingDemo och på katalog.json i repots rot.
final class VisningTests: XCTestCase {
    static let rot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    func katalog() throws -> Katalog {
        try Katalog.las(Data(contentsOf: Self.rot.appendingPathComponent("katalog.json")))
    }

    // MARK: talen

    func testTalen() {
        // Engelskt sätt (BESLUT B30): decimalpunkt och äkta minus.
        XCTAssertEqual(Tal.tal(-2.4, decimaler: 1), "\u{2212}2.4")
        XCTAssertEqual(Tal.tal(11.27, decimaler: 1), "11.3")
        XCTAssertEqual(Tal.tal(-0.04, decimaler: 1), "0.0")          // inget "−0.0"
        XCTAssertEqual(Tal.tal(nil, decimaler: 1), "—")
        XCTAssertEqual(Tal.tecken(1.2, decimaler: 1), "+1.2")
        XCTAssertEqual(Tal.tecken(-2.4, decimaler: 1), "−2.4")
        XCTAssertEqual(Tal.tecken(0.03, decimaler: 1), "±0.0")
        XCTAssertEqual(Tal.tecken(2, decimaler: 0), "+2")
        XCTAssertEqual(Tal.axel(-12, decimaler: 1), "−12")
        XCTAssertEqual(Tal.axel(2.5, decimaler: 1), "2.5")
        XCTAssertEqual(Tal.axel(3.1, decimaler: 2), "3.1")
        XCTAssertEqual(Tal.axel(12.5, decimaler: 1), "12.5")
        XCTAssertEqual(Tal.axel(0, decimaler: 1), "0")
        XCTAssertEqual(Tal.axel(-0.04, decimaler: 1), "0")
        XCTAssertEqual(Tal.medEnhet("+1.2", "cm"), "+1.2 cm")
        XCTAssertEqual(Tal.medEnhet("+2", "°"), "+2°")
        XCTAssertEqual(Tal.medEnhet("+0.1", ": 1"), "+0.1")
    }

    func testDecimalregelnArPCns() {
        // tools/pc/analys.py enhet och avrunda (METOD MT3).
        XCTAssertEqual(Avrundning.enhet("tempo"), "")
        XCTAssertEqual(Avrundning.enhet("baksving_s"), "s")
        XCTAssertEqual(Avrundning.enhet("brost_bojning_tapp"), "°")
        XCTAssertEqual(Avrundning.enhet("bakre_kna_topp"), "°")
        XCTAssertEqual(Avrundning.enhet("backen_sway_topp"), "cm")
        XCTAssertEqual(Avrundning.decimaler("tempo"), 2)
        XCTAssertEqual(Avrundning.decimaler("brost_bojning_tapp"), 1)
        // Tilläggen mot Sportsbox (METOD M30–M37), som test_analys.py.
        XCTAssertEqual(["framre_kna_sway_topp", "framre_kna_topp", "handfart_max", "handfart_max_fore_traff_ms",
                        "framre_arm_vinkelfart_max", "genomsving_s", "backen_bojning_traff", "hand_lyft_topp"]
                        .map { Avrundning.enhet($0) }, ["cm", "°", "m/s", "ms", "°/s", "s", "°", "cm"])
        XCTAssertEqual(Avrundning.avrunda("handfart_max", 7.26), 7.3)
        // Tilläggen bakifrån (METOD M38–M39), som test_analys.py.
        XCTAssertEqual(Avrundning.enhet("hand_djup_topp"), "cm")
        XCTAssertEqual(Avrundning.enhet("framre_arm_plan_topp"), "°")
        XCTAssertEqual(Avrundning.decimaler("framre_arm_vinkelfart_max"), 0)
        XCTAssertEqual(Avrundning.avrunda("brost_bojning_tapp", 5.94), 5.9)
        XCTAssertEqual(Avrundning.avrunda("tempo", 2.876), 2.88)
        XCTAssertNil(Avrundning.avrunda("tempo", nil))
        // Grader med en decimal överallt: 5,9° blir inte 6°.
        XCTAssertEqual(Mattkort.text(5.9, Etiketter.etikett("brost_bojning_tapp")), "+5.9")
        XCTAssertEqual(Etiketter.etikett("sidbojning_topp").decimaler, 1)
    }

    func testSaknadeEnheter() {
        // Ett mått utan rad får enheten och decimalerna ur regeln.
        XCTAssertEqual(Etiketter.etikett("nytt_s").enhet, "s")
        XCTAssertEqual(Etiketter.etikett("nytt_s").decimaler, 2)
        XCTAssertEqual(Etiketter.etikett("nytt_matt").enhet, "cm")
        // Tom enhet: talet utan något efter.
        XCTAssertEqual(Tal.medEnhet("1.25", ""), "1.25")
        XCTAssertEqual(Tal.medEnhet("2.90", ": 1"), "2.90")
        // Varje mått i katalogen har en enhet i regeln (tempot är kvoten "").
        if let k = try? katalog() {
            for f in k.fel where f.matt != "tempo" {
                XCTAssertFalse(Avrundning.enhet(f.matt).isEmpty, f.matt)
            }
        }
    }

    func testUpplasningen() throws {
        let v = Passvisning(katalog: try katalog(), pass: Demo.pass)
        let sway = try XCTUnwrap(v.kort.first { $0.id == "sway_topp" })
        XCTAssertEqual(sway.upplasning, "Sway −2.4 cm, target from 0 cm, last −3.6 cm, +1.2 cm vs Jan 6, limit not read in original")
        let tempo = try XCTUnwrap(v.kort.first { $0.id == "tempo" })
        XCTAssertTrue(tempo.upplasning.hasPrefix("Tempo 2.90, target 2.5 to 3.1"), tempo.upplasning)
        let tapp = try XCTUnwrap(v.kort.first { $0.id == "tappad_hallning" })
        XCTAssertTrue(tapp.upplasning.contains("own baseline"), tapp.upplasning)
        XCTAssertEqual(v.kort.last?.upplasning, "Shoulder tilt, off")
        let j = AttJobbaPaVisning(Demo.attJobbaPa, katalog: try katalog())
        XCTAssertEqual(j.saker[0].upplasning, "Sway −2.4 cm, target from 0 cm, limit not read in original, FO · top · week 5")
        XCTAssertEqual(j.saker[0].foljd[2].upplasning, "Hip shift, Chest bend +2.0°")
    }

    func testAccentenBaraForDetSomOvas() throws {
        // BESLUT B31: det du övar på bär accenten, inget annat.
        let a = Demo.attJobbaPa
        XCTAssertEqual(a.ovas, ["sway_topp", "flying_elbow"])
        let p = Passvisning(katalog: try katalog(), pass: Demo.pass, ovas: a.ovas)
        XCTAssertEqual(Set(p.kort.filter { $0.ovas }.map { $0.id }), ["sway_topp", "flying_elbow"])
        let i = Idagvisning(idag: Tal.dag(2027, 1, 13), katalog: try katalog(), pass: Demo.pass, attJobbaPa: a)
        XCTAssertEqual(i.rader.filter { $0.ovas }.map { $0.id }, ["sway_topp", "flying_elbow"])
        let u = Utvecklingsvisning(katalog: try katalog(), pass: Demo.pass, ovas: a.ovas)
        XCTAssertEqual(u.matt.filter { $0.ovas }.map { $0.id }, ["sway_topp", "flying_elbow"])
        XCTAssertFalse(Passvisning(katalog: try katalog(), pass: Demo.pass).kort.contains { $0.ovas })
    }

    func testDatumen() {
        XCTAssertEqual(Tal.datum(Tal.dag(2027, 1, 6)), "Jan 6")
        XCTAssertEqual(Tal.dag(Tal.dag(2027, 1, 9)), "Sat, Jan 9")
        XCTAssertEqual(Tal.dag(Tal.dag(2026, 10, 20)), "Tue, Oct 20")
        XCTAssertEqual(Tal.manad(Tal.dag(2027, 5, 1)), "May")
        // Sent på kvällen i Sverige är fortfarande samma dag.
        XCTAssertEqual(Tal.datum(Tal.dag(2027, 1, 6, timme: 23)), "Jan 6")
    }

    // MARK: engelska (BESLUT B30)

    /// Inget som vymodellerna räknar fram bär å, ä eller ö: alla skärmar på de
    /// påhittade passen, märkningarna, filtret och stegen. Fäller svenska som smyger
    /// tillbaka i Texter, i katalogens fält som visas eller i Demo.
    func testIngaSvenskaTeckenIVisningen() throws {
        let k = try katalog()
        var texter: [String] = []
        let p = Passvisning(katalog: k, pass: Demo.pass, ovas: Demo.attJobbaPa.ovas)
        texter += [p.titel, p.undertitel] + Passvisning.Filter.allCases.map(\.etikett)
        for kort in p.kort {
            texter += [kort.namn, kort.rubrik, kort.varde, kort.enhet, kort.skillnad ?? "", kort.upplasning]
            texter += (kort.spann?.etiketter.map { $0.text } ?? []) + [kort.markning?.etikett ?? ""]
        }
        let j = AttJobbaPaVisning(Demo.attJobbaPa, katalog: k)
        texter.append(j.fran)
        for sak in j.saker {
            texter += [sak.namn, sak.rubrik, sak.nu, sak.ovning, sak.tanke, sak.villkor, sak.villkorUnder, sak.upplasningHel]
            texter += sak.steg.map { $0.namn } + sak.foljd.flatMap { $0.vag + [$0.upplasning] }
            texter += [sak.rorlighet?.test ?? "", sak.rorlighet?.ovning ?? ""]
        }
        let i = Idagvisning(idag: Tal.dag(2027, 1, 13), katalog: k, pass: Demo.pass, attJobbaPa: Demo.attJobbaPa)
        texter += [i.dag, i.senaste ?? "", i.forsta?.namn ?? "", i.forsta?.tanke ?? ""] + (i.forsta?.kedja ?? [])
        texter += i.rader.map { $0.upplasning }
        let u = Utvecklingsvisning(katalog: k, pass: Demo.pass, block: Demo.block)
        texter.append(u.period)
        for m in u.matt {
            texter += [m.namn, m.rubrik, m.varde, m.skillnad ?? ""] + m.manader.map { $0.text } + m.axelText.map { $0.text }
        }
        for vy in [Vy.fo, .dtl] {
            let s = Demo.sving(vy)
            let y = Matyta(sving: s, resultat: try Matt.mat(s))
            let g = Granskningsvisning(yta: y, forra: nil, forraDatum: Demo.datum[14], pass: Demo.pass.last!,
                                       matt: Granskningsvisning.matt(vy))
            texter += [y.namn, y.tidText(1), g.forraDatum ?? ""] + g.slag.map { $0.text }
        }
        for m in [Markning.b10, .egen, .av] { texter += [m.etikett, m.upplasning] }
        texter += Etiketter.tabell.values.flatMap { [$0.namn, $0.fas, $0.vy ?? "", $0.plus.map(Texter.plus) ?? ""] }
        texter += Array(Texter.stegnamn.values) + Texter.manader + Texter.veckodagar
        // Katalogens fält som visas (namn, övning, tanke) är också engelska.
        texter += k.fel.flatMap { [$0.namn, $0.ovning, $0.tanke] }
        XCTAssertGreaterThan(texter.count, 100)
        let svenska = CharacterSet(charactersIn: "åäöÅÄÖ")
        for t in texter { XCTAssertNil(t.rangeOfCharacter(from: svenska), t) }
        // Tal på engelskt sätt: inget decimalkomma mellan siffror.
        let komma = try NSRegularExpression(pattern: "[0-9],[0-9]")
        for t in texter where !t.contains("/") {
            XCTAssertNil(komma.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)), t)
        }
    }

    func testFelenVidLasningenArEngelska() {
        let fel = AttJobbaPaFixtur.exempel.replacingOccurrences(of: "swinglab-att-jobba-pa/1", with: "annat/1")
        XCTAssertThrowsError(try AttJobbaPa.las(json: fel)) { e in
            XCTAssertEqual("\(e)", "att_jobba_pa: format: must start with swinglab-att-jobba-pa/")
        }
        XCTAssertThrowsError(try AttJobbaPa.las(json: "{")) { e in
            XCTAssertTrue(["att_jobba_pa: not valid JSON", "att_jobba_pa: file: invalid"].contains("\(e)"), "\(e)")
        }
        let utan = AttJobbaPaFixtur.exempel.replacingOccurrences(of: #""markning": "B10","#, with: "")
        XCTAssertThrowsError(try AttJobbaPa.las(json: utan)) { e in
            XCTAssertTrue("\(e)".hasSuffix("markning is missing"), "\(e)")
        }
    }

    // MARK: axeln och spannet

    func testAxeln() {
        XCTAssertEqual(Axel.jamntSteg(3.1), 2)
        XCTAssertEqual(Axel.jamntSteg(0.12), 0.1, accuracy: 1e-12)
        XCTAssertEqual(Axel.jamntSteg(40), 50)
        let a = Axel.runt([-8, 3])
        XCTAssertLessThanOrEqual(a.lo, -8)
        XCTAssertGreaterThanOrEqual(a.hi, 3)
        XCTAssertEqual(a.lo.truncatingRemainder(dividingBy: a.steg), 0, accuracy: 1e-9)
        XCTAssertEqual(a.andel(a.lo), 0)
        XCTAssertEqual(a.andel(a.hi + 100), 1)
        XCTAssertTrue(a.streck.contains(0))
    }

    func testSpannetMedOppenGrans() {
        // Swayen: grönt ≥ 0, passet −2,4 och förra −3,6.
        let s = Spann(nu: -2.4, spridning: (-3.3, -1.5), forra: -3.6, gront: [0, nil], baslinje: nil, decimaler: 1)
        guard case let .grans(lo, hi)? = s.zon else { return XCTFail("ingen gräns") }
        XCTAssertEqual(lo, 0)
        XCTAssertEqual(hi, s.axel.hi)                       // öppen ände = axelns ände
        XCTAssertGreaterThan(s.axel.hi, 0)                  // och axeln går förbi gränsen
        XCTAssertLessThanOrEqual(s.axel.lo, -3.6)
        XCTAssertEqual(s.etiketter.map { $0.text }, [Tal.axel(s.axel.lo, decimaler: 1), "0", Tal.axel(s.axel.hi, decimaler: 1)])
    }

    func testSpannetMedBaslinje() {
        let s = Spann(nu: 11.3, spridning: (10.2, 12.1), forra: 11.0, gront: nil, baslinje: (7.6, 8.4), decimaler: 1)
        XCTAssertEqual(s.zon, .baslinje(lo: 7.6, hi: 8.4))
        XCTAssertEqual(s.etiketter.map { $0.text }.dropFirst().prefix(2), ["7.6", "8.4"])
        XCTAssertLessThanOrEqual(s.axel.lo, 7.6)
        XCTAssertGreaterThanOrEqual(s.axel.hi, 12.1)
    }

    // MARK: demopassen

    func testDemopassenHarSkissensTal() {
        let p = Demo.pass
        XCTAssertEqual(p.count, 16)
        let nu = p.last!
        XCTAssertEqual(nu.slag, 34)
        XCTAssertEqual(nu.median("backen_sway_topp", "fo")!, -2.4, accuracy: 1e-6)
        XCTAssertEqual(nu.serie1Median("backen_sway_topp", "fo")!, -4.0, accuracy: 1e-6)
        XCTAssertEqual(nu.median("backen_thrust_traff", "dtl")!, 2.6, accuracy: 1e-6)
        XCTAssertEqual(nu.median("tempo", "alla")!, 2.9, accuracy: 1e-6)
        XCTAssertEqual(p[14].median("backen_sway_topp", "fo")!, -3.6, accuracy: 1e-6)
        XCTAssertNil(nu.median("backen_thrust_traff", "fo"))
    }

    // MARK: Passet

    func testPasset() throws {
        let v = Passvisning(katalog: try katalog(), pass: Demo.pass)
        XCTAssertEqual(v.titel, "Sat, Jan 9")
        XCTAssertEqual(v.undertitel, "7i\u{00A0}· 34")
        let k = Dictionary(uniqueKeysWithValues: v.kort.map { ($0.id, $0) })
        let sway = try XCTUnwrap(k["sway_topp"])
        XCTAssertEqual(sway.namn, "Sway")
        XCTAssertEqual(sway.rubrik, "FO · top · + to target")
        XCTAssertEqual(sway.varde, "−2.4")
        XCTAssertEqual(sway.enhet, "cm")
        XCTAssertEqual(sway.skillnad, "+1.2 cm vs Jan 6")
        XCTAssertEqual(sway.markning, .b10)
        XCTAssertEqual(sway.spann?.forra ?? 0, -3.6, accuracy: 1e-6)

        let tempo = try XCTUnwrap(k["tempo"])
        XCTAssertEqual(tempo.rubrik, "Audio · start–top–impact")
        XCTAssertEqual(tempo.varde, "2.90")
        XCTAssertEqual(tempo.skillnad, "+0.10 vs Jan 6")
        guard case let .tempo(bak, ned, bakText, _)? = tempo.geometri else { return XCTFail("tempot utan sträckor") }
        XCTAssertEqual(bak / ned, 2.9, accuracy: 0.05)
        XCTAssertEqual(bakText, "0.85")

        let tapp = try XCTUnwrap(k["tappad_hallning"])
        XCTAssertEqual(tapp.markning, .egen)
        XCTAssertEqual(tapp.varde, "+2.0")
        XCTAssertEqual(tapp.enhet, "°")
        guard case let .bojning(a, t)? = tapp.geometri else { return XCTFail("böjningen utan linjer") }
        XCTAssertEqual(a - t, 2, accuracy: 1e-6)
        guard case .baslinje? = tapp.spann?.zon else { return XCTFail("egen utan baslinje") }

        let av = try XCTUnwrap(v.kort.last)
        XCTAssertEqual(av.id, "axellutning")
        XCTAssertEqual(av.markning, .av)
        XCTAssertEqual(av.varde, "—")
        XCTAssertNil(av.spann)

        // Filtret: ett kort för båda telefonerna syns i båda.
        XCTAssertTrue(v.filtrerat(.fo).contains { $0.id == "tempo" })
        XCTAssertFalse(v.filtrerat(.fo).contains { $0.id == "early_extension" })
        XCTAssertFalse(v.filtrerat(.dtl).contains { $0.id == "sway_topp" })
        XCTAssertEqual(v.filtrerat(.alla).count, v.kort.count)
    }

    func testEttMattUtanEtikettSyns() {
        XCTAssertEqual(Etiketter.etikett("nytt_matt").namn, "nytt_matt")
        // Varje mått som katalogen pekar på har en rad.
        if let k = try? katalog() {
            for f in k.fel { XCTAssertNotNil(Etiketter.tabell[f.matt], f.matt) }
        }
    }

    // MARK: Att jobba på

    func testS5sExempelGarAttLasa() throws {
        let a = try AttJobbaPa.las(json: AttJobbaPaFixtur.exempel)
        XCTAssertEqual(a.pass, "20261103-180000")
        XCTAssertEqual(Tal.datum(try XCTUnwrap(a.passDatum)), "Nov 3")
        XCTAssertEqual(a.saker.count, 1)
        let s = a.saker[0]
        XCTAssertEqual(s.fel, "sway_topp")
        XCTAssertEqual(s.matt, "backen_sway_topp")
        XCTAssertEqual(s.nu, -5.7)
        XCTAssertEqual(s.markning, "B10")
        XCTAssertEqual(s.ovning.tanke, "Leave the stick standing.")
        XCTAssertEqual(s.ovning.steg, "langsamt_med_foremal")
        XCTAssertEqual(s.klartNar.villkor, .minst)
        XCTAssertEqual(s.klartNar.lo, 0)
        XCTAssertEqual(s.klartNar.passIRad, 2)
        XCTAssertEqual(s.foljdfel.map { $0.fel }, ["reverse_spine", "early_extension", "backens_resa_framat",
                                                   "tappad_hallning", "sway_gap"])
        XCTAssertEqual(s.foljdfel[1].vag, ["sway_topp", "reverse_spine", "early_extension"])
        XCTAssertEqual(s.foljdfel[0].nu, 4.0)
        XCTAssertEqual(s.block.start, "2026-11-03")
        XCTAssertEqual(s.block.vecka, 1)
        XCTAssertNil(s.fysik)
        // Saken finns i katalogen, med samma mått och övning.
        let k = try katalog().fel.first { $0.id == s.fel }
        XCTAssertEqual(k?.matt, s.matt)
        XCTAssertEqual(k?.ovning, s.ovning.text)

        // Vyn visar filen som den är.
        let v = AttJobbaPaVisning(a, katalog: try katalog())
        XCTAssertEqual(v.fran, "Nov 3")
        let sv = v.saker[0]
        XCTAssertEqual(sv.rubrik, "FO · top · week 1")
        XCTAssertEqual(sv.nu, "−5.7")
        XCTAssertEqual(sv.foljd.map { $0.vag }, [["Side bend"], ["Side bend", "Thrust"], ["Hip shift"],
                                                ["Hip shift", "Chest bend"], ["Sway gap"]])
        XCTAssertEqual(sv.foljd.map { $0.varde }, ["+4.0", "+3.3", "13.8", "+5.9", "+16.5"])   // filens tal, inte avrundade om
        XCTAssertEqual(sv.steg.map { $0.namn }, ["Slow", "Half speed", "Full speed", "Varied"])
        XCTAssertEqual(sv.steg[0].lage, .nu)
        XCTAssertEqual(sv.villkor, "First set ≥ 0 cm")
    }

    func testFixturenArS5s() throws {
        let fil = try String(contentsOf: Self.rot.appendingPathComponent("tools/tests/fixturer/att_jobba_pa_exempel.json"),
                             encoding: .utf8)
        XCTAssertEqual(AttJobbaPaFixtur.exempel.trimmingCharacters(in: .whitespacesAndNewlines),
                       fil.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func testVillkorenOchFormen() throws {
        func las(_ villkor: String, _ grans: String) throws -> AttJobbaPa.KlartNar {
            let json = AttJobbaPaFixtur.exempel.replacingOccurrences(
                of: #""klart_nar": {"villkor": ">=", "grans": 0,"#, with: #""klart_nar": {"villkor": "\#(villkor)", "grans": \#(grans),"#)
            return try AttJobbaPa.las(json: json).saker[0].klartNar
        }
        let mellan = try las("mellan", "[2.5, 3.1]")
        XCTAssertEqual(mellan.villkor, .mellan)
        XCTAssertEqual([mellan.lo, mellan.hi], [2.5, 3.1])
        XCTAssertTrue(mellan.haller(2.9))
        XCTAssertFalse(mellan.haller(3.2))
        let hogst = try las("<=", "1.5")
        XCTAssertTrue(hogst.haller(1.5))
        XCTAssertFalse(hogst.haller(1.6))
        XCTAssertThrowsError(try las("mellan", "3"))
        XCTAssertThrowsError(try las("ungefär", "3"))
        // Formatet, och felet nämner fältet men inte värdet.
        let fel = AttJobbaPaFixtur.exempel.replacingOccurrences(of: "swinglab-att-jobba-pa/1", with: "annat/1")
        XCTAssertThrowsError(try AttJobbaPa.las(json: fel)) { e in
            XCTAssertTrue("\(e)".contains("format"))
            XCTAssertFalse("\(e)".contains("annat"))
        }
        let felSteg = AttJobbaPaFixtur.exempel.replacingOccurrences(of: "langsamt_med_foremal", with: "snabbt")
        XCTAssertThrowsError(try AttJobbaPa.las(json: felSteg)) { e in
            XCTAssertTrue("\(e)".contains("steg"), "\(e)")
            XCTAssertFalse("\(e)".contains("snabbt"))
        }
        // Formen är stängd: nu, spann, markning och fysik måste stå med, även som null.
        for nyckel in [#""nu": -5.7,"#, #""spann": [0, null],"#, #""markning": "B10","#, #""fysik": null,"#] {
            let utan = AttJobbaPaFixtur.exempel.replacingOccurrences(of: nyckel, with: "")
            XCTAssertNotEqual(utan, AttJobbaPaFixtur.exempel, nyckel)
            XCTAssertThrowsError(try AttJobbaPa.las(json: utan), nyckel)
        }
        // "klart när" med en decimal visas som den står: 12,5° blir inte 12°.
        let grader = AttJobbaPaFixtur.exempel
            .replacingOccurrences(of: #""klart_nar": {"villkor": ">=", "grans": 0,"#,
                                  with: #""klart_nar": {"villkor": "<=", "grans": 12.5,"#)
            .replacingOccurrences(of: #""matt": "backen_sway_topp""#, with: #""matt": "brost_bojning_tapp""#)
            .replacingOccurrences(of: #""enhet": "cm",\#n   "nu""#, with: #""enhet": "°",\#n   "nu""#)
        let v = AttJobbaPaVisning(try AttJobbaPa.las(json: grader), katalog: try katalog())
        XCTAssertEqual(v.saker[0].villkor, "First set ≤ 12.5°")
        XCTAssertEqual(v.saker[0].nu, "−5.7")
        let utanTanke = AttJobbaPaFixtur.exempel.replacingOccurrences(of: #""tanke": "Leave the stick standing.","#, with: "")
        XCTAssertNotEqual(utanTanke, AttJobbaPaFixtur.exempel)
        XCTAssertThrowsError(try AttJobbaPa.las(json: utanTanke)) { e in
            XCTAssertTrue("\(e)".contains("tanke"), "\(e)")
        }
    }

    func testAttJobbaPa() throws {
        let v = AttJobbaPaVisning(Demo.attJobbaPa, katalog: try katalog())
        XCTAssertEqual(v.fran, "Jan 9")
        XCTAssertEqual(v.saker.count, 2)
        let s = v.saker[0]
        XCTAssertEqual(s.namn, "Sway")
        XCTAssertEqual(s.rubrik, "FO · top · week 5")
        XCTAssertEqual(s.markning, .b10)
        XCTAssertEqual(s.nu, "−2.4")
        guard case let .grans(lo, _)? = s.mal?.zon else { return XCTFail("målet utan spann") }
        XCTAssertEqual(lo, 0)
        XCTAssertEqual(s.foljd.first?.vag, ["Side bend"])
        XCTAssertEqual(s.steg[1].lage, .nu)
        XCTAssertEqual(s.steg[0].lage, .klart)
        XCTAssertEqual(s.tanke, "\u{201C}Leave the stick standing.\u{201D}")
        XCTAssertEqual(s.villkor, "First set ≥ 0 cm")
        XCTAssertEqual(s.villkorUnder, "2 sessions in a row")
        XCTAssertNil(s.rorlighet)
        let t = v.saker[1]
        XCTAssertEqual(t.namn, "Trail elbow")
        XCTAssertEqual(t.markning, .egen)
        XCTAssertNil(t.mal)                                   // egen baslinje: inget spann i filen
        XCTAssertTrue(t.foljd.isEmpty)
        XCTAssertEqual(t.nu, "+56.0")
        XCTAssertEqual(t.villkor, "First set ≤ 51.5°")
        XCTAssertEqual(t.rorlighet?.test, "90/90, trail shoulder external rotation")
    }

    func testIdagVisarDenForstaSaken() throws {
        let v = Idagvisning(idag: Tal.dag(2027, 1, 13), katalog: try katalog(), pass: Demo.pass,
                            attJobbaPa: Demo.attJobbaPa)
        XCTAssertEqual(v.dag, "Wed, Jan 13")
        XCTAssertEqual(v.senaste, "Sat, Jan 9\u{00A0}· 7i\u{00A0}· 34")
        XCTAssertEqual(v.rader.first?.namn, "Sway")
        XCTAssertFalse(v.rader.contains { $0.id == "axellutning" })     // avstängt
        XCTAssertEqual(v.rader.first { $0.id == "tempo" }?.enhet, "")
        XCTAssertEqual(v.forsta?.namn, "Sway")
        XCTAssertEqual(v.forsta?.tanke, "\u{201C}Leave the stick standing.\u{201D}")
        XCTAssertEqual(v.forsta?.kedja, ["Sway", "Side bend", "Hip shift"])
        // Alla saker med tanken (S4c), och veckan för den första.
        XCTAssertEqual(v.fokus.map(\.namn), ["Sway", "Trail elbow"])
        XCTAssertEqual(v.fokus[1].tanke, "\u{201C}A towel under the trail arm stays in place to the top.\u{201D}")
        XCTAssertEqual(v.fokus[1].kedja.count, 1, "flying elbow saknar följdfel")
        XCTAssertEqual(v.vecka, "week 5")
        // Accenten bara på det som övas (BESLUT B31).
        XCTAssertTrue(v.rader.contains { $0.id == "sway_topp" && $0.ovas })
        XCTAssertTrue(v.rader.filter(\.ovas).allSatisfy { Demo.attJobbaPa.ovas.contains($0.id) })
        XCTAssertTrue(v.rader.contains { !$0.ovas }, "det som inte övas är gråskala")
        // Utan fil och utan pass: dagen och inget mer.
        let tom = Idagvisning(idag: Tal.dag(2027, 1, 13), katalog: try katalog(), pass: [], attJobbaPa: nil)
        XCTAssertNil(tom.senaste)
        XCTAssertTrue(tom.rader.isEmpty && tom.fokus.isEmpty)
        XCTAssertNil(tom.vecka)
    }

    /// Utveckling i appen (S4c): passets spridning per pass, perioden inom en månad, antalet
    /// pass som inte är med, och det som övas bär accenten. METOD MS16
    func testUtvecklingMedSpridningOchEjMatta() throws {
        let v = Utvecklingsvisning(katalog: try katalog(), pass: Demo.pass, block: Demo.block,
                                   ovas: Demo.attJobbaPa.ovas, ejMatta: 2)
        XCTAssertEqual(v.ejMatta, "2 not measured")
        let sway = try XCTUnwrap(v.matt.first { $0.id == "sway_topp" })
        XCTAssertTrue(sway.ovas)
        XCTAssertTrue(v.matt.filter(\.ovas).allSatisfy { Demo.attJobbaPa.ovas.contains($0.id) })
        XCTAssertFalse(try XCTUnwrap(v.matt.first { $0.id == "backens_resa_framat" }).ovas, "ett följdfel övas inte")
        for (p, pass) in zip(sway.punkter, Demo.pass) {
            let s = try XCTUnwrap(pass.sammanfattning("backen_sway_topp", "fo"))
            XCTAssertEqual(p.q1, s.q1)
            XCTAssertEqual(p.q3, s.q3)
            XCTAssertLessThanOrEqual(p.q1!, p.pass)
            XCTAssertGreaterThanOrEqual(p.q3!, p.pass)
            XCTAssertGreaterThanOrEqual(p.q1!, sway.axel.lo, "spridningen ryms i axeln")
            XCTAssertLessThanOrEqual(p.q3!, sway.axel.hi)
        }
        let jan = Array(Demo.pass.suffix(3))
        let u = Utvecklingsvisning(katalog: try katalog(), pass: jan)
        XCTAssertEqual(u.period, "7i\u{00A0}· Jan\u{00A0}· 3")
        XCTAssertTrue(Utvecklingsvisning(katalog: try katalog(), pass: []).matt.isEmpty)
    }

    // MARK: Utveckling

    func testUtveckling() throws {
        let v = Utvecklingsvisning(katalog: try katalog(), pass: Demo.pass, block: Demo.block)
        XCTAssertEqual(v.period, "7i\u{00A0}· Oct–Jan\u{00A0}· 16")
        XCTAssertNil(v.ejMatta)
        let sway = try XCTUnwrap(v.matt.first { $0.id == "sway_topp" })
        XCTAssertEqual(sway.punkter.count, 16)
        XCTAssertEqual(sway.rubrik, "FO · top")
        XCTAssertEqual(sway.varde, "−2.4")
        XCTAssertEqual(sway.skillnad, "+5.5 cm vs Oct 20")
        XCTAssertTrue(sway.harSerie1)
        XCTAssertEqual(sway.manader.map { $0.text }, ["Oct", "Nov", "Dec", "Jan"])
        XCTAssertEqual(sway.manader.map { $0.index }, [0, 3, 10, 13])
        XCTAssertEqual(sway.block.map { $0.index }, [4, 11])
        XCTAssertEqual(sway.block.map { $0.text }, ["B1", "B2"])
        guard case let .grans(lo, hi)? = sway.band else { return XCTFail("swayen utan gräns") }
        XCTAssertEqual(lo, 0)
        XCTAssertEqual(hi, .infinity)
        XCTAssertGreaterThanOrEqual(sway.axel.hi, 0)       // gränsen syns i diagrammet
        let resa = try XCTUnwrap(v.matt.first { $0.id == "backens_resa_framat" })
        guard case .baslinje? = resa.band else { return XCTFail("resan utan baslinje") }
        XCTAssertFalse(resa.harSerie1 && resa.punkter.allSatisfy { $0.serie1 == $0.pass })
        XCTAssertFalse(v.matt.contains { $0.id == "axellutning" })   // avstängt
    }

    // MARK: Granskningens mätyta

    func testMatytanGerMattetsTal() throws {
        for vy in [Vy.fo, .dtl] {
            let s = Demo.sving(vy)
            let r = try Matt.mat(s)
            let y = Matyta(sving: s, resultat: r)
            let matt = vy == .fo ? "backen_sway" : "backen_thrust"
            for fas in [Fas.topp, .traff, .finish] {
                let l = try XCTUnwrap(y.lage(fas), "\(vy) \(fas)")
                XCTAssertEqual(l.matt, r.matt["\(matt)_\(fas.rawValue)"]!, accuracy: 1e-9, "\(vy) \(fas)")
            }
            XCTAssertEqual(y.lage(.adress)!.matt, 0, accuracy: 1e-9)
            let kurva = y.kurva()
            XCTAssertGreaterThan(kurva.count, 100)
            XCTAssertEqual(kurva.first!.t, y.fran, accuracy: 1e-9)
        }
        // Demosvingarna ligger på passets medianer.
        let fo = try Matt.mat(Demo.sving(.fo))
        XCTAssertEqual(fo.matt["backen_sway_topp"]!, -2.4, accuracy: 0.05)
        XCTAssertEqual(fo.matt["backen_resa_framat"]!, 11.3, accuracy: 0.05)
        let dtl = try Matt.mat(Demo.sving(.dtl))
        XCTAssertEqual(dtl.matt["backen_thrust_traff"]!, 2.6, accuracy: 0.05)
        XCTAssertEqual(dtl.matt["brost_bojning_tapp"]!, 2, accuracy: 0.1)
        let forra = try Matt.mat(Demo.sving(.fo, forra: true))
        XCTAssertEqual(forra.matt["backen_sway_topp"]!, -3.6, accuracy: 0.05)
    }

    func testForraPassetLiggerILinjeEfterFaserna() throws {
        let s = Demo.sving(.fo), f = Demo.sving(.fo, forra: true)
        let y = Matyta(sving: s, resultat: try Matt.mat(s)), g = Matyta(sving: f, resultat: try Matt.mat(f))
        // Demots förra pass har andra tider, så samma klipptid är inte samma fas.
        XCTAssertGreaterThan(abs(y.faser.topp - g.faser.topp), 0.1)
        for (a, b) in zip(y.fastider, g.fastider) {
            XCTAssertEqual(y.motsvarande(a.t, i: g), b.t, accuracy: 1e-9, "\(a.fas)")
        }
        // Mitt mellan toppen och träffen här är mitt mellan dem där.
        XCTAssertEqual(y.motsvarande((y.faser.topp + y.faser.traff) / 2, i: g), (g.faser.topp + g.faser.traff) / 2,
                       accuracy: 1e-9)
        // Före adressen och efter finishen: samma förskjutning som fasen.
        XCTAssertEqual(y.motsvarande(y.fran - 0.2, i: g) - g.fastider[0].t, y.fran - 0.2 - y.fastider[0].t, accuracy: 1e-9)
        // Vid toppen visar förra passet sin egen sway vid toppen.
        let l = try XCTUnwrap(g.lage(y.motsvarande(y.faser.topp, i: g)))
        XCTAssertEqual(l.matt, -3.6, accuracy: 0.05)
    }

    func testGranskningensSlag() throws {
        let s = Demo.sving(.fo)
        let y = Matyta(sving: s, resultat: try Matt.mat(s))
        let g = Granskningsvisning(yta: y, forra: nil, forraDatum: Demo.datum[14], pass: Demo.pass.last!,
                                   matt: Granskningsvisning.matt(.fo))
        XCTAssertEqual(g.slag.count, 35)
        XCTAssertEqual(g.slag[0], .init(nr: nil, text: "−2.4"))
        XCTAssertEqual(g.slag[1].nr, 1)
        XCTAssertEqual(g.forraDatum, "Jan 6")
        XCTAssertEqual(y.namn, "Sway")
        XCTAssertEqual(y.tidText(2.2), "2.20 s")
        XCTAssertEqual(y.faser.topp, 2.2, accuracy: 0.01)
    }

    // MARK: Filerna från PC:n på telefonen (S4c)

    /// Blockens första dagar ur alla hämtade filer (Utvecklings B1, B2). METOD MS16
    func testBlockenUrFilerna() throws {
        let ny = Demo.attJobbaPa
        let gammal = try AttJobbaPa.las(json: Demo.attJobbaPaJSON
            .replacingOccurrences(of: "\"pass\": \"20270109-180000\"", with: "\"pass\": \"20261110-180000\"")
            .replacingOccurrences(of: "\"start\": \"2026-12-12\"", with: "\"start\": \"2026-11-05\""))
        XCTAssertEqual(gammal.pass, "20261110-180000")
        XCTAssertEqual(AttJobbaPa.block([gammal, ny, ny]), [Tal.dag(2026, 11, 5, timme: 0), Tal.dag(2026, 12, 12, timme: 0)])
        XCTAssertEqual(AttJobbaPa.block([]), [])
        // Blocken på Utvecklings axel: mellan passen före och efter blockens första dag.
        let u = Utvecklingsvisning(katalog: try katalog(), pass: Demo.pass, block: AttJobbaPa.block([gammal, ny]))
        XCTAssertEqual(try XCTUnwrap(u.matt.first { $0.id == "sway_topp" }).block.map(\.text), ["B1", "B2"])
    }

    /// Utveckling med blandade vyer: ett DTL-pass sist. FO-måttets baslinje tas ur passen före
    /// dess egen sista punkt, och perioden räknar måttets pass. METOD M27, MS16
    func testUtvecklingMedBlandadeVyer() throws {
        let k = try katalog()
        let fo = Demo.pass.map { p in Pass(datum: p.datum, klubba: p.klubba, svingar: p.svingar.filter { $0.vy == .fo },
                                            serie1: p.serie1) }
        let dtl = Pass(datum: Tal.dag(2027, 1, 12), klubba: "7i", svingar: Demo.pass.last!.svingar.filter { $0.vy == .dtl })
        let bara = Utvecklingsvisning(katalog: k, pass: fo)
        let blandat = Utvecklingsvisning(katalog: k, pass: fo + [dtl])
        let a = try XCTUnwrap(bara.matt.first { $0.id == "backens_resa_framat" })
        let b = try XCTUnwrap(blandat.matt.first { $0.id == "backens_resa_framat" })
        guard case let .baslinje(lo, hi)? = a.band, case let .baslinje(lo2, hi2)? = b.band else {
            return XCTFail("resan utan baslinje")
        }
        XCTAssertEqual(lo, lo2, "DTL-passet sist rör inte FO-måttets baslinje")
        XCTAssertEqual(hi, hi2)
        let facit = try XCTUnwrap(Baslinje.spann(fo.dropLast().flatMap { $0.varden("backen_resa_framat", "fo") }))
        XCTAssertEqual(lo, facit.lo, accuracy: 1e-12)
        XCTAssertEqual(b.punkter.count, 16)
        XCTAssertEqual(b.period, "7i\u{00A0}· Oct–Jan\u{00A0}· 16", "måttets pass, inte DTL-passet")
        XCTAssertEqual(blandat.period, "7i\u{00A0}· Oct–Jan\u{00A0}· 17")
        let thrust = try XCTUnwrap(blandat.matt.first { $0.id == "early_extension" })
        XCTAssertEqual(thrust.punkter.count, 1)
        XCTAssertEqual(thrust.period, "7i\u{00A0}· Jan\u{00A0}· 1")
        // Räkningen av passen som inte är med, var för sig.
        XCTAssertEqual(Utvecklingsvisning(katalog: k, pass: fo, ejMatta: 1, annanLangd: 2).ejMatta,
                       "1 not measured\u{00A0}· 2 at another height")
        XCTAssertEqual(Utvecklingsvisning(katalog: k, pass: fo, annanLangd: 1).ejMatta, "1 at another height")
    }
}
