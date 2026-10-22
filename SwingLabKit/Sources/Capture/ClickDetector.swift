import Foundation

/// Ett klick i ljudet: ansatsens tid och styrkan mot bitens median.
public struct Click: Codable, Equatable, Sendable {
    /// s från bitens början (detect) eller signalens (merge, detectSegmented).
    public var time: Double
    /// Toppens energi / bitens median (e[p] / bas).
    public var strength: Double

    public init(time: Double, strength: Double) {
        self.time = time
        self.strength = strength
    }
}

/// Klickjakten: Golf SG:s `handled_video.klick()` rad för rad (S2_SPEC §4.1), så att
/// Swift och Python (tools/pc/klick.py) hittar samma ansats på samma prov. METOD MS4
public enum ClickDetector {
    /// Konstanterna, METOD MS4.
    public struct Params: Codable, Equatable, Sendable {
        /// Energins fönster, s.
        public var window: Double
        /// Toppen ska vara så många gånger bitens median.
        public var factor: Double
        /// Två toppar närmare än så (s) är samma klick.
        public var minGap: Double
        /// Ansatsen söks så långt före toppen, s.
        public var onsetLookback: Double
        /// Ansatsen: första provet över den andelen av toppen.
        public var onsetFraction: Double

        public init(window: Double = 0.002, factor: Double = 25, minGap: Double = 0.5,
                    onsetLookback: Double = 0.02, onsetFraction: Double = 0.5) {
            self.window = window
            self.factor = factor
            self.minGap = minGap
            self.onsetLookback = onsetLookback
            self.onsetFraction = onsetFraction
        }
    }

    /// Bitarna (S2_SPEC §4.2): 30 s med 1 s överlapp. METOD MS4
    public static let segmentSeconds = 30.0
    public static let overlapSeconds = 1.0

    /// Energin per prov: RMS av första differensen i ett centrerat fönster om w prov
    /// (`np.convolve(hp², ones(w)/w, mode="same")`, sedan roten). Prov utanför
    /// signalen räknas som 0 men divisionen är ändå med w.
    static func energy(_ x: [Float], w: Int) -> [Double] {
        let n = x.count
        // hp och hp² i Float, som numpy med en Float32-signal; summan i Double.
        var hp2 = [Double](repeating: 0, count: n)
        for i in 1..<n {
            let d: Float = x[i] - x[i - 1]
            let d2: Float = d * d
            hp2[i] = Double(d2)
        }
        let h = (w - 1) / 2
        let fore = w - 1 - h                  // fönstret är n − fore … n + h
        var e = [Double](repeating: 0, count: n)
        func direkt(_ c: Int) -> Double {
            var s = 0.0
            for m in max(0, c - fore)...min(n - 1, c + h) { s += hp2[m] }
            return s
        }
        var s = 0.0
        for c in 0..<n {
            if c % 4096 == 0 {
                s = direkt(c)                 // löpande summan förankras om, så att avrundningen inte vandrar
            } else {
                let in_ = c + h
                let ut = c - fore - 1
                if in_ < n { s += hp2[in_] }
                if ut >= 0 { s -= hp2[ut] }
            }
            e[c] = (max(0, s) / Double(w)).squareRoot()
        }
        return e
    }

    static func median(_ v: [Double]) -> Double {
        let s = v.sorted()
        let n = s.count
        if n == 0 { return .nan }
        return n % 2 == 1 ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2
    }

    /// Klicken i en bit, med tiden från bitens början. METOD MS4
    public static func detect(_ x: [Float], sampleRate: Double = 48_000, params: Params = .init()) -> [Click] {
        let sr = sampleRate
        let w = max(1, Int(sr * params.window))
        guard x.count >= 10, x.count >= w else { return [] }   // samma vakt som tools/pc/klick.py
        let e = energy(x, w: w)
        let bas = median(e) + 1e-9
        let grans = params.factor * bas
        let gap = sr * params.minGap
        var toppar: [Int] = []
        for i in 0..<e.count where e[i] > grans {
            if let p = toppar.last, Double(i - p) < gap {
                if e[i] > e[p] { toppar[toppar.count - 1] = i }
                continue
            }
            toppar.append(i)
        }
        let bak = Int(sr * params.onsetLookback)
        return toppar.map { p in
            let a = max(0, p - bak)
            var o = a
            let halva = params.onsetFraction * e[p]
            while o < p, !(e[o] > halva) { o += 1 }
            return Click(time: Double(o) / sr, strength: e[p] / bas)
        }
    }

    /// Slår ihop bitarnas klick: tiderna flyttas med bitens start, och två klick
    /// närmare än minGap blir det starkaste (jämfört mot det senast behållna).
    public static func merge(_ segments: [(start: Double, clicks: [Click])], minGap: Double = 0.5) -> [Click] {
        var alla: [Click] = []
        for seg in segments {
            for c in seg.clicks { alla.append(Click(time: seg.start + c.time, strength: c.strength)) }
        }
        // Stabil sortering på tiden (som Pythons sorted).
        let ordnade = alla.enumerated().sorted { a, b in
            a.element.time < b.element.time || (a.element.time == b.element.time && a.offset < b.offset)
        }.map(\.element)
        var ut: [Click] = []
        for c in ordnade {
            if let sista = ut.last, c.time - sista.time < minGap {
                if c.strength > sista.strength { ut[ut.count - 1] = c }
                continue
            }
            ut.append(c)
        }
        return ut
    }

    /// Bitarnas prov [början, slut): `segment` s långa med `overlap` s överlapp; den
    /// sista slutar vid signalens slut. Samma som `tools/pc/klick.py` `bitar()`.
    public static func segments(count: Int, sampleRate: Double = 48_000,
                                segment: Double = segmentSeconds, overlap: Double = overlapSeconds) -> [Range<Int>] {
        let langd = Int(segment * sampleRate)
        let steg = Int((segment - overlap) * sampleRate)
        guard langd > 0, steg > 0 else { return [0..<count] }
        var ut: [Range<Int>] = []
        var a = 0
        while true {
            let b = min(a + langd, count)
            ut.append(a..<b)
            if b >= count { return ut }
            a += steg
        }
    }

    /// detect per bit och merge, som telefonen läser en lång serie (§4.2). För en
    /// signal som redan ligger i minnet; appen läser bitarna ur filen själv.
    public static func detectSegmented(_ x: [Float], sampleRate: Double = 48_000, params: Params = .init(),
                                       segment: Double = segmentSeconds, overlap: Double = overlapSeconds) -> [Click] {
        let delar = segments(count: x.count, sampleRate: sampleRate, segment: segment, overlap: overlap).map { r in
            (start: Double(r.lowerBound) / sampleRate,
             clicks: detect(Array(x[r]), sampleRate: sampleRate, params: params))
        }
        return merge(delar, minGap: params.minGap)
    }
}
