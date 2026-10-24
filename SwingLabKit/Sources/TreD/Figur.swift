import Capture
import Foundation
import Swing

// Figuren på telefonen (PLAN S6d, BESLUT B72, METOD MK10): kedjans triangulerade leder per slag
// och kamerorna per uppställning, i världens ram med z uppåt (FO-kameran i origo) och i meter
// (skalan ur benens längd). Telefonen som räknar 3D sparar dem i passets mapp,
// `tre_d_figur/` (docs/FORMAT.md "Figuren i 3D"): ett index med uppställningarna och en fil per
// slag, så att vyn bara läser det slag som visas. Python är facit (tools/pc/tre_d_figur.py,
// BESLUT B12).

/// Det kedjan lämnar för figuren: uppställningarna med kamerornas tal och slag, och de
/// trianguleringar kedjan redan gjort. Fylls av `TvaKameror.analysera`, även när passet sedan
/// hoppas över. METOD MK10
public final class TreDFigurSamlare: @unchecked Sendable {
    var poster: [(info: TreDUppstallning, inre: TreDInre?, grupp: [TvaKameror.SlagData])] = []
    var tri: [String: (t: [Double], p: [Double])] = [:]

    public init() {}

    static func nyckel(_ d: TvaKameror.SlagData) -> String { d.dtl.id + "/" + d.fo.id }
}

/// En telefon där kalibreringen placerade den: centrum (m), rotationen värld → kamera (3×3 rad
/// för rad), K och bildens storlek. METOD MK10
public struct TreDFigurKamera: Codable, Equatable, Sendable {
    public var c: [Double]
    public var r: [Double]
    public var k: [Double]
    public var w: Int
    public var h: Int

    enum CodingKeys: String, CodingKey { case c = "C", r = "R", k = "K", w, h }

    public init(c: [Double], r: [Double], k: [Double], w: Int, h: Int) {
        self.c = c
        self.r = r
        self.k = k
        self.w = w
        self.h = h
    }

    /// Kamerans blickriktning, bildens högra och bildens nedåt i världen (R:s rader).
    public var fram: [Double] { [r[6], r[7], r[8]] }
    public var hoger: [Double] { [r[0], r[1], r[2]] }
    public var ned: [Double] { [r[3], r[4], r[5]] }

    init(_ kam: Kamera3D, w: Int, h: Int, skala s: Double) {
        let r = kam.r, t = kam.t
        // C = −Rᵀ t
        var c = [Double](repeating: 0, count: 3)
        for i in 0..<3 {
            let v: Double = r[i] * t[0] + r[3 + i] * t[1] + r[6 + i] * t[2]
            c[i] = -v * s
        }
        self.c = c
        self.r = r
        k = kam.k
        self.w = w
        self.h = h
    }
}

/// En uppställning i figurens index: kedjans skäl och tal, och kamerorna när kalibreringen gick
/// (också över spärren, så att uppställningen syns). METOD MK3, MK10
public struct TreDFigurUppstallning: Codable, Equatable, Sendable {
    public var serie: [String: Int]
    public var slag: Int
    public var hoppat: String?
    public var sampsonPx: Double?
    public var vinkel: Double?
    public var vinkelOk: Bool?
    /// "langd" (benen) eller "kamerorna" (avståndet mellan dem är 1); nil utan kameror.
    public var skala: String?
    public var skalaM: Double?
    /// Markens höjd, m: fotledernas median i adressen minus fotledens höjd; nil med reserven.
    public var golv: Double?
    /// Varför skalan är reserven ("kamerorna"), annars nil. METOD MK10
    public var skalaFel: String?
    /// "fo" och "dtl".
    public var kameror: [String: TreDFigurKamera]?

    enum CodingKeys: String, CodingKey {
        case serie, slag, hoppat, vinkel, skala, golv, kameror
        case sampsonPx = "sampson_px", vinkelOk = "vinkel_ok", skalaM = "skala_m", skalaFel = "skala_fel"
    }

    public init(serie: [String: Int], slag: Int, hoppat: String? = nil, sampsonPx: Double? = nil,
                vinkel: Double? = nil, vinkelOk: Bool? = nil, skala: String? = nil, skalaM: Double? = nil,
                golv: Double? = nil, kameror: [String: TreDFigurKamera]? = nil) {
        self.serie = serie
        self.slag = slag
        self.hoppat = hoppat
        self.sampsonPx = sampsonPx
        self.vinkel = vinkel
        self.vinkelOk = vinkelOk
        self.skala = skala
        self.skalaM = skalaM
        self.golv = golv
        self.kameror = kameror
    }

