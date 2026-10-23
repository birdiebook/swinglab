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
    /// Starten finns men bär inte tempot (bakifrån, METOD M40).
    public let startOsaker: Bool
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

    /// Posen som starten bakifrån tas ur. METOD M40
    public static let poseLeder: [Led] = [.axelF, .axelB, .armbageF, .armbageB, .handledF, .handledB]
    /// Adressens fönster är 0,1 s långt … METOD M40
    public static let stillaS = 0.10
    /// … med minst 3 rutor per led. METOD M40
    public static let stillaRutor = 3
    /// Posen kräver minst fyra av de sex lederna. METOD M40
    public static let minLeder = 4
    /// Starten = posen har rört sig 3 % av vägen till toppen … METOD M40
    public static let poseAndel = 0.03
    /// … men minst 3 gånger posens skakning i adressen. METOD M40
    public static let brusK = 3.0
    /// Skakningen över 1,5 % av vägen = starten osäker. METOD M40
    public static let osakerAndel = 0.015

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

    /// Sista gången före toppen som händerna var inom 5 % av vägen från adressläget
    /// (händerna lägst). METOD M4
    static func startUrHanderna(_ t: [Double], _ g: [Punkt], topp: Double) -> Double? {
        var fore: [Int] = []
        for k in t.indices where g[k].hel && t[k] >= topp - maxBaksvingS && t[k] <= topp {
            fore.append(k)
        }
        let gt = vid(t, g, topp)
        guard !fore.isEmpty && gt.hel else { return nil }
        var kLag = fore[0]                                       // händerna lägst = adressläget
        for k in fore.dropFirst() where g[k].y > g[kLag].y {
            kLag = k
        }
        let r = g[kLag]
        let troskel = troskelAndel * (gt - r).langd
        let seq = fore.filter { t[$0] >= t[kLag] }
        let d = seq.map { (g[$0] - r).langd }
        guard let m = d.lastIndex(where: { $0 <= troskel }), m < seq.count - 1 else { return nil }
        let k0 = seq[m], k1 = seq[m + 1]
        let s = t[k0] + (troskel - d[m]) / (d[m + 1] - d[m]) * (t[k1] - t[k0])
        return topp - s >= minBaksvingS ? s : nil
    }

    /// Adressen bakifrån: det fönster om stillaS, med början mellan toppen −
    /// maxBaksvingS och toppen − minBaksvingS, där posen skakar minst (det första vid
    /// lika). Skakningen = medlet över lederna av rutornas kvadrerade avstånd till
    /// ledens medel i fönstret (px²). Ger första rutan och medlet och skakningen per
    /// led (i poseLeders ordning). METOD M40
    static func adressensFonster(_ t: [Double], _ pose: [[Punkt]], topp: Double)
        -> (k: Int, leder: [Led], medel: [Led: Punkt], skak: [Led: Double])? {
        var bast: (k: Int, leder: [Led], medel: [Led: Punkt], skak: [Led: Double], r: Double)? = nil
        for k in t.indices where t[k] >= topp - maxBaksvingS && t[k] <= topp - minBaksvingS {
            var sel: [Int] = []
            var i = k
            while i < t.count && t[i] <= t[k] + stillaS {
                sel.append(i)
                i += 1
            }
            var leder: [Led] = []
            var medel: [Led: Punkt] = [:]
            var skak: [Led: Double] = [:]
            for j in poseLeder {
                let p = pose[j.rawValue]
                let r = sel.filter { p[$0].hel }
                if r.count < stillaRutor { continue }
                var sx = 0.0, sy = 0.0
                for q in r {
                    sx += p[q].x
                    sy += p[q].y
                }
                let m = Punkt(sx / Double(r.count), sy / Double(r.count))
                var v = 0.0
                for q in r {
                    let dx = p[q].x - m.x, dy = p[q].y - m.y
                    v += dx * dx + dy * dy
                }
                leder.append(j)
                medel[j] = m
                skak[j] = v / Double(r.count)
            }
            if leder.count >= minLeder {
                var summa = 0.0
                for j in leder { summa += skak[j]! }
                let r = summa / Double(leder.count)
                if bast == nil || r < bast!.r {
                    bast = (k, leder, medel, skak, r)
                }
            }
        }
        guard let b = bast else { return nil }
        return (b.k, b.leder, b.medel, b.skak)
    }

    /// Baksvingens start bakifrån ur armarnas och axlarnas pose (indexerad med
    /// Led.rawValue), redan utjämnad: sista gången före toppen som posen var inom
    /// poseAndel av vägen från adressen till toppen (men minst brusK gånger
    /// skakningen i adressen), som medelavstånd över lederna. Starten är osäker när
    /// adressen skakar mer än osakerAndel av vägen, när rutorna kring den ligger mer än
    /// maxLuckaS isär (en led saknas över starten), och när klippet börjar efter toppen −
    /// maxBaksvingS och adressens fönster är klippets första ruta. Ger starten och om den
    /// är osäker, eller nil när posen inte räcker. METOD M40
    public static func startUrPosen(_ t: [Double], _ pose: [[Punkt]], topp: Double) -> (start: Double, osaker: Bool)? {
        guard let a = adressensFonster(t, pose, topp: topp) else { return nil }
        var leder: [Led] = []
        var toppen: [Led: Punkt] = [:]
        for j in a.leder {
            let p = vid(t, pose[j.rawValue], topp)
            if p.hel {
                leder.append(j)
                toppen[j] = p
            }
        }
        guard leder.count >= minLeder else { return nil }
        var skak = 0.0, vag = 0.0
        for j in leder {
            skak += a.skak[j]!
            vag += (toppen[j]! - a.medel[j]!).langd
        }
        let sigma = (skak / Double(leder.count)).squareRoot()
        vag /= Double(leder.count)
        let troskel = Swift.max(poseAndel * vag, brusK * sigma)
        var seq: [Int] = []
        var d: [Double] = []
        for k in t.indices where t[k] >= t[a.k] && t[k] <= topp && leder.allSatisfy({ pose[$0.rawValue][k].hel }) {
            var summa = 0.0
            for j in leder { summa += (pose[j.rawValue][k] - a.medel[j]!).langd }
            seq.append(k)
            d.append(summa / Double(leder.count))
        }
        guard let m = d.lastIndex(where: { $0 <= troskel }), m < seq.count - 1 else { return nil }
        let k0 = seq[m], k1 = seq[m + 1]
        let s = t[k0] + (troskel - d[m]) / (d[m + 1] - d[m]) * (t[k1] - t[k0])
        guard topp - s >= minBaksvingS else { return nil }
        let osaker = sigma > osakerAndel * vag
            || t[k1] - t[k0] > maxLuckaS
            || (t[0] > topp - maxBaksvingS && a.k == 0)
        return (s, osaker)
    }

    /// Toppen, starten, adressen och finishen ur händernas bana g, redan
    /// utjämnad. Med `pose` (lederna indexerade med Led.rawValue, utjämnade;
    /// bakifrån) tas starten ur armarnas och axlarnas pose i stället (METOD M40),
    /// annars ur händerna. METOD M4
    public static func hitta(_ t: [Double], _ g: [Punkt], tKlick: Double, pose: [[Punkt]]? = nil) throws -> Fastider {
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
        var osaker = false
        if let pose {
            if let p = startUrPosen(t, pose, topp: topp) {
                start = p.start
                osaker = p.osaker
            } else {                                                 // posen räcker inte: händerna, och bakifrån
                start = startUrHanderna(t, g, topp: topp)            // är en sådan start, eller ingen, osäker
                osaker = true
            }
        } else {
            start = startUrHanderna(t, g, topp: topp)
        }

        let s0 = start ?? (topp - toppAdressS)
        return Fastider(start: start, topp: topp, traff: tKlick,
                        adressFran: s0 + adress.fran, adressTill: s0 + adress.till,
                        finishFran: tKlick + finish.fran, finishTill: tKlick + finish.till, startOsaker: osaker)
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
