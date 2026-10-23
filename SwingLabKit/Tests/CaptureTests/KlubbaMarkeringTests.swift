import Foundation
import XCTest
import Swing
import SwingDemo
@testable import Capture

/// S7a: märkningens logik (`ClubMarking`), markeringarna i passet och slagets mått, och
/// `klubba.json` i paketet, på PÅHITTADE svingar (CLAUDE.md, Dataregeln). METOD M45–M49,
/// BESLUT B47
final class KlubbaMarkeringTests: XCTestCase {
    func testTryckenKantenOchUtsnittet() {
        var m = ClubMarking(existing: nil, width: 1080, height: 1920, crop: CropRect(x: 0.2, y: 0.1, width: 0.5, height: 0.6))
        // Utsnittet vidgat 15 % per sida (som PC:ns märksida, MF6).
        XCTAssertEqual(m.crop.x, 0.125, accuracy: 1e-3)
        XCTAssertEqual(m.crop.width, 0.65, accuracy: 1e-3)
        XCTAssertEqual(m.position, "P1")
        XCTAssertEqual(m.next, .grip)
        XCTAssertFalse(m.tap(u: 0.02, v: 0.5), "nära kanten")
        XCTAssertFalse(m.tap(u: 0.5, v: 0.99), "nära kanten")
        XCTAssertFalse(m.tap(u: -0.2, v: 0.5), "utanför")
        XCTAssertFalse(m.canUndo)
        XCTAssertFalse(m.confirm(t: -1), "inga punkter")
        XCTAssertTrue(m.tap(u: 0.5, v: 0.5))
        let g = try! XCTUnwrap(m.grip)
        XCTAssertEqual(g.x, (m.crop.x + 0.5 * m.crop.width) * 1080, accuracy: 1e-9)
        XCTAssertEqual(m.surfacePoint(g).u, 0.5, accuracy: 1e-12)
        XCTAssertEqual(m.next, .hosel)
        XCTAssertTrue(m.tap(u: 0.6, v: 0.8))
        XCTAssertNil(m.next)
        XCTAssertFalse(m.tap(u: 0.3, v: 0.3), "en tredje punkt blir ingenting")
        // Flytta: ett tryck nära hoseln tar den, inte greppet.
        XCTAssertEqual(m.grab(u: 0.61, v: 0.8), .hosel)
        XCTAssertNil(m.grab(u: 0.9, v: 0.2))
        XCTAssertTrue(m.move(.hosel, u: 0.62, v: 0.82))
        XCTAssertFalse(m.move(.hosel, u: 0.999, v: 0.82), "inte till kanten")
        m.undo()
        XCTAssertEqual(m.surfacePoint(try! XCTUnwrap(m.hosel)).u, 0.6, accuracy: 1e-12, "flytten ångrad")
        XCTAssertTrue(m.confirm(t: -1.2))
        XCTAssertEqual(m.position, "P2")
        m.skip(t: -0.9)
        XCTAssertEqual(m.position, "P3")
        XCTAssertEqual(m.result.map(\.position), ["P1", "P2"])
        XCTAssertEqual(m.result[1].hoppad, true)
        m.undo()
        XCTAssertEqual(m.position, "P2", "den hoppade positionen ångrad")
        m.undo()
        XCTAssertEqual(m.position, "P1", "den klara positionen ångrad, punkterna tillbaka")
        XCTAssertNil(m.next)
        // Gå till en klar position: dess punkter laddas för att ändras.
        XCTAssertTrue(m.confirm(t: -1.2))
        m.go(to: "P1")
        XCTAssertNotNil(m.grip)
        // Glaset: kvadratiskt i bildpunkter, inom bilden, 1/3 av ytans bredd.
        let l = m.loupeCrop(u: 0.99, v: 0.01)
        XCTAssertEqual(l.width * 1080, l.height * 1920, accuracy: 1e-6)
        XCTAssertEqual(l.width, m.crop.width / 3, accuracy: 1e-12)
        XCTAssertLessThanOrEqual(l.maxX, 1 + 1e-12)
        XCTAssertGreaterThanOrEqual(l.y, 0)
    }

