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
    /// Rensningen, toppens platå och varför mått saknas (METOD M53, M4, M52, M5).
    public let kvalitet: Kvalitet

    /// Det sessionen och katalogen behöver.
    public var svingMatt: SvingMatt { SvingMatt(vy: vy, matt: matt) }
}

/// Vad mätningen vet om sin egen kvalitet för en sving (PLAN S3b lager 1).
public struct Kvalitet: Equatable, Sendable {
    /// Vad rensningen gjorde. METOD M53
    public let rensning: Rensning
    /// Hur länge händerna stod inom 2 % av vägen från sin högsta punkt, s; nil när vägen
    /// inte går att räkna. Mäts och visas, ingen spärr än. METOD M4
    public let toppPlataS: Double?
    /// Mått som saknas → orsaken: "led_saknas", "segment_kort", "segment_langt" (METOD M52),
    /// "start_saknas", "start_osaker" (tempot och baksvingen, METOD M5).
    public let saknas: [String: String]
    /// Mått som visas men är osäkra → orsakerna, sorterade: "topp_osaker", "luckor_kring_fasen",
    /// "traff_osaker", "filterkanslig", "fas_orimlig" (METOD M54–M59). Bara mått som finns.
    public let varningar: [String: [String]]
    /// Den andra signalens topp minus toppen, s; nil när den inte går att räkna. METOD M55
    public let toppAndraS: Double?
    /// Händerna i klicket över sin lägsta punkt, andel av vägen adress → topp. METOD M57
    public let traffHojd: Double?
    /// Handens toppfart mot den smalare utjämningens (bara framifrån). METOD M58
    public let handfartKvot: Double?
}

