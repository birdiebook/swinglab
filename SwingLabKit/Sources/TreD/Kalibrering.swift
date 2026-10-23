import Foundation

/// Självkalibreringen ur lederna: viktad normaliserad åttapunktsmetod, robusta varv och
/// förfining på Sampson-felet med Levenberg–Marquardt (Hartley 1997). Rad för rad som
/// tools/pc/tre_d/kalibrering.py. Punkterna är normerade (x, y, 1), n·3 tal. METOD MK3
enum Kalibrering {
    struct ForFa: Error {}

    /// Åttapunktsmetoden kräver minst nio punktpar (med åtta är nollrummet inte bestämt
    /// som Python räknar det). METOD M51
    static let minPunktpar = 9

    /// Levenberg–Marquardt med numerisk Jacobian, som `lm`. fun(p) → residualerna.
    static func lm(_ fun: ([Double]) -> [Double], _ p0: [Double], iter: Int = 40, eps: Double = 1e-6) throws -> [Double] {
        var p = p0
        var r = fun(p)
        var c = dot(r, r)
        var lam = 1e-3
        let np = p.count, nr = r.count
        var jac = [Double](repeating: 0, count: nr * np)
        for _ in 0..<iter {
            for k in 0..<np {
                var q = p
                q[k] += eps
                let rk = fun(q)
                for i in 0..<nr { jac[i * np + k] = (rk[i] - r[i]) / eps }
            }
            var a = [Double](repeating: 0, count: np * np)
            var g = [Double](repeating: 0, count: np)
            for i in 0..<np {
                for j in 0..<np {
                    var s = 0.0
                    for l in 0..<nr { s += jac[l * np + i] * jac[l * np + j] }
                    a[i * np + j] = s
                }
                var s = 0.0
                for l in 0..<nr { s += jac[l * np + i] * r[l] }
                g[i] = s
            }
            var klart = false
            while true {
                var m = a
                for i in 0..<np { m[i * np + i] = a[i * np + i] + lam * (a[i * np + i] + 1e-12) }
                let steg = try LA.los(m, g, np, 1).map { -$0 }
                var q = p
                for i in 0..<np { q[i] += steg[i] }
                let r2 = fun(q)
                let c2 = dot(r2, r2)
                if c2 < c {
                    p = q
                    klart = (c - c2) < 1e-10 * max(c, 1e-30)
                    r = r2
                    c = c2
                    lam = max(lam * 0.3, 1e-12)
                    break
                }
                lam *= 10
                if lam > 1e10 { return p }
            }
            if klart { break }
        }
        return p
    }

    static func dot(_ a: [Double], _ b: [Double]) -> Double {
        var s = 0.0
        for i in 0..<a.count { s += a[i] * b[i] }
        return s
    }

    /// Normaliseringen (Hartley): medelpunkten till origo och medelavståndet √2.
    static func normalisering(_ x: [Double], _ n: Int) -> [Double] {
        var mx = 0.0, my = 0.0
        for i in 0..<n {
            mx += x[i * 3]
            my += x[i * 3 + 1]
        }
        mx /= Double(n)
        my /= Double(n)
        var avst = [Double](repeating: 0, count: n)
        for i in 0..<n {
            let dx = x[i * 3] - mx, dy = x[i * 3 + 1] - my
            avst[i] = (dx * dx + dy * dy).squareRoot()
        }
        let s = 2.0.squareRoot() / LA.medel(avst)
        return [s, 0, -s * mx, 0, s, -s * my, 0, 0, 1]
    }

    /// Sampson-felet per punktpar (normerade enheter, med tecken).
    static func sampson(_ e: [Double], _ x1: [Double], _ x2: [Double], _ n: Int) -> [Double] {
        var ut = [Double](repeating: 0, count: n)
        for i in 0..<n {
            let a0 = x1[i * 3], a1 = x1[i * 3 + 1], a2 = x1[i * 3 + 2]
            let b0 = x2[i * 3], b1 = x2[i * 3 + 1], b2 = x2[i * 3 + 2]
            let ex0 = e[0] * a0 + e[1] * a1 + e[2] * a2
            let ex1 = e[3] * a0 + e[4] * a1 + e[5] * a2
            let ex2 = e[6] * a0 + e[7] * a1 + e[8] * a2
            let et0 = b0 * e[0] + b1 * e[3] + b2 * e[6]
            let et1 = b0 * e[1] + b1 * e[4] + b2 * e[7]
            let num = b0 * ex0 + b1 * ex1 + b2 * ex2
            let den = ex0 * ex0 + ex1 * ex1 + et0 * et0 + et1 * et1
            ut[i] = num / max(den, 1e-18).squareRoot()
        }
        return ut
    }

