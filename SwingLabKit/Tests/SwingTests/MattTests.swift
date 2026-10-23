import XCTest
@testable import Swing

/// Swift mot Python (BESLUT B12): samma påhittade leder ska ge samma tal.
/// Facit är tools/pc/matt.py, skrivet i Fixturer.swift av tools/pc/generera.py --swift.
final class MattTests: XCTestCase {
    /// Samma algoritm ska ge samma tal: skillnaden får bara vara summeringsordningen
    /// (numpy mot en loop), ≈ 1e-13. Relativt 1e-6 med ett absolut golv för tal nära 0.
    static let relativ = 1e-6
    static let golv = 1e-9
    /// Tiderna (s): toppen och starten ur samma rutor och samma parabel.
    static let tid = 1e-9

    static func lika(_ a: Double, _ b: Double) -> Bool {
        abs(a - b) <= relativ * Swift.max(abs(a), abs(b)) + golv
    }

    func testVarjeSvingGerPythonsTal() throws {
        XCTAssertEqual(Fixturer.svingar.map { $0.namn }, ["fo", "fo_vanster", "dtl", "dtl_lucka", "fo_luckor", "dtl_kort",
                                                       "fo_kort_arm", "fo_lucka_arm", "dtl_vanster", "fo_lucka_fart",
                                                       "fo_nara_traff", "dtl_dold", "dtl_osaker", "dtl_utan_pose"])
        var jamforda = 0
        var positioner = 0
        for f in Fixturer.svingar {
            let sving = try Sving.las(json: f.indata)
            let python = try avkoda(PythonSving.self, f.python)
            let r = try Matt.mat(sving)
            XCTAssertEqual(Set(r.matt.keys), Set(python.matt.keys), "\(f.namn): samma mått")
            for (k, v) in python.matt {
                guard let s = r.matt[k] else { continue }
                XCTAssertTrue(Self.lika(s, v), "\(f.namn): \(k) Swift \(s) Python \(v)")
                jamforda += 1
            }
            XCTAssertTrue(Self.lika(r.cmPerPx, python.cmPerPx), "\(f.namn): skalan")
            XCTAssertEqual(r.faser.topp, python.faser.topp, accuracy: Self.tid, "\(f.namn): toppen")
            XCTAssertEqual(r.faser.traff, python.faser.traff, "\(f.namn): träffen")
            XCTAssertEqual(r.faser.start == nil, python.faser.start == nil, "\(f.namn): starten")
            XCTAssertEqual(r.faser.startOsaker, python.faser.startOsaker, "\(f.namn): starten osäker")
            if let a = r.faser.start, let b = python.faser.start {
                XCTAssertEqual(a, b, accuracy: Self.tid, "\(f.namn): starten")
            }
            // P-positionerna, samma tider inom 1e-9 s och samma saknade. METOD M28
            for p in Positioner.namn {
                let s = r.positioner.tid(p), py = python.positioner.tid(p)
                XCTAssertEqual(s == nil, py == nil, "\(f.namn): \(p) saknas i det ena")
                if let a = s, let b = py {
                    XCTAssertEqual(a, b, accuracy: Self.tid, "\(f.namn): \(p)")
                    positioner += 1
                }
            }
        }
        // Kvittot: testet jämförde verkligen måtten
        // (54 + 46 + 43 + 36 + 48 + 33 + 51 + 50 + 43 + 51 + 54 + 43 + 40 + 34 = 626;
        // S1c: händernas djup i varje DTL-sving, armen mot axellinjen där axlarna är vridna)
        // och positionerna (14 × 7 − 6 saknade = 92).
        XCTAssertEqual(jamforda, 626)
        XCTAssertEqual(positioner, 92)
    }

    func testDePahittadeFormerna() throws {
        // Figurens bäcken står 6 cm bakom adressen vid toppen och 8 cm framför vid
        // träffen; fixturen har 0,8 px brus, så ±0,5 cm.
        let fo = try Matt.mat(Sving.las(json: Fixturer.svingar[0].indata))
        XCTAssertEqual(fo.matt["backen_sway_topp"]!, -6.0, accuracy: 0.5)
        XCTAssertEqual(fo.matt["backen_resa_framat"]!, 14.0, accuracy: 0.5)
        XCTAssertEqual(fo.matt["stans_bredd"]!, 1.2, accuracy: 0.02)
        XCTAssertEqual(fo.cmPerPx, 0.25, accuracy: 0.005)
        let dtl = try Matt.mat(Sving.las(json: Fixturer.svingar[2].indata))
        XCTAssertEqual(dtl.matt["backen_thrust_traff"]!, 3.0, accuracy: 0.5)
        XCTAssertEqual(dtl.matt["brost_bojning_adress"]!, 40.0, accuracy: 1.0)
        XCTAssertGreaterThan(dtl.matt["handbana"]!, 0)              // + = over the top
    }

