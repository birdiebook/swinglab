import Foundation

/// Ett mått över passen (skärmen Utveckling): passets median, serie 1 under den,
/// gränsen eller den egna baslinjen som band, månaderna och träningsblocken.
public struct Utveckling: Sendable {
    public struct Passpunkt: Equatable, Sendable {
        public let datum: Date
        public let pass: Double
        /// Serie 1:s median, nil när passet saknar serie 1.
        public let serie1: Double?
        /// Passets spridning, kvartilerna (METOD M25); nil under tre svingar.
        public var q1: Double? = nil
        public var q3: Double? = nil
    }

    public enum Band: Equatable, Sendable {
        case grans(lo: Double, hi: Double)
        case baslinje(lo: Double, hi: Double)
        /// 3D utan markörer (S6c-2): passmedianens ungefärliga fel, ± grader runt varje punkt,
        /// ur felbudgeten (METOD MK7, MS19). Ingen gräns och ingen baslinje (BESLUT B14, B37).
        case fel(Double)
    }

    /// Passmedianens SD för kedjan med typiskt brus (S6_FELBUDGET §6.7, METOD MK7: golvet / √2),
    /// grader. Progress ritar den som ett tunt spann runt varje 3D-punkt. METOD MS19
    public static let felband3D = ["backen_vrid_topp": 11.1, "brost_vrid_topp": 9.7, "xfaktor_topp": 13.6,
                                   "xfaktor_stretch": 5.7, "hofter_oppna_traff": 6.0]

    public let id: String
    public let namn: String
    /// "FO · top"
    public let rubrik: String
    /// "7i · Nov–Jan · 6": klubban, månaderna och antalet pass med en punkt i måttet.
    public let period: String
    public let markning: Markning?
    /// Senaste passet: "−2.4"
    public let varde: String
    public let enhet: String
    /// "+5.5 cm vs Oct 20": senaste mot första passet i serien.
    public let skillnad: String?
    public let punkter: [Passpunkt]
    public let band: Band?
    public let axel: Axel
    public let axelText: [(varde: Double, text: String)]
    /// Månaderna under diagrammet: passets plats och "Oct".
    public let manader: [(index: Int, text: String)]
    /// Blockens gränser: mellan passet före och passet `index`, och "B2".
    public let block: [(index: Int, text: String)]
    public var harSerie1: Bool { punkter.contains { $0.serie1 != nil } }
    /// Måttet övas just nu: linjen bär accenten (BESLUT B31).
    public var ovas = false
    /// Infobladet som ⓘ öppnar (BESLUT B41).
    public let info: Infoblad

    /// `block` = blockens första dagar, äldst först.
    public init(_ fel: Katalog.Fel, pass: [Pass], block: [Date] = []) {
        let e = Etiketter.etikett(fel.matt)
        let grupp = fel.grupp
        var r = [e.vy ?? Etiketter.vy(fel.vy)]
        if !e.fas.isEmpty { r.append(e.fas) }
        let punkter = pass.compactMap { p -> Passpunkt? in
            guard let s = p.sammanfattning(fel.matt, grupp) else { return nil }
            return Passpunkt(datum: p.datum, pass: s.median, serie1: p.serie1Median(fel.matt, grupp), q1: s.q1, q3: s.q3)
        }
        let band: Band?
        if let g = fel.gront, g.count == 2 {
            band = .grans(lo: g[0] ?? -Double.infinity, hi: g[1] ?? Double.infinity)
        } else if let sista = pass.lastIndex(where: { $0.sammanfattning(fel.matt, grupp) != nil }),
                  let b = Baslinje.spann(pass[..<sista].flatMap { $0.varden(fel.matt, grupp) }) {
            // Baslinjen ur passen före måttets sista punkt, så att den aldrig rymmer punkten
            // själv (ett DTL-pass sist ändrar inte ett FO-mått). METOD M27, MS16
            band = .baslinje(lo: b.lo, hi: b.hi)
        } else {
            band = nil
        }
        self.init(id: fel.id, matt: fel.matt, namn: e.namn, rubrik: r.joined(separator: " · "),
                  markning: Markning.fran(fel), info: Infoblad(fel, namn: e.namn), punkter: punkter, band: band,
                  klubba: pass.last?.klubba, block: block)
    }

    /// Passets spridning mellan slagen över passen (METOD M44, BESLUT B46): en punkt per pass,
    /// utan kvartiler och serie 1, och de tidigare passens spridning som egen baslinje.
    public init(_ post: Katalog.Spridningspost, pass: [Pass], block: [Date] = []) {
        let e = Etiketter.etikett(post.matt)
        // Valet i Progress är ett chip med bara namnet: positionen skiljer adressens och
        // träffens spridning åt ("Spine angle spread at impact", BESLUT B40).
        let namn = Texter.felnamn(Texter.spridningsnamn(e.namn), fas: e.fas)
        let punkter = pass.compactMap { p -> Passpunkt? in
            p.spridning(post.matt, post.vy).map { Passpunkt(datum: p.datum, pass: $0, serie1: nil) }
        }
        var band: Band? = nil
        if let b = Baslinje.spann(punkter.dropLast().map(\.pass)) {
            band = .baslinje(lo: b.lo, hi: b.hi)
        }
        self.init(id: post.id, matt: post.matt, namn: namn, rubrik: Mattkort.rubrik(post), markning: .egen,
                  info: Infoblad(post, namn: namn), punkter: punkter, band: band, klubba: pass.last?.klubba,
                  block: block)
    }

