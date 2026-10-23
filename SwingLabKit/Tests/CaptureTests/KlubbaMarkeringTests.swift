import Foundation
import XCTest
import Swing
import SwingDemo
@testable import Capture

/// S7a: märkningens logik (`ClubMarking`), markeringarna i passet och slagets mått, och
/// `klubba.json` i paketet, på PÅHITTADE svingar (CLAUDE.md, Dataregeln). METOD M45–M49,
/// BESLUT B47
final class KlubbaMarkeringTests: XCTestCase {
    static let nu = Date(timeIntervalSince1970: 1_792_900_000)

    func testTryckenKantenOchUtsnittet() throws {
        var m = ClubMarking(existing: nil, width: 1080, height: 1920, crop: CropRect(x: 0.2, y: 0.1, width: 0.5, height: 0.6))
        // Utsnittet vidgat 15 % per sida (som PC:ns märksida, MF6).
        XCTAssertEqual(m.crop.x, 0.125, accuracy: 1e-3)
        XCTAssertEqual(m.crop.width, 0.65, accuracy: 1e-3)
        XCTAssertEqual(m.position, "P1")
        XCTAssertEqual(m.next, .grip)
        XCTAssertFalse(m.tap(u: 0.02, v: 0.5, t: -1.2), "nära kanten")
        XCTAssertFalse(m.tap(u: 0.5, v: 0.99, t: -1.2), "nära kanten")
        XCTAssertFalse(m.tap(u: -0.2, v: 0.5, t: -1.2), "utanför")
        XCTAssertFalse(m.canUndo)
        XCTAssertTrue(m.tap(u: 0.5, v: 0.5, t: -1.2))
        let g = try XCTUnwrap(m.grip)
        XCTAssertEqual(g.x, (m.crop.x + 0.5 * m.crop.width) * 1080, accuracy: 1e-9)
        XCTAssertEqual(m.surfacePoint(g).u, 0.5, accuracy: 1e-12)
        XCTAssertEqual(m.frameT, -1.2)
        XCTAssertEqual(m.next, .hosel)
        // Hoseln på en annan ruta än greppets blir ingenting: rutan töms först.
        XCTAssertFalse(m.tap(u: 0.6, v: 0.8, t: -1.1))
        // Hoseln: positionen sparas av sig själv med greppets ruta, och nästa position.
        XCTAssertTrue(m.tap(u: 0.6, v: 0.8, t: -1.2, now: Self.nu))
        XCTAssertEqual(m.position, "P2")
        XCTAssertNil(m.frameT)
        let p1 = try XCTUnwrap(m.result.first)
        XCTAssertEqual(p1.t, -1.2)
        XCTAssertEqual(p1.andrad, Self.nu)
        // Ångra efter den sparade positionen: tillbaka till P1 med greppet och dess ruta.
        m.undo()
        XCTAssertEqual(m.position, "P1")
        XCTAssertEqual(m.frameT, -1.2, "ångra söker till den sparade rutan")
        XCTAssertEqual(m.shownTime(measure: nil, impact: 0), -1.2)
        XCTAssertEqual(m.next, .hosel)
        XCTAssertTrue(m.result.isEmpty)
        XCTAssertTrue(m.tap(u: 0.6, v: 0.8, t: -1.2))
        XCTAssertEqual(m.position, "P2")
        m.skip(t: -0.9)
        XCTAssertEqual(m.position, "P3")
        XCTAssertEqual(m.result.map(\.position), ["P1", "P2"])
        XCTAssertEqual(m.result[1].hoppad, true)
        m.undo()
        XCTAssertEqual(m.position, "P2", "den hoppade positionen ångrad")
        // Gå till en sparad position: dess punkter och ruta laddas; ett drag flyttar en punkt
        // och sparar om på samma ruta.
        m.go(to: "P1")
        XCTAssertEqual(m.frameT, -1.2)
        XCTAssertEqual(m.grab(u: 0.61, v: 0.8), .hosel)
        XCTAssertNil(m.grab(u: 0.9, v: 0.2))
        XCTAssertTrue(m.move(.hosel, u: 0.62, v: 0.82))
        XCTAssertFalse(m.move(.hosel, u: 0.999, v: 0.82), "inte till kanten")
        XCTAssertEqual(m.surfacePoint(try XCTUnwrap(m.marks["P1"]?.hosel)).u, 0.62, accuracy: 1e-12)
        XCTAssertEqual(m.marks["P1"]?.t, -1.2)
        m.undo()
        XCTAssertEqual(m.surfacePoint(try XCTUnwrap(m.hosel)).u, 0.6, accuracy: 1e-12, "flytten ångrad")
        XCTAssertTrue(m.advance())
        XCTAssertEqual(m.position, "P2")
    }

