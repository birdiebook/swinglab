import Foundation

/// En led i den upprätta bilden: pixlar med origo uppe till vänster, och Visions konfidens.
public struct PoseJoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var c: Double

    public init(x: Double, y: Double, c: Double) {
        self.x = x
        self.y = y
        self.c = c
    }
}

/// En persons leder i en ruta (S2_SPEC §6.3).
public struct PoseFrame: Codable, Equatable, Sendable {
    /// s relativt klicket.
    public var t: Double
    /// s i källfilen.
    public var pts: Double
    /// 13 leder i JointSeries.names ordning; nil = saknad (Visions konfidens 0).
    public var joints: [PoseJoint?]
    /// Observationens konfidens.
    public var confidence: Double

    public init(t: Double, pts: Double, joints: [PoseJoint?], confidence: Double) {
        self.t = t
        self.pts = pts
        self.joints = joints
        self.confidence = confidence
    }

    /// Leden om den är säker (c ≥ PoseRules.jointConfidence). METOD MS8
    public func joint(_ i: Int) -> PoseJoint? {
        guard i >= 0, i < joints.count, let j = joints[i], j.c >= PoseRules.jointConfidence,
              j.x.isFinite, j.y.isFinite else { return nil }
        return j
    }

    /// Mittpunkten av två säkra leder.
    func mitt(_ a: Int, _ b: Int) -> (x: Double, y: Double)? {
        guard let p = joint(a), let q = joint(b) else { return nil }
        return ((p.x + q.x) / 2, (p.y + q.y) / 2)
    }

    /// Höfternas mitt.
    public var hipMid: (x: Double, y: Double)? { mitt(JointSeries.hoftV, JointSeries.hoftH) }

    /// Kroppens längd i bilden: fotledernas mitt − näsan i y, px.
    public var bodyHeight: Double? {
        guard let fot = mitt(JointSeries.fotledV, JointSeries.fotledH), let nasa = joint(JointSeries.nasa) else { return nil }
        return fot.y - nasa.y
    }

    /// Händerna: handledernas mitt, eller den ena om den andra saknas (greppregeln, METOD M1).
    public var hands: (x: Double, y: Double)? {
        if let m = mitt(JointSeries.handledV, JointSeries.handledH) { return m }
        if let j = joint(JointSeries.handledV) ?? joint(JointSeries.handledH) { return (j.x, j.y) }
        return nil
    }

    /// Alla 13 leder säkra.
    public var complete: Bool {
        joints.count == JointSeries.names.count && (0..<joints.count).allSatisfy { joint($0) != nil }
    }
}

/// Konfidensgränserna (S2_SPEC §6.3), som Apples exempel (WWDC20 10653). METOD MS8
public enum PoseRules {
    /// En led räknas som säker vid c ≥ 0,1. METOD MS8
    public static let jointConfidence = 0.1
    /// En observation räknas som säker vid confidence ≥ 0,6. METOD MS8
    public static let observationConfidence = 0.6
}

/// Ett slags leder ur Vision (S2_SPEC §6.3). Namnen och ordningen är filformatets
/// (docs/FORMAT.md, `Sving.lederIFilen`), med MediaPipes index 0, 11–16, 23–28.
public struct JointSeries: Codable, Equatable, Sendable {
    public static let names = ["nasa", "axel_v", "axel_h", "armbage_v", "armbage_h", "handled_v", "handled_h",
                               "hoft_v", "hoft_h", "kna_v", "kna_h", "fotled_v", "fotled_h"]
    static let nasa = 0, axelV = 1, axelH = 2, handledV = 5, handledH = 6, hoftV = 7, hoftH = 8
    static let fotledV = 11, fotledH = 12

    /// "vision-2d-r1".
    public var source: String
    /// Upprätt bild, 1080 × 1920.
    public var width: Int
    public var height: Int
    public var frames: [PoseFrame]

    public init(source: String = "vision-2d-r1", width: Int, height: Int, frames: [PoseFrame]) {
        self.source = source
        self.width = width
        self.height = height
        self.frames = frames
    }

    /// Adressens längd från seriens början, s. METOD MS7
    public static let addressWindow = 0.3
    /// Kroppens axel ska vara så många gånger mer lodrät än vågrät. METOD MS7
    public static let uprightRatio = 2.0

    /// I adressen (seriens första 0,3 s) ska kroppens axel, fotledernas mitt → näsan,
    /// vara mer lodrät än vågrät: |Δy| > 2·|Δx|, med medianerna av Δx och Δy över
    /// rutorna där de tre lederna är säkra. Utan sådana rutor: inte misstänkt (det
    /// säger svingdomen i stället, som blir osäker). METOD MS7
    public var orientationSuspect: Bool {
        guard let start = frames.map(\.t).min() else { return false }
        var dx: [Double] = [], dy: [Double] = []
        for f in frames where f.t <= start + Self.addressWindow {
            guard let fot = f.mitt(Self.fotledV, Self.fotledH), let nasa = f.joint(Self.nasa) else { continue }
            dx.append(nasa.x - fot.x)
            dy.append(nasa.y - fot.y)
        }
        guard !dx.isEmpty else { return false }
        return !(abs(Self.median(dy)) > Self.uprightRatio * abs(Self.median(dx)))
    }

    /// Passet märks "orienteringen misstänkt" när fler än hälften av slagen är det. METOD MS7
    public static func passSuspect(_ series: [JointSeries]) -> Bool {
        let n = series.filter(\.orientationSuspect).count
        return 2 * n > series.count
    }

    static func median(_ v: [Double]) -> Double {
        let s = v.sorted()
        guard !s.isEmpty else { return .nan }
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }
}

/// Valet bland flera personer i bild (grannen). METOD MS8
public enum PosePicker {
    /// I första rutan räknas bara de som är minst så höga som den högsta. METOD MS8
    public static let tallFraction = 0.5

    /// Index i candidates, eller nil när ingen säker observation (confidence ≥ 0,6) har
    /// höfterna; rutan saknar då leder. Med previousHipMid: den
    /// vars höfters mitt ligger närmast. Utan (första rutan): bland dem som är minst
    /// hälften så höga som den högsta (H, fotledernas mitt − näsan; en kandidat utan H
    /// räknas inte som hög), den vars höfter ligger närmast bildens mitt i x. METOD MS8
    public static func pick(_ candidates: [PoseFrame], previousHipMid: (x: Double, y: Double)?, width: Int) -> Int? {
        let med = candidates.indices.compactMap { i -> (Int, (x: Double, y: Double))? in
            guard candidates[i].confidence >= PoseRules.observationConfidence else { return nil }
            return candidates[i].hipMid.map { (i, $0) }
        }
        guard !med.isEmpty else { return nil }
        if let p = previousHipMid {
            return med.min { a, b in
                let da = (a.1.x - p.x) * (a.1.x - p.x) + (a.1.y - p.y) * (a.1.y - p.y)
                let db = (b.1.x - p.x) * (b.1.x - p.x) + (b.1.y - p.y) * (b.1.y - p.y)
                return da < db || (da == db && a.0 < b.0)
            }?.0
        }
        let hojd = med.map { candidates[$0.0].bodyHeight ?? 0 }
        let hogst = hojd.max() ?? 0
        let mitt = Double(width) / 2
        var bast: (i: Int, d: Double)?
        for (k, (i, h)) in med.enumerated() where hogst <= 0 || hojd[k] >= tallFraction * hogst {
            let d = abs(h.x - mitt)
            if bast == nil || d < bast!.d { bast = (i, d) }
        }
        return bast?.i
    }
}
