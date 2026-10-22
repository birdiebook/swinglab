import Foundation
import XCTest
@testable import Capture

/// Rutornas tider, formatet, exponeringen, ljusprovet och orienteringen (S2_SPEC §11.2),
/// på påhittade värden. METOD MS1, MS2, MS3, MS7
final class VardenaTests: XCTestCase {
    // MARK: FrameTiming

    func testJamnt240() {
        let t = (0..<480).map { Double($0) / 240 + 0.0042 }
        let f = FrameTiming.analyze(t)
        XCTAssertEqual(f.count, 480)
        XCTAssertEqual(f.gridRate, 240)
        XCTAssertEqual(f.meanRate, 240, accuracy: 1e-9)
        XCTAssertEqual(f.missingFraction, 0, accuracy: 1e-9)
        XCTAssertEqual(f.largestGap, 1.0 / 240, accuracy: 1e-12)
        XCTAssertTrue(f.isSlowMotion)
    }

    func test240MedVarTredjeBorta() {
        let t = (0..<720).filter { $0 % 3 != 2 }.map { Double($0) / 240 }
        let f = FrameTiming.analyze(t.shuffled())       // ordningen spelar ingen roll
        XCTAssertEqual(f.gridRate, 240)
        XCTAssertEqual(f.missingFraction, 1.0 / 3, accuracy: 0.002)
        XCTAssertEqual(f.meanRate, 160, accuracy: 0.5)
        XCTAssertEqual(f.largestGap, 2.0 / 240, accuracy: 1e-12)
        XCTAssertTrue(f.isSlowMotion)
    }

    func test30BilderPerSekundArInteSlowmotion() {
        let f = FrameTiming.analyze((0..<90).map { Double($0) / 30 })
        XCTAssertEqual(f.gridRate, 30)
        XCTAssertFalse(f.isSlowMotion)
    }

    func testEnEndaRutaOchIngen() {
        for t in [[1.0], []] {
            let f = FrameTiming.analyze(t)
            XCTAssertEqual(f.count, t.count)
            XCTAssertEqual(f.gridRate, 0)
            XCTAssertEqual(f.missingFraction, 0)
            XCTAssertFalse(f.isSlowMotion)
        }
    }

    func testTiderSomKodasTillJSON() throws {
        let f = FrameTiming.analyze([0, 1.0 / 240, 3.0 / 240])
        let d = try JSONEncoder().encode(f)
        XCTAssertEqual(try JSONDecoder().decode(FrameTiming.self, from: d), f)
    }

    // MARK: FormatChoice

    static func fmt(_ i: Int, w: Int = 1920, h: Int = 1080, rate: Double, fov: Double = 70, binned: Bool = false,
                    tenBit: Bool = false, maxISO: Double = 2000) -> CameraFormat {
        CameraFormat(index: i, width: w, height: h, maxFrameRate: rate, fieldOfView: fov, binned: binned,
                     minISO: 32, maxISO: maxISO, minExposure: 1.0 / 100_000, maxExposure: 1.0 / 3,
                     tenBit: tenBit, hdrSupported: false)
    }

    func testFormatetStorstSynfaltFore() {
        let f = [Self.fmt(0, rate: 60), Self.fmt(1, rate: 240, fov: 60), Self.fmt(2, rate: 240, fov: 72),
                 Self.fmt(3, w: 3840, h: 2160, rate: 240, fov: 80), Self.fmt(4, rate: 120, fov: 90)]
        XCTAssertEqual(FormatChoice.choose(f), 2)
    }

    func testFormatetBinnatSedanAttaBitar() {
        let f = [Self.fmt(0, rate: 240, tenBit: true), Self.fmt(1, rate: 240, binned: true, tenBit: true),
                 Self.fmt(2, rate: 240, binned: true), Self.fmt(3, rate: 240, binned: true)]
        XCTAssertEqual(FormatChoice.choose(f), 2)                        // binnat, 8-bitars, lägst index
        XCTAssertEqual(FormatChoice.choose(Array(f.prefix(2))), 1)      // binnat före 10-bitar
        XCTAssertEqual(FormatChoice.choose([Self.fmt(5, rate: 239.76)]), 5)   // inom 0,5
    }

