import Foundation

/// Katalogen över fel (`katalog.json` i repots rot, BESLUT B6). Samma fil läses
/// av PC:n (tools/pc/katalog.py), och samma kontroller görs här som där.
/// Fälten står i docs/FORMAT.md.
public struct Katalog: Decodable, Sendable {
    public static let vyer = ["dtl", "fo", "bada"]
    public static let statusar = ["tillverkare", "forskning", "tranare", "antagande"]

    public let version: Int
    public let fel: [Fel]

    public struct Fel: Decodable, Sendable {
        public let id: String
        public let namn: String
        /// "dtl", "fo" eller "bada" (alla svingar ihop).
        public let vy: String
        public let matt: String
        public let fas: String
        /// [min, max], nil i en ände = öppen. nil = egen baslinje.
        public let gront: [Double?]?
        public let gult: [Double?]?
        public let kalla: String
        public let status: String
        /// false tills källan lästs i original (BESLUT B10).
        public let kontrollerad: Bool
        public let aktiv: Bool
        /// "+" eller "-": åt vilket håll måttet blir sämre. nil = båda.
        public let samre: String?
        public let ovning: String
        public let tanke: String
        public let notering: String?

        enum CodingKeys: String, CodingKey {
            case id, namn, vy, matt, fas, gront, gult, kalla, status, kontrollerad, aktiv, samre, ovning, tanke, notering
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            // gront, gult och samre ska stå med även när de är null, som i Python.
            for nyckel in [CodingKeys.gront, .gult, .samre] where !c.contains(nyckel) {
                throw DecodingError.keyNotFound(nyckel, DecodingError.Context(codingPath: c.codingPath,
                                                                              debugDescription: "saknas"))
            }
            id = try c.decode(String.self, forKey: .id)
            namn = try c.decode(String.self, forKey: .namn)
            vy = try c.decode(String.self, forKey: .vy)
            matt = try c.decode(String.self, forKey: .matt)
            fas = try c.decode(String.self, forKey: .fas)
            gront = try c.decodeIfPresent([Double?].self, forKey: .gront)
            gult = try c.decodeIfPresent([Double?].self, forKey: .gult)
            kalla = try c.decode(String.self, forKey: .kalla)
            status = try c.decode(String.self, forKey: .status)
            kontrollerad = try c.decode(Bool.self, forKey: .kontrollerad)
            aktiv = try c.decode(Bool.self, forKey: .aktiv)
            samre = try c.decodeIfPresent(String.self, forKey: .samre)
            ovning = try c.decode(String.self, forKey: .ovning)
            tanke = try c.decode(String.self, forKey: .tanke)
            notering = try c.decodeIfPresent(String.self, forKey: .notering)
        }
    }

    /// Katalogens form, som `kontrollera` i tools/pc/katalog.py. Felen nämner felets id och fältet.
    public static func kontrollera(_ k: Katalog) -> [String] {
        var fel: [String] = []
        if k.version != 1 { fel.append("katalogen: ska ha version 1") }
        var sedda = Set<String>()
        for e in k.fel {
            if sedda.contains(e.id) { fel.append("\(e.id): id finns två gånger") }
            sedda.insert(e.id)
            if !vyer.contains(e.vy) {
                fel.append("\(e.id): vy ska vara dtl, fo eller bada")
            } else {
                let namn: [String]
                if let vy = Vy(rawValue: e.vy) {
                    namn = Matt.namn(vy)
                } else {
                    namn = Matt.namnDTL.filter { Matt.namnFO.contains($0) }      // bada
                }
                if !namn.contains(e.matt) { fel.append("\(e.id): måttet finns inte i vyn") }
            }
            if !statusar.contains(e.status) {
                fel.append("\(e.id): status ska vara en av \(statusar.joined(separator: ", "))")
            }
            if let s = e.samre, s != "+" && s != "-" {
                fel.append("\(e.id): samre ska vara \"+\", \"-\" eller null")
            }
            for (namn, spann) in [("gront", e.gront), ("gult", e.gult)] {
                if let s = spann, s.count != 2 { fel.append("\(e.id): \(namn) ska vara [min, max] eller null") }
            }
            if e.gront == nil && e.gult != nil { fel.append("\(e.id): gult utan gront") }
        }
        return fel
    }

