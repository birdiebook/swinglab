import Foundation

/// Skärmen Att jobba på, färdig att rita: en sektion per sak (1–3) i
/// `att_jobba_pa.json`, i svingens ordning. Talen nu räknas ur passen på
/// telefonen; filen ger saken, följdfelen, övningen, tanken och villkoret.
public struct AttJobbaPaVisning: Sendable {
    /// Ett mått i kedjan: saken först, sedan följdfelen.
    public struct Lank: Equatable, Sendable {
        public let namn: String
        /// "−2,4"
        public let varde: String
        public let enhet: String
        /// "−5,9 → −2,4": passet saken valdes på → nu.
        public let fran: String
    }

    public struct Sakvisning: Sendable {
        public let ordning: Int
        /// Måttets korta namn: "Sway".
        public let namn: String
        /// "FO · topp"
        public let rubrik: String
        public let markning: Markning?
        /// Saken och upp till två följdfel.
        public let kedja: [Lank]
        public let ovning: String
        /// Rörlighetens övning när typen inte är ren teknik (METOD MT5 i S5).
        public let fysik: String?
        /// "”Rör inte käppen.”"
        public let tanke: String
        /// "Sway topp ≥ 0,0 cm", "Tempo 2,5–3,1"
        public let villkor: String
        /// "serie 1 · 2 pass i rad"
        public let villkorUnder: String
        public let serie1: String
        public let passet: String
        public let enhet: String
        public let iRad: Int
        public let iRadKrav: Int
    }

    /// "3 nov": passet tolkningen bygger på.
    public let fran: String
    public let saker: [Sakvisning]

    /// `pass` är telefonens pass, äldst först.
    public init(_ a: AttJobbaPa, katalog: Katalog, pass: [Pass]) {
        let fel = Dictionary(katalog.fel.map { ($0.id, $0) }, uniquingKeysWith: { x, _ in x })
        let nu = pass.last
        let dag = a.passDatum
        // Passet saken valdes på: samma dag, annars det första efter.
        let dat = dag.flatMap { d in pass.first { Tal.kalender.isDate($0.datum, inSameDayAs: d) || $0.datum >= d } }
        fran = dag.map(Tal.datum) ?? ""

        func lank(_ id: String, filensNu: Double?) -> Lank? {
            guard let f = fel[id] else { return nil }
            let e = Etiketter.etikett(f.matt)
            let v = nu?.median(f.matt, f.grupp)
            let forst = dat?.median(f.matt, f.grupp) ?? filensNu
            return Lank(namn: e.namn, varde: Mattkort.text(v ?? filensNu, e), enhet: e.enhet,
                        fran: "\(Mattkort.text(forst, e)) → \(Mattkort.text(v ?? filensNu, e))")
        }

        saker = a.saker.sorted { $0.ordning < $1.ordning }.map { s -> Sakvisning in
            let f = fel[s.fel]
            let e = Etiketter.etikett(s.matt)
            let grupp = f?.grupp ?? (s.vy == "bada" ? "alla" : s.vy)
            var r = [e.vy ?? Etiketter.vy(s.vy)]
            if !e.fas.isEmpty { r.append(e.fas) }
            let markning: Markning? = s.markning == "B10" ? .b10 : s.markning == "egen" ? .egen : nil
            var kedja: [Lank] = []
            if let l = lank(s.fel, filensNu: s.nu) { kedja.append(l) }
            for ff in s.foljdfel where kedja.count < 3 {
                if let l = lank(ff, filensNu: nil) { kedja.append(l) }
            }
            let k = s.klartNar
            let fasText = e.fas.isEmpty ? "" : " \(e.fas)"
            let grans: String
            switch k.villkor {
            case .minst: grans = "≥ " + Tal.tal(k.lo, decimaler: e.decimaler)
            case .hogst: grans = "≤ " + Tal.tal(k.hi, decimaler: e.decimaler)
            case .mellan: grans = Tal.tal(k.lo, decimaler: e.decimaler) + "–" + Tal.tal(k.hi, decimaler: e.decimaler)
            }
            let fysik = s.typ == "teknik" ? nil : s.fysik?.ovning
            return Sakvisning(
                ordning: s.ordning, namn: e.namn, rubrik: r.joined(separator: " · "), markning: markning,
                kedja: kedja, ovning: s.ovning.text, fysik: fysik, tanke: "”\(s.ovning.tanke)”",
                villkor: Tal.medEnhet("\(e.namn)\(fasText) \(grans)", e.enhet),
                villkorUnder: "serie 1 · \(k.passIRad) pass i rad",
                serie1: Mattkort.text(nu?.serie1Median(s.matt, grupp), e),
                passet: Mattkort.text(nu?.median(s.matt, grupp) ?? s.nu, e),
                enhet: e.enhet,
                iRad: AttJobbaPaVisning.iRad(k, matt: s.matt, grupp: grupp, pass: pass),
                iRadKrav: k.passIRad)
        }
    }

    /// Passen i rad, från det senaste och bakåt, där serie 1 håller villkoret.
    public static func iRad(_ k: AttJobbaPa.KlartNar, matt: String, grupp: String, pass: [Pass]) -> Int {
        var n = 0
        for p in pass.reversed() {
            guard let v = p.serie1Median(matt, grupp), k.haller(v) else { break }
            n += 1
        }
        return n
    }
}

/// Idag (skissens skärm 1): dagen, senaste passet som rader med ett kompakt spann,
/// och den första saken att jobba på.
public struct Idagvisning: Sendable {
    public struct Rad: Sendable {
        public let id: String
        public let namn: String
        public let varde: String
        /// Enheten efter talet, utan kvoten ": 1".
        public let enhet: String
        public let spann: Spann
    }

    public struct Forsta: Sendable {
        public let namn: String
        public let tanke: String
        /// Saken och följdfelen: "Sway", "Resa framåt", "Sway gap".
        public let kedja: [String]
    }

    /// "tis 13 jan"
    public let dag: String
    /// "lör 9 jan · järn 7 · 34"
    public let senaste: String?
    public let rader: [Rad]
    public let forsta: Forsta?

    public init(idag: Date, katalog: Katalog, pass: [Pass], attJobbaPa: AttJobbaPa?) {
        dag = Tal.dag(idag)
        if let nu = pass.last {
            senaste = "\(Tal.dag(nu.datum)) · \(nu.klubba) · \(nu.slag)"
            let p = Passvisning(katalog: katalog, pass: pass)
            rader = p.kort.compactMap { k -> Rad? in
                guard let s = k.spann else { return nil }
                return Rad(id: k.id, namn: k.namn, varde: k.varde, enhet: k.enhet == ": 1" ? "" : k.enhet, spann: s)
            }
        } else {
            senaste = nil
            rader = []
        }
        if let a = attJobbaPa {
            let v = AttJobbaPaVisning(a, katalog: katalog, pass: pass)
            forsta = v.saker.first.map { Forsta(namn: $0.namn, tanke: $0.tanke, kedja: $0.kedja.map { $0.namn }) }
        } else {
            forsta = nil
        }
    }
}
