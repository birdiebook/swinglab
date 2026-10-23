import Capture
import Foundation
import Swing
import XCTest
@testable import TreD

/// S6c-1: 3D på telefonen mot Pythons tal (BESLUT B12, B48) och mot sanningen (METOD MK8),
/// på PÅHITTADE tvåpaketspass (CLAUDE.md, Dataregeln). Fixturerna skrivs av
/// tools/pc/generera_tre_d.py och står i tools/tests/fixturer/tre_d/. Toleranserna: METOD M50.
enum Fixtur {
    static let rot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    static func las(_ namn: String) throws -> [String: Any] {
        let url = rot.appendingPathComponent("tools/tests/fixturer/tre_d/\(namn).json")
        return try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    }

    static func tal(_ x: Any?) -> Double? {
        TreDPaket.tal(x)
    }

    static func heltal(_ x: Any?) -> Int {
        Int(TreDPaket.tal(x)!)
    }

    static func lista(_ x: Any?) -> [Double] {
        (x as! [Any]).map { tal($0) ?? .nan }
    }

    /// Kompakta leder (int32-tider i 1e-4 s, int16-leder i 0,1 px och 0,001) → JointSeries.
    static func leder(_ k: [String: Any]) -> JointSeries {
        let t = Data(base64Encoded: k["t"] as! String)!
        let j = Data(base64Encoded: k["j"] as! String)!
        let n = t.count / 4
        let tider: [Int32] = t.withUnsafeBytes { raw in
            (0..<n).map { Int32(littleEndian: raw.loadUnaligned(fromByteOffset: $0 * 4, as: Int32.self)) }
        }
        let tal: [Int16] = j.withUnsafeBytes { raw in
            (0..<(j.count / 2)).map { Int16(littleEndian: raw.loadUnaligned(fromByteOffset: $0 * 2, as: Int16.self)) }
        }
        var frames: [PoseFrame] = []
        for i in 0..<n {
            var leder: [PoseJoint?] = []
            for m in 0..<13 {
                let b = (i * 13 + m) * 3
                let c = tal[b + 2]
                leder.append(c == 0 ? nil : PoseJoint(x: Double(tal[b]) / 10, y: Double(tal[b + 1]) / 10,
                                                      c: Double(c) / 1000))
            }
            frames.append(PoseFrame(t: Double(tider[i]) / 1e4, pts: 0, joints: leder, confidence: 0.9))
        }
        return JointSeries(source: "pahittad-3d-r1", width: heltal(k["width"]), height: heltal(k["height"]),
                           frames: frames)
    }

    /// Variantens två paket (dtl, fo), lästa med TreDPaket.las.
    static func paket(_ fx: [String: Any], _ variant: String, medLeder: Bool = true) throws -> (TreDPaket, TreDPaket) {
        let bas = fx["paket"] as! [String: Any]
        let andra = ((fx["varianter"] as! [String: Any])[variant] as! [String: Any])["andra"] as! [String: Any]
        var ut: [TreDPaket] = []
        for vy in ["dtl", "fo"] {
            var p = bas[vy] as! [String: Any]
            for (k, v) in (andra[vy] as? [String: Any]) ?? [:] { p[k] = v }
            var lederna: [String: JointSeries] = [:]
            if medLeder, let l = p["leder"] as? [String: Any] {
                for (id, k) in l { lederna[id] = leder(k as! [String: Any]) }
            }
            let text = { (x: Any?) -> Data? in (x as? String).map { Data($0.utf8) } }
            ut.append(try TreDPaket.las(manifest: p["manifest"] as! [String: Any], lederna: lederna,
                                        par: text(p["par"]), enhet: text(p["enhet"])))
        }
        return (ut[0], ut[1])
    }

    /// 2D-fasernas start och topp per slag ("dtl/s01").
    static func faser(_ fx: [String: Any]) -> [String: Faser2D] {
        var ut: [String: Faser2D] = [:]
        for r in fx["rader"] as! [[String: Any]] {
            ut["\(r["vy"] as! String)/\(r["id"] as! String)"] = Faser2D(start: tal(r["start"]), topp: tal(r["topp"]))
        }
        return ut
    }

