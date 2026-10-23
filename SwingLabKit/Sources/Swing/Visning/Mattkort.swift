import Foundation

/// Märkningen bredvid ett mått (BESLUT B13, regel 5): en liten symbol och en kort etikett.
public enum Markning: String, Sendable {
    /// Gränsen är inte läst i original (BESLUT B10).
    case b10
    /// Ingen gräns: måttet mäts mot den egna baslinjen (METOD M27).
    case egen
    /// Avstängt mått (katalogens `aktiv: false`).
    case av
    /// Oprövat på telefonen: farterna kräver skarp bild (katalogens `status: "oprovad"`,
    /// METOD M35–M37, BESLUT B11).
    case oprovad

    public var etikett: String {
        switch self {
        case .b10: return "B10"
        case .egen: return Texter.markningEgen
        case .av: return Texter.markningAv
        case .oprovad: return Texter.markningOprovad
        }
    }

    /// Märkningen i ord för VoiceOver.
    public var upplasning: String {
        switch self {
        case .b10: return Texter.upplasningB10
        case .egen: return Texter.upplasningEgen
        case .av: return Texter.upplasningAv
        case .oprovad: return Texter.upplasningOprovad
        }
    }

    public static func fran(_ fel: Katalog.Fel) -> Markning? {
        if !fel.aktiv { return .av }
        if fel.gront == nil { return .egen }
        return fel.kontrollerad ? nil : .b10
    }

