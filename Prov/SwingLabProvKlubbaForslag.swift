// SIMULATORPROVET FÖR MODELLENS FÖRSLAG I KLUBBMARKERINGEN (PLAN S7d, BESLUT B93, METOD MF8).
//
// Vad som bevisas här, på provets PÅHITTADE film, leder och förslag (CLAUDE.md, Dataregeln):
//   importen   en förslagsfil för passet går igenom Store (formen och mot passet) och sparas per
//              pass och vy; en fil för en annan vy och en trasig fil avvisas med fältet, aldrig
//              värdet;
//   märkningen förslaget i rutan visas, ✓ godkänner båda punkterna med ett tryck, ett tryck på
//              "1?" godkänner greppet och ett tryck bredvid "2?" rättar hoseln; källorna sparas i
//              pass.json och ett förslag som inte rörts blir ingen markering;
//   bilderna   klubba-forslag (förslaget, streckat, med ✓), klubba-forslag-godkant (positionen
//              efter ✓) och klubba-forslag-rattat (greppet godkänt, fingret bredvid "2?").
// MED ETT RIKTIGT FINGER OCH EN RIKTIG MODELL PROVAS DET BARA PÅ TELEFONEN.

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
final class SwingLabProvKlubbaForslag: XCTestCase {
    static let ut = "/tmp/swinglab_prov"

    func testForslagenIMarkeringen() async throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "swinglab-prov", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let rot = dir.appending(path: "forslag-\(UUID().uuidString)")
        let store = Store(root: rot, exportFolder: rot.appending(path: "Export"))
        var pass = store.newPass(setup: PassSetup(view: .dtl, club: "j7", distance: 3, hand: .hoger),
                                 at: Date(timeIntervalSince1970: 1_792_848_612))
        let fil = PassState.videoPath(nr: 1)
        let film = store.url(fil, in: pass.id)
        try await SyntheticMovie.write(to: film, sound: .lpcm, seconds: 8.2, flashes: [2.5, 6.0])
        let serie = try await SeriesMaker.make(url: film, nr: 1, file: fil, source: .recording, club: "j7",
                                               start: pass.created, startHost: nil, microphone: nil)
        pass.series.append(serie)
        pass.syncShots()
        var leder: [String: JointSeries] = [:]
        for i in pass.shots.indices {
            let s = pass.shots[i]
            pass.shots[i].verdict = .swing
            let j = SwingLabProvPaket.leder(DemoSving.dtl(thrust: (-2, 3, 8)), klick: s.click.time,
                                            ljudet: pass.setup.soundDelay, width: serie.uprightWidth,
                                            height: serie.uprightHeight)
            leder[s.id] = j
            pass.shots[i].joints = try store.writeJoints(j, shot: s.id, in: pass.id)
            pass.shots[i].jointFrames = j.frames.count
        }
        store.save(pass)
        pass = store.measured(try XCTUnwrap(store.load(pass.id)))
        let s1 = pass.shots[0]
        let j1 = try XCTUnwrap(leder[s1.id])

