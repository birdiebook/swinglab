import Foundation

/// Svingen går inte att mäta.
public enum SvingFel: Error, Equatable {
    /// Händerna syns inte före träffen.
    case handernaSaknas
    /// Segmentet som ger skalan syns inte i adressen.
    case skalanSaknas
}

/// Svingens tider ur händernas bana. METOD M4
public struct Fastider: Equatable, Sendable {
    /// Baksvingens start (s), nil om den inte gick att hitta.
    public let start: Double?
    /// Händerna högst.
    public let topp: Double
    /// Klicket.
    public let traff: Double
    public let adressFran: Double
    public let adressTill: Double
    public let finishFran: Double
    public let finishTill: Double
}

public enum Fas: String, CaseIterable, Sendable {
    case adress, topp, traff, finish
}

/// Utjämningen och faserna. Rutorna kommer med ojämna steg, så allt räknas på
/// tiderna, aldrig på rutnumret. METOD M3 (utjämningen), METOD M4 (faserna).
public enum Faser {
    /// Gaussvikt över tiden (samma varians som Golf SG:s 25 ms). METOD M3
    public static let sigmaS = 0.0075
    /// Rutor längre bort än 3σ räknas inte. METOD M3
    public static let trunkera = 3.0
    /// Längre lucka mellan två rutor interpoleras inte över. METOD M3
    public static let maxLuckaS = 0.10

    /// Toppen söks högst så långt före klicket (som Golf SG) … METOD M4
    public static let sokForeS = 1.5
    /// … och minst så långt före. METOD M4
    public static let sokSlutS = 0.05
    /// Adressläget söks högst så långt före toppen. METOD M4
    public static let maxBaksvingS = 1.5
    /// Starten = händerna har rört sig 5 % av vägen till toppen. METOD M4
    public static let troskelAndel = 0.05
    /// Kortare baksving = starten är fel och saknas (som Golf SG). METOD M4
    public static let minBaksvingS = 0.5
    /// Adressen räknas från toppen − 1,2 s när starten saknas. METOD M4
    public static let toppAdressS = 1.2
    /// s kring baksvingens start. METOD M4
    public static let adress = (fran: -0.40, till: -0.10)
    /// s efter träffen. METOD M4
    public static let finish = (fran: 1.0, till: 1.2)

    /// Händerna sitter ihop på greppet: en saknad handled tar den andras plats.
    /// Saknas båda är händerna borta i rutan. METOD M1
    public static func greppRegel(_ leder: [[Punkt]]) -> [[Punkt]] {
        var ut = leder
        let f = leder[Led.handledF.rawValue], b = leder[Led.handledB.rawValue]
        for k in f.indices {
            if !f[k].hel && b[k].hel {
                ut[Led.handledF.rawValue][k] = b[k]
            } else if !b[k].hel && f[k].hel {
                ut[Led.handledB.rawValue][k] = f[k]
            }
        }
        return ut
    }

    /// Gaussvikt över tiden: varje ruta blir det viktade medlet av rutorna inom
    /// 3σ, med vikten exp(−½(Δt/σ)²). Saknade värden räknas inte, och en ruta där
    /// värdet saknas förblir saknad: utjämningen fyller inga luckor, så att
    /// luckans längd i vid() är den råa. x och y var för sig. METOD M3
    public static func jamna(_ t: [Double], _ p: [Punkt], sigma: Double = sigmaS) -> [Punkt] {
        let n = t.count
        let grans = trunkera * sigma
        var ut = [Punkt](repeating: .saknad, count: n)
        var lo = 0
        for i in 0..<n {
            while lo < n && t[i] - t[lo] > grans { lo += 1 }
            var sx = 0.0, wx = 0.0, sy = 0.0, wy = 0.0
            var j = lo
            while j < n && t[j] - t[i] <= grans {
                let d = (t[i] - t[j]) / sigma
                let w = exp(-0.5 * (d * d))
                if p[j].x.isFinite {
                    sx += w * p[j].x
                    wx += w
                }
                if p[j].y.isFinite {
                    sy += w * p[j].y
                    wy += w
                }
                j += 1
            }
            ut[i] = Punkt(p[i].x.isFinite && wx > 0 ? sx / wx : .nan,
                          p[i].y.isFinite && wy > 0 ? sy / wy : .nan)
        }
        return ut
    }