    /// Kalibreringen gick men uppställningen mättes inte (spärren): kameror utan figur.
    public var overSparren: Bool { hoppat != nil && kameror != nil }
}

/// Ett slags figur: lederna (m) på en tidsaxel i steg om 1/240 s med träffen = 0 på FO:s klocka,
/// synken och kroppens positioner på samma tid. METOD MK5, MK10
public struct TreDFigur: Equatable, Sendable {
    public static let antalLeder = 13
    public var dtl: String
    public var fo: String
    public var uppstallning: Int
    public var synkS: Double
    public var t0: Double
    public var steg: Double
    public var n: Int
    /// n · 13 · 3, m; NaN där leden saknas.
    public var p: [Double]
    public var positioner: [String: Double]

    public init(dtl: String, fo: String, uppstallning: Int, synkS: Double, t0: Double, steg: Double, n: Int,
                p: [Double], positioner: [String: Double]) {
        self.dtl = dtl
        self.fo = fo
        self.uppstallning = uppstallning
        self.synkS = synkS
        self.t0 = t0
        self.steg = steg
        self.n = n
        self.p = p
        self.positioner = positioner
    }

    public var filnamn: String { "\(dtl)-\(fo).json" }
    public func t(_ i: Int) -> Double { t0 + Double(i) * steg }
    public var tSista: Double { t(max(0, n - 1)) }

    /// Leden j i ruta i, nil när den saknas.
    public func led(_ i: Int, _ j: Int) -> [Double]? {
        guard i >= 0, i < n, j >= 0, j < Self.antalLeder else { return nil }
        let b = (i * Self.antalLeder + j) * 3
        let v = [p[b], p[b + 1], p[b + 2]]
        return v.allSatisfy(\.isFinite) ? v : nil
    }

    /// Rutan närmast tiden (s på figurens tid), inom slaget.
    public func ruta(_ nu: Double) -> Int {
        guard n > 0, steg > 0, nu.isFinite else { return 0 }
        return min(n - 1, max(0, Int(((nu - t0) / steg).rounded())))
    }

    /// Positionerna P1–P10 i svingens ordning med sin ruta; nil när positionen saknas eller
    /// ligger utanför slaget (P2, P6 och P8 kräver klubban). METOD M28, MK10
    public func positionsRutor() -> [(name: String, index: Int?)] {
        Klubba.positioner.map { namn in
            guard let tid = positioner[namn], tid >= t0 - steg / 2, tid <= tSista + steg / 2 else {
                return (name: namn, index: nil)
            }
            return (name: namn, index: ruta(tid))
        }
    }

    // MARK: filen

    /// Lederna i filen: int16 i mm, little endian i base64; −32768 = saknas (och ett tal utanför
    /// ±32,767 m). METOD MK10
    static let saknas = Int16.min

    struct Fil: Codable {
        var format: String
        var dtl: String
        var fo: String
        var uppstallning: Int
        var synkS: Double
        var t0: Double
        var steg: Double
        var n: Int
        var positioner: [String: Double]
        var leder: String

        enum CodingKeys: String, CodingKey {
            case format, dtl, fo, uppstallning, t0, steg, n, positioner, leder
            case synkS = "synk_s"
        }
    }

    public func data() throws -> Data {
        var b = Data(capacity: p.count * 2)
        for v in p {
            let mm = (v * 1000).rounded()
            let q: Int16 = mm.isFinite && abs(mm) <= 32767 ? Int16(mm) : Self.saknas
            withUnsafeBytes(of: q.littleEndian) { b.append(contentsOf: $0) }
        }
        let f = Fil(format: TreDFigurIndex.formatName, dtl: dtl, fo: fo, uppstallning: uppstallning, synkS: synkS,
                    t0: t0, steg: steg, n: n, positioner: positioner, leder: b.base64EncodedString())
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return try e.encode(f)
    }

