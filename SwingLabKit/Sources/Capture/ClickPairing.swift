import Foundation

/// Två telefoners klick parade (S2_SPEC §7.3): förskjutningen d där b ≈ a + d parar
/// flest klick, ur Golf SG:s `para()` (Python: tools/pc/klick.py `para`). METOD MS10
public struct ClickPairing: Codable, Equatable, Sendable {
    /// s: b ≈ a + offset.
    public var offset: Double
    public var pairs: [Pair]
    /// Flest parade i sökningen (före förfiningen).
    public var count: Int
    /// Det bästa d minst 2·tolerance från det valda, och hur många det parar
    /// (marginalen). nil och 0 när inget annat d parar något.
    public var secondBestOffset: Double?
    public var secondBestCount: Int
    /// För få par (3 utan prior, 1 med), eller ett annat d parar lika många. METOD MS10
    public var uncertain: Bool

    public struct Pair: Codable, Equatable, Sendable {
        /// Index i a och b.
        public var a: Int
        public var b: Int
        /// a + offset − b, s.
        public var residual: Double

        public init(a: Int, b: Int, residual: Double) {
            self.a = a
            self.b = b
            self.residual = residual
        }
    }

    public init(offset: Double, pairs: [Pair], count: Int, secondBestOffset: Double?, secondBestCount: Int,
                uncertain: Bool) {
        self.offset = offset
        self.pairs = pairs
        self.count = count
        self.secondBestOffset = secondBestOffset
        self.secondBestCount = secondBestCount
        self.uncertain = uncertain
    }

    /// Ingen parning: förskjutningen är prior (eller 0), osäker.
    static func none(_ prior: Double?) -> ClickPairing {
        ClickPairing(offset: prior ?? 0, pairs: [], count: 0, secondBestOffset: nil, secondBestCount: 0, uncertain: true)
    }

    /// Kvaliteten i par.json: medianen av |rest|, s. nil utan par.
    public var medianAbsResidual: Double? {
        let r = pairs.map { abs($0.residual) }.sorted()
        guard !r.isEmpty else { return nil }
        return r.count % 2 == 1 ? r[r.count / 2] : (r[r.count / 2 - 1] + r[r.count / 2]) / 2
    }

    /// Steget, toleransen och fönstren. METOD MS10
    public static let defaultStep = 0.005
    public static let defaultTolerance = 0.03
    public static let defaultPriorWindow = 0.25
    public static let defaultSearch = 10.0
    /// Så många par krävs för en säker parning. METOD MS10
    public static let minPairsWithoutPrior = 3
    public static let minPairsWithPrior = 1
    /// Ljudets fart i luft vid cirka 20 °C, m/s. METOD MS6
    public static let speedOfSound = 343.0

    /// Närmaste a (efter förskjutningen) för varje b, och resten a + d − b.
    static func rester(_ a: [Double], _ b: [Double], _ d: Double) -> [(i: Int, r: Double)] {
        b.map { x -> (i: Int, r: Double) in
            var bi = 0
            var bd = Double.infinity
            for (i, y) in a.enumerated() {
                let avst = abs(y + d - x)
                if avst < bd { bd = avst; bi = i }          // första vid lika, som np.argmin
            }
            return (i: bi, r: a[bi] + d - x)
        }
    }

    /// Sök d i steg om `step` över prior ± priorWindow (med ping) eller ± search
    /// (utan), ta det som parar flest inom tolerance (det första vid lika), och
    /// förfina med medianen av de parade resterna. Parar inget, eller är fönstret
    /// tomt (priorWindow ≤ 0), svaras prior (eller 0), inga par och osäker. METOD MS10
    public static func pair(_ a: [Double], _ b: [Double], prior: Double?, priorWindow: Double = defaultPriorWindow,
                            search: Double = defaultSearch, step: Double = defaultStep,
                            tolerance: Double = defaultTolerance) -> ClickPairing {
        guard !a.isEmpty, !b.isEmpty, step > 0 else { return none(prior) }
        let (lo, hi): (Double, Double) = prior.map { ($0 - priorWindow, $0 + priorWindow) } ?? (-search, search)
        let n = max(0, Int(((hi - lo) / step).rounded(.up)))
        var sokta: [(d: Double, n: Int)] = []
        sokta.reserveCapacity(n)
        for i in 0..<n {
            let d = lo + Double(i) * step
            sokta.append((d: d, n: rester(a, b, d).filter { abs($0.r) < tolerance }.count))
        }
        var bast = lo
        var flest = 0
        for s in sokta where s.n > flest { bast = s.d; flest = s.n }
        guard flest > 0 else { return none(prior) }
        var nast: Double?
        var nastAntal = 0
        for s in sokta where abs(s.d - bast) >= 2 * tolerance && s.n > nastAntal { nast = s.d; nastAntal = s.n }
        let parade = rester(a, b, bast).map(\.r).filter { abs($0) < tolerance }.sorted()
        let median = parade.count % 2 == 1 ? parade[parade.count / 2]
            : (parade[parade.count / 2 - 1] + parade[parade.count / 2]) / 2
        let d = bast - median
        let par = rester(a, b, d).enumerated().compactMap { j, x -> Pair? in
            abs(x.r) < tolerance ? Pair(a: x.i, b: j, residual: x.r) : nil
        }
        let minst = prior == nil ? minPairsWithoutPrior : minPairsWithPrior
        return ClickPairing(offset: d, pairs: par, count: flest, secondBestOffset: nast, secondBestCount: nastAntal,
                            uncertain: flest < minst || nastAntal >= flest)
    }

    /// Tiden ljudet tar från bollen till telefonen: träffen = klicket − soundDelay. METOD MS6
    public static func soundDelay(distance: Double, speed: Double = speedOfSound) -> Double {
        distance / speed
    }
}
