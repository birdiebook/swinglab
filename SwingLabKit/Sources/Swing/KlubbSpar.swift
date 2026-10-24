import Foundation

// Klubbhuvudets bana mellan ankarna (PLAN S7b, METOD M61, BESLUT B71): Johannes tryck vid
// P1–P10 (S7a) är ankare, och mellan två ankare spåras klubbhuvudet med rörelsedifferens i
// gråskalerutor. Samma räkning och samma tal som tools/pc/klubbspar.py (BESLUT B12, inom
// 1e-6). Bildläsningen sker i appen; här är rutorna byte-arrayer.

public enum KlubbSpar {
    /// Rutorna t−2 och t+2. METOD M61
    public static let steg = 2
    /// Gråtoner i båda differenserna. METOD M61
    public static let troskel = 40
    /// Korridorens radie i skaft. METOD M61
    public static let rMin = 0.5, rMax = 1.35
    /// Korridorens halva vinkel, minst … METOD M61
    public static let vinkelMin = 30.0 * (Double.pi / 180.0)
    /// … och annars halva vridningen mellan ankarna. METOD M61
    public static let vinkelAndel = 0.5
    /// Färre rörliga pixlar = tappad. METOD M61
    public static let minPix = 5
    /// Klubbhuvudets bredd i skaft (bandet ytterst). METOD M61
    public static let huvud = 0.12
    /// Bandet minst så brett tvärs skaftet, i skaft (annars syns bara skaftet). METOD M61
    public static let bred = 0.05
    /// Längsta steg per ruta, i skaft. METOD M61
    public static let sprang = 0.5
    /// Maskens radier i bålens längd: lemmarna, bålen, huvudet och händerna. METOD M61
    public static let kropp = 0.18, bal = 0.35, huvudet = 0.40, handerna = 0.20
    /// Närmare P1:s hosel än så (i P1-skaft) mäts inte planet. METOD M61
    public static let planMin = 0.25
    static let ben = [(1, 2), (7, 8), (1, 3), (3, 5), (2, 4), (4, 6), (7, 9), (9, 11), (8, 10), (10, 12)]

    /// Källan för en spårad och en interpolerad ruta (BESLUT B71).
    public static let kallaSpar = "spar", kallaInterpolerad = "interpolerad"

    /// En ruta: tiden (s relativt klicket), bilden i gråskala (rad för rad, `bredd` × `hojd`
    /// i rutans upplösning) och de 13 lederna i hela bildens pixlar (nil = konfidens under
    /// 0,3, M1).
    public struct Ruta: Sendable {
        public var t: Double
        public var bild: [UInt8]
        public var leder: [Punkt?]

        public init(t: Double, bild: [UInt8], leder: [Punkt?]) {
            self.t = t
            self.bild = bild
            self.leder = leder
        }
    }

    /// En punkt i banan, i hela bildens pixlar, med källan `klick` (ankaret), `spar` eller
    /// `interpolerad`.
    public struct BanPunkt: Equatable, Sendable {
        public var t: Double
        public var x: Double
        public var y: Double
        public var kalla: String

        public init(t: Double, x: Double, y: Double, kalla: String) {
            self.t = t
            self.x = x
            self.y = y
            self.kalla = kalla
        }
    }

    static func wrap(_ a: Double) -> Double {
        var r = fmod(a + Double.pi, 2.0 * Double.pi)
        if r < 0.0 { r += 2.0 * Double.pi }
        r -= Double.pi
        return r == -Double.pi ? Double.pi : r
    }

    static func langd(_ dx: Double, _ dy: Double) -> Double { (dx * dx + dy * dy).squareRoot() }

    static func mitt(_ a: Punkt?, _ b: Punkt?) -> Punkt? {
        guard let a, let b else { return nil }
        return Punkt((a.x + b.x) / 2.0, (a.y + b.y) / 2.0)
    }

    /// Handledernas mitt per ruta med greppregeln (M1), utjämnad (M3); nil = saknas.
    static func handernasMitt(_ t: [Double], _ leder: [[Punkt?]]) -> [Punkt?] {
        let p = leder.map { L -> Punkt in mitt(L[5], L[6]) ?? L[5] ?? L[6] ?? .saknad }
        return Faser.jamna(t, p).map { $0.hel ? $0 : nil }
    }

