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
        /// Sekunden före seriens första klick.
        case beforeClick = "fore_klicket"
        /// Seriens stillastående sekunder, eniga.
        case still = "stilla"
        /// Telefonen rörde sig: fältet skrivs inte.
        case moving = "rorelse"
    }

    /// Gravitationens median per axel i enhetens ram, g.
    public var gravity: [Double]
    /// Största vinkeln mellan ett prov och medianen, grader.
    public var spread: Double
    /// Antalet prov i medianen.
    public var samples: Int
    public var basis: Basis

    public init(gravity: [Double], spread: Double, samples: Int, basis: Basis) {
        self.gravity = gravity
        self.spread = spread
        self.samples = samples
        self.basis = basis
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
    /// Spridningen (största vinkeln mot medianen) över den här är rörelse, grader. METOD MS17
    public static let maxSpread = 1.0
    /// Uppåt får luta högst så mycket från bildens överkant, grader: mer är en telefon som
    /// står i en annan orientering än filens. METOD MS17
    public static let maxTilt = 45.0
    /// Lodlinjens längd i g, som PC:ns `LODLINJE_G` (telefonen i vila). METOD MK3
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

    /// Vinkeln mellan två vektorer, grader; .nan för en nollvektor.
    static func angle(_ a: [Double], _ b: [Double]) -> Double {
        let n = norm(a) * norm(b)
        guard n > 0, n.isFinite else { return .nan }
        let c = (a[0] * b[0] + a[1] * b[1] + a[2] * b[2]) / n
        return acos(min(1, max(-1, c))) * 180 / .pi
    }

    /// Största vinkeln mellan ett prov och `m`, grader (.nan om något prov saknar riktning).
    static func spread(_ p: [GravitySample], about m: [Double]) -> Double {
        var storst = 0.0
        for s in p {
            let v = angle(s.vector, m)
            guard v.isFinite else { return .nan }
            storst = max(storst, v)
        }
        return storst
    }

    /// Ett fönster som räknas: tillräckligt många prov och spridningen inom spärren.
    static func still(_ p: [GravitySample]) -> (gravity: [Double], spread: Double)? {
        guard p.count >= minSamples else { return nil }
        let m = median(p)
        let s = spread(p, about: m)
        guard s.isFinite, s <= maxSpread else { return nil }
        return (m, s)
    }

    /// Seriens lodlinje ur proven. Sekunden före första klicket (`firstClick`, s i filen;
    /// provets tid i filen är `host − startHost`) när den är stilla; annars seriens
    /// stillastående sekunder, när de är eniga; annars `moving` med hela seriens median och
    /// spridning. nil = inga prov (simulatorn, en import ur Bilder). METOD MS17
    public static func estimate(samples: [GravitySample], startHost: Double?, firstClick: Double?) -> PlumbRecord? {
        let p = samples.filter { $0.host.isFinite && $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }
            .sorted { $0.host < $1.host }
        guard let t0 = p.first?.host else { return nil }
        if let startHost, let firstClick, startHost.isFinite, firstClick.isFinite {
            let fore = p.filter {
                let t = $0.host - startHost
                return t >= firstClick - window && t < firstClick
            }
            if let r = still(fore) {
                return PlumbRecord(gravity: r.gravity, spread: r.spread, samples: fore.count, basis: .beforeClick)
            }
        }
        // De stillastående sekunderna, och att de är eniga (ett stativ som flyttats är det inte).
        var sekunder: [Int: [GravitySample]] = [:]
        for s in p { sekunder[Int(((s.host - t0) / window).rounded(.down)), default: []].append(s) }
        let stilla = sekunder.keys.sorted().compactMap { k -> [GravitySample]? in
            guard let g = sekunder[k], still(g) != nil else { return nil }
            return g
        }.flatMap { $0 }
        if let r = still(stilla) {
            return PlumbRecord(gravity: r.gravity, spread: r.spread, samples: stilla.count, basis: .still)
        }
        let m = median(p)
        return PlumbRecord(gravity: m, spread: spread(p, about: m), samples: p.count, basis: .moving)
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
    /// telefonen rörde sig, längden är fel (inte telefonen i vila), uppåt inte pekar mot
    /// bildens överkant (PC:ns kontroll: y < 0) eller lutar mer än `maxTilt` från den.
    /// Telefonen skriver alltså aldrig ett fält som PC:n inte tar. METOD MS17, MK3
    public static func field(_ r: PlumbRecord?, exif: UInt32) -> [Double]? {
        guard let r, r.basis != .moving, r.gravity.count == 3, r.gravity.allSatisfy(\.isFinite) else { return nil }
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
