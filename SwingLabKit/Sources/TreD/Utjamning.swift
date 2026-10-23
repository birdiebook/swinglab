import Foundation

/// Ett 2D-spår: n rutor × j leder, på rutornas egna tider (s). uv är n·j·2 tal (x, y i
/// pixlar, NaN = saknad), k konfidensen (n·j, 0 = saknad).
struct Spar2D {
    var t: [Double]
    var uv: [Double]
    var k: [Double]
    var j: Int

    var n: Int { t.count }

    /// Samma spår med bara lederna i `leder`.
    func urval(_ leder: [Int]) -> Spar2D {
        var uv2 = [Double](repeating: .nan, count: n * leder.count * 2)
        var k2 = [Double](repeating: 0, count: n * leder.count)
        for i in 0..<n {
            for (a, l) in leder.enumerated() {
                uv2[(i * leder.count + a) * 2] = uv[(i * j + l) * 2]
                uv2[(i * leder.count + a) * 2 + 1] = uv[(i * j + l) * 2 + 1]
                k2[i * leder.count + a] = k[i * j + l]
            }
        }
        return Spar2D(t: t, uv: uv2, k: k2, j: leder.count)
    }

    /// Samma spår med tiderna flyttade: t − skift.
    func flyttat(_ skift: Double) -> Spar2D {
        Spar2D(t: t.map { $0 - skift }, uv: uv, k: k, j: j)
    }
}

/// Utjämningen: lokal andragradsregression med trikubisk kärna, viktad med
/// konfidensen, och två robusta varv (LOESS, Cleveland 1979). Rad för rad som
/// tools/pc/tre_d/triangulering.py. METOD MK5
enum Utjamning {
    /// Kärnans vikter från t_in till t_ut, bara inom ±h (bandmatris), som `_Band`.
    struct Band {
        let m: Int
        let b: Int
        var idx: [Int]
        var d: [Double]
        var kv: [Double]
        /// d², d³ och d⁴ per bandets plats, en gång per band (inte per led).
        var d2: [Double]
        var d3: [Double]
        var d4: [Double]

        init(_ tIn: [Double], _ tUt: [Double], _ h: Double) {
            m = tUt.count
            var lo = [Int](repeating: 0, count: m), hi = [Int](repeating: 0, count: m)
            var bredd = 1
            for i in 0..<m {
                lo[i] = LA.vanster(tIn, tUt[i] - h)
                hi[i] = LA.hoger(tIn, tUt[i] + h)
                bredd = max(bredd, hi[i] - lo[i])
            }
            b = bredd
            idx = [Int](repeating: 0, count: m * bredd)
            d = [Double](repeating: 0, count: m * bredd)
            kv = [Double](repeating: 0, count: m * bredd)
            d2 = kv
            d3 = kv
            d4 = kv
            let sista = tIn.count - 1
            for i in 0..<m {
                for k in 0..<bredd {
                    let r = lo[i] + k
                    let e = i * bredd + k
                    idx[e] = min(r, sista)
                    if r < hi[i] {
                        d[e] = (tIn[idx[e]] - tUt[i]) / h
                        kv[e] = Utjamning.trikub(d[e])
                    }
                    d2[e] = d[e] * d[e]
                    d3[e] = pow(d[e], 3)
                    d4[e] = pow(d[e], 4)
                }
            }
        }
    }

    static func trikub(_ d: Double) -> Double {
        let a = max(1 - pow(abs(d), 3), 0)
        return pow(a, 3)
    }

    /// Kärnviktad lokal andragradsregression för alla leder: y (n·j·2), w (n·j) →
    /// (m·j·2); NaN där färre än tre punkter bär. Som `_lokal_kvadrat`.
    static func lokalKvadrat(_ band: Band, _ y: [Double], _ w: [Double], _ j: Int) -> [Double] {
        var ut = [Double](repeating: .nan, count: band.m * j * 2)
        var a = [Double](repeating: 0, count: 9)
        var bv = [Double](repeating: 0, count: 6)
        for m in 0..<band.m {
            for l in 0..<j {
                var s0 = 0.0, s1 = 0.0, s2 = 0.0, s3 = 0.0, s4 = 0.0
                var b0x = 0.0, b0y = 0.0, b1x = 0.0, b1y = 0.0, b2x = 0.0, b2y = 0.0
                var bar = 0
                for k in 0..<band.b {
                    let e = m * band.b + k
                    let i = band.idx[e]
                    let yx = y[(i * j + l) * 2], yy = y[(i * j + l) * 2 + 1]
                    let ok = yx.isFinite && yy.isFinite
                    let wv = band.kv[e] * w[i * j + l] * (ok ? 1.0 : 0.0)
                    if wv > 0 { bar += 1 }
                    let d = band.d[e], d2 = band.d2[e], d3 = band.d3[e], d4 = band.d4[e]
                    s0 += wv
                    s1 += wv * d
                    s2 += wv * d2
                    s3 += wv * d3
                    s4 += wv * d4
                    let gx = ok ? yx : 0.0, gy = ok ? yy : 0.0
                    b0x += wv * gx
                    b0y += wv * gy
                    let w1 = wv * d, w2 = wv * d2
                    b1x += w1 * gx
                    b1y += w1 * gy
                    b2x += w2 * gx
                    b2y += w2 * gy
                }
                guard bar >= 3 else { continue }
                let reg = 1e-9 * max(s0, 1e-12)
                a[0] = s0 + reg; a[1] = s1; a[2] = s2
                a[3] = s1; a[4] = s2 + reg; a[5] = s3
                a[6] = s2; a[7] = s3; a[8] = s4 + reg
                bv[0] = b0x; bv[1] = b0y; bv[2] = b1x; bv[3] = b1y; bv[4] = b2x; bv[5] = b2y
                guard let x = try? LA.los(a, bv, 3, 2) else { continue }
                ut[(m * j + l) * 2] = x[0]
                ut[(m * j + l) * 2 + 1] = x[1]
            }
        }
        return ut
    }

