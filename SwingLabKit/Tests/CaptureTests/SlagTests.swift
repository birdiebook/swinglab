import Foundation
import XCTest
import Swing
import SwingDemo
@testable import Capture

/// S2e: slagen ur klicken, analysens ordning och återupptagning, personvalet genom en
/// hel serie, klippets kontroll, linjerna vid träffen och listans rader, på PÅHITTADE
/// leder (CLAUDE.md, Dataregeln). METOD MS5, MS6, MS7, MS8, MS12
final class SlagTests: XCTestCase {

    static func pass(klick: [[Double]], langd: Double = 30) -> PassState {
        var p = PassState(id: "20261024-153012", created: Date(timeIntervalSince1970: 1_792_848_612),
                          setup: PassSetup(view: .fo, club: "j7", distance: 3.43, hand: .hoger))
        for (k, tider) in klick.enumerated() {
            let timing = FrameTiming.analyze((0..<10).map { Double($0) / 240 })
            p.series.append(SeriesRecord(nr: k + 1, source: .recording, club: "j7", file: PassState.videoPath(nr: k + 1),
                                         start: p.created, startHost: nil, duration: langd, bytes: 1, timing: timing,
                                         clicks: tider.map { Click(time: $0, strength: 50) }, orientation: 6,
                                         uprightWidth: 1080, uprightHeight: 1920))
        }
        return p
    }

    // MARK: Slagen ur klicken

    func testSlagenFarIdITidsordningOchTraffenUrAvstandet() {
        var p = Self.pass(klick: [[12.0, 4.0], [3.0]])
        p.shots = ShotPlan.sync(p)
        XCTAssertEqual(p.shots.map(\.id), ["s01", "s02", "s03"])
        XCTAssertEqual(p.shots.map(\.series), [1, 1, 2])
        XCTAssertEqual(p.shots.map(\.click.time), [4.0, 12.0, 3.0])
        // 3,43 m / 343 m/s = 10 ms (METOD MS6).
        XCTAssertEqual(p.shots[0].impact, 3.99, accuracy: 1e-9)
        XCTAssertNil(p.shots[0].verdict)
    }

    func testEttIdAterAnvandsAldrigOchGjortArbeteBehalls() {
        var p = Self.pass(klick: [[4.0, 12.0]])
        p.shots = ShotPlan.sync(p)
        p.shots[1].verdict = .swing
        p.shots[1].joints = ShotRecord.jointsPath("s02")
        // Serien läses om: klicket vid 4 s försvinner, ett nytt kommer vid 20 s, och 12 s
        // ligger kvar inom en millisekund.
        p.series[0].clicks = [Click(time: 12.0004, strength: 50), Click(time: 20, strength: 40)]
        p.shots = ShotPlan.sync(p)
        XCTAssertEqual(p.shots.map(\.id), ["s02", "s03"])
        XCTAssertEqual(p.shots[0].verdict, .swing)
        XCTAssertEqual(p.shots[0].joints, "Leder/s02.json")
        XCTAssertEqual(p.shots[1].click.time, 20)
        XCTAssertEqual(ShotRecord.clipPath("s03"), "Klipp/s03.mov")
        XCTAssertEqual(ShotRecord.number("s12"), 12)
        XCTAssertNil(ShotRecord.number("x1"))
    }

    // MARK: Ordningen och återupptagningen

    /// Först domen på alla, sedan leder och klipp slag för slag; ett "inte slag" får
    /// inget av det, och en ändrad dom ger stegen som saknas (S2_SPEC §4.3, §6.4).
    func testOrdningenOchAterupptagningen() {
        var p = Self.pass(klick: [[4.0, 12.0, 20.0]])
        p.shots = ShotPlan.sync(p)
        XCTAssertEqual(ShotPlan.progress(p).done, 0)
        XCTAssertEqual(ShotPlan.progress(p).total, 9)
        var steg: [AnalysisStep] = []
        var domar: [SwingVerdict] = [.swing, .notSwing, .uncertain]
        while let s = ShotPlan.next(p), steg.count < 20 {
            steg.append(s)
            switch s {
            case .sparse(let i): p.shots[i].verdict = domar.removeFirst()
            case .dense(let i): p.shots[i].joints = ShotRecord.jointsPath(p.shots[i].id)
            case .clip(let i): p.shots[i].clip = ShotRecord.clipPath(p.shots[i].id)
            }
        }
        XCTAssertEqual(steg, [.sparse(0), .sparse(1), .sparse(2), .dense(0), .clip(0), .dense(2), .clip(2)])
        XCTAssertEqual(ShotPlan.progress(p).done, ShotPlan.progress(p).total)
        XCTAssertEqual(ShotPlan.progress(p).total, 7)

        // Johannes gör slag 2 till en sving: bara dess leder och klipp saknas.
        p.setVerdict(.swing, shot: "s02")
        XCTAssertTrue(p.shots[1].verdictByJohannes)
        XCTAssertEqual(ShotPlan.next(p), .dense(1))
        // En avbruten analys: slaget utan klipp fortsätter med klippet.
        p.shots[1].joints = "Leder/s02.json"
        XCTAssertEqual(ShotPlan.next(p), .clip(1))
        // Ett slag vars serie inte finns hoppas över.
        p.series.removeAll()
        XCTAssertNil(ShotPlan.next(p))
    }

