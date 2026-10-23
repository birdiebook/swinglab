import Foundation

/// En pinhole-kamera: K (3×3), R (världen → kameran) och t, radvisa. Som tre_d/kamera.py.
public struct Kamera3D: Equatable, Sendable {
    public var k: [Double]
    public var r: [Double]
    public var t: [Double]

    public init(k: [Double], r: [Double], t: [Double]) {
        self.k = k
        self.r = r
        self.t = t
    }

    /// En världspunkt → pixlar (u, v).
    func projicera(_ x: Double, _ y: Double, _ z: Double) -> (Double, Double) {
        let xc = r[0] * x + r[1] * y + r[2] * z + t[0]
        let yc = r[3] * x + r[4] * y + r[5] * z + t[1]
        let zc = r[6] * x + r[7] * y + r[8] * z + t[2]
        let p0 = k[0] * xc + k[1] * yc + k[2] * zc
        let p1 = k[3] * xc + k[4] * yc + k[5] * zc
        let p2 = k[6] * xc + k[7] * yc + k[8] * zc
        return (p0 / p2, p1 / p2)
    }
}

/// Trianguleringen och synkens finjustering. Som tools/pc/tre_d/triangulering.py.
/// METOD MK4, MK5
enum Triangulering {
    /// Viktad DLT: uv[c] (m·j·2 pixlar) och vikt[c] (m·j) per kamera → m·j·3 punkter;
    /// NaN där färre än två kameror har vikt > 0. Varje kameras två rader vägs med vikten.
    static func triangulera(_ kameror: [Kamera3D], _ uv: [[Double]], _ vikt: [[Double]], _ antal: Int) -> [Double] {
        let c = kameror.count
        let kinv = kameror.map { (try? LA.inv($0.k, 3)) ?? [Double](repeating: .nan, count: 9) }
        let pn = kameror.map { [$0.r[0], $0.r[1], $0.r[2], $0.t[0], $0.r[3], $0.r[4], $0.r[5], $0.t[1],
                                $0.r[6], $0.r[7], $0.r[8], $0.t[2]] }
        var ut = [Double](repeating: .nan, count: antal * 3)
        let rader = 2 * c
        var a = [Double](repeating: 0, count: rader * 4)       // kolumnvis
        var v = [Double](repeating: 0, count: 16)
        for p in 0..<antal {
            var giltig = 0
            for i in 0..<a.count { a[i] = 0 }
            for k in 0..<c {
                let u = uv[k][p * 2], v = uv[k][p * 2 + 1]
                let ki = kinv[k]
                let x0 = ki[0] * u + ki[1] * v + ki[2]
                let x1 = ki[3] * u + ki[4] * v + ki[5]
                let x2 = ki[6] * u + ki[7] * v + ki[8]
                guard x0.isFinite && x1.isFinite && x2.isFinite && vikt[k][p] > 0 else { continue }
                giltig += 1
                let w = vikt[k][p]
                let q = pn[k]
                for kol in 0..<4 {
                    a[kol * rader + 2 * k] = w * (x0 * q[8 + kol] - q[kol])
                    a[kol * rader + 2 * k + 1] = w * (x1 * q[8 + kol] - q[4 + kol])
                }
            }
            guard giltig >= 2 else { continue }
            let j = LA.nollkolumn(&a, rader, 4, &v) * 4
            ut[p * 3] = v[j] / v[j + 3]
            ut[p * 3 + 1] = v[j + 1] / v[j + 3]
            ut[p * 3 + 2] = v[j + 2] / v[j + 3]
        }
        return ut
    }

    /// Pixelfelen mellan punkterna och observationerna, per kamera (antal tal var).
    static func aterprojektionsfel(_ kameror: [Kamera3D], _ p: [Double], _ uv: [[Double]], _ antal: Int) -> [[Double]] {
        kameror.enumerated().map { c, kam in
            (0..<antal).map { i in
                let (u, v) = kam.projicera(p[i * 3], p[i * 3 + 1], p[i * 3 + 2])
                let du = u - uv[c][i * 2], dv = v - uv[c][i * 2 + 1]
                return (du * du + dv * dv).squareRoot()
            }
        }
    }

    /// Parabeln genom toppen kring index i, som `_parabel_topp`.
    static func parabelTopp(_ x: [Double], _ y: [Double], _ i: Int) -> Double {
        if 0 < i && i < y.count - 1 {
            let y0 = y[i - 1], y1 = y[i], y2 = y[i + 1]
            let den = y0 - 2 * y1 + y2
            if den != 0 && den.isFinite {                       // en granne utan värde: toppen själv (M51)
                return x[i] + 0.5 * (y0 - y2) / den * (x[1] - x[0])
            }
        }
        return x[i]
    }

    /// Hur mycket B:s klocka går före A:s (s), vald som den förskjutning som ger minst
    /// återprojektionsfel för `leder` inom `fonster`; nil när inget går att mäta där
    /// (Python kastar ValueError). Som `synk_reprojektion`. METOD MK4
    static func synkReprojektion(_ kameror: [Kamera3D], _ a: Spar2D, _ b: Spar2D, _ leder: [Int],
                                 _ fonster: (Double, Double), _ sok: Double, _ steg: Double,
                                 _ halvbredd: Double) -> Double? {
        let tFin = LA.arange(fonster.0 - sok - 0.05, fonster.1 + sok + 0.05, steg)
        let j = leder.count
        let (ua, ka) = Utjamning.jamna(a.urval(leder), tFin, halvbredd)
        let (ub, kb) = Utjamning.jamna(b.urval(leder), tFin, halvbredd)
        var inne: [Int] = []
        var nr = 0
        for (i, t) in tFin.enumerated() where t >= fonster.0 && t <= fonster.1 {
            if nr % 4 == 0 { inne.append(i) }
            nr += 1
        }
        let grans = Int(sok / steg)
        let lags = Array(stride(from: -grans, to: grans + 1, by: 2))
        var kost: [Double] = []
        let antal = inne.count * j
        for lag in lags {
            var uva = [Double](repeating: .nan, count: antal * 2), uvb = uva
            var wa = [Double](repeating: 0, count: antal), wb = wa
            for (r, i) in inne.enumerated() {
                let ib = i + lag
                for l in 0..<j {
                    let p = r * j + l
                    uva[p * 2] = ua[(i * j + l) * 2]
                    uva[p * 2 + 1] = ua[(i * j + l) * 2 + 1]
                    wa[p] = ka[i * j + l]
                    if ib >= 0 && ib < tFin.count {
                        uvb[p * 2] = ub[(ib * j + l) * 2]
                        uvb[p * 2 + 1] = ub[(ib * j + l) * 2 + 1]
                        wb[p] = kb[ib * j + l]
                    }
                }
            }
            let p = triangulera(kameror, [uva, uvb], [wa, wb], antal)
            let e = aterprojektionsfel(kameror, p, [uva, uvb], antal)
            kost.append(LA.nanmedian(e[0] + e[1]))
        }
        var bast = -1
        for (i, k) in kost.enumerated() where !k.isNaN && (bast < 0 || k < kost[bast]) { bast = i }
        guard bast >= 0 else { return nil }
        return parabelTopp(lags.map { Double($0) * steg }, kost.map { -$0 }, bast)
    }
}
