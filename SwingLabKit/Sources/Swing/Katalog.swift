import Foundation

/// Katalogen över fel (`katalog.json` i repots rot, BESLUT B6). Samma fil läses
/// av PC:n (tools/pc/katalog.py). Fälten står i docs/FORMAT.md.
public struct Katalog: Decodable, Sendable {
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
    }

    public static func las(_ data: Data) throws -> Katalog {
        let k: Katalog
        do {
            k = try JSONDecoder().decode(Katalog.self, from: data)
        } catch {
            throw FormatFel("katalogen: går inte att läsa")
        }
        guard k.version == 1 else { throw FormatFel("katalogen: ska ha version 1") }
        for f in k.fel {
            for spann in [f.gront, f.gult] {
                if let s = spann, s.count != 2 { throw FormatFel("\(f.id): gränsen ska vara [min, max]") }
            }
        }
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
