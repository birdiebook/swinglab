// SIMULATORPROVET FÖR GRANSKNINGEN OCH PASSETS MÅTT (PLAN S4, S4b; BESLUT B35).
//
// Vad som bevisas här, på provets PÅHITTADE film och PÅHITTADE leder (SwingDemo; inga
// riktiga svingar, CLAUDE.md: Dataregeln):
//   lederna   en vit markör i filmen och en led på markörens koordinat hamnar på samma punkt
//             i granskningens yta, utan utsnitt och med två utsnitt (METOD MS13, MS15);
//   kedjan    appens analys med påhittade leder (FO-svingen, fyra slag med kända sway) ger
//             måtten i passet: Passet med riktig data, kortet för sway är medianen;
//   rutorna   granskningens rutnät är videons rutor: rutan vid klicket är den vita;
//   positioner P1–P10 hoppar till rutan närmast positionens tid, och måtten under videon är
//             slagets vid positionen;
//   märkningen "Detection wrong" tar bort slaget ur passets mått, sparas och går att ångra;
//   längden   en ny längd mäter om passet och skalar måtten i cm.
// Bilderna (passet-matt, granskning-video, granskning-video-p7, granskning-utan-leder,
// granskning-detection-wrong, passet-detection-wrong, granskning-markor) ritas med en
// stillbild ur filen som videoyta: AVPlayerLayer syns inte i simulatorns bilder (BESLUT B35).
// VISIONS LEDER PÅ EN RIKTIG SVING PROVAS BARA PÅ TELEFONEN.

import XCTest
import AVFoundation
import CoreGraphics
import SwiftUI
import UIKit
import Swing
import Capture
import SwingDemo
@testable import SwingLab

/// Påhittade leder i Visions ställe: FO-svingen ur SwingDemo kring varje klick, med sitt
/// eget sway vid toppen, på filens egna rutor i fönstret (halvöppet som läsaren).
final class SvingKalla: PoseSource, @unchecked Sendable {
    let klick: [Double]
    let sway: [Double]

    init(klick: [Double], sway: [Double]) {
        self.klick = klick
        self.sway = sway
    }

    func scan(_ r: PoseScanRequest, progress: @escaping @Sendable (Double) -> Void) async throws -> PoseScan {
        let tider = try await MediaReader.frameTimes(r.file).filter { $0 >= r.from - 1e-6 && $0 < r.to - 1e-6 }
        // Det täta fönstret börjar 2,5 s före klicket (METOD MS12).
        let mitt = r.from - SwingCheck.denseWindow.lowerBound
        let i = klick.indices.min { abs(klick[$0] - mitt) < abs(klick[$1] - mitt) } ?? 0
        var frames: [ScannedFrame] = []
        for (k, t) in tider.enumerated() where k % max(1, r.stride) == 0 {
            let leder = DemoSving.lederFO(t - klick[i], sway: (topp: sway[i], traff: 2, finish: 4),
                                          width: r.uprightWidth, height: r.uprightHeight)
            frames.append(ScannedFrame(pts: t, candidates: [PoseFrame(t: t, pts: t, joints: leder.map { Optional($0) },
                                                                      confidence: 0.9)]))
        }
        progress(1)
        return PoseScan(frames: frames, decodedFrames: tider.count, visionSeconds: 0.001 * Double(frames.count),
                        wallSeconds: 0.002 * Double(frames.count))
    }
}

@MainActor
final class SwingLabProvGranskning: XCTestCase {
    static let ut = "/tmp/swinglab_prov"
    /// Klicken i filmen och svingarnas sway vid toppen, cm.
    static let klick = [2.5, 6.0, 9.5, 13.0]
    static let sway = [-2.0, -4.0, -6.0, -9.0]
    /// Markören i den lagrade bufferten 480 × 270, px.
    static let markor = (x: 40, y: 20, width: 80, height: 60)

