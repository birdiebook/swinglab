import Foundation

/// En axel med jämna steg, för spannet och diagrammet.
public struct Axel: Equatable, Sendable {
    public let lo: Double
    public let hi: Double
    public let steg: Double

    /// Steget 1, 2 eller 5 gånger en tiopotens, närmast `ra`.
    public static func jamntSteg(_ ra: Double) -> Double {
        guard ra > 0, ra.isFinite else { return 1 }
        let p = pow(10, (log10(ra)).rounded(.down))
        let f = ra / p
        return (f < 1.5 ? 1 : f < 3.5 ? 2 : f < 7.5 ? 5 : 10) * p
    }

    /// Axeln som rymmer värdena, med marginal och ändarna på hela steg.
    public static func runt(_ varden: [Double], delar: Double = 4, marginal: Double = 0.1) -> Axel {
        let v = varden.filter { $0.isFinite }
        guard var lo = v.min(), var hi = v.max() else { return Axel(lo: 0, hi: 1, steg: 1) }
        if hi - lo < 1e-9 {
            lo -= 1
            hi += 1
        }
        let m = (hi - lo) * marginal
        lo -= m
        hi += m
        let steg = jamntSteg((hi - lo) / delar)
        return Axel(lo: (lo / steg).rounded(.down) * steg, hi: (hi / steg).rounded(.up) * steg, steg: steg)
    }

    /// Läget 0…1 längs axeln, begränsat till axeln.
    public func andel(_ v: Double) -> Double {
        guard hi > lo else { return 0.5 }
        return Swift.min(1, Swift.max(0, (v - lo) / (hi - lo)))
    }

    /// Strecken på hela steg.
    public var streck: [Double] {
        var ut: [Double] = []
        var v = (lo / steg).rounded(.up) * steg
        while v <= hi + steg * 1e-6 {
            ut.append(abs(v) < steg * 1e-9 ? 0 : v)
            v += steg
        }
        return ut
    }
}

/// Spannet (BESLUT B13, regel 3 och 4): en tunn linje, gränsen som ett tjockare
/// segment eller den egna baslinjen som en ram, förra passet som ett streck och
/// passet som en markör med kvartilerna som en tunn vit linje.
public struct Spann: Equatable, Sendable {
    public enum Zon: Equatable, Sendable {
        /// Katalogens gröna gräns, öppna ändar till axelns ände.
        case grans(lo: Double, hi: Double)
        /// Den egna baslinjen (M27): medianen ± en robust sd.
        case baslinje(lo: Double, hi: Double)
    }

    public let axel: Axel
    public let zon: Zon?
    public let nu: Double
    /// Kvartilerna (M25), nil utan sammanfattning.
    public let spridning: (lo: Double, hi: Double)?
    public let forra: Double?
    /// Talen under linjen: axelns ändar och zonens ändar.
    public let etiketter: [(varde: Double, text: String)]

    public static func == (a: Spann, b: Spann) -> Bool {
        a.axel == b.axel && a.zon == b.zon && a.nu == b.nu && a.forra == b.forra
            && a.spridning?.lo == b.spridning?.lo && a.spridning?.hi == b.spridning?.hi
            && a.etiketter.map(\.text) == b.etiketter.map(\.text)
    }

    /// `gront` som i katalogen ([lo, hi], nil = öppen ände); utan den används `baslinje`.
    public init(nu: Double, spridning: (lo: Double, hi: Double)?, forra: Double?, gront: [Double?]?,
                baslinje: (lo: Double, hi: Double)?, decimaler: Int) {
        var varden = [nu]
        if let s = spridning { varden += [s.lo, s.hi] }
        if let f = forra { varden.append(f) }
        let gLo = gront?.first ?? nil, gHi = gront?.last ?? nil
        if let g = gLo { varden.append(g) }
        if let g = gHi { varden.append(g) }
        if gront == nil, let b = baslinje { varden += [b.lo, b.hi] }
        // En öppen gräns ska synas som öppen: axeln sträcker sig en bit förbi den slutna änden.
        if gront != nil, (gLo == nil) != (gHi == nil), let sluten = gLo ?? gHi {
            let span = (varden.max()! - varden.min()!)
            varden.append(gLo == nil ? sluten - Swift.max(span, 1) * 0.5 : sluten + Swift.max(span, 1) * 0.5)
        }
        let axel = Axel.runt(varden)
        self.axel = axel
        self.nu = nu
        self.spridning = spridning
        self.forra = forra
        if gront != nil {
            zon = .grans(lo: gLo ?? axel.lo, hi: gHi ?? axel.hi)
        } else if let b = baslinje {
            zon = .baslinje(lo: b.lo, hi: b.hi)
        } else {
            zon = nil
        }
        var e: [Double] = [axel.lo]
        switch zon {
        case let .grans(lo, hi), let .baslinje(lo, hi):
            for v in [lo, hi] where v > axel.lo + 1e-9 && v < axel.hi - 1e-9 { e.append(v) }
        case nil:
            break
        }
        e.append(axel.hi)
        etiketter = e.map { v -> (varde: Double, text: String) in
            // Baslinjens ändar är räknade tal; axelns och gränsens är hela.
            (v, Tal.axel(v, decimaler: decimaler))
        }
    }
}
