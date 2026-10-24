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

/// Ett pass som analysen läser: id:t (`yyyyMMdd-HHmmss`), längden som gav skalan och de mätta
/// slagen i passets ordning.
public struct Passrader: Sendable {
    public let pass: String
    public let langd: Double?
    public let slag: [Slagrad]

    public init(pass: String, langd: Double?, slag: [Slagrad]) {
        self.pass = pass
        self.langd = langd
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
    /// Klubbans id ("j7"); varje klubba i ett pass är en egen enhet (BESLUT B56).
    public let klubba: String?
    /// Längden som gav skalan; bara enheter med samma längd jämförs.
    public let langd: Double?
    /// Passets huvudklubba (flest mätta slag): den som passets "Att jobba på" gäller.
    public let huvud: Bool
    /// Alla klubbor i passet.
    public let klubbor: [String]
    /// Enhetens slag: passets slag med klubban.
    public let slag: [Slagrad]
    /// Vyerna med mätta slag, sorterade.
    public let vyer: [String]
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

    /// Samma klubba och längd: enheten går att jämföra med (`samma` i analys.py, BESLUT B56).
    public func samma(klubba k: String?, langd l: Double?) -> Bool { klubba == k && langd == l }

    /// Ordningen i historiken: passet, huvudklubban först.
    static func fore(_ a: Passanalys, _ b: Passanalys) -> Bool {
        a.pass != b.pass ? a.pass < b.pass : (a.huvud && !b.huvud)
    }

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

    /// Klubban med flest mätta slag, vid lika den som sorterar först och utan klubba först
    /// (`huvudklubba` i analys.py, BESLUT B56).
    static func huvudklubba(_ slag: [Slagrad]) -> String? {
        var ordning: [String?] = []
        var n: [String: Int] = [:]
        for s in slag {
            let k = s.klubba ?? "\u{0}"
            if n[k] == nil { ordning.append(s.klubba) }
            n[k, default: 0] += 1
        }
        let sorterad = ordning.enumerated().sorted { a, b in
            let na = n[a.element ?? "\u{0}"]!, nb = n[b.element ?? "\u{0}"]!
            if na != nb { return na > nb }
            let ka = a.element ?? "", kb = b.element ?? ""
            if ka != kb { return ka < kb }
            return a.offset < b.offset
        }
        return sorterad.first?.element ?? nil
    }

    /// En klubbas del av passet, bedömd mot de tidigare enheterna med samma klubba och längd:
    /// baslinjen ur alla dem, förra passet den senaste med en gemensam vy (`_del` i analys.py,
    /// BESLUT B56).
    init(pass: String, langd: Double?, klubba: String?, huvud: Bool, klubbor: [String], slag: [Slagrad],
         tidigare: [Passanalys], katalog: Katalog, kedjor: Kedjor) {
        self.pass = pass
        self.langd = langd
        self.klubba = klubba
        self.huvud = huvud
        self.klubbor = klubbor
        self.slag = slag
        vyer = Set(slag.map(\.vy.rawValue)).sorted()
        let jamf = tidigare.filter { $0.pass < pass && $0.samma(klubba: klubba, langd: langd) }.sorted(by: Self.fore)
        let bas = jamf.flatMap(\.svingar)
        let minaVyer = Set(slag.map(\.vy.rawValue))
        let forra = jamf.last { !minaVyer.isDisjoint(with: $0.vyer) }
        let vyAlla = Self.tempoVy(slag)
        tempoVy = vyAlla
        let sammanf = Self.sammanfatta(slag, vyAlla)
        let forsta = Self.sammanfatta(slag.filter(\.forstaSerien), vyAlla)
        session = sammanf
        forstaSerien = forsta
        // Spridningen mellan slagen för klubban (METOD M44, BESLUT B46).
        spridning = Spridning.pass(katalog, slag.map { SvingMatt(vy: $0.vy, matt: $0.matt) }).map { s in
            Spridningsrad(matt: s.matt, vy: s.vy, klubba: klubba, n: s.n, visat: Avrundning.avrunda(s.matt, s.varde))
        }
        baslinjePass = Set(jamf.map(\.pass)).sorted()
        baslinjeSvingar = ["dtl": bas.filter { $0.vy == .dtl }.count, "fo": bas.filter { $0.vy == .fo }.count]
        self.forra = forra?.pass
        var jamforelse: [String: [String: Jamforelse]] = [:]
        if let f = forra {
            for g in Session.grupper { jamforelse[g] = Session.jamfor(nu: sammanf[g] ?? [:], forra: f.session[g] ?? [:]) }
        }
        var bed: [Rad] = []
        for fel in katalog.fel {
            let g = Self.grupp(fel.vy), m = fel.matt
            let vy = fel.vy == "bada" ? vyAlla : fel.vy
            let b_ = bas.compactMap { s -> Double? in s.vy.rawValue == vy ? s.matt[m] : nil }
            let sn = sammanf[g]?[m]
            let fs = forsta[g]?[m]
            let b = Bedomare.bedom(fel, varde: sn?.median, baslinje: b_)
            var mot: (skillnad: Double?, tydlig: Bool)? = nil
            if forra != nil, let j = jamforelse[g]?[m] {
                mot = (Avrundning.avrunda(m, j.skillnad), j.tydlig)
            }
            bed.append(Rad(id: fel.id, vy: fel.vy, matt: m, fas: fel.fas, enhet: Avrundning.enhet(m), status: b.status,
                           grund: b.grund, z: b.z, n: sn?.n ?? 0, visat: Avrundning.avrunda(m, b.varde),
                           forstaSerien: Avrundning.avrunda(m, fs?.median), spann: fel.gront, gult: fel.gult,
                           klartNar: Self.klartNar(fel, b, sn, b_), baslinje: Self.baslinjen(fel, b_), motForra: mot))
        }
        bedomning = bed
        kandidater = Self.kandidater(bed, kedjor)
    }

    /// Passets enheter: huvudklubban och varje annan klubba för sig (`analysera_rader` och
    /// `enheter` i Python). `tidigare` = de tidigare passens enheter.
    public static func enheter(_ p: Passrader, tidigare: [Passanalys], katalog: Katalog,
                               kedjor: Kedjor = .appens) -> [Passanalys] {
        let huvud = huvudklubba(p.slag)
        let klubbor = Set(p.slag.compactMap(\.klubba).filter { !$0.isEmpty }).sorted()
        var andra: [String?] = []
        for s in p.slag where s.klubba != huvud && !andra.contains(where: { $0 == s.klubba }) { andra.append(s.klubba) }
        andra.sort { ($0 ?? "") < ($1 ?? "") }
        return ([huvud] + andra).enumerated().map { i, k in
            Passanalys(pass: p.pass, langd: p.langd, klubba: k, huvud: i == 0, klubbor: klubbor,
                       slag: p.slag.filter { $0.klubba == k }, tidigare: tidigare, katalog: katalog, kedjor: kedjor)
        }
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
    /// underlag.py: varje klubba för sig mot de tidigare enheterna med samma klubba och längd.
    /// Svarar enheterna, äldst först och huvudklubban först i varje pass.
    public static func historik(_ passen: [Passrader], katalog: Katalog, kedjor: Kedjor = .appens) -> [Passanalys] {
        var ut: [Passanalys] = []
        for p in passen.enumerated().sorted(by: { ($0.element.pass, $0.offset) < ($1.element.pass, $1.offset) }) {
            ut += enheter(p.element, tidigare: ut, katalog: katalog, kedjor: kedjor)
        }
        return ut
    }

    /// Enheterna som går att jämföra med passets huvudklubba: samma klubba och längd, till och
    /// med passet (`sammanhang` i historik.py, BESLUT B56).
    public static func sammanhang(_ enh: [Passanalys], nu: String) -> [Passanalys] {
        let huvud = enh.filter { $0.huvud && $0.pass <= nu }
        guard let n = huvud.first(where: { $0.pass == nu }) ?? huvud.last else { return [] }
        return enh.filter { $0.pass <= n.pass && $0.samma(klubba: n.klubba, langd: n.langd) }
    }
}