    func testFonstrenHallerSigIFilen() throws {
        var p = Self.pass(klick: [[1.0, 29.0]], langd: 30)
        p.shots = ShotPlan.sync(p)
        let url = URL(fileURLWithPath: "/tmp/x.mov")
        let gles = try XCTUnwrap(ShotPlan.request(.sparse(0), pass: p, file: url))
        XCTAssertEqual(gles.from, 0)
        XCTAssertEqual(gles.to, 1.1, accuracy: 1e-12)
        XCTAssertEqual(gles.stride, 8)
        XCTAssertEqual(gles.exif, 6)
        XCTAssertEqual(gles.uprightWidth, 1080)
        let tatt = try XCTUnwrap(ShotPlan.request(.dense(1), pass: p, file: url))
        XCTAssertEqual(tatt.from, 26.5, accuracy: 1e-12)
        XCTAssertEqual(tatt.to, 30)
        XCTAssertEqual(tatt.stride, 1)
        XCTAssertNil(ShotPlan.request(.clip(0), pass: p, file: url))
        XCTAssertEqual(ShotPlan.window(ShotPlan.clipWindow, click: 10, duration: 30), 7.5...11.5)
        XCTAssertNil(ShotPlan.window(ShotPlan.clipWindow, click: 40, duration: 30))
    }

    // MARK: Lederna genom kedjan

    /// Vision-kandidaterna (en granne och spelaren) för var 8:e ruta i en film med var
    /// tredje ruta borta, som det glesa passet läser dem.
    static func skanna(sving: Bool, fonster: ClosedRange<Double>, stride: Int, klick: Double = 10,
                       width: Int = 270, height: Int = 480) -> [ScannedFrame] {
        var rutor: [Double] = []
        for k in 0..<(240 * 20) where k % 3 != 2 {
            let pts = Double(k) / 240
            if fonster.contains(pts) { rutor.append(pts) }
        }
        var ut: [ScannedFrame] = []
        for (n, pts) in rutor.enumerated() where n % stride == 0 {
            let kandidater = DemoLeder.kandidater(pts: pts, klick: klick, sving: sving, width: width, height: height)
            ut.append(ScannedFrame(pts: pts, candidates: kandidater))
        }
        return ut
    }

    func testPersonvaletOchDomenGenomEnSerie() {
        let w = ShotPlan.window(SwingCheck.sparseWindow, click: 10, duration: 20)!
        let sving = PoseTrack.series(Self.skanna(sving: true, fonster: w, stride: 8), click: 10, width: 270, height: 480)
        XCTAssertEqual(SwingCheck.verdict(sving), .swing)
        XCTAssertGreaterThan(sving.frames.count, 25)
        // Spelaren är vald i varje ruta, inte grannen (höfterna vid bildens mitt).
        for f in sving.frames { XCTAssertEqual(f.hipMid!.x, 135, accuracy: 0.01) }
        XCTAssertEqual(sving.frames.first!.t, -1.6, accuracy: 1.0 / 240)
        XCTAssertFalse(sving.orientationSuspect)

        let stilla = PoseTrack.series(Self.skanna(sving: false, fonster: w, stride: 8), click: 10, width: 270, height: 480)
        XCTAssertEqual(SwingCheck.verdict(stilla), .notSwing)
    }

