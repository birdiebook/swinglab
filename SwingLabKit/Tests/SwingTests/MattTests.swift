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
                                                       "fo_kort_arm", "dtl_vanster"])
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
        // Kvittot: testet jämförde verkligen måtten (38 + 33 + 28 + 23 + 32 + 22 + 35 + 28 = 239)
        // och positionerna (8 × 7 − 4 saknade = 52).
        XCTAssertEqual(jamforda, 239)
        XCTAssertEqual(positioner, 52)
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

    func testLangLuckaTarBortMattenIFasen() throws {
        let r = try Matt.mat(Sving.las(json: Fixturer.svingar[3].indata))
        XCTAssertNil(r.matt["backen_thrust_topp"])
        XCTAssertNil(r.matt["huvud_lyft_finish"])
        XCTAssertNotNil(r.matt["backen_thrust_traff"])
    }

    func testNamnenPerVy() {
        XCTAssertEqual(Matt.namnFO.count, 38)
        XCTAssertEqual(Matt.namnDTL.count, 28)
        XCTAssertEqual(Set(Matt.namnFO).count, Matt.namnFO.count)
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
        for i in [0, 2, 7] {
            let p = try Matt.mat(Sving.las(json: Fixturer.svingar[i].indata)).positioner
            let tider = Positioner.namn.compactMap { p.tid($0) }
            XCTAssertEqual(tider.count, 7, Fixturer.svingar[i].namn)
            XCTAssertEqual(tider, tider.sorted(), Fixturer.svingar[i].namn)
        }
        let h = try Matt.mat(Sving.las(json: Fixturer.svingar[2].indata)).positioner
        let v = try Matt.mat(Sving.las(json: Fixturer.svingar[7].indata)).positioner
        XCTAssertEqual(h.p3!, v.p3!, accuracy: 1 / 240.0)       // vänsterspelaren, en annan påhittad sving
    }

    func testPassagerna() {
        let t = [0.0, 0.01, 0.02, 0.03, 0.04, 0.2, 0.21]
        let a = [-2.0, -1.0, 1.0, 0.0, -1.0, 1.0, 2.0]
        XCTAssertEqual(Positioner.passager(t, a, fran: 0, till: 0.1, uppat: true), [0.015])
        XCTAssertEqual(Positioner.passager(t, a, fran: 0, till: 0.1, uppat: false), [0.03])   // 0 räknas som vågrät
        XCTAssertEqual(Positioner.passager(t, a, fran: 0, till: 0.3, uppat: true), [0.015])   // luckan 0,16 s
        var b = a
        b[2] = .nan
        XCTAssertEqual(Positioner.passager(t, b, fran: 0, till: 0.1, uppat: true), [0.03])
        XCTAssertEqual(Positioner.passager(t, b, fran: 0, till: 0.1, uppat: false), [0.03])
        let v = Positioner.armensVinkel(axel: [Punkt(0, 0), Punkt(0, 0), Punkt(0, 0)],
                                        handled: [Punkt(-10, -10), Punkt(10, 10), .saknad])
        XCTAssertEqual(v[0], 45, accuracy: 1e-12)
        XCTAssertEqual(v[1], -45, accuracy: 1e-12)
        XCTAssertTrue(v[2].isNaN)
    }
}
