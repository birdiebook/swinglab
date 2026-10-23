import Foundation

/// En svings mått: skalan, tiderna och måtten per namn. Ett mått som inte gick
/// att räkna (leden saknas i fasen) står inte med.
public struct SvingResultat: Sendable {
    public let vy: Vy
    public let hand: Hand
    public let cmPerPx: Double
    public let faser: Fastider
    /// P-positionerna (BESLUT B32). METOD M28
    public let positioner: Positioner
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
/// Positionerna P1–P10 och måtten vid P3, P5 och P10 som inte är en fas: METOD M28, M29.
/// Tilläggen mot Sportsbox i 2D (PLAN S1b): METOD M30–M37. Tilläggen bakifrån (PLAN S1c):
/// händernas djup och främre armen mot axellinjen vid toppen, METOD M38–M39.
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
    /// Kortare axellinje i bild vid toppen, cm = axlarna skymmer varandra. METOD M39
    public static let axlarMinCm = 15.0

    static let faser: [Fas] = [.adress, .topp, .traff, .finish]
    static let efter: [Fas] = [.topp, .traff, .finish]

    /// Måttens namn i varje vy (katalogen pekar bara på dessa).
    public static let namnDTL: [String] = {
        var n = faser.map { "brost_bojning_\($0.rawValue)" } + ["brost_bojning_tapp"]
        for m in ["backen_thrust", "backen_lyft", "huvud_mot_bollen", "huvud_lyft", "brost_thrust"] {
            n += efter.map { "\(m)_\($0.rawValue)" }
        }
        n += ["adress", "topp", "traff"].map { "bakre_kna_\($0)" }
        n += ["bakre_armbage_topp", "handbana", "tempo", "baksving_s", "nedsving_s"]
        for m in ["backen_bojning", "framre_kna"] {
            n += ["adress", "topp", "traff"].map { "\(m)_\($0)" }
        }
        for m in ["brost_lyft", "hand_lyft"] {
            n += efter.map { "\(m)_\($0.rawValue)" }
        }
        return n + ["genomsving_s", "hand_djup_topp", "framre_arm_plan_topp"]
    }()

