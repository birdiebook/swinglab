import Foundation
import XCTest
import Swing
@testable import Capture

/// S7d: modellens förslag i märkningen (`ClubMarking`, BESLUT B93, METOD MF8), med PÅHITTADE
/// förslag (CLAUDE.md, Dataregeln). Ett tryck på förslaget godkänner det, ett tryck någon
/// annanstans rättar det, ✓ godkänner båda med ett tryck, och ett förslag som inte rörts blir
/// aldrig en markering.
final class KlubbForslagMarkeringTests: XCTestCase {
    static let nu = Date(timeIntervalSince1970: 1_792_900_000)
    typealias P = KlubbForslagFil.Punkt

    /// Rutan −1,2 s har greppet (0,5; 0,5 på ytan) och hoseln (0,6; 0,7); rutan −0,6 s ett
    /// grepp med låg konfidens och bara huvudets mitt; rutan −0,9 s inget förslag.
    static let rutor = [
        KlubbForslagFil.Ruta(t: -1.2, grepp: P(x: 540, y: 960, konfidens: 0.9, box: nil),
                             hosel: P(x: 648, y: 1344, konfidens: 0.8, box: nil), huvud: nil, skaftMitt: nil),
        KlubbForslagFil.Ruta(t: -0.6, grepp: P(x: 540, y: 960, konfidens: 0.3, box: nil), hosel: nil,
                             huvud: P(x: 700, y: 1500, konfidens: 0.9, box: [660, 1480, 80, 40]), skaftMitt: nil),
    ]

    private func ny() -> ClubMarking {
        ClubMarking(existing: nil, width: 1080, height: 1920, crop: nil, view: .dtl, xTecken: 1,
                    suggestions: Self.rutor, suggestionModel: "klubba-golf49 0.1.0")
    }

    func testTryckPaForslagetGodkanner() throws {
        var m = ny()
        XCTAssertEqual(m.position, "P1")
        let visat = try XCTUnwrap(m.shownSuggestion(t: -1.2))
        XCTAssertEqual(visat.grepp, KlubbPunkt(x: 540, y: 960))
        XCTAssertEqual(visat.hosel, KlubbPunkt(x: 648, y: 1344))
        XCTAssertTrue(m.canUseSuggestion(t: -1.2))
        // Inom 2 ms är samma ruta (MF8), längre bort ingen.
        XCTAssertNotNil(m.suggestion(at: -1.2 + 0.0019))
        XCTAssertNil(m.suggestion(at: -1.2 + 0.0021))
        // Modellens grepp ersätter ringen ur handlederna.
        XCTAssertEqual(m.gripGuess(ring: KlubbPunkt(x: 100, y: 100), t: -1.2)?.1, Klubba.kallaForslag)
        XCTAssertEqual(m.gripGuess(ring: KlubbPunkt(x: 100, y: 100), t: -0.9)?.1, Klubba.kallaRing)
        XCTAssertTrue(m.tap(u: 0.51, v: 0.5, t: -1.2))
        XCTAssertEqual(m.grip, KlubbPunkt(x: 540, y: 960), "förslagets punkt, inte trycket")
        XCTAssertEqual(m.gripSource, Klubba.kallaForslag)
        XCTAssertNil(m.shownSuggestion(t: -1.2)?.grepp, "greppet är satt")
        XCTAssertNotNil(m.shownSuggestion(t: -1.2)?.hosel)
        XCTAssertTrue(m.tap(u: 0.6, v: 0.71, t: -1.2, now: Self.nu))
        XCTAssertEqual(m.position, "P3")
        let p1 = try XCTUnwrap(m.result.first)
        XCTAssertEqual(p1.hosel, KlubbPunkt(x: 648, y: 1344))
        XCTAssertEqual(p1.greppKalla, Klubba.kallaForslag)
        XCTAssertEqual(p1.hoselKalla, Klubba.kallaForslag)
        XCTAssertEqual(p1.forslag, KlubbMarkering.Forslag(grepp: KlubbPunkt(x: 540, y: 960),
                                                         hosel: KlubbPunkt(x: 648, y: 1344), modell: "klubba-golf49 0.1.0"))
        XCTAssertEqual(p1.t, -1.2)
    }

    func testEttTryckGodkannerBada() throws {
        var m = ny()
        XCTAssertFalse(m.canUseSuggestion(t: -0.9), "inget förslag i rutan")
        XCTAssertFalse(m.useSuggestion(t: -0.9))
        XCTAssertTrue(m.useSuggestion(t: -1.2, now: Self.nu))
        XCTAssertEqual(m.position, "P3")
        let p1 = try XCTUnwrap(m.marks["P1"])
        XCTAssertTrue(p1.markerad)
        XCTAssertEqual([p1.greppKalla, p1.hoselKalla], [Klubba.kallaForslag, Klubba.kallaForslag])
        // Ett ångra tar bort hela godkännandet.
        m.undo()
        XCTAssertEqual(m.position, "P1")
        XCTAssertNil(m.grip)
        XCTAssertTrue(m.result.isEmpty)
        // Med ett eget grepp godkänner ✓ bara hoseln.
        XCTAssertTrue(m.tap(u: 0.3, v: 0.3, t: -1.2))
        XCTAssertTrue(m.canUseSuggestion(t: -1.2))
        XCTAssertTrue(m.useSuggestion(t: -1.2))
        let igen = try XCTUnwrap(m.marks["P1"])
        XCTAssertNil(igen.greppKalla, "ett tryck: rättat förslag")
        XCTAssertEqual(igen.hoselKalla, Klubba.kallaForslag)
        XCTAssertEqual(igen.forslag?.grepp, KlubbPunkt(x: 540, y: 960), "förslaget som rättades står kvar")
    }