    func testVansterspelarenRaknasSomHoger() throws {
        let v = try Matt.mat(Sving.las(json: Fixturer.svingar[1].indata))
        XCTAssertEqual(v.hand, .vanster)
        XCTAssertEqual(v.matt["backen_sway_topp"]!, -6.0, accuracy: 0.5)      // − = bort från målet även här
        XCTAssertEqual(v.matt["sidbojning_traff"]!, 25.0, accuracy: 1.5)
        // Den främre handleden är dold: greppregeln ger händerna men inte armbågen. METOD M22
        XCTAssertNil(v.matt["framre_armbage_topp"])
        XCTAssertNil(v.matt["framre_armbage_efter_traff"])
        XCTAssertNotNil(v.matt["hander_fore_adress_traff"])
        // Farterna kräver den egna främre handleden (greppregeln ersätter inte); finishens
        // tid räknas ur den bakre. METOD M35–M37
        XCTAssertNil(v.matt["handfart_max"])
        XCTAssertNil(v.matt["framre_arm_vinkelfart_max"])
        XCTAssertNotNil(v.matt["genomsving_s"])
    }

    /// Tilläggen mot Sportsbox (PLAN S1b) på den påhittade svingen: figurens tal inom bruset.
    func testTillaggenMotSportsbox() throws {
        let fo = try Matt.mat(Sving.las(json: Fixturer.svingar[0].indata))
        XCTAssertEqual(fo.matt["bakre_kna_sway_topp"]!, -4.0, accuracy: 0.5)          // METOD M34
        XCTAssertEqual(fo.matt["framre_kna_sway_traff"]!, 9.0, accuracy: 0.5)
        XCTAssertEqual(fo.matt["handfart_max"]!, 7.2, accuracy: 0.3)                  // METOD M35, m/s
        XCTAssertGreaterThan(fo.matt["handfart_max_fore_traff_ms"]!, 0)              // före träffen
        XCTAssertEqual(fo.matt["framre_arm_vinkelfart_max"]!, 700.0, accuracy: 30.0)  // METOD M37
        XCTAssertEqual(fo.matt["genomsving_s"]!, 0.76, accuracy: 0.05)                // METOD M36
        XCTAssertEqual(fo.matt["hand_lyft_topp"]!, 107.4, accuracy: 0.5)              // METOD M32
        let dtl = try Matt.mat(Sving.las(json: Fixturer.svingar[2].indata))
        XCTAssertEqual(dtl.matt["framre_kna_traff"]!, 12.0, accuracy: 1.5)            // METOD M33
        XCTAssertEqual(dtl.matt["backen_bojning_adress"]!, 10.0, accuracy: 0.5)       // METOD M30
        XCTAssertNil(dtl.matt["handfart_max"])                                        // bara FO
        // Tilläggen bakifrån (PLAN S1c): figurens händer 20 cm från bollen vid toppen, och
        // främre armen 6,1° över axellinjen med axlarna vridna; skymda axlar ger ingen vinkel.
        XCTAssertEqual(dtl.matt["hand_djup_topp"]!, -20.0, accuracy: 0.5)            // METOD M38
        XCTAssertEqual(dtl.matt["framre_arm_plan_topp"]!, 6.1, accuracy: 1.0)         // METOD M39
        let kort = try Matt.mat(Sving.las(json: Fixturer.svingar[5].indata))         // dtl_kort
        XCTAssertNil(kort.matt["framre_arm_plan_topp"])
        XCTAssertNotNil(kort.matt["hand_djup_topp"])
        // dtl_lucka: axellinjen ≈ 15,3 cm, strax över spärren (15 cm): vinkeln finns, som i Python.
        let nara = try Matt.mat(Sving.las(json: Fixturer.svingar[3].indata))
        XCTAssertNotNil(nara.matt["framre_arm_plan_topp"])
        XCTAssertEqual(Matt.armMotAxlar(axelF: Punkt(0, 0), axelB: Punkt(-1, -1), hand: Punkt(-0.5, -1)), 18.43, accuracy: 0.01)
        XCTAssertEqual(Farter.vinkel(181), -179)
        XCTAssertEqual(Farter.vinkel(-180), 180)
        XCTAssertEqual(Farter.rutnat(2.2, 2.5).count, 301)
    }

