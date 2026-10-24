import Capture
import Foundation
import Swing
import XCTest
@testable import TreD

/// S6d: figuren på telefonen (BESLUT B72, B73, METOD MK10, MK11). Lederna och kamerorna ska
/// vara Pythons (tools/pc/tre_d_figur.py skriver tools/tests/fixturer/tre_d/figur.json, BESLUT
/// B12), och vyns geometri ska visa spelaren från rätt håll. PÅHITTADE pass (CLAUDE.md, Dataregeln).
extension TreDTests {
    /// Telefonens väg (båda paketen som TreDIndata) med figuren, för ett fixturpass.
    func figur(_ pass: String) throws -> (ut: TreDUt, figur: TreDFigurer) {
        let bas = try Fixtur.indata(pass)["paket"] as! [String: Any]
        let l = try Fixtur.leder(pass)
        var indata: [String: TreDIndata] = [:]
        for vy in ["dtl", "fo"] {
            let p = bas[vy] as! [String: Any]
            indata[vy] = TreDIndata(manifest: Fixtur.data(p["manifest"])!, lederna: l[vy]!,
                                    par: Fixtur.data(p["par"]), enhet: Fixtur.data(p["enhet"]))
        }
        let langd = try XCTUnwrap(Fixtur.tal(try Fixtur.indata(pass)["langd_m"]))
        let start = Date()
        let r = TreDTelefon.rakna(indata["fo"]!, indata["dtl"]!, langdM: langd, figur: true)
        print("TRED-FIGUR \(pass) \(Date().timeIntervalSince(start)) s med figuren")
        return (r.ut, try XCTUnwrap(r.figur, pass))
    }

    func testFigurenSomPython() throws {
        let fx = try Fixtur.las("figur")
        for (pass, v) in fx["pass"] as! [String: Any] {
            let py = v as! [String: Any]
            let (_, f) = try figur(pass)
            let a = Avvikelser()
            let ix = f.index
            XCTAssertEqual(ix.hand.rawValue, py["hand"] as? String, pass)
            XCTAssertEqual(ix.hoppat, py["hoppat"] as? String, pass)
            let pu = py["uppstallningar"] as! [[String: Any]]
            XCTAssertEqual(ix.uppstallningar.count, pu.count, pass)
            for (u, q) in zip(ix.uppstallningar, pu) {
                XCTAssertEqual(u.serie, (q["serie"] as! [String: Any]).mapValues { Fixtur.heltal($0) }, pass)
                XCTAssertEqual(u.slag, Fixtur.heltal(q["slag"]), pass)
                XCTAssertEqual(u.hoppat, q["hoppat"] as? String, pass)
                XCTAssertEqual(u.sampsonPx, Fixtur.tal(q["sampson_px"]), pass)
                XCTAssertEqual(u.vinkel, Fixtur.tal(q["vinkel"]), pass)
                XCTAssertEqual(u.vinkelOk, q["vinkel_ok"] as? Bool, pass)
                XCTAssertEqual(u.skala, q["skala"] as? String, pass)
                a.notera("skala", (u.skalaM ?? .nan) / (Fixtur.tal(q["skala_m"]) ?? .nan), 1)
                a.notera("golv", u.golv ?? .nan, Fixtur.tal(q["golv"]) ?? .nan)
                let pk = q["kameror"] as? [String: Any]
                XCTAssertEqual(u.kameror == nil, pk == nil, pass)
                for (vy, k) in pk ?? [:] {
                    let k = k as! [String: Any], s = try XCTUnwrap(u.kameror?[vy])
                    for (x, y) in zip(s.c, Fixtur.lista(k["C"])) { a.notera("kamerornas C", x, y) }
                    for (x, y) in zip(s.r, Fixtur.lista(k["R"])) { a.notera("kamerornas R", x, y) }
                    for (x, y) in zip(s.k, Fixtur.lista(k["K"])) { a.notera("kamerornas K", x, y) }
                    XCTAssertEqual(s.w, Fixtur.heltal(k["w"]))
                    XCTAssertEqual(s.h, Fixtur.heltal(k["h"]))
                }
            }
            let ps = py["slag"] as! [[String: Any]]
            XCTAssertEqual(f.figurer.count, ps.count, pass)
            XCTAssertEqual(ix.slag.map(\.fil), f.figurer.map(\.filnamn))
            for (s, q) in zip(f.figurer, ps) {
                XCTAssertEqual(s.dtl, q["dtl"] as? String)
                XCTAssertEqual(s.fo, q["fo"] as? String)
                XCTAssertEqual(s.uppstallning, Fixtur.heltal(q["uppstallning"]))
                XCTAssertEqual(s.n, Fixtur.heltal(q["n"]))
                a.notera("synken", s.synkS, Fixtur.tal(q["synk_s"])!)
                a.notera("tiden", s.t0, Fixtur.tal(q["t0"])!)
                a.notera("tiden", s.tSista, Fixtur.tal(q["t_sista"])!)
                let pp = (q["positioner"] as! [String: Any]).mapValues { Fixtur.tal($0)! }
                XCTAssertEqual(Set(s.positioner.keys), Set(pp.keys), "\(pass) \(s.dtl)")
                for (k, v) in pp { a.notera("positionerna", s.positioner[k] ?? .nan, v) }
                for (i, rad) in zip(q["index"] as! [Any], q["P"] as! [Any]) {
                    let i = Fixtur.heltal(i)
                    for (x, y) in zip(s.p[(i * 39)..<(i * 39 + 39)], Fixtur.lista(rad)) { a.notera("lederna", x, y) }
                }
                let fin = s.p.filter(\.isFinite)
                XCTAssertEqual(fin.count, Fixtur.heltal(q["antal"]), "\(pass) \(s.dtl)")
                a.notera("ledernas summa (relativt)", fin.reduce(0, +) / Fixtur.tal(q["summa"])!, 1)
            }
            a.skriv("\(pass)/figuren")
            for (namn, d) in a.storst {
                // Samma tolerans som kalibreringen och synken (METOD M50), i meter och sekunder.
                XCTAssertLessThanOrEqual(d, 1e-6, "\(pass) \(namn)")
            }
        }
    }