    func tmp(_ namn: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: "swinglab-prov", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: namn)
    }

    // MARK: Katalogen i appen

    /// Appen bär katalog.json (passets mått och positionerna), samma som repots.
    func testKatalogenIAppen() throws {
        let k = try XCTUnwrap(AppKatalog.katalog, "katalog.json saknas i appen")
        let rot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let repo = try Katalog.las(Data(contentsOf: rot.appendingPathComponent("katalog.json")))
        XCTAssertEqual(k.fel.map(\.id), repo.fel.map(\.id))
        XCTAssertEqual(k.matt.map(\.matt), repo.matt.map(\.matt))
    }

    // MARK: Lederna på bilden

    /// En led på markörens koordinat ritas där markören syns i bilden, utan och med utsnitt:
    /// ytan ritas en gång med bilden (markören) och en gång med bara leden, och de vita
    /// punkternas mitt jämförs. METOD MS13, MS15
    func testLedernaPaRattStalleIBilden() async throws {
        let film = try tmp("granskning-markor.mov")
        try await SyntheticMovie.write(to: film, sound: .lpcm, marker: Self.markor)
        let hel = try await ruta(film, t: 0.5)
        XCTAssertEqual(hel.width, 270)
        XCTAssertEqual(hel.height, 480)
        let m = Self.markor
        let iBuffert = CropRect(x: Double(m.x) / 480, y: Double(m.y) / 270, width: Double(m.width) / 480,
                                height: Double(m.height) / 270)
        let ratt = Orientation.uprightRect(iBuffert, exif: 6)
        let led = (x: ratt.midX * 270, y: ratt.midY * 480)
        var leder = [PoseJoint?](repeating: nil, count: 13)
        leder[0] = PoseJoint(x: led.x, y: led.y, c: 0.9)
        let serie = JointSeries(width: 270, height: 480, frames: [PoseFrame(t: 0, pts: 0.5, joints: leder, confidence: 0.9)])

        for (namn, utsnitt) in [("hel", nil), ("ruta", CropRect(x: 0.5, y: 0, width: 0.5, height: 0.5)),
                                ("sned", CropRect(x: 0.37, y: 0.03, width: 0.55, height: 0.33))] as [(String, CropRect?)] {
            let review = ShotReview(series: serie, crop: utsnitt)
            let bild = utsnitt.map { ShotImages.cropped(hel, $0) } ?? hel
            let bredd: CGFloat = 300, hojd = bredd / CGFloat(review.aspect)
            XCTAssertEqual(Double(bild.width) / Double(bild.height), review.aspect, accuracy: 1e-9, "bilden har ytans proportioner")
            let medBild = try rendera(ReviewStage(surface: Image(decorative: bild, scale: 1).resizable(),
                                                  overlay: review.overlay(0), overlayOn: false),
                                      bredd: bredd, hojd: hojd)
            let medLed = try rendera(ReviewStage(surface: Color.black, overlay: review.overlay(0), overlayOn: true),
                                     bredd: bredd, hojd: hojd)
            let a = try XCTUnwrap(vitMitt(medBild), "\(namn): markören syns inte")
            let b = try XCTUnwrap(vitMitt(medLed), "\(namn): leden syns inte")
            let p = try XCTUnwrap(review.overlay(0).points[0])
            let vantat = (x: p.x * Double(medLed.width), y: p.y * Double(medLed.height))
            print("PROV: granskningen \(namn): markören (\(f1(a.x)), \(f1(a.y))) px, leden (\(f1(b.x)), \(f1(b.y))) px, "
                  + "väntat (\(f1(vantat.x)), \(f1(vantat.y))) i \(medLed.width)×\(medLed.height)")
            XCTAssertEqual(a.x, b.x, accuracy: 3, "\(namn): leden i x där markören är")
            XCTAssertEqual(a.y, b.y, accuracy: 3, "\(namn): leden i y där markören är")
            XCTAssertEqual(b.x, vantat.x, accuracy: 2)
            XCTAssertEqual(b.y, vantat.y, accuracy: 2)
            if namn == "ruta" {
                // Bilden: leden som osäker (ihålig, svart inuti), så att den syns mot den vita markören.
                var svag = serie
                svag.frames[0].joints[0]?.c = 0.2
                let bada = try rendera(ReviewStage(surface: Image(decorative: bild, scale: 1).resizable(),
                                                   overlay: ShotReview(series: svag, crop: utsnitt).overlay(0),
                                                   overlayOn: true, time: "0.000 s"),
                                       bredd: bredd, hojd: hojd)
                try spara(bada, "granskning-markor")
            }
        }
    }

    // MARK: Kedjan, passet och granskningen

    func testGranskningenOchPassetsMatt() async throws {
        let rot = try tmp("granskning-\(UUID().uuidString)")
        let store = Store(root: rot, exportFolder: rot.appending(path: "Export"))
        var pass = store.newPass(setup: PassSetup(view: .fo, club: "j7", distance: 3, hand: .hoger),
                                 at: Date(timeIntervalSince1970: 1_792_848_612))
        let fil = PassState.videoPath(nr: 1)
        let film = store.url(fil, in: pass.id)
        try await SyntheticMovie.write(to: film, sound: .lpcm, seconds: 14.6, flashes: Self.klick)
        let serie = try await SeriesMaker.make(url: film, nr: 1, file: fil, source: .recording, club: "j7",
                                               start: pass.created, startHost: nil, microphone: nil)
        XCTAssertEqual(serie.clicks.count, 4, "fyra klick i filmen")
        for (c, k) in zip(serie.clicks.map(\.time), Self.klick) { XCTAssertEqual(c, k, accuracy: 0.01) }
        pass.series.append(serie)
        pass.syncShots()
        // Johannes dom på alla fyra: det glesa passet behövs inte, bara lederna och klippen.
        for s in pass.shots { pass.setVerdict(.swing, shot: s.id) }
        store.save(pass)

        // 1. Analysen ger måtten.
        let analys = Analysis()
        let svar = await analys.run(passID: pass.id, store: store,
                                    source: SvingKalla(klick: serie.clicks.map(\.time), sway: Self.sway))
        let klar = try XCTUnwrap(svar)
        XCTAssertNil(analys.problem)
        XCTAssertEqual(klar.status, .analyzed)
        let varden = klar.shots.map { $0.measure?.values["backen_sway_topp"] ?? .nan }
        print("PROV: granskningen måtten: sway \(varden.map(f2)), problem \(klar.shots.map { $0.measure?.problem ?? "-" }), "
              + "längd \(klar.measuredHeight.map { "\($0.heightM) antagen \($0.assumed)" } ?? "-")")
        XCTAssertTrue(klar.shots.allSatisfy { $0.measure?.ok == true }, "alla fyra mätta")
        for (v, s) in zip(varden, Self.sway) { XCTAssertEqual(v, s, accuracy: 0.5) }
        XCTAssertEqual(klar.measuredHeight?.assumed, true, "ingen längd angiven: antagen")
        XCTAssertEqual(klar.countedSwings.count, 4)

        // 2. Passet med riktig data: sway-kortet är medianen.
        let historik = await PassMeasures.load(klar, store: store)
        XCTAssertEqual(historik.pass, klar, "passet var redan mätt")
        XCTAssertEqual(historik.unmeasured, 0)
        let v = try XCTUnwrap(PassShotsView.visning(historik.pass, earlier: historik.earlier), "passet visar måtten")
        let kort = try XCTUnwrap(v.kort.first { $0.id == "sway_topp" })
        let median = Session.percentil(varden.sorted(), 0.5)
        XCTAssertEqual(kort.varde, Tal.tecken(Avrundning.avrunda("backen_sway_topp", median), decimaler: 1))
        XCTAssertEqual(v.undertitel, "7i\u{00A0}· 4")
        print("PROV: granskningen passet: sway \(kort.varde) \(kort.enhet), \(v.kort.filter { $0.varde != "—" }.count) kort med tal")
        var bilder: [String: CGImage] = [:]
        var linjer: [String: ImpactOverlay] = [:]
        for s in klar.shots {
            bilder[s.id] = try await ShotImages.impactFrame(pass: klar, shot: s, store: store)
            linjer[s.id] = ShotImages.overlay(shot: s, pass: klar, store: store)
        }
        try rita(PassScreenContent(pass: klar, visning: v, images: bilder, overlays: linjer, analysis: AnalysisState(),
                                   editable: false), "passet-matt")

        // 3. Granskningen av slag 4: rutnätet, positionerna och måtten under videon.
        let s4 = klar.shots[3]
        let serie4 = try XCTUnwrap(store.joints(try XCTUnwrap(s4.joints), in: klar.id))
        let review = ShotReview(series: serie4, crop: klar.series[0].activeCrop)
        let pos = review.positions(s4.measure)
        let m4 = try XCTUnwrap(s4.measure)
        print("PROV: granskningen positionerna: " + pos.map { p in
            "\(p.name) \(p.index.map { "ruta \($0) t \(f3(review.frames[$0].t)) mot \(f3(m4.positions[p.name] ?? .nan))" } ?? "saknas")"
        }.joined(separator: ", "))
        for p in pos {
            if let k = p.index {
                let t = try XCTUnwrap(m4.positions[p.name])
                XCTAssertEqual(review.frames[k].t, t, accuracy: 1.0 / 240 + 1e-6, "\(p.name): rutan närmast positionen")
            } else {
                XCTAssertNil(m4.positions[p.name])
            }
        }
        for p in ["P1", "P4", "P7", "P10"] {
            XCTAssertNotNil(pos.first { $0.name == p }?.index ?? nil, "\(p) finns alltid")
        }
        // Rutan vid klicket är filmens vita ruta, rutan före den grå: stegen är videons rutor.
        let kKlick = try XCTUnwrap(review.index(nearestT: 0))
        XCTAssertEqual(review.frames[kKlick].t, 0, accuracy: 1.0 / 480)
        let vit = try await XCTUnwrapAsync(try await ShotImages.frame(pass: klar, shot: s4, store: store,
                                                                       at: review.frames[kKlick].pts))
        let fore = try await XCTUnwrapAsync(try await ShotImages.frame(pass: klar, shot: s4, store: store,
                                                                        at: review.frames[kKlick - 1].pts))
        let ljusVit = try ljus(vit, x: 0.1, y: 0.9), ljusFore = try ljus(fore, x: 0.1, y: 0.9)
        print("PROV: granskningen rutan vid klicket ljus \(f3(ljusVit)), rutan före \(f3(ljusFore))")
        XCTAssertGreaterThan(ljusVit, 0.85)
        XCTAssertLessThan(ljusFore, 0.6)

        let k4 = try XCTUnwrap(pos.first { $0.name == "P4" }?.index ?? nil)
        let o = review.overlay(k4)
        XCTAssertEqual(o.points.compactMap { $0 }.count, 13, "alla 13 leder vid toppen")
        XCTAssertEqual(o.lines.count, ShotReview.bones.count)
        let rader = ReviewRows.rows(pass: klar, shot: s4, position: "P4", baseline: [:])
        XCTAssertEqual(rader.first?.matt, "backen_sway_topp")
        XCTAssertEqual(rader.first?.varde, Tal.tecken(Avrundning.avrunda("backen_sway_topp", m4.values["backen_sway_topp"]),
                                                      decimaler: 1))
        let stillP4 = try await XCTUnwrapAsync(try await ShotImages.frame(pass: klar, shot: s4, store: store,
                                                                           at: review.frames[k4].pts))
        func granskning(_ k: Int, _ position: String, overlayOn: Bool = true, wrong: Bool = false,
                        still: CGImage, spar: [SparPunkt]? = nil) -> ReviewContent<Image> {
            ReviewContent(surface: Image(decorative: still, scale: 1).resizable(), review: review, number: 4, frame: k,
                          overlayOn: overlayOn, position: position, positions: pos,
                          rows: ReviewRows.rows(pass: klar, shot: s4, position: position, baseline: [:]),
                          detectionWrong: wrong, impact: s4.impact - s4.click.time,
                          spar: spar.map { SparBild(serier: review.spar($0), bredd: review.width, hojd: review.height,
                                                    crop: review.crop) }, sparVal: Set(spar ?? []),
                          onSpar: spar == nil ? nil : { _ in }, editable: false)
        }
        try rita(granskning(k4, "P4", still: stillP4), "granskning-video")
        try rita(granskning(k4, "P4", overlayOn: false, still: stillP4), "granskning-utan-leder")
        let k7 = try XCTUnwrap(pos.first { $0.name == "P7" }?.index ?? nil)
        let stillP7 = try await XCTUnwrapAsync(try await ShotImages.frame(pass: klar, shot: s4, store: store,
                                                                           at: review.frames[k7].pts))
        try rita(granskning(k7, "P7", still: stillP7), "granskning-video-p7")
        XCTAssertTrue(ReviewRows.rows(pass: klar, shot: s4, position: "P7", baseline: [:])
            .contains { $0.matt == "sway_gap_traff" })

        // 3b. Spåren (S4f, BESLUT B70, METOD M60): händerna vid toppen, och alla fyra vid träffen.
        let alla: [SparPunkt] = [.hands, .shoulders, .hips, .head]
        let spar = review.spar(alla)
        XCTAssertEqual(spar.map(\.id), ["hands", "shoulders_v", "shoulders_h", "hips_v", "hips_h", "head"])
        let hander = spar[0]
        XCTAssertEqual(hander.t.count, review.frames.count, "en punkt per ruta")
        XCTAssertTrue(hander.p.allSatisfy(\.hel), "den påhittade svingen har händerna i varje ruta")
        let d4 = hander.delar(nu: review.frames[k4].t)
        XCTAssertEqual(d4.map(\.spelad), [true, false], "spelat fram till toppen, resten svagt")
        // Händernas spår går genom handledernas mitt i rutan (utjämnat högst några px).
        let o4 = review.overlay(k4)
        let mitt = try XCTUnwrap(hander.punkt(nu: review.frames[k4].t))
        let hv = try XCTUnwrap(review.frames[k4].joints[5]), hh = try XCTUnwrap(review.frames[k4].joints[6])
        print("PROV: spåren vid P4: händerna (\(f1(mitt.x)), \(f1(mitt.y))) mot handledernas mitt "
              + "(\(f1((hv.x + hh.x) / 2)), \(f1((hv.y + hh.y) / 2))), \(d4.map { $0.punkter.count }) punkter, "
              + "\(o4.points.compactMap { $0 }.count) leder")
        XCTAssertEqual(mitt.x, (hv.x + hh.x) / 2, accuracy: 3)
        XCTAssertEqual(mitt.y, (hv.y + hh.y) / 2, accuracy: 3)
        try rita(granskning(k4, "P4", still: stillP4, spar: [.hands]), "granskning-spar-p4")
        try rita(granskning(k7, "P7", overlayOn: false, still: stillP7, spar: alla), "granskning-spar-p7")

        // 4. "Detection wrong" på slag 4 (−9 cm): passet räknar tre, sparat; ångra ger fyra.
        var p = try XCTUnwrap(store.load(klar.id))
        p.setDetectionWrong(true, shot: s4.id)
        store.save(p)
        let utan = store.measured(try XCTUnwrap(store.load(klar.id)))
        XCTAssertEqual(utan.shots[3].detectionWrong, true, "märkningen står i pass.json")
        XCTAssertEqual(utan.countedSwings.count, 3)
        let v2 = try XCTUnwrap(PassShotsView.visning(utan, earlier: []))
        let kort2 = try XCTUnwrap(v2.kort.first { $0.id == "sway_topp" })
        let median3 = Session.percentil(Array(varden.prefix(3)).sorted(), 0.5)
        print("PROV: granskningen Detection wrong: sway \(kort.varde) → \(kort2.varde), slag \(v.undertitel) → \(v2.undertitel)")
        XCTAssertEqual(kort2.varde, Tal.tecken(Avrundning.avrunda("backen_sway_topp", median3), decimaler: 1))
        XCTAssertNotEqual(kort2.varde, kort.varde, "slaget togs bort ur passets mått")
        XCTAssertEqual(v2.undertitel, "7i\u{00A0}· 3")
        try rita(PassScreenContent(pass: utan, visning: v2, images: bilder, overlays: linjer, analysis: AnalysisState(),
                                   editable: false), "passet-detection-wrong")
        try rita(granskning(k4, "P4", wrong: true, still: stillP4), "granskning-detection-wrong")
        p = try XCTUnwrap(store.load(klar.id))
        p.setDetectionWrong(false, shot: s4.id)
        store.save(p)
        XCTAssertEqual(try XCTUnwrap(store.load(klar.id)).countedSwings.count, 4, "ångrat")

        // 5. Passets längd: 1,90 m mäter om passet (utanför huvudtråden), sparar och skalar
        // måtten i cm; Jag rörs inte (METOD MS16).
        store.setPassHeight(1.90, passID: klar.id)
        let lang = await PassMeasures.load(try XCTUnwrap(store.load(klar.id)), store: store).pass
        XCTAssertEqual(store.load(klar.id), lang, "de nya måtten är sparade")
        XCTAssertEqual(lang.measuredHeight?.heightM, 1.90)
        XCTAssertEqual(lang.measuredHeight?.assumed, false)
        let nya = lang.shots.map { $0.measure?.values["backen_sway_topp"] ?? .nan }
        XCTAssertEqual(nya[0] / varden[0], 1.90 / 1.80, accuracy: 1e-6)
        XCTAssertEqual(Store(root: rot, exportFolder: rot.appending(path: "Export")).load(klar.id)?.heightM, 1.90, "sparad")
        XCTAssertNil(store.settings.heightM, "Jag rörs inte av passets längd")
    }

    // MARK: Hjälp

    private func XCTUnwrapAsync<T>(_ v: T?) async throws -> T { try XCTUnwrap(v) }

    private func ruta(_ url: URL, t: Double) async throws -> CGImage {
        let g = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        g.appliesPreferredTrackTransform = true
        g.requestedTimeToleranceBefore = .zero
        g.requestedTimeToleranceAfter = .zero
        g.maximumSize = CGSize(width: 270, height: 480)
        return try await g.image(at: CMTime(seconds: t, preferredTimescale: 48_000)).image
    }

    private func rendera<V: View>(_ vy: V, bredd: CGFloat, hojd: CGFloat) throws -> CGImage {
        let r = ImageRenderer(content: vy.frame(width: bredd, height: hojd).environment(\.colorScheme, .dark))
        r.scale = 2
        return try XCTUnwrap(r.cgImage, "ytan ritades inte")
    }

    /// Mitten av de vita punkterna (ljushet > 0,8), px; nil utan sådana.
    private func vitMitt(_ cg: CGImage) -> (x: Double, y: Double)? {
        let w = cg.width, h = cg.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let ritat = px.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ritat else { return nil }
        var sx = 0.0, sy = 0.0, n = 0.0
        for y in 0..<h {
            for x in 0..<w {
                let i = (y * w + x) * 4
                let l = (Double(px[i]) + Double(px[i + 1]) + Double(px[i + 2])) / (3 * 255)
                if l > 0.8 {
                    sx += Double(x) + 0.5
                    sy += Double(y) + 0.5
                    n += 1
                }
            }
        }
        return n > 0 ? (sx / n, sy / n) : nil
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

    private func spara(_ cg: CGImage, _ namn: String) throws {
        try FileManager.default.createDirectory(atPath: Self.ut, withIntermediateDirectories: true)
        try XCTUnwrap(UIImage(cgImage: cg).pngData()).write(to: URL(fileURLWithPath: "\(Self.ut)/\(namn).png"))
    }

    /// En vy i telefonens bredd, mörk, i full längd, till /tmp/swinglab_prov/<namn>.png.
    private func rita<V: View>(_ innehall: V, _ namn: String) throws {
        let vy = innehall
            .frame(width: 390)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 16)
            .background(Theme.ground)
            .environment(\.colorScheme, .dark)
        let r = ImageRenderer(content: vy)
        r.scale = 2
        r.proposedSize = ProposedViewSize(width: 390, height: nil)
        let png = try XCTUnwrap(r.uiImage?.pngData(), "\(namn).png ritades inte")
        try FileManager.default.createDirectory(atPath: Self.ut, withIntermediateDirectories: true)
        try png.write(to: URL(fileURLWithPath: "\(Self.ut)/\(namn).png"))
        print("PROV: skrev \(namn).png")
    }

    private func f1(_ x: Double) -> String { String(format: "%.1f", x) }
    private func f2(_ x: Double) -> String { String(format: "%.2f", x) }
    private func f3(_ x: Double) -> String { String(format: "%.3f", x) }
}