    func testFormatetUtan240TarBasta120() {
        let f = [Self.fmt(0, rate: 30, fov: 90), Self.fmt(1, rate: 120, fov: 65), Self.fmt(2, rate: 120, fov: 70),
                 Self.fmt(3, rate: 100, fov: 99), Self.fmt(4, w: 1280, h: 720, rate: 240)]
        XCTAssertEqual(FormatChoice.choose(f), 2)
        XCTAssertFalse(FormatChoice.reaches(f[2]))
        XCTAssertNil(FormatChoice.choose([Self.fmt(0, rate: 60)]))
        XCTAssertNil(FormatChoice.choose([]))
    }

    // MARK: Exposure

    func testExponeringenDomarna() {
        let f = Self.fmt(0, rate: 240, maxISO: 2000)
        let p0 = Exposure.plan(aeDuration: 1.0 / 2000, aeISO: 800, aeOffsetEV: 0, format: f)
        XCTAssertEqual(p0.duration, 1.0 / 2000)
        XCTAssertEqual(p0.neededISO, 800, accuracy: 1e-9)
        XCTAssertEqual(p0.iso, 800, accuracy: 1e-9)
        XCTAssertEqual(p0.light, .good)
        XCTAssertEqual(p0.deficitEV, 0)
        let p1 = Exposure.plan(aeDuration: 1.0 / 2000, aeISO: 800, aeOffsetEV: -1, format: f)
        XCTAssertEqual(p1.neededISO, 1600, accuracy: 1e-9)
        XCTAssertEqual(p1.light, .marginal)
        let p3 = Exposure.plan(aeDuration: 1.0 / 2000, aeISO: 800, aeOffsetEV: -3, format: f)
        XCTAssertEqual(p3.neededISO, 6400, accuracy: 1e-9)
        XCTAssertEqual(p3.iso, 2000)
        XCTAssertEqual(p3.deficitEV, log2(3.2), accuracy: 1e-12)
        XCTAssertEqual(p3.light, .tooDark)
        // Autoexponeringen på 1/500 s med ISO 100 kräver ISO 400 vid 1/2000 s.
        let p = Exposure.plan(aeDuration: 1.0 / 500, aeISO: 100, aeOffsetEV: 0, format: f)
        XCTAssertEqual(p.neededISO, 400, accuracy: 1e-9)
    }

    func testExponeringenLamnarAldrigFormatet() {
        let f = CameraFormat(index: 0, width: 1920, height: 1080, maxFrameRate: 240, fieldOfView: 70, binned: false,
                             minISO: 50, maxISO: 1600, minExposure: 1.0 / 1000, maxExposure: 0.25,
                             tenBit: false, hdrSupported: false)
        for d in [1e-6, 1.0 / 4000, 1.0 / 60, 1.0, .nan, -1, .infinity] {
            for iso in [1.0, 50, 400, 1e6, .nan, 0] {
                for ev in [-8.0, -1, 0, 3, .nan] {
                    let p = Exposure.plan(aeDuration: d, aeISO: iso, aeOffsetEV: ev, format: f)
                    XCTAssertGreaterThanOrEqual(p.duration, f.minExposure)
                    XCTAssertLessThanOrEqual(p.duration, f.maxExposure)
                    XCTAssertGreaterThanOrEqual(p.iso, f.minISO)
                    XCTAssertLessThanOrEqual(p.iso, f.maxISO)
                    XCTAssertTrue(p.deficitEV.isFinite && p.neededISO.isFinite)
                    XCTAssertNoThrow(try JSONEncoder().encode(p))
                }
            }
        }
        // Formatets kortaste tid är 1/1000 s: den låses, inte 1/2000 s.
        XCTAssertEqual(Exposure.plan(aeDuration: 1.0 / 1000, aeISO: 100, aeOffsetEV: 0, format: f).duration, 1.0 / 1000)
    }

    // MARK: Flicker

    /// Rutor på 240-rutnätet med en tredjedel borta, oregelbundet (LCG), och lite jitter.
    static func tider(_ n: Int = 480) -> [Double] {
        var s: UInt64 = 42
        var t: [Double] = []
        for i in 0..<n {
            s = (1_103_515_245 &* s &+ 12345) % 2_147_483_648
            if s % 3 == 0 { continue }
            t.append(Double(i) / 240 + Double(s % 100) * 1e-6)
        }
        return t
    }

