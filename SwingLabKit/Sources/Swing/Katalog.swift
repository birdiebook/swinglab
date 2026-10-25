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
    /// Måtten vars spridning mellan slagen passet och Progress visar, ett tal per pass
    /// (METOD M44, BESLUT B46).
    public let spridning: [Spridningspost]
    /// Måtten ur två telefoner (S6c-2, BESLUT B37, B62): trenden per pass utan bedömning.
    public let treD: [TreDPost]

    enum CodingKeys: String, CodingKey {
        case version, fel, matt, spridning
        case treD = "tre_d"
    }

    /// 3D-måtten i analysens ordning (METOD MK6), som `tva_kameror.MATT` och `TvaKameror.matt`.
    public static let treDMatt = ["backen_vrid_topp", "brost_vrid_topp", "xfaktor_topp", "xfaktor_stretch",
                                  "hofter_oppna_traff"]
    public static let treDLagen = ["utan_markorer", "med_markorer"]          // BESLUT B14

    /// Ett 3D-mått (katalogens `tre_d`, docs/FORMAT.md): namnet, läget, slagen som passets median
    /// kräver, riktmärket och källan, och infobladet (BESLUT B41). Bedöms aldrig (B14, B37).
    public struct TreDPost: Decodable, Sendable {
        public let matt: String
        public let namn: String
        public let enhet: String
        public let fas: String
        public let lage: String
        public let minSlag: Int
        /// Riktmärket, visas inte än (Johannes 2026-10-24).
        public let spann: [Double?]?
        public let kalla: String
        public let status: String
        public let kontrollerad: Bool
        public let notering: String
        public let vad: String
        public let varfor: String
        public let tecken: String
        let andraFalt: [String]
        let saknas: [String]

        enum CodingKeys: String, CodingKey, CaseIterable {
            case matt, namn, enhet, fas, lage
            case minSlag = "min_slag"
            case spann, kalla, status, kontrollerad, notering, vad, varfor, tecken
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let alla = try decoder.container(keyedBy: Mattpost.Nyckel.self).allKeys.map { $0.stringValue }
            let kanda = Set(CodingKeys.allCases.map { $0.rawValue })
            andraFalt = alla.filter { !kanda.contains($0) }
            saknas = CodingKeys.allCases.map { $0.rawValue }.filter { !alla.contains($0) }
            matt = try c.decodeIfPresent(String.self, forKey: .matt) ?? ""
            namn = try c.decodeIfPresent(String.self, forKey: .namn) ?? ""
            enhet = try c.decodeIfPresent(String.self, forKey: .enhet) ?? ""
            fas = try c.decodeIfPresent(String.self, forKey: .fas) ?? ""
            lage = try c.decodeIfPresent(String.self, forKey: .lage) ?? ""
            minSlag = try c.decodeIfPresent(Int.self, forKey: .minSlag) ?? 0
            spann = try c.decodeIfPresent([Double?].self, forKey: .spann)
            kalla = try c.decodeIfPresent(String.self, forKey: .kalla) ?? ""
            status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
            kontrollerad = try c.decodeIfPresent(Bool.self, forKey: .kontrollerad) ?? false
            notering = try c.decodeIfPresent(String.self, forKey: .notering) ?? ""
            vad = try c.decodeIfPresent(String.self, forKey: .vad) ?? ""
            varfor = try c.decodeIfPresent(String.self, forKey: .varfor) ?? ""
            tecken = try c.decodeIfPresent(String.self, forKey: .tecken) ?? ""
        }

        /// Progress-måttets id: skilt från felens och spridningens.
        public var id: String { "\(matt)_3d" }
    }

    /// Ett mått vars spridning mellan passets slag visas: måttet, vyn och infobladet. METOD M44
    public struct Spridningspost: Decodable, Sendable {
        public let matt: String
        /// "dtl" eller "fo".
        public let vy: String
        public let vad: String
        public let varfor: String
        public let tecken: String
        /// Det sämre hållet och golvet: rött åt det hållet utanför den egna baslinjen (METOD M62).
        public let samre: String?
        public let golv: Double?
        /// Fält utöver de sju; kontrollen fäller dem, som Python.
        let andraFalt: [String]
        let falt: Set<String>

        enum CodingKeys: String, CodingKey, CaseIterable {
            case matt, vy, vad, varfor, tecken, samre, golv
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            matt = try c.decode(String.self, forKey: .matt)
            vy = try c.decode(String.self, forKey: .vy)
            vad = try c.decode(String.self, forKey: .vad)
            varfor = try c.decode(String.self, forKey: .varfor)
            tecken = try c.decode(String.self, forKey: .tecken)
            samre = try? c.decodeIfPresent(String.self, forKey: .samre)
            golv = try? c.decodeIfPresent(Double.self, forKey: .golv)
            falt = Set(try decoder.container(keyedBy: Mattpost.Nyckel.self).allKeys.map { $0.stringValue })
            let kanda = Set(CodingKeys.allCases.map { $0.rawValue })
            andraFalt = try decoder.container(keyedBy: Mattpost.Nyckel.self).allKeys.map { $0.stringValue }
                .filter { !kanda.contains($0) }
        }

        /// Kortets och Progress-måttets id: skilt från felens.
        public var id: String { "\(matt)_spridning" }
    }

    /// Ett mått i granskningen: namnet, vyn och positionerna, och valfritt felet vars
    /// accent (BESLUT B31) måttet följer. METOD M29
    public struct Mattpost: Decodable, Sendable {
        public let matt: String
        /// "dtl" eller "fo".
        public let vy: String
        public let positioner: [String]
        /// Katalogens id för felet som måttet hör till (sway hittills → sway_topp), eller nil.
        public let fel: String?
        /// "oprovad" = oprövat på telefonen (farterna, METOD M35–M37, BESLUT B11), eller nil.
        public let status: String?
        /// Infobladet (BESLUT B41): vad som mäts, varför det spelar roll och tecknet, på engelska.
        public let vad: String
        public let varfor: String
        public let tecken: String
        /// Bandet med källa (research 6, BESLUT B86): järnets, och driverns som inte används än.
        /// nil = egen baslinje. METOD M62
        public let gront: [Double?]?
        public let grontDriver: [Double?]?
        /// Måttets brusgolv: gult inom det utanför bandet, rött längre bort (BESLUT B87).
        public let golv: Double?
        /// Det sämre hållet för den egna baslinjen ("+" eller "-"): rött åt det hållet (METOD M62).
        public let samre: String?
        /// Bandets källa: adresserna, statusen (som felens `status`), läst i original och härledd.
        public let kalla: String?
        public let kallaStatus: String?
        public let kontrollerad: Bool?
        public let gransHarledd: Bool
        /// false = dom (b): visas inte för spelaren, men finns i exporten och underlaget (B86).
        public let visas: Bool
        /// Fält utöver de kända; kontrollen fäller dem, och ett av infobladets fält som saknas,
        /// som Python.
        let andraFalt: [String]
        let saknasInfo: Bool
        /// Fälten som står i posten, och de som inte gick att läsa som sin typ (kontrollen).
        let falt: Set<String>
        let felTyp: [String]

        enum CodingKeys: String, CodingKey, CaseIterable {
            case matt, vy, positioner, fel, status, vad, varfor, tecken
            case gront
            case grontDriver = "gront_driver"
            case golv, samre, kalla
            case kallaStatus = "kalla_status"
            case kontrollerad
            case gransHarledd = "grans_harledd"
            case visas
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
            status = try c.decodeIfPresent(String.self, forKey: .status)
            let v = try c.decodeIfPresent(String.self, forKey: .vad)
            let w = try c.decodeIfPresent(String.self, forKey: .varfor)
            let t = try c.decodeIfPresent(String.self, forKey: .tecken)
            vad = v ?? ""
            varfor = w ?? ""
            tecken = t ?? ""
            saknasInfo = v == nil || w == nil || t == nil
            var felTyp: [String] = []
            func las<T: Decodable>(_ typ: T.Type, _ n: CodingKeys) -> T? {
                guard c.contains(n) else { return nil }
                if let x = try? c.decodeNil(forKey: n), x { felTyp.append(n.rawValue); return nil }
                guard let x = try? c.decode(typ, forKey: n) else { felTyp.append(n.rawValue); return nil }
                return x
            }
            gront = las([Double?].self, .gront)
            grontDriver = las([Double?].self, .grontDriver)
            golv = las(Double.self, .golv)
            samre = las(String.self, .samre)
            kalla = las(String.self, .kalla)
            kallaStatus = las(String.self, .kallaStatus)
            kontrollerad = las(Bool.self, .kontrollerad)
            let harledd = las(Bool.self, .gransHarledd)
            gransHarledd = harledd ?? false
            if harledd == false { felTyp.append(CodingKeys.gransHarledd.rawValue) }      // bara true, som Python
            visas = las(Bool.self, .visas) ?? true
            self.felTyp = felTyp
            let kanda = Set(CodingKeys.allCases.map { $0.rawValue })
            let alla = try decoder.container(keyedBy: Nyckel.self).allKeys.map { $0.stringValue }
            falt = Set(alla)
            andraFalt = alla.filter { !kanda.contains($0) }
        }
    }

    /// Felets och måttens positioner: en lista ur `Positioner.namn`, utan dubbletter och
    /// i svingens ordning. Ett fel får ha en tom lista (tempot), ett mått inte. Klubbans
    /// mått får alla tio (P2, P6 och P8 ur markeringen, METOD M45). Som `katalog.positionerna_ok`.
    static let positionerFel = "positioner ska vara en lista av "
        + Positioner.namn.joined(separator: ", ") + " i svingens ordning"

    static func positionernaOK(_ p: [String], tom: Bool, klubba: Bool = false) -> Bool {
        let alla = klubba ? Klubba.positioner : Positioner.namn
        let i = p.compactMap { alla.firstIndex(of: $0) }
        guard i.count == p.count, tom || !p.isEmpty else { return false }
        return i == Array(Set(i)).sorted()
    }

    public struct Fel: Decodable, Sendable {
        public let id: String
        public let namn: String
        /// "dtl", "fo" eller "bada" (alla svingar ihop).
        public let vy: String
        public internal(set) var matt: String
        public let fas: String
        /// [min, max], nil i en ände = öppen. nil = egen baslinje. Järnets band (BESLUT B86).
        public internal(set) var gront: [Double?]?
        /// Driverns band, som inte används än (BESLUT B86).
        public internal(set) var grontDriver: [Double?]?
        /// Måttets brusgolv: gult inom det utanför bandet, rött längre bort (BESLUT B87, METOD M62).
        public internal(set) var golv: Double
        public internal(set) var kalla: String
        public internal(set) var status: String
        /// false tills källan lästs i original (BESLUT B10).
        public internal(set) var kontrollerad: Bool
        public let aktiv: Bool
        /// "+" eller "-": åt vilket håll måttet blir sämre. nil = båda.
        public internal(set) var samre: String?
        /// Övningens stabila id (historiken jämför på det, inte på texten).
        public let ovningId: String
        public let ovning: String
        public let tanke: String
        public let notering: String?
        /// P-positionerna där granskningen visar felets mått (BESLUT B32); tom = hela svingen.
        public internal(set) var positioner: [String]
        /// Infobladet (BESLUT B41): vad som mäts, varför det spelar roll och tecknet, på engelska.
        public internal(set) var vad: String
        public internal(set) var varfor: String
        public internal(set) var tecken: String
        /// Gränsen är ett antagande härlett ur källan (sway_topp, METOD M15); bladets källa
        /// säger då "Assumption from manufacturer". Valfritt, false utan fältet. BESLUT B41
        public internal(set) var gransHarledd: Bool
        /// false = dom (b): visas inte i sessionen för spelaren (BESLUT B86). Valfritt, true utan fältet.
        public let visas: Bool
        /// Felets källa när klubban är markerad i passet (over the top, BESLUT B88), eller nil.
        public let klubba: Klubbkalla?
        /// Fälten utöver de kända (kontrollen fäller dem, som Python).
        let andraFalt: [String]

        /// Det gula spannet: bandet vidgat med golvet åt båda hållen, nil utan band. Analysen
        /// och underlaget till Claude bär det som `gult` (METOD M62, `katalog.gult`).
        public var gult: [Double?]? {
            guard let g = gront, g.count == 2 else { return nil }
            return [g[0].map { $0 - golv }, g[1].map { $0 + golv }]
        }

        enum CodingKeys: String, CodingKey, CaseIterable {
            case id, namn, vy, matt, fas, gront, golv, kalla, status, kontrollerad, aktiv, samre, ovning, tanke, notering
            case positioner, vad, varfor, tecken, visas, klubba
            case grontDriver = "gront_driver"
            case gransHarledd = "grans_harledd"
            case ovningId = "ovning_id"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            // gront och samre ska stå med även när de är null, som i Python.
            for nyckel in [CodingKeys.gront, .samre] where !c.contains(nyckel) {
                throw DecodingError.keyNotFound(nyckel, DecodingError.Context(codingPath: c.codingPath,
                                                                              debugDescription: "saknas"))
            }
            id = try c.decode(String.self, forKey: .id)
            namn = try c.decode(String.self, forKey: .namn)
            vy = try c.decode(String.self, forKey: .vy)
            matt = try c.decode(String.self, forKey: .matt)
            fas = try c.decode(String.self, forKey: .fas)
            gront = try c.decodeIfPresent([Double?].self, forKey: .gront)
            grontDriver = try c.decodeIfPresent([Double?].self, forKey: .grontDriver)
            golv = try c.decode(Double.self, forKey: .golv)
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
            vad = try c.decode(String.self, forKey: .vad)
            varfor = try c.decode(String.self, forKey: .varfor)
            tecken = try c.decode(String.self, forKey: .tecken)
            gransHarledd = try c.decodeIfPresent(Bool.self, forKey: .gransHarledd) ?? false
            visas = try c.decodeIfPresent(Bool.self, forKey: .visas) ?? true
            klubba = try c.decodeIfPresent(Klubbkalla.self, forKey: .klubba)
            let kanda = Set(CodingKeys.allCases.map { $0.rawValue })
            andraFalt = try decoder.container(keyedBy: Mattpost.Nyckel.self).allKeys.map { $0.stringValue }
                .filter { !kanda.contains($0) }
        }
    }

    /// Felets källa när klubban är markerad i passet (BESLUT B88): ett av klubbans mått, dess
    /// positioner, band, golv, källa och infoblad. Som `klubba` i tools/pc/katalog.py.
    public struct Klubbkalla: Decodable, Sendable {
        public let matt: String
        public let positioner: [String]
        public let gront: [Double?]
        public let golv: Double
        public let kalla: String
        public let status: String
        public let kontrollerad: Bool
        public let gransHarledd: Bool
        public let vad: String
        public let varfor: String
        public let tecken: String

        enum CodingKeys: String, CodingKey {
            case matt, positioner, gront, golv, kalla, status, kontrollerad, vad, varfor, tecken
            case gransHarledd = "grans_harledd"
        }
    }

    /// Infobladets tre fält: text, inte tom (BESLUT B41), som `_info` i Python.
    static func info(_ namn: String, vad: String, varfor: String, tecken: String) -> [String] {
        [("vad", vad), ("varfor", varfor), ("tecken", tecken)]
            .filter { $0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { "\(namn): \($0.0) ska vara en text" }
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
            for f in e.andraFalt.sorted() { fel.append("\(e.id): okänt fält \(f)") }
            for (namn, spann) in [("gront", e.gront), ("gront_driver", e.grontDriver)] {
                if let s = spann, s.count != 2 { fel.append("\(e.id): \(namn) ska vara [min, max] eller null") }
            }
            if !(e.golv > 0) { fel.append("\(e.id): golv ska vara ett positivt tal") }
            if e.gront == nil && e.grontDriver != nil { fel.append("\(e.id): gront_driver utan gront") }
            if let kl = e.klubba { fel += klubbansFel(e, kl) }
            if e.gransHarledd && e.gront == nil {
                fel.append("\(e.id): grans_harledd ska vara true/false och kräver gront")
            }
            if !positionernaOK(e.positioner, tom: true) { fel.append("\(e.id): \(positionerFel)") }
            fel += info(e.id, vad: e.vad, varfor: e.varfor, tecken: e.tecken)
            for vy in e.vy == "bada" ? ["dtl", "fo"] : [e.vy] { visade.insert("\(vy)/\(e.matt)") }
        }
        let felen = Set(k.fel.map { $0.id })
        for e in k.matt {
            let namn = "matt \(e.matt)"
            if !e.andraFalt.isEmpty || e.saknasInfo {
                fel.append("\(namn): ska ha matt, vy, positioner, vad, varfor och tecken, och får ha fel och status")
                continue
            }
            fel += info(namn, vad: e.vad, varfor: e.varfor, tecken: e.tecken)
            if let s = e.status, s != "oprovad" { fel.append("\(namn): status ska vara oprovad") }
            if let f = e.fel, !felen.contains(f) { fel.append("\(namn): fel ska vara ett fel i katalogen") }
            fel += bandetsFel(namn, falt: e.falt, felTyp: e.felTyp, gront: e.gront, grontDriver: e.grontDriver,
                              golv: e.golv, samre: e.samre, kallaStatus: e.kallaStatus)
            if let vy = Vy(rawValue: e.vy) {
                // Klubbans mått ur markeringarna (METOD M46–M49) står också här.
                if !(Matt.namn(vy) + Klubba.katalognamn(vy)).contains(e.matt) {
                    fel.append("\(namn): måttet finns inte i vyn")
                }
            } else {
                fel.append("\(namn): vy ska vara dtl eller fo")
            }
            if visade.contains("\(e.vy)/\(e.matt)") { fel.append("\(namn): står redan i katalogen") }
            visade.insert("\(e.vy)/\(e.matt)")
            let klubba = Vy(rawValue: e.vy).map { Klubba.katalognamn($0).contains(e.matt) } ?? false
            if !positionernaOK(e.positioner, tom: false, klubba: klubba) { fel.append("\(namn): \(positionerFel)") }
        }
        var spridda = Set<String>()
        for e in k.spridning {
            let namn = "spridning \(e.matt)"
            if !e.andraFalt.isEmpty {
                fel.append("\(namn): ska ha matt, vy, vad, varfor och tecken, och får ha samre och golv")
                continue
            }
            fel += info(namn, vad: e.vad, varfor: e.varfor, tecken: e.tecken)
            fel += bandetsFel(namn, falt: e.falt, felTyp: [], gront: nil, grontDriver: nil, golv: e.golv, samre: e.samre,
                              kallaStatus: nil)
            if let vy = Vy(rawValue: e.vy) {
                if !Matt.namn(vy).contains(e.matt) { fel.append("\(namn): måttet finns inte i vyn") }
            } else {
                fel.append("\(namn): vy ska vara dtl eller fo")
            }
            if spridda.contains("\(e.vy)/\(e.matt)") { fel.append("\(namn): står två gånger") }
            spridda.insert("\(e.vy)/\(e.matt)")
        }
        fel += kontrolleraTreD(k.treD)
        return fel
    }

    /// Ett mått med band eller riktning (BESLUT B86, METOD M62), som `_band_fel` i Python: gront
    /// kräver golv och källan, samre kräver golv, grans_harledd och gront_driver kräver gront.
    static func bandetsFel(_ namn: String, falt: Set<String>, felTyp: [String], gront: [Double?]?,
                           grontDriver: [Double?]?, golv: Double?, samre: String?, kallaStatus: String?) -> [String] {
        var fel: [String] = []
        for (n, g) in [("gront", gront), ("gront_driver", grontDriver)] where falt.contains(n) {
            if felTyp.contains(n) || g?.count != 2 { fel.append("\(namn): \(n) ska vara [min, max]") }
        }
        if falt.contains("gront"), !["golv", "kalla", "kalla_status", "kontrollerad"].allSatisfy(falt.contains) {
            fel.append("\(namn): gront kräver golv, kalla, kalla_status, kontrollerad")
        }
        if falt.contains("samre"), samre != "+" && samre != "-" { fel.append("\(namn): samre ska vara \"+\" eller \"-\"") }
        if (falt.contains("gront") || falt.contains("samre")) && !falt.contains("golv") {
            fel.append("\(namn): gront och samre kräver golv")
        }
        if falt.contains("golv"), !((golv ?? 0) > 0) { fel.append("\(namn): golv ska vara ett positivt tal") }
        if falt.contains("golv"), !falt.contains("gront") && !falt.contains("samre") {
            fel.append("\(namn): golv kräver gront eller samre")
        }
        if falt.contains("kalla_status"), !statusar.contains(kallaStatus ?? "") {
            fel.append("\(namn): kalla_status ska vara en av \(statusar.joined(separator: ", "))")
        }
        if felTyp.contains("kontrollerad") { fel.append("\(namn): kontrollerad ska vara true/false") }
        if falt.contains("grans_harledd"), felTyp.contains("grans_harledd") || !falt.contains("gront") {
            fel.append("\(namn): grans_harledd ska vara true och kräver gront")
        }
        if falt.contains("gront_driver"), !falt.contains("gront") { fel.append("\(namn): gront_driver kräver gront") }
        if felTyp.contains("visas") { fel.append("\(namn): visas ska vara true/false") }
        return fel
    }

    /// Felets källa med klubban (BESLUT B88), som `_klubba_fel` i Python.
    static func klubbansFel(_ e: Fel, _ k: Klubbkalla) -> [String] {
        var fel: [String] = []
        if Vy(rawValue: e.vy).map({ !Klubba.katalognamn($0).contains(k.matt) }) ?? true {
            fel.append("\(e.id): klubbans mått finns inte i vyn")
        }
        if !positionernaOK(k.positioner, tom: false, klubba: true) { fel.append("\(e.id): klubbans \(positionerFel)") }
        if k.gront.count != 2 { fel.append("\(e.id): klubbans gront ska vara [min, max]") }
        if !(k.golv > 0) { fel.append("\(e.id): klubbans golv ska vara ett positivt tal") }
        if !statusar.contains(k.status) {
            fel.append("\(e.id): klubbans status ska vara en av \(statusar.joined(separator: ", "))")
        }
        fel += info("\(e.id) klubba", vad: k.vad, varfor: k.varfor, tecken: k.tecken)
        return fel
    }

    /// Katalogens `tre_d`, som `kontrollera_3d` i tools/pc/katalog.py: fälten, varje 3D-mått en
    /// gång, läget, min_slag, spannet, statusen och infobladet. BESLUT B37, B41
    static func kontrolleraTreD(_ poster: [TreDPost]) -> [String] {
        var fel: [String] = []
        var sedda = Set<String>()
        for e in poster {
            let namn = e.matt.isEmpty ? "tre_d" : e.matt
            if !e.andraFalt.isEmpty || !e.saknas.isEmpty {
                fel.append("\(namn): ska ha fälten " + TreDPost.CodingKeys.allCases.map { $0.rawValue }.joined(separator: ", "))
                continue
            }
            if !treDMatt.contains(e.matt) { fel.append("\(namn): inget 3D-mått") }
            if sedda.contains(e.matt) { fel.append("\(namn): står två gånger") }
            sedda.insert(e.matt)
            if !treDLagen.contains(e.lage) { fel.append("\(namn): lage ska vara \(treDLagen.joined(separator: " eller "))") }
            if e.minSlag < 1 { fel.append("\(namn): min_slag ska vara ett positivt heltal") }
            if let s = e.spann, s.count != 2 { fel.append("\(namn): spann ska vara [min, max] eller null") }
            if !statusar.contains(e.status) { fel.append("\(namn): status ska vara en av \(statusar.joined(separator: ", "))") }
            fel += info(namn, vad: e.vad, varfor: e.varfor, tecken: e.tecken)
        }
        let saknas = treDMatt.filter { !sedda.contains($0) }
        if !saknas.isEmpty { fel.append("tre_d: saknar " + saknas.sorted().joined(separator: ", ")) }
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

/// Passets spridning mellan slagen för ett mått i katalogens `spridning`. METOD M44
public struct Spridning: Equatable, Sendable {
    public let matt: String
    public let vy: String
    /// Svingar med måttet i passet.
    public let n: Int
    /// Den robusta sd:n (q3 − q1)/1,349 (METOD M25, M26); nil under `minSlag` svingar.
    public let varde: Double?

    /// Slag för passets spridning: under dem är IQR/1,349 skev (0,63σ vid tre slag), 8
    /// räcker (Severin 2021, som baslinjen i M27). METOD M44
    public static let minSlag = 8

    /// Passets spridning för katalogens mått, i katalogens ordning. Samma tal som
    /// `spridning` i tools/pc/katalog.py. METOD M44
    public static func pass(_ katalog: Katalog, _ svingar: [SvingMatt]) -> [Spridning] {
        let sammanf = Session.sammanfattaSession(svingar)
        return katalog.spridning.map { e in
            let n = svingar.filter { $0.vy.rawValue == e.vy && ($0.matt[e.matt]?.isFinite ?? false) }.count
            let s = sammanf[e.vy]?[e.matt]
            return Spridning(matt: e.matt, vy: e.vy, n: n, varde: n >= minSlag ? s.map(Session.robustSD) : nil)
        }
    }
}

/// Bedömningen av ett pass mot katalogen. Samma regler som tools/pc/katalog.py. METOD M27
public enum Bedomare {
    /// Svingar i baslinjen (8 slag räcker, Severin 2021). METOD M27
    public static let minBaslinje = 8
    /// Inom 1 robust sd från baslinjen = grönt. METOD M27
    public static let gronZ = 1.0
    /// Inom 2 = gult, längre bort åt det sämre hållet = rött. METOD M27
    public static let gulZ = 2.0


    /// Ett fel bedömt för ett värde (passets median) mot gränsen eller baslinjen.
    public static func bedom(_ fel: Katalog.Fel, varde: Double?, baslinje: [Double]) -> Bedomning {
        func ut(_ status: Bedomningsstatus, _ grund: String? = nil, _ z: Double? = nil) -> Bedomning {
            Bedomning(id: fel.id, varde: varde, status: status, grund: grund, z: z)
        }
        guard fel.aktiv else { return ut(.av) }
        guard let v = varde else { return ut(.okand) }
        if let gront = fel.gront {
            // Gult inom golvet utanför bandet, rött längre bort (METOD M62, BESLUT B87).
            switch Bandlage.lage(v, gront: gront, golv: fel.golv).lage {
            case .gron: return ut(.gron, "grans")
            case .gul: return ut(.gul, "grans")
            case .rod, .ingen: return ut(.rod, "grans")
            }
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