    func testTryckAnnanstansRattar() throws {
        var m = ny()
        XCTAssertTrue(m.tap(u: 0.45, v: 0.45, t: -1.2))
        XCTAssertEqual(m.gripSource, Klubba.kalla)
        XCTAssertTrue(m.tap(u: 0.7, v: 0.8, t: -1.2))
        let p1 = try XCTUnwrap(m.marks["P1"])
        XCTAssertNil(p1.greppKalla)
        XCTAssertNil(p1.hoselKalla)
        XCTAssertNotNil(p1.forslag, "förslaget visades: punkterna är rättade, inte rena klick")
        // Ett godkänt förslag som flyttas blir ett tryck.
        m.go(to: "P1")
        m.clearPoints()
        XCTAssertTrue(m.useSuggestion(t: -1.2))
        m.go(to: "P1")
        XCTAssertTrue(m.move(.hosel, u: 0.62, v: 0.72))
        XCTAssertNil(m.marks["P1"]?.hoselKalla)
        XCTAssertEqual(m.marks["P1"]?.greppKalla, Klubba.kallaForslag)
    }

    /// Ett förslag som inte rörts sparas aldrig: en hoppad position har inga punkter, en ruta
    /// utan förslag ger rena klick, och huvudets mitt är bara en ledtråd (ett tryck där blir ett
    /// klick, aldrig hoseln ur förslaget). Låg konfidens visas inte.
    func testOrortForslagSparasAldrig() throws {
        var m = ny()
        m.skip(t: -1.2)
        let p1 = try XCTUnwrap(m.marks["P1"])
        XCTAssertNil(p1.grepp)
        XCTAssertNil(p1.forslag)
        XCTAssertEqual(m.position, "P3")
        XCTAssertNil(m.shownSuggestion(t: -0.9))
        let lag = try XCTUnwrap(m.shownSuggestion(t: -0.6))
        XCTAssertNil(lag.grepp, "konfidensen 0,3 visas inte")
        XCTAssertEqual(lag.huvud, KlubbPunkt(x: 700, y: 1500))
        XCTAssertEqual(lag.huvudBox, [660, 1480, 80, 40])
        XCTAssertFalse(m.canUseSuggestion(t: -0.6), "huvudets mitt godkänns aldrig som hoseln")
        XCTAssertTrue(m.tap(u: 0.5, v: 0.5, t: -0.6))
        XCTAssertEqual(m.gripSource, Klubba.kalla, "det låga förslaget godtas inte")
        XCTAssertTrue(m.tap(u: 700.0 / 1080, v: 1500.0 / 1920, t: -0.6))
        let p3 = try XCTUnwrap(m.marks["P3"])
        XCTAssertNil(p3.hoselKalla)
        XCTAssertNil(p3.forslag, "inget grepp eller hosel föreslogs")
        XCTAssertEqual(m.result.filter(\.markerad).map(\.position), ["P3"])
    }

    /// Paketets klubba.json bär källan och förslaget, som PC:ns klubba.kontrollera kräver.
    func testFilenBarKallanOchForslaget() throws {
        var m = ny()
        XCTAssertTrue(m.useSuggestion(t: -1.2, now: Self.nu))
        let p1 = try XCTUnwrap(m.marks["P1"])
        let r = KlubbFil.ruta(p1, vy: .dtl, slag: "s01", fil: "swinglab-x-dtl.zip", bredd: 1080, hojd: 1920,
                              visad: [0, 0, 1080, 1920], tKlipp: nil)
        XCTAssertEqual(r.punkter.grepp, .klick(x: 540, y: 960, kalla: "godkand_forslag"))
        XCTAssertEqual(r.punkter.klubbhuvud, .klick(x: 648, y: 1344, kalla: "godkand_forslag"))
        XCTAssertEqual(r.forslag["grepp"]?.kalla, "modell")
        XCTAssertEqual(r.forslag["klubbhuvud"]?.modell, "klubba-golf49 0.1.0")
        let j = try XCTUnwrap(try JSONSerialization.jsonObject(with: JSONEncoder().encode(r)) as? [String: Any])
        let f = try XCTUnwrap(j["forslag"] as? [String: [String: Any]])
        XCTAssertEqual(Set(f["klubbhuvud"]?.keys.map { $0 } ?? []), ["x", "y", "kalla", "modell"])
        // Och tillbaka: markeringen är densamma utom tiden för ändringen.
        let fil = KlubbFil(pass: "20261024-171500", kalla: ["swinglab-x-dtl.zip"], andrad: "2026-10-25T12:00:00+02:00",
                           rutor: [r])
        var lasta = try XCTUnwrap(try KlubbFil.las(JSONEncoder().encode(fil)).markeringar()["s01"]?.first)
        lasta.andrad = p1.andrad
        XCTAssertEqual(lasta, p1)
    }
}
