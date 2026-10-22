import Foundation

// Slagen i passet (S2_SPEC §4.3, §6, §8.2, §12 S2e): varje klick blir ett slag som
// analysen för genom tre steg — det glesa Vision-passet och domen, det täta passet
// med lederna, och klippet kring slaget. Allt som avgör ordningen, fönstren,
// personvalet, klippets kontroll och listans rader bor här och prövas på Linux;
// App/Analysis.swift kör stegen med AVFoundation och Vision. BESLUT B25

/// Ett slag: klicket, träffen, domen, lederna och klippet. Fälten fylls i allt eftersom
/// analysen går; ett fält som saknas betyder att steget inte är gjort (återupptagbart).
public struct ShotRecord: Codable, Equatable, Sendable {
    /// "s01", "s02" … Ges en gång och återanvänds aldrig. Manifestets `id`.
    public var id: String
    /// Seriens `nr`.
    public var series: Int
    /// Klicket i seriens fil, s, och styrkan.
    public var click: Click
    /// Träffen = klicket − avstånd / 343, s i seriens fil. METOD MS6
    public var impact: Double
    /// Domen ur det glesa passet, eller Johannes ändring. nil = inte analyserad.
    public var verdict: SwingVerdict?
    public var verdictByJohannes: Bool
    /// Lederna i det täta fönstret, relativt passets mapp ("Leder/s01.json").
    public var joints: String?
    /// Rutor i lederna, och om orienteringen ser misstänkt ut i adressen (METOD MS7).
    public var jointFrames: Int?
    public var orientationSuspect: Bool?
    /// Klippet kring slaget ("Klipp/s01.mov"), var det började i serien, och klicket
    /// mätt i klippet självt (S2_SPEC §8.2).
    public var clip: String?
    public var clipStart: Double?
    public var clickInClip: Double?
    /// Klicket i klippet ligger mer än 10 ms från det väntade, eller hittades inte. METOD MS12
    public var clipFlagged: Bool?

    public init(id: String, series: Int, click: Click, impact: Double, verdict: SwingVerdict? = nil,
                verdictByJohannes: Bool = false, joints: String? = nil, jointFrames: Int? = nil,
                orientationSuspect: Bool? = nil, clip: String? = nil, clipStart: Double? = nil,
                clickInClip: Double? = nil, clipFlagged: Bool? = nil) {
        self.id = id
        self.series = series
        self.click = click
        self.impact = impact
        self.verdict = verdict
        self.verdictByJohannes = verdictByJohannes
        self.joints = joints
        self.jointFrames = jointFrames
        self.orientationSuspect = orientationSuspect
        self.clip = clip
        self.clipStart = clipStart
        self.clickInClip = clickInClip
        self.clipFlagged = clipFlagged
    }

    /// "s01" … ur numret.
    public static func id(_ n: Int) -> String { String(format: "s%02d", n) }

    /// Numret ur id:t ("s07" → 7), eller nil.
    public static func number(_ id: String) -> Int? {
        guard id.hasPrefix("s") else { return nil }
        return Int(id.dropFirst())
    }

    /// Ledernas fil i passet.
    public static func jointsPath(_ id: String) -> String { "Leder/\(id).json" }
    /// Klippets fil i passet.
    public static func clipPath(_ id: String) -> String { "Klipp/\(id).mov" }

    /// Slaget får det täta passet och ett klipp: bekräftat eller osäkert (S2_SPEC §4.3).
    public var wantsDetail: Bool { verdict == .swing || verdict == .uncertain }
}

/// Vad Vision kostade (S2_SPEC §6.4): rutorna som avkodades och analyserades, och tiden.
/// `msPerFrame` är Visions egen tid per analyserad ruta; `wallMsPerFrame` räknar med
/// avkodningen av rutorna som hoppades över i det glesa passet. METOD MS12
public struct VisionStats: Codable, Equatable, Sendable {
    public var revision: Int
    public var sparseStride: Int
    public var denseStride: Int
    public var decodedFrames: Int
    public var analyzedFrames: Int
    public var visionSeconds: Double
    public var wallSeconds: Double
    public var msPerFrame: Double?
    public var wallMsPerFrame: Double?

