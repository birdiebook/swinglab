import Foundation
import XCTest
import Swing
@testable import Capture

/// S6b: telefonens lodlinje till manifestet, på PÅHITTADE telefoner (CLAUDE.md, Dataregeln).
/// Vektorerna står i tools/tests/fixturer/lodlinje.json, som PC:n läser i
/// tools/tests/test_lodlinje.py med `paket.py`: samma fall prövas åt båda håll.
/// METOD MS17, MK3, BESLUT B39
final class LodlinjeTests: XCTestCase {
    static let rot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    struct Fall: Decodable {
        let namn: String
        let orientering: UInt32
        let gravitation: [Double]
        let lodlinje: [Double]?
    }

    struct Fixtur: Decodable { let fall: [Fall] }

    func fall() throws -> [Fall] {
        let url = Self.rot.appendingPathComponent("tools/tests/fixturer/lodlinje.json")
        return try JSONDecoder().decode(Fixtur.self, from: Data(contentsOf: url)).fall
    }

    /// PC:ns kontroll (`paket.lodlinjen`): tre tal, längden 0,8–1,2 g, y < 0. METOD MK3
    static func pcTar(_ v: [Double]) -> Bool {
        v.count == 3 && Plumb.length.contains(Plumb.norm(v)) && v[1] < 0
    }

    /// Proven i 30 Hz på värdklockan från `fran` till `till` (s), gravitationen `g` vriden
    /// `vrid(t)` grader kring enhetens z (telefonen som vrids i sitt plan).
    static func prov(_ g: [Double], fran: Double, till: Double, vrid: (Double) -> Double = { _ in 0 }) -> [GravitySample] {
        var ut: [GravitySample] = []
        var t = fran
        while t < till {
            let a = vrid(t) * .pi / 180
            ut.append(GravitySample(host: t, x: g[0] * cos(a) - g[1] * sin(a), y: g[0] * sin(a) + g[1] * cos(a), z: g[2]))
            t += Plumb.sampleInterval
        }
        return ut
    }

    static let staende = [0.069078, -0.987856, -0.139173]     // fixturens "staende_lutar"

    // MARK: Kamerans ram

    func testFixturensTelefonerStaendeOchLiggande() throws {
        let f = try fall()
        XCTAssertTrue(f.contains { $0.orientering == 6 && $0.lodlinje != nil }, "stående")
        XCTAssertTrue(f.contains { $0.orientering == 1 && $0.lodlinje != nil }, "liggande")
        for c in f {
            let r = PlumbRecord(gravity: c.gravitation, spread: 0.1, samples: 30, basis: .beforeClick)
            let v = Plumb.field(r, exif: c.orientering)
            if let vantad = c.lodlinje {
                let v = try XCTUnwrap(v, c.namn)
                for i in 0..<3 { XCTAssertEqual(v[i], vantad[i], accuracy: 1e-9, "\(c.namn)[\(i)]") }
                XCTAssertTrue(Self.pcTar(v), "\(c.namn): PC:ns kontroll tar det")
                XCTAssertLessThan(v[1], -0.95, "\(c.namn): uppåt mot bildens överkant")
            } else {
                XCTAssertNil(v, "\(c.namn): skrivs inte")
            }
        }
    }

    func testRakTelefonGerUppatMotOverkanten() {
        // Stående i kamerans vanliga läge (EXIF 6) och liggande med överkanten åt vänster (EXIF 1).
        XCTAssertEqual(Plumb.up(gravity: [0, -1, 0], exif: 6), [0, -1, 0])
        XCTAssertEqual(Plumb.up(gravity: [-1, 0, 0], exif: 1), [0, -1, 0])
        XCTAssertEqual(Plumb.up(gravity: [1, 0, 0], exif: 3), [0, -1, 0])
        XCTAssertEqual(Plumb.up(gravity: [0, 1, 0], exif: 8), [0, -1, 0])
        // Telefonen lutad bakåt (skärmen mot himlen): kameran tittar nedåt, uppåt pekar bakåt (z < 0).
        let bakat = Plumb.up(gravity: [0, -0.9848, -0.1736], exif: 6)
        XCTAssertLessThan(bakat[2], 0)
        // Höger sida nedåt: bilden vrids moturs, uppåt pekar åt vänster (x < 0).
        XCTAssertLessThan(Plumb.up(gravity: [0.0698, -0.9976, 0], exif: 6)[0], 0)
    }