    static func python(_ fx: [String: Any], _ variant: String) -> [String: Any] {
        ((fx["varianter"] as! [String: Any])[variant] as! [String: Any])["python"] as! [String: Any]
    }

    static func inre(_ fx: [String: Any], _ variant: String) -> [Any] {
        ((fx["varianter"] as! [String: Any])[variant] as! [String: Any])["inre"] as! [Any]
    }
}

/// Största avvikelsen mot Python per storhet, skriven i loggen ("TRED-AVVIKELSE").
final class Avvikelser {
    var storst: [String: Double] = [:]

    func notera(_ namn: String, _ a: Double, _ b: Double) {
        let d = (a.isNaN && b.isNaN) ? 0 : abs(a - b)
        storst[namn] = max(storst[namn] ?? 0, d.isNaN ? .infinity : d)
    }

    func skriv(_ pass: String) {
        for (k, v) in storst.sorted(by: { $0.key < $1.key }) { print("TRED-AVVIKELSE \(pass) \(k) \(v)") }
    }
}

final class TreDTests: XCTestCase {
    /// Toleranserna mot Python, METOD M50.
    static let tolKamera = 1e-8        // R, t, uppåt (enhetslösa); uppmätt högst 4e-11
    static let tolSynk = 1e-9          // s; uppmätt högst 1e-11
    static let tolRep = 1e-7           // px; uppmätt högst 5e-10
    static let tolMatt = 1e-6          // grader, per slag och passets sammanfattning; uppmätt högst 4e-9