    public init(revision: Int = 1, sparseStride: Int = SwingCheck.sparseStride, denseStride: Int = ShotPlan.denseStride) {
        self.revision = revision
        self.sparseStride = sparseStride
        self.denseStride = denseStride
        decodedFrames = 0
        analyzedFrames = 0
        visionSeconds = 0
        wallSeconds = 0
    }

    public mutating func add(_ scan: PoseScan) {
        decodedFrames += scan.decodedFrames
        analyzedFrames += scan.frames.count
        visionSeconds += scan.visionSeconds
        wallSeconds += scan.wallSeconds
        msPerFrame = analyzedFrames > 0 ? visionSeconds / Double(analyzedFrames) * 1000 : nil
        wallMsPerFrame = analyzedFrames > 0 ? wallSeconds / Double(analyzedFrames) * 1000 : nil
    }
}

// MARK: - Vision-steget som värden

/// Vad ett Vision-pass ska läsa: fönstret i filen (s, filens tidslinje), var k:te ruta,
/// och orienteringen så att lederna hamnar i den upprätta bilden (METOD MS7).
public struct PoseScanRequest: Equatable, Sendable {
    public var file: URL
    public var from: Double
    public var to: Double
    public var stride: Int
    public var exif: UInt32
    public var uprightWidth: Int
    public var uprightHeight: Int

    public init(file: URL, from: Double, to: Double, stride: Int, exif: UInt32, uprightWidth: Int, uprightHeight: Int) {
        self.file = file
        self.from = from
        self.to = to
        self.stride = stride
        self.exif = exif
        self.uprightWidth = uprightWidth
        self.uprightHeight = uprightHeight
    }
}

/// En analyserad ruta: rutans egen tid i filen och en kandidat per person Vision såg
/// (t = pts, lederna i pixlar i den upprätta bilden). Tom = ingen person.
public struct ScannedFrame: Equatable, Sendable {
    public var pts: Double
    public var candidates: [PoseFrame]

    public init(pts: Double, candidates: [PoseFrame]) {
        self.pts = pts
        self.candidates = candidates
    }
}

/// Ett Vision-pass: de analyserade rutorna, de avkodade, och tiden.
public struct PoseScan: Equatable, Sendable {
    public var frames: [ScannedFrame]
    public var decodedFrames: Int
    public var visionSeconds: Double
    public var wallSeconds: Double

    public init(frames: [ScannedFrame], decodedFrames: Int, visionSeconds: Double, wallSeconds: Double) {
        self.frames = frames
        self.decodedFrames = decodedFrames
        self.visionSeconds = visionSeconds
        self.wallSeconds = wallSeconds
    }
}

/// Det som ger lederna: Vision på telefonen (App/PoseRunner.swift), eller påhittade leder i
/// simulatorprovet, där Vision inte hittar någon i en genererad film (METOD MS12). Ett fel
/// kastas alltid vidare; analysen stannar på slaget och fortsätter därifrån nästa gång.
public protocol PoseSource: Sendable {
    func scan(_ request: PoseScanRequest, progress: @escaping @Sendable (Double) -> Void) async throws -> PoseScan
}

extension PoseFrame {
    /// En persons leder ur Vision: normaliserade punkter (origo nere till vänster) i
    /// `JointSeries.names` ordning, till pixlar i den upprätta bilden. En punkt med
    /// konfidens 0 är ogiltig (Apple) och sparas som saknad. t = pts tills serien byggs.
    /// METOD MS7, MS8
    public static func fromVision(pts: Double, points: [PoseJoint?], confidence: Double,
                                  uprightWidth: Int, uprightHeight: Int) -> PoseFrame {
        let joints = (0..<JointSeries.names.count).map { i -> PoseJoint? in
            guard i < points.count, let p = points[i], p.c > 0, p.x.isFinite, p.y.isFinite else { return nil }
            let px = Orientation.pixels(x: p.x, y: p.y, uprightWidth: uprightWidth, uprightHeight: uprightHeight)
            return PoseJoint(x: px.x, y: px.y, c: p.c)
        }
        return PoseFrame(t: pts, pts: pts, joints: joints, confidence: confidence)
    }

