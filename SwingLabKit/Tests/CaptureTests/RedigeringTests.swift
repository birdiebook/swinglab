import Foundation
import XCTest
import Swing
import SwingDemo
@testable import Capture

/// S2i: fönstret och utsnittet. Handtagen, rutan som dras, nyps och dras i hörnen,
/// Visions koordinater i rutan tillbaka till hela bildens pixlar, buffertens koordinater,
/// klicken utanför fönstret och att seriens slag görs om när redigeringen ändras. På
/// PÅHITTADE leder (CLAUDE.md, Dataregeln). METOD MS7, MS8, MS12, MS13
final class RedigeringTests: XCTestCase {

    func assertRect(_ r: CropRect, _ x: Double, _ y: Double, _ w: Double, _ h: Double, accuracy a: Double = 1e-9,
                    file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(r.x, x, accuracy: a, "x", file: file, line: line)
        XCTAssertEqual(r.y, y, accuracy: a, "y", file: file, line: line)
        XCTAssertEqual(r.width, w, accuracy: a, "bredd", file: file, line: line)
        XCTAssertEqual(r.height, h, accuracy: a, "höjd", file: file, line: line)
    }

    // MARK: Fönstret

    func testFonstretsHandtagGarInteForbiVarandraOchStannarIFilen() {
        let d = 9.0
        var w = TimeWindow.full(d)
        XCTAssertEqual(w, TimeWindow(start: 0, end: 9))
        w = w.withStart(2.5, duration: d)
        w = w.withEnd(6.0, duration: d)
        XCTAssertEqual(w, TimeWindow(start: 2.5, end: 6.0))
        XCTAssertEqual(w.length, 3.5, accuracy: 1e-12)
        // Starten förbi slutet: stannar en minsta längd före.
        XCTAssertEqual(w.withStart(8, duration: d), TimeWindow(start: 5.0, end: 6.0))
        XCTAssertEqual(w.withEnd(1, duration: d), TimeWindow(start: 2.5, end: 3.5))
        // Utanför filen.
        XCTAssertEqual(w.withStart(-3, duration: d).start, 0)
        XCTAssertEqual(w.withEnd(30, duration: d).end, 9)
        XCTAssertEqual(w.withStart(.nan, duration: d), w)
        // Gränserna räknas in.
        XCTAssertTrue(w.contains(2.5))
        XCTAssertTrue(w.contains(6.0))
        XCTAssertFalse(w.contains(2.4999))
        XCTAssertFalse(w.contains(6.0001))
    }

    func testFonstretKlamptKringMittenOchHelaFilenNarDenArKort() {
        XCTAssertEqual(TimeWindow(start: 4.0, end: 4.2).clamped(duration: 9), TimeWindow(start: 3.6, end: 4.6))
        XCTAssertEqual(TimeWindow(start: 8.9, end: 9.5).clamped(duration: 9), TimeWindow(start: 8.0, end: 9.0))
        XCTAssertEqual(TimeWindow(start: 6, end: 2).clamped(duration: 9), TimeWindow(start: 2, end: 6))
        XCTAssertEqual(TimeWindow(start: 0.2, end: 0.4).clamped(duration: 0.8), TimeWindow.full(0.8))
        XCTAssertEqual(TimeWindow(start: .nan, end: 3).clamped(duration: 9), TimeWindow.full(9))
    }

    // MARK: Utsnittet

    func testRutanDrasInomBildenOchBehallerStorleken() {
        let r = CropRect(x: 0.2, y: 0.3, width: 0.5, height: 0.4)
        assertRect(r.moved(dx: 0.1, dy: -0.1), 0.3, 0.2, 0.5, 0.4)
        assertRect(r.moved(dx: 0.9, dy: 0.9), 0.5, 0.6, 0.5, 0.4)
        assertRect(r.moved(dx: -0.9, dy: -0.9), 0, 0, 0.5, 0.4)
        XCTAssertEqual(r.moved(dx: .infinity, dy: 0), r)
    }