    /// Ett steg till en annan ruta när en punkt är satt: punkterna töms (efter appens fråga),
    /// och nästa tryck tar den nya rutan.
    func testStegetTommerPunkterna() {
        var m = ClubMarking(existing: nil, width: 1080, height: 1920, crop: nil)
        XCTAssertTrue(m.tap(u: 0.5, v: 0.5, t: -1.25))
        XCTAssertTrue(m.hasPoints)
        m.clearPoints()
        XCTAssertFalse(m.hasPoints)
        XCTAssertNil(m.frameT)
        XCTAssertTrue(m.tap(u: 0.5, v: 0.5, t: -1.20))
        XCTAssertTrue(m.tap(u: 0.5, v: 0.7, t: -1.20))
        XCTAssertEqual(m.result.first?.t, -1.20, "rutan efter steget")
        m.undo()
        m.undo()
        m.undo()
        XCTAssertEqual(m.frameT, -1.25, "ångra tömningen: den första rutan tillbaka")
    }

    /// Ringen ur handlederna: ett tryck på den blir greppet med egen källa; ett tryck utanför
    /// den är ett fritt grepp.
    func testRingenBlirGreppetMedEgenKalla() throws {
        var m = ClubMarking(existing: nil, width: 1080, height: 1920, crop: nil)
        let ring = KlubbPunkt(x: 540, y: 960)
        XCTAssertTrue(m.tap(u: 0.51, v: 0.5, t: 0, ring: ring))
        XCTAssertEqual(m.grip, ring)
        XCTAssertEqual(m.gripSource, Klubba.kallaRing)
        XCTAssertTrue(m.tap(u: 0.5, v: 0.8, t: 0))
        XCTAssertEqual(m.result[0].greppKalla, Klubba.kallaRing)
        XCTAssertTrue(m.tap(u: 0.3, v: 0.3, t: 0.1, ring: ring))
        XCTAssertEqual(m.gripSource, Klubba.kalla, "utanför ringen: ett fritt tryck")
    }

    func testGestenGlasetOchForslaget() throws {
        XCTAssertEqual(ClubMarking.surface(x: 130, y: 230, width: 260, height: 460).u, 0.5)
        XCTAssertFalse(ClubMarking.isDrag(dx: 2, dy: 3))
        XCTAssertTrue(ClubMarking.isDrag(dx: 3, dy: 3))
        let m = ClubMarking(existing: nil, width: 1080, height: 1920, crop: nil)
        // Glaset förstorar exakt loupeZoom gånger i punkter, kvadratiskt och inom bilden.
        let l = m.loupeCrop(u: 0.5, v: 0.5, surfaceWidthPt: 259, loupePt: 124)
        XCTAssertEqual(m.loupeMagnification(l, surfaceWidthPt: 259, loupePt: 124), ClubMarking.loupeZoom, accuracy: 1e-12)
        XCTAssertEqual(l.width * 1080, l.height * 1920, accuracy: 1e-6)
        let k = m.loupeCrop(u: 0.99, v: 0.01, surfaceWidthPt: 259, loupePt: 124)
        XCTAssertLessThanOrEqual(k.maxX, 1 + 1e-12)
        XCTAssertGreaterThanOrEqual(k.y, 0)
        let mv = ShotMeasure(heightM: 1.8, heightAssumed: false, positions: ["P1": -1.4, "P3": -0.5, "P5": -0.1, "P7": 0])
        var n = m
        n.skip(t: 0)
        XCTAssertEqual(n.shownTime(measure: mv, impact: 0), -0.95, accuracy: 1e-12, "P2 mitt mellan P1 och P3")
    }