    func testFlimretVid100Hz() {
        let t = Self.tider()
        let luma = t.map { 0.4 * (1 + 0.2 * cos(2 * Double.pi * 100 * $0 + 0.7)) }
        XCTAssertEqual(Flicker.depth(luma: luma, times: t, hz: 100), 0.20, accuracy: 0.01)
        XCTAssertLessThan(Flicker.depth(luma: t.map { _ in 0.4 }, times: t, hz: 100), 0.005)
        XCTAssertLessThan(Flicker.depth(luma: t.map { _ in 0.4 }, times: t, hz: 120), 0.005)
    }

    func testFlimretPaHalvaBildfrekvensenGarAttRakna() {
        // Exakt 240-rutnät: sinus vid 120 Hz är noll på rutorna, och kolumnen lämnas ute.
        let t = (0..<480).map { Double($0) / 240 }
        let luma = t.map { 0.4 * (1 + 0.1 * cos(2 * Double.pi * 120 * $0)) }
        XCTAssertEqual(Flicker.depth(luma: luma, times: t, hz: 120), 0.10, accuracy: 0.005)
        XCTAssertEqual(Flicker.depth(luma: [0.4, 0.4], times: [0, 0.1], hz: 100), 0)
    }

    func testLjusprovetsDom() {
        let f = Self.fmt(0, rate: 240)
        let bra = Exposure.plan(aeDuration: 1.0 / 2000, aeISO: 400, aeOffsetEV: 0, format: f)
        let t = Self.tider()
        let jamn = FrameTiming.analyze((0..<480).map { Double($0) / 240 })
        let stilla = t.map { _ in 0.4 }
        XCTAssertEqual(Flicker.check(exposure: bra, timing: jamn, luma: stilla, times: t).verdict, .good)
        let flimmer = t.map { 0.4 * (1 + 0.15 * cos(2 * Double.pi * 100 * $0)) }
        let c = Flicker.check(exposure: bra, timing: jamn, luma: flimmer, times: t)
        XCTAssertEqual(c.flickerLight, .tooDark)
        XCTAssertEqual(c.verdict, .tooDark)
        let tappad = FrameTiming.analyze(t)                             // en tredjedel borta
        XCTAssertEqual(Flicker.check(exposure: bra, timing: tappad, luma: stilla, times: t).framesLight, .tooDark)
        let mork = Flicker.check(exposure: bra, timing: jamn, luma: t.map { _ in 0.1 }, times: t)
        XCTAssertEqual(mork.lumaLight, .marginal)
        XCTAssertEqual(mork.verdict, .marginal)
        XCTAssertEqual(Flicker.grade(flicker: 0.029), .good)
        XCTAssertEqual(Flicker.grade(flicker: 0.10), .marginal)
        XCTAssertEqual(Flicker.grade(missing: 0.011), .marginal)
        XCTAssertNoThrow(try JSONEncoder().encode(c))
    }

    // MARK: Orientation

    func testOrienteringen() {
        XCTAssertEqual(Orientation.exif(a: 0, b: 1, c: -1, d: 0), 6)
        XCTAssertEqual(Orientation.exif(a: 0.001, b: 0.999, c: -1, d: 0), 6)
        XCTAssertEqual(Orientation.exif(a: 0, b: -1, c: 1, d: 0), 8)
        XCTAssertEqual(Orientation.exif(a: 1, b: 0, c: 0, d: 1), 1)
        XCTAssertEqual(Orientation.exif(a: -1, b: 0, c: 0, d: -1), 3)
        XCTAssertEqual(Orientation.exif(a: -1, b: 0, c: 0, d: 1), 1)      // speglad: okänd
        for (e, w, h) in [(UInt32(6), 1080, 1920), (8, 1080, 1920), (3, 1920, 1080), (1, 1920, 1080)] {
            let s = Orientation.uprightSize(width: 1920, height: 1080, exif: e)
            XCTAssertEqual([s.width, s.height], [w, h], "exif \(e)")
        }
        let p = Orientation.pixels(x: 0.5, y: 0.9, uprightWidth: 1080, uprightHeight: 1920)
        XCTAssertEqual(p.x, 540, accuracy: 1e-9)
        XCTAssertEqual(p.y, 192, accuracy: 1e-9)
    }
}
