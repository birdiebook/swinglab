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

/// Formfel i ett paket: varje rad nämner filen och fältet, aldrig värdet (CLAUDE.md,
/// Dataregeln). Blir `tre_d.hoppat` (TvaKameror.treD). METOD M51
public struct TreDPaketFel: Error, Equatable, Sendable {
    public var fel: [String]
    public var skal: String { fel.joined(separator: "; ") }

    public init(_ fel: [String]) {
        self.fel = fel
    }
}

extension TreDPaket {
    /// Lodlinjens längd i g (accelerometern i vila). METOD MK3, BESLUT B39
    public static let lodlinjeG = 0.8...1.2
    /// paket.py: formatet, domarna och de rimliga talen. METOD MT1, MS13
    public static let format = "swinglab-paket/1"
    public static let domar = ["sving", "inte_sving", "osaker"]
    public static let avstandM = 0.5...20.0
    public static let langdM = 1.0...2.5
    static let kant = 1e-6

    /// Paketet ur dess filer: manifest.json, par.json och enhet.json (valfria), lederna
    /// per slag-id och, när de är kända, paketets filnamn (`filer`; då prövas att slagens
    /// filer finns). Manifestet kontrolleras som paket.py (`kontrollera`): ett formfel
    /// kastar TreDPaketFel. Lodlinjen, synfältet och par.json läses som paket.py gör: det
    /// som inte går att använda blir ett skäl, inte ett stopp. METOD MK1, MK3, M51
    public static func las(manifest: Data, lederna: [String: JointSeries], filer: Set<String>? = nil,
                           par: Data? = nil, enhet: Data? = nil) throws -> TreDPaket {
        guard let m = try? JSONVarde.las(manifest) else { throw TreDPaketFel(["manifest.json är inte giltig JSON"]) }
        let fel = kontrollera(m, filer: filer)
        guard fel.isEmpty, let o = m.objekt else { throw TreDPaketFel(fel) }
        var ut: [Int: TreDSerie] = [:]
        for s in o["serier"]?.lista ?? [] {
            guard let nr = s["nr"]?.heltal else { continue }
            let (lod, lodFel) = lodlinjen(s["lodlinje"], nr)
            ut[nr] = TreDSerie(nr: nr, lodlinje: lod, lodlinjeFel: lodFel, synfalt: synfalt(s["format"]))
        }
        var lista: [TreDSlag] = []
        for s in o["slag"]?.lista ?? [] {
            guard let id = s["id"]?.text, let serie = s["serie"]?.heltal, let dom = s["dom"]?.text,
                  let klick = s["klick_s"]?.tal else { continue }
            lista.append(TreDSlag(id: id, serie: serie, dom: dom, klickS: klick, traffS: s["traff_s"]?.tal,
                                  detectionWrong: s["detection_wrong"] == .bool(true), lederna: lederna[id]))
        }
        var enhetSF: Synfalt?
        if let enhet, let e = try? JSONVarde.las(enhet), let eo = e.objekt, let format = eo["format"]?.lista {
            // Som paket.py: formatet vars index är valt_index (== i Python, även None == None).
            if let f = format.first(where: { $0.objekt != nil && JSONVarde.pyLika($0["index"], eo["valt_index"]) }) {
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
        return TreDPaket(passID: o["pass"]!.text!, vy: Vy(rawValue: o["vy"]!.text!)!,
                         spelhand: Hand(rawValue: o["spelhand"]!.text!)!, avstandM: o["avstand_m"]?.tal,
                         serier: ut, slag: lista, par: parFil, parFel: parFel, enhetSynfalt: enhetSF)
    }

    static func sakertNamn(_ v: JSONVarde?) -> Bool {
        guard let s = v?.text, !s.isEmpty, !s.hasPrefix("/") else { return false }
        return !s.split(separator: "/", omittingEmptySubsequences: false).contains("..")
    }

    static func arSlagID(_ s: String) -> Bool {
        let c = Array(s.utf8)
        guard c.count >= 3, c.count <= 5, c[0] == UInt8(ascii: "s") else { return false }
        return c.dropFirst().allSatisfy { $0 >= 0x30 && $0 <= 0x39 }
    }

    /// Manifestets formfel, rad för rad som paket._kontrollera_manifest (samma text).
    /// `filer` nil: att slagens filer finns prövas inte. METOD MT1, MS13, M51
    public static func kontrollera(_ m: JSONVarde, filer: Set<String>?) -> [String] {
        let F = "manifest.json"
        guard m.objekt != nil else { return ["\(F): ska vara ett JSON-objekt"] }
        var fel: [String] = []
        if m["format"] != .strang(format) { fel.append("\(F): format ska vara \(format)") }
        if m["pass"]?.text.map(arPassID) != true { fel.append("\(F): pass ska vara yyyyMMdd-HHmmss") }
        if !["dtl", "fo"].contains(m["vy"]?.text ?? "") { fel.append("\(F): vy ska vara dtl eller fo") }
        if !["hoger", "vanster"].contains(m["spelhand"]?.text ?? "") {
            fel.append("\(F): spelhand ska vara hoger eller vanster")
        }
        if let a = m["avstand_m"], a != .null, !(a.tal.map(avstandM.contains) ?? false) {
            fel.append("\(F): avstand_m ska vara ett tal mellan \(avstandM.lowerBound) och \(avstandM.upperBound)")
        }
        if let a = m["spelarens_langd_m"], a != .null, !(a.tal.map(langdM.contains) ?? false) {
            fel.append("\(F): spelarens_langd_m ska vara ett tal mellan \(langdM.lowerBound) och \(langdM.upperBound)")
        }
        var nr = Set<Int>()
        var fonster: [Int: (Double, Double)] = [:]
        if let serier = m["serier"]?.lista {
            for (i, s) in serier.enumerated() {
                guard s.objekt != nil, let n = s["nr"]?.heltal else {
                    fel.append("\(F): serier[\(i)].nr ska vara ett heltal")
                    continue
                }
                nr.insert(n)
                if redigering(s, "").isEmpty, let f = s["fonster"], f.objekt != nil {
                    fonster[n] = (f["fran_s"]!.tal!, f["till_s"]!.tal!)
                }
                if let k = s["klubba"], k != .null, k.text == nil { fel.append("\(F): serier[\(i)].klubba ska vara text") }
                if let rp = s["riktpinne"], rp != .null {
                    // Riktpinnen (S7a, METOD M48): två punkter [x, y].
                    let ok = rp.lista.map { l in
                        l.count == 2 && l.allSatisfy { q in q.lista.map { $0.count == 2 && $0.allSatisfy { $0.tal != nil } } ?? false }
                    } ?? false
                    if !ok { fel.append("\(F): serier[\(i)].riktpinne ska vara två punkter [x, y]") }
                }
                fel += redigering(s, "\(F): serier[\(i)]")
            }
        } else {
            fel.append("\(F): serier ska vara en lista")
        }
        guard let slag = m["slag"]?.lista, !slag.isEmpty else {
            fel.append("\(F): slag saknas eller är tom")
            return fel
        }
        var sedda = Set<String>()
        for (i, s) in slag.enumerated() {
            let p = "\(F): slag[\(i)]"
            guard s.objekt != nil else {
                fel.append("\(p): ska vara ett objekt")
                continue
            }
            if let id = s["id"]?.text, arSlagID(id) {
                if sedda.contains(id) { fel.append("\(p).id finns två gånger") }
                sedda.insert(id)
            } else {
                fel.append("\(p).id ska vara s och siffror")
            }
            let serie = s["serie"]?.heltal
            if serie.map(nr.contains) != true { fel.append("\(p).serie ska vara ett nr i serier") }
            if let klick = s["klick_s"]?.tal {
                if let serie, let f = fonster[serie], !(f.0 - kant <= klick && klick <= f.1 + kant) {
                    fel.append("\(p).klick_s ligger utanför seriens fonster")
                }
            } else {
                fel.append("\(p).klick_s ska vara ett tal")
            }
            if let t = s["traff_s"], t != .null, t.tal == nil { fel.append("\(p).traff_s ska vara ett tal") }
            if let d = s["detection_wrong"], d != .null, !(d == .bool(true) || d == .bool(false)) {
                fel.append("\(p).detection_wrong ska vara true eller false")
            }
            if !domar.contains(s["dom"]?.text ?? "") {
                fel.append("\(p).dom ska vara en av \(domar.joined(separator: ", "))")
            }
            if !sakertNamn(s["leder"]) {
                fel.append("\(p).leder ska vara en sökväg i paketet")
            } else if let filer, !filer.contains(s["leder"]!.text!) {
                fel.append("\(p).leder: filen saknas i paketet")
            }
            if let k = s["klipp"], k != .null {
                if !sakertNamn(k) {
                    fel.append("\(p).klipp ska vara en sökväg i paketet")
                } else if let filer, !filer.contains(k.text!) {
                    fel.append("\(p).klipp: filen saknas i paketet")
                }
                if s["klick_i_klipp_s"]?.tal == nil { fel.append("\(p).klick_i_klipp_s ska vara ett tal när klipp finns") }
                if let l = s["klipp_langd_s"], l != .null, !((l.tal ?? 0) > 0) {
                    fel.append("\(p).klipp_langd_s ska vara ett positivt tal")
                }
            }
        }
        return fel
    }

    /// Seriens `fonster` och `utsnitt` (valfria, S2i), som paket._kontrollera_redigering. METOD MS13
    static func redigering(_ s: JSONVarde, _ p: String) -> [String] {
        var fel: [String] = []
        if let f = s["fonster"], f != .null {
            if f.objekt == nil || f["fran_s"]?.tal == nil || f["till_s"]?.tal == nil {
                fel.append("\(p).fonster ska ha talen fran_s och till_s")
            } else if !(0 <= f["fran_s"]!.tal! && f["fran_s"]!.tal! < f["till_s"]!.tal!) {
                fel.append("\(p).fonster ska ha 0 <= fran_s < till_s")
            }
        }
        if let u = s["utsnitt"], u != .null {
            let v = ["x", "y", "b", "h"].map { u[$0]?.tal }
            if u.objekt == nil || v.contains(where: { $0 == nil }) {
                fel.append("\(p).utsnitt ska ha talen x, y, b och h")
            } else {
                let x = v[0]!, y = v[1]!, b = v[2]!, h = v[3]!
                if !(x >= -kant && y >= -kant && b > 0 && h > 0 && x + b <= 1 + kant && y + h <= 1 + kant) {
                    fel.append("\(p).utsnitt ska ligga inom bilden (0–1) med positiv b och h")
                }
            }
        }
        return fel
    }

    /// Seriens `lodlinje`: tre tal, längd 0,8–1,2 g och uppåt mot bildens överkant
    /// (y < 0). Annars nil och skälet utan värden, som paket.lodlinjen. METOD MK3, BESLUT B39
    static func lodlinjen(_ v: JSONVarde?, _ nr: Int) -> ([Double]?, String?) {
        guard let v, v != .null else { return (nil, nil) }
        let p = "serie \(nr): lodlinje"
        guard let lista = v.lista, lista.count == 3 else { return (nil, "\(p) ska vara tre tal") }
        let x = lista.compactMap(\.tal)
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
    static func synfalt(_ f: JSONVarde?) -> Synfalt? {
        guard let f, f.objekt != nil else { return nil }
        let bv = f["bredd"] ?? f["width"], hv = f["hojd"] ?? f["height"]
        guard let b = bv?.heltal, let h = hv?.heltal, b > 0, h > 0,
              let v = (f["synfalt"] ?? f["fieldOfView"])?.tal, Synfalt.tillatet.contains(v) else { return nil }
        return Synfalt(bredd: b, hojd: h, grader: v)
    }

    /// par.json med paket.kontrollera_par:s krav och text. METOD MK1
    static func lasPar(_ data: Data) -> Result<ParFil, TreDPaketFel> {
        let F = "par.json"
        guard let d = try? JSONVarde.las(data) else { return .failure(TreDPaketFel(["\(F) är inte giltig JSON"])) }
        guard d.objekt != nil else { return .failure(TreDPaketFel(["\(F): ska vara ett JSON-objekt"])) }
        var fel: [String] = []
        if d["format"] != .strang("swinglab-par/1") { fel.append("\(F): format ska vara swinglab-par/1") }
        if d["pass"]?.text.map(arPassID) != true { fel.append("\(F): pass ska vara yyyyMMdd-HHmmss") }
        let vy = d["vy"]?.text.flatMap(Vy.init(rawValue:))
        if vy == nil { fel.append("\(F): vy ska vara dtl eller fo") }
        guard let serier = d["serier"]?.lista else {
            return .failure(TreDPaketFel(fel + ["\(F): serier ska vara en lista"]))
        }
        var rader: [ParFil.Rad] = []
        for (i, r) in serier.enumerated() {
            let p = "\(F): serier[\(i)]"
            guard r.objekt != nil else {
                fel.append("\(p) ska vara ett objekt")
                continue
            }
            let serie = r["serie"]?.heltal
            if serie == nil { fel.append("\(p).serie ska vara ett heltal") }
            let forsk = r["forskjutning_s"]?.tal
            if forsk == nil { fel.append("\(p).forskjutning_s ska vara ett tal") }
            let osaker = r["osaker"]
            if let osaker, osaker != .null, !(osaker == .bool(true) || osaker == .bool(false)) {
                fel.append("\(p).osaker ska vara true eller false")
            }
            guard let f = r["foljare"], f.objekt != nil else {
                fel.append("\(p).foljare ska vara ett objekt")
                continue
            }
            let fvy = f["vy"]?.text.flatMap(Vy.init(rawValue:))
            if fvy == nil { fel.append("\(p).foljare.vy ska vara dtl eller fo") }
            let fpass = f["pass"]?.text
            if fpass.map(arPassID) != true { fel.append("\(p).foljare.pass ska vara yyyyMMdd-HHmmss") }
            let fserie = f["serie"]?.heltal
            if fserie == nil { fel.append("\(p).foljare.serie ska vara ett heltal") }
            if let serie, let forsk, let fvy, let fpass, let fserie {
                rader.append(ParFil.Rad(serie: serie, forskjutningS: forsk, osaker: osaker == .bool(true),
                                        foljareVy: fvy, foljarePass: fpass, foljareSerie: fserie))
            }
        }
        guard fel.isEmpty, let pass = d["pass"]?.text, let vy else { return .failure(TreDPaketFel(fel)) }
        return .success(ParFil(vy: vy, pass: pass, serier: rader))
    }

    static func arPassID(_ s: String) -> Bool {
        let c = Array(s.utf8)
        guard c.count == 15, c[8] == UInt8(ascii: "-") else { return false }
        return c.enumerated().allSatisfy { i, x in i == 8 || (x >= UInt8(ascii: "0") && x <= UInt8(ascii: "9")) }
    }
}