        // 1. Förslagsfilen: en ruta per Visions ruta, greppet vid handledernas mitt och hoseln ett
        // skaft bort, som PC:ns klubba_forslag.py skriver den (FORMAT.md).
        func hander(_ f: PoseFrame) -> KlubbPunkt? {
            let h = [f.joints[5], f.joints[6]].compactMap { $0 }
            guard !h.isEmpty else { return nil }
            return KlubbPunkt(x: h.map(\.x).reduce(0, +) / Double(h.count), y: h.map(\.y).reduce(0, +) / Double(h.count))
        }
        func hoselFor(_ g: KlubbPunkt) -> KlubbPunkt {
            KlubbPunkt(x: min(Double(j1.width) - 1, g.x + 30), y: min(Double(j1.height) - 1, g.y + 75))
        }
        var rutor: [[String: Any]] = []
        for f in j1.frames {
            guard let g = hander(f) else { continue }
            let h = hoselFor(g)
            let hosel: [String: Any] = ["x": h.x, "y": h.y, "konfidens": 0.8, "box": [h.x - 6, h.y - 6, 22.0, 14.0]]
            let punkter: [String: Any] = ["grepp": ["x": g.x, "y": g.y, "konfidens": 0.9], "hosel": hosel,
                                          "huvud": ["x": h.x + 8, "y": h.y + 3, "konfidens": 0.85]]
            rutor.append(["t": f.t, "punkter": punkter])
        }
        func forslagsfil(vy: String, pass id: String) throws -> Data {
            let modell: [String: Any] = ["namn": "prov-modell", "version": "0.0.1",
                                         "data": [["namn": "golf-49wbh", "licens": "CC BY 4.0"]]]
            let slag: [String: Any] = ["id": s1.id, "rutor": rutor]
            let d: [String: Any] = ["format": KlubbForslagFil.format, "pass": id, "vy": vy,
                                    "skapad": "2026-10-25T21:15:00+02:00", "modell": modell,
                                    "bredd": j1.width, "hojd": j1.height, "slag": [slag]]
            return try JSONSerialization.data(withJSONObject: d)
        }
        XCTAssertThrowsError(try store.importClubSuggestions(forslagsfil(vy: "fo", pass: pass.id))) { e in
            XCTAssertEqual((e as? FormatFel)?.beskrivning, "suggestions: vy: does not match the session")
        }
        XCTAssertThrowsError(try store.importClubSuggestions(forslagsfil(vy: "dtl", pass: "20991231-235959"))) { e in
            XCTAssertEqual((e as? FormatFel)?.beskrivning, "suggestions: pass: no such session")
        }
        var trasig = try XCTUnwrap(try JSONSerialization.jsonObject(with: forslagsfil(vy: "dtl", pass: pass.id)) as? [String: Any])
        trasig["bredd"] = -5
        XCTAssertThrowsError(try store.importClubSuggestions(JSONSerialization.data(withJSONObject: trasig))) { e in
            let text = (e as? FormatFel)?.beskrivning ?? ""
            XCTAssertEqual(text, "suggestions: bredd: invalid")
            XCTAssertFalse(text.contains("-5"))
        }
        XCTAssertNil(store.clubSuggestions(pass), "inget sparat av de avvisade")
        try store.importClubSuggestions(forslagsfil(vy: "dtl", pass: pass.id))
        let forslag = try XCTUnwrap(store.clubSuggestions(pass))
        XCTAssertEqual(forslag.slag.first?.rutor.count, rutor.count)
        print("PROV: förslagen: \(rutor.count) rutor för \(s1.id) hämtade; vyn, passet och bredden avvisade med fältet")

