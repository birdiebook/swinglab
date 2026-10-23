import Capture
import Foundation
import Swing

/// 2D-fasernas start och topp för ett slag (s i ledernas tid, relativt klicket), ur
/// telefonens eller PC:ns 2D-analys (METOD M4). Indata till 3D:s adress. METOD MK6
public struct Faser2D: Equatable, Sendable {
    public var start: Double?
    public var topp: Double?

    public init(start: Double?, topp: Double?) {
        self.start = start
        self.topp = topp
    }
}

/// En uppställning (en DTL-serie mot en FO-serie) i `tre_d.kalibrering`. METOD MK3
public struct TreDUppstallning: Equatable, Sendable, Codable {
    public var serie: [String: Int]
    public var slag: Int
    public var fKalla: [String: String]
    public var lodlinjeFel: [String]?
    public var lodlinjeMotVagrata: Double?
    public var hoppat: String?
    public var lodlinje: String?
    public var sampsonPx: Double?
    public var vinkelMellanKamerorna: Double?
    public var vinkelOk: Bool?

    enum CodingKeys: String, CodingKey {
        case serie, slag, hoppat, lodlinje
        case fKalla = "f_kalla", lodlinjeFel = "lodlinje_fel", lodlinjeMotVagrata = "lodlinje_mot_vagrata"
        case sampsonPx = "sampson_px", vinkelMellanKamerorna = "vinkel_mellan_kamerorna", vinkelOk = "vinkel_ok"
    }
}

/// Ett parat slag i `tre_d.slag`: synken, återprojektionen och måtten eller skälet.
public struct TreDSlagRad: Equatable, Sendable, Codable {
    public var dtl: String
    public var fo: String
    public var serie: [String: Int]
    /// DTL:s klocka före FO:s efter klicket, ms (en decimal). METOD MK4
    public var synkMs: Double
    public var aterprojektionPx: Double?
    public var matt: [String: Double]?
    public var fel: String?

    enum CodingKeys: String, CodingKey {
        case dtl, fo, serie, matt, fel
        case synkMs = "synk_ms", aterprojektionPx = "aterprojektion_px"
    }
}

/// M25:s sammanfattning av ett mått över passets slag.
public struct TreDSammanfattning: Equatable, Sendable, Codable {
    public var n: Int
    public var median: Double
    public var q1: Double
    public var q3: Double
    public var sd: Double
    public var min: Double
    public var max: Double
    public var trend: Double
    public var avvikare: [Int]

    public init(_ s: Sammanfattning) {
        n = s.n
        median = s.median
        q1 = s.q1
        q3 = s.q3
        sd = s.sd
        min = s.min
        max = s.max
        trend = s.trend
        avvikare = s.avvikare
    }

    public init(n: Int, median: Double, q1: Double, q3: Double, sd: Double, min: Double, max: Double, trend: Double,
                avvikare: [Int]) {
        self.n = n
        self.median = median
        self.q1 = q1
        self.q3 = q3
        self.sd = sd
        self.min = min
        self.max = max
        self.trend = trend
        self.avvikare = avvikare
    }
}

/// Skillnaden mot förra passet för ett mått. METOD MK7
public struct TreDJamforelse: Equatable, Sendable, Codable {
    public var skillnad: Double
    public var spridning: Double
    public var golv: Double
    public var tydlig: Bool
}

/// 3D för passet: det som analys.json bär som `tre_d` (docs/FORMAT.md). METOD MK1–MK7
public struct TreDResultat: Equatable, Sendable, Codable {
    public var lage: String
    public var minSlag: Int
    public var matt: [String]
    public var parning: TreDParning
    public var kalibrering: [TreDUppstallning]
    public var osaker: [String]
    public var slag: [TreDSlagRad]
    public var n: [String: Int]
    public var session: [String: TreDSammanfattning]
    /// De oavrundade talen per uppställning (nil för en som hoppades över före
    /// kalibreringen), för facit mot Python (METOD M50). Följer inte med i JSON.
    public var inre: [TreDInre?] = []

