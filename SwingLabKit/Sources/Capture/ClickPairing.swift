import Foundation

/// Två telefoners klick parade (S2_SPEC §7.3): förskjutningen d där b ≈ a + d parar
/// flest klick, ur Golf SG:s `para()` (Python: tools/pc/klick.py `para`). METOD MS10
public struct ClickPairing: Codable, Equatable, Sendable {
    /// s: b ≈ a + offset.
    public var offset: Double
    public var pairs: [Pair]

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

    public init(offset: Double, pairs: [Pair]) {
        self.offset = offset
        self.pairs = pairs
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
    /// förfina med medianen av de parade resterna. Parar inget svaras prior (eller 0)
    /// och inga par. METOD MS10
    public static func pair(_ a: [Double], _ b: [Double], prior: Double?, priorWindow: Double = defaultPriorWindow,
                            search: Double = defaultSearch, step: Double = defaultStep,
                            tolerance: Double = defaultTolerance) -> ClickPairing {
        guard !a.isEmpty, !b.isEmpty, step > 0 else { return ClickPairing(offset: prior ?? 0, pairs: []) }
        let (lo, hi): (Double, Double) = prior.map { ($0 - priorWindow, $0 + priorWindow) } ?? (-search, search)
        let n = max(0, Int(((hi - lo) / step).rounded(.up)))
        var bast = lo
        var flest = -1
        for i in 0..<n {
            let d = lo + Double(i) * step
            let antal = rester(a, b, d).filter { abs($0.r) < tolerance }.count
            if antal > flest { bast = d; flest = antal }
        }
        guard flest > 0 else { return ClickPairing(offset: prior ?? 0, pairs: []) }
        let parade = rester(a, b, bast).map(\.r).filter { abs($0) < tolerance }.sorted()
        let median = parade.count % 2 == 1 ? parade[parade.count / 2]
            : (parade[parade.count / 2 - 1] + parade[parade.count / 2]) / 2
        let d = bast - median
        let par = rester(a, b, d).enumerated().compactMap { j, x -> Pair? in
            abs(x.r) < tolerance ? Pair(a: x.i, b: j, residual: x.r) : nil
        }
        return ClickPairing(offset: d, pairs: par)
    }

    /// Tiden ljudet tar från bollen till telefonen: träffen = klicket − soundDelay. METOD MS6
    public static func soundDelay(distance: Double, speed: Double = speedOfSound) -> Double {
        distance / speed
    }
}
