import Foundation

// Klubban ur handmarkerade punkter (PLAN S7a, BESLUT B47, METOD M45–M49): datamodellen,
// förslaget till P2, P6 och P8, måtten och filformatet `swinglab-klubba/2`. Samma
// definitioner och samma tal som tools/pc/klubba.py (BESLUT B12, inom 1e-6).

/// En punkt i hela den upprätta bildens pixlar (som lederna), y nedåt.
public struct KlubbPunkt: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// En markering av klubban vid en P-position i ett slag: rutans tid (s relativt klicket,
/// samma klocka som Visions rutor), greppet (skaftet mitt mellan händerna) och hoseln
/// (BESLUT B44), båda tryck (`kalla` = "klick"). En hoppad position (klubban syns inte)
/// har inga punkter. Vyoberoende: samma markering i DTL och FO. METOD M45
public struct KlubbMarkering: Codable, Equatable, Sendable {
    /// "P1" … "P10".
    public var position: String
    public var t: Double
    public var grepp: KlubbPunkt?
    public var hosel: KlubbPunkt?
    /// Klubban syns inte i rutan: positionen hoppades över. nil = inte hoppad.
    public var hoppad: Bool?
    /// Varifrån punkterna kommer: "klick" (ett tryck). BESLUT B44
    public var kalla: String
    /// Greppets källa när den är en annan: "handlederna_bekraftad" = ringen ur handlederna,
    /// bekräftad med ett tryck på den (BESLUT B47). nil = `kalla`.
    public var greppKalla: String?
    /// När markeringen sattes eller ändrades (paketets `andrad`). nil = okänt (före granskningen).
    public var andrad: Date?

    public init(position: String, t: Double, grepp: KlubbPunkt?, hosel: KlubbPunkt?, hoppad: Bool? = nil,
                kalla: String = Klubba.kalla, greppKalla: String? = nil, andrad: Date? = nil) {
        self.position = position
        self.t = t
        self.grepp = grepp
        self.hosel = hosel
        self.hoppad = hoppad
        self.kalla = kalla
        self.greppKalla = greppKalla
        self.andrad = andrad
    }

    /// Både greppet och hoseln är satta och positionen är inte hoppad.
    public var markerad: Bool { hoppad != true && grepp != nil && hosel != nil }
}

public enum Klubba {
    /// Alla tio positionerna, i svingens ordning.
    public static let positioner = ["P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8", "P9", "P10"]
    /// Positionerna som definieras av skaftet, inte av kroppen. METOD M45
    public static let skaftets = ["P2", "P6", "P8"]
    /// Varje punkt är ett tryck. BESLUT B44
    public static let kalla = "klick"
    /// Greppet ur ringen vid handlederna, bekräftat med ett tryck på den. BESLUT B47
    public static let kallaRing = "handlederna_bekraftad"
    /// Punkternas källor i formatet (`klubba.KALLOR`).
    public static let kallor = [kalla, kallaRing]
    /// Antagen osäkerhet per tryck, px i hela bilden (1 sd). METOD M46
    public static let tryckPx = 3.0
    /// Ett mått vars skattade osäkerhet ur trycken är större saknas, grader. METOD M46
    public static let maxSD = 4.0
    /// Steget i de centrala differenserna för osäkerheten, px. METOD M46
    public static let stegPx = 0.5
    /// Riktpinnens linje måste gå så mycket av bildhöjden i y. METOD M48
    public static let pinneMinDy = 0.05
    /// Greppet ska stå så mycket av bildhöjden över bildens mitt vid toppen. METOD M48
    public static let centrumMarginal = 0.05

    /// Mått per position: skaft_vinkel_p1 … _p10. METOD M46
    public static let perPosition = ["skaft_vinkel"]
    public static let mattDTL = ["skaftplan_p1", "skaft_riktning_topp", "skaft_plan_p6"]
    public static let mattFO = ["skaft_topp", "skaft_arm_p5", "skaft_arm_p6", "skaft_lutning_traff"]

    public static func specifika(_ vy: Vy) -> [String] { vy == .dtl ? mattDTL : mattFO }
    /// Måtten som vilar på flyktpunkten bakifrån (METOD M48).
    public static let flyktpunktsmatt = ["skaft_riktning_topp"]

    /// Måttets namn vid en position: skaft_vinkel vid P4 → skaft_vinkel_p4. METOD M46
    public static func nyckel(_ matt: String, _ position: String) -> String {
        perPosition.contains(matt) ? "\(matt)_\(position.lowercased())" : matt
    }