    /// Medianen av axlarnas mitt → höfternas mitt över rutorna där alla fyra finns.
    static func balensLangd(_ leder: [[Punkt?]]) -> Double? {
        var v: [Double] = []
        for L in leder {
            if let a = mitt(L[1], L[2]), let h = mitt(L[7], L[8]) { v.append(langd(a.x - h.x, a.y - h.y)) }
        }
        guard !v.isEmpty else { return nil }
        v.sort()
        let n = v.count
        return n % 2 == 1 ? v[n / 2] : (v[n / 2 - 1] + v[n / 2]) / 2.0
    }

    struct Streck {
        let a: Punkt
        let b: Punkt
        let r: Double
    }

    static func naraStreck(_ px: Double, _ py: Double, _ s: Streck) -> Bool {
        let dx = s.b.x - s.a.x, dy = s.b.y - s.a.y
        let n2 = dx * dx + dy * dy
        var u = 0.0
        if n2 > 0.0 {
            u = ((px - s.a.x) * dx + (py - s.a.y) * dy) / n2
            u = min(max(u, 0.0), 1.0)
        }
        let ex = px - (s.a.x + u * dx)
        let ey = py - (s.a.y + u * dy)
        return ex * ex + ey * ey <= s.r * s.r
    }

    /// Maskens streck i rutans pixlar ur lederna i rutan; en saknad led tar bort sina streck.
    static func kroppensStreck(_ L: [Punkt?], _ b: Double) -> [Streck] {
        var ut: [Streck] = []
        for (i, j) in ben {
            if let p = L[i], let q = L[j] { ut.append(Streck(a: p, b: q, r: kropp * b)) }
        }
        if let a = mitt(L[1], L[2]), let h = mitt(L[7], L[8]) { ut.append(Streck(a: a, b: h, r: bal * b)) }
        if let n = L[0] { ut.append(Streck(a: n, b: n, r: huvudet * b)) }
        if let g = mitt(L[5], L[6]) ?? L[5] ?? L[6] { ut.append(Streck(a: g, b: g, r: handerna * b)) }
        return ut
    }

    /// Klubbhuvudet i ruta k i rutans pixlar, eller nil (för lite rörelse eller bara skaftet).
    static func hitta(_ rutor: [Ruta], _ k: Int, bredd w: Int, hojd h: Int, g: Punkt, theta: Double, lim: Double,
                      L: Double, streck: [Streck]) -> Punkt? {
        guard k - steg >= 0, k + steg < rutor.count else { return nil }
        let I = rutor[k].bild, A = rutor[k - steg].bild, B = rutor[k + steg].bild
        guard I.count == w * h, A.count == w * h, B.count == w * h else { return nil }
        let rmin = rMin * L, rmax = rMax * L
        let x0 = max(0, Int(floor(g.x - rmax))), x1 = min(w - 1, Int(ceil(g.x + rmax)))
        let y0 = max(0, Int(floor(g.y - rmax))), y1 = min(h - 1, Int(ceil(g.y + rmax)))
        guard x1 >= x0, y1 >= y0 else { return nil }
        let ux = cos(theta), uy = sin(theta), cl = cos(lim)
        // Kandidaterna: (cx, cy, vx, vy, r) i radordning, som numpy.
        var kand: [(cx: Double, cy: Double, vx: Double, vy: Double, r: Double)] = []
        for j in y0...y1 {
            for i in x0...x1 {
                let cx = Double(i) + 0.5, cy = Double(j) + 0.5
                let vx = cx - g.x, vy = cy - g.y
                let r = (vx * vx + vy * vy).squareRoot()
                guard r >= rmin, r <= rmax, vx * ux + vy * uy >= r * cl else { continue }
                let n = j * w + i
                let a = Int(I[n])
                guard min(abs(a - Int(A[n])), abs(a - Int(B[n]))) >= troskel else { continue }
                if streck.contains(where: { naraStreck(cx, cy, $0) }) { continue }
                kand.append((cx, cy, vx, vy, r))
            }
        }
        let n = kand.count
        guard n >= minPix else { return nil }
        let rs = kand.map(\.r).sorted(by: >)
        let rEnd = rs[min(2, n - 1)]
        let band = kand.filter { $0.r >= rEnd - huvud * L }
        let m = Double(band.count)
        let mx = band.reduce(0.0) { $0 + $1.cx } / m, my = band.reduce(0.0) { $0 + $1.cy } / m
        // Bredden tvärs riktningen greppet → bandets mitt.
        let ex = mx - g.x, ey = my - g.y
        let en = langd(ex, ey)
        var lo = Double.infinity, hi = -Double.infinity
        for q in band {
            let v = q.vx * (-ey / en) + q.vy * (ex / en)
            lo = min(lo, v)
            hi = max(hi, v)
        }
        guard hi - lo >= bred * L else { return nil }
        return Punkt(mx, my)
    }

