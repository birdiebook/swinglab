import Foundation

/// Farterna ur ledernas tidsserie: handens fart, främre armens vinkelfart och
/// finishens tid, samma som `tools/pc/farter.py` (BESLUT B12). METOD M35–M37
///
/// Farten räknas på ett rutnät i tiden (1 ms), inte i rutorna: i varje punkt τ är
/// hastigheten lutningen i en viktad linjär anpassning över tiden till de råa
/// lederna inom 3σ från τ, med utjämningens gaussvikt (METOD M3). Inte en differens
/// av de utjämnade lägena: luckorna gör utjämningens vikter osymmetriska, och en
/// differens förstorar det. Farterna kräver skarp bild (BESLUT B11) och är
/// oprovade på telefonen. METOD M35
public enum Farter {
    /// Rutnätet i tiden som farten räknas på. METOD M35
    public static let stegS = 0.001
    /// Finishen = handens fart under 10 % av genomsvingens toppfart. METOD M36
    public static let genomsvingAndel = 0.10

    /// Tiderna a, a + 1 ms, … till och med b. METOD M35
    public static func rutnat(_ a: Double, _ b: Double) -> [Double] {
        let n = Int(((b - a) / stegS + 1e-9).rounded(.down))
        guard n >= 0 else { return [] }
        return (0...n).map { a + Double($0) * stegS }
    }

    /// Rutorna med värde inom 3σ från τ och deras gaussvikter, i tidsordning, eller
    /// nil utan en ruta med värde före τ och en efter. METOD M35
    static func fonster(_ t: [Double], _ ok: [Bool], _ tau: Double) -> (js: [Int], w: [Double])? {
        let grans = Faser.trunkera * Faser.sigmaS
        let js = t.indices.filter { ok[$0] && abs(t[$0] - tau) <= grans }
        guard let forsta = js.first, let sista = js.last, t[forsta] < tau && tau < t[sista] else { return nil }
        return (js, js.map { j in
            let d = (t[j] - tau) / Faser.sigmaS
            return exp(-0.5 * (d * d))
        })
    }

    /// Lutningen i den viktade linjära anpassningen y ≈ a + b·dt.
    static func lutning(_ dt: [Double], _ y: [Double], _ w: [Double]) -> Double {
        var sw = 0.0, st = 0.0, sy = 0.0
        for i in w.indices {
            sw += w[i]
            st += w[i] * dt[i]
            sy += w[i] * y[i]
        }
        let mt = st / sw, my = sy / sw
        var num = 0.0, den = 0.0
        for i in w.indices {
            num += w[i] * (dt[i] - mt) * (y[i] - my)
            den += w[i] * (dt[i] - mt) * (dt[i] - mt)
        }
        return num / den
    }

    /// Punktens hastighet i px/s på rutnätet tau ur de råa lägena p, saknad där den
    /// inte går att räkna. METOD M35
    public static func hastighet(_ t: [Double], _ p: [Punkt], _ tau: [Double]) -> [Punkt] {
        let ok = p.map { $0.hel }
        return tau.map { tc in
            guard let f = fonster(t, ok, tc) else { return .saknad }
            let dt = f.js.map { t[$0] - tc }
            return Punkt(lutning(dt, f.js.map { p[$0].x }, f.w), lutning(dt, f.js.map { p[$0].y }, f.w))
        }
    }

    /// Farten i px/s på rutnätet tau (NaN där hastigheten saknas). METOD M35
    public static func fart(_ t: [Double], _ p: [Punkt], _ tau: [Double]) -> [Double] {
        hastighet(t, p, tau).map { $0.hel ? hypot($0.x, $0.y) : .nan }
    }

    /// Vinkelskillnaden i grader, lagd i (−180, 180].
    static func vinkel(_ d: Double) -> Double {
        d - 360.0 * ((d - 180.0) / 360.0).rounded(.up)
    }

    /// Linjen fran → till (råa lägen): vinkelns fart i grader/s i bildens plan, som
    /// belopp, på rutnätet tau. Varje rutas vinkel räknas mot den första rutan i
    /// fönstret, lagd i (−180, 180]. METOD M37
    public static func vinkelfart(_ t: [Double], fran: [Punkt], till: [Punkt], _ tau: [Double]) -> [Double] {
        let d = zip(fran, till).map { $1 - $0 }
        let ok = d.map { $0.hel }
        func grad(_ j: Int) -> Double { Matt.grader(atan2(d[j].y, d[j].x)) }
        return tau.map { tc in
            guard let f = fonster(t, ok, tc) else { return .nan }
            let ref = grad(f.js[0])
            let dt = f.js.map { t[$0] - tc }
            return abs(lutning(dt, f.js.map { vinkel(grad($0) - ref) }, f.w))
        }
    }

    /// Parabeln genom tre punkter, i tc (Lagrange).
    static func parabel(_ t0: Double, _ y0: Double, _ t1: Double, _ y1: Double, _ t2: Double, _ y2: Double,
                        _ tc: Double) -> Double {
        y0 * (tc - t1) * (tc - t2) / ((t0 - t1) * (t0 - t2))
            + y1 * (tc - t0) * (tc - t2) / ((t1 - t0) * (t1 - t2))
            + y2 * (tc - t0) * (tc - t1) / ((t2 - t0) * (t2 - t1))
    }

    /// (största värdet, dess tid) på rutnätet, förfinade med parabeln genom punkten
    /// och dess två grannar med värde (som toppen, METOD M4). nil utan värden. METOD M35
    public static func maxpunkt(_ tau: [Double], _ s: [Double]) -> (varde: Double, tid: Double)? {
        let idx = s.indices.filter { s[$0].isFinite }
        guard !idx.isEmpty else { return nil }
        var j = 0
        for m in 1..<idx.count where s[idx[m]] > s[idx[j]] { j = m }
        let k1 = idx[j]
        guard j > 0 && j < idx.count - 1 else { return (s[k1], tau[k1]) }
        let k0 = idx[j - 1], k2 = idx[j + 1]
        let tc = Faser.toppunkt(tau[k0], -s[k0], tau[k1], -s[k1], tau[k2], -s[k2])
        return (parabel(tau[k0], s[k0], tau[k1], s[k1], tau[k2], s[k2], tc), tc)
    }

    /// Finishen i tid: första gången efter toppfarten på rutnätet som handens fart
    /// faller under genomsvingAndel av den, linjärt mellan två punkter i följd med
    /// värde. nil om farten aldrig faller under, eller om punkterna ligger mer än
    /// maxLuckaS isär. METOD M36
    public static func finishTid(_ tau: [Double], _ s: [Double]) -> Double? {
        let idx = s.indices.filter { s[$0].isFinite }
        guard !idx.isEmpty else { return nil }
        var j = 0
        for m in 1..<idx.count where s[idx[m]] > s[idx[j]] { j = m }
        let troskel = genomsvingAndel * s[idx[j]]
        var i = j + 1
        while i < idx.count {
            let k0 = idx[i - 1], k1 = idx[i]
            if s[k1] < troskel {
                guard tau[k1] - tau[k0] <= Faser.maxLuckaS else { return nil }
                return tau[k0] + (troskel - s[k0]) / (s[k1] - s[k0]) * (tau[k1] - tau[k0])
            }
            i += 1
        }
        return nil
    }
}
