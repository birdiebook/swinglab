// SIMULATORPROVET FÖR REDIGERAREN (PLAN.md S2i: trimma och utsnitt).
//
// Vad som bevisas här, på provets PÅHITTADE film (SwingLabProvInspelning.swift, klick vid
// 1,0 och 2,2 s; inga riktiga svingar, CLAUDE.md: Dataregeln):
//   bilden    en vit markör uppe till vänster i filens lagrade buffert ligger där
//             SwingLabKit säger i den upprätta bilden (EXIF 6: uppe till höger), inte där
//             fel vridning eller ingen vridning hade lagt den (Orientation.uprightRect);
//   sparat    fönstret 1,1–3,2 s och utsnittet sparas i pass.json med manifestets namn och
//             står kvar efter en omstart (en ny Store på samma mapp);
//   fönstret  klicket vid 1,0 s ligger utanför och blir inget slag; analysens Vision-pass och
//             klippet stannar inom fönstret;
//   utsnittet varje Vision-fråga bär utsnittet, appens Vision-körning skär ut rutan ur
//             varje ruta (markören hamnar rätt i den utskurna bilden, redigering-utskuren.png),
//             och påhittade leder som Vision hade gett dem i den utskurna bilden förs tillbaka till hela bildens pixlar: spelaren väljs, grannen
//             utanför rutan försvinner, och inga leder sparas utanför rutan;
//   vyerna    redigeraren före och efter (redigerare-hel.png, redigerare.png), slagen med
//             serierna och miniatyren i utsnittet (redigering-slag.png, redigering-traff.png);
//   ändringen hela bilden igen gör om slaget och tar bort lederna och klippet på disken.
// Vision går inte att starta i simulatorn (kod 9, METOD MS12): VISIONS LEDER I RUTAN PROVAS
// BARA PÅ TELEFONEN. METOD MS7, MS13

import XCTest
import AVFoundation
import CoreGraphics
import CoreImage
import SwiftUI
import UIKit
import Vision
import Swing
import Capture
import SwingDemo
@testable import SwingLab

/// Påhittade leder som Vision hade gett dem när den bara fick den utskurna rutan: DemoLeders
/// pixlar → normaliserade i den utskurna bilden med origo nere till vänster → appens egen väg tillbaka
/// (`PoseFrame.fromVision(…, crop:)`, samma som `VisionPoseSource.frame`). Frågorna sparas.
final class UtsnittKalla: PoseSource, @unchecked Sendable {
    let inner: DemoPoseSource
    private let lock = NSLock()
    private var fragor: [PoseScanRequest] = []
    var requests: [PoseScanRequest] { lock.withLock { fragor } }

    init(_ inner: DemoPoseSource) { self.inner = inner }

    func scan(_ r: PoseScanRequest, progress: @escaping @Sendable (Double) -> Void) async throws -> PoseScan {
        lock.withLock { fragor.append(r) }
        var scan = try await inner.scan(r, progress: progress)
        guard let ruta = r.crop else { return scan }
        // Som appen: rutan på hela pixlar (VisionPoseSource.cutOut), punkterna normaliserade i den.
        let crop = ruta.snapped(width: r.uprightWidth, height: r.uprightHeight)
        let w = Double(r.uprightWidth), h = Double(r.uprightHeight)
        scan.frames = scan.frames.map { f in
            ScannedFrame(pts: f.pts, candidates: f.candidates.map { k in
                let vision = k.joints.map { j in
                    j.map { p -> PoseJoint in
                        let v = crop.toVision(x: p.x / w, y: p.y / h)
                        return PoseJoint(x: v.x, y: v.y, c: p.c)
                    }
                }
                return PoseFrame.fromVision(pts: k.pts, points: vision, confidence: k.confidence,
                                            uprightWidth: r.uprightWidth, uprightHeight: r.uprightHeight, crop: crop)
            })
        }
        return scan
    }
}

@MainActor
final class SwingLabProvRedigering: XCTestCase {
    static let ut = "/tmp/swinglab_prov"
    /// Markören i den lagrade bufferten 480 × 270, px.
    static let markor = (x: 40, y: 20, width: 80, height: 60)
    /// Utsnittet runt den påhittade spelaren (DemoLeder): grannen till höger hamnar utanför.
    static let utsnitt = CropRect(x: 0.01, y: 0.2, width: 0.78, height: 0.7)

