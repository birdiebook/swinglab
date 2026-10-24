import Foundation

// Klubbhuvudets bana mellan ankarna (PLAN S7b, METOD M61, BESLUT B71): Johannes tryck vid
// P1–P10 (S7a) är ankare, och bara mellan två ankare som är grannar i svingens ordning spåras
// klubbhuvudet med rörelsedifferens i gråskalerutor. Samma räkning och samma tal som
// tools/pc/klubbspar.py (BESLUT B12, inom 1e-6). Bildläsningen sker i appen; här är rutorna
// byte-arrayer som hämtas ruta för ruta i tidsordning (appen strömmar dem).

public enum KlubbSpar {
    /// Rutorna så långt före och efter, s. METOD M61
    public static let stegS = 2.0 / 240
    /// Tröskeln i σ av differensen (σ ur MAD) … METOD M61
    public static let troskelK = 3.5
    /// … men minst så många gråtoner. METOD M61
    public static let troskelMin = 8.0
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
    /// Bandet minst så brett tvärs riktningen, i skaft (annars syns bara skaftet). METOD M61
    public static let bred = 0.05
    /// Rörliga pixlar utanför kroppen och korridoren, andel av sökrutan. METOD M61
    public static let skak = 0.01
    /// |avståndet till greppet − skaftet| högst så mycket, i skaft. METOD M61
    public static let radieTol = 0.25
    /// Längsta förflyttning, skaft per sekund. METOD M61
    public static let sprangS = 120.0
    /// Förskjutningen mitt → hosel räknas mellan så mycket och så mycket, i skaft. METOD M61
    public static let mittMin = 0.03, mittMax = 0.12
    /// Högst så långt från grannarnas interpolation, i skaft. METOD M61
    public static let granne = 0.10
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
        return v.isEmpty ? nil : median(v)
    }

    static func median(_ v: [Double]) -> Double {
        let s = v.sorted()
        let n = s.count
        return n % 2 == 1 ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2.0
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

    /// Rutorna närmast `stegS` före och efter ruta k (högst tre rutor bort), eller nil när
    /// ingen ligger inom 0,6 `stegS` från det (en saknad ruta ger 3/240 s). METOD M61
    public static func grannrutor(_ t: [Double], _ k: Int) -> (fore: Int, efter: Int)? {
        func bast(_ js: [Int]) -> Int? {
            var b: Int? = nil
            for j in js where b == nil || abs(abs(t[k] - t[j]) - stegS) < abs(abs(t[k] - t[b!]) - stegS) { b = j }
            guard let b, abs(abs(t[k] - t[b]) - stegS) <= 0.6 * stegS else { return nil }
            return b
        }
        guard let a = bast(Array(max(0, k - 3)..<k)), let b = bast(Array((k + 1)..<min(t.count, k + 4))) else {
            return nil
        }
        return (a, b)
    }

    /// Klubbhuvudets rörliga mitt i ruta I (rutorna A före och B efter) i rutans pixlar, eller
    /// nil: för lite rörelse, bara skaftet, eller skak. Som `klubbspar.hitta`. METOD M61
    static func hitta(_ I: [UInt8], _ A: [UInt8], _ B: [UInt8], bredd w: Int, hojd h: Int, g: Punkt, theta: Double,
                      lim: Double, L: Double, streck: [Streck]) -> Punkt? {
        guard I.count == w * h, A.count == w * h, B.count == w * h else { return nil }
        let rmin = rMin * L, rmax = rMax * L
        let x0 = max(0, Int(floor(g.x - rmax))), x1 = min(w - 1, Int(ceil(g.x + rmax)))
        let y0 = max(0, Int(floor(g.y - rmax))), y1 = min(h - 1, Int(ceil(g.y + rmax)))
        guard x1 >= x0, y1 >= y0 else { return nil }
        let bw = x1 - x0 + 1, bh = y1 - y0 + 1, antal = bw * bh
        let ux = cos(theta), uy = sin(theta), cl = cos(lim)
        // Differenserna i sökrutan, rad för rad.
        var d1 = [Int](repeating: 0, count: antal), d2 = [Int](repeating: 0, count: antal)
        for j in 0..<bh {
            for i in 0..<bw {
                let n = (y0 + j) * w + (x0 + i)
                let a = Int(I[n])
                d1[j * bw + i] = a - Int(A[n])
                d2[j * bw + i] = a - Int(B[n])
            }
        }
        // Brusets σ ur differensens MAD (1,4826 · MAD) i hela sökrutan. METOD M61
        let m = median(d1.map(Double.init))
        let sigma = 1.4826 * median(d1.map { abs(Double($0) - m) })
        let troskel = max(troskelMin, troskelK * sigma)
        var ok = [Bool](repeating: false, count: antal)
        var r = [Double](repeating: 0, count: antal)
        var utanfor = 0
        for j in 0..<bh {
            for i in 0..<bw {
                let q = j * bw + i
                let cx = Double(x0 + i) + 0.5, cy = Double(y0 + j) + 0.5
                let vx = cx - g.x, vy = cy - g.y
                let rr = (vx * vx + vy * vy).squareRoot()
                r[q] = rr
                guard Double(min(abs(d1[q]), abs(d2[q]))) >= troskel else { continue }
                if streck.contains(where: { naraStreck(cx, cy, $0) }) { continue }
                let korridor = rr >= rmin && rr <= rmax && vx * ux + vy * uy >= rr * cl
                if korridor { ok[q] = true } else { utanfor += 1 }
            }
        }
        if Double(utanfor) > skak * Double(antal) { return nil }
        // Fläckarna (8-grannar): klubbhuvudet är fläcken vars yttre kant ligger närmast L.
        guard let flack = flacken(ok, r, bredd: bw, hojd: bh, L: L) else { return nil }
        let rs = flack.map { r[$0] }.sorted(by: >)
        let rEnd = rs[min(2, rs.count - 1)]
        let band = flack.filter { r[$0] >= rEnd - huvud * L }.sorted()
        let mb = Double(band.count)
        var sx = 0.0, sy = 0.0
        for q in band {
            sx += Double(x0 + q % bw) + 0.5
            sy += Double(y0 + q / bw) + 0.5
        }
        let mx = sx / mb, my = sy / mb
        // Bredden tvärs riktningen greppet → bandets mitt.
        let ex = mx - g.x, ey = my - g.y
        let en = langd(ex, ey)
        var lo = Double.infinity, hi = -Double.infinity
        for q in band {
            let vx = Double(x0 + q % bw) + 0.5 - g.x, vy = Double(y0 + q / bw) + 0.5 - g.y
            let v = vx * (-ey / en) + vy * (ex / en)
            lo = min(lo, v)
            hi = max(hi, v)
        }
        guard hi - lo >= bred * L else { return nil }
        return Punkt(mx, my)
    }

    /// Fläcken (8-grannar) med minst `minPix` pixlar vars yttre kant (den tredje yttersta
    /// pixeln) ligger närmast L från greppet; lika: den som hittas först rad för rad. Index i
    /// sökrutan, eller nil. Som `klubbspar._flacken`. METOD M61
    static func flacken(_ ok: [Bool], _ r: [Double], bredd w: Int, hojd h: Int, L: Double) -> [Int]? {
        var etikett = [Int](repeating: -1, count: ok.count)
        var basta: [Int]? = nil, bastaD = Double.infinity, nr = 0
        for start in ok.indices where ok[start] && etikett[start] < 0 {
            var stack = [start], pix: [Int] = []
            etikett[start] = nr
            while let q = stack.popLast() {
                pix.append(q)
                let y = q / w, x = q % w
                for dy in -1...1 {
                    for dx in -1...1 {
                        let yy = y + dy, xx = x + dx
                        guard yy >= 0, yy < h, xx >= 0, xx < w else { continue }
                        let n = yy * w + xx
                        if ok[n] && etikett[n] < 0 {
                            etikett[n] = nr
                            stack.append(n)
                        }
                    }
                }
            }
            if pix.count >= minPix {
                let rr = pix.map { r[$0] }.sorted(by: >)
                let d = abs(rr[2] - L)
                if d < bastaD {
                    basta = pix
                    bastaD = d
                }
            }
            nr += 1
        }
        return basta
    }

    /// Paren av ankare (index i tidsordningen) som är grannar i svingens ordning P1 → P10.
    public static func segment(_ positioner: [String]) -> [(Int, Int)] {
        var ut: [(Int, Int)] = []
        for i in 0..<max(0, positioner.count - 1) {
            if let a = Klubba.positioner.firstIndex(of: positioner[i]),
               let b = Klubba.positioner.firstIndex(of: positioner[i + 1]), b == a + 1 {
                ut.append((i, i + 1))
            }
        }
        return ut
    }

    /// Punkten en andel f mellan p0 (kring g0) och p1 (kring g1), polärt kring g.
    static func polar(_ g0: Punkt, _ p0: Punkt, _ g1: Punkt, _ p1: Punkt, _ g: Punkt, _ f: Double) -> Punkt {
        let a0 = atan2(p0.y - g0.y, p0.x - g0.x)
        let a1 = atan2(p1.y - g1.y, p1.x - g1.x)
        let r0 = langd(p0.x - g0.x, p0.y - g0.y)
        let r1 = langd(p1.x - g1.x, p1.y - g1.y)
        let a = a0 + f * wrap(a1 - a0)
        let r = r0 + f * (r1 - r0)
        return Punkt(g.x + r * cos(a), g.y + r * sin(a))
    }

    /// Banan ur rutor i minnet (proven); appen strömmar med `spara(t:leder:...bild:)`.
    public static func spara(_ rutor: [Ruta], bredd: Int, hojd: Int, skala: Double,
                             ankare: [KlubbMarkering], bildBredd: Int? = nil, bildHojd: Int? = nil) -> [BanPunkt?] {
        spara(t: rutor.map(\.t), leder: rutor.map(\.leder), bredd: bredd, hojd: hojd, skala: skala, ankare: ankare,
              bildBredd: bildBredd, bildHojd: bildHojd) { rutor.indices.contains($0) ? rutor[$0].bild : nil }
    }

    /// Banan: en punkt per ruta (nil där ingen bana räknas), i hela bildens pixlar. `t` i
    /// tidsordning, `leder` per ruta i hela bildens pixlar, rutorna `bredd` × `hojd` i rutans
    /// upplösning, `skala` = rutans px per bildens px, `ankare` = markerade positioner (S7a),
    /// `bildBredd` × `bildHojd` = hela bilden (punkter utanför skrivs inte). `bild(k)` hämtar
    /// ruta k; den anropas i tidsordning och högst tre rutor bort från rutan som räknas, så att
    /// appen kan läsa filen en gång med en ringbuffert. nil från `bild` = rutan saknas. Avbryts
    /// när `avbruten()` blir sann (nil tillbaka). Som `klubbspar.spara`. METOD M61
    public static func spara(t: [Double], leder: [[Punkt?]], bredd: Int, hojd: Int, skala: Double,
                             ankare: [KlubbMarkering], bildBredd: Int? = nil, bildHojd: Int? = nil,
                             avbruten: () -> Bool = { false }, bild: (Int) -> [UInt8]?) -> [BanPunkt?] {
        sparaAvbrytbar(t: t, leder: leder, bredd: bredd, hojd: hojd, skala: skala, ankare: ankare,
                       bildBredd: bildBredd, bildHojd: bildHojd, avbruten: avbruten, bild: bild)
            ?? [BanPunkt?](repeating: nil, count: t.count)
    }

    /// Som `spara`, men nil när den avbröts.
    public static func sparaAvbrytbar(t: [Double], leder: [[Punkt?]], bredd: Int, hojd: Int, skala: Double,
                                      ankare: [KlubbMarkering], bildBredd: Int? = nil, bildHojd: Int? = nil,
                                      avbruten: () -> Bool = { false }, bild: (Int) -> [UInt8]?) -> [BanPunkt?]? {
        let n = t.count
        var ut = [BanPunkt?](repeating: nil, count: n)
        let markerade = ankare.filter(\.markerad)
        guard n > 0, !markerade.isEmpty else { return ut }
        let Ls = leder.map { L in L.map { $0.map { Punkt($0.x * skala, $0.y * skala) } } }
        let hm = handernasMitt(t, Ls)
        let b = balensLangd(Ls) ?? 0.0
        struct Ankare {
            let k: Int, position: String, g: Punkt, h: Punkt, off: Punkt, L: Double, theta: Double
            var mitt: Punkt? = nil
        }
        var ank: [Ankare] = []
        // Stabil sortering på tiden (som Pythons sorted); ett ankare per ruta, det senare vinner.
        for a in markerade.enumerated().sorted(by: { ($0.element.t, $0.offset) < ($1.element.t, $1.offset) }).map(\.element) {
            var k = 0
            for j in 1..<n where abs(t[j] - a.t) < abs(t[k] - a.t) { k = j }
            let g = Punkt(a.grepp!.x * skala, a.grepp!.y * skala)
            let hs = Punkt(a.hosel!.x * skala, a.hosel!.y * skala)
            let off = hm[k].map { Punkt(g.x - $0.x, g.y - $0.y) } ?? Punkt(0.0, 0.0)
            let post = Ankare(k: k, position: a.position, g: g, h: hs, off: off, L: langd(hs.x - g.x, hs.y - g.y),
                              theta: atan2(hs.y - g.y, hs.x - g.x))
            if let sista = ank.last, sista.k == k { ank[ank.count - 1] = post } else { ank.append(post) }
        }
        let seg = segment(ank.map(\.position))
        // Geometrin per ruta: andelen f, greppet, väntad vinkel, korridorens halva vinkel, L.
        struct Geo {
            let f: Double, g: Punkt?, theta: Double, lim: Double, L: Double
        }
        var geo: [Int: Geo] = [:]
        for (i, j) in seg {
            let A = ank[i], B = ank[j]
            let dth = wrap(B.theta - A.theta)
            let lim = max(vinkelMin, vinkelAndel * abs(dth))
            for k in (A.k + 1)..<B.k {
                let f = (t[k] - t[A.k]) / (t[B.k] - t[A.k])
                let L = A.L + f * (B.L - A.L)
                let g = hm[k].map { Punkt($0.x + A.off.x + f * (B.off.x - A.off.x), $0.y + A.off.y + f * (B.off.y - A.off.y)) }
                geo[k] = Geo(f: f, g: g, theta: A.theta + f * dth, lim: lim, L: L)
            }
        }
        for A in ank where geo[A.k] == nil { geo[A.k] = Geo(f: 0, g: A.g, theta: A.theta, lim: vinkelMin, L: A.L) }
        // 1. Rörelsen, ruta för ruta i tidsordning (rutorna strömmar).
        var ra: [Int: Punkt] = [:]
        for k in geo.keys.sorted() {
            if avbruten() { return nil }
            let G = geo[k]!
            guard let g = G.g, let gr = grannrutor(t, k), G.L > 0 else { continue }
            guard let I = bild(k), let A = bild(gr.fore), let B = bild(gr.efter) else { continue }
            if let q = hitta(I, A, B, bredd: bredd, hojd: hojd, g: g, theta: G.theta, lim: G.lim, L: G.L,
                             streck: kroppensStreck(Ls[k], b)) {
                ra[k] = q
            }
        }
        // 2. Förskjutningen mitt → hosel vid ankarna, i skaftets koordinater (längs, tvärs).
        for i in ank.indices {
            let A = ank[i]
            guard let q = ra[A.k] else { continue }
            let ux = cos(A.theta), uy = sin(A.theta)
            let dx = q.x - A.h.x, dy = q.y - A.h.y
            let d = langd(dx, dy)
            // Under mittMin tryckens brus, över mittMax något annat (en skugga, bollen).
            if mittMin * A.L <= d && d <= mittMax * A.L { ank[i].mitt = Punkt(dx * ux + dy * uy, dx * -uy + dy * ux) }
        }
        var punkt: [Int: Punkt] = [:], kalla: [Int: String] = [:], grepp: [Int: Punkt?] = [:]
        for A in ank {
            punkt[A.k] = A.h
            kalla[A.k] = Klubba.kalla
            grepp[A.k] = A.g
        }
        for (i, j) in seg {
            let A = ank[i], B = ank[j]
            let ka = A.k, kb = B.k
            func mittVid(_ f: Double) -> Punkt {
                if let a = A.mitt, let c = B.mitt { return Punkt(a.x + f * (c.x - a.x), a.y + f * (c.y - a.y)) }
                return A.mitt ?? B.mitt ?? Punkt(0.0, 0.0)
            }
            // 3. Mitten → hoseln, radien och språnget, i tidsordning.
            var forra = A.h, kforra = ka
            var sakra: [Int: Punkt] = [:]
            for k in (ka + 1)..<kb {
                let G = geo[k]!
                grepp[k] = .some(G.g)
                guard let q = ra[k], let g = G.g else { continue }
                let ex = q.x - g.x, ey = q.y - g.y
                let en = langd(ex, ey)
                guard en > 0 else { continue }
                let ux = ex / en, uy = ey / en
                let m = mittVid(G.f)
                let p = Punkt(q.x - (m.x * ux - m.y * uy), q.y - (m.x * uy + m.y * ux))
                let r = langd(p.x - g.x, p.y - g.y)
                if abs(r - G.L) > radieTol * G.L { continue }
                if langd(p.x - forra.x, p.y - forra.y) > sprangS * G.L * (t[k] - t[kforra]) { continue }
                sakra[k] = p
                forra = p
                kforra = k
            }
            // 4. Grannarna: interpolationen mellan förra och nästa säkra punkt (före prövningen).
            var alla = sakra
            alla[ka] = A.h
            alla[kb] = B.h
            let nycklar = alla.keys.sorted()
            var bort: [Int] = []
            if nycklar.count >= 3 {
                for idx in 1..<(nycklar.count - 1) {
                    let k = nycklar[idx], k0 = nycklar[idx - 1], k1 = nycklar[idx + 1]
                    let f = (t[k] - t[k0]) / (t[k1] - t[k0])
                    let fo = polar(grepp[k0]!!, alla[k0]!, grepp[k1]!!, alla[k1]!, grepp[k]!!, f)
                    if langd(alla[k]!.x - fo.x, alla[k]!.y - fo.y) > granne * geo[k]!.L { bort.append(k) }
                }
            }
            for k in bort { sakra[k] = nil }
            for (k, p) in sakra {
                punkt[k] = p
                kalla[k] = kallaSpar
            }
            // 5. De tappade: polärt kring greppet mellan de säkra grannarna (spårade eller ankare).
            var saker = sakra
            saker[ka] = A.h
            saker[kb] = B.h
            for k in (ka + 1)..<kb where sakra[k] == nil {
                let k0 = (ka..<k).last { saker[$0] != nil }!
                let k1 = ((k + 1)...kb).first { saker[$0] != nil }!
                let f = (t[k] - t[k0]) / (t[k1] - t[k0])
                let g0 = grepp[k0]!!, g1 = grepp[k1]!!
                let g = (grepp[k] ?? nil) ?? Punkt(g0.x + f * (g1.x - g0.x), g0.y + f * (g1.y - g0.y))
                punkt[k] = polar(g0, saker[k0]!, g1, saker[k1]!, g, f)
                kalla[k] = kallaInterpolerad
            }
        }
        for (k, q) in punkt {
            let x = q.x / skala, y = q.y / skala
            if let bw = bildBredd, let bh = bildHojd, !(0.0 <= x && x <= Double(bw) && 0.0 <= y && y <= Double(bh)) {
                continue
            }
            ut[k] = BanPunkt(t: t[k], x: x, y: y, kalla: kalla[k]!)
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

    /// En bana kräver två markerade positioner som är grannar i svingens ordning (M61).
    public static func mojlig(_ marks: [KlubbMarkering]?) -> Bool {
        !KlubbSpar.segment(ankare(marks).map(\.position)).isEmpty
    }

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
