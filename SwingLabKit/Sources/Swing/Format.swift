import Foundation

/// En punkt i bilden, i pixlar: X (+ mot målet eller bollen efter läsningen) och
/// Y (nedåt). En saknad punkt är NaN.
public struct Punkt: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public static let saknad = Punkt(.nan, .nan)

    /// Båda koordinaterna har värde.
    public var hel: Bool { x.isFinite && y.isFinite }

    public var langd: Double { (x * x + y * y).squareRoot() }

    public static func + (a: Punkt, b: Punkt) -> Punkt { Punkt(a.x + b.x, a.y + b.y) }
    public static func - (a: Punkt, b: Punkt) -> Punkt { Punkt(a.x - b.x, a.y - b.y) }

    /// Mittpunkten, som i Python: (a + b) / 2.
    public static func mitt(_ a: Punkt, _ b: Punkt) -> Punkt { Punkt((a.x + b.x) / 2, (a.y + b.y) / 2) }
}

public enum Vy: String, Codable, Sendable {
    case dtl, fo
}

public enum Hand: String, Codable, Sendable {
    case hoger, vanster
}

/// Lederna internt: främre (mot målet) och bakre sida. För en högerspelare är
/// främre = vänster. METOD M1
public enum Led: Int, CaseIterable, Sendable {
    case nasa = 0, axelF, axelB, armbageF, armbageB, handledF, handledB, hoftF, hoftB, knaF, knaB, fotledF, fotledB
}

/// Felet nämner fältet och rutan, aldrig värdet (CLAUDE.md, Dataregeln).
public struct FormatFel: Error, CustomStringConvertible, Equatable {
    public let beskrivning: String
    public init(_ beskrivning: String) { self.beskrivning = beskrivning }
    public var description: String { beskrivning }
}

/// En sving i filformatet (docs/FORMAT.md), läst och omräknad till främre och
/// bakre sida med +X mot målet (FO) eller bollen (DTL). METOD M1
public struct Sving: Sendable {
    public static let format = 1
    /// Ledernas ordning i filen: snittet av Apple Visions 2D-leder och MediaPipe.
    public static let lederIFilen = ["nasa", "axel_v", "axel_h", "armbage_v", "armbage_h", "handled_v",
                                     "handled_h", "hoft_v", "hoft_h", "kna_v", "kna_h", "fotled_v", "fotled_h"]
    public static let antalLeder = 13
    /// Under detta räknas leden som saknad i rutan. METOD M1
    public static let minKonfidens = 0.3
    static let langdGrans = 1.0...2.5

    /// Internt index → index i filen. Vänsterspelaren byter sida på varje par.
    static func franFil(_ hand: Hand) -> [Int] {
        switch hand {
        case .hoger: return Array(0..<13)
        case .vanster: return [0, 2, 1, 4, 3, 6, 5, 8, 7, 10, 9, 12, 11]
        }
    }

    public let vy: Vy
    public let hand: Hand
    /// +1 eller −1: bildens x mot målet (FO) eller bollen (DTL).
    public let xTecken: Double
    public let langdM: Double
    public let tKlick: Double
    /// Rutornas tider i s, stigande.
    public let t: [Double]
    /// leder[led][ruta], NaN där leden saknas.
    public let leder: [[Punkt]]

    public init(vy: Vy, hand: Hand, xTecken: Double, langdM: Double, tKlick: Double, t: [Double], leder: [[Punkt]]) {
        self.vy = vy
        self.hand = hand
        self.xTecken = xTecken
        self.langdM = langdM
        self.tKlick = tKlick
        self.t = t
        self.leder = leder
    }

    public func led(_ l: Led) -> [Punkt] { leder[l.rawValue] }

    // MARK: läsningen

    private struct Fil: Decodable {
        let format: Int?
        let vy: String?
        let hand: String?
        let xMotMalet: Double?
        let xMotBollen: Double?
        let langd: Double?
        let tKlick: Double?
        let rutor: [Ruta]?

        enum CodingKeys: String, CodingKey {
            case format, vy, hand, rutor
            case xMotMalet = "x_mot_malet"
            case xMotBollen = "x_mot_bollen"
            case langd = "spelarens_langd_m"
            case tKlick = "t_klick"
        }
    }