    /// Alla klubbmått i vyn, som de står bland ett slags mått.
    public static func namn(_ vy: Vy) -> [String] {
        perPosition.flatMap { m in positioner.map { nyckel(m, $0) } } + specifika(vy)
    }

    /// Namnen som katalogens `matt` får peka på: familjen per position och de specifika.
    public static func katalognamn(_ vy: Vy) -> [String] { perPosition + specifika(vy) }

    /// Rutan som föreslås för en position, s relativt klicket (METOD M45): kroppens
    /// positioner där de är, P2 mitt mellan P1 och P3 (annars P4), P6 mitt mellan P5 (annars
    /// P4) och P7, P8 mitt mellan P7 och P9 (annars P10). nil när en ände saknas. Bara
    /// positionerna, så att telefonen och PC:n föreslår samma ruta (`klubba.forslag_tid`).
    public static func forslagTid(_ position: String, positioner p: [String: Double]) -> Double? {
        func mitt(_ a: Double?, _ b: Double?) -> Double? {
            guard let a, let b else { return nil }
            return (a + b) / 2
        }
        switch position {
        case "P2": return mitt(p["P1"], p["P3"] ?? p["P4"])
        case "P6": return mitt(p["P5"] ?? p["P4"], p["P7"])
        case "P8": return mitt(p["P7"], p["P9"] ?? p["P10"])
        default: return p[position]
        }
    }

    /// Framifrån går skaftet genom vågrätt mellan positionerna före och efter: ändarna, vinkeln
    /// som är vågrätt (M46: 180 = bort från målet, 0 = mot målet) och vinkelns håll i den
    /// speglade bilden (baksvingen medurs, nedsvingen moturs). Som `klubba.SKAFT_VAGRATT`. METOD M45
    public static let skaftVagratt: [String: (fore: String, efter: String, vagratt: Double, hall: Double)] = [
        "P2": ("P1", "P3", 180, -1), "P6": ("P5", "P7", 180, 1), "P8": ("P7", "P9", 0, 1)]
    /// Mer än så åt svingens håll mellan ändarna är skaftet åt fel håll, grader. METOD M45
    public static let skaftMaxSpann = 270.0

    /// Framifrån (FO): rutan där skaftets vinkel (M46), linjärt i tiden mellan de markerade
    /// positionerna före och efter, går genom vågrätt, s relativt klicket (METOD M45). För P2
    /// räknas vinkeln från baksvingens start `start` (M4) när den ligger efter P1. nil när en
    /// ände saknas eller är hoppad, tiderna inte är i ordning, vinkeln går mer än
    /// `skaftMaxSpann` (fel håll) eller inte passerar vågrätt. Som `klubba.forslag_tid_skaft`.
    public static func forslagTidSkaft(_ position: String, marks: [KlubbMarkering], xTecken: Double,
                                       start: Double? = nil) -> Double? {
        guard let r = skaftVagratt[position] else { return nil }
        var pos: [String: KlubbMarkering] = [:]
        for m in marks where m.grepp != nil && m.hosel != nil { pos[m.position] = m }
        guard let a = pos[r.fore], let b = pos[r.efter] else { return nil }
        var ta = a.t
        if position == "P2", let start { ta = max(ta, start) }
        guard b.t > ta else { return nil }
        func vinkel(_ m: KlubbMarkering) -> Double {
            riktning(Punkt(xTecken * m.grepp!.x, m.grepp!.y), Punkt(xTecken * m.hosel!.x, m.hosel!.y))
        }
        func mod360(_ x: Double) -> Double {
            let v = x.truncatingRemainder(dividingBy: 360)
            return v < 0 ? v + 360 : v
        }
        let va = vinkel(a), vb = vinkel(b)
        let spann = mod360((vb - va) * r.hall), dit = mod360((r.vagratt - va) * r.hall)
        guard spann > 0, spann <= skaftMaxSpann, dit <= spann else { return nil }
        return ta + (b.t - ta) * dit / spann
    }

