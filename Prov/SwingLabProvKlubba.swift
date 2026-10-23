// SIMULATORPROVET FÖR KLUBBANS MÄRKNING (PLAN S7a, BESLUT B47, METOD M45–M49).
//
// Vad som bevisas här, på provets PÅHITTADE film och PÅHITTADE leder (SwingDemo:s DTL-sving;
// inga riktiga svingar, CLAUDE.md: Dataregeln):
//   märkningen  P1–P10 genom appens egen logik (ClubMarking): ett tryck nära kanten blir ingen
//               punkt, greppet och hoseln per position med tryck på ytan, en flytt och ett
//               ångra, P8 hoppad; sparat i pass.json och läst tillbaka;
//   måtten      slaget mäts om: skaftets vinkel vid positionerna är den satta, skaftplanet vid
//               P1, och P2 och P6 är rutorna som valdes;
//   bilderna    granskningen med skaftlinjen (klubba-granskning), märkningsläget med
//               förstoringsglaset under fingret (klubba-markera) och passet med antalet
//               markerade svingar och klubbmåttens kort (klubba-passet).
// Kontraktet med PC:n (klubba.json i paketet) prövas i SwingLabProvPaket. TRYCKEN MED ETT
// RIKTIGT FINGER PÅ EN RIKTIG SVING PROVAS BARA PÅ TELEFONEN.

import XCTest
import AVFoundation
import CoreGraphics
import SwiftUI
import UIKit
import Swing
import Capture
import SwingDemo
@testable import SwingLab

@MainActor
final class SwingLabProvKlubba: XCTestCase {
    static let ut = "/tmp/swinglab_prov"
    static let klick = [2.5, 6.0]
    /// Satta skaft per position: vinkeln grepp → hosel (grader, y uppåt) och längden i px i
    /// bilden 270 × 480. P8 hoppas över (klubban syns inte).
    static let satta: [String: (Double, Double)] = [
        "P1": (-60, 100), "P2": (-35, 90), "P3": (100, 90), "P4": (-75, 90), "P5": (95, 90),
        "P6": (60, 110), "P7": (-58, 95), "P9": (110, 90), "P10": (170, 80)]