    /// En ruta utan person: 13 saknade leder.
    public static func empty(t: Double, pts: Double) -> PoseFrame {
        PoseFrame(t: t, pts: pts, joints: Array(repeating: nil, count: JointSeries.names.count), confidence: 0)
    }
}

/// Från Visions rutor till ett slags leder: en person per ruta (PosePicker, METOD MS8),
/// följd från ruta till ruta, med t relativt klicket. En ruta där ingen säker person
/// finns behålls med saknade leder, så att tiden och andelen hela rutor (MS5) syns.
public enum PoseTrack {
    public static func series(_ scanned: [ScannedFrame], click: Double, width: Int, height: Int) -> JointSeries {
        var previous: (x: Double, y: Double)?
        var frames: [PoseFrame] = []
        for s in scanned.sorted(by: { $0.pts < $1.pts }) {
            let t = s.pts - click
            if let i = PosePicker.pick(s.candidates, previousHipMid: previous, width: width) {
                let c = s.candidates[i]
                frames.append(PoseFrame(t: t, pts: s.pts, joints: c.joints, confidence: c.confidence))
                if let h = c.hipMid { previous = h }
            } else {
                frames.append(.empty(t: t, pts: s.pts))
            }
        }
        return JointSeries(width: width, height: height, frames: frames)
    }
}

extension JointSeries {
    /// Avrundad som i paketet (S2_SPEC §8.3): 0,1 px, konfidensen på 3 decimaler och
    /// tiderna på 4. Sparas så i `Leder/`, så att filen och paketet är samma tal.
    public func rounded() -> JointSeries {
        func r(_ v: Double, _ steg: Double) -> Double { (v / steg).rounded() * steg }
        var s = self
        s.frames = frames.map { f in
            PoseFrame(t: r(f.t, 1e-4), pts: r(f.pts, 1e-4),
                      joints: f.joints.map { j in j.map { PoseJoint(x: r($0.x, 0.1), y: r($0.y, 0.1), c: r($0.c, 1e-3)) } },
                      confidence: r(f.confidence, 1e-3))
        }
        return s
    }
}

// MARK: - Planen: vilket steg är nästa

/// Analysens tre steg för ett slag (S2_SPEC §4.3): det glesa passet och domen, det täta
/// med lederna, och klippet.
public enum AnalysisStep: Equatable, Sendable {
    case sparse(Int)
    case dense(Int)
    case clip(Int)

    /// Slagets plats i `PassState.shots`.
    public var shot: Int {
        switch self {
        case .sparse(let i), .dense(let i), .clip(let i): return i
        }
    }
}

/// Ordningen och fönstren. Först domen på alla slag (listan fylls snabbt), sedan
/// lederna och klippet slag för slag. Varje steg avgörs av det som står i passet, så
/// att en avbruten analys fortsätter från första slag som saknar något (S2_SPEC §6.4).
/// BESLUT B25
public enum ShotPlan {
    /// Var k:te ruta i det täta passet: varje ruta (S2_SPEC §6.1; 2 om Vision tar mer än
    /// 20 ms per ruta, Johannes beslut). METOD MS12
    public static let denseStride = 1
    /// Klippet kring slaget, s: samma fönster som det täta passet (S2_SPEC §8.2). METOD MS12
    public static let clipWindow = SwingCheck.denseWindow
    /// Ett klick räknas som samma när det ligger så nära, s (en ny läsning av samma fil).
    public static let sameClick = 0.001

    /// Slagen ur seriernas klick. Ett slag som redan finns (samma serie, samma klick)
    /// behåller sitt id och allt som är gjort; ett klick utan slag får nästa lediga id;
    /// ett slag vars klick inte längre finns tas bort. Ordningen är serie och tid.
    public static func sync(_ pass: PassState) -> [ShotRecord] {
        var kvar: [ShotRecord] = []
        var nya: [(series: Int, click: Click)] = []
        for s in pass.series.sorted(by: { $0.nr < $1.nr }) {
            for c in s.clicks.sorted(by: { $0.time < $1.time }) {
                if let old = pass.shots.first(where: { $0.series == s.nr && abs($0.click.time - c.time) <= sameClick }) {
                    kvar.append(old)
                } else {
                    nya.append((s.nr, c))
                }
            }
        }
        var n = pass.shots.compactMap { ShotRecord.number($0.id) }.max() ?? 0
        for (serie, c) in nya {
            n += 1
            kvar.append(ShotRecord(id: ShotRecord.id(n), series: serie, click: c,
                                   impact: c.time - pass.setup.soundDelay))
        }
        return kvar.sorted { ($0.series, $0.click.time) < ($1.series, $1.click.time) }
    }

