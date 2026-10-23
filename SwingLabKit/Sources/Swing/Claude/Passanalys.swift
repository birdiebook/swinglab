import Foundation

/// Ett slag som analysen läser: vyn, klubban, måtten och om det hör till första serien
/// (de fem första mätta slagen i serie 1, METOD MT2).
public struct Slagrad: Sendable {
    public let vy: Vy
    public let klubba: String?
    public let matt: [String: Double]
    public let forstaSerien: Bool

    public init(vy: Vy, klubba: String?, matt: [String: Double], forstaSerien: Bool) {
        self.vy = vy
        self.klubba = klubba
        self.matt = matt
        self.forstaSerien = forstaSerien
    }
}

/// Ett pass som analysen läser: id:t (`yyyyMMdd-HHmmss`) och de mätta slagen i passets ordning.
public struct Passrader: Sendable {
    public let pass: String
    public let slag: [Slagrad]

    public init(pass: String, slag: [Slagrad]) {
        self.pass = pass
        self.slag = slag
    }
}

/// Passets analys på telefonen: samma räkning som `analysera_rader` i tools/pc/analys.py
/// (BESLUT B12, BESLUT B53), med det som underlaget till Claude-appen och kontrollen av svaret
/// läser: sessionen, första serien, spridningen, bedömningen med "klart när" och kandidaterna.
/// METOD M25–M27, METOD MT2, MT3, MT6, MT9
public struct Passanalys: Sendable {
    /// "Klart när" som analysen föreslår det (METOD MT3).
    public struct KlartNarForslag: Sendable {
        /// ">=", "<=" eller "mellan".
        public let villkor: String
        /// Ett tal, eller [min, max] för `mellan`.
        public let grans: JSONVarde
        /// "grans", "baslinje" eller "nu".
        public let grund: String
        /// nil (kontrollerad gräns), "B10" eller "egen".
        public let markning: String?
    }

    /// Ett fel bedömt i passet, som en rad i analysens `bedomning`.
    public struct Rad: Sendable {
        public let id: String
        public let vy: String
        public let matt: String
        public let fas: String
        public let enhet: String
        public let status: Bedomningsstatus
        public let grund: String?
        public let z: Double?
        public let n: Int
        /// Passets median avrundad som den visas (METOD MT3).
        public let visat: Double?
        public let forstaSerien: Double?
        public let spann: [Double?]?
        public let gult: [Double?]?
        public let klartNar: KlartNarForslag?
        /// Den egna baslinjen: median, robust sd och svingar (avrundade), nil med gräns.
        public let baslinje: (median: Double?, sd: Double?, n: Int)?
        public let motForra: (skillnad: Double?, tydlig: Bool)?
    }

    /// Ett flaggat fel i läsordning (METOD MT6).
    public struct Kandidat: Sendable {
        public let fel: String
        public let status: Bedomningsstatus
        public let fas: String
        /// Flaggade orsaker med vägen genom kedjan, i den ordning kedjorna hittar dem.
        public let orsaker: [(fel: String, vag: [String])]
        public let foljdfel: Bool
        public let fysik: [String]
    }

    public struct Spridningsrad: Sendable {
        public let matt: String
        public let vy: String
        public let klubba: String?
        public let n: Int
        public let visat: Double?
    }

    public let pass: String
    public let klubbor: [String]
    public let slag: [Slagrad]
    /// "dtl" eller "fo": vyn som gruppen alla tas ur (METOD MT9).
    public let tempoVy: String
    public let session: [String: [String: Sammanfattning]]
    public let forstaSerien: [String: [String: Sammanfattning]]
    public let spridning: [Spridningsrad]
    public let baslinjePass: [String]
    public let baslinjeSvingar: [String: Int]
    public let forra: String?
    public let bedomning: [Rad]
    public let kandidater: [Kandidat]

    /// De mätta svingarna, som baslinjen för senare pass (analys.svingar).
    public var svingar: [SvingMatt] { slag.map { SvingMatt(vy: $0.vy, matt: $0.matt) } }

    public func rad(_ id: String) -> Rad? { bedomning.first { $0.id == id } }

    /// Vyn med flest slag med tempo, FO vid lika. METOD MT9
    static func tempoVy(_ slag: [Slagrad]) -> String {
        let dtl = slag.filter { $0.vy == .dtl && $0.matt["tempo"] != nil }.count
        let fo = slag.filter { $0.vy == .fo && $0.matt["tempo"] != nil }.count
        return dtl > fo ? "dtl" : "fo"
    }

    static func sammanfatta(_ slag: [Slagrad], _ vyAlla: String) -> [String: [String: Sammanfattning]] {
        func m(_ vy: Vy) -> [[String: Double]] { slag.filter { $0.vy == vy }.map(\.matt) }
        return ["dtl": Session.sammanfatta(m(.dtl)), "fo": Session.sammanfatta(m(.fo)),
                "alla": Session.sammanfatta(m(Vy(rawValue: vyAlla) ?? .fo))]
    }