    /// Mållinjens flyktpunkt i bild och om den är antagen (METOD M48): där riktpinnens linje
    /// skär bildens vågräta mittlinje, eller bildens mitt (antagen) utan pinne eller med en
    /// nästan vågrät. Som `klubba.flyktpunkt`.
    public static func flyktpunkt(_ pinne: [KlubbPunkt]?, bredd: Int, hojd: Int) -> (punkt: KlubbPunkt, antagen: Bool) {
        let mitt = KlubbPunkt(x: Double(bredd) / 2.0, y: Double(hojd) / 2.0)
        guard let pinne, pinne.count == 2 else { return (mitt, true) }
        let a = pinne[0], b = pinne[1]
        guard abs(b.y - a.y) >= pinneMinDy * Double(hojd) else { return (mitt, true) }
        let u = (mitt.y - a.y) / (b.y - a.y)
        return (KlubbPunkt(x: a.x + u * (b.x - a.x), y: mitt.y), false)
    }

    // MARK: måtten

    static func grader(_ r: Double) -> Double { r * (180.0 / Double.pi) }

    /// Vektorn a → b med y uppåt.
    static func upp(_ a: Punkt, _ b: Punkt) -> Punkt { Punkt(b.x - a.x, -(b.y - a.y)) }

    /// Vektorn a → b mot vågrätt +X, grader i (−180, 180], + moturs med y uppåt.
    public static func riktning(_ a: Punkt, _ b: Punkt) -> Double {
        let d = upp(a, b)
        return grader(atan2(d.y, d.x))
    }

    /// Vinkeln från u till v, grader, + moturs (vektorerna med y uppåt).
    static func vinkelMellan(_ u: Punkt, _ v: Punkt) -> Double {
        grader(atan2(u.x * v.y - u.y * v.x, u.x * v.x + u.y * v.y))
    }

    static func wrap180(_ d: Double) -> Double {
        var r = (d + 180.0).truncatingRemainder(dividingBy: 360.0)
        if r < 0 { r += 360.0 }
        r -= 180.0
        return r == -180.0 ? 180.0 : r
    }

    /// Måttets osäkerhet (1 sd, grader) av tryckens: varje punkt osäker `tryckPx` i x och y,
    /// oberoende, genom måttets egen geometri (centrala differenser med `stegPx`). METOD M46
    public static func osakerhet(_ f: ([Punkt]) -> Double, _ punkter: [Punkt], tryckPx: Double = tryckPx) -> Double {
        var s2 = 0.0
        for i in punkter.indices {
            for k in 0..<2 {
                var plus = punkter, minus = punkter
                if k == 0 {
                    plus[i].x += stegPx
                    minus[i].x -= stegPx
                } else {
                    plus[i].y += stegPx
                    minus[i].y -= stegPx
                }
                let d = wrap180(f(plus) - f(minus)) / (2.0 * stegPx)
                s2 += (d * tryckPx) * (d * tryckPx)
            }
        }
        return s2.squareRoot()
    }

