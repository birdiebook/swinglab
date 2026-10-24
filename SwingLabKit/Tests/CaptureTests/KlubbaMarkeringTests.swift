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
        var m = ClubMarking(existing: nil, width: 1080, height: 1920, crop: CropRect(x: 0.2, y: 0.1, width: 0.5, height: 0.6),
                            view: .dtl, xTecken: 1)
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
        XCTAssertEqual(m.position, "P3", "kroppens positioner först (BESLUT B58)")
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
        XCTAssertEqual(m.position, "P3")
        m.skip(t: -0.6)
        XCTAssertEqual(m.position, "P4")
        XCTAssertEqual(m.result.map(\.position), ["P1", "P3"])
        XCTAssertEqual(m.result[1].hoppad, true)
        m.undo()
        XCTAssertEqual(m.position, "P3", "den hoppade positionen ångrad")
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
        XCTAssertEqual(m.position, "P3")
    }

    /// Ett steg till en annan ruta när en punkt är satt: punkterna töms (efter appens fråga),
    /// och nästa tryck tar den nya rutan.
    func testStegetTommerPunkterna() {
        var m = ClubMarking(existing: nil, width: 1080, height: 1920, crop: nil, view: .dtl, xTecken: 1)
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
        var m = ClubMarking(existing: nil, width: 1080, height: 1920, crop: nil, view: .dtl, xTecken: 1)
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
        let m = ClubMarking(existing: nil, width: 1080, height: 1920, crop: nil, view: .dtl, xTecken: 1)
        // Glaset förstorar exakt loupeZoom gånger i punkter, kvadratiskt och inom bilden.
        let l = m.loupeCrop(u: 0.5, v: 0.5, surfaceWidthPt: 259, loupePt: 124)
        XCTAssertEqual(m.loupeMagnification(l, surfaceWidthPt: 259, loupePt: 124), ClubMarking.loupeZoom, accuracy: 1e-12)
        XCTAssertEqual(l.width * 1080, l.height * 1920, accuracy: 1e-6)
        let k = m.loupeCrop(u: 0.99, v: 0.01, surfaceWidthPt: 259, loupePt: 124)
        XCTAssertLessThanOrEqual(k.maxX, 1 + 1e-12)
        XCTAssertGreaterThanOrEqual(k.y, 0)
        let mv = ShotMeasure(heightM: 1.8, heightAssumed: false, positions: ["P1": -1.4, "P3": -0.5, "P5": -0.1, "P7": 0])
        var n = m
        n.go(to: "P2")
        XCTAssertEqual(n.shownTime(measure: mv, impact: 0), -0.95, accuracy: 1e-12, "P2 mitt mellan P1 och P3")
    }

    /// Framifrån (S7a-FO, BESLUT B57, B58): samma märkning utan riktpinne, kroppens positioner
    /// först och skaftets sist, och P2, P6 och P8 föreslås där skaftets vinkel mellan ändarna
    /// går genom vågrätt (P2 från baksvingens start). Talen här räknas för hand ur de satta
    /// vinklarna, inte med `Klubba.forslagTidSkaft`. METOD M45
    func testFramifranForeslarRutanUrSkaftet() throws {
        var mv = ShotMeasure(heightM: 1.8, heightAssumed: false,
                             positions: ["P1": -1.2, "P3": -0.4, "P4": -0.25, "P5": -0.1, "P7": 0, "P9": 0.3, "P10": 1.0])
        mv.start = -1.0
        var m = ClubMarking(existing: nil, width: 1080, height: 1920, crop: nil, view: .fo, xTecken: 1)
        XCTAssertFalse(m.stickAvailable)
        XCTAssertTrue(ClubMarking(existing: nil, width: 1080, height: 1920, crop: nil, view: .dtl, xTecken: 1).stickAvailable)
        let satta: [String: Double] = ["P1": -95, "P3": 130, "P4": 10, "P5": 100, "P7": -104, "P9": 80, "P10": -20,
                                       "P2": 178, "P6": 178, "P8": 2]
        func hosel(_ vinkel: Double) -> (u: Double, v: Double) {
            (0.5 + 300 * cos(vinkel * .pi / 180) / 1080, 0.6 - 300 * sin(vinkel * .pi / 180) / 1920)
        }
        var ordning: [String] = []
        var forslag: [String: Double] = [:]
        while !m.done {
            let p = m.position
            ordning.append(p)
            let t = m.shownTime(measure: mv, impact: 0)
            if Klubba.skaftets.contains(p) { forslag[p] = t }
            XCTAssertTrue(m.tap(u: 0.5, v: 0.6, t: t), p)
            let h = hosel(try XCTUnwrap(satta[p]))
            XCTAssertTrue(m.tap(u: h.u, v: h.v, t: t), p)
        }
        XCTAssertEqual(ordning, ["P1", "P3", "P4", "P5", "P7", "P9", "P10", "P2", "P6", "P8"], "nästa position av sig själv")
        XCTAssertEqual(m.result.map(\.position), Klubba.positioner, "sparat i svingens ordning")
        // P2: −95° → −180° → 130° är 135° medurs och vågrätt efter 85°, räknat från starten −1,0 s
        // (inte från P1 −1,2 s) till P3 −0,4 s.
        XCTAssertEqual(forslag["P2"] ?? .nan, -1.0 + 0.6 * 85.0 / 135.0, accuracy: 1e-9)
        // P6: 100° → 180° → 256° (P7 −104°) är 156° moturs, vågrätt efter 80°; P8: −104° → 0° → 80°.
        XCTAssertEqual(forslag["P6"] ?? .nan, -0.1 + 0.1 * 80.0 / 156.0, accuracy: 1e-9)
        XCTAssertEqual(forslag["P8"] ?? .nan, 0.3 * 104.0 / 184.0, accuracy: 1e-9)

        // En hoppad P2 visar förslaget, inte den hoppade rutan; en markerad position sin egen ruta.
        var marks = m.result
        let i2 = try XCTUnwrap(marks.firstIndex { $0.position == "P2" })
        marks[i2] = KlubbMarkering(position: "P2", t: -0.9, grepp: nil, hosel: nil, hoppad: true)
        var n = ClubMarking(existing: marks, width: 1080, height: 1920, crop: nil, view: .fo, xTecken: 1)
        n.go(to: "P2")
        XCTAssertNil(n.frameT)
        XCTAssertEqual(n.shownTime(measure: mv, impact: 0), forslag["P2"] ?? .nan, accuracy: 1e-9)
        n.go(to: "P3")
        XCTAssertEqual(n.shownTime(measure: mv, impact: 0), -0.4, "den markerade rutan går före")
        // Utan förslag (inga mått, P3 hoppad): den hoppade rutan.
        let i3 = try XCTUnwrap(marks.firstIndex { $0.position == "P3" })
        var utanP3 = marks
        utanP3[i3] = KlubbMarkering(position: "P3", t: -0.4, grepp: nil, hosel: nil, hoppad: true)
        var o = ClubMarking(existing: utanP3, width: 1080, height: 1920, crop: nil, view: .fo, xTecken: 1)
        o.go(to: "P2")
        XCTAssertEqual(o.shownTime(measure: nil, impact: 0), -0.9)
        XCTAssertEqual(o.shownTime(measure: mv, impact: 0), -0.8, accuracy: 1e-12, "kroppens: mitt mellan P1 och P3")
        // Fel håll: P3 vid −85° (10° moturs från P1) ger inget förslag ur skaftet, utan kroppens.
        var felHall = marks
        felHall[i3] = KlubbMarkering(position: "P3", t: -0.4, grepp: KlubbPunkt(x: 540, y: 1152),
                                     hosel: KlubbPunkt(x: 540 + 300 * cos(-85 * .pi / 180),
                                                       y: 1152 - 300 * sin(-85 * .pi / 180)))
        var f = ClubMarking(existing: felHall, width: 1080, height: 1920, crop: nil, view: .fo, xTecken: 1)
        f.go(to: "P2")
        XCTAssertEqual(f.shownTime(measure: mv, impact: 0), -0.8, accuracy: 1e-12)
        // Bakifrån gäller kroppens förslag (skaftet pekar mot kameran där, M45).
        var d = ClubMarking(existing: marks, width: 1080, height: 1920, crop: nil, view: .dtl, xTecken: 1)
        d.go(to: "P2")
        XCTAssertEqual(d.shownTime(measure: mv, impact: 0), -0.8, accuracy: 1e-12)
        // En vänsterspelare speglas: samma tid.
        let speglade = marks.map { k in
            KlubbMarkering(position: k.position, t: k.t, grepp: k.grepp.map { KlubbPunkt(x: 1080 - $0.x, y: $0.y) },
                           hosel: k.hosel.map { KlubbPunkt(x: 1080 - $0.x, y: $0.y) }, hoppad: k.hoppad)
        }
        var v = ClubMarking(existing: speglade, width: 1080, height: 1920, crop: nil, view: .fo, xTecken: -1)
        v.go(to: "P2")
        XCTAssertEqual(v.shownTime(measure: mv, impact: 0), forslag["P2"] ?? .nan, accuracy: 1e-9)
    }

    /// Två parade telefoner (S2g): FO-slagets markerade P2, P6 och P8 blir DTL-markeringens
    /// förslag på samma tid, förd över med träffens förskjutning, vem som än styr; klicken tas ur
    /// paret med index, och en parning som inte är DTL mot FO ger inget. METOD M45
    func testDTLForeslarFOTidenMedTvaTelefoner() throws {
        let klick = [3.0, 9.5, 16.25]
        func serie(_ vy: Vy, _ forsk: Double, avstand: Double) -> LinkSeries {
            LinkSeries(series: 1, localSeries: 1, passID: "20261103-180000", startHost: nil, frameRate: 240,
                       clicks: klick.map { Click(time: $0 + forsk, strength: 1) }, view: vy, distance: avstand)
        }
        let dtlKlick = klick, foKlick = klick.map { $0 + 0.8 }
        // DTL styr, FO följer: FO:s fil 0,8 s efter, FO 1,0 m längre från bollen.
        let dtlStyr = PairEntry.make(lead: serie(.dtl, 0, avstand: 3), follower: serie(.fo, 0.8, avstand: 4),
                                     followerModel: "iPhone14,5", before: [], after: [])
        XCTAssertFalse(dtlStyr.uncertain)
        XCTAssertEqual(ClubPairTime.pair(dtlStyr, leadView: .dtl, dtlIndex: 1)?.fo, 1)
        XCTAssertNil(ClubPairTime.pair(dtlStyr, leadView: .dtl, dtlIndex: 7))
        XCTAssertNil(ClubPairTime.pair(dtlStyr, leadView: .fo, dtlIndex: 1), "FO mot FO är inget DTL-par")
        let fo = [KlubbMarkering(position: "P2", t: -0.82, grepp: KlubbPunkt(x: 1, y: 1), hosel: KlubbPunkt(x: 300, y: 1)),
                  KlubbMarkering(position: "P6", t: -0.06, grepp: KlubbPunkt(x: 1, y: 1), hosel: KlubbPunkt(x: 300, y: 1)),
                  KlubbMarkering(position: "P8", t: 0.3, grepp: nil, hosel: nil, hoppad: true),
                  KlubbMarkering(position: "P4", t: -0.3, grepp: KlubbPunkt(x: 1, y: 1), hosel: KlubbPunkt(x: 300, y: 1))]
        let t = ClubPairTime.dtlTimes(fo: fo, entry: dtlStyr, leadView: .dtl, dtlIndex: 1, dtlClicks: dtlKlick,
                                      foClicks: foKlick)
        XCTAssertEqual(Set(t.keys), ["P2", "P6"], "bara skaftets positioner, inte den hoppade")
        // Klicket når FO 1/343 s senare än DTL: samma ögonblick ligger 1/343 s tidigare relativt
        // FO:s klick, så DTL:s tid är FO:s + 1/343 s.
        XCTAssertEqual(t["P2"] ?? .nan, -0.82 + 1.0 / 343, accuracy: 1e-6)
        XCTAssertEqual(t["P6"] ?? .nan, -0.06 + 1.0 / 343, accuracy: 1e-6)
        // Klicken ur paret: slaget med klick 2 får samma tider relativt sitt eget klick.
        let t2 = ClubPairTime.dtlTimes(fo: fo, entry: dtlStyr, leadView: .dtl, dtlIndex: 2, dtlClicks: dtlKlick,
                                       foClicks: foKlick)
        XCTAssertEqual(t2["P2"] ?? .nan, t["P2"] ?? 0, accuracy: 1e-9)
        XCTAssertTrue(ClubPairTime.dtlTimes(fo: fo, entry: dtlStyr, leadView: .dtl, dtlIndex: 1, dtlClicks: dtlKlick,
                                            foClicks: [3.8]).isEmpty, "FO:s klick saknas")
        // FO styr, DTL följer: samma tider.
        let foStyr = PairEntry.make(lead: serie(.fo, 0.8, avstand: 4), follower: serie(.dtl, 0, avstand: 3),
                                    followerModel: "iPhone14,5", before: [], after: [])
        XCTAssertEqual(ClubPairTime.pair(foStyr, leadView: .fo, dtlIndex: 1)?.fo, 1)
        let u = ClubPairTime.dtlTimes(fo: fo, entry: foStyr, leadView: .fo, dtlIndex: 1, dtlClicks: dtlKlick,
                                      foClicks: foKlick)
        XCTAssertEqual(u["P2"] ?? .nan, t["P2"] ?? 0, accuracy: 1e-9)
        // Två DTL-telefoner, eller en osäker parning: inget par.
        let dtlDtl = PairEntry.make(lead: serie(.dtl, 0, avstand: 3), follower: serie(.dtl, 0.8, avstand: 4),
                                    followerModel: "iPhone14,5", before: [], after: [])
        XCTAssertNil(ClubPairTime.pair(dtlDtl, leadView: .dtl, dtlIndex: 1))
        var osaker = dtlStyr
        osaker.uncertain = true
        XCTAssertNil(ClubPairTime.pair(osaker, leadView: .dtl, dtlIndex: 1))
        // DTL-markeringen föreslår den tiden för P2, också när P2 är hoppad, och kroppens utan par.
        let mv = ShotMeasure(heightM: 1.8, heightAssumed: false, positions: ["P1": -1.2, "P3": -0.4])
        var m = ClubMarking(existing: nil, width: 1080, height: 1920, crop: nil, view: .dtl, xTecken: 1)
        m.go(to: "P2")
        XCTAssertEqual(m.shownTime(measure: mv, impact: 0, paired: t), t["P2"] ?? 0, accuracy: 1e-12)
        XCTAssertEqual(m.shownTime(measure: mv, impact: 0), -0.8, accuracy: 1e-12, "utan par: kroppens")
        m.skip(t: -0.5)
        m.go(to: "P2")
        XCTAssertEqual(m.shownTime(measure: mv, impact: 0, paired: t), t["P2"] ?? 0, accuracy: 1e-12)
        // Framifrån används inte FO-tiden från ett par (den är ju FO:s egen).
        var f = ClubMarking(existing: nil, width: 1080, height: 1920, crop: nil, view: .fo, xTecken: 1)
        f.go(to: "P2")
        XCTAssertEqual(f.shownTime(measure: mv, impact: 0, paired: t), -0.8, accuracy: 1e-12)
    }

    /// Trycken på ytan blir samma pixel som PC:n räknar ur `visad` (KlubbYtaFixturer.swift,
    /// tools/pc/klubba.py), och det visade utsnittet är samma pixlar, i båda vyerna (vyn ingår
    /// inte). METOD M45
    func testTryckenArSammaPixelSomPC() throws {
        struct Zoom: Decodable {
            let hander: [Double]
            let cm_per_px: Double?
            let rect: [Double]
        }
        struct Yta: Decodable {
            let utsnitt: [Double]?
            let bredd: Int
            let hojd: Int
            let u: Double
            let v: Double
            let visad: [Int]
            let zoom: Zoom?
            let punkt: [Double]
        }
        let fall = try JSONDecoder().decode([Yta].self, from: Data(KlubbYtaFixturer.json.utf8))
        XCTAssertEqual(fall.count, 9)
        XCTAssertEqual(fall.filter { $0.zoom != nil }.count, 4, "inzoomat (S7c)")
        for f in fall {
            let c = f.utsnitt.map { CropRect(x: $0[0], y: $0[1], width: $0[2], height: $0[3]) }
            let px = ClubMarking.shownCrop(c).pixels(width: f.bredd, height: f.hojd)
            XCTAssertEqual([px.x, px.y, px.width, px.height], f.visad)
            // Vyn ingår inte i trycket: samma pixel i båda.
            for vy in [Vy.dtl, .fo] {
                var m = ClubMarking(existing: nil, width: f.bredd, height: f.hojd, crop: c, view: vy, xTecken: 1)
                if let z = f.zoom {
                    // Startzoomen kring händerna, med skaftets längd ur skalan, som PC:ns zoom_start.
                    m.startZoom(hands: KlubbPunkt(x: z.hander[0], y: z.hander[1]), cmPerPx: z.cm_per_px)
                    let r = [m.zoom.x * Double(f.bredd), m.zoom.y * Double(f.hojd), m.zoom.width * Double(f.bredd),
                             m.zoom.height * Double(f.hojd)]
                    for (a, b) in zip(r, z.rect) { XCTAssertEqual(a, b, accuracy: 1e-6) }
                }
                let p = try XCTUnwrap(m.imagePoint(u: f.u, v: f.v))
                XCTAssertEqual(p.x, f.punkt[0], accuracy: 1e-6)
                XCTAssertEqual(p.y, f.punkt[1], accuracy: 1e-6)
            }
        }
    }

    /// Positionen i klartext i märkningens ordning (S7c, BESLUT B58, B59), namnen för P1–P10, och
    /// riktpinnens steg bakifrån en gång per serie före P1.
    func testPositionenIKlartextOchRiktpinnensSteg() throws {
        let nbsp = "\u{00A0}"
        var m = ClubMarking(existing: nil, width: 1080, height: 1920, crop: nil, view: .fo, xTecken: 1)
        XCTAssertEqual(m.positionLine, "P1\(nbsp)· Address\(nbsp)· 1 of 10")
        m.skip(t: -1.2)
        XCTAssertEqual(m.positionLine, "P3\(nbsp)· Lead arm parallel, backswing\(nbsp)· 2 of 10")
        m.go(to: "P4")
        XCTAssertEqual(m.positionLine, "P4\(nbsp)· Top of backswing\(nbsp)· 3 of 10")
        m.go(to: "P8")
        XCTAssertEqual(m.positionLine, "P8\(nbsp)· Club parallel, follow-through\(nbsp)· 10 of 10")
        XCTAssertEqual(Set(Texter.positionsnamn.keys), Set(Klubba.positioner))
        for (p, namn) in Texter.positionsnamn {
            XCTAssertNil(namn.range(of: "[åäöÅÄÖ]", options: .regularExpression), p)
            XCTAssertFalse(namn.lowercased().contains("hosel"), p)
        }
        // Riktpinnens steg: bakifrån, när serien saknar pinne och steget inte hoppats över.
        var pass = PassState(id: "20261103-180000", created: Date(timeIntervalSince1970: 1_792_848_612),
                             setup: PassSetup(view: .dtl, club: "j7", distance: 3, hand: .hoger), shots: [])
        pass.series = [SeriesRecord(nr: 1, source: .recording, club: "j7", file: "Video/01.mov", start: pass.created,
                                    startHost: nil, duration: 9, bytes: 1, timing: FrameTiming.analyze([0, 1.0 / 240]),
                                    clicks: [], orientation: 6, uprightWidth: 1080, uprightHeight: 1920)]
        XCTAssertTrue(pass.asksForRiktpinne(series: 1))
        pass.skipRiktpinne(series: 1)
        XCTAssertFalse(pass.asksForRiktpinne(series: 1), "hoppat över: frågar inte igen")
        let data = try PassCoding.encoder().encode(pass)
        XCTAssertEqual(try PassCoding.decoder().decode(PassState.self, from: data).series[0].riktpinneHoppad, true)
        pass.series[0].riktpinneHoppad = nil
        pass.setRiktpinne([KlubbPunkt(x: 560, y: 1800), KlubbPunkt(x: 548, y: 1300)], series: 1) { _ in nil }
        XCTAssertFalse(pass.asksForRiktpinne(series: 1), "pinnen finns")
        pass.setup.view = .fo
        pass.series[0].riktpinne = nil
        XCTAssertFalse(pass.asksForRiktpinne(series: 1), "framifrån aldrig")
        // Guiden visas en gång: inställningen sparas per användare.
        var installningar = AppSettings()
        XCTAssertNil(installningar.clubGuideSeen)
        installningar.clubGuideSeen = true
        let sparad = try PassCoding.decoder().decode(AppSettings.self, from: PassCoding.encoder().encode(installningar))
        XCTAssertEqual(sparad.clubGuideSeen, true)
    }

    /// Skip på en markerad position är Next och nollar den aldrig; nästa position efter en sparad
    /// är nästa som saknar markering; ett helt markerat slag öppnas klart; och punkt 2 på punkt 1
    /// blir ingen punkt (granskningen av S7c). METOD M45
    func testSkipNollarAldrigEnMarkering() throws {
        func m(_ p: String, _ t: Double) -> KlubbMarkering {
            KlubbMarkering(position: p, t: t, grepp: KlubbPunkt(x: 500, y: 900), hosel: KlubbPunkt(x: 520, y: 1200))
        }
        let alla = Klubba.positioner.enumerated().map { m($1, Double($0) * 0.1 - 1) }
        // Helt markerat: klart, och Skip gör ingenting.
        var klar = ClubMarking(existing: alla, width: 1080, height: 1920, crop: nil, view: .dtl, xTecken: 1)
        XCTAssertTrue(klar.done)
        XCTAssertNil(klar.positionLine)
        klar.skip(t: 0)
        XCTAssertEqual(klar.result, alla)
        // Tillbaka till en markerad position: Skip är Next och lämnar markeringen orörd.
        klar.go(to: "P4")
        XCTAssertTrue(klar.isMarked)
        klar.skip(t: 0.5)
        XCTAssertEqual(klar.result, alla, "markeringen står kvar")
        XCTAssertTrue(klar.done, "ingen position saknar markering")
        // Med luckor: nästa som saknar markering, också bakåt i ordningen.
        let utan = alla.filter { !["P3", "P8"].contains($0.position) }
        var x = ClubMarking(existing: utan, width: 1080, height: 1920, crop: nil, view: .dtl, xTecken: 1)
        XCTAssertEqual(x.position, "P3", "den första omarkerade")
        x.go(to: "P5")
        XCTAssertTrue(x.isMarked)
        x.skip(t: 0.5)
        XCTAssertEqual(x.position, "P8", "Next: nästa som saknar markering")
        XCTAssertEqual(x.result.count, utan.count, "inget skrivet")
        XCTAssertTrue(x.tap(u: 0.5, v: 0.5, t: 0.4))
        // Punkt 2 på punkt 1: ingen punkt.
        XCTAssertFalse(x.tap(u: 0.51, v: 0.5, t: 0.4), "klubbhuvudet på greppet")
        XCTAssertEqual(x.next, .hosel)
        XCTAssertTrue(x.tap(u: 0.5, v: 0.7, t: 0.4))
        XCTAssertEqual(x.position, "P3", "runt till början: P3 saknas")
        x.skip(t: -0.7)
        XCTAssertTrue(x.done)
        XCTAssertEqual(x.result.first { $0.position == "P3" }?.hoppad, true)
        XCTAssertEqual(x.result.first { $0.position == "P5" }, utan.first { $0.position == "P5" })
    }

    /// Zoomen (S7c): nypet håller bildens punkt under fingrarna, dragningen flyttar det som syns
    /// inom ytan, dubbeltrycket (hela ytan) och startzoomen kring positionens egen markering;
    /// trycken blir hela bildens pixlar i varje läge och glaset förstorar fortfarande 3 ×. METOD M45
    func testZoomenHallerTryckenIBildensPixlar() throws {
        var m = ClubMarking(existing: nil, width: 1080, height: 1920, crop: nil, view: .dtl, xTecken: 1)
        XCTAssertEqual(m.zoomFactor, 1, accuracy: 1e-12)
        m.startZoom(hands: KlubbPunkt(x: 540, y: 960), cmPerPx: nil)
        XCTAssertEqual(m.zoomFactor, ClubMarking.zoomStart, accuracy: 1e-12)
        let fore = try XCTUnwrap(m.imagePoint(u: 0.3, v: 0.4))
        m.zoom(by: 2, u: 0.3, v: 0.4)
        XCTAssertEqual(m.zoomFactor, 5, accuracy: 1e-9)
        let efter = try XCTUnwrap(m.imagePoint(u: 0.3, v: 0.4))
        XCTAssertEqual(efter.x, fore.x, accuracy: 1e-6, "punkten under fingrarna står kvar")
        XCTAssertEqual(efter.y, fore.y, accuracy: 1e-6)
        m.zoom(by: 100, u: 0.5, v: 0.5)
        XCTAssertEqual(m.zoomFactor, ClubMarking.zoomMax, accuracy: 1e-9)
        m.zoom(by: 0.001, u: 0.5, v: 0.5)
        XCTAssertEqual(m.zoomFactor, 1, accuracy: 1e-9, "aldrig mindre än hela ytan")
        m.zoom(by: 2, u: 0.5, v: 0.5)
        let a = try XCTUnwrap(m.imagePoint(u: 0.5, v: 0.5))
        m.pan(du: 0.1, dv: 0)
        let b = try XCTUnwrap(m.imagePoint(u: 0.6, v: 0.5))
        XCTAssertEqual(b.x, a.x, accuracy: 1e-6, "bilden följer fingret")
        m.pan(du: 10, dv: 10)
        XCTAssertEqual(m.zoom.x, 0, accuracy: 1e-12, "inom ytan")
        XCTAssertEqual(m.zoom.y, 0, accuracy: 1e-12)
        let l = m.loupeCrop(u: 0.5, v: 0.5, surfaceWidthPt: 259, loupePt: 124)
        XCTAssertEqual(m.loupeMagnification(l, surfaceWidthPt: 259, loupePt: 124), ClubMarking.loupeZoom, accuracy: 1e-9)
        m.showWhole()
        XCTAssertEqual(m.zoom, m.crop)
        // En markerad punkt sitter kvar på samma bildpunkt när zoomen ändras.
        XCTAssertTrue(m.tap(u: 0.5, v: 0.5, t: -1.2))
        let g = try XCTUnwrap(m.grip)
        m.zoom(by: 3, u: 0.45, v: 0.55)
        let s = m.surfacePoint(g)
        XCTAssertNotEqual(s.u, 0.5, accuracy: 1e-3, "punkten har flyttat sig på ytan")
        let tillbaka = try XCTUnwrap(m.imagePoint(u: s.u, v: s.v))
        XCTAssertEqual(tillbaka.x, g.x, accuracy: 1e-6)
        // Startzoomen kring positionens egen markering (skaftets mitt): P1 med ett skaft på 300 px
        // ryms med radien 0,6 · 300 i 2,5 gånger (1080 / 360 = 3).
        let p1 = KlubbMarkering(position: "P1", t: -1.2, grepp: KlubbPunkt(x: 500, y: 900), hosel: KlubbPunkt(x: 500, y: 1200))
        var n = ClubMarking(existing: [p1], width: 1080, height: 1920, crop: nil, view: .fo, xTecken: 1)
        n.go(to: "P1")
        n.startZoom(hands: KlubbPunkt(x: 100, y: 100), cmPerPx: 0.25)
        XCTAssertEqual(n.zoomFactor, ClubMarking.zoomStart, accuracy: 1e-9)
        XCTAssertEqual(n.zoom.midY * 1920, 1050, accuracy: 1e-6)
        // En omarkerad position: kring skaftets förväntade mitt, greppet vid händerna plus halva
        // skaftet (medianen 300 px) åt det håll grannen P1 pekar (rakt ned).
        n.go(to: "P3")
        n.startZoom(hands: KlubbPunkt(x: 540, y: 960), cmPerPx: 0.25)
        XCTAssertEqual(n.zoomFactor, ClubMarking.zoomStart, accuracy: 1e-9)
        XCTAssertEqual(n.zoom.midX * 1080, 540, accuracy: 1e-6)
        XCTAssertEqual(n.zoom.midY * 1920, 1110, accuracy: 1e-6)
        // Utan händer: från de markerade greppen; de markerade skaften går före skalan.
        n.startZoom(hands: nil, cmPerPx: 0.01)
        XCTAssertEqual(n.zoomFactor, ClubMarking.zoomStart, accuracy: 1e-9, "de markerade går före skalan")
        XCTAssertEqual(n.zoom.midX * 1080, 500, accuracy: 1e-6)
        XCTAssertEqual(n.zoom.midY * 1920, 1050, accuracy: 1e-6)
        // Ett långt skaft (800 px ur skalan, inga markeringar): cirkeln med radien 0,6 · 800 ryms.
        var o = ClubMarking(existing: nil, width: 1080, height: 1920, crop: nil, view: .fo, xTecken: 1)
        o.startZoom(hands: KlubbPunkt(x: 540, y: 960), cmPerPx: 0.1)
        XCTAssertEqual(o.zoomFactor, 1080 / (2 * ClubMarking.zoomRadius * 800), accuracy: 1e-9)
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