    public static func las(_ d: Data) throws -> TreDFigur {
        guard let f = try? JSONDecoder().decode(Fil.self, from: d) else {
            throw OverforingFel("figurens fil går inte att läsa")
        }
        guard f.format == TreDFigurIndex.formatName else {
            throw OverforingFel("figurens fil: format ska vara \(TreDFigurIndex.formatName)")
        }
        guard let b = Data(base64Encoded: f.leder), f.n >= 0, b.count == f.n * antalLeder * 3 * 2 else {
            throw OverforingFel("figurens fil: lederna har fel längd")
        }
        let p: [Double] = b.withUnsafeBytes { r in
            (0..<(b.count / 2)).map { i -> Double in
                let q = Int16(littleEndian: r.loadUnaligned(fromByteOffset: i * 2, as: Int16.self))
                return q == saknas ? .nan : Double(q) / 1000
            }
        }
        return TreDFigur(dtl: f.dtl, fo: f.fo, uppstallning: f.uppstallning, synkS: f.synkS, t0: f.t0, steg: f.steg,
                         n: f.n, p: p, positioner: f.positioner)
    }
}

/// `tre_d_figur/index.json`: passets uppställningar och slagens filer, för de buntar
/// (`kallor`) som `tre_d.json` räknades på. METOD MK10
public struct TreDFigurIndex: Codable, Equatable, Sendable {
    public static let formatName = "swinglab-tre-d-figur/1"
    /// Kedjans version för figuren: höjs när MK10 ändras, så att telefonen räknar om (BESLUT B72).
    /// Samma tal som `tre_d_figur.KEDJA`.
    public static let kedjeversion = 2
    public static let mapp = "tre_d_figur"
    public static let filnamn = "index.json"

    public struct Post: Codable, Equatable, Sendable {
        public var dtl: String
        public var fo: String
        public var uppstallning: Int
        public var fil: String
    }

    public var format: String
    /// Kedjans version (nil i ett index från före versionen).
    public var kedja: Int?
    public var pass: String
    public var kallor: [String: String]
    public var langdM: Double
    public var hand: Hand
    /// Kedjans skäl när passet hoppades över (som `tre_d.json`).
    public var hoppat: String?
    public var uppstallningar: [TreDFigurUppstallning]
    public var slag: [Post]

    enum CodingKeys: String, CodingKey {
        case format, kedja, pass, kallor, hand, hoppat, uppstallningar, slag
        case langdM = "langd_m"
    }

    public init(pass: String, kallor: [String: String], langdM: Double, hand: Hand, hoppat: String?,
                uppstallningar: [TreDFigurUppstallning], slag: [Post]) {
        format = Self.formatName
        kedja = Self.kedjeversion
        self.pass = pass
        self.kallor = kallor
        self.langdM = langdM
        self.hand = hand
        self.hoppat = hoppat
        self.uppstallningar = uppstallningar
        self.slag = slag
    }

    public func data() throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try e.encode(self)
    }

    /// Det finns något att visa: en figur eller telefonerna.
    public var harInnehall: Bool { !slag.isEmpty || uppstallningar.contains { $0.kameror != nil } }

    public static func las(_ d: Data) throws -> TreDFigurIndex {
        guard let f = try? JSONDecoder().decode(TreDFigurIndex.self, from: d) else {
            throw OverforingFel("\(mapp)/\(filnamn): går inte att läsa")
        }
        guard f.format == formatName else { throw OverforingFel("\(mapp)/\(filnamn): format ska vara \(formatName)") }
        return f
    }
}

/// Passets figur som telefonen räknade: indexet och slagens figurer. METOD MK10
public struct TreDFigurer: Equatable, Sendable {
    public var index: TreDFigurIndex
    public var figurer: [TreDFigur]

    /// Lårets och smalbenets andel av längden (Drillis och Contini 1966, ej läst i original),
    /// och fotledens höjd över marken (samma källa). METOD MK10
    public static let benetsAndel = 0.245 + 0.246
    public static let fotledAndel = 0.039
    /// Höft, knä, fotled per sida (lederna i filens ordning).
    static let ben = [(7, 9, 11), (8, 10, 12)]
    static let fotleder = [11, 12]
    /// Kroppens positioner (METOD M28).
    static let positioner = Positioner.namn

    /// Skyddet runt skalan: sidornas ben får skilja så mycket, och kamerorna ska hamna så långt
    /// från stansen och så högt över marken med skalan, m. METOD MK10
    public static let benSkillnad = 0.10
    public static let kameraAvstand = 1.5...8.0
    public static let kameraHojd = 0.5...1.8
    /// Adressens rutor: fram till P1 + 0,15 s (utan P1 de första 0,3 s), annars de första 72.
    public static let adressEfterP1S = 0.15
    static let adressReservRutor = 72

