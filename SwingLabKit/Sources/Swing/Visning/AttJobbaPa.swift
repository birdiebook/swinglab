import Foundation

/// Det PC:n och Claude valt att jobba på (PLAN S5), som vyn behöver det. Filens
/// format (`att_jobba_pa.json`) ägs av S5; det här är vyns indata.
public struct AttJobbaPa: Sendable {
    public enum Riktning: String, Sendable {
        case minst, hogst

        public var tecken: String { self == .minst ? "≥" : "≤" }
    }

    /// "Klart när" som ett villkor i tal: måttets median i serie 1 ska ligga på
    /// rätt sida om gränsen i så många pass i rad (PLAN S5).
    public struct KlartNar: Sendable {
        public let fel: String
        public let riktning: Riktning
        public let grans: Double
        public let passIRad: Int

        public init(fel: String, riktning: Riktning, grans: Double, passIRad: Int) {
            self.fel = fel
            self.riktning = riktning
            self.grans = grans
            self.passIRad = passIRad
        }
    }

    /// Temat: "Bäckenets väg".
    public let tema: String
    public let block: Int
    /// Blockets första dag; kedjans "från" räknas därifrån.
    public let blockFran: Date
    /// Felen i kedjan, i svingens ordning, det första först (1–3 st).
    public let kedja: [String]
    public let ovning: String
    /// Övningens steg, och steget som pågår (0 först).
    public let steg: [String]
    public let stegNu: Int
    public let tanke: String
    public let klartNar: KlartNar

    public init(tema: String, block: Int, blockFran: Date, kedja: [String], ovning: String, steg: [String],
                stegNu: Int, tanke: String, klartNar: KlartNar) {
        self.tema = tema
        self.block = block
        self.blockFran = blockFran
        self.kedja = kedja
        self.ovning = ovning
        self.steg = steg
        self.stegNu = stegNu
        self.tanke = tanke
        self.klartNar = klartNar
    }
}

/// Skärmen Att jobba på, färdig att rita.
public struct AttJobbaPaVisning: Sendable {
    public struct Lank: Equatable, Sendable {
        public let namn: String
        /// "−2,4"
        public let varde: String
        public let enhet: String
        /// "−6,8 → −2,4": blockets första pass till nu.
        public let fran: String
    }

    public enum Steglage: Sendable { case klart, nu, kommer }

    public let tema: String
    /// "block 2 · v 5"
    public let block: String
    public let kedja: [Lank]
    public let ovning: String
    public let steg: [(namn: String, lage: Steglage)]
    /// "”Rör inte käppen.”"
    public let tanke: String
    /// "Sway topp ≥ 0,0 cm"
    public let villkor: String
    /// "serie 1 · 2 pass i rad"
    public let villkorUnder: String
    /// Serie 1 och passet nu, och passen i rad som håller villkoret.
    public let serie1: String
    public let passet: String
    public let enhet: String
    public let iRad: Int
    public let iRadKrav: Int

    public init(_ a: AttJobbaPa, katalog: Katalog, pass: [Pass]) {
        let fel = Dictionary(katalog.fel.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let nu = pass.last
        let iBlocket = pass.filter { $0.datum >= a.blockFran }
        tema = a.tema
        let vecka = nu.map { Swift.max(1, Int(($0.datum.timeIntervalSince(a.blockFran) / (7 * 86400)).rounded(.down)) + 1) } ?? 1
        block = "block \(a.block) · v \(vecka)"
        kedja = a.kedja.compactMap { id -> Lank? in
            guard let f = fel[id] else { return nil }
            let e = Etiketter.etikett(f.matt)
            let v = nu?.median(f.matt, f.grupp)
            let forst = iBlocket.first?.median(f.matt, f.grupp)
            return Lank(namn: e.namn, varde: Mattkort.text(v, e), enhet: e.enhet,
                        fran: "\(Mattkort.text(forst, e)) → \(Mattkort.text(v, e))")
        }
        ovning = a.ovning
        steg = a.steg.enumerated().map { (i, s) -> (namn: String, lage: Steglage) in
            let lage: Steglage = i < a.stegNu ? .klart : (i == a.stegNu ? .nu : .kommer)
            return (s, lage)
        }
        tanke = "”\(a.tanke)”"

        let k = a.klartNar
        let f = fel[k.fel]
        let e = Etiketter.etikett(f?.matt ?? "")
        let grupp = f?.grupp ?? "alla"
        let matt = f?.matt ?? ""
        let fasText = e.fas.isEmpty ? "" : " \(e.fas)"
        villkor = Tal.medEnhet("\(e.namn)\(fasText) \(k.riktning.tecken) \(Tal.tal(k.grans, decimaler: e.decimaler))", e.enhet)
        villkorUnder = "serie 1 · \(k.passIRad) pass i rad"
        enhet = e.enhet
        serie1 = Mattkort.text(nu?.serie1Median(matt, grupp), e)
        passet = Mattkort.text(nu?.median(matt, grupp), e)
        iRad = AttJobbaPaVisning.iRad(k, matt: matt, grupp: grupp, pass: pass)
        iRadKrav = k.passIRad
    }

    /// Passen i rad, från det senaste och bakåt, där serie 1 håller villkoret.
    public static func iRad(_ k: AttJobbaPa.KlartNar, matt: String, grupp: String, pass: [Pass]) -> Int {
        var n = 0
        for p in pass.reversed() {
            guard let v = p.serie1Median(matt, grupp) else { break }
            let haller = k.riktning == .minst ? v >= k.grans : v <= k.grans
            guard haller else { break }
            n += 1
        }
        return n
    }
}
