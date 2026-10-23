import Foundation

/// Den linjära algebra som 3D kräver, utan Accelerate (BESLUT B48): SwingLabKit har bara
/// Foundation och testas på Linux. Varje del speglar det numpy gör i tools/pc/tre_d, så
/// att talen blir Pythons inom METOD M50:s tolerans. Matriser är radvisa [Double] om inget
/// annat sägs.
enum LA {
    // MARK: - Summor och medianer

    /// numpys parvisa summering (add.reduce längs en sammanhängande axel): åtta
    /// delsummor upp till 128 tal, annars två halvor. METOD M50
    static func parvis(_ a: UnsafeBufferPointer<Double>, _ lo: Int, _ n: Int) -> Double {
        if n < 8 {
            var res = 0.0
            for i in 0..<n { res += a[lo + i] }
            return res
        }
        if n <= 128 {
            var r0 = a[lo], r1 = a[lo + 1], r2 = a[lo + 2], r3 = a[lo + 3]
            var r4 = a[lo + 4], r5 = a[lo + 5], r6 = a[lo + 6], r7 = a[lo + 7]
            var i = 8
            while i < n - (n % 8) {
                r0 += a[lo + i]; r1 += a[lo + i + 1]; r2 += a[lo + i + 2]; r3 += a[lo + i + 3]
                r4 += a[lo + i + 4]; r5 += a[lo + i + 5]; r6 += a[lo + i + 6]; r7 += a[lo + i + 7]
                i += 8
            }
            var res = ((r0 + r1) + (r2 + r3)) + ((r4 + r5) + (r6 + r7))
            while i < n {
                res += a[lo + i]
                i += 1
            }
            return res
        }
        var n2 = n / 2
        n2 -= n2 % 8
        return parvis(a, lo, n2) + parvis(a, lo + n2, n - n2)
    }

    /// np.sum för en vektor.
    static func summa(_ a: [Double]) -> Double {
        a.withUnsafeBufferPointer { parvis($0, 0, a.count) }
    }

    /// np.mean för en vektor.
    static func medel(_ a: [Double]) -> Double {
        summa(a) / Double(a.count)
    }

    /// np.median; NaN för en tom lista.
    static func median(_ a: [Double]) -> Double {
        guard !a.isEmpty else { return .nan }
        let s = a.sorted()
        let n = s.count
        return n % 2 == 1 ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2
    }

    /// np.nanmedian: medianen av talen som inte är NaN, NaN om inga finns.
    static func nanmedian(_ a: [Double]) -> Double {
        median(a.filter { !$0.isNaN })
    }

    // MARK: - Tidsaxlar och sökning

    /// np.arange(a, b, steg) för flyttal: längden ⌈(b − a)/steg⌉, a, a + steg, och sedan
    /// a + i·((a + steg) − a), som numpys fill gör. METOD M50
    static func arange(_ a: Double, _ b: Double, _ steg: Double) -> [Double] {
        let langd = ((b - a) / steg).rounded(.up)
        // Ett orimligt långt intervall ger ingen axel (aldrig en trap eller ett minne som tar
        // slut); kedjan stoppar sådana slag före (METOD M51).
        guard langd > 0, langd < 1e7 else { return [] }
        let n = Int(langd)
        var ut = [Double](repeating: a, count: n)
        if n > 1 { ut[1] = a + steg }
        let d = (a + steg) - a
        if n > 2 {
            for i in 2..<n { ut[i] = a + Double(i) * d }
        }
        return ut
    }

    /// np.searchsorted(x, v, side="left").
    static func vanster(_ x: [Double], _ v: Double) -> Int {
        var lo = 0, hi = x.count
        while lo < hi {
            let m = (lo + hi) / 2
            if x[m] < v { lo = m + 1 } else { hi = m }
        }
        return lo
    }