    /// Rutorna i adressen. Som `tre_d_figur.adressens_rutor`. METOD MK10, MK11
    public static func adressensRutor(_ t: [Double], _ positioner: [String: Double]) -> [Int] {
        guard let t0 = t.first else { return [] }
        let slut = (positioner["P1"] ?? (t0 + adressEfterP1S)) + adressEfterP1S
        let r = t.indices.filter { t[$0] <= slut }
        return r.isEmpty ? Array(0..<min(t.count, adressReservRutor)) : r
    }

    /// Skalan och marken, eller reserven med skälet. Som `tre_d_figur.skala`. METOD MK10
    public struct Skala: Equatable, Sendable {
        public var kalla: String
        public var m: Double
        public var golv: Double?
        public var fel: String?

        static func reserv(_ fel: String) -> Skala { Skala(kalla: "kamerorna", m: 1, golv: nil, fel: fel) }
    }

    /// Meter per enhet i kalibreringens värld och markens höjd ur uppställningens figurer i
    /// adressen (lederna och adressens rutor per slag): benets längd (lår + smalben, medianen över
    /// båda sidor och alla rutor) = 0,491 × längden, och marken = fotledernas median − 0,039 ×
    /// längden. Reserven (avståndet mellan kamerorna = 1, ingen mark) med skälet när benen saknas,
    /// när sidorna skiljer mer än 10 %, eller när en kamera (`kameror`, centrum i kalibreringens
    /// enheter) då hamnar utanför 1,5–8 m från stansen eller 0,5–1,8 m över marken. Bara för
    /// bilden. Som `tre_d_figur.skala`. METOD MK10
    public static func skala(_ figurer: [(p: [Double], rutor: [Int])], _ langd: Double, kameror: [[Double]]) -> Skala {
        var sidor: [[Double]] = [[], []]
        var fot: [Double] = []
        var stans: [[[Double]]] = [[[], []], [[], []]]           // per fotled: x och y
        func d(_ p: [Double], _ i: Int, _ a: Int, _ c: Int) -> Double {
            let ia = (i * 13 + a) * 3, ic = (i * 13 + c) * 3
            let x: Double = p[ia] - p[ic]
            let y: Double = p[ia + 1] - p[ic + 1]
            let z: Double = p[ia + 2] - p[ic + 2]
            let q: Double = x * x + y * y + z * z
            return q.squareRoot()
        }
        for (p, rutor) in figurer {
            for (n, (h, k, f)) in ben.enumerated() {
                for i in rutor {
                    let v = d(p, i, h, k) + d(p, i, k, f)
                    if v.isFinite { sidor[n].append(v) }
                }
            }
            for (n, j) in fotleder.enumerated() {
                for i in rutor {
                    let b = (i * 13 + j) * 3
                    if p[b + 2].isFinite { fot.append(p[b + 2]) }
                    if p[b].isFinite, p[b + 1].isFinite, p[b + 2].isFinite {
                        stans[n][0].append(p[b])
                        stans[n][1].append(p[b + 1])
                    }
                }
            }
        }
        guard !sidor[0].isEmpty, !sidor[1].isEmpty else { return .reserv("benen syns inte i adressen") }
        let mv = LA.median(sidor[0]), mh = LA.median(sidor[1])
        guard abs(mv - mh) <= benSkillnad * max(mv, mh) else {
            return .reserv("benen skiljer mer än 10 % mellan sidorna")
        }
        let m = LA.median(sidor[0] + sidor[1])
        guard m > 0, !fot.isEmpty else { return .reserv("benen syns inte i adressen") }
        let s = benetsAndel * langd / m
        let golv = LA.median(fot) * s - fotledAndel * langd
        let mitt = stans.filter { !$0[0].isEmpty }.map { [LA.median($0[0]), LA.median($0[1])] }
        let n = Double(mitt.count)
        let sx: Double = mitt.map { $0[0] }.reduce(0, +) / n * s
        let sy: Double = mitt.map { $0[1] }.reduce(0, +) / n * s
        for c in kameror {
            let dx: Double = c[0] * s - sx, dy: Double = c[1] * s - sy
            let avst = (dx * dx + dy * dy).squareRoot(), hojd = c[2] * s - golv
            guard kameraAvstand.contains(avst), kameraHojd.contains(hojd) else {
                return .reserv("kamerorna hamnar orimligt med benens skala")
            }
        }
        return Skala(kalla: "langd", m: s, golv: golv, fel: nil)
    }