    /// De robusta vikterna (bisquare på residualerna, skala = MAD med golv 2 px), två
    /// varv: (w0, w). Som `robusta_vikter`. METOD MK5
    static func robustaVikter(_ s: Spar2D, _ h: Double) -> (w0: [Double], w: [Double]) {
        let n = s.n, j = s.j
        var w0 = [Double](repeating: 0, count: n * j)
        for i in 0..<(n * j) where s.uv[i * 2].isFinite && s.uv[i * 2 + 1].isFinite {
            w0[i] = s.k[i]
        }
        var w = w0
        let band = Band(s.t, s.t, h)
        var r = [Double](repeating: .nan, count: n * j)
        for _ in 0..<2 {
            let f = lokalKvadrat(band, s.uv, w, j)
            for i in 0..<(n * j) {
                let dx = s.uv[i * 2] - f[i * 2], dy = s.uv[i * 2 + 1] - f[i * 2 + 1]
                r[i] = (dx * dx + dy * dy).squareRoot()
            }
            for l in 0..<j {
                var kol: [Double] = []
                kol.reserveCapacity(n)
                for i in 0..<n where w0[i * j + l] > 0 { kol.append(r[i * j + l]) }
                var mad = LA.nanmedian(kol)
                if !mad.isFinite { mad = 2.0 }
                let skala = 6 * max(mad, 2.0)
                for i in 0..<n {
                    let u = r[i * j + l] / skala
                    let f: Double
                    if u.isFinite {
                        let c = max(1 - u * u, 0)
                        f = c * c
                    } else {
                        f = 1.0
                    }
                    w[i * j + l] = w0[i * j + l] * f
                }
            }
        }
        return (w0, w)
    }

    /// Jämnar ut och samplar om spåret på tUt: (uv m·j·2, konfidens m·j). Konfidensen är
    /// kärnviktat medel av indata; NaN och 0 där underlaget är för tunt. Som `jamna`.
    static func jamna(_ s: Spar2D, _ tUt: [Double], _ h: Double, robust: Bool = true,
                      vikter: (w0: [Double], w: [Double])? = nil) -> (uv: [Double], k: [Double]) {
        let j = s.j
        let w0: [Double], w: [Double]
        if robust {
            let par = vikter ?? robustaVikter(s, h)
            w0 = par.w0
            w = par.w
        } else {
            var v = [Double](repeating: 0, count: s.n * j)
            for i in 0..<(s.n * j) where s.uv[i * 2].isFinite && s.uv[i * 2 + 1].isFinite { v[i] = s.k[i] }
            w0 = v
            w = v
        }
        let band = Band(s.t, tUt, h)
        var ut = lokalKvadrat(band, s.uv, w, j)
        if robust {
            var lucka = false
            for i in 0..<(band.m * j) where !(ut[i * 2].isFinite && ut[i * 2 + 1].isFinite) {
                lucka = true
                break
            }
            if lucka {
                let reserv = lokalKvadrat(band, s.uv, w0, j)
                for i in 0..<(band.m * j) where !(ut[i * 2].isFinite && ut[i * 2 + 1].isFinite) {
                    ut[i * 2] = reserv[i * 2]
                    ut[i * 2 + 1] = reserv[i * 2 + 1]
                }
            }
        }
        var kut = [Double](repeating: 0, count: band.m * j)
        band.kv.withUnsafeBufferPointer { kb in
            for m in 0..<band.m {
                let ksum = LA.parvis(kb, m * band.b, band.b)
                for l in 0..<j {
                    guard ut[(m * j + l) * 2].isFinite && ut[(m * j + l) * 2 + 1].isFinite, ksum > 0 else { continue }
                    var summa = 0.0
                    for k in 0..<band.b {
                        let e = m * band.b + k
                        summa += band.kv[e] * w[band.idx[e] * j + l]
                    }
                    kut[m * j + l] = summa / max(ksum, 1e-12)
                }
            }
        }
        return (ut, kut)
    }
}
