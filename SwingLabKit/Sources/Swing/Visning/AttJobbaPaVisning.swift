import Foundation

/// Skärmen Att jobba på, färdig att rita: en sektion per sak (1–3) i
/// `att_jobba_pa.json`, i svingens ordning. Filen är kontraktet med PC:n
/// (docs/FORMAT.md, Att jobba på): vyn visar talen som de står där och räknar
/// inte om något; här blir de bara text i vyns form (BESLUT B13).
public struct AttJobbaPaVisning: Sendable {
    /// Ett följdfel i kedjan: vägen från saken och följdfelets tal.
    public struct Foljd: Equatable, Sendable {
        /// Måttens korta namn längs vägen, utan saken: ["Side bend", "Thrust"].
        public let vag: [String]
        public let varde: String
        public let enhet: String

        /// "Side bend, Thrust +3.3 cm"
        public var upplasning: String { "\(vag.joined(separator: ", ")) \(Tal.medEnhet(varde, enhet))" }
    }

    public enum Steglage: Sendable { case klart, nu, kommer }

    public struct Sakvisning: Sendable {
        public let ordning: Int
        /// Måttets korta namn: "Sway".
        public let namn: String
        /// "FO · top · week 5"
        public let rubrik: String
        public let markning: Markning?
        /// Du nu: "−2.4" (filens `nu`).
        public let nu: String
        public let enhet: String
        /// Målet som spann: katalogens gröna spann med Du nu som markör; nil för egen baslinje.
        public let mal: Spann?
        public let foljd: [Foljd]
        public let ovning: String
        public let steg: [(namn: String, lage: Steglage)]
        /// Rörligheten när typen inte är ren teknik: testet och övningen.
        public let rorlighet: (test: String, ovning: String?)?
        /// "“Leave the stick standing.”"
        public let tanke: String
        /// "First set ≥ 0 cm"
        public let villkor: String
        /// "2 sessions in a row"
        public let villkorUnder: String

        /// Saken i ord för VoiceOver: namnet, Du nu, målet och veckan.
        public var upplasning: String {
            var d = ["\(namn) \(Tal.medEnhet(nu, enhet))"]
            if let m = mal, !m.upplasning.isEmpty { d.append(m.upplasning) }
            if let m = markning { d.append(m.upplasning) }
            d.append(rubrik)
            return d.joined(separator: ", ")
        }

        /// Hela saken i ord, för en sammanslagen VoiceOver-etikett.
        public var upplasningHel: String {
            var d = [upplasning]
            d += foljd.map { Texter.upplasningFoljd($0.upplasning) }
            d.append(Texter.upplasningOvning(ovning))
            if let nu = steg.first(where: { $0.lage == .nu }) { d.append(Texter.upplasningSteg(nu.namn)) }
            if let r = rorlighet { d.append(Texter.upplasningRorlighet(r.test + (r.ovning.map { ", \($0)" } ?? ""))) }
            d.append(Texter.upplasningTanke(tanke))
            d.append(Texter.upplasningKlartNar("\(villkor), \(villkorUnder)"))
            return d.joined(separator: ". ")
        }
    }

    /// Stegens namn i vyn, i S5:s ordning.
    public static var stegnamn: [String: String] { Texter.stegnamn }

    /// "Nov 3": passet tolkningen bygger på.
    public let fran: String
    public let saker: [Sakvisning]