    /// Slagets positioner på figurens tid: FO:s, annars DTL:s flyttad med synken, som
    /// baksvingens start (MK6). METOD MK10
    static func positionerFor(_ d: TvaKameror.SlagData, _ forsk: Double, _ faser: [String: Faser2D]) -> [String: Double] {
        var ut: [String: Double] = [:]
        let par = [(faser["fo/" + d.fo.id], d.traffA), (faser["dtl/" + d.dtl.id], d.traffB + forsk)]
        for namn in positioner {
            for (f, skift) in par {
                if let v = f?.positioner[namn], v.isFinite {
                    ut[namn] = v - skift
                    break
                }
            }
        }
        return ut
    }

    /// Figuren ur det kedjan lämnade: kamerorna, skalan och marken för varje uppställning som
    /// kalibrerades, och figurerna bara för en som mättes (BESLUT B72). `pass` och `kallor`
    /// sätts av den som sparar. nil när räkningen avbröts. Som `tre_d_figur.figurer`. METOD MK10
    public static func bygg(_ s: TreDFigurSamlare, hand: Hand, faser: [String: Faser2D], langd: Double,
                            hoppat: String?) -> TreDFigurer? {
        var upp: [TreDFigurUppstallning] = []
        var figurer: [TreDFigur] = []
        var poster: [TreDFigurIndex.Post] = []
        for (i, post) in s.poster.enumerated() {
            let info = post.info
            var u = TreDFigurUppstallning(serie: info.serie, slag: info.slag, hoppat: info.hoppat,
                                          sampsonPx: info.sampsonPx, vinkel: info.vinkelMellanKamerorna,
                                          vinkelOk: info.vinkelOk)
            guard let inre = post.inre, let d0 = post.grupp.first else {
                upp.append(u)
                continue
            }
            var tri: [(t: [Double], p: [Double])] = []
            for (d, f) in zip(post.grupp, inre.forsk) {
                if Task.isCancelled { return nil }
                if let c = s.tri[TreDFigurSamlare.nyckel(d)] {
                    tri.append(c)
                } else {
                    let kam = Kalibrering.varld(d.ka, d.kb, inre.r, inre.t, inre.upp)
                    let (tg, p, _) = TvaKameror.triangulera(kam, d, f)
                    tri.append((tg, p))
                }
            }
            let pos = zip(post.grupp, inre.forsk).map { d, f in positionerFor(d, f, faser) }
            let (kamA, kamB) = Kalibrering.varld(d0.ka, d0.kb, inre.r, inre.t, inre.upp)
            let ca = TreDFigurKamera(kamA, w: 0, h: 0, skala: 1).c, cb = TreDFigurKamera(kamB, w: 0, h: 0, skala: 1).c
            let skalan = skala(zip(tri, pos).map { x, p in (p: x.p, rutor: adressensRutor(x.t, p)) }, langd,
                               kameror: [ca, cb])
            let sk = skalan.m
            u.skala = skalan.kalla
            u.skalaM = sk
            u.golv = skalan.golv
            u.skalaFel = skalan.fel
            u.kameror = ["fo": TreDFigurKamera(kamA, w: d0.fo.lederna?.width ?? 1080, h: d0.fo.lederna?.height ?? 1920,
                                               skala: sk),
                         "dtl": TreDFigurKamera(kamB, w: d0.dtl.lederna?.width ?? 1080,
                                                h: d0.dtl.lederna?.height ?? 1920, skala: sk)]
            upp.append(u)
            guard u.hoppat == nil else { continue }               // BESLUT B72: ingen figur där skälet säger nej
            for (((d, f), x), p) in zip(zip(zip(post.grupp, inre.forsk), tri), pos) {
                let n = x.t.count
                let steg = n > 1 ? x.t[1] - x.t[0] : TvaKameror.rutnatS
                let fig = TreDFigur(dtl: d.dtl.id, fo: d.fo.id, uppstallning: i, synkS: f, t0: x.t.first ?? 0,
                                    steg: steg, n: n, p: x.p.map { $0 * sk }, positioner: p)
                figurer.append(fig)
                poster.append(TreDFigurIndex.Post(dtl: fig.dtl, fo: fig.fo, uppstallning: i, fil: fig.filnamn))
            }
        }
        let index = TreDFigurIndex(pass: "", kallor: [:], langdM: langd, hand: hand, hoppat: hoppat,
                                   uppstallningar: upp, slag: poster)
        return TreDFigurer(index: index, figurer: figurer)
    }
}