    enum CodingKeys: String, CodingKey {
        case lage, matt, parning, kalibrering, osaker, slag, n, session
        case minSlag = "min_slag"
    }
}

/// Uppställningens kameror och slagens synk, oavrundade.
public struct TreDInre: Equatable, Sendable {
    /// B:s (DTL:s) läge mot A (FO): x_B = R · x_A + t, |t| = 1.
    public var r: [Double]
    public var t: [Double]
    /// Uppåt i A:s ram.
    public var upp: [Double]
    /// Synken per slag, s.
    public var forsk: [Double]
    /// Återprojektionens median per slag, px (nil = faserna saknas).
    public var aterprojektion: [Double?]
}

/// 3D gick inte för passet: steget, aldrig ett värde (CLAUDE.md, Dataregeln).
public struct TreDFel: Error, Equatable, Sendable {
    public var skal: String
}

/// Två telefoners paket → 3D: parningen, självkalibreringen per uppställning, synken,
/// trianguleringen, måtten och passets median. Rad för rad som tools/pc/tva_kameror.py
/// (BESLUT B12, B48); Python är facit (METOD M50). METOD MK1–MK7
public enum TvaKameror {
    public static let lage = "utan_markorer"           // BESLUT B14
    static let minKonf = 0.3                           // METOD M1
    static let fPx1920 = 1444.0                        // METOD MK3
    static let kalibKonf = 0.5                         // METOD MK3
    static let kalibPar = 5000                         // METOD MK3, M50
    static let kalibStegS = 1.0 / 60                   // METOD MK3
    static let kalibVarv = 2                           // METOD MK4
    public static let vinkelOk = 60.0...120.0          // METOD MK3
    public static let sampsonMaxPx = 8.0               // METOD MK3
    static let lodlinjeMotVagrataMax = 15.0            // METOD MK3
    static let synkSokS = 0.0105                       // METOD MK4
    static let synkSok2S = 0.003                       // METOD MK4
    static let synkStegS = 0.0005                      // METOD MK4
    static let synkFonster = (-0.35, 0.10)             // METOD MK4
    static let synkHalvbredd = 0.02                    // METOD MK4
    static let halvbredd2D = 0.04                      // METOD MK5
    static let halvbreddVinkel = 0.03                  // METOD MK5
    static let rutnatS = 1.0 / 240                     // METOD MK5
    static let kantS = 0.05                            // METOD MK5
    static let minRutor = 10                           // METOD MK5
    public static let minSlag = 10                     // METOD MK7, BESLUT B14
    /// Golvet för en tydlig skillnad mellan två pass, grader. METOD MK7
    public static let trendGolv = ["backen_vrid_topp": 15.7, "brost_vrid_topp": 13.6, "xfaktor_topp": 19.2,
                                   "xfaktor_stretch": 8.1, "hofter_oppna_traff": 8.3]
    static let snabba = [Matt3D.vHandled, Matt3D.hHandled, Matt3D.vArmbage, Matt3D.hArmbage]
    /// Måttens namn i tre_d, i analysens ordning. METOD MK6
    public static let matt = ["backen_vrid_topp", "brost_vrid_topp", "xfaktor_topp", "xfaktor_stretch",
                              "hofter_oppna_traff"]
    static let mats = ["sving", "osaker"]              // METOD MT1
    /// Adressens fönster kring starten, och adressen ur toppen när starten saknas. METOD M4
    static let adress = Faser.adress
    static let toppAdressS = Faser.toppAdressS
    static let ljudetsFart = ClickPairing.speedOfSound

    // MARK: - Slagens spår