    static func grupp(_ vy: String) -> String { vy == "bada" ? "alla" : vy }

    /// Passets analys. `tidigare` = svingarna ur de tidigare passen (baslinjen, M27),
    /// `forra` = förra passets analys. Som `analysera_rader` i Python.
    public init(_ p: Passrader, tidigare: [SvingMatt], forra: Passanalys?, baslinjePass: [String],
                katalog: Katalog, kedjor: Kedjor = .appens) {
        pass = p.pass
        slag = p.slag
        klubbor = Set(p.slag.compactMap { $0.klubba }.filter { !$0.isEmpty }).sorted()
        let vyAlla = Self.tempoVy(p.slag)
        tempoVy = vyAlla
        let sammanf = Self.sammanfatta(p.slag, vyAlla)
        let forsta = Self.sammanfatta(p.slag.filter(\.forstaSerien), vyAlla)
        session = sammanf
        forstaSerien = forsta
        // Spridningen mellan slagen per klubba (METOD M44, BESLUT B46).
        var spr: [Spridningsrad] = []
        let klubborna = Set(p.slag.map { $0.klubba ?? "\u{0}" }).sorted { ($0 == "\u{0}" ? "" : $0) < ($1 == "\u{0}" ? "" : $1) }
        for k0 in klubborna {
            let k: String? = k0 == "\u{0}" ? nil : k0
            let sv = p.slag.filter { $0.klubba == k }.map { SvingMatt(vy: $0.vy, matt: $0.matt) }
            for s in Spridning.pass(katalog, sv) {
                spr.append(Spridningsrad(matt: s.matt, vy: s.vy, klubba: k, n: s.n,
                                         visat: Avrundning.avrunda(s.matt, s.varde)))
            }
        }
        spridning = spr
        self.baslinjePass = baslinjePass
        baslinjeSvingar = ["dtl": tidigare.filter { $0.vy == .dtl }.count, "fo": tidigare.filter { $0.vy == .fo }.count]
        self.forra = forra?.pass
        var jamforelse: [String: [String: Jamforelse]] = [:]
        if let f = forra {
            for g in Session.grupper { jamforelse[g] = Session.jamfor(nu: sammanf[g] ?? [:], forra: f.session[g] ?? [:]) }
        }
        var bed: [Rad] = []
        for fel in katalog.fel {
            let g = Self.grupp(fel.vy), m = fel.matt
            let vy = fel.vy == "bada" ? vyAlla : fel.vy
            let bas = tidigare.compactMap { s -> Double? in s.vy.rawValue == vy ? s.matt[m] : nil }
            let sn = sammanf[g]?[m]
            let fs = forsta[g]?[m]
            let b = Bedomare.bedom(fel, varde: sn?.median, baslinje: bas)
            var mot: (skillnad: Double?, tydlig: Bool)? = nil
            if forra != nil, let j = jamforelse[g]?[m] {
                mot = (Avrundning.avrunda(m, j.skillnad), j.tydlig)
            }
            bed.append(Rad(id: fel.id, vy: fel.vy, matt: m, fas: fel.fas, enhet: Avrundning.enhet(m), status: b.status,
                           grund: b.grund, z: b.z, n: sn?.n ?? 0, visat: Avrundning.avrunda(m, b.varde),
                           forstaSerien: Avrundning.avrunda(m, fs?.median), spann: fel.gront, gult: fel.gult,
                           klartNar: Self.klartNar(fel, b, sn, bas), baslinje: Self.baslinjen(fel, bas), motForra: mot))
        }
        bedomning = bed
        kandidater = Self.kandidater(bed, kedjor)
    }

