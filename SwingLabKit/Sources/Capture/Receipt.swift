import Foundation
import Swing

// Kvittot efter varje serie och ljusprovets kort (S2_SPEC §2.6–2.7, §12 S2c): rader
// med etikett, tal och en färg per rad (BESLUT B13: inga värdeord, ingen
// beskrivande text). Raderna byggs här så att vyn bara ritar dem; orden står i
// Swings Texter, på engelska (BESLUT B30, B33). METOD MS11

/// En rad: etiketten, talet med enhet, och färgen (good = vit, annars signalfärgen). `kind` säger
/// vilken av kvittots rader det är, så att domen (`Receipt.dom`) kan läsas ur raderna; ljusprovets
/// rader har ingen. Två rader är lika när det som visas är lika.
public struct ReceiptRow: Equatable, Sendable {
    public var label: String
    public var value: String
    public var light: ExposurePlan.Light
    public var kind: Kind?

    public enum Kind: String, Sendable {
        case rate, dropped, frames, clicks, size, length, heat
    }

    public init(_ label: String, _ value: String, _ light: ExposurePlan.Light = .good, kind: Kind? = nil) {
        self.label = label
        self.value = value
        self.light = light
        self.kind = kind
    }

    public static func == (a: ReceiptRow, b: ReceiptRow) -> Bool {
        a.label == b.label && a.value == b.value && a.light == b.light
    }
}

/// Kvittots dom (PLAN S4h, research 8 punkt 1): en mening när inspelningen är bra
/// ("240 fps · 2 swings heard"), annars varningarna med vad man gör, den värsta först. Raderna
/// med talen ligger bakom "Details". METOD MS11
public struct Kvittodom: Equatable, Sendable {
    /// Meningen när allt är bra; den första varningen annars.
    public let text: String
    /// Varningarna, den värsta först; tom när inspelningen är bra.
    public let varningar: [String]

    public var bra: Bool { varningar.isEmpty }
}

public enum Receipt {
    /// Rutnätets frekvens mot den önskade: nådd (vit), lägre slowmotion (gul),
    /// inte slowmotion (röd). METOD MS1, MS3
    public static func rateLight(_ t: FrameTiming, wantedRate: Double = 240) -> ExposurePlan.Light {
        if !t.isSlowMotion { return .tooDark }
        return t.gridRate >= wantedRate - FormatChoice.rateSlack ? .good : .marginal
    }

    /// Frekvensen som tal: rutnätet, och den uppmätta klockan inom parentes när den
    /// skiljer minst 0,05 ("240 (239.4)"). METOD MS3, MS11
    public static func rateText(_ t: FrameTiming) -> String {
        let grid = Taltext.integer(t.gridRate)
        guard let m = t.measuredRate, m.isFinite, abs(m - t.gridRate) >= measuredShown else { return grid }
        return "\(grid) (\(Taltext.decimal(m, digits: 1)))"
    }

    /// Den uppmätta klockan visas när den skiljer så mycket från rutnätet, bilder/s. METOD MS11
    public static let measuredShown = 0.05

    /// Tappade rutor efter källan: en egen inspelning ska inte tappa (MS3), Kamera-appens
    /// slowmotion-original tappar 30–40 % (oktobers klipp: 36 %) och varnas först över det
    /// normala. METOD MS11
    public static func missingLight(_ s: SeriesRecord) -> ExposurePlan.Light {
        switch s.source {
        case .recording: return Flicker.grade(missing: s.timing.missingFraction)
        case .photos: return Flicker.grade(importMissing: s.timing.missingFraction)
        }
    }

    /// Kvittot efter en serie: frekvensen, tappade rutor, antal rutor, klicken,
    /// filens storlek per minut, längden och trycket. METOD MS11
    public static func rows(_ s: SeriesRecord, wantedRate: Double = 240) -> [ReceiptRow] {
        var r = [
            ReceiptRow(Texter.kvittoBilder, rateText(s.timing), rateLight(s.timing, wantedRate: wantedRate), kind: .rate),
            ReceiptRow(Texter.kvittoTappade, Taltext.percent(s.timing.missingFraction), missingLight(s), kind: .dropped),
            ReceiptRow(Texter.kvittoRutor, Taltext.integer(Double(s.timing.count)), kind: .frames),
            ReceiptRow(Texter.kvittoKlick, Taltext.integer(Double(s.clicks.count)), s.clicks.isEmpty ? .marginal : .good,
                       kind: .clicks),
            ReceiptRow(Texter.kvittoMBmin, Taltext.integer(s.megabytesPerMinute), kind: .size),
            ReceiptRow(Texter.kvittoLangd, Taltext.duration(s.duration), kind: .length),
        ]
        if let p = s.pressure { r.append(ReceiptRow(pressureLabel, pressureName(p), p.light, kind: .heat)) }
        return r
    }

