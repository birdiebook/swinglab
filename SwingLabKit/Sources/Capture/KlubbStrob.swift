import Foundation

// Stroboskopet (PLAN S7-2, METOD MF7): klubbhuvudet ur varje ruta från P1 till P9 inklistrat i
// grundbilden, så att detektionen syns. Samma utsnitt, grannar, lager, medianbild och filter som
// `strob` i tools/pc/formarkare.py (BESLUT B12). Bara för ögat, inget mått (B92). Appen läser
// rutorna och kör modellen (App/KlubbStrobLasare.swift); här finns det som går att pröva utan Mac.

/// En RGBA-bild rad för rad, 4 byte per pixel.
public struct RGBABild: Equatable, Sendable {
    public var bredd: Int
    public var hojd: Int
    public var pixlar: [UInt8]

    public init(bredd: Int, hojd: Int, pixlar: [UInt8]) {
        precondition(pixlar.count == bredd * hojd * 4, "pixlar ska vara bredd × höjd × 4")
        self.bredd = bredd
        self.hojd = hojd
        self.pixlar = pixlar
    }
}

/// Ett huvud att klistra in: rutan i bilden, dess pixlar och vilka av dem som är huvudet.
public struct StrobLager: Equatable, Sendable {
    public var x0: Int, y0: Int, bredd: Int, hojd: Int
    public var pixlar: [UInt8]
    public var mask: [Bool]
}

public enum KlubbStrob {
    /// Huvudets ruta vidgas så mycket åt varje håll innan pixlarna jämförs. METOD MF7
    public static let marginal = 0.25
    /// En pixel skiljer sig när någon färg skiljer mer än så (0–255). METOD MF7
    public static let skillnad = 28
    /// En pixel är huvudets när den skiljer sig från så många referenser (före, efter, medianen). METOD MF7
    public static let roster = 2
    /// Rutor jämnt över svingen i medianbilden. METOD MF7
    public static let medianRutor = 25
    /// Ett huvud längre bort än så många rutdiagonaler från båda grannarna är ett fel. METOD MF7
    public static let hopp = 3.0
    /// Utsnittets sida kring händerna i kroppens höjder (formarkare.HAND_SKALA), och kring
    /// kroppens mitt utan händer (UTSNITT_SKALA). METOD MF7
    public static let handSkala = 1.8, kroppSkala = 2.0
    /// En ruta räknas i kroppens höjd med minst så många säkra leder. METOD MF7
    public static let kroppMinLeder = 6
    /// Huvudet räknas från den konfidensen (B95).
    public static let konfidens = 0.3

    // MARK: Utsnittet kring händerna

    /// (kroppens höjd, mitt x, mitt y) i ledernas px över svingens rutor: höjden är medianen av
    /// varje rutas egen höjd (rutor med minst `kroppMinLeder` säkra leder), annars ledernas
    /// gemensamma ruta. nil utan leder. Som `kroppen` i formarkare.py.
    public static func kroppen(_ rutor: [PoseFrame]) -> (hojd: Double, x: Double, y: Double)? {
        var xs: [Double] = [], ys: [Double] = [], hojder: [Double] = []
        for f in rutor {
            let s = sakra(f)
            xs += s.map(\.x)
            ys += s.map(\.y)
            if s.count >= kroppMinLeder, let lo = s.map(\.y).min(), let hi = s.map(\.y).max() { hojder.append(hi - lo) }
        }
        guard let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max() else { return nil }
        let h = hojder.isEmpty ? max(y1 - y0, x1 - x0) : median(hojder)
        return (h, (x0 + x1) / 2, (y0 + y1) / 2)
    }

    /// Rutans kvadratiska utsnitt (x0, y0, sida) i ledernas px: kring händerna med sidan
    /// `handSkala` × kroppens höjd, utan händer kring kroppens mitt. Högst bildens långsida.
    /// Som `utsnitt` i formarkare.py.
    public static func utsnitt(_ f: PoseFrame, kropp: (hojd: Double, x: Double, y: Double), bredd: Int,
                               hojd: Int) -> (x0: Int, y0: Int, sida: Int) {
        let h = [JointSeries.handledV, JointSeries.handledH].compactMap { sakerLed(f, $0) }
        var cx = kropp.x, cy = kropp.y
        var sida = kroppSkala * kropp.hojd
        if !h.isEmpty {
            cx = h.map(\.x).reduce(0, +) / Double(h.count)
            cy = h.map(\.y).reduce(0, +) / Double(h.count)
            sida = handSkala * kropp.hojd
        }
        let s = max(1, min(max(bredd, hojd), Int(sida.rounded(.toNearestOrEven))))
        return (Int((cx - Double(s) / 2).rounded(.toNearestOrEven)), Int((cy - Double(s) / 2).rounded(.toNearestOrEven)), s)
    }

    private static func sakerLed(_ f: PoseFrame, _ i: Int) -> (x: Double, y: Double)? {
        guard i < f.joints.count, let j = f.joints[i], j.c >= konfidens, j.x.isFinite, j.y.isFinite else { return nil }
        return (j.x, j.y)
    }