    /// Banan: en punkt per ruta från första till sista ankaret (nil utanför), i hela bildens
    /// pixlar. `rutor` i tidsordning, bilderna `bredd` × `hojd` i rutans upplösning, `skala` =
    /// rutans px per bildens px; `ankare` = markerade positioner (S7a). METOD M61
    public static func spara(_ rutor: [Ruta], bredd: Int, hojd: Int, skala: Double,
                             ankare: [KlubbMarkering]) -> [BanPunkt?] {
        let n = rutor.count
        var ut = [BanPunkt?](repeating: nil, count: n)
        let markerade = ankare.filter(\.markerad)
        guard n > 0, !markerade.isEmpty else { return ut }
        let t = rutor.map(\.t)
        let Ls = rutor.map { r in r.leder.map { $0.map { Punkt($0.x * skala, $0.y * skala) } } }
        let hm = handernasMitt(t, Ls)
        let b = balensLangd(Ls) ?? 0.0
        struct Ankare {
            let g: Punkt, h: Punkt, off: Punkt, L: Double, theta: Double
        }
        var ank: [Int: Ankare] = [:]
        // Stabil sortering på tiden (som Pythons sorted).
        for a in markerade.enumerated().sorted(by: { ($0.element.t, $0.offset) < ($1.element.t, $1.offset) }).map(\.element) {
            var k = 0
            for j in 1..<n where abs(t[j] - a.t) < abs(t[k] - a.t) { k = j }
            let g = Punkt(a.grepp!.x * skala, a.grepp!.y * skala)
            let hs = Punkt(a.hosel!.x * skala, a.hosel!.y * skala)
            let off = hm[k].map { Punkt(g.x - $0.x, g.y - $0.y) } ?? Punkt(0.0, 0.0)
            ank[k] = Ankare(g: g, h: hs, off: off, L: langd(hs.x - g.x, hs.y - g.y), theta: atan2(hs.y - g.y, hs.x - g.x))
        }
        let ks = ank.keys.sorted()
        var punkt: [Int: Punkt] = [:], kalla: [Int: String] = [:], grepp: [Int: Punkt?] = [:]
        for k in ks {
            punkt[k] = ank[k]!.h
            kalla[k] = Klubba.kalla
            grepp[k] = ank[k]!.g
        }
        for (ka, kb) in zip(ks, ks.dropFirst()) {
            let A = ank[ka]!, B = ank[kb]!
            let dth = wrap(B.theta - A.theta)
            let lim = max(vinkelMin, vinkelAndel * abs(dth))
            var forra = A.h, kforra = ka
            var tappade: [Int] = []
            for k in (ka + 1)..<kb {
                let f = (t[k] - t[ka]) / (t[kb] - t[ka])
                let L = A.L + f * (B.L - A.L)
                guard let m = hm[k] else {
                    grepp[k] = .some(nil)
                    tappade.append(k)
                    continue
                }
                let g = Punkt(m.x + A.off.x + f * (B.off.x - A.off.x), m.y + A.off.y + f * (B.off.y - A.off.y))
                grepp[k] = g
                var q = hitta(rutor, k, bredd: bredd, hojd: hojd, g: g, theta: A.theta + f * dth, lim: lim, L: L,
                              streck: kroppensStreck(Ls[k], b))
                if let p = q, langd(p.x - forra.x, p.y - forra.y) > sprang * L * Double(k - kforra) { q = nil }
                guard let p = q else {
                    tappade.append(k)
                    continue
                }
                punkt[k] = p
                kalla[k] = kallaSpar
                forra = p
                kforra = k
            }
            // De tappade: polärt kring greppet mellan de säkra grannarna (spårade eller ankare).
            let saker = Set(punkt.keys)
            var nya: [Int: Punkt] = [:]
            for k in tappade {
                let k0 = (ka..<k).last { saker.contains($0) }!
                let k1 = ((k + 1)...kb).first { saker.contains($0) }!
                let f = (t[k] - t[k0]) / (t[k1] - t[k0])
                let g0 = grepp[k0]!!, g1 = grepp[k1]!!
                let g = (grepp[k] ?? nil) ?? Punkt(g0.x + f * (g1.x - g0.x), g0.y + f * (g1.y - g0.y))
                let p0 = punkt[k0]!, p1 = punkt[k1]!
                let a0 = atan2(p0.y - g0.y, p0.x - g0.x)
                let a1 = atan2(p1.y - g1.y, p1.x - g1.x)
                let r0 = langd(p0.x - g0.x, p0.y - g0.y)
                let r1 = langd(p1.x - g1.x, p1.y - g1.y)
                let a = a0 + f * wrap(a1 - a0)
                let r = r0 + f * (r1 - r0)
                kalla[k] = kallaInterpolerad
                nya[k] = Punkt(g.x + r * cos(a), g.y + r * sin(a))
            }
            for (k, p) in nya { punkt[k] = p }
        }
        for (k, q) in punkt {
            ut[k] = BanPunkt(t: t[k], x: q.x / skala, y: q.y / skala, kalla: kalla[k]!)
        }
        return ut
    }