    /// Jämför Swifts resultat med Pythons för en variant och svarar avvikelserna.
    func jamfor(_ r: TreDResultat, _ py: [String: Any], _ inre: [Any], _ namn: String, _ a: Avvikelser) {
        XCTAssertEqual(r.lage, py["lage"] as? String, namn)
        // Parningen
        let pp = py["parning"] as! [String: Any]
        XCTAssertEqual(r.parning.kalla, pp["kalla"] as? String, namn)
        XCTAssertEqual(r.parning.par, Fixtur.heltal(pp["par"]), namn)
        XCTAssertEqual(r.parning.oparade["dtl"], Fixtur.heltal((pp["oparade"] as! [String: Any])["dtl"]), namn)
        XCTAssertEqual(r.parning.oparade["fo"], Fixtur.heltal((pp["oparade"] as! [String: Any])["fo"]), namn)
        XCTAssertEqual(r.parning.parJsonFel, pp["par_json_fel"] as? String, namn)
        let ps = pp["serier"] as! [[String: Any]]
        XCTAssertEqual(r.parning.serier.count, ps.count, namn)
        for (s, q) in zip(r.parning.serier, ps) {
            XCTAssertEqual(s.dtl, Fixtur.heltal(q["dtl"]))
            XCTAssertEqual(s.fo, Fixtur.heltal(q["fo"]))
            XCTAssertEqual(s.kalla, q["kalla"] as? String)
            XCTAssertEqual(s.par, Fixtur.heltal(q["par"]))
        }
        // Kalibreringen
        let pk = py["kalibrering"] as! [[String: Any]]
        XCTAssertEqual(r.kalibrering.count, pk.count, namn)
        for (k, q) in zip(r.kalibrering, pk) {
            XCTAssertEqual(k.slag, Fixtur.heltal(q["slag"]), namn)
            XCTAssertEqual(k.fKalla, q["f_kalla"] as? [String: String], namn)
            XCTAssertEqual(k.hoppat, q["hoppat"] as? String, namn)
            XCTAssertEqual(k.lodlinje, q["lodlinje"] as? String, namn)
            XCTAssertEqual(k.lodlinjeFel, q["lodlinje_fel"] as? [String], namn)
            XCTAssertEqual(k.vinkelOk, q["vinkel_ok"] as? Bool, namn)
            for (sw, nyckel, steg) in [(k.sampsonPx, "sampson_px", 0.01), (k.vinkelMellanKamerorna, "vinkel_mellan_kamerorna", 0.1),
                                       (k.lodlinjeMotVagrata, "lodlinje_mot_vagrata", 0.1)] {
                let p = Fixtur.tal(q[nyckel])
                XCTAssertEqual(sw == nil, p == nil, "\(namn) \(nyckel)")
                if let sw, let p {
                    a.notera(nyckel, sw, p)
                    XCTAssertEqual(sw, p, accuracy: steg + 1e-9, "\(namn) \(nyckel)")
                }
            }
        }
        XCTAssertEqual(r.osaker, py["osaker"] as? [String], namn)
        // De oavrundade talen per uppställning
        XCTAssertEqual(r.inre.count, inre.count, namn)
        for (i, q) in zip(r.inre, inre) {
            guard let q = q as? [String: Any] else {
                XCTAssertNil(i, namn)
                continue
            }
            guard let i else {
                XCTFail("\(namn): Swift saknar kalibreringen")
                continue
            }
            let R = (q["R"] as! [[Any]]).flatMap { $0.map { Fixtur.tal($0)! } }
            for (x, y) in zip(i.r, R) { a.notera("R", x, y) }
            for (x, y) in zip(i.t, Fixtur.lista(q["t"])) { a.notera("t", x, y) }
            for (x, y) in zip(i.upp, Fixtur.lista(q["upp"])) { a.notera("upp", x, y) }
            for (x, y) in zip(i.forsk, Fixtur.lista(q["forsk"])) { a.notera("synk_s", x, y) }
            for (x, y) in zip(i.aterprojektion, (q["aterprojektion"] as! [Any]).map(Fixtur.tal)) {
                a.notera("aterprojektion_px", x ?? .nan, y ?? .nan)
            }
        }
        // Slagen
        let pslag = py["slag"] as! [[String: Any]]
        XCTAssertEqual(r.slag.count, pslag.count, namn)
        for (s, q) in zip(r.slag, pslag) {
            XCTAssertEqual(s.dtl, q["dtl"] as? String, namn)
            XCTAssertEqual(s.fo, q["fo"] as? String, namn)
            XCTAssertEqual(s.fel, q["fel"] as? String, namn)
            a.notera("synk_ms (avrundad)", s.synkMs, Fixtur.tal(q["synk_ms"])!)
            XCTAssertEqual(s.synkMs, Fixtur.tal(q["synk_ms"])!, accuracy: 0.1 + 1e-9, namn)
            if let p = Fixtur.tal(q["aterprojektion_px"]), let sw = s.aterprojektionPx {
                XCTAssertEqual(sw, p, accuracy: 0.1 + 1e-9, namn)
            }
            let pm = (q["matt"] as? [String: Any]) ?? [:]
            XCTAssertEqual(Set((s.matt ?? [:]).keys), Set(pm.keys), namn)
            for (m, v) in pm {
                guard let sw = s.matt?[m] else { continue }
                a.notera("matt " + m, sw, Fixtur.tal(v)!)
            }
        }
        XCTAssertEqual(r.n, (py["n"] as! [String: Any]).mapValues { Fixtur.heltal($0) }, namn)
        let pses = py["session"] as! [String: Any]
        XCTAssertEqual(Set(r.session.keys), Set(pses.keys), namn)
        for (m, v) in pses {
            guard let s = r.session[m] else { continue }
            let q = v as! [String: Any]
            XCTAssertEqual(s.n, Fixtur.heltal(q["n"]), namn)
            XCTAssertEqual(s.avvikare, (q["avvikare"] as! [Any]).map { Fixtur.heltal($0) }, namn)
            for (x, nyckel) in [(s.median, "median"), (s.q1, "q1"), (s.q3, "q3"), (s.sd, "sd"), (s.min, "min"),
                                (s.max, "max"), (s.trend, "trend")] {
                a.notera("session " + nyckel, x, Fixtur.tal(q[nyckel])!)
            }
        }
    }