    func testRutorUtanPersonBehallsOchGorDomenOsaker() {
        var skannat = Self.skanna(sving: true, fonster: 8.4...10.1, stride: 8)
        for i in skannat.indices where i % 2 == 0 { skannat[i].candidates = [] }
        let s = PoseTrack.series(skannat, click: 10, width: 270, height: 480)
        XCTAssertEqual(s.frames.count, skannat.count)
        XCTAssertTrue(s.frames[0].joints.allSatisfy { $0 == nil })
        XCTAssertEqual(s.frames[0].confidence, 0)
        XCTAssertEqual(SwingCheck.verdict(s), .uncertain)
        // Ingen person alls (simulatorns Vision på en genererad film): alla leder saknas.
        let tom = PoseTrack.series(skannat.map { ScannedFrame(pts: $0.pts, candidates: []) }, click: 10,
                                   width: 270, height: 480)
        XCTAssertTrue(tom.frames.allSatisfy { $0.joints.count == 13 && $0.joints.allSatisfy { $0 == nil } })
        XCTAssertEqual(SwingCheck.verdict(tom), .uncertain)
    }

    func testVisionsPunkterBlirPixlarIDenUppratteBilden() {
        var punkter = [PoseJoint?](repeating: PoseJoint(x: 0.5, y: 0.9, c: 0.8), count: 13)
        punkter[3] = PoseJoint(x: 0.2, y: 0.2, c: 0)      // konfidens 0 är ogiltig (Apple)
        punkter[4] = nil
        let f = PoseFrame.fromVision(pts: 2.5, points: punkter, confidence: 0.7, uprightWidth: 1080, uprightHeight: 1920)
        XCTAssertEqual(f.joints[0]!.x, 540, accuracy: 1e-9)
        XCTAssertEqual(f.joints[0]!.y, 192, accuracy: 1e-9)
        XCTAssertEqual(f.joints[0]!.c, 0.8)
        XCTAssertNil(f.joints[3])
        XCTAssertNil(f.joints[4])
        XCTAssertEqual(f.joints.count, 13)
        XCTAssertEqual(f.pts, 2.5)
        XCTAssertEqual(f.confidence, 0.7)
        // För få punkter: resten saknas.
        XCTAssertEqual(PoseFrame.fromVision(pts: 0, points: [], confidence: 1, uprightWidth: 10, uprightHeight: 10)
            .joints.compactMap { $0 }.count, 0)
    }

    func testAvrundningenSomIPaketet() throws {
        let s = JointSeries(width: 1080, height: 1920, frames: [
            PoseFrame(t: -0.123456, pts: 9.876543, joints: [PoseJoint(x: 540.06, y: 812.44, c: 0.93456), nil],
                      confidence: 0.91234),
        ]).rounded()
        let f = s.frames[0]
        XCTAssertEqual(f.t, -0.1235, accuracy: 1e-12)
        XCTAssertEqual(f.pts, 9.8765, accuracy: 1e-12)
        XCTAssertEqual(f.joints[0]!.x, 540.1, accuracy: 1e-9)
        XCTAssertEqual(f.joints[0]!.y, 812.4, accuracy: 1e-9)
        XCTAssertEqual(f.joints[0]!.c, 0.935, accuracy: 1e-12)
        XCTAssertNil(f.joints[1])
        XCTAssertEqual(f.confidence, 0.912, accuracy: 1e-12)
        // Formatet: nycklarna som FORMAT.md beskriver.
        let json = String(decoding: try JSONEncoder().encode(s), as: UTF8.self)
        for k in ["\"source\"", "\"width\"", "\"frames\"", "\"joints\"", "\"pts\"", "\"confidence\""] {
            XCTAssertTrue(json.contains(k), k)
        }
    }

    // MARK: Klippet

    func testKlicketIKlippet() {
        let k = [Click(time: 0.4, strength: 10), Click(time: 2.506, strength: 80)]
        let a = ClipCheck.measure(k, expected: 2.5)
        XCTAssertEqual(a.time, 2.506)
        XCTAssertFalse(a.flagged)
        let b = ClipCheck.measure(k, expected: 2.52)
        XCTAssertTrue(b.flagged, "14 ms ifrån")
        let c = ClipCheck.measure([], expected: 2.5)
        XCTAssertNil(c.time)
        XCTAssertTrue(c.flagged)
        XCTAssertEqual(ClipCheck.tolerance, 0.010)
    }

    // MARK: Visions tid

    func testMsPerRuta() {
        var v = VisionStats()
        XCTAssertNil(v.msPerFrame)
        let ruta = ScannedFrame(pts: 0, candidates: [])
        v.add(PoseScan(frames: Array(repeating: ruta, count: 100), decodedFrames: 800, visionSeconds: 1.84, wallSeconds: 2.5))
        v.add(PoseScan(frames: Array(repeating: ruta, count: 100), decodedFrames: 100, visionSeconds: 1.84, wallSeconds: 2.5))
        XCTAssertEqual(v.msPerFrame!, 18.4, accuracy: 1e-9)
        XCTAssertEqual(v.wallMsPerFrame!, 25, accuracy: 1e-9)
        XCTAssertEqual(v.decodedFrames, 900)
        XCTAssertEqual(v.sparseStride, 8)
        XCTAssertEqual(v.denseStride, 1)
    }

