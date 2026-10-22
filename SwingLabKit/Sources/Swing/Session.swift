import Foundation

/// En svings mått, det sessionen och katalogen behöver.
public struct SvingMatt: Codable, Sendable {
    public let vy: Vy
    public let matt: [String: Double]

    public init(vy: Vy, matt: [String: Double]) {
        self.vy = vy
        self.matt = matt
    }
}

/// Ett mått sammanfattat över passets svingar. METOD M25
public struct Sammanfattning: Equatable, Sendable {
    public let n: Int
    public let median: Double
    public let q1: Double
    public let q3: Double
    public let sd: Double
    public let min: Double
    public let max: Double
    /// Spearmans ρ mot svingens plats i passet.
    public let trend: Double
    /// Avvikarnas plats i passet (0 först).
    public let avvikare: [Int]
}

/// Skillnaden mot förra passet. METOD M26
public struct Jamforelse: Equatable, Sendable {
    public let skillnad: Double
    public let spridning: Double
    public let tydlig: Bool
}

/// Sessionen: varje mått sammanfattat över passets svingar, och jämförelsen mot
/// förra passet. Samma räkning som tools/pc/session.py. METOD M25, METOD M26
public enum Session {
    /// Färre svingar ger ingen sammanfattning. METOD M25
    public static let minN = 3
    /// Avvikare = mer än 3 robusta sd från medianen. METOD M25
    public static let madGrans = 3.0
    /// MAD → sd för normalfördelning. METOD M25
    public static let madSkala = 1.4826
    /// IQR → sd för normalfördelning. METOD M26
    public static let iqrSkala = 1.349

    /// Linjär interpolation mellan de närmaste (som numpy 'linear'), p i 0…1.
    public static func percentil(_ sorterad: [Double], _ p: Double) -> Double {
        let n = sorterad.count
        let pos = p * Double(n - 1)
        let lo = Int(pos.rounded(.down))
        let hi = Swift.min(lo + 1, n - 1)
        return sorterad[lo] + (pos - Double(lo)) * (sorterad[hi] - sorterad[lo])
    }

    /// Rangerna 1…n, med medelrangen för lika värden.
    public static func rang(_ x: [Double]) -> [Double] {
        let ordning = x.indices.sorted { a, b in x[a] < x[b] || (x[a] == x[b] && a < b) }
        var r = [Double](repeating: 0, count: x.count)
        var i = 0
        while i < ordning.count {
            var j = i
            while j + 1 < ordning.count && x[ordning[j + 1]] == x[ordning[i]] {
                j += 1
            }
            let medel = Double(i + j) / 2 + 1
            for k in i...j {
                r[ordning[k]] = medel
            }
            i = j + 1
        }
        return r
    }

    public static func pearson(_ a: [Double], _ b: [Double]) -> Double {
        let n = Double(a.count)
        let ma = a.reduce(0, +) / n, mb = b.reduce(0, +) / n
        var sab = 0.0, saa = 0.0, sbb = 0.0
        for i in a.indices {
            sab += (a[i] - ma) * (b[i] - mb)
            saa += (a[i] - ma) * (a[i] - ma)
            sbb += (b[i] - mb) * (b[i] - mb)
        }
        if saa == 0 || sbb == 0 { return 0 }
        return sab / (saa * sbb).squareRoot()
    }

    public static func spearman(_ a: [Double], _ b: [Double]) -> Double {
        pearson(rang(a), rang(b))
    }

    /// Rader = måtten per sving i passets ordning. METOD M25
    public static func sammanfatta(_ rader: [[String: Double]]) -> [String: Sammanfattning] {
        var ut: [String: Sammanfattning] = [:]
        let nycklar = Set(rader.flatMap { $0.keys })
        for k in nycklar.sorted() {
            var plats: [Int] = []
            var x: [Double] = []
            for (i, r) in rader.enumerated() {
                if let v = r[k], v.isFinite {
                    plats.append(i)
                    x.append(v)
                }
            }
            let n = x.count
            if n < minN { continue }
            let s = x.sorted()
            let med = percentil(s, 0.5)
            let medel = x.reduce(0, +) / Double(n)
            var kvadrat = 0.0
            for v in x {
                kvadrat += (v - medel) * (v - medel)
            }
            let sd = (kvadrat / Double(n - 1)).squareRoot()
            let mad = percentil(x.map { abs($0 - med) }.sorted(), 0.5)
            let grans = madGrans * madSkala * mad
            var avvikare: [Int] = []
            for i in 0..<n where mad > 0 && abs(x[i] - med) > grans {
                avvikare.append(plats[i])
            }
            ut[k] = Sammanfattning(n: n, median: med, q1: percentil(s, 0.25), q3: percentil(s, 0.75), sd: sd,
                                   min: s[0], max: s[n - 1], trend: spearman(plats.map { Double($0) }, x),
                                   avvikare: avvikare)
        }
        return ut
    }

    /// Spridningen ur kvartilerna: (q3 − q1)/1,349. METOD M26
    public static func robustSD(_ s: Sammanfattning) -> Double {
        (s.q3 - s.q1) / iqrSkala
    }

    /// Skillnaden i median mot förra passet, och om den är större än förra
    /// passets spridning. METOD M26
    public static func jamfor(nu: [String: Sammanfattning], forra: [String: Sammanfattning]) -> [String: Jamforelse] {
        var ut: [String: Jamforelse] = [:]
        for (k, a) in nu {
            guard let b = forra[k] else { continue }
            let skillnad = a.median - b.median
            let spridning = robustSD(b)
            ut[k] = Jamforelse(skillnad: skillnad, spridning: spridning, tydlig: abs(skillnad) > spridning)
        }
        return ut
    }

    /// Grupperna i en sessions sammanfattning: varje vy, och alla svingar ihop (tempot).
    public static let grupper = ["dtl", "fo", "alla"]

    /// Passets svingar sammanfattade per vy och för alla ihop.
    public static func sammanfattaSession(_ svingar: [SvingMatt]) -> [String: [String: Sammanfattning]] {
        [
            "dtl": sammanfatta(svingar.filter { $0.vy == .dtl }.map { $0.matt }),
            "fo": sammanfatta(svingar.filter { $0.vy == .fo }.map { $0.matt }),
            "alla": sammanfatta(svingar.map { $0.matt }),
        ]
    }
}
