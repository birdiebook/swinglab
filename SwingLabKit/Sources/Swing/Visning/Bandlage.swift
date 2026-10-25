import Foundation

/// Läget för ett värde mot bandet (METOD M62, BESLUT B87): grönt innanför, gult utanför men
/// inom måttets brusgolv från gränsen ("kan vara mätfel"), rött längre bort med en pil åt det
/// håll värdet ligger, eller inget (ingen gräns, eller den egna baslinjen utan avvikelse åt det
/// sämre hållet). Samma regler som `lage`, `lage_baslinje` och `lage_for` i tools/pc/katalog.py,
/// prövat mot tools/tests/fixturer/bandlage.json (BESLUT B12).
public struct Bandlage: Equatable, Sendable {
    public enum Lage: String, Sendable {
        case gron, gul, rod, ingen
    }

    /// Värdet ligger över (större än) eller under bandet.
    public enum Riktning: String, Sendable {
        case over, under
    }

    public let lage: Lage
    /// Bara när läget är rött.
    public let pil: Riktning?

    public init(_ lage: Lage, pil: Riktning? = nil) {
        self.lage = lage
        self.pil = pil
    }

    public static let ingen = Bandlage(.ingen)

    /// Gränserna är slutna; flyttalens fel räknas inte. METOD M62
    static let eps = 1e-9

    /// Järnets band gäller på järnpass (BESLUT B86): järnen 4–9 och PW, som id ("j7", "pw") eller
    /// etikett ("7i", "PW"). Okänd klubba räknas som järn, standarden.
    static let jarnen: Set<String> = Set((4...9).flatMap { ["j\($0)", "\($0)i"] } + ["pw"])

    public static func jarn(_ klubba: String?) -> Bool {
        guard let k = klubba, !k.isEmpty else { return true }
        return jarnen.contains(k.lowercased())
    }

    /// Ett värde mot bandet (`gront`, nil i en ände = öppen) och golvet. METOD M62
    public static func lage(_ v: Double, gront: [Double?]?, golv: Double) -> Bandlage {
        guard let g = gront, g.count == 2 else { return .ingen }
        let lo = g[0], hi = g[1]
        if (lo.map { v >= $0 - eps } ?? true) && (hi.map { v <= $0 + eps } ?? true) { return Bandlage(.gron) }
        let d: Double, pil: Riktning
        if let l = lo, v < l {
            d = l - v
            pil = .under
        } else {
            d = v - (hi ?? v)
            pil = .over
        }
        return d <= golv + eps ? Bandlage(.gul) : Bandlage(.rod, pil: pil)
    }

    /// Ett värde mot den egna baslinjen (medianen ± en robust sd, M27), som aldrig blir grön eller
    /// gul (Johannes 2026-10-25): röd med pil bara när måttets sämre håll är känt och värdet ligger
    /// mer än golvet utanför baslinjens ände åt det hållet. METOD M62
    public static func lage(_ v: Double, baslinje: (lo: Double, hi: Double)?, samre: String?, golv: Double?) -> Bandlage {
        guard let b = baslinje, let s = samre, let g = golv else { return .ingen }
        if s == "+" && v > b.hi + g + eps { return Bandlage(.rod, pil: .over) }
        if s == "-" && v < b.lo - g - eps { return Bandlage(.rod, pil: .under) }
        return .ingen
    }

    /// Läget för en post i ett pass med klubban `klubba`: mot bandet när det visas (järnpass),
    /// annars mot den egna baslinjen ur `baslinje` (tidigare värden). Som `lage_for`. METOD M62
    public static func lage(_ v: Double, gront: [Double?]?, golv: Double?, samre: String?, baslinje: [Double],
                            klubba: String?) -> Bandlage {
        if let g = gront, jarn(klubba), let golv { return lage(v, gront: g, golv: golv) }
        return lage(v, baslinje: Baslinje.spann(baslinje), samre: samre, golv: golv)
    }