    /// Klubbhuvudet mot P1-planet bakifrån i varje ruta från P5 till P7: samma vinkel som
    /// `skaft_plan_p6` (M47) med banans punkt, grader, + = över planet. Kräver P1, P5 och P7
    /// bland ankarna; tomt annars. En punkt närmare P1:s hosel än `planMin` skaft mäts inte.
    /// Visas inte i appen än (BESLUT B71). Som `klubbspar.planet`. METOD M61
    public static func planet(_ bana: [BanPunkt?], ankare: [KlubbMarkering], xTecken s: Double)
        -> [(t: Double, grader: Double, kalla: String)] {
        var pos: [String: KlubbMarkering] = [:]
        for a in ankare where a.markerad { pos[a.position] = a }
        guard let p1 = pos["P1"], let p5 = pos["P5"], let p7 = pos["P7"] else { return [] }
        let g1 = Punkt(s * p1.grepp!.x, p1.grepp!.y), h1 = Punkt(s * p1.hosel!.x, p1.hosel!.y)
        let L1 = langd(h1.x - g1.x, h1.y - g1.y)
        var ut: [(t: Double, grader: Double, kalla: String)] = []
        for b in bana {
            guard let b, p5.t - 1e-9 <= b.t, b.t <= p7.t + 1e-9 else { continue }
            let q = Punkt(s * b.x, b.y)
            if langd(q.x - h1.x, q.y - h1.y) < planMin * L1 { continue }
            ut.append((b.t, -Klubba.vinkelMellan(Klubba.upp(h1, g1), Klubba.upp(h1, q)), b.kalla))
        }
        return ut
    }
}

// MARK: - Datamodellen (BESLUT B71)

/// En punkt i klubbhuvudets sparade bana (S7b): tiden, punkten i hela bildens pixlar, källan
/// (`klick` = ankaret, `spar`, `interpolerad`, eller `klick` i en rättad ruta) och Johannes
/// granskning. En rättad punkt behåller maskinens punkt i `fore` och dess källa i
/// `foreKalla`, så att träningsdatan kan skilja dem. BESLUT B71
public struct KlubbBanPunkt: Codable, Equatable, Sendable {
    public static let godkand = "godkand", rattad = "rattad"
    public var t: Double
    public var x: Double
    public var y: Double
    public var kalla: String
    /// nil = ogranskad, "godkand" eller "rattad".
    public var granskning: String?
    public var fore: KlubbPunkt?
    public var foreKalla: String?