    /// Ett parat slag med båda vyernas spår: FO är kamera A, DTL kamera B.
    struct SlagData {
        let dtl: TreDSlag
        let fo: TreDSlag
        let a: Spar2D
        let b: Spar2D
        let ka: [Double]
        let kb: [Double]
        let fKa: String
        let fKb: String
        let traffA: Double
        let traffB: Double
        let vA: (w0: [Double], w: [Double])
        let vB: (w0: [Double], w: [Double])
    }

    /// Träffen i ledernas tid (s relativt klicket). METOD MT1
    static func traffISerien(_ p: TreDPaket, _ s: TreDSlag) -> Double {
        if let tr = s.traffS { return tr - s.klickS }
        if let a = p.avstandM { return -a / ljudetsFart }
        return 0
    }

    /// Slagets leder på träffens tid; en led under 0,3 är saknad. METOD MK2
    static func spar(_ p: TreDPaket, _ s: TreDSlag) -> Spar2D {
        guard let js = s.lederna else { return Spar2D(t: [], uv: [], k: [], j: Matt3D.antalLeder) }
        let traff = traffISerien(p, s)
        let ordning = js.frames.indices.sorted { (js.frames[$0].t, $0) < (js.frames[$1].t, $1) }
        let j = Matt3D.antalLeder
        var t: [Double] = [], uv: [Double] = [], k: [Double] = []
        for i in ordning {
            let r = js.frames[i]
            let ti = r.t - traff
            if let sista = t.last, sista == ti { continue }          // två rutor på samma tid: den första
            t.append(ti)
            for l in 0..<j {
                if l < r.joints.count, let led = r.joints[l], led.c >= minKonf {
                    uv.append(led.x)
                    uv.append(led.y)
                    k.append(led.c)
                } else {
                    uv.append(.nan)
                    uv.append(.nan)
                    k.append(0)
                }
            }
        }
        return Spar2D(t: t, uv: uv, k: k, j: j)
    }

    /// Slagets K ur seriens synfält, annars enhet.json, annars specifikationen. METOD MK3
    static func kFor(_ p: TreDPaket, _ s: TreDSlag) -> (k: [Double], kalla: String) {
        let w = Double(s.lederna?.width ?? 1080), h = Double(s.lederna?.height ?? 1920)
        let lang = max(w, h)
        var f = fPx1920 * lang / 1920.0
        var kalla = "specifikationen"
        if let sf = p.serier[s.serie]?.synfalt {
            f = (lang / 2) / tan(sf.grader * (Double.pi / 180) / 2)
            kalla = "serien"
        } else if let sf = p.enhetSynfalt {
            f = (lang / 2) / tan(sf.grader * (Double.pi / 180) / 2)
            kalla = "enhet.json"
        }
        return ([f, 0, w / 2, 0, f, h / 2, 0, 0, 1], kalla)
    }

    static func rutnat(_ ta: [Double], _ tb: [Double], _ steg: Double = rutnatS) -> [Double] {
        guard let a0 = ta.first, let b0 = tb.first, let a1 = ta.last, let b1 = tb.last else { return [] }
        let a = max(a0, b0) + kantS, b = min(a1, b1) - kantS
        guard b > a else { return [] }
        return LA.arange(a, b, steg)
    }

    /// Båda vyerna utjämnade (±40 ms) på en gemensam tidsaxel, DTL flyttad med synken.
    static func jamnade(_ d: SlagData, _ forsk: Double, _ steg: Double = rutnatS)
        -> (t: [Double], a: [Double], ka: [Double], b: [Double], kb: [Double]) {
        let bs = d.b.flyttat(forsk)
        let tg = rutnat(d.a.t, bs.t, steg)
        let (a, ka) = Utjamning.jamna(d.a, tg, halvbredd2D, vikter: d.vA)
        let (b, kb) = Utjamning.jamna(bs, tg, halvbredd2D, vikter: d.vB)
        return (tg, a, ka, b, kb)
    }

