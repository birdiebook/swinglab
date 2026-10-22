import Foundation

/// En svings mått: skalan, tiderna och måtten per namn. Ett mått som inte gick
/// att räkna (leden saknas i fasen) står inte med.
public struct SvingResultat: Sendable {
    public let vy: Vy
    public let hand: Hand
    public let cmPerPx: Double
    public let faser: Fastider
    public let matt: [String: Double]

    /// Det sessionen och katalogen behöver.
    public var svingMatt: SvingMatt { SvingMatt(vy: vy, matt: matt) }
}

/// Svingens mått per vy, i Sportsbox-form, portade från Golf SG
/// (`tools/handled_svingmatt.py`) och samma som `tools/pc/matt.py`.
///
/// En kamera ser två av tre axlar, så varje mått tas i den vy där det ligger i
/// bildens plan. X pekar mot målet (FO) eller mot bollen (DTL), Y nedåt.
/// Vridningen och X-factor ingår inte: de kräver två kameror (PLAN S6).
public enum Matt {
    // Drillis & Contini via Winter, andel av kroppslängden H. METOD M2
    public static let axelhojd = 0.818
    public static let hofthojd = 0.530
    public static let fotledshojd = 0.039
    /// Axelmitt–höftmitt, DTL. METOD M2
    public static let bal = axelhojd - hofthojd
    /// Höftmitt–fotledsmitt, FO. METOD M2
    public static let ben = hofthojd - fotledshojd

    /// s efter träffen. METOD M23
    public static let chicken = (fran: 0.05, till: 0.15)
    /// Andel av höjden från adress till topp. METOD M13
    public static let handbanaNivaer = [0.25, 0.50, 0.75]

    static let faser: [Fas] = [.adress, .topp, .traff, .finish]
    static let efter: [Fas] = [.topp, .traff, .finish]

    /// Måttens namn i varje vy (katalogen pekar bara på dessa).
    public static let namnDTL: [String] = {
        var n = faser.map { "brost_bojning_\($0.rawValue)" } + ["brost_bojning_tapp"]
        for m in ["backen_thrust", "backen_lyft", "huvud_mot_bollen", "huvud_lyft", "brost_thrust"] {
            n += efter.map { "\(m)_\($0.rawValue)" }
        }
        n += ["adress", "topp", "traff"].map { "bakre_kna_\($0)" }
        return n + ["bakre_armbage_topp", "handbana", "tempo", "baksving_s", "nedsving_s"]
    }()

    public static let namnFO: [String] = {
        var n = faser.map { "sidbojning_\($0.rawValue)" }
        for m in ["backen_sway", "brost_sway", "backen_lyft", "huvud_sway", "huvud_lyft"] {
            n += efter.map { "\(m)_\($0.rawValue)" }
        }
        n += ["adress", "traff"].map { "axellinje_lutning_\($0)" }
        n += ["adress", "topp", "traff"].map { "hoftlinje_lutning_\($0)" }
        return n + ["sway_gap_traff", "hander_fore_adress_traff", "hander_fore_backen_traff", "backen_resa_framat",
                    "framre_armbage_topp", "framre_armbage_efter_traff", "stans_bredd", "tempo", "baksving_s",
                    "nedsving_s"]
    }()

    public static func namn(_ vy: Vy) -> [String] { vy == .dtl ? namnDTL : namnFO }

    static func grader(_ radianer: Double) -> Double { radianer * (180.0 / Double.pi) }

    /// Linjen nedre→övre mot lodlinjen i bild, i grader, + när den övre punkten
    /// ligger åt +X. METOD M6, METOD M14
    public static func vinkelFranLod(_ nedre: Punkt, _ ovre: Punkt) -> Double {
        let d = ovre - nedre
        return grader(atan2(d.x, -d.y))
    }

    /// Ledens böjning i grader: 0 = rak, 90 = rät vinkel. METOD M11, METOD M22
    public static func bojning(_ a: Punkt, _ mitt: Punkt, _ c: Punkt) -> Double {
        let u = a - mitt, v = c - mitt
        let nu = u.langd, nv = v.langd
        guard nu > 0 && nv > 0 else { return .nan }
        let cosv = (u.x * v.x + u.y * v.y) / (nu * nv)
        return 180.0 - grader(acos(max(-1.0, min(1.0, cosv))))
    }

