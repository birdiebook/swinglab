import Capture
import Foundation
import Swing

// Figurens vy (PLAN S6d, BESLUT B73, METOD MK11): riktningarna ur kroppen i adressen, de färdiga
// vinklarna, en kamera som vrids med ett finger och nyps, perspektivet till skärmen, och spåren i
// 3D med S4f:s datamodell och delning (`SparSerie`). Ren geometri utan UI, så att den prövas på
// Linux; appen ritar med en egen vy.

/// De färdiga vinklarna. METOD MK11
public enum TreDVinkel: String, CaseIterable, Sendable {
    case faceOn, dtl, top
}

/// Figurens riktningar: vyns mitt, mot målet och spelarens framsida (båda vågräta
/// enhetsvektorer), markens höjd och hur stort det som ska synas är. METOD MK11
public struct TreDRiktning: Equatable, Sendable {
    public var mitt: [Double]
    public var mal: [Double]
    public var fram: [Double]
    public var golv: Double
    /// Mittpunkten mellan fotlederna i adressen, på marken: mållinjens ankare.
    public var stans: [Double]
    /// Punkterna som en färdig vinkel ska rymma: lederna i var sjätte ruta (det figuren når under
    /// svingen) och stansen, eller utan figur stansen och en upprätt spelare ovanför den.
    public var omfang: [[Double]]
    /// Riktningarna kommer ur en figur (annars ur telefonerna: ingen mållinje ritas).
    public var urFigur: Bool

    public init(mitt: [Double], mal: [Double], fram: [Double], golv: Double, stans: [Double], omfang: [[Double]],
                urFigur: Bool) {
        self.mitt = mitt
        self.mal = mal
        self.fram = fram
        self.golv = golv
        self.stans = stans
        self.omfang = omfang
        self.urFigur = urFigur
    }

    static func vagrat(_ v: [Double]) -> [Double]? {
        let n = (v[0] * v[0] + v[1] * v[1]).squareRoot()
        guard n > 1e-9, n.isFinite else { return nil }
        return [v[0] / n, v[1] / n, 0]
    }

    /// Medianen per koordinat av leden j i rutorna, nil när den saknas i alla.
    static func median(_ f: TreDFigur, _ rutor: [Int], _ j: Int) -> [Double]? {
        let v = rutor.compactMap { f.led($0, j) }
        guard !v.isEmpty else { return nil }
        return (0..<3).map { a in LA.median(v.map { $0[a] }) }
    }