    /// k av n punktpar, jämnt spridda: ⌊i · n / k⌋. METOD M50, BESLUT B48
    public static func urval(_ n: Int, _ k: Int) -> [Int] {
        (0..<k).map { $0 * n / k }
    }

    // MARK: - Kalibreringen

    struct Kalib {
        var r: [Double]
        var t: [Double]
        var upp: [Double]
        var kalla: String
        var sampsonPx: Double
        var vinkel: Double
        var motVagrata: Double?
        var lodlinjeFel: [String]
    }

    /// Kamerorna för en uppställning ur dess slags leder ihop. Som `kalibrera`. METOD MK3
    static func kalibrera(_ slagen: [SlagData], _ forsk: [Double], _ uppA: [Double]?, _ uppB: [Double]?) throws -> Kalib {
        var x1: [Double] = [], x2: [Double] = [], w: [Double] = []
        for (d, f) in zip(slagen, forsk) {
            let (_, a, ka, b, kb) = jamnade(d, f, kalibStegS)
            let ia = try LA.inv(d.ka, 3), ib = try LA.inv(d.kb, 3)
            for i in 0..<ka.count {
                guard a[i * 2].isFinite, a[i * 2 + 1].isFinite, b[i * 2].isFinite, b[i * 2 + 1].isFinite,
                      ka[i] > kalibKonf, kb[i] > kalibKonf else { continue }
                let ua = a[i * 2], va = a[i * 2 + 1], ub = b[i * 2], vb = b[i * 2 + 1]
                x1.append(ua * ia[0] + va * ia[1] + ia[2])
                x1.append(ua * ia[3] + va * ia[4] + ia[5])
                x1.append(ua * ia[6] + va * ia[7] + ia[8])
                x2.append(ub * ib[0] + vb * ib[1] + ib[2])
                x2.append(ub * ib[3] + vb * ib[4] + ib[5])
                x2.append(ub * ib[6] + vb * ib[7] + ib[8])
                w.append((ka[i] * kb[i]).squareRoot())
            }
        }
        if w.count > kalibPar {
            let val = urval(w.count, kalibPar)
            x1 = val.flatMap { [x1[$0 * 3], x1[$0 * 3 + 1], x1[$0 * 3 + 2]] }
            x2 = val.flatMap { [x2[$0 * 3], x2[$0 * 3 + 1], x2[$0 * 3 + 2]] }
            w = val.map { w[$0] }
        }
        let fPx = LA.median(slagen.map { $0.ka[0] })
        let lang = LA.median(slagen.map { max($0.ka[2], $0.ka[5]) * 2 })
        let rel: (r: [Double], t: [Double], sampson: Double)
        do {
            rel = try Kalibrering.relativUrNormerade(x1, x2, w, fPx: fPx)
        } catch {
            throw TreDFel(skal: "kalibreringen: för få leder syns i båda vyerna")
        }
        let r = rel.r, t = rel.t
        let vagrata = Kalibrering.uppUrVagrata(r)
        var upp: [Double]?
        var kalla = "kamerornas_vagrata"
        var motVagrata: Double?
        var fel: [String] = []
        if uppA != nil || uppB != nil {
            var u = uppA ?? [0, 0, 0]
            if let ub = uppB {
                let rt = LA.mulv3(LA.transp(r, 3, 3), ub)
                u = uppA == nil ? rt : [u[0] + rt[0], u[1] + rt[1], u[2] + rt[2]]
            }
            upp = u
            kalla = "manifest"
            if let vagrata {
                let c = min(max(LA.dot3(u, vagrata) / LA.norm3(u), -1), 1)
                let avvik = Matt3D.grader(acos(c))
                motVagrata = LA.avrunda(avvik, 1)
                if avvik > lodlinjeMotVagrataMax {
                    upp = nil
                    kalla = "kamerornas_vagrata"
                    fel.append("lodlinjen i manifestet avviker mer än 15° från kamerornas vågräta")
                }
            }
        }
        if upp == nil {
            guard let vagrata else { throw TreDFel(skal: "kalibreringen: kamerorna står för nära samma riktning") }
            upp = vagrata
        }
        let (kamA, kamB) = Kalibrering.varld(LA.enhet3, LA.enhet3, r, t, upp!)
        let fa = [kamA.r[6], kamA.r[7], 0.0], fb = [kamB.r[6], kamB.r[7], 0.0]
        let c = min(max(LA.dot3(fa, fb) / (LA.norm3(fa) * LA.norm3(fb)), -1), 1)
        let vinkel = Matt3D.grader(acos(c))
        return Kalib(r: r, t: t, upp: upp!, kalla: kalla, sampsonPx: rel.sampson * fPx * 1920.0 / lang,
                     vinkel: vinkel, motVagrata: motVagrata, lodlinjeFel: fel)
    }

