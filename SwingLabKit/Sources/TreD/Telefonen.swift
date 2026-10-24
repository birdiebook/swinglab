import Capture
import Foundation
import Swing

// 3D på telefonen (S6c-2, BESLUT B61, B62, METOD MS19): den räknande telefonen har sitt eget
// pass och den andra telefonens slag (`SlagBunt`, över kopplingen eller ur zippen). 2D-faserna
// räknas här ur samma leder som PC:n mäter (analys.mat_paket), och resultatet sparas som
// `tre_d.json` i båda telefonernas pass och följer med paketet till PC:n, som jämför (B61).

/// En telefons paket som 3D läser det: manifestet, lederna per slag, par.json och enhet.json.
public struct TreDIndata: Sendable {
    public var manifest: Data
    public var lederna: [String: JointSeries]
    public var par: Data?
    public var enhet: Data?

    public init(manifest: Data, lederna: [String: JointSeries], par: Data? = nil, enhet: Data? = nil) {
        self.manifest = manifest
        self.lederna = lederna
        self.par = par
        self.enhet = enhet
    }

    /// Ur en bunt (den andra telefonens slag, eller den egna, METOD MS19).
    public init(_ b: SlagBunt) throws {
        self.init(manifest: b.manifestData, lederna: try b.lederna(), par: b.parData, enhet: b.enhetData)
    }
}

/// Den räknande telefonens väg till 3D. METOD MS19
public enum TreDTelefon {
    /// 2D-fasernas start och topp per slag ("dtl/s01"), som PC:ns `analys.mat_paket` och
    /// `paket.till_sving`: slagen med domen sving eller osaker, inte "Detection wrong", mätta med
    /// `Matt.mat` med träffen ur manifestet och längden `langdM`. Ett slag som inte går att mäta
    /// får inga faser (då tar 3D den andra vyns, MK6). METOD M4, MK6, MT1
    public static func faser(_ p: TreDPaket, langdM: Double) -> [String: Faser2D] {
        var ut: [String: Faser2D] = [:]
        for s in p.slag where TvaKameror.mats.contains(s.dom) && !s.detectionWrong {
            guard let js = s.lederna,
                  let sv = try? ShotMeasuring.sving(js, view: p.vy, hand: p.spelhand, heightM: langdM,
                                                    impact: TvaKameror.traffISerien(p, s)),
                  let r = try? Matt.mat(sv) else { continue }
            var pos: [String: Double] = [:]
            for namn in Positioner.namn {
                if let v = r.positioner.tid(namn), v.isFinite { pos[namn] = v }
            }
            ut["\(p.vy.rawValue)/\(s.id)"] = Faser2D(start: r.faser.start, topp: r.faser.topp, positioner: pos)
        }
        return ut
    }

    /// 3D ur två telefoners paket, i vilken ordning som helst. Längden till 2D-faserna är
    /// `langdM` (den räknande telefonens pass), annars DTL:s manifests, annars FO:s, annars
    /// standarden 1,80 m (PC:n: första paketets). Varje fel blir `hoppat` med skälet. Tung:
    /// körs i `Task.detached` (PLAN S6c). METOD MK1–MK7, MS19
    public static func rakna(_ a: TreDIndata, _ b: TreDIndata, langdM: Double? = nil) -> TreDUt {
        rakna(a, b, langdM: langdM, figur: false).ut
    }

    /// Som `rakna`, och med `figur` också figuren (S6d): kamerorna per uppställning och lederna
    /// per slag, eller bara skälet (BESLUT B72). Figuren är nil när räkningen avbröts eller inte
    /// begärdes. METOD MK10
    public static func rakna(_ a: TreDIndata, _ b: TreDIndata, langdM: Double? = nil, figur: Bool)
        -> (ut: TreDUt, figur: TreDFigurer?) {
        let samlare = figur ? TreDFigurSamlare() : nil
        var hand = Hand.hoger, langd = langdM ?? ShotMeasuring.assumedHeightM
        var f2d: [String: Faser2D] = [:]
        let ut: TreDUt
        do {
            let pa = try TreDPaket.las(manifest: a.manifest, lederna: a.lederna, par: a.par, enhet: a.enhet)
            let pb = try TreDPaket.las(manifest: b.manifest, lederna: b.lederna, par: b.par, enhet: b.enhet)
            guard Set([pa.vy, pb.vy]) == [.dtl, .fo] else {
                throw TreDFel(skal: "parningen: paketen ska vara ett DTL- och ett FO-paket")
            }
            let (dtl, fo) = pa.vy == .dtl ? (pa, pb) : (pb, pa)
            hand = dtl.spelhand
            langd = langdM ?? dtl.spelarensLangdM ?? fo.spelarensLangdM ?? ShotMeasuring.assumedHeightM
            f2d = Self.faser(dtl, langdM: langd).merging(Self.faser(fo, langdM: langd)) { x, _ in x }
            ut = .resultat(try TvaKameror.analysera(dtl: dtl, fo: fo, faser: f2d, samlare: samlare))
        } catch let e as TreDPaketFel {
            ut = .hoppat(e.skal)
        } catch let e as TreDFel {
            ut = .hoppat(e.skal)
        } catch {
            ut = .hoppat("3D gick inte (\(type(of: error)))")
        }
        guard let samlare else { return (ut, nil) }
        var skal: String?
        if case let .hoppat(s) = ut { skal = s }
        return (ut, TreDFigurer.bygg(samlare, hand: hand, faser: f2d, langd: langd, hoppat: skal))
    }
}

