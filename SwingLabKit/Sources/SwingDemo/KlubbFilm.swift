import Foundation
import Swing

/// Den påhittade filmen med en ritad klubba längs en känd båge (PLAN S7b, METOD M61, BESLUT
/// B71), samma bytes som tools/pc/klubbfilm.py (summan per ruta prövas mot fixturen). Inga
/// riktiga svingar (CLAUDE.md, Dataregeln). Bilden 600 × 560 px, rutorna i halv upplösning,
/// 240 bilder/s från −1,0 till +0,45 s med var nionde ruta borta; kroppen ritas över
/// klubban, och ett mörkt fält uppe till höger döljer klubbhuvudet mot en mörk bakgrund.
public enum KlubbFilm {
    public static let bredd = 600, hojd = 560
    public static let skala = 0.5
    public static var rutBredd: Int { Int(Double(bredd) * skala) }
    public static var rutHojd: Int { Int(Double(hojd) * skala) }
    static let fps = 240.0, t0 = -1.0, t1 = 0.45, bort = 9
    static let psiTopp = 2.0, hTopp = 1.4, psiFin = 2.4, hFin = 1.0
    static let arm = 120.0
    /// Greppet → hoseln, px i bilden.
    public static let skaft = 150.0
    static let bakgrund = 150, mork = 50
    static let morktFalt = (x0: 330.0, y0: 0.0, x1: 600.0, y1: 110.0)
    static let skaftFarg = 95, huvudFarg = 60, kroppFarg = 110
    static let skaftR = 1.6, huvudR = 8.0
    static let ankare: [(String, Double)] = [("P1", -0.90), ("P2", -0.62), ("P3", -0.50), ("P4", -0.25),
                                             ("P5", -0.12), ("P6", -0.06), ("P7", 0.0), ("P8", 0.06),
                                             ("P9", 0.15), ("P10", 0.40)]
    static let ledBrus = 1.5, tryckBrus = 1.5
    /// Bakifrån: skaftets vågräta del i bild (som `klubbfilm.DTL_KORT`).
    static let dtlKort = 0.25

    /// Heltalshash (lowbias32) av pixel och ruta, som `klubbfilm.hash32`.
    public static func hash32(_ x: UInt32, _ y: UInt32, _ k: UInt32) -> UInt32 {
        var h = (x &* 0x9E37_79B1) ^ (y &* 0x85EB_CA77) ^ (k &* 0xC2B2_AE3D)
        h ^= h >> 16
        h = h &* 0x7FEB_352D
        h ^= h >> 15
        h = h &* 0x846C_A68B
        h ^= h >> 16
        return h
    }

    static func smooth(_ u: Double) -> Double { u * u * (3.0 - 2.0 * u) }

    static func vinklar(_ t: Double) -> (psi: Double, h: Double) {
        if t <= -0.80 { return (0.0, 0.0) }
        if t <= -0.25 {
            let s = smooth((t + 0.80) / 0.55)
            return (psiTopp * s, hTopp * s * s)
        }
        if t <= 0.0 {
            let u = (t + 0.25) / 0.25
            return (psiTopp * (1.0 - u * u), hTopp * (1.0 - u * u * u * u))
        }
        if t <= 0.40 {
            let v = t / 0.40
            let w = 2.0 * v - v * v
            return (-psiFin * w, -hFin * w)
        }
        return (-psiFin, -hFin)
    }

    /// Svingen vid tiden t i hela bildens pixlar: greppet, hoseln och de 13 lederna.
    public static func scen(_ t: Double, dtl: Bool = false) -> (grepp: Punkt, hosel: Punkt, leder: [Punkt]) {
        let (psi, h) = vinklar(t)
        let cx = 300.0 + 8.0 * sin(0.5 * psi), cy = 260.0
        let hx = 300.0 + 5.0 * sin(0.4 * psi), hy = 375.0
        let g = Punkt(cx + arm * sin(psi), cy + arm * cos(psi))
        let d = Punkt(sin(psi + h) * (dtl ? dtlKort : 1.0), cos(psi + h))
        let hosel = Punkt(g.x + skaft * d.x, g.y + skaft * d.y)
        let ws = 50.0 * cos(0.6 * psi)
        let wh = 35.0 * cos(0.35 * psi)
        let sy = 3.0 * sin(0.6 * psi)
        let axv = Punkt(cx + ws, cy + sy), axh = Punkt(cx - ws, cy - sy)
        let hov = Punkt(hx + wh, hy), hoh = Punkt(hx - wh, hy)
        let leder = [
            Punkt(cx + 4.0 * sin(0.3 * psi), cy - 55.0),
            axv, axh,
            Punkt((axv.x + g.x) / 2.0, (axv.y + g.y) / 2.0),
            Punkt((axh.x + g.x) / 2.0, (axh.y + g.y) / 2.0),
            Punkt(g.x + 4.0, g.y), Punkt(g.x - 4.0, g.y),
            hov, hoh,
            Punkt(hx + 30.0, 455.0), Punkt(hx - 30.0, 455.0),
            Punkt(345.0, 530.0), Punkt(255.0, 530.0),
        ]
        return (g, hosel, leder)
    }

    struct Streck {
        let a: Punkt, b: Punkt, r: Double
    }

