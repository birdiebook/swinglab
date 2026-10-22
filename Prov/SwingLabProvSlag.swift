// SIMULATORPROVET FÖR SLAGEN OCH LEDERNA (S2_SPEC §10.2 steg 6–7, §12 S2e).
//
// Vad som bevisas här, på provets PÅHITTADE film (SwingLabProvInspelning.swift; inga
// riktiga svingar, CLAUDE.md: Dataregeln):
//   steg 6  klippet: appens passthrough-export kring ett klick, och klicket mätt i
//           klippet stämmer med den vita rutan i klippet inom en ruta;
//   steg 7  appens Vision-körning (PoseRunner) på klippet: varje ruta avkodas och når
//           Vision-anropet med sin tid och orientering, en körning utan personer ger en
//           JointSeries med alla leder saknade, och Visions eget fel stoppar analysen synligt;
//   kedjan  appens hela analys (Analysis) på ett pass ur filmen, med PÅHITTADE leder i
//           Visions ställe (PoseSource, DemoLeder): domen, lederna på disk, klippen,
//           passet, återupptagningen efter ett avbrott och Johannes ändrade dom.
// Vision går inte att starta i simulatorn (kod 9, även på CPU); steg 7 prövar därför
// läsningen kring anropet, att Visions fel syns och att inget sväljs. VISIONS LEDER
// SJÄLVA PROVAS BARA PÅ TELEFONEN (T2, METOD MS12). Bilden av listan ritas till /tmp/swinglab_prov/slag.png.

import XCTest
import AVFoundation
import CoreGraphics
import ImageIO
import SwiftUI
import Vision
import Swing
import Capture
import SwingDemo
@testable import SwingLab

/// Påhittade leder i Visions ställe: rutornas tider läses ur filen (samma rutor och samma
/// fönster som Vision skulle få), och lederna kommer ur DemoLeder. Kastar på det anrop
/// som `failOnCall` säger, så att avbrottet prövas.
final class DemoPoseSource: PoseSource, @unchecked Sendable {
    let swingClicks: [Double]
    let allClicks: [Double]
    let failOnCall: Int?
    private let lock = NSLock()
    private var calls = 0

    init(swingClicks: [Double], allClicks: [Double], failOnCall: Int? = nil) {
        self.swingClicks = swingClicks
        self.allClicks = allClicks
        self.failOnCall = failOnCall
    }

    func scan(_ r: PoseScanRequest, progress: @escaping @Sendable (Double) -> Void) async throws -> PoseScan {
        let n = lock.withLock { () -> Int in
            calls += 1
            return calls
        }
        if n == failOnCall { throw ProvFel("påhittat avbrott i anrop \(n)") }
        let tider = try await MediaReader.frameTimes(r.file).filter { $0 >= r.from - 1e-6 && $0 <= r.to + 1e-6 }
        // Klicket som fönstret hör till: fönstret slutar 0,1 s (glest) eller 1,5 s (tätt)
        // efter klicket, om filen inte tog slut före (METOD MS5).
        func avstand(_ c: Double) -> Double {
            min(abs(r.to - SwingCheck.sparseWindow.upperBound - c), abs(r.to - SwingCheck.denseWindow.upperBound - c))
        }
        let iFonstret = allClicks.filter { $0 >= r.from && $0 <= r.to }
        let klick = iFonstret.min { avstand($0) < avstand($1) } ?? r.from
        let sving = swingClicks.contains { abs($0 - klick) < 1e-6 }
        var frames: [ScannedFrame] = []
        for (k, t) in tider.enumerated() where k % max(1, r.stride) == 0 {
            frames.append(ScannedFrame(pts: t, candidates: DemoLeder.kandidater(
                pts: t, klick: klick, sving: sving, width: r.uprightWidth, height: r.uprightHeight)))
        }
        progress(1)
        return PoseScan(frames: frames, decodedFrames: tider.count, visionSeconds: 0.001 * Double(frames.count),
                        wallSeconds: 0.002 * Double(frames.count))
    }
}

@MainActor
final class SwingLabProvSlag: XCTestCase {
    static let ut = "/tmp/swinglab_prov"

