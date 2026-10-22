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
        XCTAssertEqual(Tal.tal(-2.4, decimaler: 1), "−2,4")
        XCTAssertEqual(Tal.tal(11.27, decimaler: 1), "11,3")
        XCTAssertEqual(Tal.tal(-0.04, decimaler: 1), "0,0")          // inget "−0,0"
        XCTAssertEqual(Tal.tal(nil, decimaler: 1), "—")
        XCTAssertEqual(Tal.tecken(1.2, decimaler: 1), "+1,2")
        XCTAssertEqual(Tal.tecken(-2.4, decimaler: 1), "−2,4")
        XCTAssertEqual(Tal.tecken(0.03, decimaler: 1), "±0,0")
        XCTAssertEqual(Tal.tecken(2, decimaler: 0), "+2")
        XCTAssertEqual(Tal.axel(-12, decimaler: 1), "−12")
        XCTAssertEqual(Tal.axel(2.5, decimaler: 1), "2,5")
        XCTAssertEqual(Tal.medEnhet("+1,2", "cm"), "+1,2 cm")
        XCTAssertEqual(Tal.medEnhet("+2", "°"), "+2°")
        XCTAssertEqual(Tal.medEnhet("+0,1", ": 1"), "+0,1")
    }

    func testDatumen() {
        XCTAssertEqual(Tal.datum(Tal.dag(2027, 1, 6)), "6 jan")
        XCTAssertEqual(Tal.dag(Tal.dag(2027, 1, 9)), "lör 9 jan")
        XCTAssertEqual(Tal.dag(Tal.dag(2026, 10, 20)), "tis 20 okt")
        // Sent på kvällen i Sverige är fortfarande samma dag.
        XCTAssertEqual(Tal.datum(Tal.dag(2027, 1, 6, timme: 23)), "6 jan")
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
        XCTAssertEqual(s.etiketter.map { $0.text }.dropFirst().prefix(2), ["7,6", "8,4"])
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
        XCTAssertEqual(v.titel, "lör 9 jan")
        XCTAssertEqual(v.undertitel, "järn 7 · 34")
        let k = Dictionary(uniqueKeysWithValues: v.kort.map { ($0.id, $0) })
        let sway = try XCTUnwrap(k["sway_topp"])
        XCTAssertEqual(sway.namn, "Sway")
        XCTAssertEqual(sway.rubrik, "FO · topp · + mot mål")
        XCTAssertEqual(sway.varde, "−2,4")
        XCTAssertEqual(sway.enhet, "cm")
        XCTAssertEqual(sway.skillnad, "+1,2 cm mot 6 jan")
        XCTAssertEqual(sway.markning, .b10)
        XCTAssertEqual(sway.spann?.forra ?? 0, -3.6, accuracy: 1e-6)

        let tempo = try XCTUnwrap(k["tempo"])
        XCTAssertEqual(tempo.rubrik, "Klick · start–topp–träff")
        XCTAssertEqual(tempo.varde, "2,9")
        XCTAssertEqual(tempo.skillnad, "+0,1 mot 6 jan")
        guard case let .tempo(bak, ned, bakText, _)? = tempo.geometri else { return XCTFail("tempot utan sträckor") }
        XCTAssertEqual(bak / ned, 2.9, accuracy: 0.05)
        XCTAssertEqual(bakText, "0,85")

        let tapp = try XCTUnwrap(k["tappad_hallning"])
        XCTAssertEqual(tapp.markning, .egen)
        XCTAssertEqual(tapp.varde, "+2")
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
        XCTAssertEqual(Tal.datum(try XCTUnwrap(a.passDatum)), "3 nov")
        XCTAssertEqual(a.saker.count, 1)
        let s = a.saker[0]
        XCTAssertEqual(s.fel, "sway_topp")
        XCTAssertEqual(s.matt, "backen_sway_topp")
        XCTAssertEqual(s.nu, -5.7)
        XCTAssertEqual(s.markning, "B10")
        XCTAssertEqual(s.ovning.tanke, "Rör inte käppen.")
        XCTAssertEqual(s.klartNar.villkor, .minst)
        XCTAssertEqual(s.klartNar.lo, 0)
        XCTAssertEqual(s.klartNar.passIRad, 2)
        XCTAssertEqual(s.foljdfel, ["reverse_spine", "backens_resa_framat", "sway_gap"])
        XCTAssertNil(s.fysik)
        // Saken finns i katalogen, med samma mått och övning.
        let k = try katalog().fel.first { $0.id == s.fel }
        XCTAssertEqual(k?.matt, s.matt)
        XCTAssertEqual(k?.ovning, s.ovning.text)
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
        let utanTanke = AttJobbaPaFixtur.exempel.replacingOccurrences(of: #""tanke": "Rör inte käppen.","#, with: "")
        XCTAssertThrowsError(try AttJobbaPa.las(json: utanTanke)) { e in
            XCTAssertTrue("\(e)".contains("tanke"), "\(e)")
        }
    }

    func testAttJobbaPa() throws {
        let v = AttJobbaPaVisning(Demo.attJobbaPa, katalog: try katalog(), pass: Demo.pass)
        XCTAssertEqual(v.fran, "12 dec")
        XCTAssertEqual(v.saker.count, 2)
        let s = v.saker[0]
        XCTAssertEqual(s.namn, "Sway")
        XCTAssertEqual(s.rubrik, "FO · topp")
        XCTAssertEqual(s.markning, .b10)
        XCTAssertEqual(s.kedja.map { $0.namn }, ["Sway", "Resa framåt", "Sway gap"])
        XCTAssertEqual(s.kedja[0].fran, "−5,9 → −2,4")
        XCTAssertEqual(s.kedja[1].varde, "11,3")
        XCTAssertEqual(s.tanke, "”Rör inte käppen.”")
        XCTAssertEqual(s.villkor, "Sway topp ≥ 0,0 cm")
        XCTAssertEqual(s.villkorUnder, "serie 1 · 2 pass i rad")
        XCTAssertEqual(s.serie1, "−4,0")
        XCTAssertEqual(s.passet, "−2,4")
        XCTAssertEqual(s.iRad, 0)
        XCTAssertEqual(s.iRadKrav, 2)
        XCTAssertNil(s.fysik)
        let t = v.saker[1]
        XCTAssertEqual(t.namn, "Thrust")
        XCTAssertEqual(t.markning, .egen)
        XCTAssertEqual(t.kedja.map { $0.namn }, ["Thrust", "Böjning"])
        XCTAssertEqual(t.villkor, "Thrust träff ≤ 1,5 cm")
        XCTAssertNotNil(t.fysik)
    }

    func testPassenIRad() {
        func pass(_ serie1: [Double]) -> Pass {
            Pass(datum: Tal.dag(2027, 1, 1), klubba: "järn 7",
                 svingar: serie1.map { SvingMatt(vy: .fo, matt: ["backen_sway_topp": $0]) }, serie1: serie1.count)
        }
        let k = AttJobbaPa.KlartNar(villkor: .minst, lo: 0, hi: 0, passIRad: 2)
        let p = [pass([1, 1, 1]), pass([-1, -2, -1]), pass([0.5, 1, 0]), pass([0, 2, 1])]
        XCTAssertEqual(AttJobbaPaVisning.iRad(k, matt: "backen_sway_topp", grupp: "fo", pass: p), 2)
        XCTAssertEqual(AttJobbaPaVisning.iRad(k, matt: "backen_sway_topp", grupp: "fo", pass: Array(p.prefix(2))), 0)
    }

    func testIdagVisarDenForstaSaken() throws {
        let v = Idagvisning(idag: Tal.dag(2027, 1, 13), katalog: try katalog(), pass: Demo.pass,
                            attJobbaPa: Demo.attJobbaPa)
        XCTAssertEqual(v.dag, "ons 13 jan")
        XCTAssertEqual(v.senaste, "lör 9 jan · järn 7 · 34")
        XCTAssertEqual(v.rader.first?.namn, "Sway")
        XCTAssertFalse(v.rader.contains { $0.id == "axellutning" })     // avstängt
        XCTAssertEqual(v.rader.first { $0.id == "tempo" }?.enhet, "")
        XCTAssertEqual(v.forsta?.namn, "Sway")
        XCTAssertEqual(v.forsta?.tanke, "”Rör inte käppen.”")
        XCTAssertEqual(v.forsta?.kedja, ["Sway", "Resa framåt", "Sway gap"])
    }

    // MARK: Utveckling

    func testUtveckling() throws {
        let v = Utvecklingsvisning(katalog: try katalog(), pass: Demo.pass, block: Demo.block)
        XCTAssertEqual(v.period, "okt–jan · 16")
        let sway = try XCTUnwrap(v.matt.first { $0.id == "sway_topp" })
        XCTAssertEqual(sway.punkter.count, 16)
        XCTAssertEqual(sway.rubrik, "FO · topp")
        XCTAssertEqual(sway.varde, "−2,4")
        XCTAssertEqual(sway.skillnad, "+5,5 cm mot 20 okt")
        XCTAssertTrue(sway.harSerie1)
        XCTAssertEqual(sway.manader.map { $0.text }, ["okt", "nov", "dec", "jan"])
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

    func testGranskningensSlag() throws {
        let s = Demo.sving(.fo)
        let y = Matyta(sving: s, resultat: try Matt.mat(s))
        let g = Granskningsvisning(yta: y, forra: nil, forraDatum: Demo.datum[14], pass: Demo.pass.last!,
                                   matt: Granskningsvisning.matt(.fo))
        XCTAssertEqual(g.slag.count, 35)
        XCTAssertEqual(g.slag[0], .init(nr: nil, text: "−2,4"))
        XCTAssertEqual(g.slag[1].nr, 1)
        XCTAssertEqual(g.forraDatum, "6 jan")
        XCTAssertEqual(y.namn, "Sway")
        XCTAssertEqual(y.tidText(2.2), "2,20 s")
        XCTAssertEqual(y.faser.topp, 2.2, accuracy: 0.01)
    }
}