    public init(t: Double, x: Double, y: Double, kalla: String, granskning: String? = nil, fore: KlubbPunkt? = nil,
                foreKalla: String? = nil) {
        self.t = t
        self.x = x
        self.y = y
        self.kalla = kalla
        self.granskning = granskning
        self.fore = fore
        self.foreKalla = foreKalla
    }

    /// Spårad eller interpolerad, inte ett ankare och inte rättad.
    public var maskinens: Bool { kalla == KlubbSpar.kallaSpar || kalla == KlubbSpar.kallaInterpolerad }
}

/// Klubbhuvudets bana för ett slag (S7b), sparad i `pass.json` (`slag[].klubbaBana`) med
/// ankarna den räknades ur, så att en ändrad markering ger en ny bana. BESLUT B71, METOD M61
public struct KlubbBana: Codable, Equatable, Sendable {
    /// Räkningens version (M61); en annan version räknas om.
    public static let aktuellVersion = 1
    public var version: Int
    public var ankare: [KlubbMarkering]
    public var punkter: [KlubbBanPunkt]

    public init(version: Int = KlubbBana.aktuellVersion, ankare: [KlubbMarkering], punkter: [KlubbBanPunkt]) {
        self.version = version
        self.ankare = ankare
        self.punkter = punkter
    }

    /// Ankarna som räknas: markerade positioner, med bara det som spårningen läser.
    public static func ankare(_ marks: [KlubbMarkering]?) -> [KlubbMarkering] {
        (marks ?? []).filter(\.markerad).map {
            KlubbMarkering(position: $0.position, t: $0.t, grepp: $0.grepp, hosel: $0.hosel)
        }.sorted { $0.t < $1.t }
    }

    /// Minst två markerade positioner behövs för en bana.
    public static func mojlig(_ marks: [KlubbMarkering]?) -> Bool { ankare(marks).count >= 2 }

    /// Banan ur spårningen (KlubbSpar.spara) och ankarna.
    public init(_ bana: [KlubbSpar.BanPunkt?], ankare marks: [KlubbMarkering]?) {
        self.init(ankare: Self.ankare(marks),
                  punkter: bana.compactMap { $0.map { KlubbBanPunkt(t: $0.t, x: $0.x, y: $0.y, kalla: $0.kalla) } })
    }

    /// Banan är räknad ur dessa markeringar med dagens räkning.
    public func aktuell(_ marks: [KlubbMarkering]?) -> Bool {
        version == Self.aktuellVersion && ankare == Self.ankare(marks)
    }

    /// Andelen interpolerade punkter (0–1).
    public var andelInterpolerade: Double {
        punkter.isEmpty ? 0 : Double(punkter.filter { $0.kalla == KlubbSpar.kallaInterpolerad }.count) / Double(punkter.count)
    }

    /// Johannes godkänner maskinens punkt i rutan (ett tryck, senare i appen). BESLUT B71
    public mutating func godkann(_ i: Int) {
        guard punkter.indices.contains(i), punkter[i].maskinens else { return }
        punkter[i].granskning = KlubbBanPunkt.godkand
    }

    /// Johannes flyttar punkten: källan blir `klick`, och maskinens punkt sparas. BESLUT B71
    public mutating func ratta(_ i: Int, till p: KlubbPunkt) {
        guard punkter.indices.contains(i) else { return }
        var q = punkter[i]
        if q.maskinens {
            q.fore = KlubbPunkt(x: q.x, y: q.y)
            q.foreKalla = q.kalla
        }
        guard q.fore != nil else { return }        // ett ankare rättas i märkningen, inte här
        q.x = p.x
        q.y = p.y
        q.kalla = Klubba.kalla
        q.granskning = KlubbBanPunkt.rattad
        punkter[i] = q
    }
}
