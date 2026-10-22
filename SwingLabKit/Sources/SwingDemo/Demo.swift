import Foundation
import Swing

/// Påhittade pass för vyernas prov (CLAUDE.md, Dataregeln: repot är publikt, bara
/// påhittade tal). Talen följer skissen (`design/skiss.html`): 16 pass med järn 7
/// från 20 okt till 9 jan, där bäckenets sway går från −7,9 till −2,4 cm.
/// Varje pass ges som svingar, så att vyerna räknar medianen, kvartilerna och
/// jämförelsen själva (METOD M25–M27). Appen länkar inte in det här målet.
public enum Demo {
    public static let datum: [Date] = [
        (2026, 10, 20), (2026, 10, 24), (2026, 10, 28), (2026, 11, 1), (2026, 11, 5), (2026, 11, 9),
        (2026, 11, 14), (2026, 11, 19), (2026, 11, 24), (2026, 11, 29), (2026, 12, 6), (2026, 12, 12),
        (2026, 12, 19), (2027, 1, 2), (2027, 1, 6), (2027, 1, 9),
    ].map { Tal.dag($0.0, $0.1, $0.2) }

    /// Träningsblockens första dagar (B1, B2).
    public static let block: [Date] = [Tal.dag(2026, 11, 5), Tal.dag(2026, 12, 12)]

    /// Måttets median per pass, spridningen (sd) per sving och serie 1:s median.
    struct Serie {
        let vy: Vy?            // nil = båda telefonerna
        let pass: [Double]
        let sd: Double
        let serie1: [Double]?
    }

    static let serier: [String: Serie] = [
        "backen_sway_topp": Serie(vy: .fo, pass: [-7.9, -8.3, -7.4, -8.1, -7.6, -7.9, -7.2, -7.6, -7.0, -7.3, -6.8, -5.9, -4.6, -3.9, -3.6, -2.4],
                                  sd: 1.4,
                                  serie1: [-8.4, -8.9, -8.0, -8.6, -8.3, -8.5, -7.9, -8.2, -7.7, -8.0, -7.5, -7.0, -6.1, -5.2, -4.8, -4.0]),
        "backen_resa_framat": Serie(vy: .fo, pass: [8.1, 7.6, 8.4, 7.9, 8.0, 8.2, 7.8, 8.3, 8.1, 8.4, 8.2, 9.0, 9.8, 10.4, 11.0, 11.3],
                                    sd: 1.6, serie1: nil),
        "backen_thrust_traff": Serie(vy: .dtl, pass: [3.4, 3.1, 3.6, 3.3, 3.0, 2.7, 2.5, 2.2, 2.0, 1.8, 1.7, 1.9, 1.8, 1.7, 1.6, 2.6],
                                     sd: 1.1,
                                     serie1: [3.6, 3.5, 3.9, 3.6, 3.4, 3.1, 3.0, 2.8, 2.5, 2.4, 2.2, 2.3, 2.3, 2.2, 2.1, 2.9]),
        "brost_bojning_tapp": Serie(vy: .dtl, pass: [6, 5, 7, 6, 6, 5, 6, 5, 6, 5, 6, 5, 4, 4, 4, 2], sd: 1.5, serie1: nil),
        "tempo": Serie(vy: nil, pass: [2.8, 2.9, 2.8, 3.0, 2.9, 2.8, 2.9, 2.9, 3.0, 2.8, 2.9, 2.9, 2.8, 2.9, 2.8, 2.9],
                       sd: 0.15, serie1: nil),
        "sway_gap_traff": Serie(vy: .fo, pass: [5.2, 5.0, 5.4, 5.1, 4.9, 5.3, 5.0, 4.8, 5.1, 4.9, 4.7, 4.6, 4.4, 4.2, 4.3, 4.1], sd: 1.2, serie1: nil),
        "axellinje_lutning_traff": Serie(vy: .fo, pass: Array(repeating: 31, count: 16), sd: 3, serie1: nil),
        "sidbojning_topp": Serie(vy: .fo, pass: [4, 5, 4, 4, 3, 4, 5, 4, 4, 3, 4, 4, 5, 4, 4, 4], sd: 1.5, serie1: nil),
        "framre_armbage_efter_traff": Serie(vy: .fo, pass: [22, 24, 21, 23, 22, 25, 23, 22, 24, 23, 22, 21, 23, 22, 24, 23], sd: 4, serie1: nil),
        "framre_armbage_topp": Serie(vy: .fo, pass: [14, 15, 13, 16, 15, 14, 15, 16, 14, 15, 13, 14, 15, 14, 15, 14], sd: 3, serie1: nil),
        "bakre_armbage_topp": Serie(vy: .dtl, pass: [56, 58, 55, 57, 56, 54, 57, 55, 56, 58, 55, 54, 56, 55, 57, 56], sd: 5, serie1: nil),
        "handbana": Serie(vy: .dtl, pass: [2.4, 2.8, 2.2, 2.6, 2.5, 2.3, 2.7, 2.4, 2.6, 2.2, 2.5, 2.4, 2.3, 2.6, 2.4, 2.5], sd: 1.2, serie1: nil),
        "baksving_s": Serie(vy: nil, pass: Array(repeating: 0.85, count: 16), sd: 0.04, serie1: nil),
        "brost_bojning_adress": Serie(vy: .dtl, pass: Array(repeating: 40, count: 16), sd: 1, serie1: nil),
    ]