    /// Avvikelserna inom toleranserna (METOD M50).
    func inomTolerans(_ a: Avvikelser, _ namn: String) {
        for (k, v) in a.storst {
            let tol: Double
            switch k {
            case "R", "t", "upp": tol = Self.tolKamera
            case "synk_s": tol = Self.tolSynk
            case "aterprojektion_px": tol = Self.tolRep
            case let x where x.hasPrefix("matt ") || x.hasPrefix("session "): tol = Self.tolMatt
            default: continue                   // avrundade fält prövas mot sitt steg ovan
            }
            XCTAssertLessThanOrEqual(v, tol, "\(namn): \(k)")
        }
    }

    /// Kör en fixturs varianter mot Python. Svarar Swifts resultat per variant.
    @discardableResult
    func korFixtur(_ namn: String) throws -> [String: Result<TreDResultat, TreDFel>] {
        let fx = try Fixtur.las(namn)
        var ut: [String: Result<TreDResultat, TreDFel>] = [:]
        for variant in (fx["varianter"] as! [String: Any]).keys.sorted() {
            let (dtl, fo) = try Fixtur.paket(fx, variant)
            let py = Fixtur.python(fx, variant)
            let a = Avvikelser()
            let start = Date()
            do {
                let r = try TvaKameror.analysera(dtl: dtl, fo: fo, faser: Fixtur.faser(fx))
                print("TRED-TID \(namn)/\(variant) \(r.parning.par) slag \(Date().timeIntervalSince(start)) s")
                XCTAssertNil(py["hoppat"], "\(namn)/\(variant): Python hoppade över")
                if py["hoppat"] == nil { jamfor(r, py, Fixtur.inre(fx, variant), "\(namn)/\(variant)", a) }
                ut[variant] = .success(r)
            } catch let e as TreDFel {
                XCTAssertEqual(e.skal, py["hoppat"] as? String, "\(namn)/\(variant)")
                ut[variant] = .failure(e)
            }
            a.skriv("\(namn)/\(variant)")
            inomTolerans(a, "\(namn)/\(variant)")
        }
        return ut
    }

    static func sant(_ fx: [String: Any]) -> (perSlag: [String: [String: Double]], median: [String: Double], synk: [String: Double]) {
        let s = fx["sant"] as! [String: Any]
        var per: [String: [String: Double]] = [:], synk: [String: Double] = [:]
        for x in s["slag"] as! [[String: Any]] {
            let nyckel = "\(x["dtl"] as! String)/\(x["fo"] as! String)"
            per[nyckel] = (x["sant"] as! [String: Any]).mapValues { Fixtur.tal($0)! }
            synk[nyckel] = Fixtur.tal(x["synk_ms"])!
        }
        return (per, (s["median"] as! [String: Any]).mapValues { Fixtur.tal($0)! }, synk)
    }

    // MARK: - Mot Python och mot sanningen

    func testUtanBrusSomPythonOchExakt() throws {
        let fx = try Fixtur.las("utan_brus")
        let r = try XCTUnwrap(try korFixtur("utan_brus")["grund"]?.get())
        let (per, median, synk) = Self.sant(fx)
        XCTAssertEqual(r.parning.par, 10)
        XCTAssertEqual(r.parning.kalla, "par.json")
        for s in r.slag {
            let k = "\(s.dtl)/\(s.fo)"
            for (m, v) in s.matt ?? [:] { XCTAssertEqual(v, per[k]![m]!, accuracy: 1.0, "\(k) \(m)") }
            XCTAssertEqual(s.synkMs, synk[k]!, accuracy: 1.0, k)          // klicket ±7 ms → under 1 ms
        }
        for m in TvaKameror.matt { XCTAssertEqual(r.session[m]!.median, median[m]!, accuracy: 0.5, m) }
        XCTAssertEqual(r.kalibrering[0].lodlinje, "kamerornas_vagrata")
        XCTAssertEqual(r.osaker, [])
    }