    private struct Ruta: Decodable {
        let t: Double?
        let leder: [[Double]]?
    }

    /// Var i filen ett avkodningsfel sitter, utan värdet.
    private static func plats(_ vag: [CodingKey]) -> String {
        var s = ""
        for k in vag {
            if let i = k.intValue {
                s += "[\(i)]"
            } else {
                s += s.isEmpty ? k.stringValue : ".\(k.stringValue)"
            }
        }
        return s.isEmpty ? "svingen" : s
    }

    public static func las(_ data: Data) throws -> Sving {
        let fil: Fil
        do {
            fil = try JSONDecoder().decode(Fil.self, from: data)
        } catch let DecodingError.typeMismatch(_, kontext) {
            throw FormatFel("\(plats(kontext.codingPath)): fel typ")
        } catch let DecodingError.valueNotFound(_, kontext) {
            throw FormatFel("\(plats(kontext.codingPath)): saknar värde")
        } catch let DecodingError.keyNotFound(nyckel, kontext) {
            throw FormatFel("\(plats(kontext.codingPath + [nyckel])): saknas")
        } catch {
            throw FormatFel("inte giltig JSON")
        }
        return try fran(fil)
    }

    public static func las(json: String) throws -> Sving {
        try las(Data(json.utf8))
    }

    private static func fran(_ f: Fil) throws -> Sving {
        guard f.format == format else { throw FormatFel("format: ska vara \(format)") }
        guard let vyText = f.vy, let vy = Vy(rawValue: vyText) else {
            throw FormatFel("vy: ska vara \"dtl\" eller \"fo\"")
        }
        guard let handText = f.hand, let hand = Hand(rawValue: handText) else {
            throw FormatFel("hand: ska vara \"hoger\" eller \"vanster\"")
        }
        let falt = vy == .fo ? "x_mot_malet" : "x_mot_bollen"
        // Utan fältet: standardkameran, där vänsterspelaren är spegelvänd.
        let tecken = (vy == .fo ? f.xMotMalet : f.xMotBollen) ?? (hand == .hoger ? 1.0 : -1.0)
        guard tecken == 1.0 || tecken == -1.0 else { throw FormatFel("\(falt): ska vara 1 eller -1") }
        guard let langd = f.langd, langd.isFinite else {
            throw FormatFel("spelarens_langd_m: ska vara ett ändligt tal")
        }
        guard langdGrans.contains(langd) else { throw FormatFel("spelarens_langd_m: utanför 1,0–2,5 m") }
        guard let tKlick = f.tKlick, tKlick.isFinite else { throw FormatFel("t_klick: ska vara ett ändligt tal") }
        guard let rutor = f.rutor, !rutor.isEmpty else { throw FormatFel("rutor: saknas eller är tom") }

        var tider = [Double](repeating: 0, count: rutor.count)
        for (i, r) in rutor.enumerated() {
            guard let t = r.t, t.isFinite else { throw FormatFel("ruta \(i): t: ska vara ett ändligt tal") }
            guard let leder = r.leder, leder.count == antalLeder else {
                throw FormatFel("ruta \(i): leder ska vara \(antalLeder) st")
            }
            for (j, led) in leder.enumerated() {
                guard led.count == 3 else { throw FormatFel("ruta \(i), \(lederIFilen[j]): ska vara [x, y, konfidens]") }
                guard led.allSatisfy({ $0.isFinite }) else {
                    throw FormatFel("ruta \(i), \(lederIFilen[j]): ska vara ett ändligt tal")
                }
            }
            tider[i] = t
        }

        // Stabil sortering på tiden: lika tider behåller filens ordning.
        let ordning = tider.indices.sorted { a, b in tider[a] < tider[b] || (tider[a] == tider[b] && a < b) }
        let karta = franFil(hand)
        var leder = [[Punkt]](repeating: [], count: antalLeder)
        for (iInt, iFil) in karta.enumerated() {
            leder[iInt] = ordning.map { k -> Punkt in
                let v = rutor[k].leder![iFil]
                return v[2] < minKonfidens ? .saknad : Punkt(tecken * v[0], v[1])
            }
        }
        return Sving(vy: vy, hand: hand, xTecken: tecken, langdM: langd, tKlick: tKlick,
                     t: ordning.map { tider[$0] }, leder: leder)
    }
}