    /// Avkodningen utan kontrollerna.
    static func avkoda(_ data: Data) throws -> Katalog {
        do {
            return try JSONDecoder().decode(Katalog.self, from: data)
        } catch let DecodingError.keyNotFound(nyckel, _) {
            throw FormatFel("katalogen: \(nyckel.stringValue) saknas")
        } catch {
            throw FormatFel("katalogen: går inte att läsa")
        }
    }

    public static func las(_ data: Data) throws -> Katalog {
        let k = try avkoda(data)
        let fel = kontrollera(k)
        guard fel.isEmpty else { throw FormatFel(fel.joined(separator: "; ")) }
        return k
    }

    public static func las(json: String) throws -> Katalog {
        try las(Data(json.utf8))
    }
}

public enum Bedomningsstatus: String, Sendable {
    case gron, gul, rod, okand, av
}

/// Ett fel bedömt för ett pass. METOD M27
public struct Bedomning: Equatable, Sendable {
    public let id: String
    /// Passets median, nil om måttet saknas.
    public let varde: Double?
    public let status: Bedomningsstatus
    /// "grans" eller "baslinje", nil när det inte gick att bedöma.
    public let grund: String?
    /// Avvikelsen mot baslinjen i robusta sd.
    public let z: Double?
}

/// Bedömningen av ett pass mot katalogen. Samma regler som tools/pc/katalog.py. METOD M27
public enum Bedomare {
    /// Svingar i baslinjen (8 försök räcker, research 1 del 4). METOD M27
    public static let minBaslinje = 8
    /// Inom 1 robust sd från baslinjen = grönt. METOD M27
    public static let gronZ = 1.0
    /// Inom 2 = gult, längre bort åt det sämre hållet = rött. METOD M27
    public static let gulZ = 2.0

    static func inom(_ v: Double, _ spann: [Double?]) -> Bool {
        let lo = spann[0], hi = spann[1]
        return (lo == nil || v >= lo!) && (hi == nil || v <= hi!)
    }

    /// Ett fel bedömt för ett värde (passets median) mot gränsen eller baslinjen.
    public static func bedom(_ fel: Katalog.Fel, varde: Double?, baslinje: [Double]) -> Bedomning {
        func ut(_ status: Bedomningsstatus, _ grund: String? = nil, _ z: Double? = nil) -> Bedomning {
            Bedomning(id: fel.id, varde: varde, status: status, grund: grund, z: z)
        }
        guard fel.aktiv else { return ut(.av) }
        guard let v = varde else { return ut(.okand) }
        if let gront = fel.gront {
            if inom(v, gront) { return ut(.gron, "grans") }
            if let gult = fel.gult { return ut(inom(v, gult) ? .gul : .rod, "grans") }
            return ut(.gul, "grans")
        }
        guard baslinje.count >= minBaslinje else { return ut(.okand) }
        let s = baslinje.sorted()
        let med = Session.percentil(s, 0.5)
        let spr = (Session.percentil(s, 0.75) - Session.percentil(s, 0.25)) / Session.iqrSkala
        guard spr > 0 else { return ut(.okand) }
        let z = (v - med) / spr
        let samre = fel.samre == "+" ? z : fel.samre == "-" ? -z : abs(z)
        return ut(samre <= gronZ ? .gron : samre <= gulZ ? .gul : .rod, "baslinje", z)
    }

    /// Passet `nu` bedömt mot katalogen. Baslinjen är måttets värden i
    /// `tidigare` pass (alla svingar ur dem, i samma vy).
    public static func bedom(_ katalog: Katalog, nu: [SvingMatt], tidigare: [SvingMatt]) -> [Bedomning] {
        let sammanf = Session.sammanfattaSession(nu)
        return katalog.fel.map { (fel: Katalog.Fel) -> Bedomning in
            let grupp = fel.vy == "bada" ? "alla" : fel.vy
            let median = sammanf[grupp]?[fel.matt]?.median
            let bas = tidigare.compactMap { s -> Double? in
                guard fel.vy == "bada" || s.vy.rawValue == fel.vy else { return nil }
                return s.matt[fel.matt]
            }
            return bedom(fel, varde: median, baslinje: bas)
        }
    }
}