    static func kropp(_ L: [Punkt]) -> [Streck] {
        let ma = Punkt((L[1].x + L[2].x) / 2.0, (L[1].y + L[2].y) / 2.0)
        let mh = Punkt((L[7].x + L[8].x) / 2.0, (L[7].y + L[8].y) / 2.0)
        let gr = Punkt((L[5].x + L[6].x) / 2.0, (L[5].y + L[6].y) / 2.0)
        return [Streck(a: ma, b: mh, r: 38.0), Streck(a: L[1], b: L[2], r: 14.0), Streck(a: L[7], b: L[8], r: 18.0),
                Streck(a: L[1], b: L[3], r: 9.0), Streck(a: L[3], b: L[5], r: 9.0), Streck(a: L[2], b: L[4], r: 9.0),
                Streck(a: L[4], b: L[6], r: 9.0), Streck(a: L[7], b: L[9], r: 13.0), Streck(a: L[9], b: L[11], r: 13.0),
                Streck(a: L[8], b: L[10], r: 13.0), Streck(a: L[10], b: L[12], r: 13.0),
                Streck(a: L[0], b: L[0], r: 24.0), Streck(a: gr, b: gr, r: 9.0)]
    }

    static func nara(_ px: Double, _ py: Double, _ s: Streck) -> Bool {
        let dx = s.b.x - s.a.x, dy = s.b.y - s.a.y
        let n2 = dx * dx + dy * dy
        var u = 0.0
        if n2 > 0.0 {
            u = ((px - s.a.x) * dx + (py - s.a.y) * dy) / n2
            u = min(max(u, 0.0), 1.0)
        }
        let ex = px - (s.a.x + u * dx)
        let ey = py - (s.a.y + u * dy)
        return ex * ex + ey * ey <= s.r * s.r
    }

    /// Rutornas nummer i 240-rutnätet och tid, utan var nionde.
    public static func tider() -> [(i: Int, t: Double)] {
        let n = Int(((t1 - t0) * fps).rounded()) + 1
        return (0..<n).filter { $0 % bort != 4 }.map { ($0, t0 + Double($0) / fps) }
    }

    /// Rutan i gråskala, rad för rad.
    public static func ruta(_ i: Int, _ t: Double, dtl: Bool = false) -> [UInt8] {
        let w = rutBredd, h = rutHojd
        let s = scen(t, dtl: dtl)
        let skaftet = Streck(a: s.grepp, b: s.hosel, r: skaftR)
        let huvudet = Streck(a: s.hosel, b: s.hosel, r: huvudR)
        let kroppen = kropp(s.leder)
        var ut = [UInt8](repeating: 0, count: w * h)
        for jj in 0..<h {
            let py = (Double(jj) + 0.5) / skala
            for ii in 0..<w {
                let px = (Double(ii) + 0.5) / skala
                var bas = bakgrund
                if px >= morktFalt.x0 && px < morktFalt.x1 && py >= morktFalt.y0 && py < morktFalt.y1 { bas = mork }
                if nara(px, py, skaftet) { bas = skaftFarg }
                if nara(px, py, huvudet) { bas = huvudFarg }
                if kroppen.contains(where: { nara(px, py, $0) }) { bas = kroppFarg }
                let hh = hash32(UInt32(ii), UInt32(jj), UInt32(i))
                let summa = Int(hh & 0xFF) + Int((hh >> 8) & 0xFF) + Int((hh >> 16) & 0xFF) + Int((hh >> 24) & 0xFF)
                let v = (bas * 20 + summa + 10 - 510) / 20
                ut[jj * w + ii] = UInt8(min(255, max(0, v)))
            }
        }
        return ut
    }

    /// ±amp/2 ur hashen, som `klubbfilm.brus`.
    static func brus(_ i: Int, _ n: Int, _ amp: Double) -> Double {
        (Double(hash32(UInt32(n), 7919, UInt32(i)) & 0xFFFF) / 65535.0 - 0.5) * amp
    }

    /// Hela filmen: rutorna (lederna med brus, i hela bildens pixlar), ankarna (trycken med
    /// brus) och sanningen (hoseln per ruta).
    public static func film(dtl: Bool = false) -> (rutor: [KlubbSpar.Ruta], ankare: [KlubbMarkering], sanning: [Punkt]) {
        var rutor: [KlubbSpar.Ruta] = [], sanning: [Punkt] = []
        for (i, t) in tider() {
            let s = scen(t, dtl: dtl)
            let leder = s.leder.enumerated().map { n, p -> Punkt? in
                Punkt(p.x + brus(i, 2 * n, 2 * ledBrus), p.y + brus(i, 2 * n + 1, 2 * ledBrus))
            }
            rutor.append(KlubbSpar.Ruta(t: t, bild: ruta(i, t, dtl: dtl), leder: leder))
            sanning.append(s.hosel)
        }
        let tr = rutor.map(\.t)
        var ank: [KlubbMarkering] = []
        for (nr, (pos, ta)) in ankare.enumerated() {
            var k = 0
            for j in 1..<tr.count where abs(tr[j] - ta) < abs(tr[k] - ta) { k = j }
            let s = scen(tr[k], dtl: dtl)
            ank.append(KlubbMarkering(
                position: pos, t: tr[k],
                grepp: KlubbPunkt(x: s.grepp.x + brus(nr, 101, 2 * tryckBrus), y: s.grepp.y + brus(nr, 102, 2 * tryckBrus)),
                hosel: KlubbPunkt(x: s.hosel.x + brus(nr, 103, 2 * tryckBrus), y: s.hosel.y + brus(nr, 104, 2 * tryckBrus))))
        }
        return (rutor, ank, sanning)
    }

    /// Rutans kontrollsumma: Σ (index + 1) · byte mod 2³², som `klubbfilm.summa`.
    public static func summa(_ r: [UInt8]) -> UInt32 {
        var s: UInt64 = 0
        for (n, b) in r.enumerated() { s &+= UInt64(n + 1) * UInt64(b) }
        return UInt32(truncatingIfNeeded: s)
    }
}