    func tmp(_ namn: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: "swinglab-prov", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: namn)
    }

    func testFonstretOchUtsnittetGenomAnalysen() async throws {
        let rot = try tmp("redigering-\(UUID().uuidString)")
        let store = Store(root: rot, exportFolder: rot.appending(path: "Export"))
        var pass = store.newPass(setup: PassSetup(view: .fo, club: "j7", distance: 3, hand: .hoger),
                                 at: Date(timeIntervalSince1970: 1_792_848_612))
        let fil = PassState.videoPath(nr: 1)
        let film = store.url(fil, in: pass.id)
        try await SyntheticMovie.write(to: film, sound: .lpcm, marker: Self.markor)
        let serie = try await SeriesMaker.make(url: film, nr: 1, file: fil, source: .recording, club: "j7",
                                               start: pass.created, startHost: nil, microphone: nil)
        pass.series.append(serie)
        store.save(pass)
        let klick = serie.clicks.map(\.time)
        XCTAssertEqual(klick.count, 2)
        XCTAssertEqual(serie.orientation, 6)
        // Fönstret 1,1 s till filens slut: klicket vid 1,0 s ligger utanför.
        let fonster = TimeWindow(start: 1.1, end: serie.duration)

        // 1. Bilden: markören i bufferten ligger där SwingLabKit säger i den upprätta bilden.
        let m = Self.markor
        let iBuffert = CropRect(x: Double(m.x) / 480, y: Double(m.y) / 270, width: Double(m.width) / 480,
                                height: Double(m.height) / 270)
        let ratt = Orientation.uprightRect(iBuffert, exif: 6)
        let fel8 = Orientation.uprightRect(iBuffert, exif: 8)
        let uppratt = try await ruta(film, t: 0.5, maxSize: CGSize(width: 270, height: 480))
        XCTAssertEqual(uppratt.width, 270)
        XCTAssertEqual(uppratt.height, 480)
        let iRatt = try ljus(uppratt, x: ratt.midX, y: ratt.midY)
        let iFel8 = try ljus(uppratt, x: fel8.midX, y: fel8.midY)
        let utanVridning = try ljus(uppratt, x: iBuffert.midX, y: iBuffert.midY)
        print("PROV: redigeraren markören: EXIF 6 → (\(f3(ratt.midX)), \(f3(ratt.midY))) ljus \(f3(iRatt)), "
              + "som EXIF 8 \(f3(iFel8)), utan vridning \(f3(utanVridning))")
        XCTAssertGreaterThan(iRatt, 0.85, "markören där Orientation.uprightRect säger")
        XCTAssertLessThan(iFel8, 0.6)
        XCTAssertLessThan(utanVridning, 0.6)

        // 2. Redigeraren före: hela filen och hela bilden.
        let stillbild = try await ruta(film, t: 2.0, maxSize: CGSize(width: 270, height: 480))
        try rita(EditorContent(surface: Image(decorative: stillbild, scale: 1).resizable(), uprightWidth: 270,
                               uprightHeight: 480, duration: serie.duration, clicks: serie.clicks,
                               window: serie.activeWindow, crop: .constant(.full), current: 2.0, playing: false),
                 "redigerare-hel")

        // 3. Done: fönstret och utsnittet sparas i passet, och redigeraren efter.
        let sparat = try XCTUnwrap(try store.saveEdit(SeriesEdit(window: fonster, crop: Self.utsnitt),
                                                       series: 1, in: pass.id))
        XCTAssertEqual(sparat.series[0].edit, SeriesEdit(window: fonster, crop: Self.utsnitt))
        try rita(EditorContent(surface: Image(decorative: stillbild, scale: 1).resizable(), uprightWidth: 270,
                               uprightHeight: 480, duration: serie.duration, clicks: serie.clicks,
                               window: fonster, crop: .constant(Self.utsnitt), current: 2.0, playing: false),
                 "redigerare")

        // 4. Omstart: en ny Store på samma mapp läser samma redigering; pass.json bär
        // manifestets namn.
        let omstart = Store(root: rot, exportFolder: rot.appending(path: "Export"))
        let last = try XCTUnwrap(omstart.load(pass.id))
        XCTAssertEqual(last.series[0].edit, SeriesEdit(window: fonster, crop: Self.utsnitt))
        let json = try String(contentsOf: omstart.passFolder(pass.id).appending(path: "pass.json"), encoding: .utf8)
        for nyckel in ["\"fonster\"", "\"fran_s\"", "\"till_s\"", "\"utsnitt\"", "\"b\"", "\"h\""] {
            XCTAssertTrue(json.contains(nyckel), "\(nyckel) i pass.json")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: film.path), "originalet finns kvar")
        let rutorNu = try await MediaReader.frameTimes(film).count
        XCTAssertEqual(rutorNu, serie.timing.count, "originalet oförändrat")

        // 5. Analysen med påhittade leder i rutan.
        let kalla = UtsnittKalla(DemoPoseSource(swingClicks: [klick[1]], allClicks: klick))
        let analys = Analysis()
        let svar = await analys.run(passID: pass.id, store: omstart, source: kalla)
        let klar = try XCTUnwrap(svar)
        XCTAssertNil(analys.problem)
        print("PROV: redigeraren analysen: slag \(klar.shots.map { "\($0.id) \(f3($0.click.time)) \($0.verdict.map { "\($0)" } ?? "-")" }), "
              + "frågor \(kalla.requests.map { "\(f3($0.from))–\(f3($0.to))" })")
        XCTAssertEqual(klar.shots.count, 1, "klicket vid 1,0 s ligger utanför fönstret")
        let s1 = try XCTUnwrap(klar.shots.first)
        XCTAssertEqual(s1.click.time, klick[1], accuracy: 1e-9)
        XCTAssertEqual(s1.verdict, .swing)
        XCTAssertFalse(kalla.requests.isEmpty)
        for r in kalla.requests {
            XCTAssertEqual(r.crop, Self.utsnitt, "Vision letar i rutan")
            XCTAssertGreaterThanOrEqual(r.from, fonster.start - 1e-9, "inget före fönstret")
            XCTAssertLessThanOrEqual(r.to, fonster.end + 1e-9)
        }
        let leder = try XCTUnwrap(omstart.joints(try XCTUnwrap(s1.joints), in: pass.id))
        // Rutan som skars ut, på hela pixlar (avrundad utåt).
        let skuren = Self.utsnitt.snapped(width: 270, height: 480)
        let px = (x0: skuren.x * 270, x1: skuren.maxX * 270, y0: skuren.y * 480, y1: skuren.maxY * 480)
        var utanfor = 0, saknadeHander = 0
        for f in leder.frames {
            for j in f.joints.compactMap({ $0 }) where j.x < px.x0 - 0.1 || j.x > px.x1 + 0.1 || j.y < px.y0 - 0.1
                || j.y > px.y1 + 0.1 {
                utanfor += 1
            }
            if f.joints[0] != nil && f.joints[JointSeries.names.firstIndex(of: "handled_v")!] == nil { saknadeHander += 1 }
        }
        print("PROV: redigeraren lederna: \(leder.frames.count) rutor, \(utanfor) leder utanför rutan, "
              + "\(saknadeHander) rutor där händerna lämnat rutan, höfterna x \(f3(leder.frames.first?.hipMid?.x ?? .nan)) px")
        XCTAssertEqual(utanfor, 0, "inga leder utanför rutan")
        XCTAssertGreaterThan(saknadeHander, 0, "händerna efter träffen går ut ur rutan och sparas som saknade")
        XCTAssertTrue(leder.frames.filter { $0.confidence > 0 }.allSatisfy { abs(($0.hipMid?.x ?? 0) - 135) < 0.2 },
                      "spelaren, i hela bildens pixlar")
        XCTAssertGreaterThanOrEqual(leder.frames.first?.pts ?? 0, fonster.start - 1e-4)
        XCTAssertEqual(s1.clipStart ?? .nan, fonster.start, accuracy: 1e-9, "klippet börjar vid fönstret")
        XCTAssertEqual(s1.clickInClip ?? .nan, klick[1] - fonster.start, accuracy: 0.002)
        XCTAssertEqual(klar.status, .analyzed)

        // 6. Appens Vision-körning skär ut rutan ur varje ruta: bilden Vision får är den
        // upprätta rutan med origo i (0, 0), och markören ligger där den ska i den. Utsnittet
        // (0,5; 0; 0,5; 0,5) tar markören uppe till höger, så att ett fel i vridningen eller i
        // Core Images y (nerifrån) flyttar den ut ur bilden eller till fel höjd.
        let logg = BildLogg()
        let vision = VisionPoseSource(makeDetect: { () -> VisionPoseSource.Detect in
            { input in
                logg.add(input)
                return []
            }
        })
        let markorRuta = CropRect(x: 0.5, y: 0, width: 0.5, height: 0.5)
        _ = try await vision.scan(PoseScanRequest(file: film, from: 0.4, to: 0.6, stride: 1, exif: 6, uprightWidth: 270,
                                                  uprightHeight: 480, crop: markorRuta)) { _ in }
        let utskurna = logg.images
        XCTAssertFalse(utskurna.isEmpty, "rutorna nådde Vision som utskurna bilder")
        XCTAssertEqual(logg.buffers, 0, "med utsnitt aldrig hela bufferten")
        let ci = try XCTUnwrap(utskurna.first)
        XCTAssertEqual(ci.extent.origin, .zero, "bilden börjar i origo")
        XCTAssertEqual(ci.extent.width, 135)
        XCTAssertEqual(ci.extent.height, 240)
        let cg = try XCTUnwrap(CIContext().createCGImage(ci, from: ci.extent))
        let iRutan = markorRuta.local(x: ratt.midX, y: ratt.midY)
        let paMarkoren = try ljus(cg, x: iRutan.x, y: iRutan.y)
        let speglad = try ljus(cg, x: iRutan.x, y: 1 - iRutan.y)
        let under = try ljus(cg, x: iRutan.x, y: 0.85)
        print("PROV: redigeraren utskurna rutan \(cg.width)×\(cg.height) från origo \(ci.extent.origin), markören vid "
              + "(\(f3(iRutan.x)), \(f3(iRutan.y))) ljus \(f3(paMarkoren)), y speglat \(f3(speglad)), nedanför \(f3(under))")
        XCTAssertGreaterThan(paMarkoren, 0.85, "markören i den utskurna bilden där rutan säger")
        XCTAssertLessThan(speglad, 0.6, "Core Images y är vänt rätt")
        XCTAssertLessThan(under, 0.6)
        try FileManager.default.createDirectory(atPath: Self.ut, withIntermediateDirectories: true)
        try XCTUnwrap(UIImage(cgImage: cg).pngData()).write(to: URL(fileURLWithPath: "\(Self.ut)/redigering-utskuren.png"))
        // Rutan som punkterna förs tillbaka genom är den utskurna på hela pixlar.
        let buffert = try await forstaBufferten(film, t: 0.5)
        let cut = VisionPoseSource.cutOut(try XCTUnwrap(buffert), orientation: .right, crop: Self.utsnitt)
        XCTAssertEqual(cut.image.extent.width, 212)
        XCTAssertEqual(cut.image.extent.height, 336)
        XCTAssertEqual(cut.crop, Self.utsnitt.snapped(width: 270, height: 480))
        // Utan utsnitt: rutan som den är, med orienteringen (vägen från S2e).
        _ = try await vision.scan(PoseScanRequest(file: film, from: 0.4, to: 0.5, stride: 1, exif: 6, uprightWidth: 270,
                                                  uprightHeight: 480)) { _ in }
        XCTAssertGreaterThan(logg.buffers, 0, "utan utsnitt går bufferten till Vision")
        XCTAssertEqual(logg.images.count, utskurna.count)

        // 7. Miniatyren visar utsnittet, med linjerna i rutans koordinater.
        let miniatyr = try await ShotImages.impactFrame(pass: klar, shot: s1, store: omstart)
        let bild = try XCTUnwrap(miniatyr)
        let o = try XCTUnwrap(ShotImages.overlay(shot: s1, pass: klar, store: omstart))
        print("PROV: redigeraren miniatyren \(bild.width)×\(bild.height), axlarna \(o.shoulders.map { "(\(f3($0.x)), \(f3($0.y)))" })")
        XCTAssertEqual(bild.width, 212)
        XCTAssertEqual(bild.height, 336)
        XCTAssertTrue((o.shoulders + o.hips).allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
        try rita(ShotsContent(pass: klar, images: [s1.id: bild], overlays: [s1.id: o], analysis: AnalysisState(),
                              editable: false).padding(20), "redigering-slag")
        let tumme = ImpactThumb(image: bild, overlay: o).frame(width: 212, height: 336)
        let tr = ImageRenderer(content: tumme)
        tr.scale = 1
        try XCTUnwrap(tr.uiImage?.pngData()).write(to: URL(fileURLWithPath: "\(Self.ut)/redigering-traff.png"))

        // 8. Hela bilden igen: slaget görs om, lederna och klippet tas bort från disken.
        let ledfil = omstart.url(try XCTUnwrap(s1.joints), in: pass.id)
        let klippfil = omstart.url(try XCTUnwrap(s1.clip), in: pass.id)
        let om = try XCTUnwrap(try omstart.saveEdit(SeriesEdit(window: fonster, crop: .full), series: 1,
                                                    in: pass.id))
        XCTAssertNil(om.shots[0].joints)
        XCTAssertNil(om.shots[0].clip)
        XCTAssertEqual(om.status, .recorded)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ledfil.path), "lederna borttagna")
        XCTAssertFalse(FileManager.default.fileExists(atPath: klippfil.path), "klippet borttaget")
        XCTAssertTrue(FileManager.default.fileExists(atPath: film.path), "originalet kvar")
    }

    // MARK: Hjälp

    /// Bilderna som nådde Vision-anropet: utskurna bilder och hela buffertar.
    final class BildLogg: @unchecked Sendable {
        private let lock = NSLock()
        private var bilder: [CIImage] = []
        private var antal = 0
        var images: [CIImage] { lock.withLock { bilder } }
        var buffers: Int { lock.withLock { antal } }
        func add(_ input: VisionPoseSource.Input) {
            lock.withLock {
                switch input {
                case .image(let i): bilder.append(i)
                case .buffer: antal += 1
                }
            }
        }
    }

    /// Den lagrade bufferten för rutan närmast t (BGRA), som Vision-körningen läser den.
    private func forstaBufferten(_ url: URL, t: Double) async throws -> CVPixelBuffer? {
        let asset = AVURLAsset(url: url)
        let spar = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(spar.first)
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(start: CMTime(seconds: t, preferredTimescale: 48_000),
                                       duration: CMTime(seconds: 0.1, preferredTimescale: 48_000))
        let out = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        ])
        reader.add(out)
        XCTAssertTrue(reader.startReading())
        while let sb = out.copyNextSampleBuffer() {
            if let pb = CMSampleBufferGetImageBuffer(sb) { return pb }
        }
        return nil
    }

    private func f3(_ x: Double) -> String { String(format: "%.3f", x) }

    /// Den upprätta rutan vid t (transformen tillämpad), som miniatyren läser den.
    private func ruta(_ url: URL, t: Double, maxSize: CGSize) async throws -> CGImage {
        let g = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        g.appliesPreferredTrackTransform = true
        g.requestedTimeToleranceBefore = .zero
        g.requestedTimeToleranceAfter = .zero
        g.maximumSize = maxSize
        return try await g.image(at: CMTime(seconds: t, preferredTimescale: 48_000)).image
    }

    /// Ljusheten 0…1 i en punkt, som andel av bildens bredd och höjd (origo uppe till vänster).
    private func ljus(_ cg: CGImage, x: Double, y: Double) throws -> Double {
        let px = min(cg.width - 1, max(0, Int(Double(cg.width) * x)))
        let py = min(cg.height - 1, max(0, Int(Double(cg.height) * y)))
        var rgba = [UInt8](repeating: 0, count: 4)
        let ritat = rgba.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                                      bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: -px, y: -(cg.height - 1 - py), width: cg.width, height: cg.height))
            return true
        }
        XCTAssertTrue(ritat)
        return (Double(rgba[0]) + Double(rgba[1]) + Double(rgba[2])) / (3 * 255)
    }

    /// En vy i telefonens storlek, mörk, till /tmp/swinglab_prov/<namn>.png.
    private func rita<V: View>(_ innehall: V, _ namn: String) throws {
        let vy = innehall
            .frame(width: 390, height: 780, alignment: .top)
            .background(Theme.ground)
            .environment(\.colorScheme, .dark)
        let r = ImageRenderer(content: vy)
        r.scale = 2
        let png = try XCTUnwrap(r.uiImage?.pngData(), "\(namn).png ritades inte")
        try FileManager.default.createDirectory(atPath: Self.ut, withIntermediateDirectories: true)
        try png.write(to: URL(fileURLWithPath: "\(Self.ut)/\(namn).png"))
    }
}
