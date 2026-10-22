import Foundation

/// Rutorna i filen är liggande; spårets preferredTransform säger hur de vrids, och
/// Vision får EXIF-orienteringen så att personen står upp (S2_SPEC §6.2). METOD MS7
public enum Orientation {
    /// Jämförelsen med tabellen tål så mycket. METOD MS7
    public static let tolerance = 0.01

    /// EXIF 1 (.up), 3 (.down), 6 (.right) eller 8 (.left) ur preferredTransform
    /// (a, b, c, d). En transform som inte är en av de fyra vridningarna (speglad,
    /// skev) ger 1. METOD MS7
    public static func exif(a: Double, b: Double, c: Double, d: Double) -> UInt32 {
        func lika(_ x: Double, _ y: Double) -> Bool { abs(x - y) <= tolerance }
        let tabell: [(Double, Double, Double, Double, UInt32)] = [
            (0, 1, -1, 0, 6),      // stående, kamerans vanliga läge
            (0, -1, 1, 0, 8),
            (1, 0, 0, 1, 1),
            (-1, 0, 0, -1, 3),
        ]
        for (ta, tb, tc, td, e) in tabell where lika(a, ta) && lika(b, tb) && lika(c, tc) && lika(d, td) {
            return e
        }
        return 1
    }

    /// Upprätt storlek: bredd och höjd byter plats för 6 och 8.
    public static func uprightSize(width: Int, height: Int, exif: UInt32) -> (width: Int, height: Int) {
        exif == 6 || exif == 8 ? (height, width) : (width, height)
    }

    /// Visions normaliserade punkt (origo nere till vänster) → pixlar i den upprätta
    /// bilden (origo uppe till vänster, y nedåt).
    public static func pixels(x: Double, y: Double, uprightWidth: Int, uprightHeight: Int) -> (x: Double, y: Double) {
        (x * Double(uprightWidth), (1 - y) * Double(uprightHeight))
    }
}
