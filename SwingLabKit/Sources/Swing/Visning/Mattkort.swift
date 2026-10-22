import Foundation

/// Märkningen bredvid ett mått (BESLUT B13, regel 5): en liten symbol och en kort etikett.
public enum Markning: String, Sendable {
    /// Gränsen är inte läst i original (BESLUT B10).
    case b10
    /// Ingen gräns: måttet mäts mot den egna baslinjen (METOD M27).
    case egen
    /// Avstängt mått (katalogens `aktiv: false`).
    case av

    public var etikett: String { self == .b10 ? "B10" : rawValue }

    public static func fran(_ fel: Katalog.Fel) -> Markning? {
        if !fel.aktiv { return .av }
        if fel.gront == nil { return .egen }
        return fel.kontrollerad ? nil : .b10
    }
}

/// Geometrin i ett kort, i måttets egna tal.
public enum Geometri: Equatable, Sendable {
    /// Bröstets lutning från lodlinjen i adressen och vid träffen, grader (METOD M6).
    case bojning(adress: Double, traff: Double)
    /// Baksvingen och nedsvingen, s (METOD M5).
    case tempo(bak: Double, ned: Double, bakText: String, nedText: String)
}

/// Ett mått i passet: namn, tal, enhet, förändringen mot förra passet och spannet.
public struct Mattkort: Identifiable, Equatable, Sendable {
    public let id: String
    public let matt: String
    public let namn: String
    /// "FO · topp · + mot mål"
    public let rubrik: String
    /// Vyn för filtret; nil = båda telefonerna.
    public let vy: Vy?
    public let markning: Markning?
    /// "−2,4"; "—" när måttet saknas eller är avstängt.
    public let varde: String
    public let enhet: String
    /// "+1,2 cm mot 6 jan"
    public let skillnad: String?
    public let spann: Spann?
    public let geometri: Geometri?

    public init(id: String, matt: String, namn: String, rubrik: String, vy: Vy?, markning: Markning?,
                varde: String, enhet: String, skillnad: String?, spann: Spann?, geometri: Geometri?) {
        self.id = id
        self.matt = matt
        self.namn = namn
        self.rubrik = rubrik
        self.vy = vy
        self.markning = markning
        self.varde = varde
        self.enhet = enhet
        self.skillnad = skillnad
        self.spann = spann
        self.geometri = geometri
    }

    /// Värdet som text, med tecken för mått där noll är adressen.
    public static func text(_ v: Double?, _ e: Mattetikett) -> String {
        e.tecken ? Tal.tecken(v, decimaler: e.decimaler) : Tal.tal(v, decimaler: e.decimaler)
    }

    /// Ett fel i katalogen som kort för passet `nu`. `tidigare` är passen före,
    /// äldst först; det sista är förra passet. Baslinjen är alla svingar i dem (M27).
    public static func kort(_ fel: Katalog.Fel, nu: Pass, tidigare: [Pass]) -> Mattkort {
        let e = Etiketter.etikett(fel.matt)
        let grupp = fel.grupp
        let markning = Markning.fran(fel)
        let vy = Vy(rawValue: fel.vy)
        guard fel.aktiv, let s = nu.sammanfattning(fel.matt, grupp) else {
            return Mattkort(id: fel.id, matt: fel.matt, namn: e.namn, rubrik: Etiketter.rubrik(fel), vy: vy,
                            markning: markning, varde: "—", enhet: e.enhet, skillnad: nil, spann: nil, geometri: nil)
        }
        let forra = tidigare.last
        let forraMedian = forra?.median(fel.matt, grupp)
        var skillnad: String? = nil
        if let f = forraMedian, let d = forra?.datum {
            skillnad = Tal.medEnhet(Tal.tecken(s.median - f, decimaler: e.decimaler), e.enhet) + " mot " + Tal.datum(d)
        }
        let bas = Baslinje.spann(tidigare.flatMap { $0.varden(fel.matt, grupp) })
        let spann = Spann(nu: s.median, spridning: (s.q1, s.q3), forra: forraMedian, gront: fel.gront,
                          baslinje: bas, decimaler: e.decimaler)
        var geometri: Geometri? = nil
        switch e.geometri {
        case .bojning:
            if let a = nu.median("brost_bojning_adress", grupp), let t = nu.median("brost_bojning_traff", grupp) {
                geometri = .bojning(adress: a, traff: t)
            }
        case .tempo:
            if let b = nu.median("baksving_s", grupp), let n = nu.median("nedsving_s", grupp) {
                geometri = .tempo(bak: b, ned: n, bakText: Tal.tal(b, decimaler: 2), nedText: Tal.tal(n, decimaler: 2))
            }
        case nil:
            break
        }
        return Mattkort(id: fel.id, matt: fel.matt, namn: e.namn, rubrik: Etiketter.rubrik(fel), vy: vy,
                        markning: markning, varde: text(s.median, e), enhet: e.enhet, skillnad: skillnad,
                        spann: spann, geometri: geometri)
    }

    /// Passets kort i katalogens ordning, de avstängda sist.
    public static func passet(_ katalog: Katalog, nu: Pass, tidigare: [Pass]) -> [Mattkort] {
        let fel = katalog.fel.filter { $0.aktiv } + katalog.fel.filter { !$0.aktiv }
        return fel.map { kort($0, nu: nu, tidigare: tidigare) }
    }
}

/// Passets skärm: rubriken, raden under och korten.
public struct Passvisning: Sendable {
    /// "fre 9 jan"
    public let titel: String
    /// "järn 7 · 34"
    public let undertitel: String
    public let kort: [Mattkort]

    public init(katalog: Katalog, pass: [Pass]) {
        let nu = pass.last!
        titel = Tal.dag(nu.datum)
        undertitel = "\(nu.klubba) · \(nu.slag)"
        kort = Mattkort.passet(katalog, nu: nu, tidigare: Array(pass.dropLast()))
    }

    public enum Filter: String, CaseIterable, Sendable {
        case alla, fo, dtl

        public var etikett: String { self == .alla ? "Alla" : rawValue.uppercased() }
    }

    /// Korten i filtret: ett kort för båda telefonerna syns i alla filter.
    public func filtrerat(_ f: Filter) -> [Mattkort] {
        switch f {
        case .alla: return kort
        case .fo: return kort.filter { $0.vy != .dtl }
        case .dtl: return kort.filter { $0.vy != .fo }
        }
    }
}
