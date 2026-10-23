import Capture
import Foundation
import Swing

/// Ett kameraformat: lagrad bredd och höjd (liggande) och vågrätt synfält i grader. METOD MK3
public struct Synfalt: Equatable, Sendable {
    public var bredd: Int
    public var hojd: Int
    public var grader: Double

    public init(bredd: Int, hojd: Int, grader: Double) {
        self.bredd = bredd
        self.hojd = hojd
        self.grader = grader
    }

    /// Ett synfält utanför det är fel och räknas som saknat. METOD MK3
    public static let tillatet = 10.0...170.0
}

/// En serie i en telefons paket, så långt 3D läser den.
public struct TreDSerie: Equatable, Sendable {
    public var nr: Int
    /// Uppåt (−gravitationen) i kamerans ram i den upprätta bilden, när fältet gick att
    /// använda. METOD MK3, MS17
    public var lodlinje: [Double]?
    /// Lodlinjen fanns men gick inte att använda: skälet, utan värden (BESLUT B39).
    public var lodlinjeFel: String?
    public var synfalt: Synfalt?

    public init(nr: Int, lodlinje: [Double]? = nil, lodlinjeFel: String? = nil, synfalt: Synfalt? = nil) {
        self.nr = nr
        self.lodlinje = lodlinje
        self.lodlinjeFel = lodlinjeFel
        self.synfalt = synfalt
    }
}

/// Ett slag i en telefons paket: klicket, träffen, domen och lederna.
public struct TreDSlag: Equatable, Sendable {
    public var id: String
    public var serie: Int
    /// "sving", "inte_sving" eller "osaker". METOD MT1
    public var dom: String
    public var klickS: Double
    public var traffS: Double?
    public var detectionWrong: Bool
    public var lederna: JointSeries?

    public init(id: String, serie: Int, dom: String, klickS: Double, traffS: Double?, detectionWrong: Bool = false,
                lederna: JointSeries?) {
        self.id = id
        self.serie = serie
        self.dom = dom
        self.klickS = klickS
        self.traffS = traffS
        self.detectionWrong = detectionWrong
        self.lederna = lederna
    }
}

/// par.json så långt 3D läser den (S2g, FORMAT.md "Två telefoner"). METOD MK1
public struct ParFil: Equatable, Sendable {
    public struct Rad: Equatable, Sendable {
        public var serie: Int
        public var forskjutningS: Double
        public var osaker: Bool
        public var foljareVy: Vy
        public var foljarePass: String
        public var foljareSerie: Int
    }

    public var vy: Vy
    public var pass: String
    public var serier: [Rad]
}

/// En telefons paket för ett pass, så långt 3D läser det (Python: paket.Paket).
public struct TreDPaket: Equatable, Sendable {
    public var passID: String
    public var vy: Vy
    public var spelhand: Hand
    public var avstandM: Double?
    public var serier: [Int: TreDSerie]
    /// Slagen efter serie och klick (den första vid lika), som paket.las.
    public var slag: [TreDSlag]
    public var par: ParFil?
    /// par.json fanns men gick inte att läsa: skälet utan värden. METOD MK1
    public var parFel: String?
    /// enhet.json:s valda format, när serien inte bär sitt synfält. METOD MK3
    public var enhetSynfalt: Synfalt?

    public init(passID: String, vy: Vy, spelhand: Hand, avstandM: Double?, serier: [Int: TreDSerie], slag: [TreDSlag],
                par: ParFil? = nil, parFel: String? = nil, enhetSynfalt: Synfalt? = nil) {
        self.passID = passID
        self.vy = vy
        self.spelhand = spelhand
        self.avstandM = avstandM
        self.serier = serier
        let ordning = slag.indices.sorted {
            (slag[$0].serie, slag[$0].klickS, $0) < (slag[$1].serie, slag[$1].klickS, $1)
        }
        self.slag = ordning.map { slag[$0] }
        self.par = par
        self.parFel = parFel
        self.enhetSynfalt = enhetSynfalt
    }
}

/// Formfel i manifestet (3D läser inte ett paket som PC:n inte heller läser). Nämner
/// fältet, aldrig värdet.
public struct TreDPaketFel: Error, Equatable {
    public var skal: String
}

extension TreDPaket {
    /// Lodlinjens längd i g (accelerometern i vila). METOD MK3, BESLUT B39
    public static let lodlinjeG = 0.8...1.2

