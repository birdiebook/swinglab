import Capture
import Foundation
import Swing
import XCTest
@testable import TreD

/// S6c-1: 3D på telefonen mot Pythons tal (BESLUT B12, B48) och mot sanningen (METOD MK8),
/// på PÅHITTADE tvåpaketspass (CLAUDE.md, Dataregeln). Fixturerna skrivs av
/// tools/pc/generera_tre_d.py: passens indata i tools/tests/fixturer/tre_d/indata/ och
/// Pythons tal per variant bredvid. Toleranserna: METOD M50.
enum Fixtur {
    static let rot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let mapp = rot.appendingPathComponent("tools/tests/fixturer/tre_d")

    static func las(_ namn: String) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(contentsOf: mapp.appendingPathComponent("\(namn).json"))) as! [String: Any]
    }

    private static var indataMinne: [String: [String: Any]] = [:]
    private static var lederMinne: [String: [String: [String: JointSeries]]] = [:]

    /// Ett pass indata (läst en gång).
    static func indata(_ namn: String) throws -> [String: Any] {
        if let d = indataMinne[namn] { return d }
        let d = try las("indata/\(namn)")
        indataMinne[namn] = d
        return d
    }

    /// Passets leder per vy och slag-id (avkodade en gång).
    static func leder(_ namn: String) throws -> [String: [String: JointSeries]] {
        if let l = lederMinne[namn] { return l }
        var ut: [String: [String: JointSeries]] = [:]
        for vy in ["dtl", "fo"] {
            let p = (try indata(namn)["paket"] as! [String: Any])[vy] as! [String: Any]
            ut[vy] = (p["leder"] as! [String: Any]).mapValues { leder($0 as! [String: Any]) }
        }
        lederMinne[namn] = ut
        return ut
    }

    static func tal(_ x: Any?) -> Double? {
        (x as? NSNumber)?.doubleValue
    }

    static func heltal(_ x: Any?) -> Int {
        (x as! NSNumber).intValue
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

    static func data(_ x: Any?) -> Data? {
        (x as? String).map { Data($0.utf8) }
    }

    /// Paketets filer med en variants ändringar (andra[vy]).
    static func filer(_ bas: [String: Any], _ vy: String, _ andra: [String: Any]) -> [String: Any] {
        var p = bas[vy] as! [String: Any]
        for (k, v) in (andra[vy] as? [String: Any]) ?? [:] { p[k] = v }
        return p
    }

    /// Ett pass två paket (dtl, fo) med en variants ändringar, lästa med TreDPaket.las.
    static func paket(pass: String, andra: [String: Any]) throws -> (TreDPaket, TreDPaket) {
        let bas = try indata(pass)["paket"] as! [String: Any]
        let l = try leder(pass)
        var ut: [TreDPaket] = []
        for vy in ["dtl", "fo"] {
            let p = filer(bas, vy, andra)
            ut.append(try TreDPaket.las(manifest: data(p["manifest"])!, lederna: l[vy]!,
                                        filer: Set(p["filer"] as! [String]), par: data(p["par"]), enhet: data(p["enhet"])))
        }
        return (ut[0], ut[1])
    }

    /// 2D-fasernas start och topp per slag ("dtl/s01").
    static func faser(_ pass: String) throws -> [String: Faser2D] {
        var ut: [String: Faser2D] = [:]
        for r in try indata(pass)["rader"] as! [[String: Any]] {
            ut["\(r["vy"] as! String)/\(r["id"] as! String)"] = Faser2D(start: tal(r["start"]), topp: tal(r["topp"]))
        }
        return ut
    }

    static func variant(_ fx: [String: Any], _ v: String) -> [String: Any] {
        (fx["varianter"] as! [String: Any])[v] as! [String: Any]
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
    static let tolKamera = 1e-8        // R, t, uppåt (enhetslösa); uppmätt högst 1,9e-10
    static let tolSynk = 1e-8          // s; uppmätt högst 7,3e-10
    static let tolRep = 1e-6           // px; uppmätt högst 2,9e-8
    static let tolMatt = 1e-5          // grader, per slag och passets sammanfattning; uppmätt högst 3,3e-7

    /// Jämför Swifts resultat med Pythons för en variant, fält för fält.
    func jamfor(_ r: TreDResultat, _ py: [String: Any], _ inre: [Any], _ namn: String, _ a: Avvikelser) {
        XCTAssertEqual(r.lage, py["lage"] as? String, namn)
        XCTAssertEqual(r.matt, py["matt"] as? [String], namn)
        XCTAssertEqual(r.minSlag, Fixtur.heltal(py["min_slag"]), namn)
        // Parningen
        let pp = py["parning"] as! [String: Any]
        XCTAssertEqual(r.parning.kalla, pp["kalla"] as? String, namn)
        XCTAssertEqual(r.parning.par, Fixtur.heltal(pp["par"]), namn)
        XCTAssertEqual(r.parning.oparade, (pp["oparade"] as! [String: Any]).mapValues { Fixtur.heltal($0) }, namn)
        XCTAssertEqual(r.parning.parJsonFel, pp["par_json_fel"] as? String, namn)
        let ps = pp["serier"] as! [[String: Any]]
        XCTAssertEqual(r.parning.serier.count, ps.count, namn)
        for (s, q) in zip(r.parning.serier, ps) {
            XCTAssertEqual([s.dtl, s.fo, s.par], [Fixtur.heltal(q["dtl"]), Fixtur.heltal(q["fo"]), Fixtur.heltal(q["par"])],
                           namn)
            XCTAssertEqual(s.kalla, q["kalla"] as? String, namn)
        }
        // Kalibreringen
        let pk = py["kalibrering"] as! [[String: Any]]
        XCTAssertEqual(r.kalibrering.count, pk.count, namn)
        for (k, q) in zip(r.kalibrering, pk) {
            XCTAssertEqual(k.serie, (q["serie"] as! [String: Any]).mapValues { Fixtur.heltal($0) }, namn)
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
        let pu = (py["utelamnade"] as! [[String: Any]]).map { "\($0["dtl"]!)/\($0["fo"]!): \($0["skal"]!)" }
        XCTAssertEqual(r.utelamnade.map { "\($0.dtl)/\($0.fo): \($0.skal)" }, pu, namn)
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
            XCTAssertEqual(i.forsk.count, Fixtur.lista(q["forsk"]).count, namn)
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
            XCTAssertEqual(s.serie, (q["serie"] as! [String: Any]).mapValues { Fixtur.heltal($0) }, namn)
            XCTAssertEqual(s.fel, q["fel"] as? String, namn)
            a.notera("synk_ms (avrundad)", s.synkMs, Fixtur.tal(q["synk_ms"])!)
            XCTAssertEqual(s.synkMs, Fixtur.tal(q["synk_ms"])!, accuracy: 0.1 + 1e-9, namn)
            XCTAssertEqual(s.aterprojektionPx == nil, Fixtur.tal(q["aterprojektion_px"]) == nil, namn)
            if let p = Fixtur.tal(q["aterprojektion_px"]), let sw = s.aterprojektionPx {
                XCTAssertEqual(sw, p, accuracy: 0.1 + 1e-9, namn)
            }
            let pm = (q["matt"] as? [String: Any]) ?? [:]
            XCTAssertEqual(s.matt == nil, q["matt"] == nil, namn)
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
        let pass = fx["indata"] as! String
        var ut: [String: Result<TreDResultat, TreDFel>] = [:]
        for variant in (fx["varianter"] as! [String: Any]).keys.sorted() {
            let v = Fixtur.variant(fx, variant)
            let (dtl, fo) = try Fixtur.paket(pass: pass, andra: v["andra"] as! [String: Any])
            let py = v["python"] as! [String: Any]
            let a = Avvikelser()
            let start = Date()
            do {
                let r = try TvaKameror.analysera(dtl: dtl, fo: fo, faser: Fixtur.faser(pass))
                print("TRED-TID \(namn)/\(variant) \(r.parning.par) slag \(Date().timeIntervalSince(start)) s")
                XCTAssertNil(py["hoppat"], "\(namn)/\(variant): Python hoppade över")
                if py["hoppat"] == nil { jamfor(r, py, v["inre"] as! [Any], "\(namn)/\(variant)", a) }
                // Inget NaN i utdata: JSONEncoder vägrar icke ändliga tal (METOD M51).
                XCTAssertNoThrow(try JSONEncoder().encode(r), "\(namn)/\(variant)")
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

    static func sant(_ pass: String) throws
        -> (perSlag: [String: [String: Double]], median: [String: Double], synk: [String: Double]) {
        let s = try Fixtur.indata(pass)["sant"] as! [String: Any]
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
        let r = try XCTUnwrap(try korFixtur("utan_brus")["grund"]?.get())
        let (per, median, synk) = try Self.sant("utan_brus")
        XCTAssertEqual(r.parning.par, 10)
        XCTAssertEqual(r.parning.kalla, "par.json")
        for s in r.slag {
            let k = "\(s.dtl)/\(s.fo)"
            for (m, v) in s.matt ?? [:] { XCTAssertEqual(v, per[k]![m]!, accuracy: 1.0, "\(k) \(m)") }
            XCTAssertEqual(s.synkMs, synk[k]!, accuracy: 1.0, k)          // klicket ±7 ms → under 1 ms
        }
        for m in TvaKameror.matt { XCTAssertEqual(r.session[m]!.median, median[m]!, accuracy: 0.5, m) }
        XCTAssertEqual(r.kalibrering[0].lodlinje, "manifest")
        XCTAssertEqual(r.osaker, [])
        XCTAssertEqual(r.utelamnade, [])
    }

    func testBraBrusVansterMedLodlinjeUtanParJson() throws {
        let r = try XCTUnwrap(try korFixtur("bra_brus_vanster")["grund"]?.get())
        XCTAssertEqual(r.parning.kalla, "klicken")
        XCTAssertEqual(r.kalibrering[0].lodlinje, "manifest")
        // Felbudgetens gräns |bias| + 3 SD för passets median med bra brus (S6_FELBUDGET §6.7, MK8).
        let grans = ["backen_vrid_topp": 1.7 + 3 * 5.6, "brost_vrid_topp": 1.2 + 3 * 4.0, "xfaktor_topp": 0.8 + 3 * 7.4,
                     "xfaktor_stretch": 3.3 + 3 * 3.7, "hofter_oppna_traff": 0.7 + 3 * 5.5]
        let (_, median, _) = try Self.sant("bra_brus_vanster")
        for m in TvaKameror.matt {
            XCTAssertLessThanOrEqual(abs(r.session[m]!.median - median[m]!), grans[m]!, m)
        }
    }

    func testLodlinjensOchBrannviddensVagar() throws {
        let ut = try korFixtur("lodlinje")
        let (per, _, _) = try Self.sant("utan_brus")
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
        let dw = try ut["detection_wrong"]!.get()
        XCTAssertEqual(dw.slag.count, 1)
        XCTAssertEqual(dw.utelamnade.map(\.skal), ["lederna är märkta fel (Detection wrong)",
                                                   "lederna är märkta fel (Detection wrong)", "domen är inte sving"])
    }

    func testTvaSerierMedOsakerVinkelSaknadeFaserOchTvetydigaKlick() throws {
        let ut = try korFixtur("tva_serier")
        let r = try ut["grund"]!.get()
        XCTAssertEqual(r.kalibrering.count, 2)
        XCTAssertEqual(r.kalibrering.map(\.vinkelOk), [true, false])
        XCTAssertEqual(r.osaker, ["serie 2 (DTL) mot 2 (FO): vinkeln mellan kamerorna utanför 60–120°"])
        XCTAssertEqual(r.slag.first { $0.dtl == "s03" }?.fel, "faserna saknas i båda vyerna")
        XCTAssertNotNil(r.slag.first { $0.dtl == "s02" }?.fel)
        XCTAssertGreaterThanOrEqual(r.slag.filter { $0.serie["dtl"] == 2 && $0.matt != nil }.count, 4)
        // Utan par.json är serie 2:s klick tvetydiga (jämna mellanrum): bara serie 1 paras.
        let u = try ut["utan_par"]!.get()
        XCTAssertEqual(u.parning.serier.map(\.dtl), [1])
        XCTAssertEqual(u.parning.oparade["dtl"], 4)
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
            let bas = pass["paket"] as! [String: Any]
            for (variant, v) in pass["varianter"] as! [String: Any] {
                let q = v as! [String: Any]
                let andra = q["andra"] as! [String: Any]
                let paket = try ["dtl", "fo"].map { vy -> TreDPaket in
                    let f = Fixtur.filer(bas, vy, andra)
                    return try TreDPaket.las(manifest: Fixtur.data(f["manifest"])!, lederna: [:], par: Fixtur.data(f["par"]),
                                             enhet: Fixtur.data(f["enhet"]))
                }
                let (par, info) = try Parning.paraSlag(paket[0], paket[1])
                let pyPar = (q["par"] as! [[String]]).map { $0[0] + "/" + $0[1] }
                XCTAssertEqual(par.map { $0.0.id + "/" + $0.1.id }, pyPar, "\(namn)/\(variant)")
                let pi = q["info"] as! [String: Any]
                XCTAssertEqual(info.kalla, pi["kalla"] as? String, "\(namn)/\(variant)")
                XCTAssertEqual(info.parJsonFel, pi["par_json_fel"] as? String, "\(namn)/\(variant)")
                XCTAssertEqual(info.serier.map { "\($0.dtl)-\($0.fo) \($0.kalla) \($0.par)" },
                               (pi["serier"] as! [[String: Any]]).map {
                                   "\(Fixtur.heltal($0["dtl"]))-\(Fixtur.heltal($0["fo"])) \($0["kalla"] as! String) \(Fixtur.heltal($0["par"]))"
                               }, "\(namn)/\(variant)")
                XCTAssertEqual(info.oparade, (pi["oparade"] as! [String: Any]).mapValues { Fixtur.heltal($0) })
                // Paketen i fel ordning: ett fel, inte en tyst parning.
                XCTAssertThrowsError(try Parning.paraSlag(paket[1], paket[0]))
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
        func ses(_ namn: String) throws -> [String: TreDSammanfattning] {
            (Fixtur.variant(try Fixtur.las(namn), "grund")["python"] as! [String: Any])["session"].map {
                ($0 as! [String: Any]).mapValues { v in
                    let q = v as! [String: Any]
                    return TreDSammanfattning(n: Fixtur.heltal(q["n"]), median: Fixtur.tal(q["median"])!, q1: Fixtur.tal(q["q1"])!,
                                              q3: Fixtur.tal(q["q3"])!, sd: Fixtur.tal(q["sd"])!, min: Fixtur.tal(q["min"])!,
                                              max: Fixtur.tal(q["max"])!, trend: Fixtur.tal(q["trend"])!, avvikare: [])
                }
            }!
        }
        let nu = try ses("utan_brus"), forra = try ses("bra_brus_vanster")
        let j = TvaKameror.jamfor(nu, forra)
        XCTAssertEqual(Set(j.keys), Set(TvaKameror.matt))
        let x = j["brost_vrid_topp"]!
        XCTAssertEqual(x.skillnad, nu["brost_vrid_topp"]!.median - forra["brost_vrid_topp"]!.median)
        XCTAssertEqual(x.golv, 13.7)
        XCTAssertEqual(x.tydlig, abs(x.skillnad) > max(x.spridning, 13.7))
    }

    // MARK: - Paketens form och vakterna (METOD M51)

    func testManifestensFelSomPython() throws {
        let fx = try Fixtur.las("manifest_fel")
        let filer = Set(fx["filer"] as! [String])
        for f in fx["fall"] as! [[String: Any]] {
            let namn = f["namn"] as! String
            let m = try JSONVarde.las(Fixtur.data(f["manifest"])!)
            XCTAssertEqual(TreDPaket.kontrollera(m, filer: filer), f["fel"] as! [String], namn)
            XCTAssertThrowsError(try TreDPaket.las(manifest: Fixtur.data(f["manifest"])!, lederna: [:], filer: filer), namn) {
                XCTAssertEqual(($0 as? TreDPaketFel)?.fel, f["fel"] as? [String], namn)
            }
        }
    }

    func testTrasigaPaketBlirHoppat() throws {
        let bas = try Fixtur.indata("utan_brus")["paket"] as! [String: Any]
        let l = try Fixtur.leder("utan_brus")
        func filer(_ vy: String, manifest: Data? = nil)
            -> (manifest: Data, lederna: [String: JointSeries], filer: Set<String>?, par: Data?, enhet: Data?) {
            let p = bas[vy] as! [String: Any]
            return (manifest ?? Fixtur.data(p["manifest"])!, l[vy]!, Set(p["filer"] as! [String]), Fixtur.data(p["par"]),
                    nil)
        }
        let faser = try Fixtur.faser("utan_brus")
        guard case .hoppat(let s) = TvaKameror.treD(dtl: filer("dtl", manifest: Data("{\"pass\": ".utf8)), fo: filer("fo"),
                                                     faser: faser) else { return XCTFail("trasig JSON gick igenom") }
        XCTAssertEqual(s, "manifest.json är inte giltig JSON")
        guard case .hoppat(let s2) = TvaKameror.treD(dtl: filer("fo"), fo: filer("dtl"), faser: faser) else {
            return XCTFail("vyerna i fel ordning gick igenom")
        }
        XCTAssertEqual(s2, "parningen: paketen ska vara ett DTL- och ett FO-paket")
    }

    func testOrimligaTiderStopparSlagetUtanAttKrascha() throws {
        let fx = try Fixtur.las("lodlinje")
        var (dtl, fo) = try Fixtur.paket(pass: "utan_brus", andra: Fixtur.variant(fx, "grund")["andra"] as! [String: Any])
        // Ett slag med en ruta en vecka bort och ett med en tid som inte är ett tal.
        var a = fo.slag[0].lederna!
        a.frames[5].t = 7 * 24 * 3600
        fo.slag[0].lederna = a
        var b = dtl.slag[1].lederna!
        b.frames[3].t = .nan
        dtl.slag[1].lederna = b
        let r = try TvaKameror.analysera(dtl: dtl, fo: fo, faser: Fixtur.faser("utan_brus"))
        XCTAssertEqual(r.utelamnade.map(\.skal), ["ledernas tider spänner orimligt långt", "ledernas tider spänner orimligt långt"])
        XCTAssertEqual(r.slag.count, 2)
        XCTAssertNoThrow(try JSONEncoder().encode(r))
    }

    func testVakternaMotNaN() {
        // En granne utan värde: toppen själv, inte NaN.
        XCTAssertEqual(Triangulering.parabelTopp([0, 1, 2], [.nan, 5, 3], 1), 1)
        XCTAssertEqual(LA.arange(0, .infinity, 1), [])
        XCTAssertEqual(LA.arange(0, .nan, 1), [])
        XCTAssertEqual(LA.arange(0, 1e9, 1e-3), [])
        XCTAssertNil(TvaKameror.utelamnat((0..<50).map { Double($0) * 0.01 }))
        XCTAssertEqual(TvaKameror.utelamnat([0, 1]), "för få rutor")
    }

    func testJsonLasarenSkiljerPaTalOchBool() throws {
        let v = try JSONVarde.las(Data(#"{"a": 1, "b": 1.0, "c": true, "d": "xå\n", "e": [null, -2e-3], "f": 1E2}"#.utf8))
        XCTAssertEqual(v["a"], .nummer(1, heltal: true))
        XCTAssertEqual(v["a"]?.heltal, 1)
        XCTAssertNil(v["b"]?.heltal)
        XCTAssertEqual(v["b"]?.tal, 1)
        XCTAssertNil(v["c"]?.tal)
        XCTAssertEqual(v["d"]?.text, "xå\n")
        XCTAssertEqual(v["e"]?.lista?[1].tal, -0.002)
        XCTAssertEqual(v["f"], .nummer(100, heltal: false))
        for trasig in ["{", "[1,]", "01", "1.", "\"a", "{\"a\" 1}", "tru", "[1] 2"] {
            XCTAssertThrowsError(try JSONVarde.las(Data(trasig.utf8)), trasig)
        }
        XCTAssertTrue(JSONVarde.pyLika(nil, .null))
        XCTAssertTrue(JSONVarde.pyLika(.nummer(7, heltal: true), .nummer(7, heltal: false)))
        XCTAssertFalse(JSONVarde.pyLika(.strang("7"), .nummer(7, heltal: true)))
    }

    func testEnhetUtanValtIndexValjerSomPython() throws {
        // Python: x.get("index") == e.get("valt_index"), så utan valt_index väljs det format som saknar index.
        let m = (try Fixtur.indata("utan_brus")["paket"] as! [String: Any])["fo"] as! [String: Any]
        var man = try JSONSerialization.jsonObject(with: Fixtur.data(m["manifest"])!) as! [String: Any]
        var serier = man["serier"] as! [[String: Any]]
        serier[0]["format"] = nil
        man["serier"] = serier
        let md = try JSONSerialization.data(withJSONObject: man)
        let enhet = #"{"format": [{"index": 3, "width": 1920, "height": 1080, "fieldOfView": 40.0}, {"width": 1920, "height": 1080, "fieldOfView": 55.0}]}"#
        let p = try TreDPaket.las(manifest: md, lederna: [:], par: nil, enhet: Data(enhet.utf8))
        XCTAssertEqual(p.enhetSynfalt?.grader, 55.0)
    }

    func testResultatetArJsonSomAnalysens() throws {
        let fx = try Fixtur.las("lodlinje")
        let (dtl, fo) = try Fixtur.paket(pass: "utan_brus", andra: Fixtur.variant(fx, "grund")["andra"] as! [String: Any])
        let r = try TvaKameror.analysera(dtl: dtl, fo: fo, faser: Fixtur.faser("utan_brus"))
        let o = try JSONSerialization.jsonObject(with: JSONEncoder().encode(r)) as! [String: Any]
        XCTAssertEqual(Set(o.keys), ["lage", "min_slag", "matt", "parning", "kalibrering", "osaker", "slag", "utelamnade",
                                     "n", "session"])
        XCTAssertEqual(o["lage"] as? String, "utan_markorer")
        XCTAssertNotNil((o["kalibrering"] as! [[String: Any]])[0]["sampson_px"])
    }

    // MARK: - Delstegen (för att hitta en avvikelse)

    func testDelstegenSomPython() throws {
        let k = try Fixtur.las("komponenter")
        let pass = k["pass"] as! String
        let (dtl, fo) = try Fixtur.paket(pass: pass, andra: [:])
        let (par, _) = try Parning.paraSlag(dtl, fo)
        XCTAssertEqual([par[0].0.id, par[0].1.id], k["par"] as! [String])
        let grupp = Self.grupp(dtl, fo, par)
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

    static func grupp(_ dtl: TreDPaket, _ fo: TreDPaket, _ par: [(TreDSlag, TreDSlag)], serie: Int? = nil)
        -> [TvaKameror.SlagData] {
        par.filter { serie == nil || $0.0.serie == serie }.map { sd, sf in
            let a = TvaKameror.spar(fo, sf), b = TvaKameror.spar(dtl, sd)
            let (ka, fKa) = TvaKameror.kFor(fo, sf), (kb, fKb) = TvaKameror.kFor(dtl, sd)
            return TvaKameror.SlagData(dtl: sd, fo: sf, a: a, b: b, ka: ka, kb: kb, fKa: fKa, fKb: fKb,
                                       traffA: TvaKameror.traffISerien(fo, sf), traffB: TvaKameror.traffISerien(dtl, sd),
                                       vA: Utjamning.robustaVikter(a, 0.04), vB: Utjamning.robustaVikter(b, 0.04))
        }
    }

    // MARK: - Tiden

    /// Tiden för 20 slag i två uppställningar (passets tio slag en gång till som serie 2, parad
    /// på klicken), och var den går. För METOD M50:s skattning på telefonen.
    func testTidenFor20SlagOchVarDenGar() throws {
        var (dtl, fo) = try Fixtur.paket(pass: "bra_brus_vanster", andra: [:])
        var faser = try Fixtur.faser("bra_brus_vanster")
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
        let (par, _) = try Parning.paraSlag(dtl, fo)
        var t0 = Date()
        let grupp = Self.grupp(dtl, fo, par, serie: 1)
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
}
