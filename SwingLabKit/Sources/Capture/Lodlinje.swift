import Foundation

// Telefonens lodlinje till PC:ns 3D (S6b, BESLUT B39, docs/FORMAT.md `serier[].lodlinje`).
// Appen läser `CMDeviceMotion.gravity` medan serien spelas in och ger bara proven
// (App/Motion.swift); CoreMotion finns inte på Linux. Medianen, spärren för rörelse och
// vridningen till kamerans ram i den upprätta bilden räknas här och prövas på Linux,
// mot samma påhittade telefoner som PC:n läser (tools/tests/fixturer/lodlinje.json).

/// Ett prov av gravitationen i enhetens ram (CoreMotion): x åt höger på skärmen i stående,
/// y mot skärmens överkant, z ut ur skärmen, i g. `host` är provets tid på värdklockan, s
/// (`CMLogItem.timestamp`, samma klocka som seriens `startHost`). METOD MS17
public struct GravitySample: Codable, Equatable, Sendable {
    public var host: Double
    public var x: Double
    public var y: Double
    public var z: Double

    public init(host: Double, x: Double, y: Double, z: Double) {
        self.host = host
        self.x = x
        self.y = y
        self.z = z
    }

    var vector: [Double] { [x, y, z] }
}

/// Seriens lodlinje som den lästes på telefonen, i enhetens ram. Sparas i `pass.json`;
/// manifestet vrider den till kamerans ram (`Plumb.field`). METOD MS17
public struct PlumbRecord: Codable, Equatable, Sendable {
    public enum Basis: String, Codable, Sendable {
        /// Sekunden före seriens första klick, enig med seriens stilla sekunder.
        case beforeClick = "fore_klicket"
        /// Seriens stillastående sekunder, eniga.
        case still = "stilla"
        /// Telefonen rörde sig i varje fönster: fältet skrivs inte.
        case moving = "rorelse"
        /// Stilla fönster som inte är eniga (stativet stöttes eller flyttades): fältet skrivs inte.
        case disagree = "oenig"
        /// Inget fönster hade nog med giltiga prov: fältet skrivs inte.
        case tooFew = "for_fa_prov"
    }

    /// Gravitationens median per axel i enhetens ram, g; tom när inget prov var giltigt.
    public var gravity: [Double]
    /// Spridningen: 95:e percentilen av vinkeln mellan ett prov och medianen, grader. Alltid ändlig.
    public var spread: Double
    /// Antalet prov i medianen.
    public var samples: Int
    public var basis: Basis
    /// Antalet prov i sekunden före första klicket (nil utan klick eller värdklocka), så att
    /// ett fel i klockan syns i `pass.json`: ett tomt fönster i en serie med prov.
    public var beforeClickSamples: Int? = nil
    /// Första giltiga provets tid i filen, `t0 − startHost`, s (nil utan värdklocka). Nära 0
    /// när provets klocka är seriens; sekunder eller mer är ett klockfel.
    public var firstSampleOffset: Double? = nil

    public init(gravity: [Double], spread: Double, samples: Int, basis: Basis, beforeClickSamples: Int? = nil,
                firstSampleOffset: Double? = nil) {
        self.gravity = gravity
        self.spread = spread
        self.samples = samples
        self.basis = basis
        self.beforeClickSamples = beforeClickSamples
        self.firstSampleOffset = firstSampleOffset
    }
}

/// Lodlinjen: medianen, spärren och kamerans ram. METOD MS17, MK3, BESLUT B39
public enum Plumb {
    /// Provens takt: CMMotionManager.deviceMotionUpdateInterval, s. METOD MS17
    public static let sampleInterval = 1.0 / 30
    /// Fönstret före första klicket, och de stillastående delarnas längd, s. METOD MS17
    public static let window = 1.0
    /// Ett fönster räknas bara med minst så många prov. METOD MS17
    public static let minSamples = 10
    /// Spridningen (95:e percentilen av vinkeln mot medianen) över den här är rörelse, och två
    /// stilla fönster vars medianer skiljer mer är oeniga, grader. METOD MS17
    public static let maxSpread = 1.0
    /// Percentilen som spridningen mäts med. METOD MS17
    public static let spreadPercentile = 0.95
    /// Ett prov vars längd ligger utanför det här (g) är trasigt och slängs. METOD MS17
    public static let sampleLength: ClosedRange<Double> = 0.5...1.5
    /// Uppåt får luta högst så mycket från bildens överkant, grader: mer är en telefon som
    /// står i en annan orientering än filens. METOD MS17
    public static let maxTilt = 45.0
    /// Lodlinjens längd i g, som PC:ns formkontroll `LODLINJE_G`. METOD MK3
    public static let length: ClosedRange<Double> = 0.8...1.2