    /// Viktad, normaliserad åttapunktsmetod för E, som `atta_punkt`.
    static func attaPunkt(_ x1: [Double], _ x2: [Double], _ w: [Double], _ n: Int) -> [Double] {
        let t1 = normalisering(x1, n), t2 = normalisering(x2, n)
        var a = [Double](repeating: 0, count: n * 9)        // kolumnvis, n rader
        for i in 0..<n {
            let p = [x1[i * 3], x1[i * 3 + 1], x1[i * 3 + 2]], q = [x2[i * 3], x2[i * 3 + 1], x2[i * 3 + 2]]
            let pa = LA.mulv3(t1, p), qb = LA.mulv3(t2, q)
            for r in 0..<3 {
                for c in 0..<3 { a[(r * 3 + c) * n + i] = qb[r] * pa[c] * w[i] }
            }
        }
        let f = LA.nollvektor(&a, n, 9)
        let e = LA.mul3(LA.mul3(LA.transp(t2, 3, 3), f), t1)
        let (u, _, v) = LA.svd3(e)
        // U · diag(1, 1, 0) · Vᵀ
        var ut = [Double](repeating: 0, count: 9)
        for i in 0..<3 {
            for j in 0..<3 { ut[i * 3 + j] = u[i * 3] * v[j * 3] + u[i * 3 + 1] * v[j * 3 + 1] }
        }
        return ut
    }

    /// De fyra lösningarna ur E; den där flest punkter ligger framför båda kamerorna.
    static func delaUppE(_ e: [Double], _ x1: [Double], _ x2: [Double], _ n: Int) -> (r: [Double], t: [Double]) {
        let usv = LA.svd3(e)
        var u = usv.u
        if LA.det3(u) < 0 { u = u.map { -$0 } }
        let vt = LA.transp(usv.v, 3, 3)
        let vtr = LA.det3(vt) < 0 ? vt.map { -$0 } : vt
        let w: [Double] = [0, -1, 0, 1, 0, 0, 0, 0, 1]
        let u3 = [u[2], u[5], u[8]]
        var bast: ([Double], [Double]) = (LA.enhet3, [0, 0, 1])
        var flest = -1
        var a = [Double](repeating: 0, count: 16), v = a
        for r in [LA.mul3(LA.mul3(u, w), vtr), LA.mul3(LA.mul3(u, LA.transp(w, 3, 3)), vtr)] {
            for t in [u3, u3.map { -$0 }] {
                let p2: [Double] = [r[0], r[1], r[2], t[0], r[3], r[4], r[5], t[1], r[6], r[7], r[8], t[2]]
                var fram = 0
                for i in 0..<n {
                    let x = triangulerPar(p2, x1, x2, i, &a, &v)
                    let z2 = r[6] * x.0 + r[7] * x.1 + r[8] * x.2 + t[2]
                    if x.2 > 0 && z2 > 0 { fram += 1 }
                }
                if fram > flest {
                    bast = (r, t)
                    flest = fram
                }
            }
        }
        return bast
    }

