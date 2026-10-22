import Foundation

/// `att_jobba_pa.json`: det PC:n och Claude valt efter ett pass (PLAN S5, BESLUT B28).
/// Formen ägs av S5 och står i docs/FORMAT.md (Att jobba på); `tools/pc/att_jobba_pa.py`
/// kontrollerar den på PC:n. Telefonen kräver formatet och det vyn läser, och
/// felet nämner fältet, aldrig värdet (CLAUDE.md, Dataregeln).
public struct AttJobbaPa: Decodable, Sendable {
    public static let formatPrefix = "swinglab-att-jobba-pa/"

    public let format: String
    /// Passet tolkningen bygger på: "20261103-180000".
    public let pass: String
    public let skapad: String
    /// 1–3 saker i svingens ordning.
    public let saker: [Sak]

    public struct Sak: Decodable, Sendable {
        public let ordning: Int
        /// Felets id i katalogen.
        public let fel: String
        /// Katalogens namn (en beskrivning; vyn visar måttets korta namn).
        public let namn: String
        public let vy: String
        public let matt: String
        public let enhet: String
        /// Passets median när saken valdes, avrundad som analysen visar den.
        public let nu: Double?
        public let spann: [Double?]?
        /// "B10", "egen" eller nil.
        public let markning: String?
        public let ovning: Ovning
        public let klartNar: KlartNar
        /// Fel som mäts men inte övas, ett led efter saken.
        public let foljdfel: [String]
        /// "teknik", "teknik_kroppen_gor_det_svart" eller "troligen_rorlighet".
        public let typ: String
        public let fysik: Fysik?

        enum CodingKeys: String, CodingKey {
            case ordning, fel, namn, vy, matt, enhet, nu, spann, markning, ovning, foljdfel, typ, fysik
            case klartNar = "klart_nar"
        }
    }

    public struct Ovning: Decodable, Sendable {
        public let text: String
        public let tanke: String
        /// "katalog" eller "research3".
        public let kalla: String
    }

    public struct Fysik: Decodable, Sendable {
        public let test: String?
        public let treregeln: [Bool]?
        public let ovning: String?
    }

    /// "Klart när" som ett villkor i tal på första serien, så många pass i rad.
    public struct KlartNar: Decodable, Sendable {
        public enum Villkor: String, Decodable, Sendable {
            case minst = ">="
            case hogst = "<="
            case mellan
        }

        public let villkor: Villkor
        /// Gränsen; för `mellan` är `lo` och `hi` olika.
        public let lo: Double
        public let hi: Double
        /// "forsta_serien"
        public let pa: String
        public let passIRad: Int

        enum CodingKeys: String, CodingKey {
            case villkor, grans, pa
            case passIRad = "pass_i_rad"
        }

        public init(villkor: Villkor, lo: Double, hi: Double, pa: String = "forsta_serien", passIRad: Int) {
            self.villkor = villkor
            self.lo = lo
            self.hi = hi
            self.pa = pa
            self.passIRad = passIRad
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            villkor = try c.decode(Villkor.self, forKey: .villkor)
            pa = try c.decode(String.self, forKey: .pa)
            passIRad = try c.decode(Int.self, forKey: .passIRad)
            if villkor == .mellan {
                let g = try c.decode([Double].self, forKey: .grans)
                guard g.count == 2, g[0] <= g[1] else {
                    throw DecodingError.dataCorruptedError(forKey: .grans, in: c, debugDescription: "[min, max]")
                }
                lo = g[0]
                hi = g[1]
            } else {
                let g = try c.decode(Double.self, forKey: .grans)
                lo = g
                hi = g
            }
        }

        /// Villkoret för ett värde.
        public func haller(_ v: Double) -> Bool {
            switch villkor {
            case .minst: return v >= lo
            case .hogst: return v <= hi
            case .mellan: return v >= lo && v <= hi
            }
        }
    }

    /// Passets dag ur id:t "yyyyMMdd-HHmmss", i svensk tid.
    public var passDatum: Date? {
        let s = Array(pass)
        guard s.count >= 8, let ar = Int(String(s[0..<4])), let man = Int(String(s[4..<6])),
              let dag = Int(String(s[6..<8])) else { return nil }
        return Tal.kalender.date(from: DateComponents(year: ar, month: man, day: dag, hour: 0))
    }

    public static func las(_ data: Data) throws -> AttJobbaPa {
        let a: AttJobbaPa
        do {
            a = try JSONDecoder().decode(AttJobbaPa.self, from: data)
        } catch let DecodingError.keyNotFound(nyckel, k) {
            throw FormatFel("att_jobba_pa: \(plats(k.codingPath + [nyckel])) saknas")
        } catch let DecodingError.typeMismatch(_, k) {
            throw FormatFel("att_jobba_pa: \(plats(k.codingPath)): fel typ")
        } catch let DecodingError.valueNotFound(_, k) {
            throw FormatFel("att_jobba_pa: \(plats(k.codingPath)): saknar värde")
        } catch let DecodingError.dataCorrupted(k) {
            throw FormatFel("att_jobba_pa: \(plats(k.codingPath)): ogiltigt")
        } catch {
            throw FormatFel("att_jobba_pa: inte giltig JSON")
        }
        guard a.format.hasPrefix(formatPrefix) else { throw FormatFel("att_jobba_pa: format: ska börja med \(formatPrefix)") }
        guard (1...3).contains(a.saker.count) else { throw FormatFel("att_jobba_pa: saker: ska vara 1–3") }
        return a
    }

    public static func las(json: String) throws -> AttJobbaPa {
        try las(Data(json.utf8))
    }

    static func plats(_ vag: [CodingKey]) -> String {
        var s = ""
        for k in vag {
            if let i = k.intValue {
                s += "[\(i)]"
            } else {
                s += s.isEmpty ? k.stringValue : ".\(k.stringValue)"
            }
        }
        return s.isEmpty ? "filen" : s
    }
}