    static func kameror(_ d: SlagData, _ k: Kalib) -> (Kamera3D, Kamera3D) {
        Kalibrering.varld(d.ka, d.kb, k.r, k.t, k.upp)
    }

    /// DTL:s klocka före FO:s efter klicket (s), på minsta återprojektionsfel. METOD MK4
    static func synka(_ kam: (Kamera3D, Kamera3D), _ d: SlagData, _ mitt: Double, _ sok: Double) -> Double {
        guard let v = Triangulering.synkReprojektion([kam.0, kam.1], d.a, d.b.flyttat(mitt), snabba, synkFonster, sok,
                                                     synkStegS, synkHalvbredd) else { return mitt }
        return mitt + v
    }

    /// Slagets 3D-leder på den gemensamma tidsaxeln och återprojektionens median. METOD MK5
    static func triangulera(_ kam: (Kamera3D, Kamera3D), _ d: SlagData, _ forsk: Double)
        -> (t: [Double], p: [Double], rep: Double) {
        let (tg, a, ka, b, kb) = jamnade(d, forsk)
        let antal = tg.count * Matt3D.antalLeder
        let p = Triangulering.triangulera([kam.0, kam.1], [a, b], [ka, kb], antal)
        let e = Triangulering.aterprojektionsfel([kam.0, kam.1], p, [a, b], antal)
        let fin = (e[0] + e[1]).filter { $0.isFinite }
        return (tg, p, fin.isEmpty ? .nan : LA.median(fin))
    }

    // MARK: - Måtten

    /// Baksvingens start på träffens tid: FO:s, annars DTL:s flyttad med synken, annars
    /// toppen − 1,2 s. METOD MK6
    static func start(_ fo: Faser2D?, _ dtl: Faser2D?, _ d: SlagData, _ forsk: Double) -> Double? {
        let par = [(fo, d.traffA), (dtl, d.traffB + forsk)]
        for (f, skift) in par { if let s = f?.start { return s - skift } }
        for (f, skift) in par { if let t = f?.topp { return t - skift - toppAdressS } }
        return nil
    }

    /// Måtten ur 3D-lederna, eller skälet. En vänsterspelare speglas. METOD MK6
    static func matt(_ t: [Double], _ p: [Double], _ tStart: Double, _ hand: Hand) -> Result<[String: Double], TreDFel> {
        let adr = (tStart + adress.fran, tStart + adress.till)
        guard let f = t.first, let l = t.last, f <= adr.0, l >= 0.0 else {
            return .failure(TreDFel(skal: "adressen eller träffen ligger utanför slagets tid"))
        }
        var q = p
        if hand == .vanster {
            for i in 0..<(q.count / 3) { q[i * 3] *= -1 }
        }
        let m = Matt3D.svingmatt(q, t, tStart, 0.0, adr, utjamna: halvbreddVinkel)
        var ut: [String: Double] = [:]
        for (namn, v) in zip(matt, [m.backenTopp, m.brostTopp, m.xfaktorTopp, m.stretch, m.hofterOppnaTraff])
            where v.isFinite {
            ut[namn] = v
        }
        return .success(ut)
    }

