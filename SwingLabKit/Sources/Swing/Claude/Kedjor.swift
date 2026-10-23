import Foundation

/// `tools/pc/kedjor.json` på telefonen (BESLUT B53): vilka fel som kan vara följdfel av vilka,
/// faserna i ordning, de fysiska testen och övningarna ur research 3. Appen bär filen ordagrant
/// som källa (`ClaudeKallor.kedjor`), så att analysens kandidater, mallarna och kontrollen av
/// svaret är desamma som på PC:n. METOD MT6
public struct Kedjor: Decodable, Sendable {
    public let faser: [String]
    public let lagPrioritet: [LagPrioritet]
    public let kedjor: [Kedja]
    public let ovningar: [Ovning]
    public let fysik: [Fysik]

    public struct LagPrioritet: Decodable, Sendable { public let fel: String }
    public struct Kedja: Decodable, Sendable {
        public let orsak: String
        public let foljd: String
    }
    public struct Ovning: Decodable, Sendable {
        public let fel: String
        public let id: String
        public let text: String
    }
    public struct Fysik: Decodable, Sendable {
        public let fel: String
        public let test: String
    }

    enum CodingKeys: String, CodingKey {
        case faser, kedjor, ovningar, fysik
        case lagPrioritet = "lag_prioritet"
    }

    /// Kedjorna som appen bär.
    public static let appens: Kedjor = {
        // Källan är genererad ur kedjor.json och prövad i testerna; den går alltid att läsa.
        try! JSONDecoder().decode(Kedjor.self, from: Data(ClaudeKallor.kedjor.utf8))
    }()

    /// Alla fel som kan ligga före `fel` i en kedja, med vägen dit ([orsak, …, fel]), i den
    /// ordning Python hittar dem (bredden först). Kedjorna läses transitivt. METOD MT6
    public func orsaker(_ fel: String) -> [(fel: String, vag: [String])] {
        var fore: [String: [String]] = [:]
        for k in kedjor { fore[k.foljd, default: []].append(k.orsak) }
        var ut: [(fel: String, vag: [String])] = []
        var sedda = Set<String>()
        var ko: [(String, [String])] = (fore[fel] ?? []).map { ($0, [$0, fel]) }
        var i = 0
        while i < ko.count {
            let (o, vag) = ko[i]
            i += 1
            if sedda.contains(o) || o == fel { continue }
            sedda.insert(o)
            ut.append((o, vag))
            ko += (fore[o] ?? []).map { ($0, [$0] + vag) }
        }
        return ut
    }

    /// Testen för ett fel, i filens ordning.
    public func test(_ fel: String) -> [String] { fysik.filter { $0.fel == fel }.map(\.test) }
}

/// En dag som ett heltal (dagar sedan 1970-01-01), utan kalender och tidszon, så att blocket och
/// dagarna sedan valet räknas som Pythons `datetime.date` (METOD MT5, MT10).
enum Dag {
    /// "20261103-180000" eller "2026-11-03" som dag, eller nil.
    static func fran(_ s: String) -> Int? {
        let siffror = s.unicodeScalars.filter { ("0"..."9").contains($0) }.prefix(8).map { Int($0.value) - 48 }
        guard siffror.count == 8 else { return nil }
        let y = siffror[0] * 1000 + siffror[1] * 100 + siffror[2] * 10 + siffror[3]
        let m = siffror[4] * 10 + siffror[5]
        let d = siffror[6] * 10 + siffror[7]
        guard (1...12).contains(m), (1...31).contains(d), d <= dagar(i: m, ar: y) else { return nil }
        return civil(y, m, d)
    }

    static func skottar(_ y: Int) -> Bool { (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 }

    static func dagar(i m: Int, ar y: Int) -> Int {
        [31, skottar(y) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1]
    }

    /// Dagar sedan 1970-01-01 (Howard Hinnants days_from_civil).
    static func civil(_ y0: Int, _ m: Int, _ d: Int) -> Int {
        let y = m <= 2 ? y0 - 1 : y0
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    /// Dagen som "2026-11-03".
    static func iso(_ z0: Int) -> String {
        let z = z0 + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        let y = yoe + era * 400 + (m <= 2 ? 1 : 0)
        func tva(_ v: Int) -> String { v < 10 ? "0\(v)" : "\(v)" }
        return "\(y)-\(tva(m))-\(tva(d))"
    }

    /// Hela veckor från `start` till `dag`, + 1 (blocket, METOD MT10), som Pythons `//`.
    static func vecka(fran start: Int, till dag: Int) -> Int {
        let d = dag - start
        return (d >= 0 ? d / 7 : (d - 6) / 7) + 1
    }
}
