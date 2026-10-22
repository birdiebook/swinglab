import Foundation

/// Det låsta exponeringsläget (S2_SPEC §2.3). Båda talen ligger alltid inom
/// formatets gränser, så att `setExposureModeCustom` inte kastar ett undantag (risk R2).
public struct ExposurePlan: Codable, Equatable, Sendable {
    /// Ljuset: good (ett steg kvar), marginal (inom maxISO), tooDark. Ordnat från bäst.
    public enum Light: String, Codable, Sendable, Comparable {
        case good, marginal, tooDark

        var rang: Int {
            switch self {
            case .good: return 0
            case .marginal: return 1
            case .tooDark: return 2
            }
        }

        public static func < (a: Light, b: Light) -> Bool { a.rang < b.rang }
    }

    /// s, det som låses.
    public var duration: Double
    /// Det som låses, inom [minISO, maxISO].
    public var iso: Double
    /// Vad tiden hade krävt för autoexponeringens nivå.
    public var neededISO: Double
    /// > 0 betyder för mörkt med så många steg.
    public var deficitEV: Double
    public var light: Light

    public init(duration: Double, iso: Double, neededISO: Double, deficitEV: Double, light: Light) {
        self.duration = duration
        self.iso = iso
        self.neededISO = neededISO
        self.deficitEV = deficitEV
        self.light = light
    }
}

public enum Exposure {
    /// Slutartiden (BESLUT B11 säger 1/2000 s). METOD MS2
    public static let targetDuration = 1.0 / 2000

    static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(v, lo), max(lo, hi))
    }

    /// Exponeringsplanen ur autoexponeringens mätning. aeOffsetEV är
    /// exposureTargetOffset: negativt = för mörkt. Ett tal som inte är ett ändligt,
    /// positivt värde ersätts (tiden med den låsta, ISO med minISO, offset med 0),
    /// så att planen alltid går att låsa och skriva som JSON. METOD MS2
    public static func plan(aeDuration: Double, aeISO: Double, aeOffsetEV: Double,
                            target: Double = targetDuration, format: CameraFormat) -> ExposurePlan {
        let duration = clamp(target, format.minExposure, format.maxExposure)
        let tid = aeDuration.isFinite && aeDuration > 0 ? aeDuration : duration
        let iso0 = aeISO.isFinite && aeISO > 0 ? aeISO : format.minISO
        let offset = aeOffsetEV.isFinite ? aeOffsetEV : 0
        var needed = iso0 * (tid / duration) * pow(2, -offset)
        if !needed.isFinite { needed = .greatestFiniteMagnitude }
        let iso = clamp(needed, format.minISO, format.maxISO)
        let deficit = format.maxISO > 0 ? max(0, log2(needed / format.maxISO)) : 0
        let light: ExposurePlan.Light
        if needed <= format.maxISO / 2 {
            light = .good
        } else if needed <= format.maxISO {
            light = .marginal
        } else {
            light = .tooDark
        }
        return ExposurePlan(duration: duration, iso: iso, neededISO: needed,
                            deficitEV: deficit.isFinite ? deficit : 0, light: light)
    }
}