    func testBraBrusVansterMedLodlinjeUtanParJson() throws {
        let fx = try Fixtur.las("bra_brus_vanster")
        let r = try XCTUnwrap(try korFixtur("bra_brus_vanster")["grund"]?.get())
        XCTAssertEqual(r.parning.kalla, "klicken")
        XCTAssertEqual(r.kalibrering[0].lodlinje, "manifest")
        // Felbudgetens gräns |bias| + 3 SD för passets median med bra brus (S6_FELBUDGET §6.7, MK8).
        let grans = ["backen_vrid_topp": 1.7 + 3 * 5.6, "brost_vrid_topp": 1.2 + 3 * 4.0, "xfaktor_topp": 0.8 + 3 * 7.4,
                     "xfaktor_stretch": 3.3 + 3 * 3.7, "hofter_oppna_traff": 0.7 + 3 * 5.5]
        let (_, median, _) = Self.sant(fx)
        for m in TvaKameror.matt {
            XCTAssertLessThanOrEqual(abs(r.session[m]!.median - median[m]!), grans[m]!, m)
        }
    }

    func testLodlinjensOchBrannviddensVagar() throws {
        let fx = try Fixtur.las("lodlinje")
        let ut = try korFixtur("lodlinje")
        let (per, _, _) = Self.sant(fx)
        for v in ["grund", "utan_lodlinje", "vriden_30", "vand", "trasig_fo", "synfalt_ur_enhet", "detection_wrong"] {
            let r = try XCTUnwrap(try ut[v]?.get(), v)
            for s in r.slag {
                for (m, x) in s.matt ?? [:] {
                    XCTAssertEqual(x, per["\(s.dtl)/\(s.fo)"]![m]!, accuracy: 1.0, "\(v) \(m)")   // tecknet vänds inte
                }
            }
        }
        XCTAssertEqual(try ut["vriden_30"]!.get().kalibrering[0].lodlinje, "kamerornas_vagrata")
        XCTAssertEqual(try ut["vand"]!.get().kalibrering[0].lodlinjeFel?.first,
                       "serie 1: lodlinje pekar inte mot bildens överkant")
        XCTAssertEqual(try ut["synfalt_ur_enhet"]!.get().kalibrering[0].fKalla, ["dtl": "specifikationen", "fo": "enhet.json"])
        XCTAssertEqual(try ut["detection_wrong"]!.get().slag.count, 1)
    }

    func testSparrenHopparOver() throws {
        let ut = try korFixtur("sparren")
        guard case .failure(let e) = ut["grund"]! else { return XCTFail("spärren släppte igenom") }
        XCTAssertEqual(e.skal, "kalibreringen: ingen serie gick att kalibrera under spärren")
    }

    func testParningenSomPython() throws {
        let fx = try Fixtur.las("parning")
        for (namn, p) in fx["pass"] as! [String: Any] {
            let pass = p as! [String: Any]
            for (variant, v) in pass["varianter"] as! [String: Any] {
                let (dtl, fo) = try Fixtur.paket(pass, variant, medLeder: false)
                let (par, info) = Parning.paraSlag(dtl, fo)
                let q = v as! [String: Any]
                let pyPar = (q["par"] as! [[String]]).map { $0[0] + "/" + $0[1] }
                XCTAssertEqual(par.map { $0.0.id + "/" + $0.1.id }, pyPar, "\(namn)/\(variant)")
                let pi = q["info"] as! [String: Any]
                XCTAssertEqual(info.kalla, pi["kalla"] as? String, "\(namn)/\(variant)")
                XCTAssertEqual(info.parJsonFel, pi["par_json_fel"] as? String, "\(namn)/\(variant)")
                XCTAssertEqual(info.serier.map(\.kalla), (pi["serier"] as! [[String: Any]]).map { $0["kalla"] as! String },
                               "\(namn)/\(variant)")
                XCTAssertEqual(info.oparade["fo"], Fixtur.heltal((pi["oparade"] as! [String: Any])["fo"]))
            }
        }
    }

    func testParaUtanPriorHittarForskjutningLangreAnSokningen() {
        let a = [10.0, 17.4, 25.1, 31.9, 40.2]
        let b = zip(a, [0.004, -0.003, 0.0, 0.006, -0.002]).map { $0 + 37.2 + $1 }
        let r = Parning.utanPrior(a, b)
        XCTAssertFalse(r.uncertain)
        XCTAssertEqual(r.pairs.count, 5)
        XCTAssertEqual(r.offset, 37.2, accuracy: 0.005)
        XCTAssertTrue(Parning.utanPrior(Array(a[0..<2]), Array(b[0..<2])).uncertain)
    }