    func testFigurensFilTurOchRetur() throws {
        let (_, f) = try figur("bra_brus_vanster")
        let s = try XCTUnwrap(f.figurer.first)
        let d = try s.data()
        let l = try TreDFigur.las(d)
        XCTAssertEqual(l.n, s.n)
        XCTAssertEqual(l.positioner, s.positioner)
        XCTAssertEqual(l.t0, s.t0)
        for (x, y) in zip(l.p, s.p) {
            XCTAssertEqual(x.isNaN, y.isNaN)
            if x.isFinite { XCTAssertLessThanOrEqual(abs(x - y), 0.0005 + 1e-12) }
        }
        print("TRED-FIGUR fil \(d.count) byte för \(s.n) rutor (\(d.count / max(1, s.n)) per ruta)")
        // Ett tal utanför ±32,767 m blir saknat, aldrig ett annat tal.
        var stor = s
        stor.p[0] = 40
        XCTAssertTrue(try TreDFigur.las(try stor.data()).p[0].isNaN)
        XCTAssertThrowsError(try TreDFigur.las(Data("{}".utf8)))
        var index = f.index
        index.pass = "20261103-180000"
        index.kallor = ["dtl": "a", "fo": "b"]
        XCTAssertEqual(try TreDFigurIndex.las(try index.data()), index)
    }

    func testOverSparrenKamerornaMenIngenFigur() throws {
        let (ut, f) = try figur("sparren")
        XCTAssertEqual(ut, .hoppat("kalibreringen: Sampson-felet är över spärren"))
        XCTAssertEqual(f.figurer, [])
        let u = try XCTUnwrap(f.index.uppstallningar.first)
        XCTAssertTrue(u.overSparren)
        let r = try XCTUnwrap(TreDRiktning.ur(nil, uppstallning: u, hand: f.index.hand))
        XCTAssertEqual(r.golv, u.golv)
        // Kamerorna syns i varje färdig vinkel.
        let kameror = u.kameror!.values.map(\.c)
        for v in TreDVinkel.allCases {
            let pr = TreDProjektion(TreDBetraktare.vinkel(v, r, kameror: kameror), bredd: 390, hojd: 440)
            for c in kameror {
                let q = try XCTUnwrap(pr.punkt(c), "\(v)")
                XCTAssertTrue((0...390).contains(q.p.x) && (0...440).contains(q.p.y), "\(v) \(q.p)")
            }
        }
    }