    /// Framifrån (S7a-FO, BESLUT B56): samma märkning utan riktpinne, och P2 föreslås där
    /// skaftets vinkel mellan P1 och P3 går genom vågrätt när båda är markerade; annars ur
    /// kroppens positioner. METOD M45
    func testFramifranForeslarRutanUrSkaftet() throws {
        let mv = ShotMeasure(heightM: 1.8, heightAssumed: false, positions: ["P1": -1.2, "P3": -0.4, "P5": -0.1, "P7": 0])
        var m = ClubMarking(existing: nil, width: 1080, height: 1920, crop: nil, view: .fo)
        XCTAssertFalse(m.stickAvailable)
        XCTAssertTrue(ClubMarking(existing: nil, width: 1080, height: 1920, crop: nil).stickAvailable)
        func skaft(_ vinkel: Double, _ langd: Double) -> (u: Double, v: Double) {
            (0.5 + langd * cos(vinkel * .pi / 180) / 1080, 0.6 - langd * sin(vinkel * .pi / 180) / 1920)
        }
        // P1 (−95°, 285 px) markerad med två tryck; P3 saknas: förslaget ur kroppens positioner.
        XCTAssertTrue(m.tap(u: 0.5, v: 0.6, t: -1.2))
        let h1 = skaft(-95, 285)
        XCTAssertTrue(m.tap(u: h1.u, v: h1.v, t: -1.2))
        XCTAssertEqual(m.position, "P2")
        XCTAssertEqual(m.shownTime(measure: mv, impact: 0), -0.8, accuracy: 1e-12, "P3 saknas: mitt mellan P1 och P3")
        // P2 hoppas, P3 (130°, 220 px) markeras, och tillbaka till P2: P2:s hoppade ruta visas.
        m.skip(t: -0.8)
        XCTAssertTrue(m.tap(u: 0.5, v: 0.6, t: -0.4))
        let h3 = skaft(130, 220)
        XCTAssertTrue(m.tap(u: h3.u, v: h3.v, t: -0.4))
        m.go(to: "P2")
        XCTAssertEqual(m.shownTime(measure: mv, impact: 0), -0.8, accuracy: 1e-12, "den sparade rutan går före")
        // Vinkeln går −95° → −180° → 130° (135° medurs) och är vågrät efter 85°.
        let vantad = -1.2 + 0.8 * 85.0 / 135.0
        // Med P3 markerad och P2 omarkerad: förslaget ur skaftet.
        var n = ClubMarking(existing: [
            KlubbMarkering(position: "P1", t: -1.2, grepp: KlubbPunkt(x: 540, y: 1152),
                           hosel: KlubbPunkt(x: 540 + 285 * cos(-95 * .pi / 180), y: 1152 - 285 * sin(-95 * .pi / 180))),
            KlubbMarkering(position: "P3", t: -0.4, grepp: KlubbPunkt(x: 540, y: 1152),
                           hosel: KlubbPunkt(x: 540 + 220 * cos(130 * .pi / 180), y: 1152 - 220 * sin(130 * .pi / 180))),
        ], width: 1080, height: 1920, crop: nil, view: .fo)
        XCTAssertEqual(n.position, "P2")
        XCTAssertEqual(n.shownTime(measure: mv, impact: 0), vantad, accuracy: 1e-9)
        // Bakifrån gäller förslaget ur kroppen (skaftet pekar mot kameran där, M45).
        let d = ClubMarking(existing: n.result, width: 1080, height: 1920, crop: nil, view: .dtl)
        XCTAssertEqual(d.shownTime(measure: mv, impact: 0), -0.8, accuracy: 1e-12)
        // En vänsterspelare speglas: samma tid.
        let speglade = n.result.map { k in
            KlubbMarkering(position: k.position, t: k.t, grepp: k.grepp.map { KlubbPunkt(x: 1080 - $0.x, y: $0.y) },
                           hosel: k.hosel.map { KlubbPunkt(x: 1080 - $0.x, y: $0.y) })
        }
        let v = ClubMarking(existing: speglade, width: 1080, height: 1920, crop: nil, view: .fo, xTecken: -1)
        XCTAssertEqual(v.shownTime(measure: mv, impact: 0), vantad, accuracy: 1e-9)
        n.skip(t: vantad)
        XCTAssertEqual(n.position, "P3")
    }