    /// Punkten i ögonblicket tc, linjärt mellan de två närmaste rutorna med
    /// värde. Saknad utanför serien och över en lucka längre än maxLuckaS (den
    /// råa luckan, eftersom jamna inte fyller). METOD M3
    public static func vid(_ t: [Double], _ p: [Punkt], _ tc: Double) -> Punkt {
        guard tc.isFinite else { return .saknad }
        var forra: Int? = nil
        for k in t.indices where p[k].hel {
            if t[k] == tc { return p[k] }
            if t[k] > tc {
                guard let lo = forra, t[k] - t[lo] <= maxLuckaS else { return .saknad }
                let f = (tc - t[lo]) / (t[k] - t[lo])
                return Punkt(p[lo].x + f * (p[k].x - p[lo].x), p[lo].y + f * (p[k].y - p[lo].y))
            }
            forra = k
        }
        return .saknad
    }

    /// Medlet av punkten över rutorna a ≤ t ≤ b som har värde.
    public static func medel(_ t: [Double], _ p: [Punkt], _ a: Double, _ b: Double) -> Punkt {
        var sx = 0.0, sy = 0.0, n = 0
        for k in t.indices where t[k] >= a && t[k] <= b && p[k].hel {
            sx += p[k].x
            sy += p[k].y
            n += 1
        }
        return n > 0 ? Punkt(sx / Double(n), sy / Double(n)) : .saknad
    }

    /// Minimum på parabeln genom tre punkter med ojämna steg (tiderna räknas
    /// från t1 för noggrannhetens skull). Faller tillbaka på t1. METOD M4
    public static func toppunkt(_ t0: Double, _ y0: Double, _ t1: Double, _ y1: Double,
                                _ t2: Double, _ y2: Double) -> Double {
        let u0 = t0 - t1, u2 = t2 - t1
        let d = u0 * (u0 - u2) * (-u2)
        if d == 0 { return t1 }
        let a = (u2 * (y1 - y0) + u0 * (y2 - y1)) / d
        let b = (u2 * u2 * (y0 - y1) + u0 * u0 * (y1 - y2)) / d
        if a <= 0 { return t1 }
        let u = -b / (2 * a)
        return t1 + min(max(u, u0), u2)
    }

    /// Toppen, starten, adressen och finishen ur händernas bana g, redan
    /// utjämnad. METOD M4
    public static func hitta(_ t: [Double], _ g: [Punkt], tKlick: Double) throws -> Fastider {
        let n = t.count
        var idx: [Int] = []
        for k in 0..<n where g[k].hel && t[k] >= tKlick - sokForeS && t[k] <= tKlick - sokSlutS {
            idx.append(k)
        }
        guard !idx.isEmpty else { throw SvingFel.handernaSaknas }
        var j = 0
        for m in 1..<idx.count where g[idx[m]].y < g[idx[j]].y {     // minst y = högst i bilden
            j = m
        }
        var topp = t[idx[j]]
        if j > 0 && j < idx.count - 1 {
            let a = idx[j - 1], b = idx[j], c = idx[j + 1]
            topp = toppunkt(t[a], g[a].y, t[b], g[b].y, t[c], g[c].y)
        }

        var start: Double? = nil
        var fore: [Int] = []
        for k in 0..<n where g[k].hel && t[k] >= topp - maxBaksvingS && t[k] <= topp {
            fore.append(k)
        }
        let gt = vid(t, g, topp)
        if !fore.isEmpty && gt.hel {
            var kLag = fore[0]                                       // händerna lägst = adressläget
            for k in fore.dropFirst() where g[k].y > g[kLag].y {
                kLag = k
            }
            let r = g[kLag]
            let troskel = troskelAndel * (gt - r).langd
            let seq = fore.filter { t[$0] >= t[kLag] }
            let d = seq.map { (g[$0] - r).langd }
            if let m = d.lastIndex(where: { $0 <= troskel }), m < seq.count - 1 {
                let k0 = seq[m], k1 = seq[m + 1]
                let s = t[k0] + (troskel - d[m]) / (d[m + 1] - d[m]) * (t[k1] - t[k0])
                if topp - s >= minBaksvingS {
                    start = s
                }
            }
        }

        let s0 = start ?? (topp - toppAdressS)
        return Fastider(start: start, topp: topp, traff: tKlick,
                        adressFran: s0 + adress.fran, adressTill: s0 + adress.till,
                        finishFran: tKlick + finish.fran, finishTill: tKlick + finish.till)
    }

    /// Punkten i en fas: medel över adressens och finishens fönster, värdet i
    /// ögonblicket vid toppen och träffen. METOD M4
    public static func lage(_ t: [Double], _ p: [Punkt], _ f: Fastider, _ fas: Fas) -> Punkt {
        switch fas {
        case .adress: return medel(t, p, f.adressFran, f.adressTill)
        case .finish: return medel(t, p, f.finishFran, f.finishTill)
        case .topp: return vid(t, p, f.topp)
        case .traff: return vid(t, p, f.traff)
        }
    }
}