    func testFelRiktningSkrivsInte() {
        let r = { (g: [Double]) in PlumbRecord(gravity: g, spread: 0, samples: 30, basis: .still) }
        XCTAssertNil(Plumb.field(r([0, 1, 0]), exif: 6), "upp och ned mot filen")
        XCTAssertNil(Plumb.field(r([-1, 0, 0]), exif: 6), "liggande telefon i en stående fil")
        XCTAssertNil(Plumb.field(r([0, -0.5, 0]), exif: 6), "för kort: inte telefonen i vila")
        XCTAssertNil(Plumb.field(r([0, -1, .nan]), exif: 6))
        XCTAssertNil(Plumb.field(PlumbRecord(gravity: [0, -1, 0], spread: 5, samples: 30, basis: .moving), exif: 6))
        XCTAssertNil(Plumb.field(nil, exif: 6))
        // 44° lutning går, 46° inte (METOD MS17).
        let a44 = 44.0 * .pi / 180, a46 = 46.0 * .pi / 180
        XCTAssertNotNil(Plumb.field(r([sin(a44), -cos(a44), 0]), exif: 6))
        XCTAssertNil(Plumb.field(r([sin(a46), -cos(a46), 0]), exif: 6))
    }

    // MARK: Medianen och spärren

    func testSekundenForeForstaKlicket() throws {
        // Serien börjar på värdklockan 100 s, första klicket 5 s in. Telefonen gungar de
        // första 2 s (någon tryckte på den) och står sedan still.
        let p = Self.prov(Self.staende, fran: 100, till: 112, vrid: { t in t < 102 ? 3 * sin(9 * t) : 0 })
        let r = try XCTUnwrap(Plumb.estimate(samples: p, startHost: 100, firstClick: 5))
        XCTAssertEqual(r.basis, .beforeClick)
        XCTAssertTrue((29...31).contains(r.samples), "en sekund i 30 Hz")
        XCTAssertEqual(r.beforeClickSamples, r.samples, "fönstrets prov syns i pass.json")
        XCTAssertEqual(r.firstSampleOffset ?? .nan, 0, accuracy: 1e-9, "provens klocka är seriens")
        XCTAssertLessThan(r.spread, 1e-3)
        for i in 0..<3 { XCTAssertEqual(r.gravity[i], Self.staende[i], accuracy: 1e-9) }
        let v = try XCTUnwrap(Plumb.field(r, exif: 6))
        XCTAssertEqual(v, [-0.0691, -0.9879, -0.1392])
    }

    func testStotEfterForstaKlicketSkrivsInte() throws {
        // Stilla före klicket, men stativet stöts 6 s in och står sedan 3° snett: sekunden
        // före klicket stämmer inte med seriens stilla sekunder, så inget fält.
        let p = Self.prov(Self.staende, fran: 100, till: 112, vrid: { t in t < 106 ? 0 : 3 })
        let r = try XCTUnwrap(Plumb.estimate(samples: p, startHost: 100, firstClick: 5))
        XCTAssertEqual(r.basis, .disagree)
        XCTAssertTrue(r.spread.isFinite)
        XCTAssertNil(Plumb.field(r, exif: 6))
        // Ett stöt inom spärren (0,5°) gör inget.
        let litet = Self.prov(Self.staende, fran: 100, till: 112, vrid: { t in t < 106 ? 0 : 0.5 })
        XCTAssertEqual(Plumb.estimate(samples: litet, startHost: 100, firstClick: 5)?.basis, .beforeClick)
    }