    /// Två parade telefoner (S2g): FO-slagets markerade P2, P6 och P8 blir DTL-markeringens
    /// förslag på samma tid, förd över med träffens förskjutning, vem som än styr. METOD M45
    func testDTLForeslarFOTidenMedTvaTelefoner() throws {
        let klick = [3.0, 9.5, 16.25]
        func serie(_ vy: Vy, _ forsk: Double, avstand: Double) -> LinkSeries {
            LinkSeries(series: 1, localSeries: 1, passID: "20261103-180000", startHost: nil, frameRate: 240,
                       clicks: klick.map { Click(time: $0 + forsk, strength: 1) }, view: vy, distance: avstand)
        }
        // DTL styr, FO följer: FO:s fil 0,8 s efter, FO 1,0 m längre från bollen.
        let dtlStyr = PairEntry.make(lead: serie(.dtl, 0, avstand: 3), follower: serie(.fo, 0.8, avstand: 4),
                                     followerModel: "iPhone14,5", before: [], after: [])
        XCTAssertFalse(dtlStyr.uncertain)
        XCTAssertEqual(ClubPairTime.partner(dtlStyr, view: .dtl, index: 1), 1)
        XCTAssertEqual(ClubPairTime.partner(dtlStyr, view: .fo, index: 2), 2)
        XCTAssertNil(ClubPairTime.partner(dtlStyr, view: .dtl, index: 7))
        let fo = [KlubbMarkering(position: "P2", t: -0.82, grepp: KlubbPunkt(x: 1, y: 1), hosel: KlubbPunkt(x: 300, y: 1)),
                  KlubbMarkering(position: "P6", t: -0.06, grepp: KlubbPunkt(x: 1, y: 1), hosel: KlubbPunkt(x: 300, y: 1)),
                  KlubbMarkering(position: "P8", t: 0.3, grepp: nil, hosel: nil, hoppad: true),
                  KlubbMarkering(position: "P4", t: -0.3, grepp: KlubbPunkt(x: 1, y: 1), hosel: KlubbPunkt(x: 300, y: 1))]
        let t = ClubPairTime.dtlTimes(fo: fo, foClick: 9.5 + 0.8, dtlClick: 9.5, entry: dtlStyr)
        XCTAssertEqual(Set(t.keys), ["P2", "P6"], "bara skaftets positioner, inte den hoppade")
        // Klicket når FO 1/343 s senare än DTL: samma ögonblick ligger 1/343 s tidigare relativt
        // FO:s klick, så DTL:s tid är FO:s + 1/343 s.
        XCTAssertEqual(t["P2"] ?? .nan, -0.82 + 1.0 / 343, accuracy: 1e-6)
        XCTAssertEqual(t["P6"] ?? .nan, -0.06 + 1.0 / 343, accuracy: 1e-6)
        // FO styr, DTL följer: samma tider.
        let foStyr = PairEntry.make(lead: serie(.fo, 0.8, avstand: 4), follower: serie(.dtl, 0, avstand: 3),
                                    followerModel: "iPhone14,5", before: [], after: [])
        XCTAssertEqual(ClubPairTime.partner(foStyr, view: .dtl, index: 1), 1)
        let u = ClubPairTime.dtlTimes(fo: fo, foClick: 9.5 + 0.8, dtlClick: 9.5, entry: foStyr)
        XCTAssertEqual(u["P2"] ?? .nan, t["P2"] ?? 0, accuracy: 1e-9)
        // DTL-markeringen föreslår den tiden för P2, och kroppens förslag för de andra.
        let mv = ShotMeasure(heightM: 1.8, heightAssumed: false, positions: ["P1": -1.2, "P3": -0.4])
        var m = ClubMarking(existing: nil, width: 1080, height: 1920, crop: nil, view: .dtl)
        XCTAssertEqual(m.shownTime(measure: mv, impact: 0, paired: t), -1.2)
        m.skip(t: -1.2)
        XCTAssertEqual(m.shownTime(measure: mv, impact: 0, paired: t), t["P2"] ?? 0, accuracy: 1e-12)
        XCTAssertEqual(m.shownTime(measure: mv, impact: 0), -0.8, accuracy: 1e-12, "utan par: kroppens")
        // Framifrån används inte FO-tiden från ett par (den är ju FO:s egen).
        var f = ClubMarking(existing: nil, width: 1080, height: 1920, crop: nil, view: .fo)
        f.skip(t: -1.2)
        XCTAssertEqual(f.shownTime(measure: mv, impact: 0, paired: t), -0.8, accuracy: 1e-12)
        // En osäker parning ger inget par.
        var osaker = dtlStyr
        osaker.uncertain = true
        XCTAssertNil(ClubPairTime.partner(osaker, view: .dtl, index: 1))
    }

