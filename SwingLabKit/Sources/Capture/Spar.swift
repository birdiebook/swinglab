import Foundation
import Swing

/// Spåren i granskningen (PLAN S4f, BESLUT B70, METOD M60): en punkts bana genom hela
/// svingen som en tunn linje. Punkterna är kroppens (händerna, axlarna, höfterna, huvudet) ur
/// slagets leder, och klubbhuvudet ur S7b:s bana. Banan jämnas lätt för visningen (M60, ett
/// fönster som krymper symmetriskt vid en kant), och en ruta där punkten saknas ger ett
/// avbrott, aldrig en gissning. Mätningen rörs inte.
public enum SparPunkt: String, CaseIterable, Codable, Sendable {
    case hands, shoulders, hips, head, club

    /// Lederna som punkten är (index i `JointSeries.names`), en serie per post; händerna är
    /// handledernas mitt efter greppregeln (M1).
    var leder: [[Int]] {
        switch self {
        case .hands: return [[5, 6]]
        case .shoulders: return [[1], [2]]
        case .hips: return [[7], [8]]
        case .head: return [[0]]
        case .club: return []
        }
    }
}

/// En namngiven punktserie i hela bildens pixlar (y nedåt) med rutornas tider: datamodellen
/// för spåren, med delningen i delar (avbrott, spelat och kvar). Kroppens spår och
/// klubbhuvudets bana (S7b) ritas av appens `SparLager`; datamodellen och delningen återanvänds
/// av 3D (S6d), som ritar med en egen vy. `Punkt.saknad` = avbrott.
public struct SparSerie: Equatable, Sendable {
    public var id: String
    public var punkt: SparPunkt
    public var t: [Double]
    public var p: [Punkt]
    /// Rutan är interpolerad, inte spårad (S7b); tom = ingen är det.
    public var interpolerad: [Bool]
    /// Index där banan bryts utan att saknas: en ny del börjar där (greppregeln byter handled).
    public var brott: Set<Int>

    public init(id: String, punkt: SparPunkt, t: [Double], p: [Punkt], interpolerad: [Bool] = [],
                brott: Set<Int> = []) {
        self.id = id
        self.punkt = punkt
        self.t = t
        self.p = p
        self.interpolerad = interpolerad
        self.brott = brott
    }

    /// En sammanhängande del av banan att rita: punkterna, index för den första i serien, om
    /// den redan spelats upp och om den är interpolerad (S7b).
    public struct Del: Equatable, Sendable {
        public var punkter: [Punkt]
        public var start: Int
        public var spelad: Bool
        public var interpolerad: Bool

        /// Index för den sista punkten i serien.
        public var slut: Int { start + punkter.count - 1 }
    }

    /// Banans delar utan hänsyn till tiden som spelats: banan bryts där punkten saknas, över
    /// en lucka längre än `Faser.maxLuckaS` mellan två rutor (M3) och vid ett `brott`; mellan
    /// spårat och interpolerat delar två delar punkten vid gränsen så att linjen är hel. En
    /// ensam punkt blir ingen del. METOD M60
    public func delar() -> [Del] {
        var ut: [Del] = []
        var cur: [Punkt] = []
        var start = 0, curInterp = false
        var forraT = -Double.infinity
        func avsluta() {
            if cur.count >= 2 { ut.append(Del(punkter: cur, start: start, spelad: false, interpolerad: curInterp)) }
            cur = []
        }
        for k in t.indices {
            let q = p[k]
            guard q.hel else {
                avsluta()
                continue
            }
            let interp = interpolerad.indices.contains(k) && interpolerad[k]
            if !cur.isEmpty && (t[k] - forraT > Faser.maxLuckaS || brott.contains(k)) { avsluta() }
            if !cur.isEmpty && interp != curInterp {
                // Gränsen: den förra punkten börjar nästa del, så att linjen är hel.
                let sista = cur[cur.count - 1]
                avsluta()
                cur = [sista]
                start = k - 1
            }
            if cur.isEmpty { start = k }
            curInterp = interp
            cur.append(q)
            forraT = t[k]
        }
        avsluta()
        return ut
    }

    /// Den senaste rutan med t ≤ nu (binärsökning), nil före den första.
    public func grans(nu: Double) -> Int? {
        var lo = 0, hi = t.count
        while lo < hi {
            let m = (lo + hi) / 2
            if t[m] <= nu + 1e-9 { lo = m + 1 } else { hi = m }
        }
        return lo > 0 ? lo - 1 : nil
    }

    /// De spelade delarna av `delar` fram till och med ruta k.
    public static func spelade(_ delar: [Del], till k: Int?) -> [Del] {
        guard let k else { return [] }
        return delar.compactMap { d -> Del? in
            guard d.start <= k else { return nil }
            let n = min(d.punkter.count, k - d.start + 1)
            guard n >= 2 else { return nil }
            return Del(punkter: Array(d.punkter.prefix(n)), start: d.start, spelad: true, interpolerad: d.interpolerad)
        }
    }