/// `tre_d.json` i passets mapp och i den styrande telefonens paket (docs/FORMAT.md,
/// `swinglab-tre-d/1`): 3D som telefonen räknade, eller skälet. METOD MS19
public struct TreDFil: Codable, Equatable, Sendable {
    public static let formatName = "swinglab-tre-d/1"
    public static let filnamn = "tre_d.json"

    public var format: String
    public var pass: String
    /// När telefonen räknade, ISO 8601 i UTC.
    public var raknad: String
    /// Vyn på telefonen som räknade.
    public var raknadAv: Vy
    /// Buntarnas summor (`Overforing.summa`) per vy, "dtl" och "fo": ett pass vars slag
    /// ändrats räknas om.
    public var kallor: [String: String]
    /// Tiden för räkningen, s (METOD M50).
    public var sekunder: Double?
    public var treD: TreDResultat?
    public var hoppat: String?
    /// De oavrundade talen per uppställning (`TreDInre`), så att PC:n kan redovisa grenar som
    /// slog om (BESLUT B63, METOD MS19).
    public var inre: [TreDInre?]?

    enum CodingKeys: String, CodingKey {
        case format, pass, raknad, kallor, sekunder, hoppat, inre
        case raknadAv = "raknad_av", treD = "tre_d"
    }

    public init(pass: String, raknad: Date, raknadAv: Vy, kallor: [String: String], sekunder: Double?, ut: TreDUt) {
        format = Self.formatName
        self.pass = pass
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        self.raknad = f.string(from: raknad)
        self.raknadAv = raknadAv
        self.kallor = kallor
        self.sekunder = sekunder
        switch ut {
        case let .resultat(r):
            treD = r
            inre = r.inre
        case let .hoppat(s): hoppat = s
        }
    }

    /// Som paketets filer: sorterade nycklar och indrag, så att PC:n och Johannes kan läsa den.
    public func data() throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try e.encode(self)
    }

    public static func las(_ d: Data) throws -> TreDFil {
        guard let f = try? JSONDecoder().decode(TreDFil.self, from: d) else {
            throw OverforingFel("\(filnamn): går inte att läsa")
        }
        guard f.format == formatName else { throw OverforingFel("\(filnamn): format ska vara \(formatName)") }
        guard (f.treD == nil) != (f.hoppat == nil) else { throw OverforingFel("\(filnamn): tre_d eller hoppat") }
        return f
    }

    /// Passets median per 3D-mått, för pass.json (Progress och förra passet). METOD MK7
    public var medianer: [String: TreDMedian]? {
        guard let r = treD else { return nil }
        var ut: [String: TreDMedian] = [:]
        for m in r.matt {
            let s = r.session[m]
            ut[m] = TreDMedian(n: r.n[m] ?? 0, median: s?.median, q1: s?.q1, q3: s?.q3)
        }
        return ut
    }

    /// Filen hör till de här buntarna.
    public func galler(_ kallor: [String: String]) -> Bool { self.kallor == kallor }
}