    func testJamforelsenMotForraPasset() throws {
        let nu = try Fixtur.las("utan_brus"), forra = try Fixtur.las("bra_brus_vanster")
        func ses(_ fx: [String: Any]) -> [String: TreDSammanfattning] {
            (Fixtur.python(fx, "grund")["session"] as! [String: Any]).mapValues { v in
                let q = v as! [String: Any]
                return TreDSammanfattning(n: Fixtur.heltal(q["n"]), median: Fixtur.tal(q["median"])!, q1: Fixtur.tal(q["q1"])!,
                                          q3: Fixtur.tal(q["q3"])!, sd: Fixtur.tal(q["sd"])!, min: Fixtur.tal(q["min"])!,
                                          max: Fixtur.tal(q["max"])!, trend: Fixtur.tal(q["trend"])!, avvikare: [])
            }
        }
        let j = TvaKameror.jamfor(ses(nu), ses(forra))
        XCTAssertEqual(Set(j.keys), Set(TvaKameror.matt))
        let b = ses(forra)["brost_vrid_topp"]!
        let x = j["brost_vrid_topp"]!
        XCTAssertEqual(x.skillnad, ses(nu)["brost_vrid_topp"]!.median - b.median)
        XCTAssertEqual(x.golv, 13.6)
        XCTAssertEqual(x.tydlig, abs(x.skillnad) > max(x.spridning, 13.6))
    }

    func testResultatetArJsonSomAnalysens() throws {
        let fx = try Fixtur.las("lodlinje")
        let (dtl, fo) = try Fixtur.paket(fx, "grund")
        let r = try TvaKameror.analysera(dtl: dtl, fo: fo, faser: Fixtur.faser(fx))
        let o = try JSONSerialization.jsonObject(with: JSONEncoder().encode(r)) as! [String: Any]
        XCTAssertEqual(Set(o.keys), ["lage", "min_slag", "matt", "parning", "kalibrering", "osaker", "slag", "n", "session"])
        XCTAssertEqual(o["lage"] as? String, "utan_markorer")
        XCTAssertNotNil((o["kalibrering"] as! [[String: Any]])[0]["sampson_px"])
    }

    // MARK: - Delstegen (för att hitta en avvikelse)