    private static func sakra(_ f: PoseFrame) -> [(x: Double, y: Double)] {
        f.joints.indices.compactMap { sakerLed(f, $0) }
    }

    private static func median(_ v: [Double]) -> Double {
        let s = v.sorted()
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }

    // MARK: Huvudena

    /// Rutorna (nyckeln) vars huvud `[x, y, b, h]` är ett ensamt hopp: längre än `hopp` ×
    /// rutans diagonal från både föregående och nästa huvud, medan de två ligger närmare
    /// varandra än så. Som `strob_ensamma` i formarkare.py.
    public static func ensamma(_ huvud: [Int: [Double]], hopp: Double = hopp) -> Set<Int> {
        let nr = huvud.keys.sorted()
        func mitt(_ n: Int) -> (Double, Double) { let b = huvud[n]!; return (b[0] + b[2] / 2, b[1] + b[3] / 2) }
        func dist(_ a: (Double, Double), _ b: (Double, Double)) -> Double { hypot(a.0 - b.0, a.1 - b.1) }
        var ut = Set<Int>()
        guard nr.count >= 3 else { return ut }
        for i in 1..<(nr.count - 1) {
            let a = nr[i - 1], b = nr[i], c = nr[i + 1]
            let g = hopp * hypot(huvud[b]![2], huvud[b]![3])
            if dist(mitt(a), mitt(b)) > g, dist(mitt(b), mitt(c)) > g, dist(mitt(a), mitt(c)) < g { ut.insert(b) }
        }
        return ut
    }

    /// Rutans del av bilden kring huvudet `[x, y, b, h]`, vidgad med `marginal`, som
    /// (x0, y0, bredd, höjd); nil när den ligger utanför bilden. Som `strob_lager`.
    public static func ruta(_ box: [Double], bredd: Int, hojd: Int, marginal: Double = marginal)
        -> (x0: Int, y0: Int, bredd: Int, hojd: Int)? {
        let x0 = max(0, Int((box[0] - marginal * box[2]).rounded(.towardZero)))
        let y0 = max(0, Int((box[1] - marginal * box[3]).rounded(.towardZero)))
        let x1 = min(bredd, Int((box[0] + box[2] + marginal * box[2]).rounded(.towardZero)) + 1)
        let y1 = min(hojd, Int((box[1] + box[3] + marginal * box[3]).rounded(.towardZero)) + 1)
        guard x1 > x0, y1 > y0 else { return nil }
        return (x0, y0, x1 - x0, y1 - y0)
    }

    /// Pixlarna i en del av bilden.
    public static func del(_ b: RGBABild, x0: Int, y0: Int, bredd: Int, hojd: Int) -> [UInt8] {
        var ut = [UInt8](repeating: 0, count: bredd * hojd * 4)
        for y in 0..<hojd {
            let fran = ((y0 + y) * b.bredd + x0) * 4
            ut.replaceSubrange((y * bredd * 4)..<((y + 1) * bredd * 4), with: b.pixlar[fran..<(fran + bredd * 4)])
        }
        return ut
    }

    /// För varje huvud den närmaste rutan (nyckeln) före och efter vars huvud, vidgat med
    /// `marginal`, inte når huvudets vidgade ruta. Där syns det som låg bakom huvudet, med kroppen
    /// nästan där den står i rutan. Som `strob_grannar` i formarkare.py.
    public static func grannar(_ huvud: [Int: [Double]], bredd: Int, hojd: Int, marginal: Double = marginal)
        -> [Int: (fore: Int?, efter: Int?)] {
        var rutor: [Int: (x0: Int, y0: Int, bredd: Int, hojd: Int)] = [:]
        for (n, b) in huvud { rutor[n] = ruta(b, bredd: bredd, hojd: hojd, marginal: marginal) }
        let nr = rutor.keys.sorted()
        func fri(_ a: Int, _ b: Int) -> Bool {
            let p = rutor[a]!, q = rutor[b]!
            return p.x0 + p.bredd <= q.x0 || q.x0 + q.bredd <= p.x0 || p.y0 + p.hojd <= q.y0 || q.y0 + q.hojd <= p.y0
        }
        var ut: [Int: (fore: Int?, efter: Int?)] = [:]
        for (i, n) in nr.enumerated() {
            ut[n] = (nr[..<i].reversed().first { fri($0, n) }, nr[(i + 1)...].first { fri($0, n) })
        }
        return ut
    }

    /// En del av bilden i en större bilds px: bilden `b` är `skala` gånger den större (appens
    /// medianbild i halv upplösning), och varje pixel tar närmaste pixel nedåt.
    public static func del(_ b: RGBABild, x0: Int, y0: Int, bredd: Int, hojd: Int, skala: Double) -> [UInt8] {
        var ut = [UInt8](repeating: 0, count: bredd * hojd * 4)
        for y in 0..<hojd {
            let yy = min(b.hojd - 1, max(0, Int(Double(y0 + y) * skala)))
            for x in 0..<bredd {
                let xx = min(b.bredd - 1, max(0, Int(Double(x0 + x) * skala)))
                let i = (y * bredd + x) * 4, j = (yy * b.bredd + xx) * 4
                ut[i] = b.pixlar[j]; ut[i + 1] = b.pixlar[j + 1]; ut[i + 2] = b.pixlar[j + 2]; ut[i + 3] = b.pixlar[j + 3]
            }
        }
        return ut
    }

