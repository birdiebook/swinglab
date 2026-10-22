import Foundation

/// Ett mått över passen (skärmen Utveckling): passets median, serie 1 under den,
/// gränsen eller den egna baslinjen som band, månaderna och träningsblocken.
public struct Utveckling: Sendable {
    public struct Passpunkt: Equatable, Sendable {
        public let datum: Date
        public let pass: Double
        /// Serie 1:s median, nil när passet saknar serie 1.
        public let serie1: Double?
    }

    public enum Band: Equatable, Sendable {
        case grans(lo: Double, hi: Double)
        case baslinje(lo: Double, hi: Double)
    }

    public let id: String
    public let namn: String
    /// "FO · topp"
    public let rubrik: String
    public let markning: Markning?
    /// Senaste passet: "−2,4"
    public let varde: String
    public let enhet: String
    /// "+5,5 cm mot 20 okt": senaste mot första passet i serien.
    public let skillnad: String?
    public let punkter: [Passpunkt]
    public let band: Band?
    public let axel: Axel
    public let axelText: [(varde: Double, text: String)]
    /// Månaderna under diagrammet: passets plats och "okt".
    public let manader: [(index: Int, text: String)]
    /// Blockens gränser: mellan passet före och passet `index`, och "B2".
    public let block: [(index: Int, text: String)]
    public var harSerie1: Bool { punkter.contains { $0.serie1 != nil } }
    /// Måttet övas just nu: linjen bär accenten (BESLUT B31).
    public var ovas = false

    /// `block` = blockens första dagar, äldst först.
    public init(_ fel: Katalog.Fel, pass: [Pass], block: [Date] = []) {
        let e = Etiketter.etikett(fel.matt)
        let grupp = fel.grupp
        id = fel.id
        namn = e.namn
        var r = [e.vy ?? Etiketter.vy(fel.vy)]
        if !e.fas.isEmpty { r.append(e.fas) }
        rubrik = r.joined(separator: " · ")
        markning = Markning.fran(fel)
        enhet = e.enhet
        punkter = pass.compactMap { p -> Passpunkt? in
            guard let m = p.median(fel.matt, grupp) else { return nil }
            return Passpunkt(datum: p.datum, pass: m, serie1: p.serie1Median(fel.matt, grupp))
        }
        varde = Mattkort.text(punkter.last?.pass, e)
        if let a = punkter.first, let b = punkter.last, punkter.count > 1 {
            let d = Avrundning.avrunda(fel.matt, b.pass)! - Avrundning.avrunda(fel.matt, a.pass)!
            skillnad = Tal.medEnhet(Tal.tecken(d, decimaler: e.decimaler), e.enhet) + " mot " + Tal.datum(a.datum)
        } else {
            skillnad = nil
        }
        if let g = fel.gront, g.count == 2 {
            band = .grans(lo: g[0] ?? -Double.infinity, hi: g[1] ?? Double.infinity)
        } else if let b = Baslinje.spann(pass.dropLast().flatMap { $0.varden(fel.matt, grupp) }) {
            band = .baslinje(lo: b.lo, hi: b.hi)
        } else {
            band = nil
        }
        var varden = punkter.map(\.pass) + punkter.compactMap(\.serie1)
        // Bandet syns när det ligger nära; ett långt bort drar inte ut axeln mer än en tredjedel.
        let lo0 = varden.min() ?? 0, hi0 = varden.max() ?? 1
        let ra = Swift.max(hi0 - lo0, 1e-9)
        switch band {
        case let .grans(lo, hi), let .baslinje(lo, hi):
            for v in [lo, hi] where v.isFinite {
                varden.append(Swift.min(hi0 + ra * 0.33, Swift.max(lo0 - ra * 0.33, v)))
            }
        case nil:
            break
        }
        axel = Axel.runt(varden, delar: 4, marginal: 0.08)
        axelText = axel.streck.map { ($0, Tal.axel($0, decimaler: e.decimaler)) }
        var man: [(index: Int, text: String)] = []
        for (i, p) in punkter.enumerated() {
            let t = Tal.manad(p.datum)
            if man.last?.text != t { man.append((i, t)) }
        }
        manader = man
        var bl: [(index: Int, text: String)] = []
        for (n, start) in block.enumerated() {
            if let i = punkter.firstIndex(where: { $0.datum >= start }), i > 0 {
                bl.append((i, "B\(n + 1)"))
            }
        }
        self.block = bl
    }
}

/// Skärmen Utveckling: perioden, måtten att välja bland och det valda måttet.
public struct Utvecklingsvisning: Sendable {
    /// "okt–jan · 16"
    public let period: String
    public let matt: [Utveckling]

    public init(katalog: Katalog, pass: [Pass], block: [Date] = [], ovas: Set<String> = []) {
        if let a = pass.first, let b = pass.last {
            period = "\(Tal.manad(a.datum))–\(Tal.manad(b.datum)) · \(pass.count)"
        } else {
            period = ""
        }
        matt = katalog.fel.filter { $0.aktiv }.map { f -> Utveckling in
            var u = Utveckling(f, pass: pass, block: block)
            u.ovas = ovas.contains(f.id)
            return u
        }.filter { !$0.punkter.isEmpty }
    }
}
