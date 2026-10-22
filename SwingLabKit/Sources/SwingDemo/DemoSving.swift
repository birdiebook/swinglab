import Foundation
import Swing

/// En påhittad sving med kända tal, för provets bilder (CLAUDE.md, Dataregeln:
/// inga riktiga leder). Samma figur som `tools/pc/generera.py` (figur_fo och
/// figur_dtl), utan brus och utan saknade rutor: en ledfigur i bildens plan i cm
/// (X mot målet eller bollen, Z uppåt), ritad med 4 px/cm.
public enum DemoSving {
    static let kPx = 4.0
    static let x0 = 540.0, y0 = 1750.0
    static let frekvens = 240.0
    static let kroppSen = 0.10
    /// Tiderna (s): baksvingens start, toppen, klicket och klippets slut.
    public struct Tider: Sendable {
        public let start: Double
        public let topp: Double
        public let klick: Double
        public let slut: Double

        public init(start: Double, topp: Double, klick: Double, slut: Double) {
            self.start = start
            self.topp = topp
            self.klick = klick
            self.slut = slut
        }

        /// Som generera.py: baksving 0,95 s och nedsving 0,30 s.
        public static let standard = Tider(start: 1.25, topp: 2.20, klick: 2.50, slut: 3.80)
    }

    static func smoothstep(_ u: Double) -> Double {
        let v = Swift.min(1, Swift.max(0, u))
        return v * v * (3 - 2 * v)
    }

    /// Värdet står still på varje platå (ta, tb, v) och glider mjukt mellan dem.
    static func profil(_ t: Double, _ platar: [(Double, Double, Double)]) -> Double {
        var v = platar[0].2
        for i in 0..<(platar.count - 1) {
            let (_, b0, v0) = platar[i], (a1, _, v1) = platar[i + 1]
            if t > b0 { v = v0 + (v1 - v0) * smoothstep((t - b0) / (a1 - b0)) }
        }
        return v
    }

    /// Kroppens fyra lägen: adress, topp (±0,06 s), träff (±0,04 s), finish.
    static func kropp(_ t: Double, _ v: (Double, Double, Double, Double), _ T: Tider) -> Double {
        let ts = T.start + kroppSen
        return profil(t, [(-.infinity, ts, v.0), (T.topp - 0.06, T.topp + 0.06, v.1), (T.klick - 0.04, T.klick + 0.04, v.2),
                          (T.klick + 0.8, .infinity, v.3)])
    }

    static func rad(_ g: Double) -> Double { g * .pi / 180 }

    /// Knäet mellan höften och fotleden, böjt `grader` framåt.
    static func kna(_ h: Punkt, _ f: Punkt, _ grader: Double) -> Punkt {
        let m = Punkt.mitt(h, f), d = f - h
        let l = d.langd
        var n = Punkt(-d.y / l, d.x / l)
        if n.x < 0 { n = Punkt(-n.x, -n.y) }
        let k = l / 2 * tan(rad(grader) / 2)
        return Punkt(m.x + n.x * k, m.y + n.y * k)
    }

    /// FO: bäckenets sway (cm) i adress, topp, träff och finish.
    static func figurFO(_ t: Double, sway: (Double, Double, Double, Double), langdCm: Double, _ T: Tider) -> [Punkt] {
        let za = Matt.fotledshojd * langdCm, ben = Matt.ben * langdCm, bal = Matt.bal * langdCm
        let hals = 0.12 * langdCm, ua = 0.186 * langdCm, fa = 0.146 * langdCm
        let lyft = kropp(t, (0, 1, 2, 5), T)
        let beta = rad(kropp(t, (6, 4, 25, 10), T)), alfa = rad(kropp(t, (2, 6, 8, 0), T)), gamma = rad(kropp(t, (8, 20, 30, 0), T))
        let phi = rad(profil(t, [(-.infinity, T.start + kroppSen, 5), (T.topp - 0.06, T.topp + 0.06, 15),
                                 (T.klick - 0.04, T.klick + 0.20, 20), (T.klick + 0.8, .infinity, 90)]))
        let psi = rad(profil(t, [(-.infinity, T.start, -14), (T.topp, T.topp, -130), (T.klick - 0.04, T.klick + 0.04, -6),
                                 (T.klick + 0.8, .infinity, 140)]))
        var L = [Punkt](repeating: Punkt(0, 0), count: 13)
        let P = Punkt(kropp(t, sway, T), za + ben + lyft)
        let hw = 16.0, sw = 20.0
        L[7] = Punkt(P.x + hw * cos(alfa), P.y + hw * sin(alfa))
        L[8] = Punkt(P.x - hw * cos(alfa), P.y - hw * sin(alfa))
        let C = Punkt(P.x - bal * sin(beta), P.y + bal * cos(beta))
        L[1] = Punkt(C.x + sw * cos(gamma), C.y + sw * sin(gamma))
        L[2] = Punkt(C.x - sw * cos(gamma), C.y - sw * sin(gamma))
        let b0 = rad(6)
        L[0] = Punkt(-(bal + hals) * sin(b0) + kropp(t, (0, -3, -2, 10), T),
                     za + ben + (bal + hals) * cos(b0) + kropp(t, (0, -1, -1, 2), T))
        L[11] = Punkt(24, za)
        L[12] = Punkt(-24, za)
        L[9] = Punkt((L[7].x + L[11].x) / 2 + 2, (L[7].y + L[11].y) / 2)
        L[10] = Punkt((L[8].x + L[12].x) / 2 - 2, (L[8].y + L[12].y) / 2)
        L[3] = Punkt(L[1].x + ua * sin(psi), L[1].y - ua * cos(psi))
        let under = Punkt(sin(psi - phi), -cos(psi - phi))
        L[5] = Punkt(L[3].x + fa * under.x, L[3].y + fa * under.y)
        L[6] = Punkt(L[5].x + 2 * under.x, L[5].y + 2 * under.y)
        L[4] = Punkt((L[2].x + L[6].x) / 2, (L[2].y + L[6].y) / 2 - 3)
        return L
    }