    /// Delarna att rita vid tiden `nu` (s relativt klicket): de spelade (t ≤ nu) och resten;
    /// de två delar punkten vid gränsen. METOD M60
    public func delar(nu: Double) -> [Del] {
        let k = grans(nu: nu) ?? -1
        var ut: [Del] = []
        for d in delar() {
            if d.slut <= k {
                ut.append(Del(punkter: d.punkter, start: d.start, spelad: true, interpolerad: d.interpolerad))
            } else if d.start > k {
                ut.append(d)
            } else {
                let n = k - d.start + 1
                if n >= 2 {
                    ut.append(Del(punkter: Array(d.punkter.prefix(n)), start: d.start, spelad: true,
                                  interpolerad: d.interpolerad))
                }
                ut.append(Del(punkter: Array(d.punkter.suffix(from: n - 1)), start: k, spelad: false,
                              interpolerad: d.interpolerad))
            }
        }
        return ut
    }

    /// Punkten i den senaste rutan med t ≤ nu, nil när den saknas där (spårets "nu").
    public func punkt(nu: Double) -> Punkt? {
        guard let k = grans(nu: nu), p[k].hel else { return nil }
        return p[k]
    }
}

public enum Spar {
    /// Spårets utjämning: gaussvikt med σ = 7,5 ms som mätningen (M3), men fönstret krymper
    /// symmetriskt vid en kant. METOD M60
    public static let sigmaS = Faser.sigmaS

    /// Utjämningen för visningen (M60): varje ruta blir det gaussviktade medlet av rutorna inom
    /// h = min(3σ, avståndet i tid till delens första ruta, avståndet till dess sista), så att
    /// fönstret alltid är symmetriskt och en kant eller lucka inte drar punkten åt ett håll. En
    /// del slutar där punkten saknas, över en lucka längre än `Faser.maxLuckaS` och vid ett
    /// `brott`; delens ändpunkter blir som de är. Saknade förblir saknade. Mätningens
    /// `Faser.jamna` (M3) är orörd.
    public static func jamna(_ t: [Double], _ p: [Punkt], brott: Set<Int> = [], sigma: Double = sigmaS) -> [Punkt] {
        var ut = [Punkt](repeating: .saknad, count: p.count)
        var a = 0
        while a < p.count {
            guard p[a].hel else {
                a += 1
                continue
            }
            var b = a
            while b + 1 < p.count, p[b + 1].hel, t[b + 1] - t[b] <= Faser.maxLuckaS, !brott.contains(b + 1) { b += 1 }
            for i in a...b {
                let h = min(Faser.trunkera * sigma, t[i] - t[a], t[b] - t[i])
                var sx = 0.0, sy = 0.0, sw = 0.0
                var j = i
                while j > a, t[i] - t[j - 1] <= h + 1e-12 { j -= 1 }
                while j <= b, t[j] - t[i] <= h + 1e-12 {
                    let d = (t[j] - t[i]) / sigma
                    let w = exp(-0.5 * d * d)
                    sx += w * p[j].x
                    sy += w * p[j].y
                    sw += w
                    j += 1
                }
                ut[i] = Punkt(sx / sw, sy / sw)
            }
            a = b + 1
        }
        return ut
    }

    /// Kroppens spår ur slagets rutor (tidsordning), för punkterna i `val` (klubban ingår inte;
    /// den kommer ur S7b:s bana). En led räknas från konfidensen 0,3 (M1); händerna är
    /// handledernas mitt, där en saknad handled tar den andras plats (greppregeln, M1), och
    /// banan bryts där regeln byter handled (punkten hoppar en halv handledsbredd). METOD M60
    public static func serier(_ frames: [PoseFrame], val: [SparPunkt]) -> [SparSerie] {
        let t = frames.map(\.t)
        func led(_ i: Int) -> [Punkt] {
            frames.map { f -> Punkt in
                guard i < f.joints.count, let j = f.joints[i], j.c >= Sving.minKonfidens, j.x.isFinite, j.y.isFinite
                else { return .saknad }
                return Punkt(j.x, j.y)
            }
        }
        var ut: [SparSerie] = []
        for punkt in SparPunkt.allCases where val.contains(punkt) {
            for (n, grupp) in punkt.leder.enumerated() {
                var rad: [Punkt]
                var brott: Set<Int> = []
                if grupp.count == 2 {
                    let a = led(grupp[0]), b = led(grupp[1])
                    // Vilken regel som gav punkten: 0 båda, 1 bara den första, 2 bara den andra.
                    var lage = [Int](repeating: -1, count: a.count)
                    rad = []
                    for k in a.indices {
                        switch (a[k].hel, b[k].hel) {
                        case (true, true):
                            rad.append(Punkt((a[k].x + b[k].x) / 2, (a[k].y + b[k].y) / 2))
                            lage[k] = 0
                        case (true, false):
                            rad.append(a[k])
                            lage[k] = 1
                        case (false, true):
                            rad.append(b[k])
                            lage[k] = 2
                        default:
                            rad.append(.saknad)
                        }
                    }
                    var forra = -1
                    for k in lage.indices where lage[k] >= 0 {
                        if forra >= 0 && lage[k] != forra { brott.insert(k) }
                        forra = lage[k]
                    }
                } else {
                    rad = led(grupp[0])
                }
                let id = punkt.leder.count > 1 ? "\(punkt.rawValue)_\(n == 0 ? "v" : "h")" : punkt.rawValue
                ut.append(SparSerie(id: id, punkt: punkt, t: t, p: jamna(t, rad, brott: brott), brott: brott))
            }
        }
        return ut
    }
}

extension ShotReview {
    /// Kroppens spår för granskningens rutor (S4f). METOD M60
    public func spar(_ val: [SparPunkt]) -> [SparSerie] { Spar.serier(frames, val: val) }
}