    /// Riktningarna ur figuren i adressen (rutorna fram till P1 + 0,15 s, annars slagets första
    /// 0,3 s): mot målet = bakre fotleden → främre (höfterna när fotlederna saknas), framsidan =
    /// vinkelrätt mot den, åt det håll näsan står framför höfterna (spelaren böjer sig mot bollen),
    /// annars mot FO-kameran. Utan figur: där kamerornas blickar möts, med framsidan mot
    /// FO-kameran. Markens höjd ur uppställningen. nil utan både figur och kameror. METOD MK11
    public static func ur(_ f: TreDFigur?, uppstallning u: TreDFigurUppstallning, hand: Hand) -> TreDRiktning? {
        let fo = u.kameror?["fo"], dtl = u.kameror?["dtl"]
        let z: [Double] = [0, 0, 1]
        if let f, f.n > 0 {
            let slut = (f.positioner["P1"] ?? (f.t0 + 0.15)) + 0.15
            var rutor = (0..<f.n).filter { f.t($0) <= slut }
            if rutor.isEmpty { rutor = Array(0..<min(f.n, 72)) }
            let (fram, bak) = hand == .hoger ? (11, 12) : (12, 11)
            let (hf, hb) = hand == .hoger ? (7, 8) : (8, 7)
            var mal: [Double]?
            if let a = median(f, rutor, fram), let b = median(f, rutor, bak) {
                mal = vagrat([a[0] - b[0], a[1] - b[1], 0])
            }
            if mal == nil, let a = median(f, rutor, hf), let b = median(f, rutor, hb) {
                mal = vagrat([a[0] - b[0], a[1] - b[1], 0])
            }
            // Alla leder i alla rutor: mitten och radien (det figuren når under svingen).
            var lo = [Double](repeating: .infinity, count: 3), hi = [Double](repeating: -.infinity, count: 3)
            for i in 0..<f.n {
                for j in 0..<TreDFigur.antalLeder {
                    guard let v = f.led(i, j) else { continue }
                    for a in 0..<3 {
                        lo[a] = min(lo[a], v[a])
                        hi[a] = max(hi[a], v[a])
                    }
                }
            }
            guard lo[0].isFinite else { return ur(nil, uppstallning: u, hand: hand) }
            let golv = u.golv ?? lo[2]
            let hofter = [median(f, rutor, hf), median(f, rutor, hb)].compactMap { $0 }
            let fot = [median(f, rutor, fram), median(f, rutor, bak)].compactMap { $0 }
            let bas = fot.isEmpty ? hofter : fot
            var stans: [Double] = [(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, golv]
            if !bas.isEmpty {
                let n = Double(bas.count)
                let sx: Double = bas.map { $0[0] }.reduce(0, +), sy: Double = bas.map { $0[1] }.reduce(0, +)
                stans = [sx / n, sy / n, golv]
            }
            let m = mal ?? fo.flatMap { k in vagrat(LA.kryss(z, [stans[0] - k.c[0], stans[1] - k.c[1], 0])) } ?? [0, 1, 0]
            var c = LA.kryss(z, m)                               // vinkelrätt mot målet, vågrätt
            var tecken = 0.0
            if let n = median(f, rutor, 0), !hofter.isEmpty {
                let k = Double(hofter.count)
                let hx: Double = hofter.map { $0[0] }.reduce(0, +) / k, hy: Double = hofter.map { $0[1] }.reduce(0, +) / k
                tecken = (n[0] - hx) * c[0] + (n[1] - hy) * c[1]
            }
            if abs(tecken) < 0.02, let k = fo {                  // näsan säger inget: mot FO-kameran
                let tx: Double = (k.c[0] - stans[0]) * c[0], ty: Double = (k.c[1] - stans[1]) * c[1]
                tecken = tx + ty
            }
            if tecken < 0 { c = c.map { -$0 } }
            let mitt: [Double] = [(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (golv + hi[2]) / 2]
            var omfang: [[Double]] = [stans]
            for i in stride(from: 0, to: f.n, by: 6) {
                for j in 0..<TreDFigur.antalLeder { if let v = f.led(i, j) { omfang.append(v) } }
            }
            return TreDRiktning(mitt: mitt, mal: m, fram: c, golv: golv, stans: stans, omfang: omfang, urFigur: true)
        }
        guard let fo, let dtl else { return nil }
        // Där blickarna möts (närmaste punkten mellan de två linjerna), om den ligger framför
        // båda; annars 3 m framför FO-kameran.
        var mot = [fo.c[0] + 3 * fo.fram[0], fo.c[1] + 3 * fo.fram[1], fo.c[2] + 3 * fo.fram[2]]
        let w = [fo.c[0] - dtl.c[0], fo.c[1] - dtl.c[1], fo.c[2] - dtl.c[2]]
        let a = LA.dot3(fo.fram, fo.fram), b = LA.dot3(fo.fram, dtl.fram), cc = LA.dot3(dtl.fram, dtl.fram)
        let d = LA.dot3(fo.fram, w), e = LA.dot3(dtl.fram, w)
        let nam = a * cc - b * b
        if abs(nam) > 1e-6 {
            let s = (b * e - cc * d) / nam, t = (a * e - b * d) / nam
            if s > 0.5, t > 0.5, s < 20, t < 20 {
                var m = [Double](repeating: 0, count: 3)
                for i in 0..<3 {
                    let pa: Double = fo.c[i] + s * fo.fram[i]
                    let pb: Double = dtl.c[i] + t * dtl.fram[i]
                    m[i] = (pa + pb) / 2
                }
                mot = m
            }
        }
        let golv = u.golv ?? (min(fo.c[2], dtl.c[2]) - 1.0)
        let fram = vagrat([fo.c[0] - mot[0], fo.c[1] - mot[1], 0]) ?? [-1, 0, 0]
        var m = LA.kryss(z, fram)
        if hand == .vanster { m = m.map { -$0 } }
        let stans: [Double] = [mot[0], mot[1], golv]
        return TreDRiktning(mitt: [mot[0], mot[1], golv + 0.9], mal: m, fram: fram, golv: golv, stans: stans,
                            omfang: [stans, [mot[0], mot[1], golv + 1.8]], urFigur: false)
    }
}

/// Kameran som figuren ses med: en punkt den kretsar kring, vridningen runt lodlinjen, höjden
/// över marken (vinkel) och avståndet. Ett finger vrider, en nypning zoomar. METOD MK11
public struct TreDBetraktare: Equatable, Sendable {
    public var mal: [Double]
    public var azimut: Double
    public var elevation: Double
    public var avstand: Double

    /// Synfältet över skärmens kortsida, grader.
    public static let fov = 40.0
    /// Höjden för Face on och Down the line, och för Top (inte 90°: då saknar vyn ett upp).
    public static let elevationSida = 6.0 * .pi / 180, elevationTop = 89.0 * .pi / 180
    /// Fingrets vridning, rad per pt, och höjdens gränser.
    public static let vridPerPt = 0.008
    public static let elevationGrans = (-10.0 * .pi / 180, 89.5 * .pi / 180)
    public static let avstandGrans = (0.5, 40.0)

    public init(mal: [Double], azimut: Double, elevation: Double, avstand: Double) {
        self.mal = mal
        self.azimut = azimut
        self.elevation = elevation
        self.avstand = avstand
    }

    /// En färdig vinkel kring figuren, passad så att hela svingen ryms på ytan (`bredd` × `hojd`
    /// pt); med `kameror` (telefonernas centrum) vidgas vyn så att de syns. Face on ser spelaren framifrån, Down the line bakifrån längs mållinjen, och Top
    /// uppifrån med målet till höger. METOD MK11
    public static func vinkel(_ v: TreDVinkel, _ r: TreDRiktning, kameror: [[Double]] = [], bredd: Double = 350,
                              hojd: Double = 440) -> TreDBetraktare {
        let az: Double, el: Double
        switch v {
        case .faceOn:
            az = atan2(r.fram[1], r.fram[0])
            el = elevationSida
        case .dtl:
            az = atan2(-r.mal[1], -r.mal[0])
            el = elevationSida
        case .top:
            // Skärmens högra = (−sin az, cos az, 0) när den ses uppifrån: målet.
            az = atan2(-r.mal[0], r.mal[1])
            el = elevationTop
        }
        return passad(TreDBetraktare(mal: r.mitt, azimut: az, elevation: el, avstand: 1), r.omfang + kameror,
                      bredd: bredd, hojd: hojd)
    }

    /// Andelen av ytans halva bredd och höjd som de passade punkterna får fylla.
    public static let fyllnad = (0.9, 0.86)

    /// Vyn flyttad och på det avstånd där punkterna ryms på ytan (`bredd` × `hojd` pt) med
    /// riktningen kvar: mitten där deras utbredning åt sidan och i höjd har sin mitt, och avståndet
    /// det minsta där varje punkt hamnar inom `fyllnad` och minst 0,5 m framför ögat. METOD MK11
    static func passad(_ b: TreDBetraktare, _ punkter: [[Double]], bredd: Double, hojd: Double) -> TreDBetraktare {
        guard !punkter.isEmpty else { return b }
        let pr = TreDProjektion(b, bredd: bredd, hojd: hojd)
        var lo = (Double.infinity, Double.infinity), hi = (-Double.infinity, -Double.infinity)
        for p in punkter {
            let q: [Double] = [p[0] - b.mal[0], p[1] - b.mal[1], p[2] - b.mal[2]]
            let x = LA.dot3(q, pr.hoger), y = LA.dot3(q, pr.upp)
            lo = (min(lo.0, x), min(lo.1, y))
            hi = (max(hi.0, x), max(hi.1, y))
        }
        var ut = b
        let sx: Double = (lo.0 + hi.0) / 2, sy: Double = (lo.1 + hi.1) / 2
        for a in 0..<3 { ut.mal[a] = b.mal[a] + sx * pr.hoger[a] + sy * pr.upp[a] }
        let f = pr.brannvidd
        let gx: Double = fyllnad.0 * bredd / 2, gy: Double = fyllnad.1 * hojd / 2
        var d = 0.5
        for p in punkter {
            let q: [Double] = [p[0] - ut.mal[0], p[1] - ut.mal[1], p[2] - ut.mal[2]]
            let x = abs(LA.dot3(q, pr.hoger)), y = abs(LA.dot3(q, pr.upp)), z = LA.dot3(q, pr.fram)
            d = max(d, f * x / gx - z, f * y / gy - z, 0.5 - z)
        }
        ut.avstand = min(avstandGrans.1, d)
        return ut
    }

    /// Efter ett drag med fingret (pt): åt sidan vrider runt lodlinjen, upp och ned ändrar höjden.
    public func vriden(dx: Double, dy: Double) -> TreDBetraktare {
        var b = self
        b.azimut -= dx * Self.vridPerPt
        b.elevation = min(Self.elevationGrans.1, max(Self.elevationGrans.0, elevation + dy * Self.vridPerPt))
        return b
    }

    /// Efter en nypning med faktorn k från avståndet `fran`.
    public func zoomad(_ k: Double, fran: Double) -> TreDBetraktare {
        var b = self
        if k > 0, k.isFinite { b.avstand = min(Self.avstandGrans.1, max(Self.avstandGrans.0, fran / k)) }
        return b
    }

    public var oga: [Double] {
        let c: Double = cos(elevation), d: Double = avstand
        let x: Double = mal[0] + d * c * cos(azimut), y: Double = mal[1] + d * c * sin(azimut)
        let z: Double = mal[2] + d * sin(elevation)
        return [x, y, z]
    }
}

/// Perspektivet från betraktaren till en yta på `bredd` × `hojd` pt (y nedåt). METOD MK11
public struct TreDProjektion: Sendable {
    public let oga: [Double]
    let fram: [Double], hoger: [Double], upp: [Double]
    public let brannvidd: Double
    let cx: Double, cy: Double
    /// Punkter närmare ögat än så ritas inte (linjer klipps där), m.
    public static let nara = 0.05

    public init(_ b: TreDBetraktare, bredd: Double, hojd: Double) {
        let o = b.oga
        oga = o
        let f: [Double] = [b.mal[0] - o[0], b.mal[1] - o[1], b.mal[2] - o[2]]
        let nf = LA.norm3(f)
        let fr: [Double] = [f[0] / nf, f[1] / nf, f[2] / nf]
        fram = fr
        var h = LA.kryss(fr, [0, 0, 1])
        let nh = LA.norm3(h)
        h = nh > 1e-9 ? [h[0] / nh, h[1] / nh, h[2] / nh] : [1, 0, 0]
        hoger = h
        upp = LA.kryss(h, fr)
        brannvidd = (min(bredd, hojd) / 2) / tan(TreDBetraktare.fov / 2 * .pi / 180)
        cx = bredd / 2
        cy = hojd / 2
    }

    /// Kamerans ram: (höger, upp, djup).
    func ram(_ p: [Double]) -> (Double, Double, Double) {
        let d = [p[0] - oga[0], p[1] - oga[1], p[2] - oga[2]]
        return (LA.dot3(d, hoger), LA.dot3(d, upp), LA.dot3(d, fram))
    }

    func skarm(_ x: Double, _ y: Double, _ z: Double) -> Punkt {
        let u: Double = cx + brannvidd * x / z
        let v: Double = cy - brannvidd * y / z
        return Punkt(u, v)
    }

    /// Punkten på ytan och djupet (m), nil bakom ögat eller utan värde.
    public func punkt(_ p: [Double]) -> (p: Punkt, djup: Double)? {
        guard p.count == 3, p.allSatisfy(\.isFinite) else { return nil }
        let (x, y, z) = ram(p)
        guard z > Self.nara else { return nil }
        return (skarm(x, y, z), z)
    }

    /// En linje på ytan, klippt där den passerar bakom ögat; nil när hela ligger bakom.
    public func linje(_ a: [Double], _ b: [Double]) -> (Punkt, Punkt)? {
        guard a.count == 3, b.count == 3, (a + b).allSatisfy(\.isFinite) else { return nil }
        var (ax, ay, az) = ram(a)
        var (bx, by, bz) = ram(b)
        if az <= Self.nara && bz <= Self.nara { return nil }
        if az < Self.nara {
            let s: Double = (Self.nara - az) / (bz - az)
            ax += s * (bx - ax)
            ay += s * (by - ay)
            az = Self.nara
        } else if bz < Self.nara {
            let s: Double = (Self.nara - bz) / (az - bz)
            bx += s * (ax - bx)
            by += s * (ay - by)
            bz = Self.nara
        }
        return (skarm(ax, ay, az), skarm(bx, by, bz))
    }
}

/// Figurens streck: axellinjen, armarna, sidorna av bålen, höftlinjen och benen (samma som
/// visaren, `kontaktark.BEN`), med sidan så att vänster och höger kan ritas olika. METOD MK11
public enum TreDStreck {
    public enum Sida: Sendable { case vanster, hoger, mitt }
    public static let ben: [(a: Int, b: Int, sida: Sida)] = [
        (1, 2, .mitt), (1, 3, .vanster), (3, 5, .vanster), (2, 4, .hoger), (4, 6, .hoger), (7, 8, .mitt),
        (1, 7, .vanster), (2, 8, .hoger), (7, 9, .vanster), (9, 11, .vanster), (8, 10, .hoger), (10, 12, .hoger),
    ]

    /// Ledens sida: personens vänstra (udda index), högra (jämna) eller näsan.
    public static func sida(_ j: Int) -> Sida { j == 0 ? .mitt : (j % 2 == 1 ? .vanster : .hoger) }
}

/// Ett spår i 3D (S4f:s punkter, BESLUT B70): S4f:s `SparSerie` bär tiden, avbrotten och
/// delningen i spelat och kvar, och `xyz` punkterna i världen med samma index. METOD MK11, M60
public struct TreDSpar: Equatable, Sendable {
    public var serie: SparSerie
    public var xyz: [Double]

    public func punkt(_ i: Int) -> [Double] { [xyz[i * 3], xyz[i * 3 + 1], xyz[i * 3 + 2]] }

    /// Lederna per punkt (filens ordning), en serie per post; händerna med greppregeln (M1).
    static func leder(_ p: SparPunkt) -> [[Int]] {
        switch p {
        case .hands: return [[5, 6]]
        case .shoulders: return [[1], [2]]
        case .hips: return [[7], [8]]
        case .head: return [[0]]
        case .club: return []
        }
    }

    /// Spåren för punkterna i `val` ur figuren. Händerna är handledernas mitt, där en saknad
    /// handled tar den andras plats (greppregeln, M1), och banan bryts där regeln byter handled,
    /// som i S4f. Ingen ny utjämning: lederna är redan jämnade före trianguleringen (MK5).
    /// Klubbhuvudet kräver S7b:s bana i båda vyerna och ingår inte än. METOD MK11, M60
    public static func spar(_ f: TreDFigur, val: [SparPunkt]) -> [TreDSpar] {
        let t = (0..<f.n).map { f.t($0) }
        var ut: [TreDSpar] = []
        for punkt in SparPunkt.allCases where val.contains(punkt) {
            let grupper = leder(punkt)
            for (k, grupp) in grupper.enumerated() {
                var xyz = [Double](repeating: .nan, count: f.n * 3)
                var brott: Set<Int> = []
                var forra = -1
                for i in 0..<f.n {
                    var v: [Double]?
                    var lage = -1
                    if grupp.count == 2 {
                        let a = f.led(i, grupp[0]), b = f.led(i, grupp[1])
                        switch (a, b) {
                        case let (a?, b?):
                            v = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2]
                            lage = 0
                        case let (a?, nil):
                            v = a
                            lage = 1
                        case let (nil, b?):
                            v = b
                            lage = 2
                        default: break
                        }
                    } else {
                        v = f.led(i, grupp[0])
                        lage = v == nil ? -1 : 0
                    }
                    if lage >= 0 {
                        if forra >= 0 && lage != forra { brott.insert(i) }
                        forra = lage
                    }
                    if let v { xyz.replaceSubrange((i * 3)..<(i * 3 + 3), with: v) }
                }
                // Seriens punkter bär bara om punkten finns (avbrotten); läget står i xyz.
                let p = (0..<f.n).map { i in xyz[i * 3].isFinite ? Punkt(xyz[i * 3], xyz[i * 3 + 1]) : .saknad }
                let id = grupper.count > 1 ? "\(punkt.rawValue)_\(k == 0 ? "v" : "h")" : punkt.rawValue
                ut.append(TreDSpar(serie: SparSerie(id: id, punkt: punkt, t: t, p: p, brott: brott), xyz: xyz))
            }
        }
        return ut
    }
}