    func testStillaSekunderNarKlicketGungar() throws {
        // Klicket 0,5 s in, medan telefonen gungar: de stillastående sekunderna efter tar över.
        let p = Self.prov(Self.staende, fran: 100, till: 110, vrid: { t in t < 101.5 ? 3 * sin(9 * t) : 0 })
        let r = try XCTUnwrap(Plumb.estimate(samples: p, startHost: 100, firstClick: 0.5))
        XCTAssertEqual(r.basis, .still)
        XCTAssertLessThanOrEqual(r.spread, Plumb.maxSpread)
        XCTAssertNotNil(Plumb.field(r, exif: 6))
        // Utan värdklocka (startHost saknas) eller klick: samma väg, och ingen tid i filen.
        let utan = try XCTUnwrap(Plumb.estimate(samples: p, startHost: nil, firstClick: 0.5))
        XCTAssertEqual(utan.basis, .still)
        XCTAssertNil(utan.firstSampleOffset)
        XCTAssertNil(utan.beforeClickSamples)
        XCTAssertEqual(Plumb.estimate(samples: p, startHost: 100, firstClick: nil)?.basis, .still)
    }

    func testKlockfelSyns() throws {
        // Proven på en annan klocka (1000 s fel): fönstret före klicket är tomt och första
        // provet ligger 1000 s in i filen. De stilla sekunderna ger ändå lodlinjen.
        let p = Self.prov(Self.staende, fran: 1100, till: 1110)
        let r = try XCTUnwrap(Plumb.estimate(samples: p, startHost: 100, firstClick: 5))
        XCTAssertEqual(r.basis, .still)
        XCTAssertEqual(r.beforeClickSamples, 0)
        XCTAssertEqual(r.firstSampleOffset ?? .nan, 1000, accuracy: 1e-9)
    }

    func testSpridningenArEnPercentil() throws {
        // Ett ensamt prov 10° snett (en skakning vid träffen) av 30: under 95:e percentilen.
        var p = Self.prov(Self.staende, fran: 100, till: 112)
        let i = p.firstIndex { $0.host >= 104.5 }!
        let a = 10.0 * .pi / 180
        p[i] = GravitySample(host: p[i].host, x: p[i].x * cos(a) - p[i].y * sin(a), y: p[i].x * sin(a) + p[i].y * cos(a),
                             z: p[i].z)
        let r = try XCTUnwrap(Plumb.estimate(samples: p, startHost: 100, firstClick: 5))
        XCTAssertEqual(r.basis, .beforeClick)
        XCTAssertLessThan(r.spread, 1e-3)
    }

    func testTelefonenSomRorSigSkrivsInte() throws {
        // Vriden 5°/s hela serien: inget fönster är stilla.
        let p = Self.prov(Self.staende, fran: 100, till: 110, vrid: { t in 5 * (t - 100) })
        let r = try XCTUnwrap(Plumb.estimate(samples: p, startHost: 100, firstClick: 5))
        XCTAssertEqual(r.basis, .moving)
        XCTAssertGreaterThan(r.spread, Plumb.maxSpread)
        XCTAssertNil(Plumb.field(r, exif: 6))
        // Två stilla lägen 5° isär (stativet flyttat mitt i serien): de är inte eniga.
        let tva = Self.prov(Self.staende, fran: 100, till: 110, vrid: { t in t < 105 ? 0 : 5 })
        let o = try XCTUnwrap(Plumb.estimate(samples: tva, startHost: nil, firstClick: nil))
        XCTAssertEqual(o.basis, .disagree)
        XCTAssertNil(Plumb.field(o, exif: 6))
    }

    func testForFaProvSkiljsFranRorelse() {
        XCTAssertNil(Plumb.estimate(samples: [], startHost: 100, firstClick: 5), "simulatorn")
        let fa = Self.prov(Self.staende, fran: 100, till: 100.2)
        let r = Plumb.estimate(samples: fa, startHost: 100, firstClick: 5)
        XCTAssertEqual(r?.basis, .tooFew, "för få prov för ett fönster")
        XCTAssertNil(Plumb.field(r, exif: 6))
    }