        // 2. Märkningen med förslagen (samma väg som granskningen, GranskningVideo.startMarking).
        let review = ShotReview(series: j1, crop: serie.activeCrop)
        let sv = try ShotMeasuring.sving(j1, view: .dtl, hand: .hoger, heightM: 1.8, impact: s1.impact - s1.click.time)
        var m = ClubMarking(existing: nil, width: review.width, height: review.height, crop: serie.activeCrop, view: .dtl,
                            xTecken: sv.xTecken,
                            suggestions: forslag.rutor(slag: s1.id, bredd: review.width, hojd: review.height),
                            suggestionModel: forslag.modell)
        func ruta() throws -> Int {
            try XCTUnwrap(review.index(nearestT: m.shownTime(measure: s1.measure, impact: s1.impact - s1.click.time)))
        }
        func yta(_ k: Int, touch: (u: Double, v: Double)? = nil) async throws -> some View {
            let hel = try await fullFrame(film, at: review.frames[k].pts)
            let t = review.frames[k].t
            let tid = Tal.tecken(t - (s1.impact - s1.click.time), decimaler: 3) + " s"
            return ClubMarkContent(surface: { Image(decorative: ShotImages.cropped(hel, $0), scale: 1).resizable() },
                                   loupe: { LoupeImage(image: hel, crop: $0) }, marking: m, time: tid,
                                   ring: hander(review.frames[k]), suggestion: m.shownSuggestion(t: t),
                                   canUse: m.canUseSuggestion(t: t), previewTouch: touch, editable: false)
        }
        // P1: förslaget visas, och ✓ godkänner båda punkterna med ett tryck.
        let k1 = try ruta()
        let t1 = review.frames[k1].t
        let g1 = try XCTUnwrap(hander(review.frames[k1]))
        m.startZoom(hands: g1, cmPerPx: s1.measure?.cmPerPx)
        let visat = try XCTUnwrap(m.shownSuggestion(t: t1))
        XCTAssertEqual(visat.grepp, g1)
        XCTAssertTrue(m.canUseSuggestion(t: t1))
        try rita(try await yta(k1), "klubba-forslag")
        XCTAssertTrue(m.useSuggestion(t: t1))
        XCTAssertEqual(m.position, "P3", "ett tryck: positionen sparad och nästa")
        let p1 = try XCTUnwrap(m.marks["P1"])
        XCTAssertEqual([p1.greppKalla, p1.hoselKalla], [Klubba.kallaForslag, Klubba.kallaForslag])
        XCTAssertEqual(p1.hosel, hoselFor(g1))
        m.go(to: "P1")
        m.startZoom(hands: g1, cmPerPx: s1.measure?.cmPerPx)
        try rita(try await yta(k1), "klubba-forslag-godkant")
        XCTAssertTrue(m.advance())

        // P3: "1?" godkänns med ett tryck på den, och hoseln rättas med ett tryck bredvid "2?".
        XCTAssertEqual(m.position, "P3")
        let k3 = try ruta()
        let t3 = review.frames[k3].t
        let g3 = try XCTUnwrap(hander(review.frames[k3]))
        m.startZoom(hands: g3, cmPerPx: s1.measure?.cmPerPx)
        let ug = m.surfacePoint(g3)
        XCTAssertTrue(m.tap(u: ug.u + 0.01, v: ug.v, t: t3, ring: g3))
        XCTAssertEqual(m.grip, g3)
        XCTAssertEqual(m.gripSource, Klubba.kallaForslag)
        let ratt = KlubbPunkt(x: hoselFor(g3).x - 25, y: hoselFor(g3).y + 10)
        let ur = m.surfacePoint(ratt)
        try rita(try await yta(k3, touch: ur), "klubba-forslag-rattat")
        XCTAssertTrue(m.tap(u: ur.u, v: ur.v, t: t3))
        let p3 = try XCTUnwrap(m.marks["P3"])
        XCTAssertEqual(p3.greppKalla, Klubba.kallaForslag)
        XCTAssertNil(p3.hoselKalla, "rättad: ett tryck")
        XCTAssertEqual(p3.hosel?.x ?? .nan, ratt.x, accuracy: 1e-6)
        XCTAssertEqual(p3.forslag?.hosel, hoselFor(g3), "förslaget som rättades står bredvid")

        // P4 hoppas: förslaget i rutan blir ingen markering.
        m.skip(t: review.frames[try ruta()].t)
        XCTAssertNil(m.marks["P4"]?.grepp)
        XCTAssertNil(m.marks["P4"]?.forslag)
        pass.setClubMarks(m.result, shot: s1.id, joints: j1)
        store.save(pass)
        let last = try XCTUnwrap(store.load(pass.id))
        XCTAssertEqual(last.shots[0].klubba, m.result, "källorna och förslagen står i pass.json")
        XCTAssertEqual(last.shots[0].klubba?.filter(\.markerad).map(\.position), ["P1", "P3"])
        print("PROV: förslagen i märkningen: P1 godkänt med ✓, P3 greppet godkänt och hoseln rättad, P4 hoppad utan förslag")
    }

    // MARK: Hjälp

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