    /// Domen ur kvittots rader (PLAN S4h): varje rad som inte är bra blir en varning i ord med vad
    /// man gör, den värsta först och annars i radernas ordning; utan varningar en mening med
    /// frekvensen och svingarna som hördes. nil för rader utan `kind` (ljusprovet). METOD MS11
    public static func dom(_ rows: [ReceiptRow]) -> Kvittodom? {
        guard rows.contains(where: { $0.kind != nil }) else { return nil }
        let rate = rows.first { $0.kind == .rate }
        // Frekvensen utan den uppmätta klockan inom parentes: "240 (239.4)" → "240".
        let fps = rate.map { String($0.value.split(separator: " ").first ?? Substring($0.value)) } ?? ""
        var varningar: [(light: ExposurePlan.Light, nr: Int, text: String)] = []
        for (i, r) in rows.enumerated() where r.light != .good {
            let t: String?
            switch r.kind {
            case .rate?:
                let onskad = Int(FormatChoice.wantedRate)
                t = r.light == .tooDark ? Texter.domInteSlowmotion(fps, onskad: onskad) : Texter.domLagFps(fps, onskad: onskad)
            case .dropped?: t = Texter.domTappade(r.value)
            case .clicks?: t = Texter.domIngenHord
            case .heat?: t = Texter.domVarm
            default: t = nil
            }
            if let t { varningar.append((light: r.light, nr: i, text: t)) }
        }
        let ordnade = varningar.sorted { a, b in a.light != b.light ? a.light > b.light : a.nr < b.nr }.map { $0.text }
        if let forsta = ordnade.first { return Kvittodom(text: forsta, varningar: ordnade) }
        let klick = rows.first { $0.kind == .clicks }.flatMap { Int($0.value.replacingOccurrences(of: ",", with: "")) }
        let delar = (rate == nil ? [] : [Texter.domFps(fps)]) + (klick.map { [Texter.domHord($0)] } ?? [])
        return Kvittodom(text: delar.joined(separator: Texter.skilje), varningar: [])
    }

    /// Ljusprovets kort: ljuset (ISO eller bristen i steg), flimret, rutorna och
    /// ljusheten. Domen är den sämsta raden (METOD MS3).
    public static func rows(_ c: LightCheck, wantedRate: Double = 240) -> [ReceiptRow] {
        let e = c.exposure
        let ljus = e.deficitEV > 0
            ? ReceiptRow(Texter.ljusLjus, Texter.forMorkt(Taltext.decimal(e.deficitEV, digits: 1)), .tooDark)
            : ReceiptRow(Texter.ljusISO, Taltext.integer(e.neededISO), e.light)
        let flimmer = max(c.flicker100, c.flicker120)
        let rutor = Texter.rutorOchTappade(Taltext.integer(c.timing.gridRate), Taltext.percent(c.timing.missingFraction))
        return [
            ljus,
            ReceiptRow(Texter.ljusFlimmer, Taltext.percent(flimmer), c.flickerLight),
            ReceiptRow(Texter.ljusRutor, rutor, max(c.framesLight, rateLight(c.timing, wantedRate: wantedRate))),
            ReceiptRow(Texter.ljusLjushet, Taltext.percent(c.meanLuma), c.lumaLight),
        ]
    }

    /// Samma ord för värmetrycket i kvittot och i inspelningsvyn (BESLUT B13).
    public static let pressureLabel = Texter.kvittoVarme

    /// Trycket i ord (Texter).
    public static func pressureName(_ p: Pressure) -> String {
        Texter.trycket[p.rawValue] ?? p.rawValue
    }
}

/// Tal i kvittot på engelskt sätt (BESLUT B30), oberoende av telefonens språk:
/// decimalpunkt, komma mellan tusental och procent utan mellanslag.
public enum Taltext {
    public static func integer(_ x: Double) -> String {
        guard x.isFinite else { return "–" }
        let n = Int(x.rounded())
        let s = String(abs(n))
        var ut = ""
        for (i, ch) in s.enumerated() {
            if i > 0, (s.count - i) % 3 == 0, s.count > 4 { ut.append(",") }
            ut.append(ch)
        }
        return (n < 0 ? "−" : "") + ut
    }

    public static func decimal(_ x: Double, digits: Int) -> String {
        guard x.isFinite else { return "–" }
        let s = String(format: "%.\(max(0, digits))f", abs(x))
        let noll = s.allSatisfy { $0 == "0" || $0 == "." }
        return (x < 0 && !noll ? "−" : "") + s
    }

    /// Andel som procent: under 0.05 % → "0%", under 10 % med en decimal, annars heltal.
    public static func percent(_ f: Double) -> String {
        guard f.isFinite else { return "–" }
        let p = f * 100
        if abs(p) < 0.05 { return "0%" }
        return (abs(p) < 10 ? decimal(p, digits: 1) : integer(p)) + "%"
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
    public static let refusal = Texter.inteOriginalet
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