    /// Trycken på ytan blir samma pixel som PC:n räknar ur `visad` (KlubbYtaFixturer.swift,
    /// tools/pc/klubba.py), och det visade utsnittet är samma pixlar, i båda vyerna. METOD M45
    func testTryckenArSammaPixelSomPC() throws {
        struct Yta: Decodable {
            let vy: Vy
            let utsnitt: [Double]?
            let bredd: Int
            let hojd: Int
            let u: Double
            let v: Double
            let visad: [Int]
            let punkt: [Double]
        }
        let fall = try JSONDecoder().decode([Yta].self, from: Data(KlubbYtaFixturer.json.utf8))
        XCTAssertEqual(fall.count, 5)
        XCTAssertEqual(fall.filter { $0.vy == .fo }.count, 2, "framifrån prövas")
        for f in fall {
            let c = f.utsnitt.map { CropRect(x: $0[0], y: $0[1], width: $0[2], height: $0[3]) }
            let m = ClubMarking(existing: nil, width: f.bredd, height: f.hojd, crop: c, view: f.vy)
            let px = ClubMarking.shownCrop(c).pixels(width: f.bredd, height: f.hojd)
            XCTAssertEqual([px.x, px.y, px.width, px.height], f.visad)
            let p = try XCTUnwrap(m.imagePoint(u: f.u, v: f.v))
            XCTAssertEqual(p.x, f.punkt[0], accuracy: 1e-9)
            XCTAssertEqual(p.y, f.punkt[1], accuracy: 1e-9)
        }
    }