    /// DTL: bäckenets thrust (cm) och bröstets böjning (grader) i de fyra lägena.
    static func figurDTL(_ t: Double, thrust: (Double, Double, Double, Double),
                         bojning: (Double, Double, Double, Double), langdCm: Double, _ T: Tider) -> [Punkt] {
        let za = Matt.fotledshojd * langdCm, bal = Matt.bal * langdCm
        let hals = 0.12 * langdCm, ua = 0.186 * langdCm
        let px0 = -14.0, pz0 = za + 0.47 * langdCm
        let theta = rad(kropp(t, bojning, T)), eta = rad(kropp(t, (10, 60, 5, 40), T))
        var L = [Punkt](repeating: Punkt(0, 0), count: 13)
        let P = Punkt(px0 + kropp(t, thrust, T), pz0 + kropp(t, (0, 0.5, 3, 6), T))
        L[7] = Punkt(P.x + 1.5, P.y)
        L[8] = Punkt(P.x - 1.5, P.y)
        let C = Punkt(P.x + bal * sin(theta), P.y + bal * cos(theta))
        L[1] = Punkt(C.x + 1.5, C.y)
        L[2] = Punkt(C.x - 1.5, C.y)
        let t0 = rad(bojning.0)
        L[0] = Punkt(px0 + (bal + hals) * sin(t0) + kropp(t, (0, -1, 2, 8), T),
                     pz0 + (bal + hals) * cos(t0) + kropp(t, (0, -0.5, 1, 12), T))
        L[11] = Punkt(2, za)
        L[12] = Punkt(-2, za)
        L[9] = kna(L[7], L[11], 20)
        L[10] = kna(L[8], L[12], kropp(t, (22, 30, 25, 10), T))
        L[4] = Punkt(L[2].x - ua * sin(eta), L[2].y - ua * cos(eta))
        let u = profil(t, [(-.infinity, T.start, 0), (T.topp, T.topp, 1), (T.klick - 0.04, .infinity, 0)])
        let v = profil(t, [(-.infinity, T.klick + 0.04, 0), (T.klick + 0.8, .infinity, 1)])
        let utanfor = (t > T.topp && t < T.klick) ? 4.0 * sin(.pi * u) : 0
        let G = Punkt(px0 + 32 - 20 * u + utanfor + 15 * v, pz0 - 12 + 70 * u + 60 * v)
        L[5] = Punkt(G.x + 0.5, G.y + 1)
        L[6] = Punkt(G.x - 0.5, G.y - 1)
        L[3] = Punkt((L[1].x + L[5].x) / 2, (L[1].y + L[5].y) / 2)
        return L
    }

    /// En FO-sving där bäckenet ligger `sway` cm från adressen i topp, träff och finish.
    public static func fo(sway: (topp: Double, traff: Double, finish: Double), langdM: Double = 1.80,
                          tider: Tider = .standard) -> Sving {
        sving(.fo, langdM: langdM, tider: tider) {
            figurFO($0, sway: (0, sway.topp, sway.traff, sway.finish), langdCm: langdM * 100, tider)
        }
    }

    /// En DTL-sving med bäckenets thrust (cm) och bröstets böjning (grader).
    public static func dtl(thrust: (topp: Double, traff: Double, finish: Double),
                           bojning: (adress: Double, topp: Double, traff: Double, finish: Double) = (40, 38, 34, 10),
                           langdM: Double = 1.80, tider: Tider = .standard) -> Sving {
        sving(.dtl, langdM: langdM, tider: tider) {
            figurDTL($0, thrust: (0, thrust.topp, thrust.traff, thrust.finish),
                     bojning: (bojning.adress, bojning.topp, bojning.traff, bojning.finish), langdCm: langdM * 100, tider)
        }
    }

    static func sving(_ vy: Vy, langdM: Double, tider: Tider, figur: (Double) -> [Punkt]) -> Sving {
        let n = Int((tider.slut * frekvens).rounded())
        let t = (0...n).map { Double($0) / frekvens }
        var leder = [[Punkt]](repeating: [], count: 13)
        for tc in t {
            let L = figur(tc)
            for j in 0..<13 {
                leder[j].append(Punkt(x0 + L[j].x * kPx, y0 - L[j].y * kPx))
            }
        }
        return Sving(vy: vy, hand: .hoger, xTecken: 1, langdM: langdM, tKlick: tider.klick, t: t, leder: leder)
    }
}