    /// Slagen per pass; serie 1 är de första 5.
    public static let slag = [28, 30, 26, 32, 30, 29, 31, 33, 30, 27, 32, 30, 31, 29, 33, 34]
    public static let serie1 = 5

    /// Ett deterministiskt slumptal (Park–Miller), så att bilderna blir samma varje gång.
    struct Slump {
        var s: UInt64
        mutating func nasta() -> Double {
            s = (s * 16807) % 2_147_483_647
            return Double(s) / 2_147_483_647
        }
        /// Ungefär normalfördelat, medel 0 och sd 1.
        mutating func gauss() -> Double {
            var u = 0.0
            for _ in 0..<6 { u += nasta() }
            return (u - 3) / 0.5.squareRoot()
        }
    }

    static func median(_ x: [Double]) -> Double { Session.percentil(x.sorted(), 0.5) }

    /// n värden med medianen `mal` (och serie 1:s median `mal1` för de första k).
    static func varden(_ n: Int, mal: Double, sd: Double, k: Int, mal1: Double?, _ r: inout Slump) -> [Double] {
        let brus = (0..<n).map { _ in r.gauss() * sd }
        var forsta = Array(brus.prefix(k)), resten = Array(brus.dropFirst(k))
        if let m1 = mal1, k > 0 {
            let m = median(forsta)
            forsta = forsta.map { $0 - m + m1 }
        } else {
            forsta = forsta.map { $0 + mal }
        }
        let m = median(resten)
        resten = resten.map { $0 - m + mal }
        // Skjut resten tills hela passets median är målet (serie 1 ligger fast).
        for _ in 0..<40 {
            let d = mal - median(forsta + resten)
            if abs(d) < 1e-9 { break }
            resten = resten.map { $0 + d }
        }
        return forsta + resten
    }

    /// Passen, äldst först.
    public static let pass: [Pass] = allaPass()

    static func allaPass() -> [Pass] {
        var r = Slump(s: 7)
        return datum.indices.map { i -> Pass in
            let n = slag[i]
            var fo = [[String: Double]](repeating: [:], count: n)
            var dtl = [[String: Double]](repeating: [:], count: n)
            for (matt, s) in serier.sorted(by: { $0.key < $1.key }) {
                // Ett mått för båda telefonerna (tempot) är samma slag sett två gånger: samma tal.
                let v = varden(n, mal: s.pass[i], sd: s.sd, k: serie1, mal1: s.serie1?[i], &r)
                for j in 0..<n {
                    if s.vy != .dtl { fo[j][matt] = v[j] }
                    if s.vy != .fo { dtl[j][matt] = v[j] }
                }
            }
            // Det som hänger ihop räknas ur det andra, som i Matt.mat (METOD M5, M6).
            func harled(_ m: inout [String: Double]) {
                if let b = m["baksving_s"], let t = m["tempo"] { m["nedsving_s"] = b / t }
                if let a = m["brost_bojning_adress"], let t = m["brost_bojning_tapp"] { m["brost_bojning_traff"] = a - t }
            }
            for j in 0..<n {
                harled(&fo[j])
                harled(&dtl[j])
            }
            // Slagen i ordning: FO och DTL från samma slag efter varandra.
            var svingar: [SvingMatt] = []
            for j in 0..<n {
                svingar.append(SvingMatt(vy: .fo, matt: fo[j]))
                svingar.append(SvingMatt(vy: .dtl, matt: dtl[j]))
            }
            return Pass(datum: datum[i], klubba: "järn 7", svingar: svingar, serie1: serie1)
        }
    }