    func testTrasigaProvSlangsOchPassJsonGarAttSpara() throws {
        // NaN, nollvektorer och fel längd (accelerometerns hela utslag) slängs; spridningen är
        // alltid ändlig, så att pass.json (JSONEncoder utan NaN) går att spara.
        var p = Self.prov(Self.staende, fran: 100, till: 106)
        for k in stride(from: 0, to: p.count, by: 3) { p[k].x = .nan }
        for k in stride(from: 1, to: p.count, by: 7) { p[k] = GravitySample(host: p[k].host, x: 0, y: 0, z: 0) }
        for k in stride(from: 2, to: p.count, by: 11) { p[k].y = -3 }
        var pass = SlagTests.pass(klick: [[4.0]])
        pass.series[0].startHost = 100
        pass.series[0].setPlumb(p)
        let r = try XCTUnwrap(pass.series[0].plumb)
        XCTAssertEqual(r.basis, .beforeClick)
        XCTAssertTrue(r.spread.isFinite)
        for i in 0..<3 { XCTAssertEqual(r.gravity[i], Self.staende[i], accuracy: 1e-9) }
        let e = try PassCoding.encoder().encode(pass)
        XCTAssertEqual(try PassCoding.decoder().decode(PassState.self, from: e).series[0].plumb, r)
        // Bara trasiga prov: inget giltigt, "för få", och pass.json går att spara.
        let trasiga = (0..<60).map { GravitySample(host: 100 + Double($0) / 30, x: .nan, y: 0, z: 0) }
        pass.series[0].setPlumb(trasiga)
        XCTAssertEqual(pass.series[0].plumb?.basis, .tooFew)
        XCTAssertEqual(pass.series[0].plumb?.samples, 0)
        XCTAssertNoThrow(try PassCoding.encoder().encode(pass))
        // Motsatta prov (medianen nära noll): spridningen är ändå ändlig.
        let mot = Self.prov([0, -1, 0], fran: 100, till: 101) + Self.prov([0, 1, 0], fran: 101, till: 102)
        XCTAssertTrue(Plumb.estimate(samples: mot, startHost: nil, firstClick: nil)?.spread.isFinite ?? false)
    }

    // MARK: Manifestet

    func testManifestetMedOchUtanLodlinje() throws {
        var p = SlagTests.pass(klick: [[4.0], [3.0]])
        p.series[0].startHost = 100
        p.series[0].setPlumb(Self.prov(Self.staende, fran: 100, till: 106))
        XCTAssertEqual(p.series[0].plumb?.basis, .beforeClick)
        XCTAssertNil(p.series[1].plumb)
        p.syncShots()
        for i in p.shots.indices {
            p.shots[i].verdict = .swing
            p.shots[i].joints = ShotRecord.jointsPath(p.shots[i].id)
        }
        let m = PackageManifest.make(pass: p, app: PaketTests.app, phone: PaketTests.phone, created: PaketTests.skapad,
                                     timeZone: PaketTests.zon, includeClips: false)
        let data = try PassPackage.encoder().encode(m)
        let serier = try XCTUnwrap(JSONDecoder().decode(J.self, from: data)["serier"]?.arr)
        XCTAssertEqual(serier[0]["lodlinje"], .a([.n(-0.0691), .n(-0.9879), .n(-0.1392)]))
        XCTAssertNil(serier[1]["lodlinje"], "utan prov står fältet inte med")
        XCTAssertEqual(try JSONDecoder().decode(PackageManifest.self, from: data), m)
    }

    func testGamlaPassUtanFaltet() throws {
        // Ett pass.json från före S6b saknar `plumb`: nil skrivs inte, och utan nyckeln läses
        // passet och manifestet blir som förut.
        let p = SlagTests.pass(klick: [[4.0]])
        let e = try PassCoding.encoder().encode(p)
        XCTAssertFalse(String(decoding: e, as: UTF8.self).contains("plumb"), "nil skrivs inte")
        let igen = try PassCoding.decoder().decode(PassState.self, from: e)
        XCTAssertNil(igen.series[0].plumb)
        let m = PackageManifest.make(pass: igen, app: PaketTests.app, phone: PaketTests.phone,
                                     created: PaketTests.skapad, timeZone: PaketTests.zon, includeClips: false)
        XCTAssertNil(m.series[0].plumb)
        let utan = try PassPackage.encoder().encode(m)
        XCTAssertFalse(String(decoding: utan, as: UTF8.self).contains("lodlinje"))
        XCTAssertEqual(try JSONDecoder().decode(PackageManifest.self, from: utan), m)
    }
}