    /// np.searchsorted(x, v, side="right").
    static func hoger(_ x: [Double], _ v: Double) -> Int {
        var lo = 0, hi = x.count
        while lo < hi {
            let m = (lo + hi) / 2
            if x[m] <= v { lo = m + 1 } else { hi = m }
        }
        return lo
    }

    /// np.interp(x, xp, fp) inom xp (xp stigande); ändvärdena utanför, som numpy.
    static func interp(_ x: Double, _ xp: [Double], _ fp: [Double]) -> Double {
        let n = xp.count
        if x > xp[n - 1] { return fp[n - 1] }
        if x < xp[0] { return fp[0] }
        if n == 1 { return fp[0] }
        if x == xp[n - 1] { return fp[n - 1] }
        let j = hoger(xp, x) - 1               // xp[j] <= x < xp[j + 1]
        if xp[j] == x { return fp[j] }
        let lutning = (fp[j + 1] - fp[j]) / (xp[j + 1] - xp[j])
        var r = lutning * (x - xp[j]) + fp[j]
        if r.isNaN {
            r = lutning * (x - xp[j + 1]) + fp[j + 1]
            if r.isNaN && fp[j] == fp[j + 1] { r = fp[j] }
        }
        return r
    }

    // MARK: - Python-avrundning

    /// Pythons round(x, decimaler): det exakta binära talet avrundat, lika till jämnt
    /// (som printf). METOD M50
    static func avrunda(_ x: Double, _ decimaler: Int) -> Double {
        guard x.isFinite else { return x }
        return Double(String(format: "%.\(decimaler)f", x)) ?? x
    }

    // MARK: - 3-vektorer och 3×3

    static func dot3(_ a: [Double], _ b: [Double]) -> Double {
        a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
    }

    static func norm3(_ a: [Double]) -> Double {
        dot3(a, a).squareRoot()
    }

