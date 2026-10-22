import Foundation
import Swing

/// Vägen tillbaka (S2_SPEC §8.5, BESLUT B28): `att_jobba_pa.json` från PC:n hämtas med
/// Filer och sparas som `AttJobbaPa/att_jobba_pa-<pass>.json` i appens mapp, där
/// Idag och Att jobba på läser den senaste (vyerna kopplas in i S4c). Här bor det som
/// avgör om filen tas emot och vad den heter; App/Store.swift läser och skriver.
/// Felen är SwingLabKits engelska texter (BESLUT B33) och nämner fältet, aldrig värdet.
/// Telefonen kontrollerar formen; textens regler (engelska, inga värdeord, BESLUT B30)
/// kontrolleras av PC:ns `tools/pc/att_jobba_pa.py` innan filen skickas.
public enum FocusInbox {
    /// Mappen i appens Application Support/SwingLab.
    public static let folder = "AttJobbaPa"
    /// Större än så är ingen `att_jobba_pa.json` (1–3 saker), byte.
    public static let maxBytes = 1_000_000

    /// "att_jobba_pa-20261103-180000.json" för passet, eller nil när id:t inte är
    /// `yyyyMMdd-HHmmss` (ett id ur en fil blir aldrig en sökväg ut ur mappen).
    public static func fileName(pass: String) -> String? {
        let c = Array(pass)
        guard c.count == 15, c[8] == "-",
              c.enumerated().allSatisfy({ $0.offset == 8 || ($0.element.isASCII && $0.element.isNumber) }) else {
            return nil
        }
        return "att_jobba_pa-\(pass).json"
    }

    /// Kontrollerar filen (`AttJobbaPa.las`: formatet, 1–3 saker, stegen) och passets id,
    /// och svarar den tolkade filen och namnet den sparas under. Kastar `FormatFel`.
    /// Felet för en fil över `maxBytes`; appen kontrollerar storleken innan filen läses.
    public static var tooLarge: FormatFel { FormatFel(Texter.filFel(Texter.ogiltigt(Texter.filen))) }

    public static func accept(_ data: Data) throws -> (focus: AttJobbaPa, fileName: String) {
        guard data.count <= maxBytes else { throw tooLarge }
        let a = try AttJobbaPa.las(data)
        guard let namn = fileName(pass: a.pass) else { throw FormatFel(Texter.filFel(Texter.ogiltigt("pass"))) }
        return (a, namn)
    }

    /// Den senaste filen bland namnen i mappen: passets id är tiden, så det högsta vinner.
    public static func latest(_ names: [String]) -> String? {
        all(names).last
    }

    /// Filerna bland namnen i mappen, äldst först (Utvecklings block, S4c); annat hoppas över.
    /// METOD MS16
    public static func all(_ names: [String]) -> [String] {
        names.filter { n in
            n.hasPrefix("att_jobba_pa-") && n.hasSuffix(".json")
                && fileName(pass: String(n.dropFirst(13).dropLast(5))) == n
        }.sorted()
    }

    /// Alla filer i mappen som går igenom kontrollen, äldst först; läses utan Store, så att det
    /// går utanför huvudtråden. METOD MS16
    public static func readAll(in folder: URL) -> [AttJobbaPa] {
        let namn = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return all(namn).compactMap { n in
            guard let data = try? Data(contentsOf: folder.appendingPathComponent(n)) else { return nil }
            return try? accept(data).focus
        }
    }
}
