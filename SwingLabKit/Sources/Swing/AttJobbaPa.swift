import Foundation

/// `att_jobba_pa.json`: det PC:n och Claude valt efter ett pass (PLAN S5, BESLUT B28).
/// Formen ägs av S5 och är kontraktet i docs/FORMAT.md (Att jobba på); vyn visar den
/// som den är, utan att räkna om något. `tools/pc/att_jobba_pa.py` kontrollerar den
/// på PC:n; telefonen kräver formatet och fälten vyn läser, och felet nämner
/// fältet, aldrig värdet (CLAUDE.md, Dataregeln).
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
        /// Fel som mäts men inte övas, ett eller flera led efter saken (kedjan).
        public let foljdfel: [Foljdfel]
        /// "teknik", "teknik_kroppen_gor_det_svart" eller "troligen_rorlighet".
        public let typ: String
        public let fysik: Fysik?
        public let block: Block

        enum CodingKeys: String, CodingKey {
            case ordning, fel, namn, vy, matt, enhet, nu, spann, markning, ovning, foljdfel, typ, fysik, block
            case klartNar = "klart_nar"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            // Formen är stängd (docs/FORMAT.md): nu, spann, markning och fysik står med även när de är null.
            for nyckel in [CodingKeys.nu, .spann, .markning, .fysik] where !c.contains(nyckel) {
                throw DecodingError.keyNotFound(nyckel, DecodingError.Context(codingPath: c.codingPath,
                                                                              debugDescription: "saknas"))
            }
            ordning = try c.decode(Int.self, forKey: .ordning)
            fel = try c.decode(String.self, forKey: .fel)
            namn = try c.decode(String.self, forKey: .namn)
            vy = try c.decode(String.self, forKey: .vy)
            matt = try c.decode(String.self, forKey: .matt)
            enhet = try c.decode(String.self, forKey: .enhet)
            nu = try c.decodeIfPresent(Double.self, forKey: .nu)
            spann = try c.decodeIfPresent([Double?].self, forKey: .spann)
            markning = try c.decodeIfPresent(String.self, forKey: .markning)
            ovning = try c.decode(Ovning.self, forKey: .ovning)
            klartNar = try c.decode(KlartNar.self, forKey: .klartNar)
            foljdfel = try c.decode([Foljdfel].self, forKey: .foljdfel)
            typ = try c.decode(String.self, forKey: .typ)
            fysik = try c.decodeIfPresent(Fysik.self, forKey: .fysik)
            block = try c.decode(Block.self, forKey: .block)
        }
    }

    public struct Ovning: Decodable, Sendable {
        /// Stegen i ordning (METOD MT10 i S5).
        public static let stegen = ["langsamt_med_foremal", "halv_fart", "full_fart", "varierat"]

        public let text: String
        public let tanke: String
        /// "katalog" eller "research3".
        public let kalla: String
        /// Ett av `stegen`: var Johannes är.
        public let steg: String
    }

    public struct Foljdfel: Decodable, Sendable {
        public let fel: String
        public let namn: String
        /// Kedjans väg från saken till följdfelet, saken först.
        public let vag: [String]
        public let nu: Double?
        public let enhet: String

        enum CodingKeys: String, CodingKey { case fel, namn, vag, nu, enhet }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            guard c.contains(.nu) else {
                throw DecodingError.keyNotFound(CodingKeys.nu, DecodingError.Context(codingPath: c.codingPath,
                                                                                    debugDescription: "saknas"))
            }
            fel = try c.decode(String.self, forKey: .fel)
            namn = try c.decode(String.self, forKey: .namn)
            vag = try c.decode([String].self, forKey: .vag)
            nu = try c.decodeIfPresent(Double.self, forKey: .nu)
            enhet = try c.decode(String.self, forKey: .enhet)
        }
    }

    /// Blocket: dagen felet först valdes och veckan i blocket.
    public struct Block: Decodable, Sendable {
        /// "2026-11-03"
        public let start: String
        public let vecka: Int
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

    /// Felen som övas: de som bär accenten i Passet, Idag, Utveckling och Granskningen (BESLUT B31).
    public var ovas: Set<String> { Set(saker.map { $0.fel }) }

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
        for (i, s) in a.saker.enumerated() where !Ovning.stegen.contains(s.ovning.steg) {
            throw FormatFel("att_jobba_pa: saker[\(i)].ovning.steg: ska vara ett av \(Ovning.stegen.joined(separator: ", "))")
        }
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
