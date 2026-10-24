import Foundation
import Swing

/// Rutorna till klubbhuvudets spårning (PLAN S7b, BESLUT B71, METOD M61): appen läser
/// Y-planet (ljusheten) ur seriens fil som det är lagrat, och här blir det en upprätt
/// gråskalebild i lägre upplösning, i samma rutnät som lederna (pixelns mitt (i + 0,5) /
/// skala i hela den upprätta bilden). Bara Foundation, så att vridningen prövas på Linux.
public enum KlubbRutor {
    /// Den upprätta bildens kortaste sida i rutorna, px: en 1080 × 1920-film blir 320 × 569.
    /// METOD M61
    public static let kortSida = 320

    /// Rutans px per den upprätta bildens px (högst 1).
    public static func skala(uprightWidth w: Int, uprightHeight h: Int) -> Double {
        min(1.0, Double(kortSida) / Double(max(1, min(w, h))))
    }

    /// Den lagrade pixeln för den upprätta pixeln (u, v), för en lagrad bild W × H med
    /// EXIF-orienteringen (MS7): 6 = vriden medurs till upprätt, 8 moturs, 3 ett halvt varv.
    public static func lagrad(u: Int, v: Int, width W: Int, height H: Int, exif: UInt32) -> (x: Int, y: Int) {
        switch exif {
        case 6: return (v, H - 1 - u)
        case 8: return (W - 1 - v, u)
        case 3: return (W - 1 - u, H - 1 - v)
        default: return (u, v)
        }
    }

    /// Upprätt gråskala ur ett lagrat Y-plan (`radBytes` per rad), i `skala` av den upprätta
    /// storleken; varje pixel är den lagrade pixeln under pixelns mitt.
    public static func upratt(_ plan: UnsafeBufferPointer<UInt8>, radBytes: Int, width W: Int, height H: Int,
                              exif: UInt32, skala: Double) -> (bild: [UInt8], bredd: Int, hojd: Int) {
        let upp = Orientation.uprightSize(width: W, height: H, exif: exif)
        let w = max(1, Int(Double(upp.width) * skala)), h = max(1, Int(Double(upp.height) * skala))
        var ut = [UInt8](repeating: 0, count: w * h)
        for j in 0..<h {
            let v = min(upp.height - 1, Int((Double(j) + 0.5) / skala))
            for i in 0..<w {
                let u = min(upp.width - 1, Int((Double(i) + 0.5) / skala))
                let p = lagrad(u: u, v: v, width: W, height: H, exif: exif)
                let n = p.y * radBytes + p.x
                ut[j * w + i] = plan.indices.contains(n) ? plan[n] : 0
            }
        }
        return (ut, w, h)
    }

    /// Lederna i rutan som spårningen läser: hela bildens pixlar, nil under konfidensen 0,3 (M1).
    public static func leder(_ f: PoseFrame) -> [Punkt?] {
        (0..<JointSeries.names.count).map { i in
            guard i < f.joints.count, let j = f.joints[i], j.c >= Sving.minKonfidens, j.x.isFinite, j.y.isFinite
            else { return nil }
            return Punkt(j.x, j.y)
        }
    }

    /// Rutorna som spårningen behöver: från första ankaret till sista, med `marginal` rutor
    /// på var sida (rörelsen tar rutan två före och två efter). nil med färre än två ankare.
    public static func spann(_ frames: [PoseFrame], ankare: [KlubbMarkering], marginal: Int = 3) -> ClosedRange<Int>? {
        let a = KlubbBana.ankare(ankare)
        guard a.count >= 2, !frames.isEmpty, let f = a.first, let l = a.last else { return nil }
        func narmast(_ t: Double) -> Int {
            var k = 0
            for j in frames.indices where abs(frames[j].t - t) < abs(frames[k].t - t) { k = j }
            return k
        }
        return max(0, narmast(f.t) - marginal)...min(frames.count - 1, narmast(l.t) + marginal)
    }
}
