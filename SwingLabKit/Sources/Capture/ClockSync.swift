import Foundation

/// En ping: NTP:s fyra tider. t0 och t3 på den styrande telefonens värdklocka,
/// t1 och t2 på följarens (S2_SPEC §7.2).
public struct PingSample: Codable, Equatable, Sendable {
    public var t0: Double
    public var t1: Double
    public var t2: Double
    public var t3: Double

    public init(t0: Double, t1: Double, t2: Double, t3: Double) {
        self.t0 = t0
        self.t1 = t1
        self.t2 = t2
        self.t3 = t3
    }

    /// θ = ((t1 − t0) + (t2 − t3)) / 2: följarens klocka − styrande.
    public var theta: Double { ((t1 - t0) + (t2 - t3)) / 2 }
    /// δ = (t3 − t0) − (t2 − t1): tiden på vägen fram och tillbaka.
    public var delta: Double { (t3 - t0) - (t2 - t1) }
}

public struct ClockOffset: Codable, Equatable, Sendable {
    /// Följarens klocka − styrande, s.
    public var offset: Double
    /// Gränsen för felet, s: största δ / 2 bland de använda proven.
    public var uncertainty: Double
    /// Giltiga prov (ändliga, δ ≥ 0).
    public var samples: Int

    public init(offset: Double, uncertainty: Double, samples: Int) {
        self.offset = offset
        self.uncertainty = uncertainty
        self.samples = samples
    }
}

/// Klockorna mellan två telefoner. Bara ett förhandsvärde: den slutliga synken är
/// klicket (ClickPairing). METOD MS9
public enum ClockSync {
    /// Andelen prov med lägst δ som används. METOD MS9
    public static let bestFraction = 0.25

    /// Medianen av θ bland den fjärdedel av proven som har lägst δ. Varje provs θ
    /// ligger inom δ/2 från den sanna förskjutningen (vägen kan vara hur osymmetrisk
    /// som helst), så största δ/2 bland de använda är en gräns för medianens fel.
    /// nil utan giltiga prov. METOD MS9
    public static func estimate(_ s: [PingSample]) -> ClockOffset? {
        let giltiga = s.filter { [$0.t0, $0.t1, $0.t2, $0.t3].allSatisfy(\.isFinite) && $0.delta >= 0 }
        guard !giltiga.isEmpty else { return nil }
        let ordnade = giltiga.enumerated().sorted { a, b in
            a.element.delta < b.element.delta || (a.element.delta == b.element.delta && a.offset < b.offset)
        }.map(\.element)
        let k = max(1, Int((Double(ordnade.count) * bestFraction).rounded(.up)))
        let basta = Array(ordnade.prefix(k))
        let theta = basta.map(\.theta).sorted()
        let median = theta.count % 2 == 1 ? theta[theta.count / 2] : (theta[theta.count / 2 - 1] + theta[theta.count / 2]) / 2
        let osakerhet = (basta.map(\.delta).max() ?? 0) / 2
        return ClockOffset(offset: median, uncertainty: osakerhet, samples: giltiga.count)
    }

    /// Driften mellan två mätningar, ppm (följarens klocka går så mycket fortare). 0 om tiderna är lika.
    public static func drift(_ a: ClockOffset, at ta: Double, _ b: ClockOffset, at tb: Double) -> Double {
        guard tb != ta else { return 0 }
        return (b.offset - a.offset) / (tb - ta) * 1e6
    }
}
