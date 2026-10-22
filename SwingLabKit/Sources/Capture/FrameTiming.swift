import Foundation

/// Rutornas tider ur filen (S2_SPEC §3.2): rutnätet, tappade rutor och om filen är
/// slowmotion-originalet. METOD MS3
public struct FrameTiming: Codable, Equatable, Sendable {
    public var count: Int
    /// Rutnätets frekvens: 1 / medel av de korta stegen (högst 1,75 × 5:e percentilen),
    /// avrundat till heltal. 0 = okänt.
    public var gridRate: Double
    /// (count − 1) / (sista − första).
    public var meanRate: Double
    /// 1 − count / ((sista − första)·gridRate + 1), ≥ 0.
    public var missingFraction: Double
    /// Största steget, s.
    public var largestGap: Double
    /// gridRate ≥ 100. Annars är en import omräknad (S2_SPEC §5).
    public var isSlowMotion: Bool

    public init(count: Int, gridRate: Double, meanRate: Double, missingFraction: Double,
                largestGap: Double, isSlowMotion: Bool) {
        self.count = count
        self.gridRate = gridRate
        self.meanRate = meanRate
        self.missingFraction = missingFraction
        self.largestGap = largestGap
        self.isSlowMotion = isSlowMotion
    }

    /// Percentilen som ger rutnätet. De kortaste stegen, inte medianen: oktobers klipp
    /// låg på 240-rutnätet med drygt en tredjedel av rutorna borta. METOD MS3
    public static let gridPercentile = 0.05
    /// De korta stegen är de upp till så många gånger percentilen. Deras medel tål en
    /// grov tidsskala: 1/240 s i filmens standard 600 blir steg om 2 och 3 enheter,
    /// och percentilen ensam gav 300 (simulatorprovet S2c). 1,75 ligger mellan 3/2
    /// (avrundningen) och 2 (en tappad ruta), så att 3/2 inte faller på flyttalets kant. METOD MS3
    public static let shortStepFactor = 1.75
    /// Gränsen för slowmotion, bilder/s. METOD MS3
    public static let slowMotionRate = 100.0

    /// Percentil med linjär interpolation (numpys standard) i en sorterad lista.
    static func percentile(_ sorted: [Double], _ q: Double) -> Double {
        let pos = q * Double(sorted.count - 1)
        let lo = Int(pos.rounded(.down))
        let hi = min(lo + 1, sorted.count - 1)
        return sorted[lo] + (pos - Double(lo)) * (sorted[hi] - sorted[lo])
    }

    public static func analyze(_ times: [Double]) -> FrameTiming {
        let t = times.filter { $0.isFinite }.sorted()
        guard t.count >= 2, let forsta = t.first, let sista = t.last, sista > forsta else {
            return FrameTiming(count: t.count, gridRate: 0, meanRate: 0, missingFraction: 0, largestGap: 0,
                               isSlowMotion: false)
        }
        var steg: [Double] = []
        steg.reserveCapacity(t.count - 1)
        for i in 1..<t.count { steg.append(t[i] - t[i - 1]) }
        let largest = steg.max() ?? 0
        let positiva = steg.filter { $0 > 0 }.sorted()   // två rutor med samma tid ger inget steg
        let p = positiva.isEmpty ? 0 : percentile(positiva, gridPercentile)
        let korta = positiva.filter { $0 <= shortStepFactor * p }
        let medel = korta.isEmpty ? 0 : korta.reduce(0, +) / Double(korta.count)
        let grid = medel > 0 ? (1 / medel).rounded() : 0
        let langd = sista - forsta
        let mojliga = langd * grid + 1
        let saknas = grid > 0 ? max(0, 1 - Double(t.count) / mojliga) : 0
        return FrameTiming(count: t.count, gridRate: grid, meanRate: Double(t.count - 1) / langd,
                           missingFraction: saknas, largestGap: largest, isSlowMotion: grid >= slowMotionRate)
    }
}