    /// Paketet ur dess filer: manifest.json, par.json och enhet.json (valfria) och
    /// lederna per slag-id. Lodlinjen, synfältet och par.json läses som paket.py gör:
    /// det som inte går att använda blir ett skäl, inte ett stopp. METOD MK1, MK3
    public static func las(manifest: Data, lederna: [String: JointSeries], par: Data? = nil,
                           enhet: Data? = nil) throws -> TreDPaket {
        guard let m = try? JSONSerialization.jsonObject(with: manifest) as? [String: Any] else {
            throw TreDPaketFel(skal: "manifest.json är inte ett JSON-objekt")
        }
        return try las(manifest: m, lederna: lederna, par: par, enhet: enhet)
    }

    /// Som `las(manifest:…)` med manifestet redan läst som JSON-objekt.
    public static func las(manifest m: [String: Any], lederna: [String: JointSeries], par: Data? = nil,
                           enhet: Data? = nil) throws -> TreDPaket {
        guard let pass = m["pass"] as? String, let vy = (m["vy"] as? String).flatMap(Vy.init(rawValue:)),
              let hand = (m["spelhand"] as? String).flatMap(Hand.init(rawValue:)),
              let serier = m["serier"] as? [[String: Any]], let slag = m["slag"] as? [[String: Any]] else {
            throw TreDPaketFel(skal: "manifest.json saknar pass, vy, spelhand, serier eller slag")
        }
        var ut: [Int: TreDSerie] = [:]
        for s in serier {
            guard let nr = heltal(s["nr"]) else { throw TreDPaketFel(skal: "manifest.json: serier[].nr") }
            let (lod, fel) = lodlinjen(s["lodlinje"], nr)
            ut[nr] = TreDSerie(nr: nr, lodlinje: lod, lodlinjeFel: fel, synfalt: synfalt(s["format"]))
        }
        var lista: [TreDSlag] = []
        for s in slag {
            guard let id = s["id"] as? String, let serie = heltal(s["serie"]), let dom = s["dom"] as? String,
                  let klick = tal(s["klick_s"]) else {
                throw TreDPaketFel(skal: "manifest.json: slag[] saknar id, serie, dom eller klick_s")
            }
            lista.append(TreDSlag(id: id, serie: serie, dom: dom, klickS: klick, traffS: tal(s["traff_s"]),
                                  detectionWrong: (s["detection_wrong"] as? Bool) == true, lederna: lederna[id]))
        }
        var enhetSF: Synfalt?
        if let enhet, let e = try? JSONSerialization.jsonObject(with: enhet) as? [String: Any],
           let format = e["format"] as? [[String: Any]] {
            let valt = heltal(e["valt_index"])
            if let f = format.first(where: { heltal($0["index"]) == valt && valt != nil }) {
                enhetSF = synfalt(f)
            }
        }
        var parFil: ParFil?
        var parFel: String?
        if let par {
            switch lasPar(par) {
            case .success(let p): parFil = p
            case .failure(let f): parFel = f.skal
            }
        }
        return TreDPaket(passID: pass, vy: vy, spelhand: hand, avstandM: tal(m["avstand_m"]), serier: ut,
                         slag: lista, par: parFil, parFel: parFel, enhetSynfalt: enhetSF)
    }

    /// Ett ändligt tal.
    static func tal(_ v: Any?) -> Double? {
        guard let n = v as? NSNumber else { return nil }
        let d = n.doubleValue
        return d.isFinite ? d : nil
    }

    static func heltal(_ v: Any?) -> Int? {
        guard let d = tal(v), d == d.rounded(), abs(d) < 1e15 else { return nil }
        return Int(d)
    }

    /// Seriens `lodlinje`: tre tal, längd 0,8–1,2 g och uppåt mot bildens överkant
    /// (y < 0). Annars nil och skälet utan värden, som paket.lodlinjen. METOD MK3, BESLUT B39
    static func lodlinjen(_ v: Any?, _ nr: Int) -> ([Double]?, String?) {
        guard let v, !(v is NSNull) else { return (nil, nil) }
        let p = "serie \(nr): lodlinje"
        guard let lista = v as? [Any], lista.count == 3 else { return (nil, "\(p) ska vara tre tal") }
        let x = lista.compactMap { tal($0) }
        guard x.count == 3 else { return (nil, "\(p) ska vara tre tal") }
        let langd = (x[0] * x[0] + x[1] * x[1] + x[2] * x[2]).squareRoot()
        guard lodlinjeG.contains(langd) else {
            return (nil, "\(p) ska ha längden \(lodlinjeG.lowerBound)–\(lodlinjeG.upperBound) (g)")
        }
        guard x[1] < 0 else { return (nil, "\(p) pekar inte mot bildens överkant") }
        return (x, nil)
    }