    func testDelstegenSomPython() throws {
        let k = try Fixtur.las("komponenter")
        let fx = try Fixtur.las(k["pass"] as! String)
        let (dtl, fo) = try Fixtur.paket(fx, "grund")
        let (par, _) = Parning.paraSlag(dtl, fo)
        let pk = k["par"] as! [String]
        XCTAssertEqual([par[0].0.id, par[0].1.id], pk)
        var grupp: [TvaKameror.SlagData] = []
        for (sd, sf) in par {
            let a = TvaKameror.spar(fo, sf), b = TvaKameror.spar(dtl, sd)
            let (ka, fKa) = TvaKameror.kFor(fo, sf), (kb, fKb) = TvaKameror.kFor(dtl, sd)
            grupp.append(TvaKameror.SlagData(dtl: sd, fo: sf, a: a, b: b, ka: ka, kb: kb, fKa: fKa, fKb: fKb,
                                             traffA: TvaKameror.traffISerien(fo, sf), traffB: TvaKameror.traffISerien(dtl, sd),
                                             vA: Utjamning.robustaVikter(a, 0.04), vB: Utjamning.robustaVikter(b, 0.04)))
        }
        let d = grupp[0]
        let av = Avvikelser()
        let sp = k["spar_a"] as! [String: Any]
        XCTAssertEqual(d.a.n, Fixtur.heltal(sp["n"]))
        for (x, y) in zip(d.a.t, Fixtur.lista(sp["t"])) { av.notera("spar t", x, y) }
        let vk = k["vikter_a"] as! [String: Any]
        for (l, y) in Fixtur.lista(vk["w_summa"]).enumerated() {
            av.notera("vikter w_summa", (0..<d.a.n).map { d.vA.w[$0 * 13 + l] }.reduce(0, +), y)
        }
        let jk = k["jamnade"] as! [String: Any]
        let (tg, a, ka, b, kb) = TvaKameror.jamnade(d, 0)
        XCTAssertEqual(tg.count, Fixtur.heltal(jk["n"]))
        av.notera("jamnade t0", tg[0], Fixtur.tal(jk["t0"])!)
        let index = (jk["index"] as! [Any]).map { Fixtur.heltal($0) }
        for (nr, (namn, uv)) in [("a", a), ("b", b)].enumerated() {
            let p = jk[namn] as! [[[Any]]]
            for (r, i) in index.enumerated() {
                for l in 0..<13 {
                    av.notera("jamnade " + namn, uv[(i * 13 + l) * 2], Fixtur.tal(p[r][l][0]) ?? .nan)
                    av.notera("jamnade " + namn, uv[(i * 13 + l) * 2 + 1], Fixtur.tal(p[r][l][1]) ?? .nan)
                    let kk = nr == 0 ? ka : kb
                    av.notera("jamnade k", kk[i * 13 + l], Fixtur.tal((jk[nr == 0 ? "ka" : "kb"] as! [[Any]])[r][l])!)
                }
            }
        }
        let kal = try TvaKameror.kalibrera(grupp, [Double](repeating: 0, count: grupp.count), nil, nil)
        let kk = k["kalibrering"] as! [String: Any]
        for (x, y) in zip(kal.r, (kk["R"] as! [[Any]]).flatMap { $0.map { Fixtur.tal($0)! } }) { av.notera("kalib R", x, y) }
        for (x, y) in zip(kal.t, Fixtur.lista(kk["t"])) { av.notera("kalib t", x, y) }
        av.notera("kalib sampson_px", LA.avrunda(kal.sampsonPx, 2), Fixtur.tal(kk["sampson_px"])!)
        let kam = TvaKameror.kameror(d, kal)
        let synk = TvaKameror.synka(kam, d, 0, 0.0105)
        av.notera("synk", synk, Fixtur.tal(k["synk"])!)
        let tk = k["triangulering"] as! [String: Any]
        let (t3, p3, rep) = TvaKameror.triangulera(kam, d, synk)
        XCTAssertEqual(t3.count, Fixtur.heltal(tk["n"]))
        av.notera("triangulering rep", rep, Fixtur.tal(tk["rep"])!)
        let pp = tk["P"] as! [[[Any]]]
        for (r, i) in index.enumerated() {
            let ii = min(i, t3.count - 1)
            for l in 0..<13 {
                for c in 0..<3 { av.notera("triangulering P", p3[(ii * 13 + l) * 3 + c], Fixtur.tal(pp[r][l][c]) ?? .nan) }
            }
        }
        let vk2 = k["vinklar"] as! [String: Any]
        let backen = Matt3D.fyllLuckor(t3, Matt3D.linjevinkel(p3, Matt3D.vHoft, Matt3D.hHoft, t3, (-1.2, -0.9)))
        let brost = Matt3D.fyllLuckor(t3, Matt3D.linjevinkel(p3, Matt3D.vAxel, Matt3D.hAxel, t3, (-1.2, -0.9)))
        for (r, i) in index.enumerated() {
            let ii = min(i, t3.count - 1)
            av.notera("vinklar backen", backen[ii], Fixtur.tal((vk2["backen"] as! [Any])[r]) ?? .nan)
            av.notera("vinklar brost", brost[ii], Fixtur.tal((vk2["brost"] as! [Any])[r]) ?? .nan)
        }
        av.skriv("komponenter")
        for (namn, v) in av.storst {
            XCTAssertLessThanOrEqual(v, 1e-6, namn)
        }
    }

    // MARK: - Tiden