    // MARK: - Passet

    static func uppstallning(_ dtl: TreDPaket, _ fo: TreDPaket, _ grupp: [SlagData], _ faser: [String: Faser2D])
        -> (TreDUppstallning, [TreDSlagRad], TreDInre?) {
        let sd = grupp[0].dtl.serie, sf = grupp[0].fo.serie
        var info = TreDUppstallning(serie: ["dtl": sd, "fo": sf], slag: grupp.count,
                                    fKalla: ["dtl": grupp[0].fKb, "fo": grupp[0].fKa])
        let fel = [fo.serier[sf]?.lodlinjeFel, dtl.serier[sd]?.lodlinjeFel].compactMap { $0 }
        if !fel.isEmpty { info.lodlinjeFel = fel }
        let uppA = enhetsvektor(fo.serier[sf]?.lodlinje), uppB = enhetsvektor(dtl.serier[sd]?.lodlinje)
        var forsk = [Double](repeating: 0, count: grupp.count)
        let k: Kalib
        do {
            for varv in 0..<kalibVarv {
                let kv = try kalibrera(grupp, forsk, uppA, uppB)
                let sok = varv == 0 ? synkSokS : synkSok2S
                forsk = zip(grupp, forsk).map { d, f in synka(kameror(d, kv), d, f, sok) }
            }
            k = try kalibrera(grupp, forsk, uppA, uppB)
        } catch {
            info.hoppat = (error as? TreDFel)?.skal ?? "kalibreringen: för få leder syns i båda vyerna"
            return (info, [], nil)
        }
        var inre = TreDInre(r: k.r, t: k.t, upp: k.upp, forsk: forsk, aterprojektion: [])
        info.lodlinje = k.kalla
        info.sampsonPx = LA.avrunda(k.sampsonPx, 2)
        info.vinkelMellanKamerorna = LA.avrunda(k.vinkel, 1)
        info.vinkelOk = vinkelOk.contains(k.vinkel)
        info.lodlinjeMotVagrata = k.motVagrata
        if !k.lodlinjeFel.isEmpty { info.lodlinjeFel = (info.lodlinjeFel ?? []) + k.lodlinjeFel }
        if info.sampsonPx! > sampsonMaxPx {
            info.hoppat = "kalibreringen: Sampson-felet är över spärren"
            return (info, [], inre)
        }
        var ut: [TreDSlagRad] = []
        for (d, f) in zip(grupp, forsk) {
            var r = TreDSlagRad(dtl: d.dtl.id, fo: d.fo.id, serie: ["dtl": sd, "fo": sf],
                                synkMs: LA.avrunda(f * 1000, 1))
            guard let tStart = start(faser["fo/" + d.fo.id], faser["dtl/" + d.dtl.id], d, f) else {
                r.fel = "faserna saknas i båda vyerna"
                ut.append(r)
                inre.aterprojektion.append(nil)
                continue
            }
            let (tg, p, rep) = triangulera(kameror(d, k), d, f)
            inre.aterprojektion.append(rep)
            r.aterprojektionPx = rep.isFinite ? LA.avrunda(rep, 1) : nil
            switch matt(tg, p, tStart, dtl.spelhand) {
            case .success(let m): r.matt = m
            case .failure(let e): r.fel = e.skal
            }
            ut.append(r)
        }
        return (info, ut, inre)
    }

    static func enhetsvektor(_ v: [Double]?) -> [Double]? {
        guard let v else { return nil }
        let n = LA.norm3(v)
        return v.map { $0 / n }
    }

