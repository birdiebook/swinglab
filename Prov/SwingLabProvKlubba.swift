// SIMULATORPROVET FÖR KLUBBANS MÄRKNING (PLAN S7a, BESLUT B47, B57, B58, METOD M45–M49), bakifrån och
// framifrån (testMarkeraKlubbanFramifran).
//
// Vad som bevisas här, på provets PÅHITTADE film och PÅHITTADE leder (SwingDemo:s DTL-sving;
// inga riktiga svingar, CLAUDE.md: Dataregeln):
//   märkningen  P1–P10 genom appens egen logik (ClubMarking): ett tryck nära kanten blir ingen
//               punkt, greppet och hoseln per position med tryck på ytan, en flytt och ett
//               ångra, P8 hoppad; sparat i pass.json och läst tillbaka;
//   måtten      slaget mäts om: skaftets vinkel vid positionerna är den satta, skaftplanet vid
//               P1, och P2 och P6 är rutorna som valdes;
//   bilderna    granskningen med skaftlinjen (klubba-granskning), märkningsläget (S7c, BESLUT
//               B59): guiden (klubba-guide-1 … 3), riktpinnens steg (klubba-riktpinne),
//               "1 · Tap the grip" inzoomat med gissningen "1?" (klubba-greppet), "2 · Tap the
//               clubhead" med fingret och glaset (klubba-klubbhuvudet), en klar position
//               (klubba-klar), och passet med antalet markerade svingar och klubbmåttens kort
//               (klubba-passet).
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
        let sv1 = try ShotMeasuring.sving(j1, view: .dtl, hand: .hoger, heightM: 1.8, impact: s1.impact - s1.click.time)
        var m = ClubMarking(existing: s1.klubba, width: review.width, height: review.height, crop: serie.activeCrop,
                            view: .dtl, xTecken: sv1.xTecken)
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

        // 4. Märkningsläget (S7c, BESLUT B59) för slag 2: guiden, riktpinnens steg, P4 inzoomad
        // med "1 · Tap the grip" och gissningen "1?", "2 · Tap the clubhead" med fingret och
        // glaset, och en klar position med punkterna 1 och 2 och skaftlinjen.
        for i in 0..<ClubGuideContent.pages { try rita(ClubGuideContent(page: i), "klubba-guide-\(i + 1)") }
        let s2 = last.shots[1]
        let j2 = try XCTUnwrap(leder[s2.id])
        let r2 = ShotReview(series: j2, crop: serie.activeCrop)
        var m2 = ClubMarking(existing: nil, width: r2.width, height: r2.height, crop: serie.activeCrop, view: .dtl,
                             xTecken: sv1.xTecken)
        let k1b = try XCTUnwrap(r2.index(nearestT: m2.shownTime(measure: s2.measure, impact: s2.impact - s2.click.time)))
        let hel1 = try await fullFrame(store.url(fil, in: last.id), at: r2.frames[k1b].pts)
        let tid1 = Tal.tecken(r2.frames[k1b].t - (s2.impact - s2.click.time), decimaler: 3) + " s"
        XCTAssertTrue(last.asksForRiktpinne(series: 1), "bakifrån utan pinne: riktpinnens steg före P1")
        try rita(ClubMarkContent(surface: { Image(decorative: ShotImages.cropped(hel1, $0), scale: 1).resizable() },
                                 loupe: { LoupeImage(image: hel1, crop: $0) }, marking: m2, time: tid1, stickStep: true,
                                 stick: [KlubbPunkt(x: 150, y: 455), KlubbPunkt(x: 140, y: 380)]), "klubba-riktpinne")
        for p in ["P1", "P3"] { m2.skip(t: s2.measure?.positions[p] ?? 0) }
        XCTAssertEqual(m2.position, "P4")
        let k4 = try XCTUnwrap(r2.index(nearestT: m2.shownTime(measure: s2.measure, impact: s2.impact - s2.click.time)))
        let f4 = r2.frames[k4].joints
        let g4 = KlubbPunkt(x: ((f4[5]?.x ?? 0) + (f4[6]?.x ?? 0)) / 2, y: ((f4[5]?.y ?? 0) + (f4[6]?.y ?? 0)) / 2)
        m2.startZoom(hands: g4, cmPerPx: s2.measure?.cmPerPx)
        XCTAssertGreaterThan(m2.zoomFactor, 1.2, "positionen öppnas inzoomad kring händerna")
        let hel = try await fullFrame(store.url(fil, in: last.id), at: r2.frames[k4].pts)
        let tid = Tal.tecken(r2.frames[k4].t - (s2.impact - s2.click.time), decimaler: 3) + " s"
        func yta(_ m: ClubMarking, touch: (u: Double, v: Double)? = nil, ring: KlubbPunkt? = nil) -> some View {
            ClubMarkContent(surface: { Image(decorative: ShotImages.cropped(hel, $0), scale: 1).resizable() },
                            loupe: { LoupeImage(image: hel, crop: $0) }, marking: m, time: tid, ring: ring,
                            previewTouch: touch)
        }
        try rita(yta(m2, ring: g4), "klubba-greppet")
        let ug = m2.surfacePoint(g4)
        XCTAssertTrue(m2.tap(u: ug.u, v: ug.v, t: r2.frames[k4].t, ring: g4), "1? godtas med ett tryck")
        XCTAssertEqual(m2.gripSource, Klubba.kallaRing)
        let hoselP = KlubbPunkt(x: g4.x + 25, y: g4.y + 60)
        let uh = m2.surfacePoint(hoselP)
        // Glaset förstorar loupeZoom gånger i punkter också inzoomat: ytan är stageHeight · aspect punkter bred.
        let bredd = Double(ClubMarkContent<Color, Color>.stageHeight) * m2.aspect
        let lc = m2.loupeCrop(u: uh.u, v: uh.v, surfaceWidthPt: bredd, loupePt: Double(ClubMarkContent<Color, Color>.loupeSize))
        let zoom = m2.loupeMagnification(lc, surfaceWidthPt: bredd, loupePt: Double(ClubMarkContent<Color, Color>.loupeSize))
        print(String(format: "PROV: glaset förstorar %.3f× ovanpå zoomen %.2f× (ytan %.1f pt bred, glaset %.0f pt, %d × %d px i glaset)",
                     zoom, m2.zoomFactor, bredd, Double(ClubMarkContent<Color, Color>.loupeSize),
                     Int((lc.width * Double(m2.width)).rounded()), Int((lc.height * Double(m2.height)).rounded())))
        XCTAssertEqual(zoom, ClubMarking.loupeZoom, accuracy: 1e-9)
        try rita(yta(m2, touch: uh), "klubba-klubbhuvudet")
        XCTAssertTrue(m2.tap(u: uh.u, v: uh.v, t: r2.frames[k4].t))
        XCTAssertEqual(m2.position, "P5", "appen går vidare själv")
        let h4 = try XCTUnwrap(m2.marks["P4"]?.hosel)
        XCTAssertEqual(h4.x, hoselP.x, accuracy: 1e-6, "inzoomat tryck = hela bildens pixel")
        XCTAssertEqual(h4.y, hoselP.y, accuracy: 1e-6)
        m2.go(to: "P4")
        m2.startZoom(hands: g4, cmPerPx: s2.measure?.cmPerPx)
        try rita(yta(m2), "klubba-klar")
        print("PROV: märkningen S7c: guiden 3 bilder, riktpinnens steg, P4 inzoomad \(String(format: "%.2f", m2.zoomFactor))×, "
              + (m2.positionLine ?? ""))

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

    /// Satta skaft framifrån (S7a-FO, BESLUT B57): vinkeln grepp → hosel (grader, y uppåt, +X mot
    /// målet) och längden i px i bilden 270 × 480, som de påhittade svingarna (1080 × 1920,
    /// 400 px/m) skalade en fjärdedel: grepp → hosel 0,80 m är 80 px i bildens plan, P2, P6 och
    /// P8 78 px, adressen och träffen 72–74 px (skaftet lutar mot kameran), P3 och P9 62 px och
    /// finishen 45 px (METOD M49). Finishen är för kort för spärren (M46).
    static let sattaFO: [String: (Double, Double)] = [
        "P1": (-95, 72), "P2": (178, 78), "P3": (130, 62), "P4": (10, 72), "P5": (100, 70),
        "P6": (178, 78), "P7": (-104, 74), "P8": (2, 78), "P9": (80, 62), "P10": (-20, 45)]

    /// Framifrån: ett FO-pass märks genom appens logik i appens ordning (kroppens positioner
    /// först, BESLUT B58) utan riktpinne; P2, P6 och P8 föreslås där skaftets vinkel går genom
    /// vågrätt, kontrollerat mot värden räknade för hand (METOD M45); måtten ur M49;
    /// bilderna klubba-fo-granskning (träffen med skaftlinjen) och klubba-fo-markera (P6 med
    /// glaset och utan riktpinnen).
    func testMarkeraKlubbanFramifran() async throws {
        let rot = try tmp("klubba-fo-\(UUID().uuidString)")
        let store = Store(root: rot, exportFolder: rot.appending(path: "Export"))
        var pass = store.newPass(setup: PassSetup(view: .fo, club: "j7", distance: 3, hand: .hoger),
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
            let j = SwingLabProvPaket.leder(DemoSving.fo(sway: (-6, 6, 14)), klick: s.click.time,
                                            ljudet: pass.setup.soundDelay, width: serie.uprightWidth,
                                            height: serie.uprightHeight)
            leder[s.id] = j
            pass.shots[i].joints = try store.writeJoints(j, shot: s.id, in: pass.id)
            pass.shots[i].jointFrames = j.frames.count
        }
        store.save(pass)
        pass = store.measured(try XCTUnwrap(store.load(pass.id)))
        XCTAssertTrue(pass.shots.allSatisfy { $0.measure?.ok == true }, "båda mätta")

        // 1. Märkningen av slag 1 framifrån, ändarna före P2, P6 och P8.
        let s1 = pass.shots[0]
        let j1 = try XCTUnwrap(leder[s1.id])
        let review = ShotReview(series: j1, crop: serie.activeCrop)
        let sv1 = try ShotMeasuring.sving(j1, view: .fo, hand: .hoger, heightM: 1.8, impact: s1.impact - s1.click.time)
        var m = ClubMarking(existing: s1.klubba, width: review.width, height: review.height, crop: serie.activeCrop,
                            view: .fo, xTecken: sv1.xTecken)
        XCTAssertFalse(m.stickAvailable, "riktpinnen bara bakifrån")
        let start = try XCTUnwrap(s1.measure?.start, "baksvingens start sparad i måtten")
        var tryck = 0
        var satt: [String: Double] = [:]
        var forslag: [String: Double] = [:]
        var ordning: [String] = []
        // Appens ordning: nästa position av sig själv, kroppens först och skaftets sist (BESLUT B58).
        while !m.done {
            let p = m.position
            ordning.append(p)
            let ts = m.shownTime(measure: s1.measure, impact: s1.impact - s1.click.time)
            if Klubba.skaftets.contains(p) { forslag[p] = ts }
            let k = try XCTUnwrap(review.index(nearestT: ts))
            let tk = review.frames[k].t
            let (vinkel, langd) = try XCTUnwrap(Self.sattaFO[p])
            let f = review.frames[k].joints
            let h = [f[5], f[6]].compactMap { $0 }
            let ring = KlubbPunkt(x: h.map(\.x).reduce(0, +) / Double(h.count), y: h.map(\.y).reduce(0, +) / Double(h.count))
            // P1: greppet ur ringen; övriga ett fritt tryck ovanför ringen (skaftet når kanten åt
            // sidan vid P8 och i finishen).
            let g = p == "P1" ? ring : KlubbPunkt(x: ring.x, y: ring.y - 16)
            let hosel = KlubbPunkt(x: g.x + langd * cos(vinkel * .pi / 180), y: g.y - langd * sin(vinkel * .pi / 180))
            let ug = m.surfacePoint(g), uh = m.surfacePoint(hosel)
            XCTAssertTrue(m.tap(u: ug.u, v: ug.v, t: tk, ring: ring), "\(p): greppet")
            XCTAssertEqual(m.gripSource, p == "P1" ? Klubba.kallaRing : Klubba.kalla, p)
            XCTAssertTrue(m.tap(u: uh.u, v: uh.v, t: tk), "\(p): hoseln")
            XCTAssertNotNil(m.marks[p], "\(p): sparad av sig själv")
            tryck += 2
            satt[p] = tk
        }
        XCTAssertEqual(ordning, ["P1", "P3", "P4", "P5", "P7", "P9", "P10", "P2", "P6", "P8"])
        // Förslaget till P2, P6 och P8 räknat för hand ur de satta vinklarna och rutorna där
        // ändarna markerades (METOD M45): P2 från starten, −95° → 130° medurs 135°, vågrätt efter
        // 85°; P6 100° → −104° moturs 156°, efter 80°; P8 −104° → 80° moturs 184°, efter 104°.
        let t1 = try XCTUnwrap(satt["P1"]), t3 = try XCTUnwrap(satt["P3"]), t5 = try XCTUnwrap(satt["P5"])
        let t7 = try XCTUnwrap(satt["P7"]), t9 = try XCTUnwrap(satt["P9"])
        XCTAssertGreaterThan(start, t1, "starten efter adressens mitt")
        let fran = max(t1, start)
        XCTAssertEqual(forslag["P2"] ?? .nan, fran + (t3 - fran) * 85 / 135, accuracy: 1e-6)
        XCTAssertEqual(forslag["P6"] ?? .nan, t5 + (t7 - t5) * 80 / 156, accuracy: 1e-6)
        XCTAssertEqual(forslag["P8"] ?? .nan, t7 + (t9 - t7) * 104 / 184, accuracy: 1e-6)
        for p in Klubba.skaftets {
            let kropp = try XCTUnwrap(Klubba.forslagTid(p, positioner: s1.measure?.positions ?? [:]))
            print(String(format: "PROV: framifrån %@ föreslås %.4f s ur skaftet (kroppens mitt %.4f s, starten %.4f s)",
                         p, forslag[p] ?? .nan, kropp, start))
        }
        XCTAssertEqual(m.result.map(\.position), Klubba.positioner)
        print("PROV: klubban framifrån: \(tryck) tryck för P1–P10 utan steg, ingen riktpinne")
        pass.setClubMarks(m.result, shot: s1.id, joints: j1)
        store.save(pass)
        let last = try XCTUnwrap(store.load(pass.id))
        XCTAssertEqual(last.shots[0].klubba, m.result, "markeringarna står i pass.json")

        // 2. Måtten framifrån (METOD M46, M49) och P2, P6 och P8 som rutorna som valdes.
        let mv = try XCTUnwrap(last.shots[0].measure)
        for (p, (vinkel, langd)) in Self.sattaFO {
            let k = Klubba.nyckel("skaft_vinkel", p)
            if 2.0.squareRoot() * Klubba.tryckPx / langd * 180 / .pi > Klubba.maxSD {
                XCTAssertNil(mv.values[k], "\(p): för kort för spärren")
            } else {
                XCTAssertEqual(mv.values[k] ?? .nan, vinkel, accuracy: 0.01, p)
            }
        }
        XCTAssertEqual(mv.values["skaft_topp"] ?? .nan, 10, accuracy: 0.01)
        XCTAssertEqual(mv.values["skaft_lutning_traff"] ?? .nan, 14, accuracy: 0.01)
        let p5 = try XCTUnwrap(mv.values["skaft_arm_p5"], "casting vid P5")
        let p6 = try XCTUnwrap(mv.values["skaft_arm_p6"], "casting vid P6")
        XCTAssertTrue((0.0...180.0).contains(p5) && (0.0...180.0).contains(p6))
        XCTAssertNil(mv.values["skaftplan_p1"], "bakifrån-måtten finns inte framifrån")
        XCTAssertNil(mv.klubbaFlyktpunktAntagen, "ingen flyktpunkt framifrån")
        for p in Klubba.skaftets { XCTAssertEqual(mv.positions[p] ?? .nan, satt[p] ?? 0, accuracy: 1e-9, p) }
        print("PROV: klubban framifrån P1–P10: " + Klubba.positioner.map { p in
            "\(p) \(mv.values[Klubba.nyckel("skaft_vinkel", p)].map { String(format: "%.2f", $0) } ?? "–")"
        }.joined(separator: ", ") + String(format: "; toppen %.2f, armen P5 %.2f, P6 %.2f, lutningen %.2f",
                                           mv.values["skaft_topp"] ?? .nan, p5, p6, mv.values["skaft_lutning_traff"] ?? .nan))

        // 3. Granskningen vid träffen med skaftlinjen och klubbmåtten under videon.
        let pos = review.positions(mv)
        let k7 = try XCTUnwrap(pos.first { $0.name == "P7" }?.index ?? nil)
        for p in Klubba.skaftets { XCTAssertNotNil(pos.first { $0.name == p }?.index ?? nil, "\(p) går att välja") }
        let shaft = try XCTUnwrap(review.shaft(k7, marks: last.shots[0].klubba), "skaftlinjen i rutan")
        let rader = ReviewRows.rows(pass: last, shot: last.shots[0], position: "P7", baseline: [:])
        XCTAssertTrue(rader.contains { $0.matt == "skaft_lutning_traff" })
        XCTAssertTrue(rader.contains { $0.matt == "skaft_vinkel_p7" })
        print("PROV: granskningen framifrån vid P7: \(rader.filter { $0.matt.hasPrefix("skaft") }.map { "\($0.namn) \($0.varde)" })")
        let still7 = try await XCTUnwrapAsync(try await ShotImages.frame(pass: last, shot: last.shots[0], store: store,
                                                                          at: review.frames[k7].pts))
        try rita(ReviewContent(surface: Image(decorative: still7, scale: 1).resizable(), review: review, number: 1,
                               frame: k7, position: "P7", positions: pos, rows: rader, impact: s1.impact - s1.click.time,
                               shaft: shaft, editable: false), "klubba-fo-granskning")

        // 4. Märkningsläget för slag 2 vid P6: greppet satt, fingret på hoseln med glaset, ingen
        // riktpinne.
        let s2 = last.shots[1]
        let r2 = ShotReview(series: try XCTUnwrap(leder[s2.id]), crop: serie.activeCrop)
        var m2 = ClubMarking(existing: nil, width: r2.width, height: r2.height, crop: serie.activeCrop, view: .fo,
                             xTecken: sv1.xTecken)
        for p in ["P1", "P3", "P4", "P5", "P7", "P9", "P10", "P2"] { m2.skip(t: s2.measure?.positions[p] ?? 0) }
        XCTAssertEqual(m2.position, "P6")
        let k6 = try XCTUnwrap(r2.index(nearestT: m2.shownTime(measure: s2.measure, impact: s2.impact - s2.click.time)))
        let f6 = r2.frames[k6].joints
        let g6 = KlubbPunkt(x: ((f6[5]?.x ?? 0) + (f6[6]?.x ?? 0)) / 2 + 20, y: ((f6[5]?.y ?? 0) + (f6[6]?.y ?? 0)) / 2)
        m2.startZoom(hands: KlubbPunkt(x: g6.x - 20, y: g6.y), cmPerPx: s2.measure?.cmPerPx)
        let ug = m2.surfacePoint(g6)
        XCTAssertTrue(m2.tap(u: ug.u, v: ug.v, t: r2.frames[k6].t))
        let (v6, l6) = try XCTUnwrap(Self.sattaFO["P6"])
        let uh = m2.surfacePoint(KlubbPunkt(x: g6.x + l6 * cos(v6 * .pi / 180), y: g6.y - l6 * sin(v6 * .pi / 180)))
        let hel = try await fullFrame(store.url(fil, in: last.id), at: r2.frames[k6].pts)
        let tid = Tal.tecken(r2.frames[k6].t - (s2.impact - s2.click.time), decimaler: 3) + " s"
        try rita(ClubMarkContent(surface: { Image(decorative: ShotImages.cropped(hel, $0), scale: 1).resizable() },
                                 loupe: { LoupeImage(image: hel, crop: $0) }, marking: m2, time: tid,
                                 previewTouch: uh), "klubba-fo-markera")
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