    /// Luckan över toppfarten ger inget tal, och toppfarten nära träffen hittas. METOD M35
    func testToppfartenVidLuckaOchNaraTraffen() throws {
        let lucka = try Matt.mat(Sving.las(json: Fixturer.svingar[9].indata))
        XCTAssertNil(lucka.matt["handfart_max"])
        XCTAssertNil(lucka.matt["handfart_max_fore_traff_ms"])
        XCTAssertNil(lucka.matt["framre_arm_vinkelfart_max"])
        XCTAssertNotNil(lucka.matt["genomsving_s"])
        let nara = try Matt.mat(Sving.las(json: Fixturer.svingar[10].indata))
        XCTAssertEqual(nara.matt["handfart_max_fore_traff_ms"]!, 15.0, accuracy: 5.0)
        // Toppen i rutnätets ände eller intill en lång lucka saknas; en kort lucka gör inget.
        let tau = Farter.rutnat(0.0, 0.1)
        XCTAssertNil(Farter.maxpunkt(tau, tau.map { 500 + 1000 * $0 }))
        let s = tau.map { 700 - 1e5 * ($0 - 0.0423) * ($0 - 0.0423) }
        XCTAssertNil(Farter.maxpunkt(tau, zip(tau, s).map { $0 > 0.045 && $0 < 0.067 ? .nan : $1 }))
        XCTAssertEqual(Farter.maxpunkt(tau, zip(tau, s).map { $0 > 0.050 && $0 < 0.062 ? .nan : $1 })!.tid,
                       0.0423, accuracy: 1e-9)
    }

    func testRaLuckaLangreAnMaxLuckaSaknas() throws {
        // Höften 0,146 s rå lucka kring toppen, näsan 0,067 s. METOD M3
        let r = try Matt.mat(Sving.las(json: Fixturer.svingar[4].indata))
        XCTAssertNil(r.matt["backen_sway_topp"])
        XCTAssertNotNil(r.matt["huvud_sway_topp"])
        XCTAssertEqual(r.matt["huvud_sway_topp"]!, -3.0, accuracy: 0.5)
    }

    func testKortBaksvingGerIngenStartOchKonfidensensGrans() throws {
        let s = try Sving.las(json: Fixturer.svingar[5].indata)
        XCTAssertTrue(s.led(.hoftF).allSatisfy { $0.hel })            // konfidens 0,3: räknas
        XCTAssertTrue(s.led(.knaB).allSatisfy { !$0.hel })            // 0,29: saknas
        let r = try Matt.mat(s)
        XCTAssertNil(r.faser.start)                                    // baksvingen 0,25 s
        XCTAssertNil(r.matt["tempo"])
        XCTAssertNil(r.matt["baksving_s"])
        XCTAssertNil(r.matt["bakre_kna_adress"])
        XCTAssertEqual(r.matt["backen_thrust_traff"]!, 3.0, accuracy: 0.5)
        XCTAssertEqual(r.faser.adressTill, r.faser.topp - Faser.toppAdressS - 0.10, accuracy: 1e-12)
    }

    /// Bakifrån tas starten ur posen (METOD M40): med dold takeaway finns den och
    /// tempot; skakar posen i adressen, eller räcker den inte, är starten osäker och
    /// tempot saknas. Framifrån är starten händernas (M4).
    func testStartenBakifranUrPosen() throws {
        func sving(_ namn: String) throws -> Sving {
            try Sving.las(json: Fixturer.svingar.first(where: { $0.namn == namn })!.indata)
        }
        let dold = try Matt.mat(sving("dtl_dold"))
        XCTAssertFalse(dold.faser.startOsaker)
        XCTAssertNotNil(dold.matt["tempo"])
        for namn in ["dtl_osaker", "dtl_utan_pose"] {
            let r = try Matt.mat(sving(namn))
            XCTAssertNotNil(r.faser.start, namn)
            XCTAssertTrue(r.faser.startOsaker, namn)
            XCTAssertNil(r.matt["tempo"], namn)
            XCTAssertNil(r.matt["baksving_s"], namn)
        }
        // Utan posen räcker inte händerna: deras start (M4) saknas med den dolda takeawayn.
        let s = try sving("dtl_dold")
        let b = Faser.greppRegel(s.leder).map { Faser.jamna(s.t, $0) }
        let g = zip(b[Led.handledF.rawValue], b[Led.handledB.rawValue]).map { Punkt.mitt($0, $1) }
        XCTAssertNil(try Faser.hitta(s.t, g, tKlick: s.tKlick).start)
        XCTAssertFalse(try Matt.mat(sving("fo")).faser.startOsaker)
    }