    func testVinklarnaVisarSpelarenFranRattHall() throws {
        let (_, f) = try figur("utan_brus")
        let fig = try XCTUnwrap(f.figurer.first)
        let u = f.index.uppstallningar[fig.uppstallning]
        let r = try XCTUnwrap(TreDRiktning.ur(fig, uppstallning: u, hand: .hoger))
        XCTAssertEqual(LA.norm3(r.mal), 1, accuracy: 1e-9)
        XCTAssertEqual(r.mal[2], 0)
        XCTAssertEqual(LA.dot3(r.mal, r.fram), 0, accuracy: 1e-9)
        // FO-kameran står på spelarens framsida, DTL-kameran bakom honom längs mållinjen (MK8).
        let fo = u.kameror!["fo"]!.c, dtl = u.kameror!["dtl"]!.c
        let vfo = [fo[0] - r.stans[0], fo[1] - r.stans[1], 0.0], vdtl = [dtl[0] - r.stans[0], dtl[1] - r.stans[1], 0.0]
        XCTAssertGreaterThan(LA.dot3(vfo, r.fram) / LA.norm3(vfo), 0.95)
        XCTAssertLessThan(LA.dot3(vdtl, r.mal) / LA.norm3(vdtl), -0.95)
        // Marken under fötterna.
        let p1 = try XCTUnwrap(fig.positionsRutor().first { $0.name == "P1" }?.index)
        let vfot = try XCTUnwrap(fig.led(p1, 11)), hfot = try XCTUnwrap(fig.led(p1, 12))
        XCTAssertEqual(vfot[2] - r.golv, TreDFigurer.fotledAndel * 1.80, accuracy: 0.03)

        // Face on och Top: målet (högerspelarens vänstra fot) till höger; Down the line: den
        // vänstra foten längre bort än den högra.
        for v in TreDVinkel.allCases {
            let b = TreDBetraktare.vinkel(v, r)
            let pr = TreDProjektion(b, bredd: 390, hojd: 440)
            let a = try XCTUnwrap(pr.punkt(vfot)), h = try XCTUnwrap(pr.punkt(hfot))
            if v == .faceOn {
                // Vyn är passad: spelaren i adressen är minst en tredjedel av ytans höjd.
                let n = try XCTUnwrap(pr.punkt(fig.led(p1, 0)!))
                XCTAssertGreaterThan(a.p.y - n.p.y, 440 / 3, "figuren för liten")
            }
            switch v {
            case .faceOn, .top: XCTAssertGreaterThan(a.p.x, h.p.x + 10, "\(v)")
            case .dtl: XCTAssertGreaterThan(a.djup, h.djup + 0.2, "\(v)")
            }
            // Hela figuren ryms i varje ruta.
            for i in stride(from: 0, to: fig.n, by: 20) {
                for j in 0..<13 {
                    guard let p = fig.led(i, j), let q = pr.punkt(p) else { continue }
                    XCTAssertTrue((0...390).contains(q.p.x) && (0...440).contains(q.p.y), "\(v) ruta \(i) led \(j)")
                }
            }
            // Mittpunkten i skärmens mitt.
            let m = try XCTUnwrap(pr.punkt(b.mal))
            XCTAssertEqual(m.p.x, 195, accuracy: 1e-6)
            XCTAssertEqual(m.p.y, 220, accuracy: 1e-6)
        }
        // Top ses uppifrån: huvudet närmare än fötterna.
        let top = TreDProjektion(TreDBetraktare.vinkel(.top, r), bredd: 390, hojd: 440)
        XCTAssertLessThan(try XCTUnwrap(top.punkt(fig.led(p1, 0)!)).djup, try XCTUnwrap(top.punkt(vfot)).djup)

        // P7 är träffen (figurens tid 0), P4 före den.
        let pos = Dictionary(uniqueKeysWithValues: fig.positionsRutor().map { ($0.name, $0.index) })
        XCTAssertEqual(pos["P7"]!, fig.ruta(0))
        XCTAssertLessThan(pos["P4"]!!, pos["P7"]!!)
        XCTAssertNil(pos["P2"]!)                               // klubban (S7)
    }