/// Svingens mått per vy, i Sportsbox-form, portade från Golf SG
/// (`tools/handled_svingmatt.py`) och samma som `tools/pc/matt.py`.
///
/// En kamera ser två av tre axlar, så varje mått tas i den vy där det ligger i
/// bildens plan. X pekar mot målet (FO) eller mot bollen (DTL), Y nedåt.
/// Vridningen och X-factor ingår inte: de kräver två kameror (PLAN S6).
/// Positionerna P1–P10 och måtten vid P3, P5 och P10 som inte är en fas: METOD M28, M29.
/// Tilläggen mot Sportsbox i 2D (PLAN S1b): METOD M30–M37. Tilläggen bakifrån (PLAN S1c):
/// händernas djup och främre armen mot axellinjen vid toppen, METOD M38–M39. Tilläggen ur
/// research 5 (PLAN S1e): bäckenets recentrering och skiftets tidpunkt (FO), bäckenets lägsta
/// punkt i nedsvingen och lyftet därifrån in i träffen (båda vyerna), METOD M41–M43.
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
    /// Kortare segment i bild än så mot adressen = vinkeln i leden mäts inte. METOD M52
    public static let segmentMin = 0.70
    /// Längre än så mot adressen = en punkt är fel (ett stelt segment kan inte växa). METOD M52
    public static let segmentMax = 1.15
    /// Toppens platå = händerna inom 2 % av vägen adress → topp från toppen. METOD M4
    public static let plataAndel = 0.02
    /// Platån söks högst så långt från toppen åt vardera hållet. METOD M4
    public static let plataSokS = 0.30
    /// Kortare axellinje i bild vid toppen, cm = axlarna skymmer varandra. METOD M39
    public static let axlarMinCm = 15.0

    // Varningarna: mått som visas men är osäkra (METOD M54). Gränserna är antaganden.
    /// Bredare platå än så = toppen prövas mot en andra signal. METOD M55
    public static let plataBredS = 0.08
    /// Signalerna mer än så isär = toppen osäker. METOD M55
    public static let toppOenigS = 0.05
    /// Rutorna så nära måttets ögonblick räknas. METOD M56
    public static let luckaFonsterS = 0.05
    /// Större andel saknade av måttets egna leder där = varning. METOD M56
    public static let luckaAndel = 0.20
    /// Händerna i klicket högre än så över sin lägsta punkt = träffen osäker. METOD M57
    public static let synkAndel = 0.10
    /// En nedsving utanför (s) = toppen eller träffen fel. METOD M59
    public static let nedsvingRimlig = (fran: 0.20, till: 0.45)
    /// Ett tempo utanför = toppen, starten eller träffen fel. METOD M59
    public static let tempoRimligt = (fran: 2.0, till: 4.5)
    /// Måtten som beror på toppens tid. METOD M55, METOD M59
    public static let toppens = ["tempo", "baksving_s", "nedsving_s"]
    /// Måtten som beror på träffens tid utöver de som slutar på _traff. METOD M57
    public static let traffens: Set<String> = ["brost_bojning_tapp", "backen_resa_framat", "tempo", "nedsving_s",
                                               "genomsving_s", "handfart_max", "handfart_max_fore_traff_ms",
                                               "framre_arm_vinkelfart_max", "backen_lyft_min", "backen_skifte_ms"]
    /// Handens fart och dess tid. METOD M58
    public static let farternas = ["handfart_max", "handfart_max_fore_traff_ms"]
    /// Händerna efter greppregeln (M1) bland luckornas leder: saknade bara när båda handlederna
    /// saknas. METOD M56
    public static let grepp = -1

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
            + ["backen_lyft_min", "backen_lyft_in_traff"]
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
            + ["backen_recentrering", "backen_skifte_ms", "backen_lyft_min", "backen_lyft_in_traff"]
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

    /// Ledens böjning (som `bojning`), men NaN när ett av de två segmenten syns kortare i
    /// bild än `segmentMin` av sin längd i adressen (a0, mitt0, c0): segmentet pekar då mot
    /// eller från kameran, och några cm fel i en punkt blir tiotals grader. En rak led syns
    /// rak i bild hur den än är vriden, men felet i punkterna förstärks. METOD M52
    public static func bojningSynlig(_ a: Punkt, _ mitt: Punkt, _ c: Punkt,
                                     _ a0: Punkt, _ mitt0: Punkt, _ c0: Punkt) -> Double {
        segmentOrsak(a, mitt, c, a0, mitt0, c0) == nil ? bojning(a, mitt, c) : .nan
    }

    /// Varför ledens vinkel inte kan mätas, eller nil: "led_saknas" (en punkt saknas),
    /// "segment_kort" (kortare i bild än `segmentMin` av adressens längd) eller
    /// "segment_langt" (längre än `segmentMax`: en punkt är fel). Det korta före det långa. METOD M52
    public static func segmentOrsak(_ a: Punkt, _ mitt: Punkt, _ c: Punkt,
                                    _ a0: Punkt, _ mitt0: Punkt, _ c0: Punkt) -> String? {
        var kvoter: [Double] = []
        for (p, q, p0, q0) in [(a, mitt, a0, mitt0), (c, mitt, c0, mitt0)] {
            let l0 = (p0 - q0).langd, l1 = (p - q).langd
            guard l0.isFinite && l1.isFinite && l0 > 0 else { return "led_saknas" }
            kvoter.append(l1 / l0)
        }
        if kvoter.contains(where: { !($0 >= segmentMin) }) { return "segment_kort" }
        if kvoter.contains(where: { $0 > segmentMax }) { return "segment_langt" }
        return nil
    }

    /// Toppens platå i s: hur länge händerna står inom `plataAndel` av vägen adress → topp
    /// från sin högsta punkt, från rutan närmast toppen och utåt (högst `plataSokS`, inte
    /// över en lucka längre än `Faser.maxLuckaS`). Samma som `matt.topp_plata`. METOD M4
    static func toppPlata(_ t: [Double], _ g: [Punkt], _ f: Fastider) -> Double? {
        let yTopp = Faser.vid(t, g, f.topp).y
        let yAdr = Faser.lage(t, g, f, .adress).y
        let vag = yAdr - yTopp
        guard vag.isFinite && vag > 0 else { return nil }
        let ok = t.indices.filter { g[$0].hel && abs(t[$0] - f.topp) <= plataSokS }
        guard !ok.isEmpty else { return nil }
        var k0 = 0
        for i in ok.indices where abs(t[ok[i]] - f.topp) < abs(t[ok[k0]] - f.topp) { k0 = i }
        let grans = plataAndel * vag
        guard g[ok[k0]].y - yTopp <= grans else { return 0.0 }
        var lo = k0, hi = k0
        while lo > 0 && t[ok[lo]] - t[ok[lo - 1]] <= Faser.maxLuckaS && g[ok[lo - 1]].y - yTopp <= grans { lo -= 1 }
        while hi < ok.count - 1 && t[ok[hi + 1]] - t[ok[hi]] <= Faser.maxLuckaS && g[ok[hi + 1]].y - yTopp <= grans {
            hi += 1
        }
        return t[ok[hi]] - t[ok[lo]]
    }

    /// Måttet beror på träffens tid: ett läge i klicket, eller en tid, fart eller ett fönster
    /// som slutar där. Samma som `matt.traffens_matt`. METOD M57
    public static func traffensMatt(_ namn: String) -> Bool {
        namn.hasSuffix("_traff") || traffens.contains(namn)
    }

    /// Måttets egna leder (`Led.rawValue`, `grepp` = händerna) och ögonblicken det läses i, för
    /// luckorna kring fasen: "start", "topp", "traff", "P3", "P5", "handfart", "vinkelfart". Mått
    /// som är medel över ett fönster eller sökningar över svingen har inga. Samma ordning och
    /// regler som `matt.luckornas_leder`. METOD M56
    public static func luckornasLeder(_ namn: String) -> (leder: [Int], tider: [String]) {
        let tider: [String]
        if namn == "tempo" || namn == "baksving_s" {
            tider = ["start", "topp"]
        } else if namn == "nedsving_s" || namn == "backen_recentrering" {
            tider = ["topp"]
        } else if namn.hasPrefix("handfart_max") {
            tider = ["handfart"]
        } else if namn == "framre_arm_vinkelfart_max" {
            tider = ["vinkelfart"]
        } else if namn == "backen_resa_framat" {
            tider = ["topp", "traff"]
        } else if namn == "backen_resa_p5" {
            tider = ["topp", "P5"]
        } else if namn == "brost_bojning_tapp" {
            tider = ["traff"]
        } else if namn == "framre_armbage_efter_traff" {
            tider = []
        } else if namn.hasSuffix("_topp") {
            tider = ["topp"]
        } else if namn.hasSuffix("_traff") {
            tider = ["traff"]
        } else if namn.hasSuffix("_p3") {
            tider = ["P3"]
        } else {
            tider = []
        }
        func r(_ l: [Led]) -> [Int] { l.map(\.rawValue) }
        func borjar(_ p: [String]) -> Bool { p.contains { namn.hasPrefix($0) } }
        let axlar = r([.axelF, .axelB]), hofter = r([.hoftF, .hoftB])
        let leder: [Int]
        if toppens.contains(namn) {
            leder = [grepp]
        } else if borjar(["handfart"]) {
            leder = r([.handledF, .handledB])
        } else if borjar(["framre_arm_vinkelfart"]) {
            leder = r([.axelF, .handledF])
        } else if borjar(["framre_arm_plan"]) {
            leder = r([.axelF, .axelB, .handledF])
        } else if borjar(["framre_armbage"]) {
            leder = r([.axelF, .armbageF, .handledF])
        } else if borjar(["bakre_armbage"]) {
            leder = r([.axelB, .armbageB])
        } else if borjar(["framre_kna_sway"]) {
            leder = r([.knaF])
        } else if borjar(["bakre_kna_sway"]) {
            leder = r([.knaB])
        } else if borjar(["framre_kna"]) {
            leder = r([.hoftF, .knaF, .fotledF])
        } else if borjar(["bakre_kna"]) {
            leder = r([.hoftB, .knaB, .fotledB])
        } else if borjar(["backen_bojning"]) {
            leder = axlar + hofter + r([.knaB])
        } else if borjar(["brost_bojning", "sidbojning", "sway_gap"]) {
            leder = axlar + hofter
        } else if borjar(["brost", "axellinje"]) {
            leder = axlar
        } else if borjar(["backen", "hoftlinje"]) {
            leder = hofter
        } else if borjar(["huvud"]) {
            leder = r([.nasa])
        } else if borjar(["hander_fore_backen"]) {
            leder = [grepp] + hofter
        } else if borjar(["hand_", "hander_"]) {
            leder = [grepp]
        } else {
            leder = []
        }
        return leder.isEmpty || tider.isEmpty ? ([], []) : (leder, tider)
    }

    /// Andelen av rutorna inom `luckaFonsterS` från tc där leden saknas (låg konfidens eller
    /// borttagen av rensningen); `grepp` saknas bara där båda handlederna saknas (M1). Rutor som
    /// telefonen inte gav räknas inte (där gäller M3:s lucka). 1 utan rutor. METOD M56
    static func saknadAndel(_ t: [Double], _ leder: [[Punkt]], led: Int, _ tc: Double) -> Double {
        var n = 0, ute = 0
        for k in t.indices where abs(t[k] - tc) <= luckaFonsterS {
            n += 1
            let borta = led == grepp
                ? !leder[Led.handledF.rawValue][k].hel && !leder[Led.handledB.rawValue][k].hel
                : !leder[led][k].hel
            if borta { ute += 1 }
        }
        return n == 0 ? 1.0 : Double(ute) / Double(n)
    }

    /// Mått som visas men är osäkra → orsakerna, sorterade. Bara mått som finns: ett mått som
    /// saknas har sin orsak i `saknas`. `kontroller` = kontrollernas tal ("topp_andra_s",
    /// "traff_hojd", "handfart_kvot"), `tider` = farternas toppar. Samma som `matt.varningar`.
    /// METOD M54
    static func varningar(_ matt: [String: Double], kontroller: [String: Double], plata: Double?, _ t: [Double],
                          _ leder: [[Punkt]], _ f: Fastider, _ pos: Positioner,
                          tider: [String: Double]) -> [String: [String]] {
        var ut: [String: Set<String>] = [:]
        func varna(_ namn: String, _ orsak: String) {
            if matt[namn] != nil { ut[namn, default: []].insert(orsak) }
        }
        if let p = plata, p > plataBredS, let d2 = kontroller["topp_andra_s"], abs(d2) > toppOenigS {   // METOD M55
            for n in toppens { varna(n, "topp_osaker") }
        }
        var ogonblick: [String: Double] = ["topp": f.topp, "traff": f.traff]
        if let s = f.start { ogonblick["start"] = s }
        if let p3 = pos.p3 { ogonblick["P3"] = p3 }
        if let p5 = pos.p5 { ogonblick["P5"] = p5 }
        for (k, v) in tider { ogonblick[k] = v }
        for namn in matt.keys {                                                                          // METOD M56
            let (lederna, nar) = luckornasLeder(namn)
            let glest = nar.contains { x in
                guard let tc = ogonblick[x] else { return false }
                return lederna.contains { saknadAndel(t, leder, led: $0, tc) > luckaAndel }
            }
            if glest { varna(namn, "luckor_kring_fasen") }
        }
        if let h = kontroller["traff_hojd"], h > synkAndel {                                              // METOD M57
            for namn in matt.keys where traffensMatt(namn) { varna(namn, "traff_osaker") }
        }
        if let k = kontroller["handfart_kvot"], k < Farter.filterKvot {                                   // METOD M58
            for n in farternas { varna(n, "filterkanslig") }
        }
        let ned = matt["nedsving_s"], tempo = matt["tempo"]                                               // METOD M59
        let orimlig = (ned.map { !($0 >= nedsvingRimlig.fran && $0 <= nedsvingRimlig.till) } ?? false)
            || (tempo.map { !($0 >= tempoRimligt.fran && $0 <= tempoRimligt.till) } ?? false)
        if orimlig {
            for n in toppens { varna(n, "fas_orimlig") }
        }
        return ut.mapValues { $0.sorted() }
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

    /// Punktens koordinat (x eller y) minus `noll`, gånger `skala`, i fönstret a…b: värdet i
    /// ögonblicket vid a och vid b (M3) och rutorna strikt mellan dem som har värde, i
    /// tidsordning. nil när en ände saknas eller när två tider i följd ligger mer än
    /// maxLuckaS isär: då kan ytterläget ligga i luckan. Som `fonster` i tools/pc/matt.py.
    /// METOD M41, METOD M42, METOD M43
    static func fonster(_ t: [Double], _ p: [Punkt], y: Bool, noll: Double, skala: Double,
                        _ a: Double, _ b: Double) -> (t: [Double], v: [Double])? {
        let pa = Faser.vid(t, p, a), pb = Faser.vid(t, p, b)
        guard pa.hel && pb.hel else { return nil }
        var tt = [a], v = [y ? pa.y : pa.x]
        for k in t.indices where p[k].hel && t[k] > a && t[k] < b {
            tt.append(t[k])
            v.append(y ? p[k].y : p[k].x)
        }
        tt.append(b)
        v.append(y ? pb.y : pb.x)
        for i in 1..<tt.count where tt[i] - tt[i - 1] > Faser.maxLuckaS {
            return nil
        }
        return (tt, v.map { ($0 - noll) * skala })
    }

    /// Första tiden då v når 0 underifrån, linjärt mellan två värden i följd; tt[0] när v
    /// redan är ≥ 0 där, nil när v aldrig når 0. METOD M42
    static func forstaFramat(_ tt: [Double], _ v: [Double]) -> Double? {
        if v[0] >= 0 { return tt[0] }
        for i in 1..<v.count where v[i] >= 0 {
            return tt[i - 1] + (0.0 - v[i - 1]) / (v[i] - v[i - 1]) * (tt[i] - tt[i - 1])
        }
        return nil
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
    public static func mat(_ raa: Sving) throws -> SvingResultat {
        // Byten och spikar bort först, sedan räknas allt på de rensade lederna. METOD M53
        let (rensade, rensning) = Rensa.rensa(raa.t, raa.leder)
        let s = Sving(vy: raa.vy, hand: raa.hand, xTecken: raa.xTecken, langdM: raa.langdM, tKlick: raa.tKlick,
                      t: raa.t, leder: rensade)
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
        var saknas: [String: String] = [:]
        var tider: [String: Double] = [:]          // farternas toppar, för luckorna kring dem (METOD M56)
        var handfartKvot: Double? = nil            // METOD M58
        /// Vinkeln i leden som måttet `namn`, eller orsaken till att den saknas. METOD M52
        func synlig(_ namn: String, _ a: Punkt, _ mitt: Punkt, _ c: Punkt, _ a0: Punkt, _ mitt0: Punkt, _ c0: Punkt) {
            if let orsak = segmentOrsak(a, mitt, c, a0, mitt0, c0) {
                saknas[namn] = orsak
            } else {
                m[namn] = bojning(a, mitt, c)
            }
        }
        /// Böjningen i fasen, bara när båda segmenten syns rimligt i bild. METOD M52
        func synligLed(_ namn: String, _ a: [Punkt], _ mitt: [Punkt], _ c: [Punkt], _ fas: Fas) {
            synlig(namn, L(a, fas), L(mitt, fas), L(c, fas), L(a, .adress), L(mitt, .adress), L(c, .adress))
        }
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
                synligLed("bakre_kna_\(fz.rawValue)", led(.hoftB), led(.knaB), led(.fotledB), fz)   // METOD M52
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
                synligLed("framre_kna_\(fz.rawValue)", led(.hoftF), led(.knaF), led(.fotledF), fz)   // METOD M52
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
            synligLed("framre_armbage_topp", led(.axelF), led(.armbageF), handF, .topp)           // METOD M22, METOD M52
            let a0 = s.tKlick + chicken.fran, a1 = s.tKlick + chicken.till                        // METOD M23
            synlig("framre_armbage_efter_traff", Faser.medel(t, led(.axelF), a0, a1),
                   Faser.medel(t, led(.armbageF), a0, a1), Faser.medel(t, handF, a0, a1),
                   L(led(.axelF), .adress), L(led(.armbageF), .adress), L(handF, .adress))
            let fot = L(led(.fotledF), .adress) - L(led(.fotledB), .adress)                        // METOD M24
            let axl = L(led(.axelF), .adress) - L(led(.axelB), .adress)
            m["stans_bredd"] = axl.langd > 0 ? fot.langd / axl.langd : .nan
            // Måtten vid positionerna som inte är en fas. METOD M29
            if let p3 = pos.p3 {
                m["backen_sway_p3"] = (Faser.vid(t, P, p3).x - L(P, .adress).x) * cm
                synlig("framre_armbage_p3", Faser.vid(t, led(.axelF), p3), Faser.vid(t, led(.armbageF), p3),
                       Faser.vid(t, handF, p3), L(led(.axelF), .adress), L(led(.armbageF), .adress),
                       L(handF, .adress))
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
                tider["handfart"] = hf.tid
                // Samma topp med en smalare utjämning: känslig för utjämningen? METOD M58
                handfartKvot = Farter.kvotMotSmal(nedsving, hf) { tau in
                    Farter.handensFart(t, fram: s.led(.handledF), bak: s.led(.handledB), tau, bada: true,
                                       sigma: Farter.smalSigmaS).map { $0 * cm }
                }
            }
            if let af = Farter.maxpunkt(nedsving, Farter.vinkelfart(t, fran: s.led(.axelF), till: s.led(.handledF),
                                                                    nedsving)) {
                m["framre_arm_vinkelfart_max"] = af.varde
                tider["vinkelfart"] = af.tid
            }
        }

        for fz in efter {                                                           // METOD M31, METOD M32
            m["brost_lyft_\(fz.rawValue)"] = flyttUpp(C, fz)
            m["hand_lyft_\(fz.rawValue)"] = flyttUpp(G, fz)
        }
        // Bäckenets lägsta punkt mellan toppen och träffen, från adressen, och lyftet därifrån
        // in i träffen. METOD M43
        if let ned = fonster(t, P, y: true, noll: L(P, .adress).y, skala: -cm, f.topp, f.traff),
           let lagst = ned.v.min() {
            m["backen_lyft_min"] = lagst
            m["backen_lyft_in_traff"] = ned.v[ned.v.count - 1] - lagst
        }
        if s.vy == .fo {
            let x0 = L(P, .adress).x
            // Recentreringen: bäckenets sway vid toppen minus dess minsta i baksvingen. METOD M41
            if let bak = fonster(t, P, y: false, noll: x0, skala: cm, f.adressTill, f.topp), let lagst = bak.v.min() {
                m["backen_recentrering"] = bak.v[bak.v.count - 1] - lagst
            }
            // Skiftet: tiden från toppen tills höftmitten är tillbaka i adressläget. METOD M42
            if let fram = fonster(t, P, y: false, noll: x0, skala: cm, f.topp, f.traff),
               let tc = forstaFramat(fram.t, fram.v) {
                m["backen_skifte_ms"] = (tc - f.topp) * 1000.0
            }
        }

        let efterTraff = Farter.rutnat(f.traff + Farter.stegS, f.traff + Faser.finish.fran)   // METOD M36
        if let tf = Farter.finishTid(efterTraff, Farter.handensFart(t, fram: s.led(.handledF), bak: s.led(.handledB),
                                                                    efterTraff, bada: false)) {
            m["genomsving_s"] = tf - f.traff
        }

        m["nedsving_s"] = f.traff - f.topp                                          // METOD M5: utan starten
        if let start = f.start, !f.startOsaker {                                    // METOD M5, METOD M40
            let bak = f.topp - start, ned = f.traff - f.topp
            m["baksving_s"] = bak
            if ned > 0 {
                m["tempo"] = bak / ned
            }
        } else {                                                                    // METOD M5: varför tempot saknas
            let orsak = f.start == nil ? "start_saknas" : "start_osaker"
            saknas["tempo"] = orsak
            saknas["baksving_s"] = orsak
        }
        let matt = m.filter { $0.value.isFinite }
        let plata = toppPlata(t, G, f)
        let toppAndra = Faser.andraToppen(t, G, axelF: led(.axelF), handF: handF, f, vy: s.vy).map { $0 - f.topp }
        let traffHojd = Faser.traffensHojd(t, G, f)                                 // METOD M57
        var kontroller: [String: Double] = [:]                                      // METOD M54
        if let v = toppAndra { kontroller["topp_andra_s"] = v }                     // METOD M55
        if let v = traffHojd { kontroller["traff_hojd"] = v }
        if let v = handfartKvot { kontroller["handfart_kvot"] = v }
        let kvalitet = Kvalitet(rensning: rensning, toppPlataS: plata,
                                saknas: saknas.filter { matt[$0.key] == nil },
                                varningar: varningar(matt, kontroller: kontroller, plata: plata, t, s.leder, f, pos,
                                                     tider: tider),
                                toppAndraS: toppAndra, traffHojd: traffHojd, handfartKvot: handfartKvot)
        return SvingResultat(vy: s.vy, hand: s.hand, cmPerPx: cm, faser: f, positioner: pos, matt: matt,
                             kvalitet: kvalitet)
    }
}