    public init(_ a: AttJobbaPa, katalog: Katalog) {
        let fel = Dictionary(katalog.fel.map { ($0.id, $0) }, uniquingKeysWith: { x, _ in x })
        fran = a.passDatum.map(Tal.datum) ?? ""

        /// Måttets etikett för ett fel i katalogen, eller filens namn när felet saknas där.
        func etikett(_ id: String, namn: String, enhet: String) -> Mattetikett {
            if let f = fel[id] { return Etiketter.etikett(f.matt) }
            return Mattetikett(namn, enhet, Avrundning.decimaler(enhet: enhet), "")
        }

        saker = a.saker.sorted { $0.ordning < $1.ordning }.map { s -> Sakvisning in
            let e = Etiketter.etikett(s.matt)
            var r = [e.vy ?? Etiketter.vy(s.vy)]
            if !e.fas.isEmpty { r.append(e.fas) }
            r.append(Texter.vecka(s.block.vecka))
            let markning: Markning? = s.markning == "B10" ? .b10 : s.markning == "egen" ? .egen : nil
            var mal: Spann? = nil
            if let nu = s.nu, let g = s.spann {
                mal = Spann(nu: nu, spridning: nil, forra: nil, gront: g, baslinje: nil, decimaler: e.decimaler, enhet: s.enhet)
            }
            let foljd = s.foljdfel.map { f -> Foljd in
                let fe = etikett(f.fel, namn: f.namn, enhet: f.enhet)
                let vag = f.vag.dropFirst().map { id -> String in
                    id == f.fel ? fe.namn : etikett(id, namn: id, enhet: "").namn
                }
                return Foljd(vag: Array(vag), varde: Mattkort.text(f.nu, fe), enhet: f.enhet)
            }
            let iSteg = AttJobbaPa.Ovning.stegen.firstIndex(of: s.ovning.steg) ?? 0
            let steg = AttJobbaPa.Ovning.stegen.enumerated().map { (i, id) -> (namn: String, lage: Steglage) in
                let lage: Steglage = i < iSteg ? .klart : (i == iSteg ? .nu : .kommer)
                return (AttJobbaPaVisning.stegnamn[id] ?? id, lage)
            }
            var rorlighet: (test: String, ovning: String?)? = nil
            if s.typ != "teknik", let f = s.fysik, let test = f.test {
                rorlighet = (test, f.ovning)
            }
            let k = s.klartNar
            let grans: String
            switch k.villkor {
            case .minst: grans = "≥ " + Tal.axel(k.lo, decimaler: e.decimaler)
            case .hogst: grans = "≤ " + Tal.axel(k.hi, decimaler: e.decimaler)
            case .mellan: grans = Tal.axel(k.lo, decimaler: e.decimaler) + "–" + Tal.axel(k.hi, decimaler: e.decimaler)
            }
            return Sakvisning(
                ordning: s.ordning, namn: e.namn, rubrik: r.joined(separator: " · "), markning: markning,
                nu: Mattkort.text(s.nu, e), enhet: s.enhet, mal: mal, foljd: foljd, ovning: s.ovning.text,
                steg: steg, rorlighet: rorlighet, tanke: Texter.citat(s.ovning.tanke),
                villkor: Tal.medEnhet(Texter.forstaSerien(grans), s.enhet),
                villkorUnder: Texter.passIRad(k.passIRad))
        }
    }
}

/// Idag (skissens skärm 1): dagen, senaste passet som rader med ett kompakt spann,
/// och sakerna att jobba på (1–3, ur den senaste `att_jobba_pa.json`) med tanken.
public struct Idagvisning: Sendable {
    public struct Rad: Sendable {
        public let id: String
        public let namn: String
        public let varde: String
        /// Enheten efter talet, utan kvoten ": 1".
        public let enhet: String
        public let spann: Spann
        /// Måttet övas just nu (BESLUT B31).
        public let ovas: Bool

        /// "Sway −2.4 cm, target from 0 cm"
        public var upplasning: String {
            let m = spann.upplasning
            return "\(namn) \(Tal.medEnhet(varde, enhet))" + (m.isEmpty ? "" : ", \(m)")
        }
    }

    /// En sak att jobba på: måttets namn, tanken och kedjan.
    public struct Forsta: Sendable {
        public let namn: String
        public let tanke: String
        /// Saken och dess närmaste följdfel: "Sway", "Side bend", "Hip shift".
        public let kedja: [String]
    }

    /// "Tue, Jan 13"
    public let dag: String
    /// "Sat, Jan 9 · 7i · 34", med hårt mellanslag före punkterna (Texter.skilje)
    public let senaste: String?
    public let rader: [Rad]
    /// Sakerna i svingens ordning (1–3); tom utan `att_jobba_pa.json`.
    public let fokus: [Forsta]
    /// "week 5": den första sakens vecka i blocket; nil utan fokus.
    public let vecka: String?
    /// Den första saken.
    public var forsta: Forsta? { fokus.first }

    public init(idag: Date, katalog: Katalog, pass: [Pass], attJobbaPa: AttJobbaPa?) {
        dag = Tal.dag(idag)
        if let nu = pass.last {
            senaste = [Tal.dag(nu.datum), nu.klubba, "\(nu.slag)"].joined(separator: Texter.skilje)
            let p = Passvisning(katalog: katalog, pass: pass, ovas: attJobbaPa?.ovas ?? [])
            rader = p.kort.compactMap { k -> Rad? in
                guard let s = k.spann else { return nil }
                return Rad(id: k.id, namn: k.namn, varde: k.varde, enhet: k.enhet == ": 1" ? "" : k.enhet, spann: s,
                           ovas: k.ovas)
            }
        } else {
            senaste = nil
            rader = []
        }
        let saker = attJobbaPa.map { AttJobbaPaVisning($0, katalog: katalog).saker } ?? []
        fokus = saker.map { s in
            // Kedjan på en rad: saken och följdfelen ett led bort, högst två.
            let nara = s.foljd.filter { $0.vag.count == 1 }.prefix(2).map { $0.vag[0] }
            return Forsta(namn: s.namn, tanke: s.tanke, kedja: [s.namn] + nara)
        }
        vecka = attJobbaPa?.saker.min { $0.ordning < $1.ordning }.map { Texter.vecka($0.block.vecka) }
    }
}