    static let p1: [Double] = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0]

    /// Ett punktpar trianguleras med P1 = [I | 0], P2 = [R | t] (p2, 3×4 radvis), som
    /// `_triangulera_par`. a och v är arbetsytor om 16 tal.
    static func triangulerPar(_ p2: [Double], _ x1: [Double], _ x2: [Double], _ i: Int,
                              _ a: inout [Double], _ v: inout [Double]) -> (Double, Double, Double) {
        let p1 = Kalibrering.p1
        let a0 = x1[i * 3], a1 = x1[i * 3 + 1], b0 = x2[i * 3], b1 = x2[i * 3 + 1]
        for k in 0..<4 {
            a[k * 4] = a0 * p1[8 + k] - p1[k]
            a[k * 4 + 1] = a1 * p1[8 + k] - p1[4 + k]
            a[k * 4 + 2] = b0 * p2[8 + k] - p2[k]
            a[k * 4 + 3] = b1 * p2[8 + k] - p2[4 + k]
        }
        let j = LA.nollkolumn(&a, 4, 4, &v) * 4
        return (v[j] / v[j + 3], v[j + 1] / v[j + 3], v[j + 2] / v[j + 3])
    }

    static func paramT(_ a0: Double, _ a1: Double) -> [Double] {
        [sin(a0) * cos(a1), sin(a0) * sin(a1), cos(a0)]
    }

    /// De robusta vikterna ur residualerna i px (Cauchy med skalan 2,5 · 1,4826 · median).
    static func vikter(_ w: [Double], _ r: [Double]) -> [Double] {
        let s = 1.4826 * LA.median(r) + 1e-9
        return (0..<w.count).map { i in
            let q = r[i] / (2.5 * s)
            return w[i] / (1 + q * q)
        }
    }

    /// R, t (|t| = 1) från kamera 1 till kamera 2 ur normerade punktpar, som
    /// `relativ_orientering`.
    static func relativOrientering(_ x1: [Double], _ x2: [Double], _ w: [Double], _ n: Int, fPx: Double,
                                   varv: Int = 3) throws -> (r: [Double], t: [Double]) {
        var vikt = w
        var e = LA.enhet3
        for _ in 0..<varv {
            e = attaPunkt(x1, x2, vikt, n)
            let r = sampson(e, x1, x2, n).map { abs($0) * fPx }
            vikt = vikter(w, r)
        }
        var (r0, t0) = delaUppE(e, x1, x2, n)
        var th = acos(min(max(t0[2], -1), 1))
        var ph = atan2(t0[1], t0[0])
        var sv = vikt.map { $0.squareRoot() }
        for _ in 0..<2 {
            let rBas = r0, svNu = sv
            let res: ([Double]) -> [Double] = { p in
                let rr = LA.mul3(LA.rodrigues([p[0], p[1], p[2]]), rBas)
                let e = LA.mul3(LA.skev(paramT(p[3], p[4])), rr)
                let s = sampson(e, x1, x2, n)
                return (0..<n).map { svNu[$0] * s[$0] * fPx }
            }
            let p = try Kalibrering.lm(res, [0, 0, 0, th, ph], iter: 30)
            r0 = LA.mul3(LA.rodrigues([p[0], p[1], p[2]]), r0)
            th = p[3]
            ph = p[4]
            let r = sampson(LA.mul3(LA.skev(paramT(p[3], p[4])), r0), x1, x2, n).map { abs($0) * fPx }
            vikt = vikter(w, r)
            sv = vikt.map { $0.squareRoot() }
        }
        t0 = paramT(th, ph)
        return (r0, t0)
    }

    /// R, t och Sampson-felets median (normerade enheter), som `relativ_ur_normerade`.
    static func relativUrNormerade(_ x1: [Double], _ x2: [Double], _ w: [Double], fPx: Double) throws
        -> (r: [Double], t: [Double], sampson: Double) {
        let n = w.count
        guard n >= minPunktpar else { throw ForFa() }
        let (r, t) = try relativOrientering(x1, x2, w, n, fPx: fPx)
        let s = sampson(LA.mul3(LA.skev(t), r), x1, x2, n).map { abs($0) }
        return (r, t, LA.median(s))
    }

    /// Lodlinjen i A:s ram ur kamerornas vågräta; nil när kamerorna står för nära samma
    /// riktning. Som `upp_ur_vagrata`. METOD MK3
    static func uppUrVagrata(_ r: [Double]) -> [Double]? {
        let xA: [Double] = [1, 0, 0]
        let xB = [r[0], r[1], r[2]]                     // Rᵀ · e₁
        var u = LA.kryss(xA, xB)
        let n = LA.norm3(u)
        if n < 0.2 { return nil }
        u = u.map { $0 / n }
        return u[1] < 0 ? u : u.map { -$0 }
    }

    /// Kamerorna i en värld där z är `upp` (A:s ram) och x A:s blickriktning i markplanet,
    /// origo i kamera A. Som `varld`.
    static func varld(_ ka: [Double], _ kb: [Double], _ r: [Double], _ t: [Double], _ upp: [Double])
        -> (Kamera3D, Kamera3D) {
        let nu = LA.norm3(upp)
        let z = upp.map { $0 / nu }
        let f = [0 - z[2] * z[0], 0 - z[2] * z[1], 1 - z[2] * z[2]]
        let nf = LA.norm3(f)
        let x = f.map { $0 / nf }
        let y = LA.kryss(z, x)
        let b: [Double] = [x[0], y[0], z[0], x[1], y[1], z[1], x[2], y[2], z[2]]
        return (Kamera3D(k: ka, r: b, t: [0, 0, 0]), Kamera3D(k: kb, r: LA.mul3(r, b), t: t))
    }
}