    /// Mediansvingen i passet och förra passet, som leder: bäckenets sway i FO och
    /// thrusten i DTL ligger på passens medianer.
    public static func sving(_ vy: Vy, forra: Bool = false) -> Sving {
        let i = forra ? datum.count - 2 : datum.count - 1
        switch vy {
        case .fo:
            let topp = serier["backen_sway_topp"]!.pass[i], resa = serier["backen_resa_framat"]!.pass[i]
            return DemoSving.fo(sway: (topp, topp + resa, 14))
        case .dtl:
            let traff = serier["backen_thrust_traff"]!.pass[i], tapp = serier["brost_bojning_tapp"]!.pass[i]
            return DemoSving.dtl(thrust: (-1, traff, 8), bojning: (40, 38, 40 - tapp, 10))
        }
    }

    /// Att jobba på efter passet 12 dec, i S5:s format (docs/FORMAT.md, Att jobba på):
    /// swayen med sina följdfel, och early extension med en rörlighetsövning.
    /// Övningarna är katalogens ordagrant (kalla "katalog").
    public static let attJobbaPaJSON = #"""
    {
     "format": "swinglab-att-jobba-pa/1",
     "pass": "20261212-180000",
     "skapad": "2026-12-12T21:15:00+01:00",
     "saker": [
      {
       "ordning": 1,
       "fel": "sway_topp",
       "namn": "Bäckenet glider bakåt i baksvingen",
       "vy": "fo", "matt": "backen_sway_topp", "enhet": "cm",
       "nu": -5.9, "spann": [0, null], "markning": "B10",
       "ovning": {
        "text": "Käpp i marken utanför bakre höften. Baksving till toppen och stopp: höften roterar, käppen står kvar. Sedan fötterna ihop, 3/4-svingar.",
        "tanke": "Rör inte käppen.",
        "kalla": "katalog"
       },
       "klart_nar": {"villkor": ">=", "grans": 0, "pa": "forsta_serien", "pass_i_rad": 2},
       "foljdfel": ["backens_resa_framat", "sway_gap"],
       "typ": "teknik",
       "fysik": null
      },
      {
       "ordning": 2,
       "fel": "early_extension",
       "namn": "Early extension: bäckenet mot bollen",
       "vy": "dtl", "matt": "backen_thrust_traff", "enhet": "cm",
       "nu": 1.9, "spann": null, "markning": "egen",
       "ovning": {
        "text": "Stjärten mot en stol bakom dig i adressen. Långsamma svingar som håller kontakten till träffen, och bäckenet roterar samtidigt.",
        "tanke": "Stolen ska känna stjärten hela vägen.",
        "kalla": "katalog"
       },
       "klart_nar": {"villkor": "<=", "grans": 1.5, "pa": "forsta_serien", "pass_i_rad": 2},
       "foljdfel": ["tappad_hallning"],
       "typ": "teknik_kroppen_gor_det_svart",
       "fysik": {"test": "Toe touch", "treregeln": [true, true, false], "ovning": "Raka ben, händerna mot tårna, 2 × 10 långsamt."}
      }
     ]
    }
    """#

    public static var attJobbaPa: AttJobbaPa { try! AttJobbaPa.las(json: attJobbaPaJSON) }
}
