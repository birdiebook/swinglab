import Foundation

/// Katalogen över fel (`katalog.json` i repots rot, BESLUT B6). Samma fil läses
/// av PC:n (tools/pc/katalog.py), och samma kontroller görs här som där.
/// Fälten står i docs/FORMAT.md.
public struct Katalog: Decodable, Sendable {
    public static let vyer = ["dtl", "fo", "bada"]
    public static let statusar = ["tillverkare", "forskning", "tranare", "antagande"]

    public let version: Int
    public let fel: [Fel]
    /// Måtten som granskningen visar vid en position utan att de är fel (BESLUT B32).
    public let matt: [Mattpost]

    /// Ett mått i granskningen: namnet, vyn och positionerna, och valfritt felet vars
    /// accent (BESLUT B31) måttet följer. METOD M29
    public struct Mattpost: Decodable, Sendable {
        public let matt: String
        /// "dtl" eller "fo".
        public let vy: String
        public let positioner: [String]
        /// Katalogens id för felet som måttet hör till (sway hittills → sway_topp), eller nil.
        public let fel: String?
        /// Fält utöver matt, vy, positioner och fel; kontrollen fäller dem, som Python.
        let andraFalt: [String]

        enum CodingKeys: String, CodingKey, CaseIterable {
            case matt, vy, positioner, fel
        }

        struct Nyckel: CodingKey {
            let stringValue: String
            init?(stringValue: String) { self.stringValue = stringValue }
            var intValue: Int? { nil }
            init?(intValue: Int) { nil }
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            matt = try c.decode(String.self, forKey: .matt)
            vy = try c.decode(String.self, forKey: .vy)
            positioner = try c.decode([String].self, forKey: .positioner)
            fel = try c.decodeIfPresent(String.self, forKey: .fel)
            let kanda = Set(CodingKeys.allCases.map { $0.rawValue })
            andraFalt = try decoder.container(keyedBy: Nyckel.self).allKeys.map { $0.stringValue }
                .filter { !kanda.contains($0) }
        }
    }

    /// Felets och måttens positioner: en lista ur `Positioner.namn`, utan dubbletter och
    /// i svingens ordning. Ett fel får ha en tom lista (tempot), ett mått inte.
    static let positionerFel = "positioner ska vara en lista av "
        + Positioner.namn.joined(separator: ", ") + " i svingens ordning"

    static func positionernaOK(_ p: [String], tom: Bool) -> Bool {
        let i = p.compactMap { Positioner.namn.firstIndex(of: $0) }
        guard i.count == p.count, tom || !p.isEmpty else { return false }
        return i == Array(Set(i)).sorted()
    }

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
        /// Övningens stabila id (historiken jämför på det, inte på texten).
        public let ovningId: String
        public let ovning: String
        public let tanke: String
        public let notering: String?
        /// P-positionerna där granskningen visar felets mått (BESLUT B32); tom = hela svingen.
        public let positioner: [String]

        enum CodingKeys: String, CodingKey {
            case id, namn, vy, matt, fas, gront, gult, kalla, status, kontrollerad, aktiv, samre, ovning, tanke, notering
            case positioner
            case ovningId = "ovning_id"
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
            ovningId = try c.decode(String.self, forKey: .ovningId)
            ovning = try c.decode(String.self, forKey: .ovning)
            tanke = try c.decode(String.self, forKey: .tanke)
            notering = try c.decodeIfPresent(String.self, forKey: .notering)
            positioner = try c.decode([String].self, forKey: .positioner)
        }
    }

    /// Katalogens form, som `kontrollera` i tools/pc/katalog.py. Felen nämner felets id
    /// (eller måttet) och fältet.
    public static func kontrollera(_ k: Katalog) -> [String] {
        var fel: [String] = []
        if k.version != 1 { fel.append("katalogen: ska ha version 1") }
        var sedda = Set<String>()
        var visade = Set<String>()                  // "vy/mått" som granskningen visar
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
            if !positionernaOK(e.positioner, tom: true) { fel.append("\(e.id): \(positionerFel)") }
            for vy in e.vy == "bada" ? ["dtl", "fo"] : [e.vy] { visade.insert("\(vy)/\(e.matt)") }
        }
        let felen = Set(k.fel.map { $0.id })
        for e in k.matt {
            let namn = "matt \(e.matt)"
            if !e.andraFalt.isEmpty {
                fel.append("\(namn): ska ha matt, vy och positioner, och får ha fel")
                continue
            }
            if let f = e.fel, !felen.contains(f) { fel.append("\(namn): fel ska vara ett fel i katalogen") }
            if let vy = Vy(rawValue: e.vy) {
                if !Matt.namn(vy).contains(e.matt) { fel.append("\(namn): måttet finns inte i vyn") }
            } else {
                fel.append("\(namn): vy ska vara dtl eller fo")
            }
            if visade.contains("\(e.vy)/\(e.matt)") { fel.append("\(namn): står redan i katalogen") }
            visade.insert("\(e.vy)/\(e.matt)")
            if !positionernaOK(e.positioner, tom: false) { fel.append("\(namn): \(positionerFel)") }
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
