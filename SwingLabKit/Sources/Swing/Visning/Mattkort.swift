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
    /// Tempot saknas för att starten är osäker bakifrån: VoiceOver säger det (METOD M40).
    public var ejMatt = false

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
        if ejMatt { d.append(Texter.ejMatt) }
        if let s = spann, !s.upplasning.isEmpty { d.append(s.upplasning) }
        if let k = skillnad { d.append(k) }
        if let m = markning { d.append(m.upplasning) }
        return d.joined(separator: ", ")
    }

    /// Tempot saknas ("—") och passet har slag med osäker start bakifrån (METOD M40).
    public func startOsaker(_ nu: Pass) -> Bool {
        matt == "tempo" && varde == "—" && nu.osakerStart > 0
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
        if k.startOsaker(nu), let b = k.info {                     // METOD M40
            k.info = Infoblad(namn: b.namn, vad: b.vad, varfor: b.varfor, tecken: b.tecken,
                              kalla: "\(b.kalla), \(Texter.startOsakerKalla)")
            k.ejMatt = true
        }
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

    /// Spridningens rubrik: "DTL · impact" (vyn och måttets fas). METOD M44
    static func rubrik(_ post: Katalog.Spridningspost) -> String {
        let e = Etiketter.etikett(post.matt)
        return ([Etiketter.vy(post.vy)] + (e.fas.isEmpty ? [] : [e.fas])).joined(separator: " · ")
    }

    /// Passets spridning mellan slagen för ett mått som kort (METOD M44, BESLUT B46): talet är
    /// passets robusta sd, förra passets är strecket och de tidigare passens spridning är den
    /// egna baslinjen (M27, ett tal per pass). Samma kort och spann som felen, ingen ny vy.
    public static func kort(_ post: Katalog.Spridningspost, nu: Pass, tidigare: [Pass]) -> Mattkort {
        let e = Etiketter.etikett(post.matt)
        let namn = Texter.spridningsnamn(e.namn)
        var k: Mattkort
        if let v = nu.spridning(post.matt, post.vy) {
            let forra = tidigare.last
            let f = forra?.spridning(post.matt, post.vy)
            var skillnad: String? = nil
            if let f, let d = forra?.datum {
                let a = Avrundning.avrunda(post.matt, v)!, b = Avrundning.avrunda(post.matt, f)!
                skillnad = Texter.mot(Tal.medEnhet(Tal.tecken(a - b, decimaler: e.decimaler), e.enhet), Tal.datum(d))
            }
            let bas = Baslinje.spann(tidigare.compactMap { $0.spridning(post.matt, post.vy) })
            let spann = Spann(nu: v, spridning: nil, forra: f, gront: nil, baslinje: bas, decimaler: e.decimaler,
                              enhet: e.enhet)
            k = Mattkort(id: post.id, matt: post.matt, namn: namn, rubrik: rubrik(post), vy: Vy(rawValue: post.vy),
                         markning: .egen, varde: Tal.tal(Avrundning.avrunda(post.matt, v), decimaler: e.decimaler),
                         enhet: e.enhet, skillnad: skillnad, spann: spann, geometri: nil)
        } else {
            k = Mattkort(id: post.id, matt: post.matt, namn: namn, rubrik: rubrik(post), vy: Vy(rawValue: post.vy),
                         markning: .egen, varde: "—", enhet: e.enhet, skillnad: nil, spann: nil, geometri: nil)
        }
        k.info = Infoblad(post, namn: namn)
        return k
    }

    /// Ett klubbmått ur markeringarna som kort (PLAN S7a, METOD M46–M49): medianen av de
    /// markerade svingarna och n i rubriken ("DTL · P1 · n 3"), förra passets median och de
    /// tidigare passens svingar som egen baslinje (M27). Med få svingar är det en trend, inte
    /// ett fel (BESLUT B47): ingen gräns och ingen accent. nil när inget slag har måttet.
    public static func kort(klubba post: Katalog.Mattpost, nu: Pass, tidigare: [Pass]) -> Mattkort? {
        let v = nu.varden(post.matt, post.vy)
        guard !v.isEmpty else { return nil }
        let e = Etiketter.etikett(post.matt)
        let med = Session.percentil(v.sorted(), 0.5)
        let forra = tidigare.last
        let fv = forra?.varden(post.matt, post.vy) ?? []
        let f = fv.isEmpty ? nil : Session.percentil(fv.sorted(), 0.5)
        var skillnad: String? = nil
        if let f, let d = forra?.datum {
            let a = Avrundning.avrunda(post.matt, med)!, b = Avrundning.avrunda(post.matt, f)!
            skillnad = Texter.mot(Tal.medEnhet(Tal.tecken(a - b, decimaler: e.decimaler), e.enhet), Tal.datum(d))
        }
        let bas = Baslinje.spann(tidigare.flatMap { $0.varden(post.matt, post.vy) })
        let spann = Spann(nu: med, spridning: nil, forra: f, gront: nil, baslinje: bas, decimaler: e.decimaler,
                          enhet: e.enhet)
        let rubrik = ([Etiketter.vy(post.vy)] + (e.fas.isEmpty ? [] : [e.fas]) + [Texter.n(v.count)])
            .joined(separator: " · ")
        var k = Mattkort(id: "\(post.matt)_\(post.vy)", matt: post.matt, namn: e.namn, rubrik: rubrik,
                         vy: Vy(rawValue: post.vy), markning: .egen,
                         varde: text(Avrundning.avrunda(post.matt, med), e), enhet: e.enhet, skillnad: skillnad,
                         spann: spann, geometri: nil)
        k.info = Infoblad(post, namn: e.namn)
        return k
    }

    /// Passets kort i katalogens ordning: felen, spridningen mellan slagen (METOD M44), klubbens
    /// mått när slag är markerade (S7a) och de avstängda sist. `ovas` = felen i Att jobba på
    /// (BESLUT B31).
    public static func passet(_ katalog: Katalog, nu: Pass, tidigare: [Pass], ovas: Set<String> = []) -> [Mattkort] {
        func fel(_ f: [Katalog.Fel]) -> [Mattkort] {
            f.map { f -> Mattkort in
                var k = kort(f, nu: nu, tidigare: tidigare)
                k.ovas = ovas.contains(f.id)
                return k
            }
        }
        return fel(katalog.fel.filter { $0.aktiv })
            + katalog.spridning.map { kort($0, nu: nu, tidigare: tidigare) }
            + katalog.matt.filter { m in Vy(rawValue: m.vy).map { Klubba.specifika($0).contains(m.matt) } ?? false }
                .compactMap { kort(klubba: $0, nu: nu, tidigare: tidigare) }
            + fel(katalog.fel.filter { !$0.aktiv })
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
            + (nu.klubbMarkerade > 0 ? "\(Texter.skilje)\(Texter.klubbMarkerade(nu.klubbMarkerade))" : "")
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