    public static let namnFO: [String] = {
        var n = faser.map { "sidbojning_\($0.rawValue)" }
        for m in ["backen_sway", "brost_sway", "backen_lyft", "huvud_sway", "huvud_lyft"] {
            n += efter.map { "\(m)_\($0.rawValue)" }
        }
        n += ["adress", "traff"].map { "axellinje_lutning_\($0)" }
        n += ["adress", "topp", "traff"].map { "hoftlinje_lutning_\($0)" }
        n += ["sway_gap_traff", "hander_fore_adress_traff", "hander_fore_backen_traff", "backen_resa_framat",
              "framre_armbage_topp", "framre_armbage_efter_traff", "stans_bredd", "tempo", "baksving_s",
              "nedsving_s", "backen_sway_p3", "framre_armbage_p3", "backen_resa_p5", "huvud_backen_finish"]
        for m in ["brost_lyft", "hand_lyft", "framre_kna_sway", "bakre_kna_sway"] {
            n += efter.map { "\(m)_\($0.rawValue)" }
        }
        return n + ["genomsving_s", "handfart_max", "handfart_max_fore_traff_ms", "framre_arm_vinkelfart_max"]
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

    /// Vinkeln från axellinjen (främre axel → bakre) till främre armen (främre axel → den
    /// egna handleden) i bild, grader, + när armen pekar brantare uppåt än axellinjen (över
    /// axelplanet). Kryss- och skalärprodukten i bildens koordinater (y nedåt). METOD M39
    public static func armMotAxlar(axelF: Punkt, axelB: Punkt, hand: Punkt) -> Double {
        let s = axelB - axelF, a = hand - axelF
        return grader(atan2(s.x * a.y - s.y * a.x, s.x * a.x + s.y * a.y))
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
        // Armbågarna mäts mot den egna handleden, inte greppregelns ersatta. METOD M22
        let handF = Faser.jamna(t, s.led(.handledF))
        let handB = Faser.jamna(t, s.led(.handledB))
        func led(_ l: Led) -> [Punkt] { b[l.rawValue] }
        func mitt(_ x: Led, _ y: Led) -> [Punkt] { zip(led(x), led(y)).map { Punkt.mitt($0, $1) } }
        let P = mitt(.hoftF, .hoftB)
        let C = mitt(.axelF, .axelB)
        let A = mitt(.fotledF, .fotledB)
        let G = mitt(.handledF, .handledB)
        let N = led(.nasa)
        // Bakifrån tas starten ur armarnas och axlarnas pose. METOD M40
        let f = try Faser.hitta(t, G, tKlick: s.tKlick, pose: s.vy == .dtl ? b : nil)
        // Positionerna: armarna mot de egna handlederna, som armbågarna. METOD M28
        let pos = Positioner.hitta(t, f, framre: Positioner.armensHojd(axel: led(.axelF), handled: handF),
                                   bakre: Positioner.armensHojd(axel: led(.axelB), handled: handB))

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
            // Bäckenets böjning: bålens och lårets lutning, medlet. METOD M30
            for fz in [Fas.adress, .topp, .traff] {
                m["backen_bojning_\(fz.rawValue)"] = (vinkelFranLod(L(P, fz), L(C, fz))
                                                     + vinkelFranLod(L(led(.knaB), fz), L(led(.hoftB), fz))) / 2
            }
            for fz in [Fas.adress, .topp, .traff] {                                 // METOD M33
                m["framre_kna_\(fz.rawValue)"] = bojning(L(led(.hoftF), fz), L(led(.knaF), fz), L(led(.fotledF), fz))
            }
            // Händernas djup vid toppen: greppet längs X från adressen, + mot bollen. METOD M38
            m["hand_djup_topp"] = flyttX(G, .topp)
            // Främre armen mot axellinjen vid toppen, + över axelplanet; bara när axellinjen
            // är lång nog i bild (axlarna skymmer inte varandra). METOD M39
            let af = L(led(.axelF), .topp), ab = L(led(.axelB), .topp)
            if (ab - af).langd * cm >= axlarMinCm {
                m["framre_arm_plan_topp"] = armMotAxlar(axelF: af, axelB: ab, hand: L(handF, .topp))
            }
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
                                               L(handF, .topp))                                    // METOD M22
            let a0 = s.tKlick + chicken.fran, a1 = s.tKlick + chicken.till                        // METOD M23
            m["framre_armbage_efter_traff"] = bojning(Faser.medel(t, led(.axelF), a0, a1),
                                                      Faser.medel(t, led(.armbageF), a0, a1),
                                                      Faser.medel(t, handF, a0, a1))
            let fot = L(led(.fotledF), .adress) - L(led(.fotledB), .adress)                        // METOD M24
            let axl = L(led(.axelF), .adress) - L(led(.axelB), .adress)
            m["stans_bredd"] = axl.langd > 0 ? fot.langd / axl.langd : .nan
            // Måtten vid positionerna som inte är en fas. METOD M29
            if let p3 = pos.p3 {
                m["backen_sway_p3"] = (Faser.vid(t, P, p3).x - L(P, .adress).x) * cm
                m["framre_armbage_p3"] = bojning(Faser.vid(t, led(.axelF), p3), Faser.vid(t, led(.armbageF), p3),
                                                 Faser.vid(t, handF, p3))
            }
            if let p5 = pos.p5 {
                m["backen_resa_p5"] = (Faser.vid(t, P, p5).x - L(P, .topp).x) * cm
            }
            m["huvud_backen_finish"] = (L(N, .finish).x - L(P, .finish).x) * cm
            for fz in efter {                                                       // METOD M34
                m["framre_kna_sway_\(fz.rawValue)"] = flyttX(led(.knaF), fz)
                m["bakre_kna_sway_\(fz.rawValue)"] = flyttX(led(.knaB), fz)
            }
            // Farterna i nedsvingen, från toppen till träffen. METOD M35, METOD M37
            let nedsving = Farter.rutnat(f.topp, f.traff)
            let hand = Farter.handensFart(t, fram: s.led(.handledF), bak: s.led(.handledB), nedsving, bada: true)
            if let hf = Farter.maxpunkt(nedsving, hand.map { $0 * cm }) {
                m["handfart_max"] = hf.varde / 100.0                                // m/s
                m["handfart_max_fore_traff_ms"] = (f.traff - hf.tid) * 1000.0
            }
            if let af = Farter.maxpunkt(nedsving, Farter.vinkelfart(t, fran: s.led(.axelF), till: s.led(.handledF),
                                                                    nedsving)) {
                m["framre_arm_vinkelfart_max"] = af.varde
            }
        }

        for fz in efter {                                                           // METOD M31, METOD M32
            m["brost_lyft_\(fz.rawValue)"] = flyttUpp(C, fz)
            m["hand_lyft_\(fz.rawValue)"] = flyttUpp(G, fz)
        }
        let efterTraff = Farter.rutnat(f.traff + Farter.stegS, f.traff + Faser.finish.fran)   // METOD M36
        if let tf = Farter.finishTid(efterTraff, Farter.handensFart(t, fram: s.led(.handledF), bak: s.led(.handledB),
                                                                    efterTraff, bada: false)) {
            m["genomsving_s"] = tf - f.traff
        }

        if let start = f.start, !f.startOsaker {                                    // METOD M5, METOD M40
            let bak = f.topp - start, ned = f.traff - f.topp
            m["baksving_s"] = bak
            m["nedsving_s"] = ned
            if ned > 0 {
                m["tempo"] = bak / ned
            }
        }
        return SvingResultat(vy: s.vy, hand: s.hand, cmPerPx: cm, faser: f, positioner: pos, matt: m.filter { $0.value.isFinite })
    }
}
