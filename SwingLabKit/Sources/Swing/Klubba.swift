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

    public init(position: String, t: Double, grepp: KlubbPunkt?, hosel: KlubbPunkt?, hoppad: Bool? = nil,
                kalla: String = Klubba.kalla) {
        self.position = position
        self.t = t
        self.grepp = grepp
        self.hosel = hosel
        self.hoppad = hoppad
        self.kalla = kalla
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
    /// Antagen osäkerhet per tryck, px i hela bilden (1 sd). METOD M46
    public static let tryckPx = 3.0
    /// Kortare skaft i bild ger inget mått (vinkeln ±4° med `tryckPx`). METOD M46
    public static let minSkaftPx = 60.0
    /// Greppet ska stå så mycket av bildhöjden över bildens mitt vid toppen. METOD M48
    public static let centrumMarginal = 0.05

    /// Mått per position: skaft_vinkel_p1 … _p10. METOD M46
    public static let perPosition = ["skaft_vinkel"]
    public static let mattDTL = ["skaftplan_p1", "skaft_mot_plan_p2", "skaft_riktning_topp", "skaft_plan_p6"]
    public static let mattFO = ["skaft_topp", "skaft_arm_p5", "skaft_arm_p6", "skaft_lutning_traff"]

    public static func specifika(_ vy: Vy) -> [String] { vy == .dtl ? mattDTL : mattFO }

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
    /// positioner där de är, P2 mitt mellan starten (annars P1) och P3 (annars P4), P6 mitt
    /// mellan P5 (annars P4) och P7, P8 mitt mellan P7 och P9 (annars P10). nil när en ände
    /// saknas. Samma som `klubba.forslag_tid`.
    public static func forslagTid(_ position: String, positioner p: [String: Double], start: Double?) -> Double? {
        func mitt(_ a: Double?, _ b: Double?) -> Double? {
            guard let a, let b else { return nil }
            return (a + b) / 2
        }
        switch position {
        case "P2": return mitt(start ?? p["P1"], p["P3"] ?? p["P4"])
        case "P6": return mitt(p["P5"] ?? p["P4"], p["P7"])
        case "P8": return mitt(p["P7"], p["P9"] ?? p["P10"])
        default: return p[position]
        }
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

    /// En vinkel mellan två linjer (utan riktning) i (−90, 90], som Pythons `_wrap90`.
    static func wrap90(_ d: Double) -> Double {
        var r = (d + 90.0).truncatingRemainder(dividingBy: 180.0)
        if r < 0 { r += 180.0 }
        r -= 90.0
        return r == -90.0 ? 90.0 : r
    }

    /// Vinkelns osäkerhet (1 sd, grader) för en linje mellan två tryck `langdPx` isär:
    /// √2·σ/L radianer. METOD M46
    public static func osakerhet(_ langdPx: Double, tryckPx: Double = tryckPx) -> Double {
        langdPx > 0 ? grader(2.0.squareRoot() * tryckPx / langdPx) : .infinity
    }

    /// Klubbmåtten för ett slag ur dess markeringar (METOD M46–M49). x speglas med
    /// `xTecken` (+X mot bollen eller målet, M1). `sving` = slagets sving för armen i FO;
    /// utan den saknas skaft_arm_*. Ett mått saknas när en punkt saknas eller skaftet är
    /// kortare än `minSkaftPx` i bild. Samma som `klubba.mat`.
    public static func mat(_ marks: [KlubbMarkering], vy: Vy, xTecken: Double, bredd: Int, hojd: Int,
                           sving: Sving? = nil) -> [String: Double] {
        let s = xTecken
        var pos: [String: (t: Double, g: Punkt, h: Punkt)] = [:]
        for m in marks where m.hoppad != true && positioner.contains(m.position) {
            guard let gp = m.grepp, let hp = m.hosel else { continue }
            let g = Punkt(s * gp.x, gp.y), h = Punkt(s * hp.x, hp.y)
            guard (h - g).langd >= minSkaftPx else { continue }
            pos[m.position] = (m.t, g, h)
        }
        var ut: [String: Double] = [:]
        for (p, q) in pos { ut[nyckel("skaft_vinkel", p)] = riktning(q.g, q.h) }            // METOD M46
        switch vy {
        case .dtl:
            if let p1 = pos["P1"] {
                // Skaftplanet vid P1, vinkeln mot marken sedd från bollens sida. METOD M47
                let g = p1.g, h = p1.h
                let plan = grader(atan2(-(g.y - h.y), h.x - g.x))
                ut["skaftplan_p1"] = plan
                if let p2 = pos["P2"] {
                    ut["skaft_mot_plan_p2"] = wrap90(grader(atan2(-(p2.g.y - p2.h.y), p2.h.x - p2.g.x)) - plan)
                }
                if let p6 = pos["P6"], (p6.h - h).langd >= minSkaftPx {
                    ut["skaft_plan_p6"] = -vinkelMellan(upp(h, g), upp(h, p6.h))                // METOD M47
                }
            }
            if let p4 = pos["P4"] {
                // Mot bildens mitt: ett skaft parallellt med mållinjen, kameran på linjen. METOD M48
                let c = Punkt(s * Double(bredd) / 2.0, Double(hojd) / 2.0)
                if c.y - p4.g.y >= centrumMarginal * Double(hojd) {
                    ut["skaft_riktning_topp"] = vinkelMellan(upp(p4.g, c), upp(p4.g, p4.h))
                }
            }
        case .fo:
            if let p4 = pos["P4"] { ut["skaft_topp"] = riktning(p4.g, p4.h) }                // METOD M49
            if let p7 = pos["P7"] {
                let d = upp(p7.h, p7.g)
                ut["skaft_lutning_traff"] = grader(atan2(d.x, d.y))                           // METOD M49
            }
            if let sv = sving {
                let axel = Faser.jamna(sv.t, sv.led(.axelF)), hand = Faser.jamna(sv.t, sv.led(.handledF))
                for p in ["P5", "P6"] {
                    guard let q = pos[p] else { continue }
                    let a = Faser.vid(sv.t, axel, q.t), w = Faser.vid(sv.t, hand, q.t)
                    guard a.hel, w.hel else { continue }
                    let arm = Punkt(a.x - w.x, -(a.y - w.y)), skaft = upp(q.g, q.h)
                    let la = arm.langd, ls = skaft.langd
                    guard la > 0 else { continue }
                    let cosv = (arm.x * skaft.x + arm.y * skaft.y) / (la * ls)
                    ut["skaft_arm_\(p.lowercased())"] = grader(acos(max(-1.0, min(1.0, cosv))))   // METOD M49
                }
            }
        }
        return ut
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
            ut[r.slag ?? "", default: []].append(KlubbMarkering(
                position: r.val, t: t, grepp: hoppad ? nil : r.punkter.grepp?.punkt,
                hosel: hoppad ? nil : r.punkter.klubbhuvud?.punkt, hoppad: hoppad ? true : nil))
        }
        return ut
    }

    /// En ruta ur telefonens markering (BESLUT B47): `val` = positionen, ingen klipptid
    /// eller förskjutning (paketet fyller i klipptiden), `visad` = det granskningen visade.
    public static func ruta(_ m: KlubbMarkering, vy: Vy, slag: String, fil: String, bredd: Int, hojd: Int,
                            visad: [Int], tKlipp: Double?) -> Ruta {
        func p(_ q: KlubbPunkt?) -> Punkt? { q.map { .klick(x: $0.x, y: $0.y, kalla: m.kalla) } }
        let hoppad = m.hoppad == true
        return Ruta(id: "\(vy.rawValue)-\(slag)-\(m.position)", fil: fil, vy: vy.rawValue, slag: slag, val: m.position,
                    t: m.t, tKlipp: tKlipp, forskjutningMs: nil, tRuta: nil, bredd: bredd, hojd: hojd, visad: visad,
                    status: hoppad ? "hoppad" : (m.markerad ? "markerad" : "omarkerad"),
                    punkter: Punkter(grepp: hoppad ? nil : p(m.grepp), skaftMitt: nil,
                                     klubbhuvud: hoppad ? nil : p(m.hosel)))
    }
}