    /// Linjen bakre→främre mot vågrätt, + när den bakre sidan är lägre. METOD M17
    public static func linjensLutning(fram: Punkt, bak: Punkt) -> Double {
        let d = fram - bak
        return grader(atan2(-d.y, d.x))
    }

    /// Händernas X första gången de passerar höjden `niva` mellan a och b,
    /// linjärt mellan rutorna. Uppåt i bild = y minskar. METOD M13
    static func korsning(_ t: [Double], _ g: [Punkt], _ a: Double, _ b: Double, niva: Double, uppat: Bool) -> Double {
        var forra: Int? = nil
        for k in t.indices where g[k].hel && t[k] >= a && t[k] <= b {
            if let k0 = forra {
                let y0 = g[k0].y, y1 = g[k].y
                let passerar = uppat ? (y0 > niva && niva >= y1) : (y0 < niva && niva <= y1)
                if passerar {
                    let f = (niva - y0) / (y1 - y0)
                    return g[k0].x + f * (g[k].x - g[k0].x)
                }
            }
            forra = k
        }
        return .nan
    }

    /// Måtten för en sving. METOD M2–M24
    public static func mat(_ s: Sving) throws -> SvingResultat {
        let t = s.t
        let b = Faser.greppRegel(s.leder).map { Faser.jamna(t, $0) }
        func led(_ l: Led) -> [Punkt] { b[l.rawValue] }
        func mitt(_ x: Led, _ y: Led) -> [Punkt] { zip(led(x), led(y)).map { Punkt.mitt($0, $1) } }
        let P = mitt(.hoftF, .hoftB)
        let C = mitt(.axelF, .axelB)
        let A = mitt(.fotledF, .fotledB)
        let G = mitt(.handledF, .handledB)
        let N = led(.nasa)
        let f = try Faser.hitta(t, G, tKlick: s.tKlick)

        func L(_ p: [Punkt], _ fas: Fas) -> Punkt { Faser.lage(t, p, f, fas) }

        // Skalan: segmentet som ligger i bildens plan i adressen. METOD M2
        let seg: Punkt
        let kvot: Double
        if s.vy == .dtl {
            seg = Faser.medel(t, zip(C, P).map { $0 - $1 }, f.adressFran, f.adressTill)
            kvot = bal
        } else {
            seg = Faser.medel(t, zip(A, P).map { $0 - $1 }, f.adressFran, f.adressTill)
            kvot = ben
        }
        let px = seg.langd
        guard px > 0 else { throw SvingFel.skalanSaknas }       // NaN är inte > 0
        let cm = kvot * s.langdM * 100.0 / px

        /// Förflyttningen från adressen i cm; y vänds så att + är uppåt.
        func flyttX(_ p: [Punkt], _ fas: Fas) -> Double { (L(p, fas).x - L(p, .adress).x) * cm }
        func flyttUpp(_ p: [Punkt], _ fas: Fas) -> Double { -1.0 * (L(p, fas).y - L(p, .adress).y) * cm }

        var m: [String: Double] = [:]
        switch s.vy {
        case .dtl:
            for fz in faser {                                                       // METOD M6
                m["brost_bojning_\(fz.rawValue)"] = vinkelFranLod(L(P, fz), L(C, fz))
            }
            m["brost_bojning_tapp"] = m["brost_bojning_adress"]! - m["brost_bojning_traff"]!
            for fz in efter {
                m["backen_thrust_\(fz.rawValue)"] = flyttX(P, fz)                    // METOD M7
                m["backen_lyft_\(fz.rawValue)"] = flyttUpp(P, fz)                    // METOD M8
                m["huvud_mot_bollen_\(fz.rawValue)"] = flyttX(N, fz)                 // METOD M9
                m["huvud_lyft_\(fz.rawValue)"] = flyttUpp(N, fz)                     // METOD M8
                m["brost_thrust_\(fz.rawValue)"] = flyttX(C, fz)                     // METOD M10
            }
            for fz in [Fas.adress, .topp, .traff] {                                 // METOD M11
                m["bakre_kna_\(fz.rawValue)"] = bojning(L(led(.hoftB), fz), L(led(.knaB), fz), L(led(.fotledB), fz))
            }
            // Bakre överarmen mot lodlinjen nedåt, + bort från bollen. METOD M12
            let d = L(led(.armbageB), .topp) - L(led(.axelB), .topp)
            m["bakre_armbage_topp"] = grader(atan2(-d.x, d.y))
            // Handens bana: nedsvingen mot baksvingen på samma höjd. METOD M13
            let yAdr = L(G, .adress).y, yTopp = L(G, .topp).y
            let b0 = f.start ?? f.adressTill
            var skillnad: [Double] = []
            for andel in handbanaNivaer {
                let niva = yAdr + andel * (yTopp - yAdr)
                let xb = korsning(t, G, b0, f.topp, niva: niva, uppat: true)
                let xn = korsning(t, G, f.topp, f.traff, niva: niva, uppat: false)
                skillnad.append(xn - xb)
            }
            m["handbana"] = skillnad.reduce(0, +) / Double(skillnad.count) * cm
        case .fo:
            for fz in faser {                                                       // METOD M14
                m["sidbojning_\(fz.rawValue)"] = -vinkelFranLod(L(P, fz), L(C, fz))
            }
            for fz in efter {
                m["backen_sway_\(fz.rawValue)"] = flyttX(P, fz)                      // METOD M15
                m["brost_sway_\(fz.rawValue)"] = flyttX(C, fz)                       // METOD M16
                m["backen_lyft_\(fz.rawValue)"] = flyttUpp(P, fz)                    // METOD M8
                m["huvud_sway_\(fz.rawValue)"] = flyttX(N, fz)                       // METOD M9
                m["huvud_lyft_\(fz.rawValue)"] = flyttUpp(N, fz)                     // METOD M8
            }
            for fz in [Fas.adress, .traff] {                                        // METOD M17
                m["axellinje_lutning_\(fz.rawValue)"] = linjensLutning(fram: L(led(.axelF), fz), bak: L(led(.axelB), fz))
            }
            for fz in [Fas.adress, .topp, .traff] {                                 // METOD M18
                m["hoftlinje_lutning_\(fz.rawValue)"] = linjensLutning(fram: L(led(.hoftF), fz), bak: L(led(.hoftB), fz))
            }
            m["sway_gap_traff"] = m["backen_sway_traff"]! - m["brost_sway_traff"]!                 // METOD M19
            m["hander_fore_adress_traff"] = flyttX(G, .traff)                                       // METOD M20
            m["hander_fore_backen_traff"] = (L(G, .traff).x - L(P, .traff).x) * cm
            m["backen_resa_framat"] = m["backen_sway_traff"]! - m["backen_sway_topp"]!             // METOD M21
            m["framre_armbage_topp"] = bojning(L(led(.axelF), .topp), L(led(.armbageF), .topp),
                                               L(led(.handledF), .topp))                           // METOD M22
            let a0 = s.tKlick + chicken.fran, a1 = s.tKlick + chicken.till                        // METOD M23
            m["framre_armbage_efter_traff"] = bojning(Faser.medel(t, led(.axelF), a0, a1),
                                                      Faser.medel(t, led(.armbageF), a0, a1),
                                                      Faser.medel(t, led(.handledF), a0, a1))
            let fot = L(led(.fotledF), .adress) - L(led(.fotledB), .adress)                        // METOD M24
            let axl = L(led(.axelF), .adress) - L(led(.axelB), .adress)
            m["stans_bredd"] = axl.langd > 0 ? fot.langd / axl.langd : .nan
        }

        if let start = f.start {                                                    // METOD M5
            let bak = f.topp - start, ned = f.traff - f.topp
            m["baksving_s"] = bak
            m["nedsving_s"] = ned
            if ned > 0 {
                m["tempo"] = bak / ned
            }
        }
        return SvingResultat(vy: s.vy, hand: s.hand, cmPerPx: cm, faser: f, matt: m.filter { $0.value.isFinite })
    }
}