    /// Ett kameraformat {bredd, hojd, synfalt} eller {width, height, fieldOfView}, som
    /// paket._synfalt. METOD MK3
    static func synfalt(_ f: Any?) -> Synfalt? {
        guard let f = f as? [String: Any] else { return nil }
        guard let b = heltal(f["bredd"] ?? f["width"]), let h = heltal(f["hojd"] ?? f["height"]), b > 0, h > 0,
              let v = tal(f["synfalt"] ?? f["fieldOfView"]), Synfalt.tillatet.contains(v) else { return nil }
        return Synfalt(bredd: b, hojd: h, grader: v)
    }

    /// par.json med paket.kontrollera_par:s krav. METOD MK1
    static func lasPar(_ data: Data) -> Result<ParFil, TreDPaketFel> {
        let F = "par.json"
        guard let o = try? JSONSerialization.jsonObject(with: data) else {
            return .failure(TreDPaketFel(skal: "\(F) är inte giltig JSON"))
        }
        guard let d = o as? [String: Any] else { return .failure(TreDPaketFel(skal: "\(F): ska vara ett JSON-objekt")) }
        var fel: [String] = []
        if d["format"] as? String != "swinglab-par/1" { fel.append("\(F): format ska vara swinglab-par/1") }
        let pass = d["pass"] as? String
        if pass.map(arPassID) != true { fel.append("\(F): pass ska vara yyyyMMdd-HHmmss") }
        let vy = (d["vy"] as? String).flatMap(Vy.init(rawValue:))
        if vy == nil { fel.append("\(F): vy ska vara dtl eller fo") }
        guard let serier = d["serier"] as? [Any] else {
            return .failure(TreDPaketFel(skal: (fel + ["\(F): serier ska vara en lista"]).joined(separator: "; ")))
        }
        var rader: [ParFil.Rad] = []
        for (i, r) in serier.enumerated() {
            let p = "\(F): serier[\(i)]"
            guard let r = r as? [String: Any] else {
                fel.append("\(p) ska vara ett objekt")
                continue
            }
            let serie = heltal(r["serie"])
            if serie == nil { fel.append("\(p).serie ska vara ett heltal") }
            let forsk = tal(r["forskjutning_s"])
            if forsk == nil { fel.append("\(p).forskjutning_s ska vara ett tal") }
            let osaker = r["osaker"]
            if let osaker, !(osaker is NSNull), !(osaker is Bool) {
                fel.append("\(p).osaker ska vara true eller false")
            }
            guard let f = r["foljare"] as? [String: Any] else {
                fel.append("\(p).foljare ska vara ett objekt")
                continue
            }
            let fvy = (f["vy"] as? String).flatMap(Vy.init(rawValue:))
            if fvy == nil { fel.append("\(p).foljare.vy ska vara dtl eller fo") }
            let fpass = f["pass"] as? String
            if fpass.map(arPassID) != true { fel.append("\(p).foljare.pass ska vara yyyyMMdd-HHmmss") }
            let fserie = heltal(f["serie"])
            if fserie == nil { fel.append("\(p).foljare.serie ska vara ett heltal") }
            if let serie, let forsk, let fvy, let fpass, let fserie {
                rader.append(ParFil.Rad(serie: serie, forskjutningS: forsk, osaker: (osaker as? Bool) == true,
                                        foljareVy: fvy, foljarePass: fpass, foljareSerie: fserie))
            }
        }
        guard fel.isEmpty, let pass, let vy else { return .failure(TreDPaketFel(skal: fel.joined(separator: "; "))) }
        return .success(ParFil(vy: vy, pass: pass, serier: rader))
    }

    static func arPassID(_ s: String) -> Bool {
        let c = Array(s.utf8)
        guard c.count == 15, c[8] == UInt8(ascii: "-") else { return false }
        return c.enumerated().allSatisfy { i, x in i == 8 || (x >= UInt8(ascii: "0") && x <= UInt8(ascii: "9")) }
    }
}