    /// Nästa steg, eller nil när allt är gjort. Ett slag vars serie saknas hoppas över.
    public static func next(_ pass: PassState) -> AnalysisStep? {
        let serier = Set(pass.series.map(\.nr))
        let shots = pass.shots.indices.filter { serier.contains(pass.shots[$0].series) }
        if let i = shots.first(where: { pass.shots[$0].verdict == nil }) { return .sparse(i) }
        for i in shots where pass.shots[i].wantsDetail {
            let s = pass.shots[i]
            if s.joints == nil { return .dense(i) }
            if s.clip == nil { return .clip(i) }
        }
        return nil
    }

    /// Stegen gjorda och alla steg som passet har nu: en dom per slag, och leder och
    /// klipp för de bekräftade och osäkra. Ett slag utan dom räknas som ett slag.
    public static func progress(_ pass: PassState) -> (done: Int, total: Int) {
        var done = 0, total = 0
        for s in pass.shots {
            total += 1
            if s.verdict != nil { done += 1 }
            if s.verdict == nil || s.wantsDetail {
                total += 2
                if s.joints != nil { done += 1 }
                if s.clip != nil { done += 1 }
            }
        }
        return (done, total)
    }

    /// Fönstret kring klicket i filens tid, inom filen [0, längd]. nil när inget är kvar.
    public static func window(_ w: ClosedRange<Double>, click: Double, duration: Double) -> ClosedRange<Double>? {
        let a = max(0, click + w.lowerBound)
        let b = duration > 0 ? min(duration, click + w.upperBound) : click + w.upperBound
        return a < b ? a...b : nil
    }

    /// Vision-passet för ett steg: fönstret, steget mellan rutorna och orienteringen.
    public static func request(_ step: AnalysisStep, pass: PassState, file: URL) -> PoseScanRequest? {
        guard pass.shots.indices.contains(step.shot) else { return nil }
        let shot = pass.shots[step.shot]
        guard let s = pass.series.first(where: { $0.nr == shot.series }) else { return nil }
        let w: ClosedRange<Double>
        let stride: Int
        switch step {
        case .sparse:
            w = SwingCheck.sparseWindow
            stride = SwingCheck.sparseStride
        case .dense:
            w = SwingCheck.denseWindow
            stride = denseStride
        case .clip:
            return nil
        }
        guard let f = window(w, click: shot.click.time, duration: s.duration) else { return nil }
        return PoseScanRequest(file: file, from: f.lowerBound, to: f.upperBound, stride: stride, exif: s.orientation,
                               uprightWidth: s.uprightWidth, uprightHeight: s.uprightHeight)
    }
}

// MARK: - Klippet

/// Klicket mätt om i klippet (S2_SPEC §8.2): var passthrough-klippet exakt börjar är inte
/// dokumenterat, så klippets egna klick avgör. METOD MS12
public enum ClipCheck {
    /// Över så mycket från det väntade märks slaget, s. METOD MS12
    public static let tolerance = 0.010

    /// Klicket i klippet närmast det väntade (seriens klick − klippets begärda start),
    /// och om slaget märks: inget klick, eller längre bort än toleransen.
    public static func measure(_ clicks: [Click], expected: Double) -> (time: Double?, flagged: Bool) {
        guard let c = clicks.min(by: { abs($0.time - expected) < abs($1.time - expected) }) else { return (nil, true) }
        return (c.time, abs(c.time - expected) > tolerance)
    }
}

// MARK: - Linjerna vid träffen

/// De uppmätta linjerna över bilden vid träffen (BESLUT B13: ingen figur): axellinjen,
/// höftlinjen och handlederna, personens vänstra fylld och högra ihålig, så att vänster
/// och höger går att se med ögat (klapprovet T2). Punkterna är andelar 0–1 av den
/// upprätta bilden, origo uppe till vänster.
public struct ImpactOverlay: Equatable, Sendable {
    public struct Point: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    public var t: Double
    public var shoulders: [Point]
    public var hips: [Point]
    public var leftWrist: Point?
    public var rightWrist: Point?