    /// 3D för passet ur två telefoners paket och 2D-fasernas start och topp per slag
    /// (nyckel "dtl/s01", "fo/s01"). Kastar TreDFel när 3D inte går (skälet i
    /// `tre_d.hoppat`). METOD MK1–MK7
    public static func analysera(dtl: TreDPaket, fo: TreDPaket, faser: [String: Faser2D]) throws -> TreDResultat {
        let (par, parning) = Parning.paraSlag(dtl, fo)
        var grupper: [String: [SlagData]] = [:]
        var nycklar: [(Int, Int)] = []
        for (sd, sf) in par {
            guard mats.contains(sd.dom), mats.contains(sf.dom), !sd.detectionWrong, !sf.detectionWrong,
                  sd.lederna != nil, sf.lederna != nil else { continue }
            let a = spar(fo, sf), b = spar(dtl, sd)
            if min(a.n, b.n, rutnat(a.t, b.t).count) < minRutor { continue }
            let (ka, fKa) = kFor(fo, sf), (kb, fKb) = kFor(dtl, sd)
            let d = SlagData(dtl: sd, fo: sf, a: a, b: b, ka: ka, kb: kb, fKa: fKa, fKb: fKb,
                             traffA: traffISerien(fo, sf), traffB: traffISerien(dtl, sd),
                             vA: Utjamning.robustaVikter(a, halvbredd2D), vB: Utjamning.robustaVikter(b, halvbredd2D))
            let nyckel = "\(sd.serie)-\(sf.serie)"
            if grupper[nyckel] == nil { nycklar.append((sd.serie, sf.serie)) }
            grupper[nyckel, default: []].append(d)
        }
        guard !grupper.isEmpty else {
            throw TreDFel(skal: "parningen: inga slag som båda telefonerna filmat och som går att mäta")
        }
        var kalib: [TreDUppstallning] = [], utSlag: [TreDSlagRad] = [], osaker: [String] = []
        var inre: [TreDInre?] = []
        for (sd, sf) in nycklar.sorted(by: { $0 < $1 }) {
            let (info, ut, i) = uppstallning(dtl, fo, grupper["\(sd)-\(sf)"]!, faser)
            kalib.append(info)
            utSlag += ut
            inre.append(i)
            let namn = "serie \(sd) (DTL) mot \(sf) (FO)"
            if info.hoppat == nil && info.vinkelOk == false {
                osaker.append("\(namn): vinkeln mellan kamerorna utanför 60–120°")
            }
            if let f = info.lodlinjeFel, !f.isEmpty { osaker.append("\(namn): lodlinjen i manifestet användes inte") }
        }
        guard !utSlag.isEmpty else { throw TreDFel(skal: "kalibreringen: ingen serie gick att kalibrera under spärren") }
        let matta = utSlag.compactMap(\.matt)
        let sammanf = Session.sammanfatta(matta)
        var n: [String: Int] = [:]
        for m in matt { n[m] = matta.filter { $0[m] != nil }.count }
        var session: [String: TreDSammanfattning] = [:]
        for (k, v) in sammanf where v.n >= minSlag { session[k] = TreDSammanfattning(v) }
        var r = TreDResultat(lage: lage, minSlag: minSlag, matt: matt, parning: parning, kalibrering: kalib,
                             osaker: osaker, slag: utSlag, n: n, session: session)
        r.inre = inre
        return r
    }

    /// Trenden mot förra passet: skillnaden i median (M26) och om den är tydlig, alltså
    /// större än både förra passets spridning och golvet. METOD MK7
    public static func jamfor(_ nu: [String: TreDSammanfattning], _ forra: [String: TreDSammanfattning])
        -> [String: TreDJamforelse] {
        var ut: [String: TreDJamforelse] = [:]
        for (k, a) in nu {
            guard let b = forra[k] else { continue }
            let skillnad = a.median - b.median
            let spridning = (b.q3 - b.q1) / Session.iqrSkala
            let golv = trendGolv[k] ?? 0
            ut[k] = TreDJamforelse(skillnad: skillnad, spridning: spridning, golv: golv,
                                   tydlig: abs(skillnad) > max(spridning, golv))
        }
        return ut
    }
}