/// Passets kort "3D" (S6c-2, BESLUT B62): de fem måtten med passets median, skillnaden mot
/// förra passet och antalet svingar, och skälen kort och i grått. Inget tal där skälet säger
/// nej: inget tal alls när 3D hoppades över, och inget för ett mått med färre än `min_slag`
/// svingar (BESLUT B14). Inga gränser och inget grönt eller rött (B37). METOD MK7, MS19
public struct TreDKort: Equatable, Sendable {
    public struct Rad: Equatable, Sendable, Identifiable {
        public let matt: String
        public let namn: String
        /// "41.2" eller nil (inget tal).
        public let varde: String?
        public let enhet: String
        /// "+3.1° vs Nov 10".
        public let mot: String?
        /// Skillnaden är större än förra passets spridning och golvet (MK7).
        public let tydlig: Bool
        public let n: Int
        public let info: Infoblad?
        public var id: String { matt }
    }

    public let rubrik: String
    public let rader: [Rad]
    /// "12 swings", nil när 3D hoppades över.
    public let svingar: String?
    public let skal: [String]

    /// `forra` = förra passet med 3D (samma klubba, vy och längd, `PassHistory.earlierTreD`).
    /// `aktuell` = filen gäller passets slag som de är nu; annars visas inga tal, bara "Updating…"
    /// (S6c-2, METOD MS19).
    public init(_ fil: TreDFil, forra: (datum: Date, median: [String: TreDMedian])? = nil, katalog: Katalog? = nil,
                aktuell: Bool = true) {
        rubrik = Texter.treDRubrik
        guard aktuell else {
            rader = (katalog?.treD.map(\.matt) ?? TvaKameror.matt).map { m in
                let e = Etiketter.etikett(m)
                return Rad(matt: m, namn: e.namn, varde: nil, enhet: e.enhet, mot: nil, tydlig: false, n: 0,
                           info: katalog?.treD.first { $0.matt == m }.map { Infoblad($0, namn: e.namn) })
            }
            svingar = nil
            skal = [Texter.treDUppdateras]
            return
        }
        guard let r = fil.treD else {
            rader = []
            svingar = nil
            skal = [Self.hoppat(fil.hoppat ?? "")]
            return
        }
        let poster = katalog?.treD ?? []
        let ordning = poster.isEmpty ? r.matt : poster.map(\.matt)
        var ut: [Rad] = []
        for m in ordning {
            let e = Etiketter.etikett(m)
            let post = poster.first { $0.matt == m }
            let s = r.session[m]
            var mot: String?
            var tydlig = false
            if let s, let f = forra, let fm = f.median[m], let v = fm.median {
                let d = (Avrundning.avrunda(m, s.median) ?? 0) - (Avrundning.avrunda(m, v) ?? 0)
                mot = Texter.mot(Tal.medEnhet(Tal.tecken(d, decimaler: e.decimaler), e.enhet), Tal.datum(f.datum))
                let spridning = (fm.q1 != nil && fm.q3 != nil) ? (fm.q3! - fm.q1!) / Session.iqrSkala : 0
                tydlig = abs(s.median - v) > max(spridning, TvaKameror.trendGolv[m] ?? 0)
            }
            ut.append(Rad(matt: m, namn: e.namn, varde: s.map { Mattkort.text($0.median, e) }, enhet: e.enhet,
                          mot: mot, tydlig: tydlig, n: r.n[m] ?? 0, info: post.map { Infoblad($0, namn: e.namn) }))
        }
        rader = ut
        let n = r.n.values.max() ?? 0
        svingar = Texter.svingar(n)
        var sk: [String] = []
        if n < r.minSlag { sk.append(Texter.treDFarre(r.minSlag)) }
        for k in r.kalibrering where k.hoppat != nil {
            sk.append(Texter.treDSerie(k.serie["dtl"] ?? 0, k.serie["fo"] ?? 0))
        }
        for o in r.osaker {
            sk.append(o.contains("vinkeln") ? Texter.treDVinkel : Texter.treDLutning)
        }
        let bort = r.utelamnade.count + r.slag.filter { $0.matt == nil }.count
        if bort > 0 { sk.append(Texter.treDUtelamnade(bort)) }
        var sedda = Set<String>()
        skal = sk.filter { sedda.insert($0).inserted }
    }

    /// Skälet till att 3D hoppades över, kort (TvaKameror, TreDPaketFel; METOD M51).
    static func hoppat(_ s: String) -> String {
        if s.contains("inga slag som båda") { return Texter.treDInteParat }
        if s.hasPrefix("kalibreringen") { return Texter.treDKalibrering }
        if s.contains("ett DTL- och ett FO-paket") { return Texter.treDVyerna }
        if s.contains("manifest.json") || s.contains("par.json") || s.contains(".json") { return Texter.treDPaketet }
        return Texter.treDInte
    }
}
