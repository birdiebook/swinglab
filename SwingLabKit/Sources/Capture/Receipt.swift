import Foundation

// Kvittot efter varje serie och ljusprovets kort (S2_SPEC §2.6–2.7, §12 S2c): rader
// med etikett, tal och en färg per rad (BESLUT B13: inga värdeord, ingen
// beskrivande text). Raderna byggs här så att vyn bara ritar dem. METOD MS11

/// En rad: etiketten, talet med enhet, och färgen (good = vit, annars signalfärgen).
public struct ReceiptRow: Equatable, Sendable {
    public var label: String
    public var value: String
    public var light: ExposurePlan.Light

    public init(_ label: String, _ value: String, _ light: ExposurePlan.Light = .good) {
        self.label = label
        self.value = value
        self.light = light
    }
}

public enum Receipt {
    /// Rutnätets frekvens mot den önskade: nådd (vit), lägre slowmotion (gul),
    /// inte slowmotion (röd). METOD MS1, MS3
    public static func rateLight(_ t: FrameTiming, wantedRate: Double = 240) -> ExposurePlan.Light {
        if !t.isSlowMotion { return .tooDark }
        return t.gridRate >= wantedRate - FormatChoice.rateSlack ? .good : .marginal
    }

    /// Kvittot efter en serie: frekvensen, tappade rutor, antal rutor, klicken,
    /// filens storlek per minut, längden och trycket. METOD MS11
    public static func rows(_ s: SeriesRecord, wantedRate: Double = 240) -> [ReceiptRow] {
        var r = [
            ReceiptRow("Bilder/s", Swedish.integer(s.timing.gridRate), rateLight(s.timing, wantedRate: wantedRate)),
            ReceiptRow("Tappade", Swedish.percent(s.timing.missingFraction), Flicker.grade(missing: s.timing.missingFraction)),
            ReceiptRow("Rutor", Swedish.integer(Double(s.timing.count))),
            ReceiptRow("Klick", Swedish.integer(Double(s.clicks.count)), s.clicks.isEmpty ? .marginal : .good),
            ReceiptRow("MB/min", Swedish.integer(s.megabytesPerMinute)),
            ReceiptRow("Längd", Swedish.duration(s.duration)),
        ]
        if let p = s.pressure { r.append(ReceiptRow("Tryck", pressureName(p), p.light)) }
        return r
    }

    /// Ljusprovets kort: ljuset (ISO eller bristen i steg), flimret, rutorna och
    /// ljusheten. Domen är den sämsta raden (METOD MS3).
    public static func rows(_ c: LightCheck, wantedRate: Double = 240) -> [ReceiptRow] {
        let e = c.exposure
        let ljus = e.deficitEV > 0
            ? ReceiptRow("Ljus", "För mörkt: \(Swedish.decimal(e.deficitEV, digits: 1)) steg", .tooDark)
            : ReceiptRow("ISO", Swedish.integer(e.neededISO), e.light)
        let flimmer = max(c.flicker100, c.flicker120)
        let rutor = "\(Swedish.integer(c.timing.gridRate)) bilder/s, \(Swedish.percent(c.timing.missingFraction)) tappade"
        return [
            ljus,
            ReceiptRow("Flimmer", Swedish.percent(flimmer), c.flickerLight),
            ReceiptRow("Rutor", rutor, max(c.framesLight, rateLight(c.timing, wantedRate: wantedRate))),
            ReceiptRow("Ljushet", Swedish.percent(c.meanLuma), c.lumaLight),
        ]
    }

    /// Trycket på svenska.
    public static func pressureName(_ p: Pressure) -> String {
        switch p {
        case .nominal: return "normalt"
        case .fair: return "måttligt"
        case .serious: return "högt"
        case .critical: return "kritiskt"
        case .shutdown: return "avstängt"
        }
    }
}

/// Tal på svenska, oberoende av telefonens språk: decimalkomma och mellanslag
/// mellan tusental.
public enum Swedish {
    public static func integer(_ x: Double) -> String {
        guard x.isFinite else { return "–" }
        let n = Int(x.rounded())
        let s = String(abs(n))
        var ut = ""
        for (i, ch) in s.enumerated() {
            if i > 0, (s.count - i) % 3 == 0, s.count > 4 { ut.append("\u{00A0}") }
            ut.append(ch)
        }
        return (n < 0 ? "−" : "") + ut
    }

    public static func decimal(_ x: Double, digits: Int) -> String {
        guard x.isFinite else { return "–" }
        let s = String(format: "%.\(max(0, digits))f", abs(x)).replacingOccurrences(of: ".", with: ",")
        let noll = s.allSatisfy { $0 == "0" || $0 == "," }
        return (x < 0 && !noll ? "−" : "") + s
    }

    /// Andel som procent: under 0,05 % → "0 %", under 10 % med en decimal, annars heltal.
    public static func percent(_ f: Double) -> String {
        guard f.isFinite else { return "–" }
        let p = f * 100
        if abs(p) < 0.05 { return "0 %" }
        return (abs(p) < 10 ? decimal(p, digits: 1) : integer(p)) + " %"
    }

    /// Sekunder som m:ss.
    public static func duration(_ s: Double) -> String {
        guard s.isFinite, s >= 0 else { return "–" }
        let t = Int(s.rounded())
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}

/// Importen ur Bilder (S2_SPEC §5): originalresursen och vägran av en omräknad fil. BESLUT B24
public enum ImportCheck {
    /// Resursens typ, `PHAssetResourceType` som värde.
    public enum ResourceKind: Equatable, Sendable {
        /// `.video`: "the original video data".
        case video
        /// `.fullSizeVideo`: "a modified version" (den omräknade slowmotion).
        case fullSizeVideo
        case other
    }

    /// Platsen för originalet bland resurserna. Aldrig `.fullSizeVideo`. BESLUT B24
    public static func original(_ kinds: [ResourceKind]) -> Int? {
        kinds.firstIndex(of: .video)
    }

    public enum Verdict: Equatable, Sendable {
        case accept
        /// Rutnätet under 100 bilder/s: omräknad (eller vanlig) film. METOD MS3
        case notSlowMotion
        /// För få rutor för att säga något.
        case tooFewFrames
    }

    /// Minsta antal rutor för att rutnätet ska gå att läsa.
    public static let minimumFrames = 10

    public static func verdict(_ t: FrameTiming) -> Verdict {
        if t.count < minimumFrames { return .tooFewFrames }
        return t.isSlowMotion ? .accept : .notSlowMotion
    }

    /// Texten i vyn när en fil vägras (S2_SPEC §5).
    public static let refusal = "Inte slowmotion-originalet"
}

/// Fyra tecken (FourCharCode) som text: 'aac ' → "aac", 'x420' → "x420".
public enum FourCC {
    public static func string(_ code: UInt32) -> String {
        let b = [24, 16, 8, 0].map { UInt8((code >> UInt32($0)) & 0xFF) }
        let s = String(decoding: b.map { (32...126).contains($0) ? $0 : 63 }, as: UTF8.self)
        return s.trimmingCharacters(in: .whitespaces)
    }

    public static func code(_ s: String) -> UInt32 {
        var c: UInt32 = 0
        for b in s.utf8.prefix(4) { c = (c << 8) | UInt32(b) }
        return c
    }

    /// 10-bitars pixelformat ('x420', 'x422', 'xf20', 'xf22'). METOD MS1
    public static func isTenBit(_ pixelFormat: UInt32) -> Bool {
        ["x420", "x422", "xf20", "xf22"].map(code).contains(pixelFormat)
    }
}