    func tmp(_ namn: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: "swinglab-prov", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: namn)
    }

    // MARK: Steg 6 — klippet

    /// Passthrough-klippet [0,5; 2,0] s ur filmen: klicket mätt i klippet ligger på den
    /// vita rutan i klippet inom en ruta (S2_SPEC §10.2 steg 6), och var klippet börjar
    /// mot det begärda skrivs ut (METOD MS12).
    func testSteg6Klippet() async throws {
        let film = try tmp("slag-film.mov")
        try await SyntheticMovie.write(to: film, sound: .lpcm)
        let klipp = try tmp("slag-klipp.mov")
        try await Clips.export(film, range: 0.5...2.0, to: klipp)

        let tider = try await MediaReader.frameTimes(klipp)
        let langd = try await AVURLAsset(url: klipp).load(.duration).seconds
        let klick = try await MediaReader.clicks(klipp)
        let l = try await MediaReader.luma(klipp)
        let vita = zip(l.times, l.luma).filter { $0.1 > 0.8 }.map(\.0)
        let m = ClipCheck.measure(klick, expected: 1.0 - 0.5)
        print("PROV: klipp längd \(String(format: "%.4f", langd)) s, \(tider.count) rutor, första \(tider.first ?? -1), "
              + "klick \(klick.map { String(format: "%.5f", $0.time) }), vita \(vita.map { String(format: "%.5f", $0) }), "
              + "klicket mot väntat \(String(format: "%+.2f", ((m.time ?? .nan) - 0.5) * 1000)) ms, märkt \(m.flagged)")
        XCTAssertEqual(langd, 1.5, accuracy: 0.05)
        XCTAssertEqual(klick.count, 1, "ett klick i klippet")
        XCTAssertEqual(vita.count, 1, "en vit ruta i klippet")
        let k = try XCTUnwrap(klick.first)
        let v = try XCTUnwrap(vita.first)
        XCTAssertEqual(k.time, v, accuracy: 1.0 / 240 + 0.001, "klicket i klippet på den vita rutan")
        XCTAssertFalse(m.flagged, "klicket i klippet inom 10 ms från väntat")
    }

    // MARK: Steg 7 — Vision på klippet

    /// Rutorna som nådde Vision-anropet: den lagrade bildens storlek och orienteringen.
    final class RutLogg: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var rutor: [(w: Int, h: Int, o: CGImagePropertyOrientation)] = []
        func add(_ sb: CMSampleBuffer, _ o: CGImagePropertyOrientation) {
            let pb = CMSampleBufferGetImageBuffer(sb)
            lock.withLock {
                rutor.append((pb.map(CVPixelBufferGetWidth) ?? 0, pb.map(CVPixelBufferGetHeight) ?? 0, o))
            }
        }
    }

    /// Steg 7 (S2_SPEC §10.2). Vision går inte att starta i simulatorn: `perform` kastar
    /// "Unable to setup request" (Vision kod 9), även på CPU (uppmätt 2026-10-22). Provet
    /// prövar därför (a) appens läsning kring Vision-anropet på klippet: varje ruta i
    /// fönstret, med sin egen tid, den lagrade bilden och orienteringen 6, når anropet, och
    /// en körning utan personer ger en serie med alla leder `null`; (b) Vision självt, som
    /// i simulatorn ska kasta ett Vision-fel; och (c) att felet inte sväljs: analysen
    /// stannar på första slaget, visar felet och sparar ingen dom. Visions leder provas på
    /// telefonen (T2). METOD MS12
    func testSteg7VisionPaKlippet() async throws {
        let film = try tmp("vision-film.mov")
        try await SyntheticMovie.write(to: film, sound: .lpcm)
        let klipp = try tmp("vision-klipp.mov")
        try await Clips.export(film, range: 0.5...2.0, to: klipp)
        let geo = try await MediaReader.geometry(klipp)
        let upp = Orientation.uprightSize(width: geo.width, height: geo.height, exif: geo.exif)
        let antal = try await MediaReader.frameTimes(klipp).count
        let req = PoseScanRequest(file: klipp, from: 0, to: 1.5, stride: 1, exif: geo.exif,
                                  uprightWidth: upp.width, uprightHeight: upp.height)

        // (a) Läsningen kring anropet.
        let logg = RutLogg()
        let utanVision = VisionPoseSource(makeDetect: { () -> VisionPoseSource.Detect in
            { sb, o in
                logg.add(sb, o)
                return []
            }
        })
        let scan = try await utanVision.scan(req) { _ in }
        let series = PoseTrack.series(scan.frames, click: 1.0 - 0.5, width: upp.width, height: upp.height)
        print("PROV: steg 7 läsningen: \(scan.frames.count) rutor till anropet av \(scan.decodedFrames) avkodade "
              + "(\(antal) i klippet), lagrad \(logg.rutor.first.map { "\($0.w)×\($0.h)" } ?? "-"), "
              + "orientering \(logg.rutor.first.map { "\($0.o.rawValue)" } ?? "-"), upprätt \(upp.width)×\(upp.height)")
        XCTAssertEqual(geo.exif, 6)
        XCTAssertEqual(scan.decodedFrames, antal, "varje ruta i fönstret avkodas")
        XCTAssertEqual(scan.frames.count, antal, "varje ruta når Vision-anropet")
        XCTAssertEqual(logg.rutor.count, antal)
        XCTAssertTrue(logg.rutor.allSatisfy { $0.w == 480 && $0.h == 270 && $0.o == .right }, "den lagrade bilden, EXIF 6")
        XCTAssertEqual(series.frames.count, antal)
        XCTAssertTrue(series.frames.allSatisfy { $0.joints.count == 13 && $0.joints.allSatisfy { $0 == nil } })
        XCTAssertEqual(SwingCheck.verdict(series), .uncertain)
        let tider = series.frames.map(\.pts)
        XCTAssertEqual(tider, tider.sorted(), "rutorna med sina egna tider, i ordning")
        XCTAssertEqual(series.frames.first?.t ?? .nan, -0.5, accuracy: 1.0 / 240 + 0.001)

        // (b) Vision självt.
        var visionFel: NSError?
        do {
            let v = try await VisionPoseSource().scan(req) { _ in }
            let personer = v.frames.reduce(0) { $0 + $1.candidates.count }
            print("PROV: steg 7 Vision körde i simulatorn: \(v.frames.count) rutor, \(personer) personer")
            XCTAssertEqual(v.frames.count, antal)
            XCTAssertEqual(personer, 0, "ingen människa i en grå film")
        } catch {
            let ns = error as NSError
            visionFel = ns
            print("PROV: steg 7 Vision i simulatorn: \(ns.domain) kod \(ns.code): \(ns.localizedDescription)")
            XCTAssertEqual(ns.domain, VNErrorDomain, "ett Vision-fel, inte ett annat")
        }

        // (c) Analysen med Vision på ett pass ur filmen: felet syns och ingen dom sparas.
        let rot = try tmp("vision-pass-\(UUID().uuidString)")
        let store = Store(root: rot, exportFolder: rot.appending(path: "Export"))
        var pass = store.newPass(setup: PassSetup(view: .fo, club: "j7", distance: 3, hand: .hoger),
                                 at: Date(timeIntervalSince1970: 1_792_848_612))
        let fil = PassState.videoPath(nr: 1)
        try await SyntheticMovie.write(to: store.url(fil, in: pass.id), sound: .lpcm)
        pass.series.append(try await SeriesMaker.make(url: store.url(fil, in: pass.id), nr: 1, file: fil,
                                                      source: .recording, club: "j7", start: pass.created,
                                                      startHost: nil, microphone: nil))
        store.save(pass)
        let analys = Analysis()
        await analys.run(passID: pass.id, store: store)
        let efter = try XCTUnwrap(store.load(pass.id))
        print("PROV: steg 7 analysen med Vision: \(analys.problem ?? "inget fel"), domar \(efter.shots.map { $0.verdict.map { "\($0)" } ?? "-" })")
        XCTAssertEqual(efter.shots.count, 2)
        if visionFel != nil {
            XCTAssertNotNil(analys.problem, "felet syns i vyn")
            XCTAssertEqual((analys.lastError as NSError?)?.domain, VNErrorDomain)
            XCTAssertEqual(analys.stepsRun, [])
            XCTAssertTrue(efter.shots.allSatisfy { $0.verdict == nil }, "ingen dom utan leder")
            XCTAssertEqual(efter.status, .recorded)
        } else {
            XCTAssertNil(analys.problem)
            XCTAssertTrue(efter.shots.allSatisfy { $0.verdict == .uncertain })
        }
    }

    // MARK: Kedjan med påhittade leder

    /// Appens hela analys på ett pass ur filmen (klick vid 1,0 och 2,2 s), med påhittade
    /// leder i Visions ställe: svingen vid 1,0 blir ett slag med leder och klipp, den
    /// stilla vid 2,2 inte. Ett avbrott mitt i stoppar analysen med felet synligt, och
    /// nästa körning fortsätter där. Johannes ändrade dom ger lederna och klippet som
    /// saknas. Listan ritas till slag.png. METOD MS5, MS8, MS12, BESLUT B25
    func testKedjanMedPahittadeLeder() async throws {
        let rot = try tmp("slag-\(UUID().uuidString)")
        let store = Store(root: rot, exportFolder: rot.appending(path: "Export"))
        var pass = store.newPass(setup: PassSetup(view: .fo, club: "j7", distance: 3, hand: .hoger),
                                 at: Date(timeIntervalSince1970: 1_792_848_612))
        let fil = PassState.videoPath(nr: 1)
        try await SyntheticMovie.write(to: store.url(fil, in: pass.id), sound: .lpcm)
        let serie = try await SeriesMaker.make(url: store.url(fil, in: pass.id), nr: 1, file: fil, source: .recording,
                                               club: "j7", start: pass.created, startHost: nil, microphone: nil)
        pass.series.append(serie)
        store.save(pass)
        let klick = serie.clicks.map(\.time)
        XCTAssertEqual(klick.count, 2)
        let sving = try XCTUnwrap(klick.first)

        // 1. Avbrott i tredje anropet (glest s01, glest s02, tätt s01).
        let analys = Analysis()
        let avbruten = DemoPoseSource(swingClicks: [sving], allClicks: klick, failOnCall: 3)
        let efter1 = await analys.run(passID: pass.id, store: store, source: avbruten)
        print("PROV: kedjan avbruten: \(analys.problem ?? "inget fel"), steg \(analys.stepsRun)")
        XCTAssertNotNil(analys.problem, "felet syns")
        XCTAssertTrue(analys.lastError is ProvFel, "felet är källans, inte svalt")
        XCTAssertEqual(analys.stepsRun, [.sparse(0), .sparse(1)])
        var p = try XCTUnwrap(store.load(pass.id))
        XCTAssertEqual(efter1?.shots, p.shots)
        XCTAssertEqual(p.shots.map(\.id), ["s01", "s02"])
        XCTAssertEqual(p.shots.map(\.verdict), [.swing, .notSwing])
        XCTAssertNil(p.shots[0].joints)
        XCTAssertEqual(p.status, .recorded)

        // 2. Fortsätter där: bara lederna och klippet för s01.
        let kalla = DemoPoseSource(swingClicks: [sving], allClicks: klick)
        await analys.run(passID: pass.id, store: store, source: kalla)
        XCTAssertNil(analys.problem)
        XCTAssertEqual(analys.stepsRun, [.dense(0), .clip(0)])
        p = try XCTUnwrap(store.load(pass.id))
        let s1 = p.shots[0]
        XCTAssertEqual(s1.joints, "Leder/s01.json")
        let leder = try XCTUnwrap(store.joints(try XCTUnwrap(s1.joints), in: p.id))
        XCTAssertEqual(leder.width, 270)
        XCTAssertEqual(leder.height, 480)
        XCTAssertEqual(leder.frames.count, s1.jointFrames)
        // Fönstret [−2,5; +1,5] kapat vid filens början: rutorna från 0 s, var tredje borta.
        XCTAssertEqual(leder.frames.first?.pts ?? .nan, 0, accuracy: 1e-4)
        XCTAssertEqual(leder.frames.last?.t ?? .nan, 1.5, accuracy: 2.0 / 240)
        XCTAssertEqual(Double(leder.frames.count), 2.5 * 240 * 2 / 3, accuracy: 3)
        // Personvalet tog spelaren (höfterna vid bildens mitt), inte grannen.
        XCTAssertTrue(leder.frames.allSatisfy { abs(($0.hipMid?.x ?? 0) - 135) < 0.1 })
        XCTAssertEqual(s1.orientationSuspect, false)
        XCTAssertEqual(s1.clip, "Klipp/s01.mov")
        XCTAssertEqual(s1.clipStart, 0)
        XCTAssertEqual(s1.clickInClip ?? .nan, sving, accuracy: 0.002)
        XCTAssertEqual(s1.clipFlagged, false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.url("Klipp/s01.mov", in: p.id).path))
        XCTAssertNil(p.shots[1].clip, "inte en sving: inget klipp")
        XCTAssertNil(p.shots[1].joints)
        XCTAssertEqual(p.status, .analyzed)
        let ms = try XCTUnwrap(p.vision?.msPerFrame)
        XCTAssertEqual(ms, 1, accuracy: 1e-6)
        XCTAssertEqual(p.shots[0].impact, sving - 3.0 / 343, accuracy: 1e-9)

        // 3. Johannes gör s02 till en sving: lederna och klippet som saknas, inget mer.
        p.setVerdict(.swing, shot: "s02")
        store.save(p)
        await analys.run(passID: pass.id, store: store, source: kalla)
        XCTAssertEqual(analys.stepsRun, [.dense(1), .clip(1)])
        p = try XCTUnwrap(store.load(pass.id))
        XCTAssertEqual(p.shots[1].verdict, .swing)
        XCTAssertTrue(p.shots[1].verdictByJohannes)
        XCTAssertEqual(p.shots[1].clickInClip ?? .nan, klick[1] - (p.shots[1].clipStart ?? .nan), accuracy: 0.002)
        await analys.run(passID: pass.id, store: store, source: kalla)
        XCTAssertEqual(analys.stepsRun, [], "allt är gjort")

        // 4. Listan med miniatyrerna och linjerna vid träffen.
        var bilder: [String: CGImage] = [:]
        var linjer: [String: ImpactOverlay] = [:]
        for s in p.shots {
            bilder[s.id] = try await ShotImages.impactFrame(pass: p, shot: s, store: store)
            linjer[s.id] = ShotImages.overlay(shot: s, pass: p, store: store)
        }
        let o = try XCTUnwrap(linjer["s01"], "linjerna vid träffen")
        XCTAssertEqual(o.shoulders.count, 2)
        XCTAssertNotNil(o.leftWrist)
        let bild = try XCTUnwrap(bilder["s01"], "rutan vid träffen")
        XCTAssertEqual(bild.width, 270)
        XCTAssertEqual(bild.height, 480)
        print("PROV: kedjan klar: \(p.shots.map { "\($0.id) \($0.verdict.map { "\($0)" } ?? "-") \($0.jointFrames ?? 0) rutor klick i klipp \(String(format: "%.4f", $0.clickInClip ?? .nan))" }), "
              + "ms/ruta \(ms), linjerna vid t = \(String(format: "%.4f", o.t))")

        let vy = ShotsContent(pass: p, images: bilder, overlays: linjer, analysis: AnalysisState(), editable: false)
            .padding(.horizontal, 20)
            .frame(width: 390)
            .padding(.vertical, 20)
            .background(Theme.ground)
            .environment(\.colorScheme, .dark)
        let r = ImageRenderer(content: vy)
        r.scale = 2
        let png = try XCTUnwrap(r.uiImage?.pngData())
        try FileManager.default.createDirectory(atPath: Self.ut, withIntermediateDirectories: true)
        try png.write(to: URL(fileURLWithPath: Self.ut + "/slag.png"))

        // Miniatyren: linjerna är vita över den grå rutan.
        let tumme = ImpactThumb(image: bild, overlay: o).frame(width: 270, height: 480)
        let tr = ImageRenderer(content: tumme)
        tr.scale = 1
        let tpng = try XCTUnwrap(tr.uiImage?.pngData())
        try tpng.write(to: URL(fileURLWithPath: Self.ut + "/traff.png"))
    }
}
