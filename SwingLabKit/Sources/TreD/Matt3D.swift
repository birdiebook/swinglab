import Foundation

/// Vridningen, X-factor, stretchen och höfterna vid träffen ur 3D-leder (m·13·3, världens
/// ram med z uppåt). Rad för rad som tools/pc/tre_d/matt.py. METOD MK6
enum Matt3D {
    /// Ledernas index i filens ordning (FORMAT.md, tre_d/sving.py LEDER).
    static let vAxel = 1, hAxel = 2, vArmbage = 3, hArmbage = 4, vHandled = 5, hHandled = 6
    static let vHoft = 7, hHoft = 8
    static let antalLeder = 13

    /// En längre lucka i en vinkelkurva fylls inte (som M3). METOD MK6
    static let maxLuckaS = 0.10

    static func grader(_ x: Double) -> Double { x * (180.0 / Double.pi) }

    /// Vridningen (grader) av linjen R → L i markplanet mot adressen, positiv bort från
    /// målet, inom ±180° från adressen. Som `linjevinkel`.
    static func linjevinkel(_ p: [Double], _ l: Int, _ r: Int, _ t: [Double], _ adress: (Double, Double)) -> [Double] {
        let n = t.count
        var vin = [Double](repeating: .nan, count: n)
        for i in 0..<n {
            let vx = p[(i * antalLeder + l) * 3] - p[(i * antalLeder + r) * 3]
            let vy = p[(i * antalLeder + l) * 3 + 1] - p[(i * antalLeder + r) * 3 + 1]
            vin[i] = atan2(vy, vx)
        }
        var s: [Double] = [], c: [Double] = []
        for i in 0..<n where t[i] >= adress.0 && t[i] <= adress.1 && vin[i].isFinite {
            s.append(sin(vin[i]))
            c.append(cos(vin[i]))
        }
        guard !s.isEmpty else { return [Double](repeating: .nan, count: n) }
        let ref = atan2(LA.medel(s), LA.medel(c))
        return vin.map { v in
            let d = v - ref
            return -grader(atan2(sin(d), cos(d)))
        }
    }

    /// Linjär interpolation över NaN, bara mellan två värden högst maxLucka isär och
    /// inom de första och sista värdena. Som `fyll_luckor`. METOD MK6
    static func fyllLuckor(_ t: [Double], _ y: [Double], maxLucka: Double = maxLuckaS) -> [Double] {
        var tk: [Double] = [], yk: [Double] = []
        for i in 0..<t.count where y[i].isFinite {
            tk.append(t[i])
            yk.append(y[i])
        }
        if tk.count < 2 || tk.count == t.count { return y }
        var ut = y
        for i in 0..<t.count where !y[i].isFinite {
            let j = min(max(LA.vanster(tk, t[i]), 1), tk.count - 1)
            let lucka = (tk[j] - tk[j - 1]) > maxLucka
            let utanfor = t[i] < tk[0] || t[i] > tk[tk.count - 1]
            ut[i] = (lucka || utanfor) ? .nan : LA.interp(t[i], tk, yk)
        }
        return ut
    }

    /// Värdet vid `tid`, linjärt mellan de närmaste; NaN utanför kurvans värden. Som `_vid`.
    static func vid(_ t: [Double], _ y: [Double], _ tid: Double) -> Double {
        var tk: [Double] = [], yk: [Double] = []
        for i in 0..<t.count where y[i].isFinite {
            tk.append(t[i])
            yk.append(y[i])
        }
        guard tk.count >= 2, tid.isFinite, tk[0] <= tid, tid <= tk[tk.count - 1] else { return .nan }
        return LA.interp(tid, tk, yk)
    }

    /// Toppen: där handledernas mitt står högst mellan starten och träffen, med en
    /// parabel genom toppen. Som `topptid`.
    static func topptid(_ p: [Double], _ t: [Double], _ tStart: Double, _ tTraff: Double) -> Double {
        var tt: [Double] = [], zz: [Double] = []
        for i in 0..<t.count {
            let z = 0.5 * (p[(i * antalLeder + vHandled) * 3 + 2] + p[(i * antalLeder + hHandled) * 3 + 2])
            if t[i] >= tStart && t[i] < tTraff && z.isFinite {
                tt.append(t[i])
                zz.append(z)
            }
        }
        guard !zz.isEmpty else { return .nan }
        var i = 0
        for k in 1..<zz.count where zz[k] > zz[i] { i = k }
        if 0 < i && i < zz.count - 1 {
            let den = zz[i - 1] - 2 * zz[i] + zz[i + 1]
            if den < 0 {
                return tt[i] + 0.5 * (zz[i - 1] - zz[i + 1]) / den * (tt[1] - tt[0])
            }
        }
        return tt[i]
    }

    /// Lokal andragradsregression (trikubisk kärna) av en vinkelkurva, som `jamna_kurva`.
    static func jamnaKurva(_ t: [Double], _ y: [Double], _ halvbredd: Double) -> [Double] {
        var uv = [Double](repeating: 0, count: t.count * 2)
        for i in 0..<t.count { uv[i * 2] = y[i] }
        let s = Spar2D(t: t, uv: uv, k: [Double](repeating: 1, count: t.count), j: 1)
        let (ut, _) = Utjamning.jamna(s, t, halvbredd, robust: false)
        return (0..<t.count).map { ut[$0 * 2] }
    }

    struct Matt {
        var tTopp: Double
        var backenTopp: Double
        var brostTopp: Double
        var xfaktorTopp: Double
        var stretch: Double
        var hofterOppnaTraff: Double
    }

    /// Måtten ur 3D-lederna på tidsaxeln t (jämn), toppen ur händerna. Som `svingmatt`
    /// med topp="hander".
    static func svingmatt(_ p: [Double], _ t: [Double], _ tStart: Double, _ tTraff: Double,
                          _ adress: (Double, Double), utjamna: Double) -> Matt {
        var b = fyllLuckor(t, linjevinkel(p, vHoft, hHoft, t, adress))
        var s = fyllLuckor(t, linjevinkel(p, vAxel, hAxel, t, adress))
        if utjamna > 0 {
            b = jamnaKurva(t, b, utjamna)
            s = jamnaKurva(t, s, utjamna)
        }
        let x = (0..<t.count).map { s[$0] - b[$0] }
        let tt = topptid(p, t, tStart, tTraff)
        let xTopp = vid(t, x, tt)
        var stretch = Double.nan
        if tt.isFinite {
            var storst = -Double.infinity
            var nagon = false
            for i in 0..<t.count where t[i] >= tt && t[i] <= tt + 0.5 * (tTraff - tt) && x[i].isFinite {
                storst = max(storst, x[i])
                nagon = true
            }
            if nagon { stretch = storst - xTopp }
        }
        return Matt(tTopp: tt, backenTopp: vid(t, b, tt), brostTopp: vid(t, s, tt), xfaktorTopp: xTopp,
                    stretch: stretch, hofterOppnaTraff: -vid(t, b, tTraff))
    }
}