    /// Medianen per axel (medelvärdet av de två mittersta vid jämnt antal).
    static func median(_ v: [Double]) -> Double {
        let s = v.sorted()
        guard !s.isEmpty else { return .nan }
        let m = s.count / 2
        return s.count % 2 == 1 ? s[m] : (s[m - 1] + s[m]) / 2
    }

    static func median(_ p: [GravitySample]) -> [Double] {
        [median(p.map(\.x)), median(p.map(\.y)), median(p.map(\.z))]
    }

    static func norm(_ a: [Double]) -> Double { (a[0] * a[0] + a[1] * a[1] + a[2] * a[2]).squareRoot() }

    /// Vinkeln mellan två vektorer, grader; 180 (största möjliga) för en nollvektor eller
    /// ett tal som inte är ändligt, så att en spridning alltid är ändlig.
    static func angle(_ a: [Double], _ b: [Double]) -> Double {
        let n = norm(a) * norm(b)
        guard n > 0, n.isFinite else { return 180 }
        let c = (a[0] * b[0] + a[1] * b[1] + a[2] * b[2]) / n
        guard c.isFinite else { return 180 }
        return acos(min(1, max(-1, c))) * 180 / .pi
    }

    /// Spridningen: `spreadPercentile` av vinkeln mellan proven och `m` (närmaste rang), grader.
    static func spread(_ p: [GravitySample], about m: [Double]) -> Double {
        let v = p.map { angle($0.vector, m) }.sorted()
        guard !v.isEmpty else { return 0 }
        let k = Int((spreadPercentile * Double(v.count)).rounded(.up)) - 1
        return v[min(max(k, 0), v.count - 1)]
    }

    /// Ett fönster som räknas: tillräckligt många prov och spridningen inom spärren.
    static func still(_ p: [GravitySample]) -> (gravity: [Double], spread: Double)? {
        guard p.count >= minSamples else { return nil }
        let m = median(p)
        let s = spread(p, about: m)
        guard s <= maxSpread else { return nil }
        return (m, s)
    }

    /// Ett giltigt prov: ändliga tal och längden inom `sampleLength`.
    static func valid(_ s: GravitySample) -> Bool {
        guard s.host.isFinite, s.x.isFinite, s.y.isFinite, s.z.isFinite else { return false }
        return sampleLength.contains(norm(s.vector))
    }

