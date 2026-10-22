import Foundation

/// Rutornas tider ur filen (S2_SPEC §3.2): rutnätet, tappade rutor och om filen är
/// slowmotion-originalet. METOD MS3
public struct FrameTiming: Codable, Equatable, Sendable {
    public var count: Int
    /// Rutnätets frekvens, heltal. Den kända frekvensen (`nominalRates`) när rutorna
    /// passar den inom ±1 %, annars den uppmätta avrundad. 0 = okänt. METOD MS3
    public var gridRate: Double
    /// (count − 1) / (sista − första).
    public var meanRate: Double
    /// 1 − count / ((sista − första)·measuredRate + 1), ≥ 0.
    public var missingFraction: Double
    /// Största steget, s.
    public var largestGap: Double
    /// gridRate ≥ 100. Annars är en import omräknad (S2_SPEC §5).
    public var isSlowMotion: Bool
    /// Klockan som rutorna faktiskt följer, bilder/s, utan avrundning (en iPhone kan gå
    /// några promille fel). nil i ett pass.json från före S2e. METOD MS3
    public var measuredRate: Double?

    public init(count: Int, gridRate: Double, meanRate: Double, missingFraction: Double,
                largestGap: Double, isSlowMotion: Bool, measuredRate: Double? = nil) {
        self.count = count
        self.gridRate = gridRate
        self.meanRate = meanRate
        self.missingFraction = missingFraction
        self.largestGap = largestGap
        self.isSlowMotion = isSlowMotion
        self.measuredRate = measuredRate
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

    /// Varven i förfiningen; den stannar när det avrundade rutnätet står still. METOD MS3
    public static let refineRounds = 5

    /// Förfinar skattningen g0 med hela spannet: varje steg räknas som ett helt antal
    /// rutor, max(1, round(steg · g)), och rutnätet är summan / (sista − första), tills
    /// det avrundade talet står still. De korta stegen ensamma vandrar vid skurar av
    /// tappade rutor i en grov tidsskala (240 → 229–249); spannet gör felet till en
    /// enhet i tidsskalan över hela filen. Svarar utan avrundning. METOD MS3
    static func refine(_ g0: Double, steps: [Double], span: Double) -> Double {
        guard g0 > 0, g0.isFinite, span > 0 else { return 0 }
        var g = g0
        for _ in 0..<refineRounds {
            let rutor = steps.reduce(0.0) { $0 + max(1, ($1 * g).rounded()) }
            let ny = rutor / span
            let stilla = ny.rounded() == g.rounded()
            g = ny
            if stilla { break }
        }
        return g
    }

    // MARK: Den kända frekvensen

    /// Kamerornas frekvenser. En iPhone-slowmotion i "240" kan gå på en klocka några
    /// promille fel (239,4 avrundas till 239, Johannes första import 2026-10-22); rutorna
    /// passar ändå 240-rutnätet. METOD MS3
    public static let nominalRates: [Double] = [24, 25, 30, 48, 50, 60, 100, 120, 240]
    /// Den uppmätta klockan får avvika så mycket från den kända. METOD MS3
    public static let snapTolerance = 0.01
    /// Bara de kända frekvenserna inom ±10 % från de korta stegens skattning prövas, så
    /// att ett rutnät som är en multipel (120 för en film i 40) inte tas. METOD MS3
    public static let snapGate = 0.10
    /// Sökningen börjar på filens första sekund. METOD MS3
    public static let snapPrefix = 1.0
    /// Sökningens steg, i varv över början (0,1 varv). METOD MS3
    public static let snapSearchStep = 0.1
    /// Rutorna passar rutnätet när fasernas medelvektor är minst så lång (1 = exakt på
    /// rutnätet, 0 = utspridda). Skakning med sd σ ger exp(−2π²σ²g²): 0,5 vid σ ≈ 0,78 ms
    /// i 240. METOD MS3
    public static let snapMinCoherence = 0.5

    /// Fasernas medelvektor för rutnätet g med början a: längden (0–1) och fasen i varv.
    static func coherence(_ t: [Double], rate g: Double, offset a: Double = 0) -> (length: Double, phase: Double) {
        guard !t.isEmpty else { return (0, 0) }
        var c = 0.0, s = 0.0
        for x in t {
            let v = 2 * Double.pi * (x - a) * g
            c += cos(v)
            s += sin(v)
        }
        let n = Double(t.count)
        return ((c * c + s * s).squareRoot() / n, atan2(s, c) / (2 * Double.pi))
    }

    /// Rutnätet nära den kända frekvensen r i tiderna `rel` (sorterade, från 0, utan
    /// dubletter): först den bästa frekvensen inom ±1 % på filens första sekund (fasernas
    /// medelvektor), sedan minsta kvadrat med rutornas nummer på ett fönster som dubblas
    /// till hela filen, så att en klocka som går fel följs utan att numren glider. Svarar
    /// klockan och hur väl rutorna passar den (medelvektorns längd). METOD MS3
    static func fitGrid(_ rel: [Double], near r: Double) -> (rate: Double, coherence: Double)? {
        guard rel.count >= 2, let span = rel.last, span > 0, r > 0 else { return nil }
        var w = min(span, snapPrefix)
        let borjan = rel.filter { $0 <= w + 1e-12 }
        let lo = r * (1 - snapTolerance), hi = r * (1 + snapTolerance)
        let n = max(3, Int(((hi - lo) / (snapSearchStep / max(w, 1e-3))).rounded(.up)) + 1)
        var bast = (length: -1.0, rate: r, phase: 0.0)
        for k in 0..<n {
            let g = lo + (hi - lo) * Double(k) / Double(n - 1)
            let c = coherence(borjan, rate: g)
            if c.length > bast.length { bast = (c.length, g, c.phase) }
        }
        var g = bast.rate
        var a = bast.phase / g
        while true {
            var sn = 0.0, st = 0.0, snn = 0.0, snt = 0.0, m = 0.0
            for x in rel where x <= w + 1e-12 {
                let k = ((x - a) * g).rounded()
                sn += k
                st += x
                snn += k * k
                snt += k * x
                m += 1
            }
            let den = m * snn - sn * sn
            if den > 0 {
                let steg = (m * snt - sn * st) / den
                guard steg > 0 else { return nil }
                a = (st - steg * sn) / m
                g = 1 / steg
            } else if w >= span {
                return nil
            }
            if w >= span { break }
            w = min(span, 2 * w)
        }
        return (g, coherence(rel, rate: g, offset: a).length)
    }

    /// Den kända frekvensen som rutorna passar, och den uppmätta klockan; nil när ingen
    /// passar inom ±1 % (då gäller de korta stegens rutnät). Den lägsta som passar vinner. METOD MS3
    static func nominal(_ rel: [Double], estimate: Double) -> (grid: Double, measured: Double)? {
        for r in nominalRates where abs(estimate - r) <= snapGate * r {
            if let f = fitGrid(rel, near: r), abs(f.rate - r) <= snapTolerance * r, f.coherence >= snapMinCoherence {
                return (r, f.rate)
            }
        }
        return nil
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
        let langd = sista - forsta
        let skattning = refine(medel > 0 ? 1 / medel : 0, steps: positiva, span: langd)
        var grid = skattning.rounded()
        var klocka = skattning
        var rel: [Double] = []
        rel.reserveCapacity(t.count)
        for x in t where rel.last.map({ x - forsta > $0 }) ?? true { rel.append(x - forsta) }
        if skattning > 0, let k = nominal(rel, estimate: skattning) {
            grid = k.grid
            klocka = k.measured
        }
        let mojliga = langd * klocka + 1
        let saknas = klocka > 0 ? max(0, 1 - Double(t.count) / mojliga) : 0
        return FrameTiming(count: t.count, gridRate: grid, meanRate: Double(t.count - 1) / langd,
                           missingFraction: saknas, largestGap: largest, isSlowMotion: grid >= slowMotionRate,
                           measuredRate: klocka > 0 ? klocka : nil)
    }
}