    func testRutanNypsKringMittenMellanMinstaSidanOchHelaBilden() {
        let r = CropRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4)
        assertRect(r.scaled(by: 1.5), 0.2, 0.2, 0.6, 0.6)
        assertRect(r.scaled(by: 0.1), 0.4, 0.4, CropRect.minSide, CropRect.minSide)
        assertRect(r.scaled(by: 10), 0, 0, 1, 1)
        XCTAssertTrue(r.scaled(by: 10).isFull)
        // Vid kanten skjuts den in i bilden.
        assertRect(CropRect(x: 0.6, y: 0, width: 0.4, height: 0.4).scaled(by: 1.5), 0.4, 0, 0.6, 0.6)
        XCTAssertEqual(r.scaled(by: -1), r)
    }

    func testHornenDrasMedFriaProportionerOchMinstaSidan() {
        let r = CropRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        assertRect(r.dragging(.topLeft, to: 0.1, 0.4), 0.1, 0.4, 0.7, 0.4)
        assertRect(r.dragging(.bottomRight, to: 0.5, 0.95), 0.2, 0.2, 0.3, 0.75)
        assertRect(r.dragging(.topRight, to: 1.4, -0.3), 0.2, 0, 0.8, 0.8)
        assertRect(r.dragging(.bottomLeft, to: 0.9, 0.1), 0.6, 0.2, CropRect.minSide, CropRect.minSide)
        for c in CropRect.Corner.allCases {
            let p = r.point(c)
            let d = r.dragging(c, to: p.x, p.y)
            assertRect(d, r.x, r.y, r.width, r.height, accuracy: 1e-12)
        }
    }

    func testRutanKlamptOchIPixlar() {
        assertRect(CropRect(x: -0.2, y: 0.9, width: 0.05, height: 2).clamped(), 0, 0, CropRect.minSide, 1)
        XCTAssertEqual(CropRect(x: .nan, y: 0, width: 1, height: 1).clamped(), .full)
        XCTAssertTrue(CropRect.full.isFull)
        XCTAssertFalse(CropRect(x: 0, y: 0, width: 0.99, height: 1).isFull)
        let px = CropRect(x: 0.1, y: 0.25, width: 0.5, height: 0.5).pixels(width: 1080, height: 1920)
        XCTAssertEqual(px.x, 108)
        XCTAssertEqual(px.y, 480)
        XCTAssertEqual(px.width, 540)
        XCTAssertEqual(px.height, 960)
        // Avrundat utåt.
        let ut = CropRect(x: 0.1001, y: 0, width: 0.3, height: 1).pixels(width: 270, height: 480)
        XCTAssertEqual(ut.x, 27)
        XCTAssertEqual(ut.x + ut.width, 109)
        XCTAssertEqual(ut.height, 480)
    }

    // MARK: Vision i rutan

    /// regionOfInterest har origo nere till vänster; rutan uppe till vänster.
    func testVisionsRegionArRutanMedYVant() {
        let r = CropRect(x: 0.1, y: 0.2, width: 0.5, height: 0.6)
        let v = r.visionRegion
        XCTAssertEqual(v.x, 0.1, accuracy: 1e-12)
        XCTAssertEqual(v.y, 0.2, accuracy: 1e-12)          // 1 − (0,2 + 0,6)
        XCTAssertEqual(v.width, 0.5, accuracy: 1e-12)
        XCTAssertEqual(v.height, 0.6, accuracy: 1e-12)
        let o = CropRect(x: 0, y: 0, width: 1, height: 0.3).visionRegion
        XCTAssertEqual(o.y, 0.7, accuracy: 1e-12, "överst i bilden är högst upp i Visions rum")
    }

    /// Visions punkter i rutan (origo nere till vänster) → hela bildens punkt (origo uppe
    /// till vänster): hörnen och mitten, och tillbaka.
    func testVisionsPunktIRutanTillHelaBilden() {
        let r = CropRect(x: 0.1, y: 0.2, width: 0.5, height: 0.6)
        func lika(_ a: (x: Double, y: Double), _ x: Double, _ y: Double, line: UInt = #line) {
            XCTAssertEqual(a.x, x, accuracy: 1e-12, line: line)
            XCTAssertEqual(a.y, y, accuracy: 1e-12, line: line)
        }
        lika(r.fromVision(x: 0, y: 0), 0.1, 0.8)            // Visions nedre vänstra = rutans nedre vänstra
        lika(r.fromVision(x: 1, y: 1), 0.6, 0.2)            // övre högra
        lika(r.fromVision(x: 0.5, y: 0.5), r.midX, r.midY)
        for (u, v) in [(0.3, 0.9), (0.0, 1.0), (0.77, 0.12)] {
            let p = r.fromVision(x: u, y: v)
            lika(r.toVision(x: p.x, y: p.y), u, v)
        }
        // Utan utsnitt (hela bilden) är det MS7:s avbildning.
        let hel = CropRect.full.fromVision(x: 0.25, y: 0.75)
        let ms7 = Orientation.pixels(x: 0.25, y: 0.75, uprightWidth: 1, uprightHeight: 1)
        lika(hel, ms7.x, ms7.y)
    }

    /// Lederna ur rutan hamnar i hela bildens pixlar (cm per px oförändrad), och en led
    /// som Vision lägger utanför rutan sparas som saknad.
    func testLedernaUrRutanIHelaBildensPixlarOchUtanforSaknas() {
        let crop = CropRect(x: 0.25, y: 0.1, width: 0.5, height: 0.8)
        var pts = [PoseJoint?](repeating: PoseJoint(x: 0.5, y: 0.5, c: 0.8), count: 13)
        pts[1] = PoseJoint(x: 1.2, y: 0.5, c: 0.9)          // utanför till höger
        pts[2] = PoseJoint(x: 0.5, y: -0.1, c: 0.9)         // nedanför
        pts[3] = PoseJoint(x: 0.5, y: 0.5, c: 0)            // ogiltig (Apple)
        pts[4] = PoseJoint(x: 1.0, y: 0.0, c: 0.9)          // på kanten: kvar
        let f = PoseFrame.fromVision(pts: 3.5, points: pts, confidence: 0.9, uprightWidth: 1080, uprightHeight: 1920,
                                     crop: crop)
        XCTAssertEqual(f.joints.count, 13)
        XCTAssertEqual(f.joints[0]?.x ?? .nan, 540, accuracy: 1e-9)
        XCTAssertEqual(f.joints[0]?.y ?? .nan, 960, accuracy: 1e-9)
        XCTAssertNil(f.joints[1])
        XCTAssertNil(f.joints[2])
        XCTAssertNil(f.joints[3])
        XCTAssertEqual(f.joints[4]?.x ?? .nan, 810, accuracy: 1e-9)
        XCTAssertEqual(f.joints[4]?.y ?? .nan, 1728, accuracy: 1e-9)
        // Utan utsnitt: som förut.
        let utan = PoseFrame.fromVision(pts: 3.5, points: pts, confidence: 0.9, uprightWidth: 1080, uprightHeight: 1920,
                                        crop: nil)
        XCTAssertEqual(utan, PoseFrame.fromVision(pts: 3.5, points: pts, confidence: 0.9, uprightWidth: 1080,
                                                  uprightHeight: 1920))
    }

    /// Hela kedjan på påhittade leder: DemoLeders spelare och granne i pixlar, som Vision
    /// skulle ge dem i rutan, tillbaka till pixlar. Spelaren blir samma pixlar; grannen
    /// utanför rutan förlorar alla leder och kan inte väljas.
    func testDemoLedernaGenomRutanOchTillbaka() throws {
        let w = 1080, h = 1920
        let crop = CropRect(x: 0.01, y: 0.2, width: 0.78, height: 0.7)
        let kandidater = DemoLeder.kandidater(pts: 2.0, klick: 2.2, sving: true, width: w, height: h)
        let tillbaka = kandidater.map { k -> PoseFrame in
            let vision = k.joints.map { j -> PoseJoint? in
                j.map { p in
                    let v = crop.toVision(x: p.x / Double(w), y: p.y / Double(h))
                    return PoseJoint(x: v.x, y: v.y, c: p.c)
                }
            }
            return PoseFrame.fromVision(pts: 2.0, points: vision, confidence: k.confidence, uprightWidth: w,
                                        uprightHeight: h, crop: crop)
        }
        XCTAssertTrue(tillbaka[0].joints.allSatisfy { $0 == nil }, "grannen står utanför rutan")
        for (a, b) in zip(tillbaka[1].joints, kandidater[1].joints) {
            let a = try XCTUnwrap(a), b = try XCTUnwrap(b)
            XCTAssertEqual(a.x, b.x, accuracy: 1e-6)
            XCTAssertEqual(a.y, b.y, accuracy: 1e-6)
        }
        XCTAssertEqual(PosePicker.pick(tillbaka, previousHipMid: nil, width: w), 1)
    }

    /// Med ett utsnitt väljs personen i första rutan kring utsnittets mitt, inte bildens.
    func testPersonvaletKringUtsnittetsMitt() {
        func person(_ x: Double) -> PoseFrame {
            var j = [PoseJoint?](repeating: nil, count: 13)
            j[JointSeries.nasa] = PoseJoint(x: x, y: 500, c: 0.9)
            j[JointSeries.hoftV] = PoseJoint(x: x + 40, y: 1050, c: 0.9)
            j[JointSeries.hoftH] = PoseJoint(x: x - 40, y: 1050, c: 0.9)
            j[JointSeries.fotledV] = PoseJoint(x: x + 60, y: 1650, c: 0.9)
            j[JointSeries.fotledH] = PoseJoint(x: x - 60, y: 1650, c: 0.9)
            return PoseFrame(t: 0, pts: 0, joints: j, confidence: 0.9)
        }
        let rutor = [ScannedFrame(pts: 0, candidates: [person(540), person(860)])]
        let utan = PoseTrack.series(rutor, click: 0, width: 1080, height: 1920)
        XCTAssertEqual(utan.frames[0].hipMid?.x ?? .nan, 540, accuracy: 1e-9)
        let med = PoseTrack.series(rutor, click: 0, width: 1080, height: 1920,
                                   crop: CropRect(x: 0.6, y: 0, width: 0.4, height: 1))
        XCTAssertEqual(med.frames[0].hipMid?.x ?? .nan, 860, accuracy: 1e-9)
    }

    func testLinjernaIRutansKoordinater() {
        let o = ImpactOverlay(t: 0, shoulders: [.init(x: 0.5, y: 0.3), .init(x: 0.3, y: 0.3)],
                              hips: [], leftWrist: .init(x: 0.25, y: 0.9), rightWrist: nil)
        let c = o.cropped(CropRect(x: 0.25, y: 0.1, width: 0.5, height: 0.8))
        XCTAssertEqual(c.shoulders[0].x, 0.5, accuracy: 1e-12)
        XCTAssertEqual(c.shoulders[0].y, 0.25, accuracy: 1e-12)
        XCTAssertEqual(c.shoulders[1].x, 0.1, accuracy: 1e-12)
        XCTAssertEqual(c.leftWrist?.x ?? .nan, 0, accuracy: 1e-12)
        XCTAssertEqual(c.leftWrist?.y ?? .nan, 1, accuracy: 1e-12)
        XCTAssertNil(c.rightWrist)
        XCTAssertEqual(o.cropped(nil), o)
    }

    // MARK: Den upprätta bilden och bufferten

    /// Varje orientering: buffert → upprätt → buffert är samma punkt, och EXIF 6 är vad
    /// preferredTransform (0, 1, −1, 0, h, 0) gör med pixlarna i en 480 × 270-buffert.
    func testBuffertOchUppratt() {
        for exif: UInt32 in [1, 3, 6, 8] {
            for (s, t) in [(0.1, 0.2), (0.9, 0.05), (0.5, 0.5)] {
                let u = Orientation.upright(x: s, y: t, exif: exif)
                let b = Orientation.stored(x: u.x, y: u.y, exif: exif)
                XCTAssertEqual(b.x, s, accuracy: 1e-12, "\(exif)")
                XCTAssertEqual(b.y, t, accuracy: 1e-12, "\(exif)")
            }
        }
        // Transformen på en pixel (x, y) i bufferten: (−y + h, x), i den upprätta 270 × 480.
        let (bw, bh) = (480.0, 270.0)
        for (x, y) in [(40.0, 20.0), (120.0, 80.0), (479.0, 0.0)] {
            let px = (-y + bh, x)
            let u = Orientation.upright(x: x / bw, y: y / bh, exif: 6)
            XCTAssertEqual(u.x * bh, px.0, accuracy: 1e-9)
            XCTAssertEqual(u.y * bw, px.1, accuracy: 1e-9)
        }
        let upp = Orientation.uprightSize(width: 480, height: 270, exif: 6)
        XCTAssertEqual(upp.width, 270)
        XCTAssertEqual(upp.height, 480)
    }

    /// Provets markör: en ruta uppe till vänster i bufferten ligger uppe till höger i den
    /// upprätta bilden (EXIF 6), och nere till vänster med EXIF 8.
    func testRektangelnMellanBuffertOchUppratt() {
        let markor = CropRect(x: 40.0 / 480, y: 20.0 / 270, width: 80.0 / 480, height: 60.0 / 270)
        let sex = Orientation.uprightRect(markor, exif: 6)
        assertRect(sex, 1 - 80.0 / 270, 40.0 / 480, 60.0 / 270, 80.0 / 480, accuracy: 1e-12)
        let atta = Orientation.uprightRect(markor, exif: 8)
        assertRect(atta, 20.0 / 270, 1 - 120.0 / 480, 60.0 / 270, 80.0 / 480, accuracy: 1e-12)
        for exif: UInt32 in [1, 3, 6, 8] {
            let r = Orientation.storedRect(Orientation.uprightRect(markor, exif: exif), exif: exif)
            assertRect(r, markor.x, markor.y, markor.width, markor.height, accuracy: 1e-12)
        }
    }

    // MARK: Passet

    func testKlickUtanforFonstretBlirInteSlag() {
        var p = SlagTests.pass(klick: [[1.0, 4.0, 7.5]], langd: 9)
        p.series[0].edit = SeriesEdit(window: TimeWindow(start: 3, end: 7.5))
        XCTAssertEqual(p.series[0].countedClicks.map(\.time), [4.0, 7.5])
        p.syncShots()
        XCTAssertEqual(p.shots.map(\.click.time), [4.0, 7.5])
        XCTAssertEqual(p.shots.map(\.id), ["s01", "s02"])
        XCTAssertEqual(p.series[0].activeWindow, TimeWindow(start: 3, end: 7.5))
        XCTAssertNil(p.series[0].activeCrop)
        // Utan redigering: alla klick och hela filen.
        XCTAssertEqual(SlagTests.pass(klick: [[1.0]], langd: 9).series[0].activeWindow, .full(9))
    }

    /// Vision-passen och klippet stannar inom fönstret och får utsnittet.
    func testAnalysensFonsterInomRedigeringenOchUtsnittetIFragan() throws {
        var p = SlagTests.pass(klick: [[4.0]], langd: 9)
        let crop = CropRect(x: 0.1, y: 0.1, width: 0.6, height: 0.8)
        p.setEdit(SeriesEdit(window: TimeWindow(start: 2.0, end: 4.8), crop: crop), series: 1)
        let fil = URL(fileURLWithPath: "/tmp/01.mov")
        let tatt = try XCTUnwrap(ShotPlan.request(.dense(0), pass: p, file: fil))
        XCTAssertEqual(tatt.from, 2.0)
        XCTAssertEqual(tatt.to, 4.8)
        XCTAssertEqual(tatt.crop, crop)
        let glest = try XCTUnwrap(ShotPlan.request(.sparse(0), pass: p, file: fil))
        XCTAssertEqual(glest.from, 2.4, accuracy: 1e-12)
        XCTAssertEqual(glest.to, 4.1, accuracy: 1e-12)
        let klipp = try XCTUnwrap(ShotPlan.window(ShotPlan.clipWindow, click: 4.0, series: p.series[0]))
        XCTAssertEqual(klipp, 2.0...4.8)
        // Hela bilden: inget utsnitt till Vision.
        p.setEdit(SeriesEdit(window: TimeWindow(start: 2.0, end: 4.8), crop: .full), series: 1)
        XCTAssertNil(try XCTUnwrap(ShotPlan.request(.dense(0), pass: p, file: fil)).crop)
        // Inget kvar av fönstret: nil.
        var s = p.series[0]
        s.edit = SeriesEdit(window: TimeWindow(start: 6, end: 9))
        XCTAssertNil(ShotPlan.window(-2.5 ... -1.0, click: 4.0, series: s))
    }

    /// En ändrad redigering gör om seriens slag: domen (inte Johannes), lederna och klippet
    /// försvinner, filerna som inget längre pekar på svaras, och ett slag utanför fönstret
    /// tas bort. Id:n ges aldrig igen när fönstret vidgas. Samma redigering igen ändrar inget.
    func testAndradRedigeringGorOmSlagenOchSvararFilerna() {
        var p = SlagTests.pass(klick: [[1.0, 4.0], [2.0]], langd: 9)
        p.syncShots()
        for i in p.shots.indices {
            p.shots[i].verdict = .swing
            p.shots[i].joints = ShotRecord.jointsPath(p.shots[i].id)
            p.shots[i].clip = ShotRecord.clipPath(p.shots[i].id)
            p.shots[i].clickInClip = 2.5
        }
        p.shots[1].verdictByJohannes = true
        p.shots[1].verdict = .uncertain
        p.status = .analyzed

        let filer = p.setEdit(SeriesEdit(window: TimeWindow(start: 2.0, end: 9.0)), series: 1)
        XCTAssertEqual(filer, ["Klipp/s01.mov", "Klipp/s02.mov", "Leder/s01.json", "Leder/s02.json"])
        XCTAssertEqual(p.shots.map(\.id), ["s02", "s03"], "klicket vid 1 s utanför: s01 borta")
        XCTAssertEqual(p.shots[0].verdict, .uncertain, "Johannes dom står kvar")
        XCTAssertNil(p.shots[0].joints)
        XCTAssertNil(p.shots[0].clip)
        XCTAssertNil(p.shots[0].clickInClip)
        XCTAssertEqual(p.shots[1].joints, "Leder/s03.json", "den andra serien rörs inte")
        XCTAssertEqual(p.status, .recorded)
        XCTAssertEqual(ShotPlan.next(p), .dense(0))

        // Samma redigering igen: inget görs om.
        p.shots[0].joints = "Leder/s02.json"
        XCTAssertEqual(p.setEdit(SeriesEdit(window: TimeWindow(start: 2.0, end: 9.0)), series: 1), [])
        XCTAssertEqual(p.shots[0].joints, "Leder/s02.json")

        // Fönstret vidgas igen: klicket vid 1 s får ett nytt id.
        p.setEdit(SeriesEdit(window: .full(9)), series: 1)
        XCTAssertEqual(p.shots.map(\.id), ["s04", "s02", "s03"])
        XCTAssertEqual(p.lastShotNumber, 4)
        // En okänd serie: inget.
        XCTAssertEqual(p.setEdit(SeriesEdit(window: .full(9)), series: 7), [])
    }

    /// Redigeringen klampas när den sätts: fönstret i filen och rutan i bilden.
    func testRedigeringenKlampasNarDenSatts() {
        var p = SlagTests.pass(klick: [[4.0]], langd: 9)
        p.setEdit(SeriesEdit(window: TimeWindow(start: -2, end: 20),
                             crop: CropRect(x: 0.9, y: 0.9, width: 0.5, height: 0.5)), series: 1)
        XCTAssertEqual(p.series[0].edit?.window, TimeWindow(start: 0, end: 9))
        assertRect(p.series[0].edit?.crop ?? .full, 0.5, 0.5, 0.5, 0.5)
    }

    /// pass.json bär redigeringen med manifestets namn, och ett pass från före S2i läses.
    func testRedigeringenIPassJsonOchEttGammaltPass() throws {
        var p = SlagTests.pass(klick: [[4.0]], langd: 9)
        p.setEdit(SeriesEdit(window: TimeWindow(start: 1.25, end: 6.5),
                             crop: CropRect(x: 0.125, y: 0.25, width: 0.5, height: 0.625)), series: 1)
        let data = try PassCoding.encoder().encode(p)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        for nyckel in ["\"edit\"", "\"fonster\"", "\"fran_s\" : 1.25", "\"till_s\" : 6.5", "\"utsnitt\"",
                       "\"b\" : 0.5", "\"h\" : 0.625"] {
            XCTAssertTrue(text.contains(nyckel), nyckel)
        }
        let igen = try PassCoding.decoder().decode(PassState.self, from: data)
        XCTAssertEqual(igen, p)

        // Ett pass.json utan edit: serien läses med nil, och alla klick räknas.
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var serier = try XCTUnwrap(json["series"] as? [[String: Any]])
        serier[0].removeValue(forKey: "edit")
        json["series"] = serier
        let gammal = try PassCoding.decoder().decode(PassState.self,
                                                      from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(gammal.series[0].edit)
        XCTAssertEqual(gammal.series[0].countedClicks.count, 1)
    }

    // MARK: Tidslinjen

    func testTidslinjensHandtagSpelhuvudOchKlick() {
        let t = TrimTimeline(window: TimeWindow(start: 2, end: 6), duration: 8, current: 3,
                             clicks: [Click(time: 1, strength: 50), Click(time: 4, strength: 50),
                                      Click(time: 6, strength: 50)])
        XCTAssertEqual(t.start, 0.25)
        XCTAssertEqual(t.end, 0.75)
        XCTAssertEqual(t.playhead, 0.375)
        XCTAssertEqual(t.ticks.map(\.position), [0.125, 0.5, 0.75])
        XCTAssertEqual(t.ticks.map(\.counted), [false, true, true])
        XCTAssertEqual(TrimTimeline.time(at: 0.5, duration: 8), 4)
        XCTAssertEqual(TrimTimeline.time(at: 1.5, duration: 8), 8)
        XCTAssertEqual(TrimTimeline.time(at: .nan, duration: 8), 0)
    }
}