    // MARK: Linjerna vid träffen

    func testLinjernaVidTraffen() throws {
        let w = ShotPlan.window(SwingCheck.denseWindow, click: 10, duration: 20)!
        let s = PoseTrack.series(Self.skanna(sving: true, fonster: w, stride: 1), click: 10, width: 270, height: 480)
        let o = try XCTUnwrap(ImpactOverlay.at(s, t: -0.01))
        XCTAssertEqual(o.t, -0.01, accuracy: 1.0 / 120)
        XCTAssertEqual(o.shoulders.count, 2)
        XCTAssertEqual(o.hips.count, 2)
        // Personens vänstra axel (axel_v) ligger till höger i bilden när personen är vänd mot kameran.
        XCTAssertEqual(o.shoulders[0].x, 600.0 / 1080, accuracy: 1e-6)
        XCTAssertEqual(o.shoulders[0].y, 650.0 / 1920, accuracy: 1e-6)
        XCTAssertNotNil(o.leftWrist)
        XCTAssertNotNil(o.rightWrist)
        XCTAssertGreaterThan(o.leftWrist!.x, o.rightWrist!.x)
        // Ingen ruta nära träffen, eller inga leder: inga linjer.
        XCTAssertNil(ImpactOverlay.at(s, t: 5))
        let tom = JointSeries(width: 270, height: 480, frames: [.empty(t: 0, pts: 10)])
        XCTAssertNil(ImpactOverlay.at(tom, t: 0))
    }

    // MARK: Passet och listan

    func testPassetUtanSlagGarAttLasa() throws {
        // pass.json från S2c/S2d saknar shots och vision.
        let p = Self.pass(klick: [[4.0]])
        var d = try JSONSerialization.jsonObject(with: PassCoding.encoder().encode(p)) as! [String: Any]
        XCTAssertNotNil(d["shots"])
        d.removeValue(forKey: "shots")
        d.removeValue(forKey: "vision")
        let gammal = try PassCoding.decoder().decode(PassState.self, from: JSONSerialization.data(withJSONObject: d))
        XCTAssertEqual(gammal.shots, [])
        XCTAssertNil(gammal.vision)
        XCTAssertEqual(gammal.series, p.series)

        var q = p
        q.shots = ShotPlan.sync(q)
        q.shots[0].verdict = .uncertain
        q.vision = VisionStats()
        let igen = try PassCoding.decoder().decode(PassState.self, from: PassCoding.encoder().encode(q))
        XCTAssertEqual(igen, q)
    }

    func testListansRaderOchOrienteringen() {
        var p = Self.pass(klick: [[4.0, 12.26, 20.0]])
        p.shots = ShotPlan.sync(p)
        p.shots[0].verdict = .swing
        p.shots[1].verdict = .uncertain
        p.shots[0].clipFlagged = false
        var v = VisionStats()
        v.add(PoseScan(frames: Array(repeating: ScannedFrame(pts: 0, candidates: []), count: 10), decodedFrames: 10,
                       visionSeconds: 0.184, wallSeconds: 0.2))
        p.vision = v
        let r = ShotRow.rows(p)
        XCTAssertEqual(r.map(\.number), [1, 2, 3])
        XCTAssertEqual(r[1].time, "12.3")
        XCTAssertEqual(r[0].club, "7i")
        XCTAssertEqual(r.map(\.warning), [false, true, false])
        XCTAssertEqual(r[2].verdict, nil)
        let n = ShotRow.counts(p)
        XCTAssertEqual(n.swing, 1)
        XCTAssertEqual(n.uncertain, 1)
        XCTAssertEqual(n.open, 1)
        XCTAssertEqual(n.msPerFrame, "18.4")

        XCTAssertFalse(p.orientationSuspect)
        p.shots[0].orientationSuspect = true
        p.shots[1].orientationSuspect = false
        XCTAssertFalse(p.orientationSuspect, "hälften räcker inte")
        p.shots[2].orientationSuspect = true
        XCTAssertTrue(p.orientationSuspect)
        p.shots[2].clipFlagged = true
        XCTAssertTrue(ShotRow.rows(p)[2].warning)
    }
}