    func tmp(_ namn: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: "swinglab-prov", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: namn)
    }

    func testMarkeraKlubban() async throws {
        let rot = try tmp("klubba-\(UUID().uuidString)")
        let store = Store(root: rot, exportFolder: rot.appending(path: "Export"))
        var pass = store.newPass(setup: PassSetup(view: .dtl, club: "j7", distance: 3, hand: .hoger),
                                 at: Date(timeIntervalSince1970: 1_792_848_612))
        let fil = PassState.videoPath(nr: 1)
        let film = store.url(fil, in: pass.id)
        try await SyntheticMovie.write(to: film, sound: .lpcm, seconds: 8.2, flashes: Self.klick)
        let serie = try await SeriesMaker.make(url: film, nr: 1, file: fil, source: .recording, club: "j7",
                                               start: pass.created, startHost: nil, microphone: nil)
        XCTAssertEqual(serie.clicks.count, 2)
        pass.series.append(serie)
        pass.syncShots()
        var leder: [String: JointSeries] = [:]
        for i in pass.shots.indices {
            let s = pass.shots[i]
            pass.shots[i].verdict = .swing
            let sv = DemoSving.dtl(thrust: (-2, 3, 8))
            let j = SwingLabProvPaket.leder(sv, klick: s.click.time, ljudet: pass.setup.soundDelay,
                                            width: serie.uprightWidth, height: serie.uprightHeight)
            leder[s.id] = j
            pass.shots[i].joints = try store.writeJoints(j, shot: s.id, in: pass.id)
            pass.shots[i].jointFrames = j.frames.count
        }
        store.save(pass)
        pass = store.measured(try XCTUnwrap(store.load(pass.id)))
        XCTAssertTrue(pass.shots.allSatisfy { $0.measure?.ok == true }, "båda mätta")

        // 1. Märkningen av slag 1 genom ClubMarking, med tryck på ytan.
        let s1 = pass.shots[0]
        let j1 = try XCTUnwrap(leder[s1.id])
        let review = ShotReview(series: j1, crop: serie.activeCrop)
        var m = ClubMarking(existing: s1.klubba, width: review.width, height: review.height, crop: serie.activeCrop)
        XCTAssertEqual(m.position, "P1")
        var satt: [String: (grip: KlubbPunkt, t: Double)] = [:]
        var tryck = 0
        while !m.done {
            let p = m.position
            let k = try XCTUnwrap(review.index(nearestT: m.shownTime(measure: s1.measure, impact: s1.impact - s1.click.time)))
            let tk = review.frames[k].t
            if p == "P1" {
                XCTAssertFalse(m.tap(u: 0.01, v: 0.5, t: tk), "nära kanten: ingen punkt")
                XCTAssertFalse(m.tap(u: 0.5, v: 1.2, t: tk), "utanför bilden: ingen punkt")
            }
            guard let vl = Self.satta[p] else {
                m.skip(t: tk)
                tryck += 1
                continue
            }
            let (vinkel, langd) = vl
            let f = review.frames[k].joints
            let h = [f[5], f[6]].compactMap { $0 }
            let ring = KlubbPunkt(x: h.map(\.x).reduce(0, +) / Double(h.count), y: h.map(\.y).reduce(0, +) / Double(h.count))
            // P1: greppet ur ringen (ett tryck på den); övriga ett fritt tryck bredvid handlederna.
            let g = p == "P1" ? ring : KlubbPunkt(x: ring.x + 20, y: ring.y - 1)   // utanför ringen
            let hosel = KlubbPunkt(x: g.x + langd * cos(vinkel * .pi / 180), y: g.y - langd * sin(vinkel * .pi / 180))
            let ug = m.surfacePoint(g), uh = m.surfacePoint(hosel)
            XCTAssertTrue(m.tap(u: ug.u, v: ug.v, t: tk, ring: ring), "\(p): greppet")
            XCTAssertEqual(m.gripSource, p == "P1" ? Klubba.kallaRing : Klubba.kalla, p)
            if k + 1 < review.frames.count {
                XCTAssertFalse(m.tap(u: uh.u, v: uh.v, t: review.frames[k + 1].t), "\(p): hoseln på en annan ruta")
            }
            XCTAssertTrue(m.tap(u: uh.u, v: uh.v, t: tk), "\(p): hoseln")
            XCTAssertTrue(m.done || m.position != p, "\(p): sparad av sig själv")
            tryck += 2
            satt[p] = (g, tk)
        }
        // En flytt på en sparad position: P4 laddas, hoseln dras och ångras.
        m.go(to: "P4")
        let h4 = try XCTUnwrap(m.hosel)
        let u4 = m.surfacePoint(h4)
        XCTAssertEqual(m.grab(u: u4.u + 0.01, v: u4.v), .hosel)
        XCTAssertTrue(m.move(.hosel, u: u4.u + 0.05, v: u4.v))
        m.undo()
        XCTAssertEqual(m.marks["P4"]?.hosel, h4)
        m.undo()
        XCTAssertTrue(m.done)
        print("PROV: klubban: \(tryck) tryck för P1–P10 utan steg (P8 hoppad), ringen vid P1")
        XCTAssertEqual(m.result.map(\.position), Klubba.positioner)
        XCTAssertEqual(m.result.first { $0.position == "P8" }?.hoppad, true)
        XCTAssertEqual(m.result.first?.greppKalla, Klubba.kallaRing)
        pass.setClubMarks(m.result, shot: s1.id, joints: j1)
        store.save(pass)
        let last = try XCTUnwrap(store.load(pass.id))
        XCTAssertEqual(last.shots[0].klubba, m.result, "markeringarna står i pass.json")
        XCTAssertEqual(last.clubMarkedCount, 1)

        // 2. Måtten ur markeringarna (METOD M46, M47) och P2/P6 som rutorna som valdes.
        let mv = try XCTUnwrap(last.shots[0].measure)
        for (p, (vinkel, _)) in Self.satta {
            XCTAssertEqual(mv.values[Klubba.nyckel("skaft_vinkel", p)] ?? .nan, vinkel, accuracy: 0.01, p)
        }
        XCTAssertEqual(mv.values["skaftplan_p1"] ?? .nan, 60, accuracy: 0.01)
        XCTAssertNil(mv.values["skaft_mot_plan_p2"], "borttaget (METOD M47)")
        XCTAssertEqual(mv.klubbaFlyktpunktAntagen, true)
        // P6 mot planet: bara hoslarnas avstånd spärrar (METOD M47).
        XCTAssertNotNil(mv.values["skaft_plan_p6"])
        XCTAssertEqual(mv.positions["P2"] ?? .nan, satt["P2"]?.t ?? 0, accuracy: 1e-9)
        XCTAssertEqual(mv.positions["P6"] ?? .nan, satt["P6"]?.t ?? 0, accuracy: 1e-9)
        XCTAssertNil(mv.positions["P8"], "P8 hoppades över")
        print("PROV: klubban P1–P10: " + Klubba.positioner.map { p in
            "\(p) \(mv.values[Klubba.nyckel("skaft_vinkel", p)].map { String(format: "%.2f", $0) } ?? "–")"
        }.joined(separator: ", ") + String(format: "; skaftplan %.2f, P6 mot planet %.2f",
                                           mv.values["skaftplan_p1"] ?? .nan, mv.values["skaft_plan_p6"] ?? .nan))

        // 3. Granskningen vid P1 med skaftlinjen och klubbmåtten under videon.
        let pos = review.positions(mv)
        let k1 = try XCTUnwrap(pos.first { $0.name == "P1" }?.index ?? nil)
        XCTAssertNotNil(pos.first { $0.name == "P2" }?.index ?? nil, "P2 går att välja")
        XCTAssertNil(pos.first { $0.name == "P8" }?.index ?? nil, "P8 går inte")
        let shaft = try XCTUnwrap(review.shaft(k1, marks: last.shots[0].klubba), "skaftlinjen i rutan")
        let rader = ReviewRows.rows(pass: last, shot: last.shots[0], position: "P1", baseline: [:])
        XCTAssertTrue(rader.contains { $0.matt == "skaftplan_p1" && $0.varde == "60.0" })
        XCTAssertTrue(rader.contains { $0.matt == "skaft_vinkel_p1" && $0.varde == "−60.0" })
        let still1 = try await XCTUnwrapAsync(try await ShotImages.frame(pass: last, shot: last.shots[0], store: store,
                                                                          at: review.frames[k1].pts))
        try rita(ReviewContent(surface: Image(decorative: still1, scale: 1).resizable(), review: review, number: 1,
                               frame: k1, position: "P1", positions: pos, rows: rader, impact: s1.impact - s1.click.time,
                               shaft: shaft, editable: false), "klubba-granskning")

        // 4. Märkningsläget för slag 2 vid P4: greppet satt, fingret på hoseln med glaset.
        let s2 = last.shots[1]
        let j2 = try XCTUnwrap(leder[s2.id])
        let r2 = ShotReview(series: j2, crop: serie.activeCrop)
        var m2 = ClubMarking(existing: nil, width: r2.width, height: r2.height, crop: serie.activeCrop)
        for p in ["P1", "P2", "P3"] { m2.skip(t: s2.measure?.positions[p] ?? 0) }
        let k4 = try XCTUnwrap(r2.index(nearestT: m2.shownTime(measure: s2.measure, impact: s2.impact - s2.click.time)))
        let f4 = r2.frames[k4].joints
        let g4 = KlubbPunkt(x: ((f4[5]?.x ?? 0) + (f4[6]?.x ?? 0)) / 2, y: ((f4[5]?.y ?? 0) + (f4[6]?.y ?? 0)) / 2)
        let ug = m2.surfacePoint(g4)
        XCTAssertTrue(m2.tap(u: ug.u + 0.08, v: ug.v, t: r2.frames[k4].t))
        let uh = m2.surfacePoint(KlubbPunkt(x: g4.x + 25, y: g4.y + 85))
        let hel = try await fullFrame(store.url(fil, in: last.id), at: r2.frames[k4].pts)
        let tid = Tal.tecken(r2.frames[k4].t - (s2.impact - s2.click.time), decimaler: 3) + " s"
        // Glaset förstorar loupeZoom gånger i punkter: ytan är stageHeight · aspect punkter bred.
        let bredd = Double(ClubMarkContent<Color, Color>.stageHeight) * m2.aspect
        let lc = m2.loupeCrop(u: uh.u, v: uh.v, surfaceWidthPt: bredd, loupePt: Double(ClubMarkContent<Color, Color>.loupeSize))
        let zoom = m2.loupeMagnification(lc, surfaceWidthPt: bredd, loupePt: Double(ClubMarkContent<Color, Color>.loupeSize))
        print(String(format: "PROV: glaset förstorar %.3f× (ytan %.1f pt bred, glaset %.0f pt, %d × %d px i glaset)", zoom, bredd,
                     Double(ClubMarkContent<Color, Color>.loupeSize), Int((lc.width * Double(m2.width)).rounded()),
                     Int((lc.height * Double(m2.height)).rounded())))
        XCTAssertEqual(zoom, ClubMarking.loupeZoom, accuracy: 1e-9)
        try rita(ClubMarkContent(surface: { Image(decorative: ShotImages.cropped(hel, $0), scale: 1).resizable() },
                                 loupe: { LoupeImage(image: hel, crop: $0) }, marking: m2, time: tid, ring: g4,
                                 previewTouch: uh), "klubba-markera")
        try rita(ClubMarkContent(surface: { Image(decorative: ShotImages.cropped(hel, $0), scale: 1).resizable() },
                                 loupe: { LoupeImage(image: hel, crop: $0) }, marking: m2, time: tid, ring: g4),
                 "klubba-markera-utan-finger")
        let m3 = ClubMarking(existing: nil, width: r2.width, height: r2.height, crop: serie.activeCrop)
        try rita(ClubMarkContent(surface: { Image(decorative: ShotImages.cropped(hel, $0), scale: 1).resizable() },
                                 loupe: { LoupeImage(image: hel, crop: $0) }, marking: m3, time: tid, ring: g4,
                                 stick: [KlubbPunkt(x: 140, y: 470), KlubbPunkt(x: 138, y: 400)]),
                 "klubba-markera-ringen")

        // 5. Passet: antalet markerade svingar och klubbmåttens kort med n.
        let v = try XCTUnwrap(PassShotsView.visning(last, earlier: []))
        XCTAssertEqual(v.undertitel, "7i\u{00A0}· 2\u{00A0}· 1 with club marked")
        let plan = try XCTUnwrap(v.kort.first { $0.matt == "skaftplan_p1" }, "kortet för skaftplanet")
        XCTAssertEqual(plan.varde, "60.0")
        XCTAssertTrue(plan.rubrik.hasSuffix("n\u{00A0}1"), plan.rubrik)
        XCTAssertNil(v.kort.first { $0.matt == "skaft_vinkel" }, "vinkeln per position bara i granskningen")
        print("PROV: klubban i passet: \(v.undertitel); kort \(v.kort.filter { $0.matt.hasPrefix("skaft") }.map { "\($0.namn) \($0.varde) (\($0.rubrik))" })")
        var bilder: [String: CGImage] = [:]
        var linjer: [String: ImpactOverlay] = [:]
        for s in last.shots {
            bilder[s.id] = try await ShotImages.impactFrame(pass: last, shot: s, store: store)
            linjer[s.id] = ShotImages.overlay(shot: s, pass: last, store: store)
        }
        try rita(PassScreenContent(pass: last, visning: v, images: bilder, overlays: linjer, analysis: AnalysisState(),
                                   editable: false), "klubba-passet")
    }

    // MARK: Hjälp

    private func XCTUnwrapAsync<T>(_ v: T?) async throws -> T { try XCTUnwrap(v) }

    /// Hela den upprätta rutan (utan utsnitt), som glaset förstorar.
    private func fullFrame(_ url: URL, at t: Double) async throws -> CGImage {
        let g = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        g.appliesPreferredTrackTransform = true
        g.requestedTimeToleranceBefore = .zero
        g.requestedTimeToleranceAfter = .zero
        return try await g.image(at: CMTime(seconds: t + ShotReview.seekInto, preferredTimescale: 48_000)).image
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
}
