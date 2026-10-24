import Foundation

/// Det som hör till en sessions vy (PLAN S4e, BESLUT B64): katalogens `vy` per fel och mått,
/// "dtl", "fo" eller "bada". En FO-session visar bara det med "fo" och "bada", en DTL-session
/// bara "dtl" och "bada" (tempot ur klicket). Gäller passets kort och granskningens rader per
/// position. METOD MS20
public enum Vyfilter {
    /// Katalogens vy för det som mäts i båda vyerna (tempot).
    public static let bada = "bada"

    /// `katalogVy` (katalogens `vy`) hör till en session med vyn `vy`.
    public static func visas(_ katalogVy: String, i vy: Vy) -> Bool {
        katalogVy == vy.rawValue || katalogVy == bada
    }

    /// Ett kort hör till en session med vyn `vy`. Kortets vy är katalogens (`Vy(rawValue:)`),
    /// och nil är "bada".
    public static func visas(_ kort: Mattkort, i vy: Vy) -> Bool {
        visas(kort.vy?.rawValue ?? bada, i: vy)
    }
}

extension Passvisning {
    /// Korten i sessionens vy, genom katalogens vy (`Vyfilter`): en FO-session har inga
    /// DTL-kort och tvärtom; tempot står i båda. BESLUT B64
    public func kort(i vy: Vy) -> [Mattkort] {
        kort.filter { Vyfilter.visas($0, i: vy) }
    }
}
