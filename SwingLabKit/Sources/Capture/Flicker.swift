import Foundation

/// Ljusprovet före passet (S2_SPEC §2.7). METOD MS3
public struct LightCheck: Codable, Equatable, Sendable {
    public var exposure: ExposurePlan
    public var timing: FrameTiming
    /// Relativt djup vid 100 Hz (50 Hz-nät).
    public var flicker100: Double
    /// Vid 120 Hz (60 Hz-nät). Ligger på halva bildfrekvensen vid 240 och kan underskattas.
    public var flicker120: Double
    /// Medelljusheten, 0–1.
    public var meanLuma: Double
    /// Den sämsta av ISO, flimmer, tappade rutor och ljushet.
    public var verdict: ExposurePlan.Light

    public init(exposure: ExposurePlan, timing: FrameTiming, flicker100: Double, flicker120: Double,
                meanLuma: Double, verdict: ExposurePlan.Light) {
        self.exposure = exposure
        self.timing = timing
        self.flicker100 = flicker100
        self.flicker120 = flicker120
        self.meanLuma = meanLuma
        self.verdict = verdict
    }

    /// Raden för flimret (den större av 100 och 120 Hz).
    public var flickerLight: ExposurePlan.Light { Flicker.grade(flicker: max(flicker100, flicker120)) }
    /// Raden för rutorna.
    public var framesLight: ExposurePlan.Light { Flicker.grade(missing: timing.missingFraction) }
    /// Raden för ljusheten.
    public var lumaLight: ExposurePlan.Light { Flicker.grade(luma: meanLuma) }
}

public enum Flicker {
    /// Flimmer: under 3 % grönt, 3–10 % gult, över 10 % rött. METOD MS3
    public static let flickerGood = 0.03
    public static let flickerMarginal = 0.10
    /// Tappade rutor: under 1 % grönt, 1–5 % gult, över 5 % rött. METOD MS3
    public static let missingGood = 0.01
    public static let missingMarginal = 0.05
    /// Tappade rutor i ett importerat slowmotion-original (Kamera-appen): upp till 45 %
    /// vitt, 45–55 % gult, över 55 % rött. Oktobers klipp och Johannes första import
    /// tappade 36 %. METOD MS11
    public static let importMissingGood = 0.45
    public static let importMissingMarginal = 0.55
    /// Ljusheten 0,20–0,60 grönt, utanför gult. METOD MS3
    public static let lumaGood = 0.20...0.60

    public static func grade(flicker: Double) -> ExposurePlan.Light {
        guard flicker.isFinite else { return .tooDark }
        return flicker < flickerGood ? .good : flicker <= flickerMarginal ? .marginal : .tooDark
    }

    public static func grade(missing: Double) -> ExposurePlan.Light {
        guard missing.isFinite else { return .tooDark }
        return missing < missingGood ? .good : missing <= missingMarginal ? .marginal : .tooDark
    }

    /// Tappade rutor i en import (Kamera-appens original). METOD MS11
    public static func grade(importMissing missing: Double) -> ExposurePlan.Light {
        guard missing.isFinite else { return .tooDark }
        return missing <= importMissingGood ? .good : missing <= importMissingMarginal ? .marginal : .tooDark
    }

    public static func grade(luma: Double) -> ExposurePlan.Light {
        lumaGood.contains(luma) ? .good : .marginal
    }

    /// Minsta kvadrat-anpassning av c + a·cos(2πft) + b·sin(2πft) på rutornas egna
    /// tider (tål tappade rutor). Svarar sqrt(a² + b²) / c, eller 0 när det inte går
    /// att anpassa (färre än tre rutor, c ≤ 0). En kolumn som är noll på rutorna
    /// (sinus på exakt halva bildfrekvensen) lämnas ute. METOD MS3
    public static func depth(luma: [Double], times: [Double], hz: Double) -> Double {
        let n = min(luma.count, times.count)
        guard n >= 3, hz.isFinite else { return 0 }
        let t0 = times[0]
        var ata = [[Double]](repeating: [Double](repeating: 0, count: 3), count: 3)
        var aty = [Double](repeating: 0, count: 3)
        for i in 0..<n where luma[i].isFinite && times[i].isFinite {
            let w = 2 * Double.pi * hz * (times[i] - t0)
            let rad = [1, cos(w), sin(w)]
            for r in 0..<3 {
                aty[r] += rad[r] * luma[i]
                for c in 0..<3 { ata[r][c] += rad[r] * rad[c] }
            }
        }
        guard let x = losMinsta(ata, aty), x[0] > 0 else { return 0 }
        return (x[1] * x[1] + x[2] * x[2]).squareRoot() / x[0]
    }

    /// Normalekvationerna med Gauss-elimination och pivotering. En pivot under
    /// 1e-9 av diagonalens största ger koefficienten 0 (kolumnen bär ingen information).
    static func losMinsta(_ a: [[Double]], _ y: [Double]) -> [Double]? {
        let n = y.count
        let skala = (0..<n).map { abs(a[$0][$0]) }.max() ?? 0
        guard skala > 0 else { return nil }
        var aktiv = [Bool](repeating: true, count: n)
        for k in 0..<n where abs(a[k][k]) < 1e-9 * skala {
            aktiv[k] = false              // kolumnen är (nästan) noll: ta bort rad och kolumn
        }
        let idx = (0..<n).filter { aktiv[$0] }
        var m = idx.map { r in idx.map { a[r][$0] } }
        var v = idx.map { y[$0] }
        let k = idx.count
        for col in 0..<k {
            guard let piv = (col..<k).max(by: { abs(m[$0][col]) < abs(m[$1][col]) }), abs(m[piv][col]) > 1e-12 * skala
            else { return nil }
            m.swapAt(col, piv)
            v.swapAt(col, piv)
            for r in (col + 1)..<k {
                let f = m[r][col] / m[col][col]
                for c in col..<k { m[r][c] -= f * m[col][c] }
                v[r] -= f * v[col]
            }
        }
        var x = [Double](repeating: 0, count: k)
        for r in stride(from: k - 1, through: 0, by: -1) {
            var s = v[r]
            for c in (r + 1)..<k { s -= m[r][c] * x[c] }
            x[r] = s / m[r][r]
        }
        var ut = [Double](repeating: 0, count: n)
        for (j, i) in idx.enumerated() { ut[i] = x[j] }
        return ut
    }

    /// Ljusprovets resultat. Domen är den sämsta raden. METOD MS3
    public static func check(exposure: ExposurePlan, timing: FrameTiming,
                             luma: [Double], times: [Double]) -> LightCheck {
        let f100 = depth(luma: luma, times: times, hz: 100)
        let f120 = depth(luma: luma, times: times, hz: 120)
        let giltiga = luma.filter { $0.isFinite }
        let medel = giltiga.isEmpty ? 0 : giltiga.reduce(0, +) / Double(giltiga.count)
        var c = LightCheck(exposure: exposure, timing: timing, flicker100: f100, flicker120: f120,
                           meanLuma: medel, verdict: exposure.light)
        c.verdict = [exposure.light, c.flickerLight, c.framesLight, c.lumaLight].max() ?? exposure.light
        return c
    }
}