    /// Rutan får ligga så långt från träffen, s.
    public static let maxOffset = 0.05

    /// Linjerna i rutan närmast `t` (s relativt klicket) som har någon säker led, eller nil.
    public static func at(_ series: JointSeries, t: Double) -> ImpactOverlay? {
        guard series.width > 0, series.height > 0 else { return nil }
        let med = series.frames.filter { f in (0..<f.joints.count).contains { f.joint($0) != nil } }
        guard let f = med.min(by: { abs($0.t - t) < abs($1.t - t) }), abs(f.t - t) <= maxOffset else { return nil }
        let w = Double(series.width), h = Double(series.height)
        func p(_ i: Int) -> Point? { f.joint(i).map { Point(x: $0.x / w, y: $0.y / h) } }
        func par(_ a: Int, _ b: Int) -> [Point] {
            guard let pa = p(a), let pb = p(b) else { return [] }
            return [pa, pb]
        }
        return ImpactOverlay(t: f.t, shoulders: par(JointSeries.axelV, JointSeries.axelH),
                             hips: par(JointSeries.hoftV, JointSeries.hoftH),
                             leftWrist: p(JointSeries.handledV), rightWrist: p(JointSeries.handledH))
    }
}

// MARK: - Listan

/// En rad i listan över slagen som värden: numret, serien och klubban, tiden i serien,
/// domen och varningarna (signalfärgen bara för dem, BESLUT B13). Orden till användaren
/// står i appens String Catalog (BESLUT B33); Swing/Visning/Texter.swift rörs inte här.
public struct ShotRow: Equatable, Sendable, Identifiable {
    public var id: String
    public var number: Int
    public var series: Int
    /// Klubbans etikett ("7i"), som i uppställningen.
    public var club: String?
    /// Klicket i serien, s, med en decimal ("12.3").
    public var time: String
    public var verdict: SwingVerdict?
    /// Domen bär en varning: osäker, klippet märkt eller orienteringen misstänkt.
    public var warning: Bool
    public var changedByJohannes: Bool
    /// Lederna finns (det täta passet är gjort).
    public var hasJoints: Bool

    public static func rows(_ pass: PassState) -> [ShotRow] {
        pass.shots.map { s in
            let klubba = pass.series.first { $0.nr == s.series }.map { PassSetup.clubLabel($0.club) }
            let warn = s.verdict == .uncertain || s.clipFlagged == true || s.orientationSuspect == true
            return ShotRow(id: s.id, number: ShotRecord.number(s.id) ?? 0, series: s.series, club: klubba,
                           time: Taltext.decimal(s.click.time, digits: 1), verdict: s.verdict, warning: warn,
                           changedByJohannes: s.verdictByJohannes, hasJoints: s.joints != nil)
        }
    }

    /// Slagen per dom, och Visions tid per ruta med en decimal ("18.4"), för raden under rubriken.
    public static func counts(_ pass: PassState) -> (swing: Int, notSwing: Int, uncertain: Int, open: Int, msPerFrame: String?) {
        let n = { (v: SwingVerdict?) in pass.shots.filter { $0.verdict == v }.count }
        return (n(.swing), n(.notSwing), n(.uncertain), n(nil),
                pass.vision?.msPerFrame.map { Taltext.decimal($0, digits: 1) })
    }
}

extension PassState {
    /// Passet märks "orienteringen misstänkt" när fler än hälften av slagen med leder är
    /// det (S2_SPEC §6.2). METOD MS7
    public var orientationSuspect: Bool {
        let med = shots.compactMap(\.orientationSuspect)
        return !med.isEmpty && 2 * med.filter { $0 }.count > med.count
    }

    /// Johannes ändrar domen på ett slag; analysen gör sedan lederna och klippet om
    /// slaget blev en sving eller osäkert (S2_SPEC §4.3).
    public mutating func setVerdict(_ v: SwingVerdict, shot id: String) {
        guard let i = shots.firstIndex(where: { $0.id == id }) else { return }
        shots[i].verdict = v
        shots[i].verdictByJohannes = true
    }
}