    /// Ett fel i katalogen (avstängt: inget läge).
    public static func lage(_ fel: Katalog.Fel, _ v: Double, baslinje: [Double] = [], klubba: String?) -> Bandlage {
        guard fel.aktiv else { return .ingen }
        return lage(v, gront: fel.gront, golv: fel.golv, samre: fel.samre, baslinje: baslinje, klubba: klubba)
    }

    public static func lage(_ post: Katalog.Mattpost, _ v: Double, baslinje: [Double] = [], klubba: String?) -> Bandlage {
        lage(v, gront: post.gront, golv: post.golv, samre: post.samre, baslinje: baslinje, klubba: klubba)
    }

    public static func lage(_ post: Katalog.Spridningspost, _ v: Double, baslinje: [Double] = [],
                            klubba: String?) -> Bandlage {
        lage(v, gront: nil, golv: post.golv, samre: post.samre, baslinje: baslinje, klubba: klubba)
    }

    /// Läget i ord för VoiceOver (inga värdeord, B13): "in range", "above range", och mot den
    /// egna baslinjen "above your usual".
    public func upplasning(baslinje: Bool = false) -> String? {
        switch lage {
        case .gron: return Texter.lageInne
        case .gul: return Texter.lageNara
        case .rod:
            if baslinje { return pil == .under ? Texter.lageUnderVanligt : Texter.lageOverVanligt }
            return pil == .under ? Texter.lageUnder : Texter.lageOver
        case .ingen: return nil
        }
    }
}

extension Katalog.Fel {
    /// Felet som det visas i ett pass med klubban `klubba`: järnets band bara på järnpass,
    /// annars utan band (egen baslinje där den finns). BESLUT B86
    public func medKlubba(_ klubba: String?) -> Katalog.Fel {
        guard !Bandlage.jarn(klubba), gront != nil else { return self }
        var f = self
        f.gront = nil
        f.grontDriver = nil
        f.gransHarledd = false
        return f
    }

    /// Felet med klubbans källa när klubban är markerad (BESLUT B88): måttet, positionerna,
    /// bandet, golvet, källan och infobladet ur `klubba`. Som `kalla_for` i tools/pc/katalog.py.
    /// S7 (klubban spårad automatiskt) byter bara vad som räknas som markerat.
    public func medKalla(klubbaMarkerad: Bool) -> Katalog.Fel {
        guard klubbaMarkerad, let k = klubba else { return self }
        var f = self
        f.matt = k.matt
        f.positioner = k.positioner
        f.gront = k.gront
        f.grontDriver = nil
        f.golv = k.golv
        f.kalla = k.kalla
        f.status = k.status
        f.kontrollerad = k.kontrollerad
        f.gransHarledd = k.gransHarledd
        f.vad = k.vad
        f.varfor = k.varfor
        f.tecken = k.tecken
        return f
    }

    /// Felet visas för spelaren: inte dom (b), utom när det övas (det Claude valt syns). BESLUT B86
    public func visas(ovas: Set<String>) -> Bool { visas || ovas.contains(id) }
}

extension Katalog.Mattpost {
    /// Måttet som det visas i ett pass med klubban `klubba`: bandet bara på järnpass. BESLUT B86
    public func band(_ klubba: String?) -> [Double?]? { Bandlage.jarn(klubba) ? gront : nil }
}

extension Katalog {
    /// Det sessionen i vyn `vy` visar för spelaren (BESLUT B64, B86): felens id och måttens namn
    /// i katalogens ordning, utan `visas: false`, och spridningens kort. Som `visade` i Python.
    public func visade(i vy: Vy) -> [String] {
        fel.filter { $0.visas && Vyfilter.visas($0.vy, i: vy) }.map(\.id)
            + matt.filter { $0.visas && $0.vy == vy.rawValue }.map(\.matt)
            + spridning.filter { $0.vy == vy.rawValue }.map(\.id)
    }

    /// Felen med en källa ur klubban (over the top, BESLUT B88) och klubbmåttet som de tar.
    public func klubbkallor(_ vy: Vy) -> Set<String> {
        Set(fel.filter { $0.vy == vy.rawValue }.compactMap { $0.klubba?.matt })
    }
}