    /// Huvudet ur en ruta som ett lager: pixlarna i delen (x0, y0, bredd, höjd) som skiljer sig
    /// mer än `skillnad` från minst `roster` av referenserna, samma del av rutan före och efter
    /// där huvudet var någon annanstans (`grannar`) och av medianbilden; med färre referenser
    /// krävs alla. Rensade från enstaka pixlar (öppning och vidgning med 3 × 3, som OpenCV). nil
    /// utan referenser eller när inget skiljer sig. Som `strob_lager`.
    public static func lager(pixlar: [UInt8], x0: Int, y0: Int, bredd: Int, hojd: Int, referenser: [[UInt8]?],
                             skillnad: Int = skillnad, roster: Int = roster) -> StrobLager? {
        let ref = referenser.compactMap { $0 }.filter { $0.count == pixlar.count }
        guard !ref.isEmpty else { return nil }
        let krav = min(roster, ref.count)
        var mask = [Bool](repeating: false, count: bredd * hojd)
        for p in mask.indices {
            let i = p * 4
            var r = 0
            for a in ref where max(abs(Int(pixlar[i]) - Int(a[i])), abs(Int(pixlar[i + 1]) - Int(a[i + 1])),
                                   abs(Int(pixlar[i + 2]) - Int(a[i + 2]))) > skillnad {
                r += 1
            }
            mask[p] = r >= krav
        }
        mask = vidga(vidga(krymp(mask, bredd, hojd), bredd, hojd), bredd, hojd)
        guard mask.contains(true) else { return nil }
        return StrobLager(x0: x0, y0: y0, bredd: bredd, hojd: hojd, pixlar: pixlar, mask: mask)
    }

    /// Klistrar in lagret i bilden.
    public static func lagg(_ l: StrobLager, i bild: inout RGBABild) {
        for y in 0..<l.hojd {
            for x in 0..<l.bredd where l.mask[y * l.bredd + x] {
                let i = (y * l.bredd + x) * 4, j = ((l.y0 + y) * bild.bredd + l.x0 + x) * 4
                bild.pixlar[j] = l.pixlar[i]
                bild.pixlar[j + 1] = l.pixlar[i + 1]
                bild.pixlar[j + 2] = l.pixlar[i + 2]
            }
        }
    }

    /// Medianbilden per pixel och färg; alla bilder lika stora.
    public static func median(_ bilder: [RGBABild]) -> RGBABild? {
        guard let f = bilder.first, bilder.count >= 3, bilder.allSatisfy({ $0.bredd == f.bredd && $0.hojd == f.hojd })
        else { return nil }
        var ut = f.pixlar
        var v = [UInt8](repeating: 0, count: bilder.count)
        for i in ut.indices {
            for k in bilder.indices { v[k] = bilder[k].pixlar[i] }
            v.sort()
            // Mitten, och medel av de två mittersta vid jämnt antal (som numpy, avrundat nedåt).
            ut[i] = v.count % 2 == 1 ? v[v.count / 2] : UInt8((Int(v[v.count / 2 - 1]) + Int(v[v.count / 2])) / 2)
        }
        return RGBABild(bredd: f.bredd, hojd: f.hojd, pixlar: ut)
    }

    /// Rutorna i medianbilden: `antal` jämnt från första till sista (som formarkare.py).
    public static func medianIndex(forsta: Int, sista: Int, antal: Int = medianRutor) -> Set<Int> {
        guard antal > 1, sista > forsta else { return [forsta] }
        return Set((0..<antal).map { forsta + Int((Double($0 * (sista - forsta)) / Double(antal - 1)).rounded(.toNearestOrEven)) })
    }

    // 3 × 3 som OpenCV: utanför bilden krymper inget och vidgar inget.
    private static func krymp(_ m: [Bool], _ b: Int, _ h: Int) -> [Bool] {
        granne(m, b, h, utanfor: true) { $0.allSatisfy { $0 } }
    }

    private static func vidga(_ m: [Bool], _ b: Int, _ h: Int) -> [Bool] {
        granne(m, b, h, utanfor: false) { $0.contains(true) }
    }

    private static func granne(_ m: [Bool], _ b: Int, _ h: Int, utanfor: Bool, _ f: ([Bool]) -> Bool) -> [Bool] {
        var ut = m
        var n = [Bool](repeating: false, count: 9)
        for y in 0..<h {
            for x in 0..<b {
                var k = 0
                for dy in -1...1 {
                    for dx in -1...1 {
                        let xx = x + dx, yy = y + dy
                        n[k] = (xx < 0 || yy < 0 || xx >= b || yy >= h) ? utanfor : m[yy * b + xx]
                        k += 1
                    }
                }
                ut[y * b + x] = f(n)
            }
        }
        return ut
    }
}