    /// Ett mått i katalogens `matt`: egen baslinje, eller oprövat. METOD M29, M35–M37
    public static func fran(_ post: Katalog.Mattpost) -> Markning {
        post.status == "oprovad" ? .oprovad : .egen
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
    /// "FO · top · + to target"
    public let rubrik: String
    /// Vyn för filtret; nil = båda telefonerna.
    public let vy: Vy?
    public let markning: Markning?
    /// "−2.4"; "—" när måttet saknas eller är avstängt.
    public let varde: String
    public let enhet: String
    /// "+1.2 cm vs Jan 6"
    public let skillnad: String?
    public let spann: Spann?
    public let geometri: Geometri?
    /// Måttet övas just nu (Att jobba på): kortet bär accenten (BESLUT B31).
    public var ovas = false
    /// Infobladet som ett tryck på kortet öppnar (BESLUT B41).
    public var info: Infoblad? = nil

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

    /// Kortet i ord för VoiceOver: "Sway −2.4 cm, target from 0 cm, last −3.6 cm, +1.2 cm vs Jan 6, …".
    public var upplasning: String {
        var d = [varde == "—" ? namn : "\(namn) \(Tal.medEnhet(varde, enhet == ": 1" ? "" : enhet))"]
        if let s = spann, !s.upplasning.isEmpty { d.append(s.upplasning) }
        if let k = skillnad { d.append(k) }
        if let m = markning { d.append(m.upplasning) }
        return d.joined(separator: ", ")
    }

    /// Värdet som text, med tecken för mått där noll är adressen.
    public static func text(_ v: Double?, _ e: Mattetikett) -> String {
        e.tecken ? Tal.tecken(v, decimaler: e.decimaler) : Tal.tal(v, decimaler: e.decimaler)
    }

    /// Ett fel i katalogen som kort för passet `nu`. `tidigare` är passen före,
    /// äldst först; det sista är förra passet. Baslinjen är alla svingar i dem (M27).
    public static func kort(_ fel: Katalog.Fel, nu: Pass, tidigare: [Pass]) -> Mattkort {
        var k = kortUtanBlad(fel, nu: nu, tidigare: tidigare)
        k.info = Infoblad(fel, namn: k.namn)
        return k
    }

    /// Kortet med måttets namn utan position: kortets rubrik bär den ("FO · top", BESLUT B40).
    static func kortUtanBlad(_ fel: Katalog.Fel, nu: Pass, tidigare: [Pass]) -> Mattkort {
        let e = Etiketter.etikett(fel.matt)
        let grupp = fel.grupp
        let markning = Markning.fran(fel)
        let vy = Vy(rawValue: fel.vy)
        // Färre än tre svingar ger ingen sammanfattning (M25). Passet visar ändå medianen av
        // de som finns, utan spridning och utan jämförelse mot förra passet. METOD MS14
        let fa = nu.varden(fel.matt, grupp)
        if fel.aktiv, nu.sammanfattning(fel.matt, grupp) == nil, !fa.isEmpty {
            let v = Session.percentil(fa.sorted(), 0.5)
            let bas = Baslinje.spann(tidigare.flatMap { $0.varden(fel.matt, grupp) })
            let spann = Spann(nu: v, spridning: nil, forra: nil, gront: fel.gront, baslinje: bas,
                              decimaler: e.decimaler, enhet: e.enhet == ": 1" ? "" : e.enhet)
            return Mattkort(id: fel.id, matt: fel.matt, namn: e.namn, rubrik: Etiketter.rubrik(fel), vy: vy,
                            markning: markning, varde: text(Avrundning.avrunda(fel.matt, v), e), enhet: e.enhet,
                            skillnad: nil, spann: spann, geometri: nil)
        }
        guard fel.aktiv, let s = nu.sammanfattning(fel.matt, grupp) else {
            return Mattkort(id: fel.id, matt: fel.matt, namn: e.namn, rubrik: Etiketter.rubrik(fel), vy: vy,
                            markning: markning, varde: "—", enhet: e.enhet, skillnad: nil, spann: nil, geometri: nil)
        }
        let forra = tidigare.last
        let forraMedian = forra?.median(fel.matt, grupp)
        var skillnad: String? = nil
        if let f = forraMedian, let d = forra?.datum {
            // På de avrundade talen, så att skillnaden stämmer med de två tal som visas.
            let a = Avrundning.avrunda(fel.matt, s.median)!, b = Avrundning.avrunda(fel.matt, f)!
            skillnad = Texter.mot(Tal.medEnhet(Tal.tecken(a - b, decimaler: e.decimaler), e.enhet), Tal.datum(d))
        }
        let bas = Baslinje.spann(tidigare.flatMap { $0.varden(fel.matt, grupp) })
        let spann = Spann(nu: s.median, spridning: (s.q1, s.q3), forra: forraMedian, gront: fel.gront,
                          baslinje: bas, decimaler: e.decimaler, enhet: e.enhet == ": 1" ? "" : e.enhet)
        var geometri: Geometri? = nil
        switch e.geometri {
        case .bojning:
            // Vinkeln mellan linjerna är kortets tal (medianen av tappet), från adressens median.
            if let a = nu.median("brost_bojning_adress", grupp) {
                geometri = .bojning(adress: a, traff: a - s.median)
            }
        case .tempo:
            if let b = nu.median("baksving_s", grupp), let n = nu.median("nedsving_s", grupp) {
                geometri = .tempo(bak: b, ned: n, bakText: Tal.tal(b, decimaler: 2), nedText: Tal.tal(n, decimaler: 2))
            }
        case nil:
            break
        }
        return Mattkort(id: fel.id, matt: fel.matt, namn: e.namn, rubrik: Etiketter.rubrik(fel), vy: vy,
                        markning: markning, varde: text(Avrundning.avrunda(fel.matt, s.median), e), enhet: e.enhet, skillnad: skillnad,
                        spann: spann, geometri: geometri)
    }

    /// Passets kort i katalogens ordning, de avstängda sist.
    /// `ovas` = felen i Att jobba på (BESLUT B31).
    public static func passet(_ katalog: Katalog, nu: Pass, tidigare: [Pass], ovas: Set<String> = []) -> [Mattkort] {
        let fel = katalog.fel.filter { $0.aktiv } + katalog.fel.filter { !$0.aktiv }
        return fel.map { f -> Mattkort in
            var k = kort(f, nu: nu, tidigare: tidigare)
            k.ovas = ovas.contains(f.id)
            return k
        }
    }
}

/// Passets skärm: rubriken, raden under och korten.
public struct Passvisning: Sendable {
    /// "Fri, Jan 9"
    public let titel: String
    /// "7i · 34"
    public let undertitel: String
    public let kort: [Mattkort]

    public init(katalog: Katalog, pass: [Pass], ovas: Set<String> = []) {
        let nu = pass.last!
        titel = Tal.dag(nu.datum)
        undertitel = "\(nu.klubba)\(Texter.skilje)\(nu.slag)"
        kort = Mattkort.passet(katalog, nu: nu, tidigare: Array(pass.dropLast()), ovas: ovas)
    }

    public enum Filter: String, CaseIterable, Sendable {
        case alla, fo, dtl

        public var etikett: String { self == .alla ? Texter.alla : rawValue.uppercased() }
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