    func testFingretOchNypningenOchLinjenBakomOgat() {
        let b = TreDBetraktare(mal: [0, 0, 1], azimut: 0, elevation: 0, avstand: 4)
        XCTAssertEqual(b.oga, [4, 0, 1])
        let v = b.vriden(dx: 100, dy: 10_000)
        XCTAssertEqual(v.azimut, -0.8, accuracy: 1e-12)
        XCTAssertEqual(v.elevation, TreDBetraktare.elevationGrans.1)
        XCTAssertEqual(b.zoomad(2, fran: 4).avstand, 2)
        XCTAssertEqual(b.zoomad(1000, fran: 4).avstand, TreDBetraktare.avstandGrans.0)
        XCTAssertEqual(b.zoomad(0, fran: 4), b)
        let pr = TreDProjektion(b, bredd: 400, hojd: 400)
        XCTAssertNil(pr.punkt([5, 0, 1]))                        // bakom ögat
        XCTAssertNil(pr.punkt([.nan, 0, 1]))
        // En linje som går bakom ögat klipps: ändpunkten framför står kvar.
        let l = pr.linje([0, 0, 1], [8, 0, 1])
        XCTAssertEqual(l?.0, Punkt(200, 200))
        XCTAssertNil(pr.linje([5, 0, 1], [6, 0, 1]))
        // Höger på skärmen är +y när ögat står på +x och ser mot origo.
        XCTAssertGreaterThan(pr.punkt([0, 1, 1])!.p.x, 200)
        XCTAssertLessThan(pr.punkt([0, 0, 2])!.p.y, 200)
    }

    func testSparenI3DMedS4fsDelning() {
        // Tre rutor: båda handlederna, bara den vänstra, båda igen; huvudet saknas i mitten.
        let nan = Double.nan
        var p = [Double](repeating: nan, count: 3 * 39)
        func satt(_ i: Int, _ j: Int, _ v: [Double]) { for a in 0..<3 { p[(i * 13 + j) * 3 + a] = v[a] } }
        satt(0, 5, [0, 0, 1]); satt(0, 6, [0, 0.2, 1])
        satt(1, 5, [0.1, 0, 1.1])
        satt(2, 5, [0.2, 0, 1.2]); satt(2, 6, [0.2, 0.2, 1.2])
        satt(0, 0, [0, 0, 1.6]); satt(2, 0, [0, 0, 1.6])
        let f = TreDFigur(dtl: "s01", fo: "s01", uppstallning: 0, synkS: 0, t0: -0.01, steg: 0.005, n: 3, p: p,
                          positioner: [:])
        let s = TreDSpar.spar(f, val: [.hands, .head, .club])
        XCTAssertEqual(s.map(\.serie.id), ["hands", "head"])
        let h = s[0]
        XCTAssertEqual(h.punkt(0), [0, 0.1, 1])
        XCTAssertEqual(h.punkt(1), [0.1, 0, 1.1])
        XCTAssertEqual(h.serie.brott, [1, 2])                    // greppregeln byter handled
        XCTAssertEqual(h.serie.delar().count, 0)                 // tre delar om en punkt: ingen linje
        XCTAssertEqual(s[1].serie.delar().count, 0)              // avbrott där huvudet saknas
        // Delningen spelat/kvar är S4f:s: index i serien pekar ut punkterna i 3D.
        var f2 = f
        f2.p = p
        for i in 0..<3 { for a in 0..<3 { f2.p[(i * 13 + 6) * 3 + a] = [0, 0.2, 1 + 0.1 * Double(i)][a] } }
        f2.p[(1 * 13 + 6) * 3 + 0] = 0.1
        let h2 = TreDSpar.spar(f2, val: [.hands])[0]
        let delar = h2.serie.delar(nu: -0.005)
        XCTAssertEqual(delar.map(\.spelad), [true, false])
        XCTAssertEqual(delar.map(\.start), [0, 1])
        XCTAssertEqual(delar[1].slut, 2)
    }
}