    /// Förslaget till "klart när" ur katalogens gräns, den egna baslinjen eller passet självt.
    /// Som `klart_nar` i analys.py. METOD MT3
    static func klartNar(_ fel: Katalog.Fel, _ b: Bedomning, _ nu: Sammanfattning?, _ bas: [Double]) -> KlartNarForslag? {
        guard fel.aktiv else { return nil }
        let m = fel.matt
        func r(_ v: Double) -> JSONVarde { .d(Avrundning.avrunda(m, v)) }
        if let g = fel.gront {
            let markning: String? = fel.kontrollerad ? nil : "B10"
            let lo = g.count == 2 ? g[0] : nil, hi = g.count == 2 ? g[1] : nil
            switch (lo, hi) {
            case (nil, nil): return nil
            case let (nil, h?): return KlartNarForslag(villkor: "<=", grans: .tal(h), grund: "grans", markning: markning)
            case let (l?, nil): return KlartNarForslag(villkor: ">=", grans: .tal(l), grund: "grans", markning: markning)
            case let (l?, h?): return KlartNarForslag(villkor: "mellan", grans: .lista([.tal(l), .tal(h)]), grund: "grans",
                                                       markning: markning)
            }
        }
        let med: Double, spr: Double, grund: String
        if b.grund == "baslinje" {
            let s = bas.sorted()
            med = Session.percentil(s, 0.5)
            spr = (Session.percentil(s, 0.75) - Session.percentil(s, 0.25)) / Session.iqrSkala
            grund = "baslinje"
        } else if let nu, fel.samre != nil {
            med = nu.median
            spr = Session.robustSD(nu)
            grund = "nu"
        } else {
            return nil
        }
        guard spr > 0 else { return nil }
        if grund == "nu" {
            let g = fel.samre == "+" ? med - spr : med + spr
            return KlartNarForslag(villkor: fel.samre == "+" ? "<=" : ">=", grans: r(g), grund: "nu", markning: "egen")
        }
        let z = Bedomare.gronZ * spr
        if fel.samre == "+" { return KlartNarForslag(villkor: "<=", grans: r(med + z), grund: grund, markning: "egen") }
        if fel.samre == "-" { return KlartNarForslag(villkor: ">=", grans: r(med - z), grund: grund, markning: "egen") }
        return KlartNarForslag(villkor: "mellan", grans: .lista([r(med - z), r(med + z)]), grund: grund, markning: "egen")
    }

    /// Den egna baslinjen för ett fel utan gräns (`baslinjen` i analys.py). METOD M27
    static func baslinjen(_ fel: Katalog.Fel, _ bas: [Double]) -> (median: Double?, sd: Double?, n: Int)? {
        guard fel.aktiv, fel.gront == nil, bas.count >= Bedomare.minBaslinje else { return nil }
        let s = bas.sorted()
        let spr = (Session.percentil(s, 0.75) - Session.percentil(s, 0.25)) / Session.iqrSkala
        return (Avrundning.avrunda(fel.matt, Session.percentil(s, 0.5)), Avrundning.avrunda(fel.matt, spr), bas.count)
    }

    /// De flaggade felen i läsordning: grundorsaker före följdfel, låg prioritet sist, tidigt i
    /// svingen före sent, rött före gult, sedan längst från grönt. METOD MT6
    static func kandidater(_ bed: [Rad], _ kedjor: Kedjor) -> [Kandidat] {
        let flaggade = bed.filter { $0.status == .gul || $0.status == .rod }
        let ids = Set(flaggade.map(\.id))
        let lag = Set(kedjor.lagPrioritet.map(\.fel))
        var fas: [String: Int] = [:]
        for (i, f) in kedjor.faser.enumerated() where fas[f] == nil { fas[f] = i }
        let z = Dictionary(flaggade.map { ($0.id, $0.z ?? 0) }, uniquingKeysWith: { a, _ in a })
        let ut = flaggade.map { b -> Kandidat in
            let o = kedjor.orsaker(b.id).filter { ids.contains($0.fel) }
            return Kandidat(fel: b.id, status: b.status, fas: b.fas, orsaker: o, foljdfel: !o.isEmpty,
                            fysik: kedjor.test(b.id))
        }
        func nyckel(_ k: Kandidat) -> (Int, Int, Int, Int, Double, String) {
            (k.foljdfel ? 1 : 0, lag.contains(k.fel) ? 1 : 0, fas[k.fas] ?? kedjor.faser.count,
             k.status == .rod ? 0 : 1, -abs(z[k.fel] ?? 0), k.fel)
        }
        return ut.sorted { a, b in
            let x = nyckel(a), y = nyckel(b)
            if x.0 != y.0 { return x.0 < y.0 }
            if x.1 != y.1 { return x.1 < y.1 }
            if x.2 != y.2 { return x.2 < y.2 }
            if x.3 != y.3 { return x.3 < y.3 }
            if x.4 != y.4 { return x.4 < y.4 }
            return x.5 < y.5
        }
    }

    /// Passen i en historik analyserade i tur och ordning, som `analysera_historik` i
    /// underlag.py: baslinjen ur alla tidigare pass och förra passet. Äldst först.
    public static func historik(_ passen: [Passrader], katalog: Katalog, kedjor: Kedjor = .appens) -> [Passanalys] {
        var ut: [Passanalys] = []
        var tidigare: [SvingMatt] = []
        for p in passen.sorted(by: { $0.pass < $1.pass }) {
            let a = Passanalys(p, tidigare: tidigare, forra: ut.last, baslinjePass: ut.map(\.pass).sorted(),
                               katalog: katalog, kedjor: kedjor)
            ut.append(a)
            tidigare += a.svingar
        }
        return ut
    }
}