    /// Ett 3D-mått över passen (S6c-2, BESLUT B62): en punkt per pass med 3D och en median
    /// (minst `min_slag` slag, METOD MK7), rubriken "3D · no markers", inget serie 1, inga
    /// kvartiler och ingen gräns: bara felbandet runt punkterna (BESLUT B14, B37).
    public init(_ post: Katalog.TreDPost, pass: [Pass], block: [Date] = []) {
        let namn = Etiketter.etikett(post.matt).namn
        let punkter = pass.compactMap { p -> Passpunkt? in
            guard let m = p.treD[post.matt], m.n >= post.minSlag, let v = m.median, v.isFinite else { return nil }
            return Passpunkt(datum: p.datum, pass: v, serie1: nil)
        }
        self.init(id: post.id, matt: post.matt, namn: namn, rubrik: Texter.treDRubrik, markning: nil,
                  info: Infoblad(post, namn: namn), punkter: punkter,
                  band: Utveckling.felband3D[post.matt].map { Band.fel($0) }, klubba: pass.last?.klubba, block: block)
    }

    /// Det gemensamma: talet nu, skillnaden mot första passet, axeln, månaderna och blocken.
    init(id: String, matt: String, namn: String, rubrik: String, markning: Markning?, info: Infoblad,
         punkter: [Passpunkt], band: Band?, klubba: String?, block: [Date]) {
        let e = Etiketter.etikett(matt)
        self.id = id
        self.namn = namn
        self.info = info
        self.rubrik = rubrik
        self.markning = markning
        enhet = e.enhet
        self.punkter = punkter
        self.band = band
        period = Utvecklingsvisning.periodText(klubba: klubba, datum: punkter.map(\.datum))
        varde = Mattkort.text(punkter.last?.pass, e)
        if let a = punkter.first, let b = punkter.last, punkter.count > 1 {
            let d = Avrundning.avrunda(matt, b.pass)! - Avrundning.avrunda(matt, a.pass)!
            skillnad = Texter.mot(Tal.medEnhet(Tal.tecken(d, decimaler: e.decimaler), e.enhet), Tal.datum(a.datum))
        } else {
            skillnad = nil
        }
        var varden = punkter.map(\.pass) + punkter.compactMap(\.serie1) + punkter.compactMap(\.q1)
            + punkter.compactMap(\.q3)
        // Bandet syns när det ligger nära; ett långt bort drar inte ut axeln mer än en tredjedel.
        let lo0 = varden.min() ?? 0, hi0 = varden.max() ?? 1
        let ra = Swift.max(hi0 - lo0, 1e-9)
        switch band {
        case let .grans(lo, hi), let .baslinje(lo, hi):
            for v in [lo, hi] where v.isFinite {
                varden.append(Swift.min(hi0 + ra * 0.33, Swift.max(lo0 - ra * 0.33, v)))
            }
        case let .fel(sd):
            // Felbandet hör till punkterna: axeln rymmer det helt.
            varden += punkter.flatMap { [$0.pass - sd, $0.pass + sd] }
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
    /// "7i · Oct–Jan · 16" över alla passen; skärmen visar det valda måttets (`Utveckling.period`).
    public let period: String
    /// "1 not measured · 2 at another height": pass med samma klubba som inte är med
    /// (METOD MS16); nil när alla är med.
    public let ejMatta: String?
    public let matt: [Utveckling]

    /// `pass` äldst först, med samma klubba. `ejMatta` = passen med samma klubba utan mått,
    /// `annanLangd` = de mätta med en annan längd (METOD MS16).
    public init(katalog: Katalog, pass: [Pass], block: [Date] = [], ovas: Set<String> = [], ejMatta: Int = 0,
                annanLangd: Int = 0) {
        period = Self.periodText(klubba: pass.last?.klubba, datum: pass.map(\.datum))
        let delar = (ejMatta > 0 ? [Texter.ejMatta(ejMatta)] : []) + (annanLangd > 0 ? [Texter.annanLangd(annanLangd)] : [])
        self.ejMatta = delar.isEmpty ? nil : delar.joined(separator: Texter.skilje)
        // Dom (b) visas inte utom när felet övas, och ett band som klubban flyttar bara på järn
        // (BESLUT B86). Över passen står felets eget mått (händernas bana för over the top, B88).
        let fel = katalog.fel.filter { $0.aktiv && $0.visas(ovas: ovas) }.map { f -> Utveckling in
            var u = Utveckling(f.medKlubba(pass.last?.klubba), pass: pass, block: block)
            u.ovas = ovas.contains(f.id)
            return u
        }
        // Spridningen mellan slagen efter felen (METOD M44, BESLUT B46).
        let spridning = katalog.spridning.map { Utveckling($0, pass: pass, block: block) }
        // 3D sist, bara när något pass har 3D (S6c-2, BESLUT B62).
        let treD = katalog.treD.map { Utveckling($0, pass: pass, block: block) }
        matt = (fel + spridning + treD).filter { !$0.punkter.isEmpty }
    }

    /// "7i · Oct–Jan · 16": klubban, månaderna och antalet ("Jan" inom en månad); "" utan datum.
    static func periodText(klubba: String?, datum: [Date]) -> String {
        guard let a = datum.first, let b = datum.last else { return "" }
        let ma = Tal.manad(a), mb = Tal.manad(b)
        let manader = ma == mb && b.timeIntervalSince(a) < 60 * 86_400 ? ma : "\(ma)–\(mb)"
        return ([klubba].compactMap { $0 } + [manader, "\(datum.count)"]).joined(separator: Texter.skilje)
    }
}