    /// Klubbmåtten och deras osäkerhet ur trycken (METOD M46–M49). x speglas med `xTecken`
    /// (+X mot bollen eller målet, M1). `sving` = slagets sving för armen i FO; `pinne` =
    /// seriens riktpinne för flyktpunkten bakifrån (M48). Ett mått saknas när en punkt saknas
    /// eller dess osäkerhet är över `maxSD`. Samma som `klubba.mat`.
    public static func matMedSD(_ marks: [KlubbMarkering], vy: Vy, xTecken: Double, bredd: Int, hojd: Int,
                                sving: Sving? = nil, pinne: [KlubbPunkt]? = nil)
        -> (matt: [String: Double], sd: [String: Double]) {
        let s = xTecken
        func spegel(_ q: KlubbPunkt) -> Punkt { Punkt(s * q.x, q.y) }
        var pos: [String: (t: Double, g: Punkt, h: Punkt)] = [:]
        for m in marks where m.hoppad != true && positioner.contains(m.position) {
            guard let gp = m.grepp, let hp = m.hosel else { continue }
            pos[m.position] = (m.t, spegel(gp), spegel(hp))
        }
        var ut: [String: Double] = [:], sd: [String: Double] = [:]
        func matt(_ namn: String, _ f: ([Punkt]) -> Double, _ punkter: [Punkt]) {
            let o = osakerhet(f, punkter)
            if o <= maxSD {
                ut[namn] = f(punkter)
                sd[namn] = o
            }
        }
        for (p, q) in pos { matt(nyckel("skaft_vinkel", p), { riktning($0[0], $0[1]) }, [q.g, q.h]) }   // METOD M46
        switch vy {
        case .dtl:
            if let p1 = pos["P1"] {
                // Skaftplanet vid P1, vinkeln mot marken sedd från bollens sida. METOD M47
                matt("skaftplan_p1", { x in grader(atan2(-(x[0].y - x[1].y), x[1].x - x[0].x)) }, [p1.g, p1.h])
                if let p6 = pos["P6"] {
                    // Bara P1:s punkter och hoseln vid P6: skaftets längd vid P6 spelar ingen roll.
                    matt("skaft_plan_p6", { x in -vinkelMellan(upp(x[1], x[0]), upp(x[1], x[2])) },
                         [p1.g, p1.h, p6.h])                                                        // METOD M47
                }
            }
            if let p4 = pos["P4"] {
                // Mot flyktpunkten (riktpinnen, annars bildens mitt). METOD M48
                let pin = pinne.flatMap { $0.count == 2 ? $0.map(spegel) : nil }
                func topp(_ x: [Punkt]) -> Double {
                    var c = Punkt(s * Double(bredd) / 2.0, Double(hojd) / 2.0)
                    if pin != nil {
                        let f = flyktpunkt([KlubbPunkt(x: x[2].x, y: x[2].y), KlubbPunkt(x: x[3].x, y: x[3].y)],
                                           bredd: bredd, hojd: hojd)
                        if !f.antagen { c = Punkt(f.punkt.x, f.punkt.y) }
                    }
                    let g = x[0]
                    guard c.y - g.y >= centrumMarginal * Double(hojd) else { return .nan }
                    return vinkelMellan(upp(g, c), upp(g, x[1]))
                }
                let punkter = [p4.g, p4.h] + (pin ?? [])
                if topp(punkter).isFinite { matt("skaft_riktning_topp", topp, punkter) }
            }
        case .fo:
            if let p4 = pos["P4"] { matt("skaft_topp", { riktning($0[0], $0[1]) }, [p4.g, p4.h]) }    // METOD M49
            if let p7 = pos["P7"] {
                matt("skaft_lutning_traff", { x in                                                    // METOD M49
                    let d = upp(x[1], x[0])
                    return grader(atan2(d.x, d.y))
                }, [p7.g, p7.h])
            }
            if let sv = sving {
                let axel = Faser.jamna(sv.t, sv.led(.axelF)), hand = Faser.jamna(sv.t, sv.led(.handledF))
                for p in ["P5", "P6"] {
                    guard let q = pos[p] else { continue }
                    let a = Faser.vid(sv.t, axel, q.t), w = Faser.vid(sv.t, hand, q.t)
                    guard a.hel, w.hel else { continue }
                    let arm = Punkt(a.x - w.x, -(a.y - w.y))
                    guard arm.langd > 0 else { continue }
                    matt("skaft_arm_\(p.lowercased())", { x in                                       // METOD M49
                        let skaft = upp(x[0], x[1])
                        let la = arm.langd, ls = skaft.langd
                        guard ls > 0 else { return .nan }
                        let cosv = (arm.x * skaft.x + arm.y * skaft.y) / (la * ls)
                        return grader(acos(max(-1.0, min(1.0, cosv))))
                    }, [q.g, q.h])
                }
            }
        }
        return (ut, sd)
    }

    /// Klubbmåtten (utan osäkerheten), som `klubba.mat`.
    public static func mat(_ marks: [KlubbMarkering], vy: Vy, xTecken: Double, bredd: Int, hojd: Int,
                           sving: Sving? = nil, pinne: [KlubbPunkt]? = nil) -> [String: Double] {
        matMedSD(marks, vy: vy, xTecken: xTecken, bredd: bredd, hojd: hojd, sving: sving, pinne: pinne).matt
    }
}

// MARK: - Filen: swinglab-klubba/2

/// Klubbans märkning som fil (docs/FORMAT.md, "Klubbans märkning"), version 1 och 2: PC:ns
/// `markera_klubba.py` och telefonens `klubba.json` i paketet. Samma kontroll som
/// `klubba.kontrollera` för det telefonen behöver; PC:n prövar hela formen. BESLUT B47
public struct KlubbFil: Codable, Equatable, Sendable {
    public static let format1 = "swinglab-klubba/1"
    public static let format = "swinglab-klubba/2"
    /// Filen i paketet.
    public static let filnamn = "klubba.json"
    public static let punktnamn = ["grepp", "skaft_mitt", "klubbhuvud"]