    func testBorjarDarMarkeringarnaSlutar() {
        let tidigare = [KlubbMarkering(position: "P1", t: -1, grepp: KlubbPunkt(x: 1, y: 2), hosel: KlubbPunkt(x: 100, y: 200)),
                        KlubbMarkering(position: "P2", t: -0.8, grepp: nil, hosel: nil, hoppad: true)]
        var m = ClubMarking(existing: tidigare, width: 1080, height: 1920, crop: nil)
        XCTAssertEqual(m.position, "P3")
        XCTAssertEqual(m.crop, .full)
        for _ in Klubba.positioner.dropFirst(2) { m.skip(t: 0) }
        XCTAssertTrue(m.done)
        XCTAssertEqual(m.result.count, 10)
        XCTAssertEqual(ClubMarking.suggestedTime("P1", measure: nil, existing: tidigare, impact: -0.01), -1)
        let mv = ShotMeasure(heightM: 1.8, heightAssumed: false, positions: ["P1": -1.4, "P3": -0.5, "P5": -0.1, "P7": 0])
        XCTAssertEqual(ClubMarking.suggestedTime("P2", measure: mv, existing: nil, impact: 0), -0.95, accuracy: 1e-12)
        XCTAssertEqual(ClubMarking.suggestedTime("P6", measure: mv, existing: nil, impact: 0), -0.05, accuracy: 1e-12)
        XCTAssertEqual(ClubMarking.suggestedTime("P8", measure: nil, existing: nil, impact: -0.01), -0.01)
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
        XCTAssertNotNil(fore.start)
        let p1 = try XCTUnwrap(fore.positions["P1"]), p4 = fore.positions["P4"]!
        let k1 = serie.frames.min { abs($0.t - p1) < abs($1.t - p1) }!
        let k4 = serie.frames.min { abs($0.t - p4) < abs($1.t - p4) }!
        let t2 = try XCTUnwrap(ClubMarking.suggestedTime("P2", measure: fore, existing: nil, impact: 0))
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
        XCTAssertEqual(m.values["backen_thrust_traff"], fore.values["backen_thrust_traff"], "kroppens mått orörda")
        XCTAssertEqual(pass.clubMarkedCount, 1)
        XCTAssertEqual(pass.visningsPass.klubbMarkerade, 1)
        // pass.json tur och retur; ett slag utan fältet läses utan markeringar.
        let data = try PassCoding.encoder().encode(pass)
        let tillbaka = try PassCoding.decoder().decode(PassState.self, from: data)
        XCTAssertEqual(tillbaka.shots[0].klubba, pass.shots[0].klubba)
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
    /// klippet följer med, och bara slag i manifestet.
    func testKlubbaJsonIPaketet() throws {
        var p = PaketTests.pass()
        XCTAssertNil(PassPackage.clubFile(pass: p, manifest: PackageManifest.make(
            pass: p, app: PaketTests.app, phone: PaketTests.phone, created: PaketTests.skapad, timeZone: PaketTests.zon,
            includeClips: true)), "inga markeringar: ingen fil")
        p.shots[0].klubba = [
            KlubbMarkering(position: "P1", t: -1.25, grepp: KlubbPunkt(x: 10, y: 20), hosel: KlubbPunkt(x: 30, y: 80)),
            KlubbMarkering(position: "P8", t: 0.3, grepp: nil, hosel: nil, hoppad: true)]
        p.shots[3].klubba = p.shots[0].klubba                     // leder saknas: inte i paketet
        for klipp in [true, false] {
            let man = PackageManifest.make(pass: p, app: PaketTests.app, phone: PaketTests.phone,
                                           created: PaketTests.skapad, timeZone: PaketTests.zon, includeClips: klipp)
            let fil = try XCTUnwrap(PassPackage.clubFile(pass: p, manifest: man))
            XCTAssertEqual(fil.format, "swinglab-klubba/2")
            XCTAssertEqual(fil.pass, p.id)
            XCTAssertEqual(fil.kalla, [PassPackage.fileName(p)])
            let vy = p.setup.view.rawValue
            XCTAssertEqual(fil.rutor.map(\.id), ["\(vy)-s01-P1", "\(vy)-s01-P8"])
            XCTAssertEqual(fil.rutor.map(\.status), ["markerad", "hoppad"])
            if klipp {
                XCTAssertEqual(fil.rutor[0].tKlipp ?? .nan, -1.25 + 2.5021, accuracy: 1e-12)
            } else {
                XCTAssertNil(fil.rutor[0].tKlipp)
            }
            XCTAssertNil(fil.rutor[0].forskjutningMs)
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
            XCTAssertEqual(try KlubbFil.las(data).markeringar()["s01"], p.shots[0].klubba)
        }
    }
}
