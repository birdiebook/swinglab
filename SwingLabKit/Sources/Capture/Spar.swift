import Foundation
import Swing

/// Spåren i granskningen (PLAN S4f, BESLUT B70, METOD M60): en punkts bana genom hela
/// svingen som en tunn linje. Punkterna är kroppens (händerna, axlarna, höfterna, huvudet) ur
/// slagets leder, och klubbhuvudet ur S7b:s bana. Banan jämnas med mätningens utjämning (M3),
/// och en ruta där punkten saknas ger ett avbrott, aldrig en gissning. Mätningen rörs inte.
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

/// En namngiven punktserie i hela bildens pixlar (y nedåt) med rutornas tider: ritlagrets
/// indata (`SparLager` i appen), så att kroppens spår, klubbhuvudets bana (S7b) och senare 3D
/// (S6d) ritas av samma lager. `Punkt.saknad` = avbrott.
public struct SparSerie: Equatable, Sendable {
    public var id: String
    public var punkt: SparPunkt
    public var t: [Double]
    public var p: [Punkt]
    /// Rutan är interpolerad, inte spårad (S7b); tom = ingen är det.
    public var interpolerad: [Bool]

    public init(id: String, punkt: SparPunkt, t: [Double], p: [Punkt], interpolerad: [Bool] = []) {
        self.id = id
        self.punkt = punkt
        self.t = t
        self.p = p
        self.interpolerad = interpolerad
    }

    /// En sammanhängande del av banan att rita: punkterna, om den redan spelats upp och om den
    /// är interpolerad (S7b).
    public struct Del: Equatable, Sendable {
        public var punkter: [Punkt]
        public var spelad: Bool
        public var interpolerad: Bool
    }

    /// Delarna att rita vid tiden `nu` (s relativt klicket): banan bryts där punkten saknas och
    /// över en lucka längre än `Faser.maxLuckaS` mellan två rutor (M3), och vid `nu` i den del
    /// som är spelad (t ≤ nu) och den som är kvar; de två delarna delar punkten vid gränsen så
    /// att linjen är hel. En ensam punkt blir ingen del. METOD M60
    public func delar(nu: Double) -> [Del] {
        var ut: [Del] = []
        var cur: [Punkt] = []
        var curSpelad = true, curInterp = false
        var forraT = -Double.infinity
        func avsluta() {
            if cur.count >= 2 { ut.append(Del(punkter: cur, spelad: curSpelad, interpolerad: curInterp)) }
            cur = []
        }
        for k in t.indices {
            let q = p[k]
            guard q.hel else {
                avsluta()
                continue
            }
            let spelad = t[k] <= nu + 1e-9
            let interp = interpolerad.indices.contains(k) && interpolerad[k]
            if !cur.isEmpty && t[k] - forraT > Faser.maxLuckaS { avsluta() }
            if !cur.isEmpty && (spelad != curSpelad || interp != curInterp) {
                // Gränsen: den förra punkten börjar nästa del, så att linjen är hel.
                let sista = cur[cur.count - 1]
                avsluta()
                cur = [sista]
            }
            curSpelad = spelad
            curInterp = interp
            cur.append(q)
            forraT = t[k]
        }
        avsluta()
        return ut
    }

    /// Punkten vid den senaste rutan med t ≤ nu, om den finns i den rutan (spårets "nu").
    public func punkt(nu: Double) -> Punkt? {
        guard let k = t.lastIndex(where: { $0 <= nu + 1e-9 }), p[k].hel else { return nil }
        return p[k]
    }
}

public enum Spar {
    /// Spårets utjämning är mätningens (M3): gaussvikt med σ = 7,5 ms, utan att fylla luckor.
    /// METOD M60
    public static let sigmaS = Faser.sigmaS

    /// Kroppens spår ur slagets rutor (tidsordning), för punkterna i `val` (klubban ingår inte;
    /// den kommer ur S7b:s bana). En led räknas från konfidensen 0,3 (M1); händerna är
    /// handledernas mitt, där en saknad handled tar den andras plats (greppregeln, M1). Varje
    /// serie jämnas över tiden (M3). METOD M60
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
                let rad: [Punkt]
                if grupp.count == 2 {
                    let a = led(grupp[0]), b = led(grupp[1])
                    rad = zip(a, b).map { a, b in
                        switch (a.hel, b.hel) {
                        case (true, true): return Punkt((a.x + b.x) / 2, (a.y + b.y) / 2)
                        case (true, false): return a
                        case (false, true): return b
                        default: return .saknad
                        }
                    }
                } else {
                    rad = led(grupp[0])
                }
                let id = punkt.leder.count > 1 ? "\(punkt.rawValue)_\(n == 0 ? "v" : "h")" : punkt.rawValue
                ut.append(SparSerie(id: id, punkt: punkt, t: t, p: Faser.jamna(t, rad, sigma: sigmaS)))
            }
        }
        return ut
    }
}

extension ShotReview {
    /// Kroppens spår för granskningens rutor (S4f). METOD M60
    public func spar(_ val: [SparPunkt]) -> [SparSerie] { Spar.serier(frames, val: val) }
}