    func testLangLuckaTarBortMattenIFasen() throws {
        let r = try Matt.mat(Sving.las(json: Fixturer.svingar[3].indata))
        XCTAssertNil(r.matt["backen_thrust_topp"])
        XCTAssertNil(r.matt["huvud_lyft_finish"])
        XCTAssertNotNil(r.matt["backen_thrust_traff"])
    }

    func testNamnenPerVy() {
        XCTAssertEqual(Matt.namnFO.count, 54)
        XCTAssertEqual(Matt.namnDTL.count, 43)
        XCTAssertEqual(Set(Matt.namnFO).count, Matt.namnFO.count)
        XCTAssertEqual(Set(Matt.namnDTL).count, Matt.namnDTL.count)
        XCTAssertTrue(Matt.namnDTL.contains("backen_bojning_traff"))       // METOD M30
        XCTAssertTrue(Matt.namnFO.contains("framre_arm_vinkelfart_max"))   // METOD M37
        XCTAssertTrue(Matt.namnDTL.contains("hand_djup_topp"))             // METOD M38
        XCTAssertTrue(Matt.namnDTL.contains("framre_arm_plan_topp"))       // METOD M39
        XCTAssertTrue(Matt.namnDTL.contains("handbana"))
        XCTAssertTrue(Matt.namnFO.contains("backen_resa_framat"))
    }

    func testVinklarna() {
        XCTAssertEqual(Matt.bojning(Punkt(0, -1), Punkt(0, 0), Punkt(0, 1)), 0, accuracy: 1e-12)
        XCTAssertEqual(Matt.bojning(Punkt(0, -1), Punkt(0, 0), Punkt(1, 0)), 90, accuracy: 1e-12)
        XCTAssertTrue(Matt.bojning(Punkt(0, 0), Punkt(0, 0), Punkt(1, 0)).isNaN)
        XCTAssertEqual(Matt.vinkelFranLod(Punkt(0, 0), Punkt(1, -1)), 45, accuracy: 1e-12)     // y nedåt
        XCTAssertEqual(Matt.linjensLutning(fram: Punkt(1, -1), bak: Punkt(0, 0)), 45, accuracy: 1e-12)
    }

    func testPositionernaSaknasNarArmenAldrigBlirVagrat() throws {
        // fo_kort_arm: främre armen under vågrätt hela baksvingen. METOD M28
        let r = try Matt.mat(Sving.las(json: Fixturer.svingar[6].indata))
        XCTAssertNil(r.positioner.p3)
        XCTAssertNil(r.positioner.p5)
        XCTAssertNotNil(r.positioner.p9)
        XCTAssertNil(r.matt["backen_sway_p3"])
        XCTAssertNil(r.matt["backen_resa_p5"])
        XCTAssertNotNil(r.matt["huvud_backen_finish"])
        // fo_vanster: den egna främre handleden är dold, så armen syns inte.
        let v = try Matt.mat(Sving.las(json: Fixturer.svingar[1].indata))
        XCTAssertNil(v.positioner.p3)
        XCTAssertNotNil(v.positioner.p9)
    }

    func testPositionernaIOrdning() throws {
        for i in [0, 2, 8] {
            let p = try Matt.mat(Sving.las(json: Fixturer.svingar[i].indata)).positioner
            let tider = Positioner.namn.compactMap { p.tid($0) }
            XCTAssertEqual(tider.count, 7, Fixturer.svingar[i].namn)
            XCTAssertEqual(tider, tider.sorted(), Fixturer.svingar[i].namn)
        }
        let h = try Matt.mat(Sving.las(json: Fixturer.svingar[2].indata)).positioner
        let v = try Matt.mat(Sving.las(json: Fixturer.svingar[8].indata)).positioner
        XCTAssertEqual(h.p3!, v.p3!, accuracy: 1 / 240.0)       // vänsterspelaren, en annan påhittad sving
    }

