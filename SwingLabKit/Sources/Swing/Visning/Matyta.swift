import Foundation

/// Granskningens mätyta (BESLUT B13, regel 2): bara de uppmätta linjerna och
/// punkterna över en neutral videoyta, och måttet över hela svingen. Räknas på
/// samma utjämnade leder och samma skala som Matt.mat, så talet i ett ögonblick
/// är det mått som Matt ger i fasen. FO visar bäckenets sway (METOD M15), DTL
/// bäckenets thrust (METOD M7); båda är bäckenets mitt längs x mot adressen.
public struct Matyta: Sendable {
    /// Ett ögonblick: lederna i cm från adressens bäckenmitt, x mot målet eller
    /// bollen och y uppåt, och måttet.
    public struct Lage: Equatable, Sendable {
        public let hoftF: Punkt
        public let hoftB: Punkt
        public let backen: Punkt
        public let axlar: Punkt
        /// cm, + mot målet (FO) eller bollen (DTL).
        public let matt: Double
    }

    public let vy: Vy
    /// "Sway" eller "Thrust".
    public let namn: String
    public let faser: Fastider
    public let cmPerPx: Double
    let t: [Double]
    let hoftF: [Punkt]
    let hoftB: [Punkt]
    let axlar: [Punkt]
    /// Bäckenets mitt i adressen, px.
    let noll: Punkt

    public init(sving s: Sving, resultat r: SvingResultat) {
        vy = s.vy
        namn = s.vy == .fo ? Texter.sway : Texter.thrust
        faser = r.faser
        cmPerPx = r.cmPerPx
        t = s.t
        // Samma utjämning som Matt.mat. METOD M3
        let j = { (l: Led) in Faser.jamna(s.t, s.led(l)) }
        hoftF = j(.hoftF)
        hoftB = j(.hoftB)
        axlar = zip(j(.axelF), j(.axelB)).map { Punkt.mitt($0, $1) }
        let mitt = zip(hoftF, hoftB).map { Punkt.mitt($0, $1) }
        noll = Faser.lage(s.t, mitt, r.faser, .adress)
    }

    /// Fasernas ögonblick: mitten av adressens och finishens fönster, toppen och träffen.
    public var fastider: [(fas: Fas, t: Double)] {
        [(.adress, (faser.adressFran + faser.adressTill) / 2), (.topp, faser.topp), (.traff, faser.traff),
         (.finish, (faser.finishFran + faser.finishTill) / 2)]
    }

    /// Ögonblicket i `annan` som motsvarar `tc` här: styckvis linjärt mellan faserna
    /// (adress, topp, träff, finish), och med samma förskjutning som den närmaste fasen
    /// utanför dem. Två svingar jämförs fas för fas, inte på samma klipptid.
    public func motsvarande(_ tc: Double, i annan: Matyta) -> Double {
        let a = fastider.map { $0.t }, b = annan.fastider.map { $0.t }
        if tc <= a[0] { return b[0] + (tc - a[0]) }
        for i in 0..<(a.count - 1) where tc <= a[i + 1] {
            let u = a[i + 1] > a[i] ? (tc - a[i]) / (a[i + 1] - a[i]) : 0
            return b[i] + u * (b[i + 1] - b[i])
        }
        return b[b.count - 1] + (tc - a[a.count - 1])
    }

    /// Tiden som visas: från klippets början.
    public var start: Double { t.first ?? 0 }

    /// Tidslinjens ände: adressen till finishen.
    public var fran: Double { faser.adressFran }
    public var till: Double { faser.finishTill }

    /// px → cm från adressens bäckenmitt, y uppåt.
    func cm(_ p: Punkt) -> Punkt {
        Punkt((p.x - noll.x) * cmPerPx, -(p.y - noll.y) * cmPerPx)
    }

    /// Lederna och måttet i ögonblicket tc, nil där en led saknas.
    public func lage(_ tc: Double) -> Lage? {
        let f = Faser.vid(t, hoftF, tc), b = Faser.vid(t, hoftB, tc), a = Faser.vid(t, axlar, tc)
        guard f.hel, b.hel, a.hel, noll.hel else { return nil }
        let m = cm(Punkt.mitt(f, b))
        return Lage(hoftF: cm(f), hoftB: cm(b), backen: m, axlar: cm(a), matt: m.x)
    }

    /// Lederna i fasen, som Matt.mat ser dem (medel över adressens och finishens fönster).
    public func lage(_ fas: Fas) -> Lage? {
        switch fas {
        case .topp: return lage(faser.topp)
        case .traff: return lage(faser.traff)
        case .adress, .finish:
            let f = Faser.lage(t, hoftF, faser, fas), b = Faser.lage(t, hoftB, faser, fas)
            let a = Faser.lage(t, axlar, faser, fas)
            guard f.hel, b.hel, a.hel, noll.hel else { return nil }
            let m = cm(Punkt.mitt(f, b))
            return Lage(hoftF: cm(f), hoftB: cm(b), backen: m, axlar: cm(a), matt: m.x)
        }
    }

    /// Måttet över tidslinjen, var `steg` s.
    public func kurva(steg: Double = 0.01) -> [(t: Double, v: Double)] {
        var ut: [(t: Double, v: Double)] = []
        var tc = fran
        while tc <= till + 1e-9 {
            if let l = lage(tc) { ut.append((tc, l.matt)) }
            tc += steg
        }
        return ut
    }

    /// Tiden som text: "1.45 s" från klippets början.
    public func tidText(_ tc: Double) -> String {
        Tal.tal(tc - start, decimaler: 2) + " s"
    }
}

/// Granskningens skärm, färdig att rita: ytan, ögonblicket och slagen.
public struct Granskningsvisning: Sendable {
    public struct Slag: Equatable, Sendable {
        /// nil = passets median.
        public let nr: Int?
        public let text: String
    }

    public let yta: Matyta
    /// Förra passets mediansving i samma vy, för jämförelsen.
    public let forra: Matyta?
    /// "Jan 6"
    public let forraDatum: String?
    public let slag: [Slag]
    /// Måttet på ytan övas just nu: den uppmätta linjen bär accenten (BESLUT B31).
    public var ovas = false

    /// `matt` = måttet för slagknapparna (backen_sway_topp eller backen_thrust_traff).
    public init(yta: Matyta, forra: Matyta?, forraDatum: Date?, pass: Pass, matt: String) {
        self.yta = yta
        self.forra = forra
        self.forraDatum = forraDatum.map(Tal.datum)
        let e = Etiketter.etikett(matt)
        let grupp = yta.vy.rawValue
        var s = [Slag(nr: nil, text: Mattkort.text(pass.median(matt, grupp), e))]
        for (i, v) in pass.grupp(grupp).enumerated() {
            s.append(Slag(nr: i + 1, text: Mattkort.text(v.matt[matt], e)))
        }
        slag = s
    }

    /// Måttet som slagknapparna visar i vyn.
    public static func matt(_ vy: Vy) -> String { vy == .fo ? "backen_sway_topp" : "backen_thrust_traff" }
}