    /// Tiden för 20 slag i två uppställningar (passets tio slag en gång till som serie 2, parad
    /// på klicken), och var den går. För METOD M50:s skattning på telefonen.
    func testTidenFor20SlagOchVarDenGar() throws {
        let fx = try Fixtur.las("bra_brus_vanster")
        var (dtl, fo) = try Fixtur.paket(fx, "grund")
        var faser = Fixtur.faser(fx)
        for vy in [Vy.dtl, Vy.fo] {
            var p = vy == .dtl ? dtl : fo
            let extra = p.slag.map { s -> TreDSlag in
                var x = s
                x.id = "s1" + s.id.dropFirst()
                x.serie = 2
                faser["\(vy.rawValue)/\(x.id)"] = faser["\(vy.rawValue)/\(s.id)"]
                return x
            }
            p.serier[2] = TreDSerie(nr: 2, lodlinje: p.serier[1]?.lodlinje, synfalt: p.serier[1]?.synfalt)
            p = TreDPaket(passID: p.passID, vy: p.vy, spelhand: p.spelhand, avstandM: p.avstandM, serier: p.serier,
                          slag: p.slag + extra, par: p.par, parFel: p.parFel, enhetSynfalt: p.enhetSynfalt)
            if vy == .dtl { dtl = p } else { fo = p }
        }
        let start = Date()
        let r = try TvaKameror.analysera(dtl: dtl, fo: fo, faser: faser)
        let tid = Date().timeIntervalSince(start)
        print("TRED-TID 20 slag \(r.parning.par) par, \(r.kalibrering.count) uppställningar, \(tid) s")
        XCTAssertEqual(r.parning.par, 20)
        XCTAssertEqual(r.slag.filter { $0.matt != nil }.count, 20)

        // Var tiden går, för en uppställning om tio slag (som `uppstallning`).
        let (par, _) = Parning.paraSlag(dtl, fo)
        var t0 = Date()
        var grupp: [TvaKameror.SlagData] = []
        for (sd, sf) in par where sd.serie == 1 {
            let a = TvaKameror.spar(fo, sf), b = TvaKameror.spar(dtl, sd)
            let (ka, fKa) = TvaKameror.kFor(fo, sf), (kb, fKb) = TvaKameror.kFor(dtl, sd)
            grupp.append(TvaKameror.SlagData(dtl: sd, fo: sf, a: a, b: b, ka: ka, kb: kb, fKa: fKa, fKb: fKb,
                                             traffA: TvaKameror.traffISerien(fo, sf), traffB: TvaKameror.traffISerien(dtl, sd),
                                             vA: Utjamning.robustaVikter(a, 0.04), vB: Utjamning.robustaVikter(b, 0.04)))
        }
        let tSpar = Date().timeIntervalSince(t0)
        t0 = Date()
        let kal = try TvaKameror.kalibrera(grupp, [Double](repeating: 0, count: grupp.count), nil, nil)
        let tKalib = Date().timeIntervalSince(t0)
        t0 = Date()
        let forsk = grupp.map { TvaKameror.synka(TvaKameror.kameror($0, kal), $0, 0, 0.0105) }
        let tSynk = Date().timeIntervalSince(t0)
        t0 = Date()
        for (d, f) in zip(grupp, forsk) { _ = TvaKameror.triangulera(TvaKameror.kameror(d, kal), d, f) }
        let tTri = Date().timeIntervalSince(t0)
        print("TRED-TID delar (10 slag): spår och robusta vikter \(tSpar) s, en kalibrering \(tKalib) s, " +
              "ett synkvarv \(tSynk) s, triangulering \(tTri) s")
        XCTAssertLessThan(tid, 30)
    }

    /// Tiden för ett pass om 10 slag (release, Linux), för METOD M50:s skattning på telefonen.
    func testTidenForEttPass() throws {
        let fx = try Fixtur.las("bra_brus_vanster")
        let (dtl, fo) = try Fixtur.paket(fx, "grund")
        let start = Date()
        let r = try TvaKameror.analysera(dtl: dtl, fo: fo, faser: Fixtur.faser(fx))
        let tid = Date().timeIntervalSince(start)
        print("TRED-TID pass \(r.parning.par) slag \(tid) s")
        XCTAssertLessThan(tid, 20)
    }
}