    func testPassagerna() {
        let t = [0.0, 0.01, 0.02, 0.03, 0.04, 0.2, 0.21]
        let h = [-2.0, -1.0, 1.0, 0.0, -1.0, 1.0, 2.0]
        let p = Positioner.passager(t, h, fran: 0, till: 0.1)
        XCTAssertEqual(p.map { $0.tid }, [0.015, 0.03])                 // 0 räknas som vågrät
        XCTAssertEqual(p.map { $0.uppat }, [true, false])
        XCTAssertEqual(Positioner.passager(t, h, fran: 0, till: 0.3).count, 2)   // luckan 0,16 s
        var b = h
        b[2] = .nan
        XCTAssertEqual(Positioner.passager(t, b, fran: 0, till: 0.1).map { $0.tid }, [0.03, 0.03])
        let v = Positioner.armensHojd(axel: [Punkt(0, 0), Punkt(0, 0), Punkt(0, 0)],
                                      handled: [Punkt(-10, -4), Punkt(10, 10), Punkt(.nan, 1)])
        XCTAssertEqual(Array(v.prefix(2)), [4, -10])
        XCTAssertTrue(v[2].isNaN)
    }

    /// Samma fall som test_positioner.py (Passagerna). METOD M28
    static let t2 = (0..<260).map { (Double($0) / 100 * 1e6).rounded() / 1e6 }
    static func faser(topp: Double = 1.0) -> Fastider {
        Fastider(start: 0.3, topp: topp, traff: 1.5, adressFran: -0.1, adressTill: 0.2, finishFran: 2.5, finishTill: 2.7,
                 startOsaker: false)
    }

    static func serie(_ f: (Double) -> Double) -> [Double] { t2.map(f) }

    func testIngenPassageOverEnLucka() {
        let t = Self.t2
        let h = Self.serie { $0 > 0.5 && $0 < 1.3 ? 5 : -5 }
        let minus = h.map { -$0 }
        let p = Positioner.hitta(t, Self.faser(), framre: h, bakre: minus)
        XCTAssertEqual(p.p3!, 0.505, accuracy: 1e-9)
        XCTAssertEqual(p.p5!, 1.295, accuracy: 1e-9)
        var g = h
        for k in t.indices {
            if t[k] > 0.7 && t[k] < 0.75 { g[k] = -5 }
            if t[k] >= 0.75 && t[k] < 0.9 { g[k] = .nan }
        }
        XCTAssertNil(Positioner.hitta(t, Self.faser(), framre: g, bakre: minus).p3)
        g = h
        for k in t.indices {
            if t[k] > 1.02 && t[k] < 1.15 { g[k] = .nan }
            if t[k] >= 1.15 && t[k] < 1.2 { g[k] = -5 }
            if t[k] >= 1.2 && t[k] < 1.25 { g[k] = .nan }
        }
        XCTAssertNil(Positioner.hitta(t, Self.faser(), framre: g, bakre: minus).p5)
        var b = Self.serie { $0 > 1.8 ? 5 : -5 }
        XCTAssertEqual(Positioner.hitta(t, Self.faser(), framre: h, bakre: b).p9!, 1.805, accuracy: 1e-9)
        b = Self.serie { $0 > 1.9 ? 5 : -5 }
        for k in t.indices {
            if t[k] > 1.55 && t[k] < 1.7 { b[k] = .nan }
            if t[k] >= 1.7 && t[k] < 1.72 { b[k] = 5 }
            if t[k] >= 1.72 && t[k] < 1.85 { b[k] = .nan }
        }
        XCTAssertNil(Positioner.hitta(t, Self.faser(), framre: h, bakre: b).p9)
    }

    func testRutparetOverToppen() {
        let t = Self.t2
        var h = Self.serie { $0 > 1.0 && $0 < 1.3 ? 5 : -5 }
        var p = Positioner.hitta(t, Self.faser(topp: 1.004), framre: h, bakre: h.map { -$0 })
        XCTAssertEqual(p.p3!, 1.005, accuracy: 1e-9)                    // efter toppen, inom rutan
        XCTAssertEqual(p.p5!, 1.295, accuracy: 1e-9)
        h = Self.serie { $0 > 0.5 && $0 < 1.0 ? 5 : -5 }
        p = Positioner.hitta(t, Self.faser(topp: 0.996), framre: h, bakre: h.map { -$0 })
        XCTAssertEqual(p.p3!, 0.505, accuracy: 1e-9)
        XCTAssertEqual(p.p5!, 0.995, accuracy: 1e-9)                    // före toppen, inom rutan
    }

    func testLuckanIArmenKringGransen() throws {
        // fo_lucka_arm: rå lucka 0,096 s kring P3 interpoleras, 0,104 s kring P5 inte. METOD M3, M28
        let r = try Matt.mat(Sving.las(json: Fixturer.svingar[7].indata))
        XCTAssertNotNil(r.positioner.p3)
        XCTAssertNil(r.positioner.p5)
        XCTAssertNil(r.matt["backen_resa_p5"])
        XCTAssertNotNil(r.matt["backen_sway_p3"])
    }
}