    /// Seriens lodlinje ur proven (trasiga prov slängs). Sekunden före första klicket
    /// (`firstClick`, s i filen; provets tid i filen är `host − startHost`) när den är stilla
    /// och stämmer med varje stilla sekund i serien; annars seriens stilla sekunder när de är
    /// eniga. Annars ett skäl utan fält: `disagree` (stilla men oeniga, stativet stöttes),
    /// `moving` (inget fönster stilla) eller `tooFew` (inget fönster med nog prov). nil = inga
    /// prov alls (simulatorn, en import ur Bilder). METOD MS17
    public static func estimate(samples: [GravitySample], startHost: Double?, firstClick: Double?) -> PlumbRecord? {
        guard !samples.isEmpty else { return nil }
        let p = samples.filter { valid($0) }.sorted { $0.host < $1.host }
        let klocka = startHost.flatMap { $0.isFinite ? $0 : nil }
        let forsta = p.first.flatMap { s in klocka.map { s.host - $0 } }
        func post(_ g: [Double], _ s: Double, _ n: Int, _ b: PlumbRecord.Basis, fore: Int?) -> PlumbRecord {
            PlumbRecord(gravity: g, spread: s, samples: n, basis: b, beforeClickSamples: fore, firstSampleOffset: forsta)
        }
        guard let t0 = p.first?.host else { return post([], 0, 0, .tooFew, fore: nil) }

        // Sekunden före första klicket.
        var fore: [GravitySample]?
        if let klocka, let firstClick, firstClick.isFinite {
            fore = p.filter {
                let t = $0.host - klocka
                return t >= firstClick - window && t < firstClick
            }
        }
        // Seriens stillastående sekunder, var för sig.
        var sekunder: [Int: [GravitySample]] = [:]
        for s in p { sekunder[Int(((s.host - t0) / window).rounded(.down)), default: []].append(s) }
        let stilla = sekunder.keys.sorted().compactMap { k -> (prov: [GravitySample], median: [Double])? in
            guard let g = sekunder[k], let r = still(g) else { return nil }
            return (g, r.gravity)
        }
        /// Varje stilla sekund ligger inom spärren från `m`.
        func eniga(_ m: [Double]) -> Bool { stilla.allSatisfy { angle($0.median, m) <= maxSpread } }

        if let f = fore, let r = still(f) {
            if eniga(r.gravity) { return post(r.gravity, r.spread, f.count, .beforeClick, fore: f.count) }
            let m = median(p)
            return post(m, spread(p, about: m), p.count, .disagree, fore: f.count)
        }
        if !stilla.isEmpty {
            let alla = stilla.flatMap { $0.prov }
            let m = median(alla)
            if eniga(m) { return post(m, spread(alla, about: m), alla.count, .still, fore: fore?.count) }
            let mp = median(p)
            return post(mp, spread(p, about: mp), p.count, .disagree, fore: fore?.count)
        }
        let nog = (fore?.count ?? 0) >= minSamples || sekunder.values.contains { $0.count >= minSamples }
        let m = median(p)
        return post(m, spread(p, about: m), p.count, nog ? .moving : .tooFew, fore: fore?.count)
    }

    /// Uppåt (−gravitationen) i kamerans ram i den upprätta bilden: x åt höger, y nedåt,
    /// z framåt ur bakre kamerans lins (docs/FORMAT.md). Den lagrade bilden (EXIF 1) är
    /// sensorns liggande bild med telefonens överkant åt vänster: höger = −y, ned = −x och
    /// framåt = −z i enhetens ram. EXIF 6 (stående, kamerans vanliga läge, METOD MS7) vrider
    /// den 90° medurs, 3 ett halvt varv och 8 90° moturs; annat räknas som 1, som
    /// `Orientation.exif`. METOD MS17
    public static func up(gravity g: [Double], exif: UInt32) -> [Double] {
        let u = [-g[0], -g[1], -g[2]]
        let hoger = -u[1], ned = -u[0], fram = -u[2]          // sensorns lagrade bild
        func ren(_ v: [Double]) -> [Double] { v.map { $0 + 0 } }   // −0 skrivs som 0
        switch exif {
        case 6: return ren([-ned, hoger, fram])
        case 3: return ren([-hoger, -ned, fram])
        case 8: return ren([ned, -hoger, fram])
        default: return ren([hoger, ned, fram])
        }
    }

    /// Fältet `serier[].lodlinje`: uppåt i kamerans ram med fyra decimaler, eller nil när
    /// lodlinjen inte lästes stilla (`beforeClick` eller `still`), längden ligger utanför PC:ns
    /// formkontroll, uppåt inte pekar mot bildens överkant (PC:ns kontroll: y < 0) eller lutar
    /// mer än `maxTilt` från den. Telefonen skriver alltså aldrig ett fält som PC:n inte tar.
    /// METOD MS17, MK3
    public static func field(_ r: PlumbRecord?, exif: UInt32) -> [Double]? {
        guard let r, r.basis == .beforeClick || r.basis == .still, r.gravity.count == 3,
              r.gravity.allSatisfy(\.isFinite) else { return nil }
        let v = up(gravity: r.gravity, exif: exif)
        guard length.contains(norm(v)), v[1] < 0 else { return nil }
        let lutning = angle(v, [0, -1, 0])
        guard lutning.isFinite, lutning <= maxTilt else { return nil }
        return v.map { ($0 * 10_000).rounded() / 10_000 + 0 }
    }
}

extension SeriesRecord {
    /// Lodlinjen ur inspelningens prov, med seriens första klick och värdklocka. METOD MS17
    public mutating func setPlumb(_ samples: [GravitySample]) {
        plumb = Plumb.estimate(samples: samples, startHost: startHost, firstClick: clicks.map(\.time).min())
    }
}