    /// En punkt i filen: ett tryck i hela bildens pixlar, eller "syns inte".
    public enum Punkt: Codable, Equatable, Sendable {
        case klick(x: Double, y: Double, kalla: String)
        case synsInte

        enum CodingKeys: String, CodingKey { case x, y, kalla, synsInte = "syns_inte" }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            if try c.decodeIfPresent(Bool.self, forKey: .synsInte) == true {
                self = .synsInte
            } else {
                self = .klick(x: try c.decode(Double.self, forKey: .x), y: try c.decode(Double.self, forKey: .y),
                              kalla: try c.decode(String.self, forKey: .kalla))
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case let .klick(x, y, kalla):
                try c.encode(x, forKey: .x)
                try c.encode(y, forKey: .y)
                try c.encode(kalla, forKey: .kalla)
            case .synsInte:
                try c.encode(true, forKey: .synsInte)
            }
        }

        public var punkt: KlubbPunkt? {
            if case let .klick(x, y, _) = self { return KlubbPunkt(x: x, y: y) }
            return nil
        }
    }

    /// De tre punkterna; nil = inte satt (null i filen). Alla tre står alltid med.
    public struct Punkter: Codable, Equatable, Sendable {
        public var grepp: Punkt?
        public var skaftMitt: Punkt?
        public var klubbhuvud: Punkt?

        enum CodingKeys: String, CodingKey { case grepp, skaftMitt = "skaft_mitt", klubbhuvud }

        public init(grepp: Punkt?, skaftMitt: Punkt?, klubbhuvud: Punkt?) {
            self.grepp = grepp
            self.skaftMitt = skaftMitt
            self.klubbhuvud = klubbhuvud
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            for k in [CodingKeys.grepp, .skaftMitt, .klubbhuvud] where !c.contains(k) {
                throw FormatFel("punkter.\(k.rawValue) saknas")
            }
            grepp = try c.decodeIfPresent(Punkt.self, forKey: .grepp)
            skaftMitt = try c.decodeIfPresent(Punkt.self, forKey: .skaftMitt)
            klubbhuvud = try c.decodeIfPresent(Punkt.self, forKey: .klubbhuvud)
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            for (k, v) in [(CodingKeys.grepp, grepp), (.skaftMitt, skaftMitt), (.klubbhuvud, klubbhuvud)] {
                if let v { try c.encode(v, forKey: k) } else { try c.encodeNil(forKey: k) }
            }
        }
    }

    public struct Forslag: Codable, Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var kalla: String
    }

    public struct Ruta: Codable, Equatable, Sendable {
        public var id: String
        public var fil: String
        public var vy: String?
        public var slag: String?
        /// "adress", "topp", "tidig_nedsving", "jamn" (PC:ns rutval, MF5) eller "P1" … "P10".
        public var val: String
        /// Visions tid, s relativt klicket.
        public var t: Double?
        public var tKlipp: Double?
        public var forskjutningMs: Double?
        public var tRuta: Double?
        public var bredd: Int
        public var hojd: Int
        public var visad: [Int]
        /// "omarkerad", "markerad" eller "hoppad".
        public var status: String
        public var punkter: Punkter
        public var forslag: [String: Forslag]

        enum CodingKeys: String, CodingKey {
            case id, fil, vy, slag, val, t, tKlipp = "t_klipp", forskjutningMs = "forskjutning_ms", tRuta = "t_ruta"
            case bredd, hojd, visad, status, punkter, forslag
        }

        public init(id: String, fil: String, vy: String?, slag: String?, val: String, t: Double?, tKlipp: Double?,
                    forskjutningMs: Double?, tRuta: Double?, bredd: Int, hojd: Int, visad: [Int], status: String,
                    punkter: Punkter, forslag: [String: Forslag] = [:]) {
            self.id = id
            self.fil = fil
            self.vy = vy
            self.slag = slag
            self.val = val
            self.t = t
            self.tKlipp = tKlipp
            self.forskjutningMs = forskjutningMs
            self.tRuta = tRuta
            self.bredd = bredd
            self.hojd = hojd
            self.visad = visad
            self.status = status
            self.punkter = punkter
            self.forslag = forslag
        }

        /// Null-fälten skrivs som null (formatet kräver nycklarna).
        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(id, forKey: .id)
            try c.encode(fil, forKey: .fil)
            try c.encode(vy, forKey: .vy)
            try c.encode(slag, forKey: .slag)
            try c.encode(val, forKey: .val)
            try c.encode(t, forKey: .t)
            try c.encode(tKlipp, forKey: .tKlipp)
            try c.encode(forskjutningMs, forKey: .forskjutningMs)
            try c.encode(tRuta, forKey: .tRuta)
            try c.encode(bredd, forKey: .bredd)
            try c.encode(hojd, forKey: .hojd)
            try c.encode(visad, forKey: .visad)
            try c.encode(status, forKey: .status)
            try c.encode(punkter, forKey: .punkter)
            try c.encode(forslag, forKey: .forslag)
        }
    }

    public var format: String
    public var pass: String?
    public var kalla: [String]
    public var punkter: [String]
    public var andrad: String
    public var rutor: [Ruta]

    public init(pass: String?, kalla: [String], andrad: String, rutor: [Ruta]) {
        format = Self.format
        self.pass = pass
        self.kalla = kalla
        punkter = Self.punktnamn
        self.andrad = andrad
        self.rutor = rutor
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(format, forKey: .format)
        try c.encode(pass, forKey: .pass)
        try c.encode(kalla, forKey: .kalla)
        try c.encode(punkter, forKey: .punkter)
        try c.encode(andrad, forKey: .andrad)
        try c.encode(rutor, forKey: .rutor)
    }

    enum CodingKeys: String, CodingKey { case format, pass, kalla, punkter, andrad, rutor }

    /// Läser version 1 eller 2 och uppgraderar till 2. Felen nämner fältet, aldrig värdet.
    public static func las(_ data: Data) throws -> KlubbFil {
        var f: KlubbFil
        do {
            f = try JSONDecoder().decode(KlubbFil.self, from: data)
        } catch let e as FormatFel {
            throw FormatFel("klubba: \(e.beskrivning)")
        } catch let DecodingError.keyNotFound(nyckel, _) {
            throw FormatFel("klubba: \(nyckel.stringValue) saknas")
        } catch {
            throw FormatFel("klubba: går inte att läsa")
        }
        guard f.format == format || f.format == format1 else { throw FormatFel("klubba: format ska vara \(format)") }
        guard f.punkter == punktnamn else { throw FormatFel("klubba: punkter ska vara \(punktnamn)") }
        f.format = format
        return f
    }

    /// Markeringarna per slag (rutorna vars `val` är en P-position och som har Visions tid),
    /// som telefonen sparar dem; en hoppad ruta har inga punkter. Som `klubba.markeringar`.
    public func markeringar() -> [String: [KlubbMarkering]] {
        var ut: [String: [KlubbMarkering]] = [:]
        for r in rutor where Klubba.positioner.contains(r.val) {
            guard let t = r.t else { continue }
            let hoppad = r.status == "hoppad"
            var gk: String? = nil
            if case let .klick(_, _, k)? = r.punkter.grepp, k != Klubba.kalla { gk = k }
            ut[r.slag ?? "", default: []].append(KlubbMarkering(
                position: r.val, t: t, grepp: hoppad ? nil : r.punkter.grepp?.punkt,
                hosel: hoppad ? nil : r.punkter.klubbhuvud?.punkt, hoppad: hoppad ? true : nil, greppKalla: gk))
        }
        return ut
    }

    /// En ruta ur telefonens markering (BESLUT B47): `val` = positionen, ingen klipptid
    /// eller förskjutning (paketet fyller i klipptiden), `visad` = det granskningen visade.
    public static func ruta(_ m: KlubbMarkering, vy: Vy, slag: String, fil: String, bredd: Int, hojd: Int,
                            visad: [Int], tKlipp: Double?) -> Ruta {
        func p(_ q: KlubbPunkt?, _ kalla: String) -> Punkt? { q.map { .klick(x: $0.x, y: $0.y, kalla: kalla) } }
        let hoppad = m.hoppad == true
        return Ruta(id: "\(vy.rawValue)-\(slag)-\(m.position)", fil: fil, vy: vy.rawValue, slag: slag, val: m.position,
                    t: m.t, tKlipp: tKlipp, forskjutningMs: nil, tRuta: nil, bredd: bredd, hojd: hojd, visad: visad,
                    status: hoppad ? "hoppad" : (m.markerad ? "markerad" : "omarkerad"),
                    punkter: Punkter(grepp: hoppad ? nil : p(m.grepp, m.greppKalla ?? m.kalla), skaftMitt: nil,
                                     klubbhuvud: hoppad ? nil : p(m.hosel, m.kalla)))
    }
}