    /// np.cross.
    static func kryss(_ a: [Double], _ b: [Double]) -> [Double] {
        [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
    }

    /// A·B för n×k och k×m.
    static func mul(_ a: [Double], _ b: [Double], _ n: Int, _ k: Int, _ m: Int) -> [Double] {
        var c = [Double](repeating: 0, count: n * m)
        for i in 0..<n {
            for j in 0..<m {
                var s = 0.0
                for l in 0..<k { s += a[i * k + l] * b[l * m + j] }
                c[i * m + j] = s
            }
        }
        return c
    }

    static func mul3(_ a: [Double], _ b: [Double]) -> [Double] {
        mul(a, b, 3, 3, 3)
    }

    /// A·v för 3×3.
    static func mulv3(_ a: [Double], _ v: [Double]) -> [Double] {
        [a[0] * v[0] + a[1] * v[1] + a[2] * v[2],
         a[3] * v[0] + a[4] * v[1] + a[5] * v[2],
         a[6] * v[0] + a[7] * v[1] + a[8] * v[2]]
    }

    static func transp(_ a: [Double], _ n: Int, _ m: Int) -> [Double] {
        var t = [Double](repeating: 0, count: n * m)
        for i in 0..<n {
            for j in 0..<m { t[j * n + i] = a[i * m + j] }
        }
        return t
    }

    static let enhet3: [Double] = [1, 0, 0, 0, 1, 0, 0, 0, 1]

    static func det3(_ a: [Double]) -> Double {
        a[0] * (a[4] * a[8] - a[5] * a[7]) - a[1] * (a[3] * a[8] - a[5] * a[6]) + a[2] * (a[3] * a[7] - a[4] * a[6])
    }

    /// Rodrigues: rotationen r (axel · vinkel i radianer). Som tre_d/kalibrering.rodrigues.
    static func rodrigues(_ r: [Double]) -> [Double] {
        let th = norm3(r)
        if th < 1e-12 { return enhet3 }
        let k = [r[0] / th, r[1] / th, r[2] / th]
        let kx: [Double] = [0, -k[2], k[1], k[2], 0, -k[0], -k[1], k[0], 0]
        let s = sin(th), c = 1 - cos(th)
        let kk = mul3(kx.map { c * $0 }, kx)                 // ((1 − cos θ)·K)·K, som numpys ordning
        var ut = enhet3
        for i in 0..<9 { ut[i] = (enhet3[i] + s * kx[i]) + kk[i] }
        return ut
    }

    /// Den skeva matrisen [t]×.
    static func skev(_ t: [Double]) -> [Double] {
        [0, -t[2], t[1], t[2], 0, -t[0], -t[1], t[0], 0]
    }

    // MARK: - Ekvationssystem

    struct Singular: Error {}

    /// Löser A·X = B (A n×n, B n×k, radvisa) med LU och radpivotering, som LAPACK:s gesv
    /// (pivoten = största |a| i kolumnen, den första vid lika). Kastar vid en nollpivot.
    static func los(_ a: [Double], _ b: [Double], _ n: Int, _ k: Int) throws -> [Double] {
        var a = a, x = b
        var perm = Array(0..<n)
        for j in 0..<n {
            var p = j
            var storst = abs(a[j * n + j])
            for i in (j + 1)..<max(j + 1, n) where abs(a[i * n + j]) > storst {
                storst = abs(a[i * n + j])
                p = i
            }
            if storst == 0 { throw Singular() }
            if p != j {
                for l in 0..<n { a.swapAt(j * n + l, p * n + l) }
                for l in 0..<k { x.swapAt(j * k + l, p * k + l) }
                perm.swapAt(j, p)
            }
            let inv = 1 / a[j * n + j]
            for i in (j + 1)..<max(j + 1, n) {
                let l = a[i * n + j] * inv
                a[i * n + j] = l
                if l != 0 {
                    for c in (j + 1)..<n { a[i * n + c] -= l * a[j * n + c] }
                }
            }
        }
        // L·y = P·b, sedan U·x = y.
        for j in 0..<n {
            for i in (j + 1)..<max(j + 1, n) {
                let l = a[i * n + j]
                for c in 0..<k { x[i * k + c] -= x[j * k + c] * l }
            }
        }
        for j in stride(from: n - 1, through: 0, by: -1) {
            let d = a[j * n + j]
            for c in 0..<k { x[j * k + c] /= d }
            for i in 0..<j {
                let u = a[i * n + j]
                for c in 0..<k { x[i * k + c] -= x[j * k + c] * u }
            }
        }
        return x
    }

    /// np.linalg.inv för n×n.
    static func inv(_ a: [Double], _ n: Int) throws -> [Double] {
        var e = [Double](repeating: 0, count: n * n)
        for i in 0..<n { e[i * n + i] = 1 }
        return try los(a, e, n, n)
    }

    // MARK: - Singulärvärden

    /// Ensidig Jacobi (Hestenes) på a (m × n, **kolumnvis**: kolumn j är a[j·m ..< j·m + m]).
    /// Kolumnerna roteras tills de är ortogonala; v (n × n, kolumnvis) samlar rotationerna.
    /// Efteråt är singulärvärdena kolumnernas längder. METOD M50
    static func jacobi(_ a: inout [Double], _ m: Int, _ n: Int, _ v: inout [Double]) {
        for i in 0..<(n * n) { v[i] = 0 }
        for i in 0..<n { v[i * n + i] = 1 }
        let tol = 1e-15 * Double(max(m, 4))
        for _ in 0..<60 {
            var roterat = false
            for p in 0..<(n - 1) {
                for q in (p + 1)..<n {
                    var alfa = 0.0, beta = 0.0, gamma = 0.0
                    let ip = p * m, iq = q * m
                    for i in 0..<m {
                        let x = a[ip + i], y = a[iq + i]
                        alfa += x * x
                        beta += y * y
                        gamma += x * y
                    }
                    if gamma == 0 || abs(gamma) <= tol * (alfa * beta).squareRoot() { continue }
                    roterat = true
                    let zeta = (beta - alfa) / (2 * gamma)
                    let t: Double
                    if abs(zeta) > 1e150 {
                        t = 1 / (2 * zeta)
                    } else {
                        t = (zeta >= 0 ? 1.0 : -1.0) / (abs(zeta) + (1 + zeta * zeta).squareRoot())
                    }
                    let c = 1 / (1 + t * t).squareRoot()
                    let s = c * t
                    for i in 0..<m {
                        let x = a[ip + i], y = a[iq + i]
                        a[ip + i] = c * x - s * y
                        a[iq + i] = s * x + c * y
                    }
                    let vp = p * n, vq = q * n
                    for i in 0..<n {
                        let x = v[vp + i], y = v[vq + i]
                        v[vp + i] = c * x - s * y
                        v[vq + i] = s * x + c * y
                    }
                }
            }
            if !roterat { break }
        }
    }

    /// Högra singulärvektorn till det minsta singulärvärdet (numpys Vh[-1]) för a
    /// (m × n, kolumnvis; skrivs över). Tecknet är godtyckligt, som i numpy.
    static func nollvektor(_ a: inout [Double], _ m: Int, _ n: Int) -> [Double] {
        var v = [Double](repeating: 0, count: n * n)
        let j = nollkolumn(&a, m, n, &v)
        return Array(v[(j * n)..<(j * n + n)])
    }

    /// Som `nollvektor`, utan allokering: v (n · n, kolumnvis) är arbetsytan, och svaret är
    /// kolumnen i v som är nollvektorn (v[j·n ..< j·n + n]).
    static func nollkolumn(_ a: inout [Double], _ m: Int, _ n: Int, _ v: inout [Double]) -> Int {
        jacobi(&a, m, n, &v)
        var minst = 0
        var minstS = Double.infinity
        for j in 0..<n {
            var s = 0.0
            for i in 0..<m { s += a[j * m + i] * a[j * m + i] }
            if s < minstS {
                minstS = s
                minst = j
            }
        }
        return minst
    }

    /// SVD av en 3×3 (radvis): U, singulärvärden (fallande) och V, båda radvisa med
    /// kolumnerna som singulärvektorer. U:s tredje kolumn är u₁ × u₂ (så det(U) = 1),
    /// eftersom den bara är bestämd upp till tecknet när σ₃ ≈ 0 (en essentiell matris).
    static func svd3(_ e: [Double]) -> (u: [Double], s: [Double], v: [Double]) {
        var a = transp(e, 3, 3)                         // kolumnvis
        var v = [Double](repeating: 0, count: 9)
        jacobi(&a, 3, 3, &v)
        var s = [0.0, 0.0, 0.0]
        for j in 0..<3 { s[j] = (a[j * 3] * a[j * 3] + a[j * 3 + 1] * a[j * 3 + 1] + a[j * 3 + 2] * a[j * 3 + 2]).squareRoot() }
        let ordning = [0, 1, 2].sorted { s[$0] > s[$1] || (s[$0] == s[$1] && $0 < $1) }
        var u = [Double](repeating: 0, count: 9), vut = [Double](repeating: 0, count: 9)
        var ss = [0.0, 0.0, 0.0]
        var kol: [[Double]] = []
        for (k, j) in ordning.enumerated() {
            ss[k] = s[j]
            for i in 0..<3 { vut[i * 3 + k] = v[j * 3 + i] }
            if k < 2 {
                let d = s[j] > 0 ? s[j] : 1
                kol.append([a[j * 3] / d, a[j * 3 + 1] / d, a[j * 3 + 2] / d])
            }
        }
        kol.append(kryss(kol[0], kol[1]))
        for k in 0..<3 {
            for i in 0..<3 { u[i * 3 + k] = kol[k][i] }
        }
        return (u, ss, vut)
    }
}