    /// Markeringarna i slaget mäter om det: klubbmåtten bland slagets mått och P2 som rutan
    /// som valdes; pass.json bär dem, och ett pass utan fältet läses som förut.
    func testMarkeringarnaMaterOmSlaget() throws {
        let sv = DemoSving.dtl(thrust: (topp: -2, traff: 3, finish: 8))
        let serie = MatningTests.serie(sv)
        var pass = PassState(id: "20261103-180000", created: Date(timeIntervalSince1970: 1_792_848_612),
                             setup: PassSetup(view: .dtl, club: "j7", distance: 3, hand: .hoger),
                             shots: [MatningTests.slag()])
        pass.measureShots(height: 1.8) { _ in serie }
        let fore = try XCTUnwrap(pass.shots[0].measure)
        let p1 = try XCTUnwrap(fore.positions["P1"]), p4 = fore.positions["P4"]!
        let k1 = serie.frames.min { abs($0.t - p1) < abs($1.t - p1) }!
        let k4 = serie.frames.min { abs($0.t - p4) < abs($1.t - p4) }!
        let t2 = try XCTUnwrap(Klubba.forslagTid("P2", positioner: fore.positions))
        let marks = [
            KlubbMarkering(position: "P4", t: k4.t, grepp: KlubbPunkt(x: 500, y: 900), hosel: KlubbPunkt(x: 500, y: 1100)),
            KlubbMarkering(position: "P1", t: k1.t, grepp: KlubbPunkt(x: 500, y: 1300), hosel: KlubbPunkt(x: 700, y: 1646.4)),
            KlubbMarkering(position: "P2", t: t2, grepp: KlubbPunkt(x: 500, y: 1200), hosel: KlubbPunkt(x: 800, y: 1300)),
            KlubbMarkering(position: "P8", t: 0.3, grepp: nil, hosel: nil, hoppad: true),
        ]
        pass.heightM = 1.8
        pass.setClubMarks(marks, shot: "s01", joints: serie)
        let m = try XCTUnwrap(pass.shots[0].measure)
        XCTAssertEqual(pass.shots[0].klubba?.map(\.position), ["P1", "P2", "P4", "P8"], "i positionernas ordning")
        XCTAssertEqual(m.values["skaft_vinkel_p4"] ?? .nan, -90, accuracy: 1e-9)
        XCTAssertEqual(m.values["skaftplan_p1"] ?? .nan, 60, accuracy: 0.01)
        XCTAssertEqual(m.positions["P2"], t2)
        XCTAssertNil(m.positions["P8"])
        XCTAssertEqual(m.klubbaFlyktpunktAntagen, true, "ingen riktpinne")
        XCTAssertEqual(m.values["backen_thrust_traff"], fore.values["backen_thrust_traff"], "kroppens mått orörda")
        XCTAssertEqual(pass.clubMarkedCount, 1)
        XCTAssertEqual(pass.visningsPass.klubbMarkerade, 1)
        // Riktpinnen i serien mäter om slaget och flyktpunkten är inte längre antagen.
        pass.series = [SeriesRecord(nr: 1, source: .recording, club: "j7", file: "Video/01.mov", start: pass.created,
                                    startHost: nil, duration: 9, bytes: 1, timing: FrameTiming.analyze([0, 1.0 / 240]),
                                    clicks: [], orientation: 6, uprightWidth: 1080, uprightHeight: 1920)]
        pass.setRiktpinne([KlubbPunkt(x: 560, y: 1800), KlubbPunkt(x: 548, y: 1300)], series: 1) { _ in serie }
        XCTAssertEqual(pass.shots[0].measure?.klubbaFlyktpunktAntagen, false)
        // pass.json tur och retur; ett slag utan fältet läses utan markeringar.
        let data = try PassCoding.encoder().encode(pass)
        let tillbaka = try PassCoding.decoder().decode(PassState.self, from: data)
        XCTAssertEqual(tillbaka.shots[0].klubba, pass.shots[0].klubba)
        XCTAssertEqual(tillbaka.series[0].riktpinne, pass.series[0].riktpinne)
        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        var slag = try XCTUnwrap(json["shots"] as? [[String: Any]])
        slag[0].removeValue(forKey: "klubba")
        json["shots"] = slag
        let gammal = try PassCoding.decoder().decode(PassState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(gammal.shots[0].klubba)
        // Inga markeringar: måtten som förut.
        pass.setClubMarks([], shot: "s01", joints: serie)
        XCTAssertNil(pass.shots[0].klubba)
        XCTAssertNil(pass.shots[0].measure?.values["skaft_vinkel_p4"])
    }

    /// klubba.json i paketet (BESLUT B47): version 2, en ruta per markering, klipptiden när
    /// rutan ligger i klippet, greppets källa, `andrad` när markeringen ändrades, och bara
    /// slag i manifestet; riktpinnen i manifestets serie.
    func testKlubbaJsonIPaketet() throws {
        var p = PaketTests.pass()
        XCTAssertNil(PassPackage.clubFile(pass: p, manifest: PackageManifest.make(
            pass: p, app: PaketTests.app, phone: PaketTests.phone, created: PaketTests.skapad, timeZone: PaketTests.zon,
            includeClips: true)), "inga markeringar: ingen fil")
        p.shots[0].klubba = [
            KlubbMarkering(position: "P1", t: -1.25, grepp: KlubbPunkt(x: 10, y: 20), hosel: KlubbPunkt(x: 30, y: 80),
                           greppKalla: Klubba.kallaRing, andrad: Self.nu),
            KlubbMarkering(position: "P8", t: 0.3, grepp: nil, hosel: nil, hoppad: true),
            KlubbMarkering(position: "P10", t: -3.0, grepp: nil, hosel: nil, hoppad: true)]   // före klippet
        p.shots[3].klubba = p.shots[0].klubba                     // leder saknas: inte i paketet
        p.series[0].riktpinne = [KlubbPunkt(x: 500, y: 1800), KlubbPunkt(x: 490, y: 1300)]
        for klipp in [true, false] {
            let man = PackageManifest.make(pass: p, app: PaketTests.app, phone: PaketTests.phone,
                                           created: PaketTests.skapad, timeZone: PaketTests.zon, includeClips: klipp)
            XCTAssertEqual(man.series[0].riktpinne, [[500, 1800], [490, 1300]])
            XCTAssertNil(man.series[1].riktpinne)
            let fil = try XCTUnwrap(PassPackage.clubFile(pass: p, manifest: man, timeZone: PaketTests.zon))
            XCTAssertEqual(fil.format, "swinglab-klubba/2")
            XCTAssertEqual(fil.pass, p.id)
            XCTAssertEqual(fil.kalla, [PassPackage.fileName(p)])
            XCTAssertEqual(fil.andrad, PackageManifest.timestamp(Self.nu, timeZone: PaketTests.zon))
            let vy = p.setup.view.rawValue
            XCTAssertEqual(fil.rutor.map(\.id), ["\(vy)-s01-P1", "\(vy)-s01-P8", "\(vy)-s01-P10"])
            XCTAssertEqual(fil.rutor.map(\.status), ["markerad", "hoppad", "hoppad"])
            XCTAssertNil(fil.rutor[2].tKlipp, "rutan ligger före klippet")
            if klipp {
                XCTAssertEqual(fil.rutor[0].tKlipp ?? .nan, -1.25 + 2.5021, accuracy: 1e-12)
            } else {
                XCTAssertNil(fil.rutor[0].tKlipp)
            }
            XCTAssertNil(fil.rutor[0].forskjutningMs)
            XCTAssertEqual(fil.rutor[0].punkter.grepp, .klick(x: 10, y: 20, kalla: Klubba.kallaRing))
            XCTAssertEqual(fil.rutor[0].punkter.klubbhuvud, .klick(x: 30, y: 80, kalla: Klubba.kalla))
            XCTAssertEqual(fil.rutor[0].punkter.skaftMitt, nil)
            let parts = try PassPackage.parts(pass: p, manifest: man, device: nil)
            var hittad: Data? = nil
            for (namn, kalla) in parts where namn == "klubba.json" {
                if case .data(let d) = kalla { hittad = d }
            }
            let data = try XCTUnwrap(hittad)
            // null-fälten står med, som formatet kräver (PC:ns kontroll).
            let j = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            let r0 = try XCTUnwrap((j["rutor"] as? [[String: Any]])?.first)
            XCTAssertTrue(r0["forskjutning_ms"] is NSNull)
            XCTAssertTrue((r0["punkter"] as? [String: Any])?["skaft_mitt"] is NSNull)
            let lasta = try XCTUnwrap(try KlubbFil.las(data).markeringar()["s01"])
            XCTAssertEqual(lasta.map(\.greppKalla), [Klubba.kallaRing, nil, nil])
            XCTAssertEqual(lasta.map(\.position), ["P1", "P8", "P10"])
        }
    }
}
