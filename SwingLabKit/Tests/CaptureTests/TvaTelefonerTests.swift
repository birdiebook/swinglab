import Foundation
import XCTest
@testable import Capture

/// Klockorna och parningen mellan två telefoner (S2_SPEC §7.2–7.3), på påhittade
/// ping och klick. METOD MS6, MS9, MS10
final class TvaTelefonerTests: XCTestCase {
    /// Deterministiska tal i [0, 1) (samma LCG som klickets recept).
    struct Slump {
        var s: UInt64
        mutating func nasta() -> Double {
            s = (1_103_515_245 &* s &+ 12345) % 2_147_483_648
            return Double(s) / 2_147_483_648
        }
    }

    /// Ping med känd förskjutning θ och slumpmässig, osymmetrisk väg (1–20 ms fram, 1–20 ms tillbaka).
    static func ping(theta: Double, n: Int, fro: UInt64) -> [PingSample] {
        var r = Slump(s: fro)
        return (0..<n).map { i in
            let t0 = 100 + Double(i) * 0.02
            let fram = 0.001 + 0.019 * r.nasta(), tillbaka = 0.001 + 0.019 * r.nasta()
            let t1 = t0 + fram + theta
            let t2 = t1 + 0.0004
            return PingSample(t0: t0, t1: t1, t2: t2, t3: t2 - theta + tillbaka)
        }
    }

    func testKlockanInomOsakerheten() throws {
        for (theta, fro) in [(0.123456, UInt64(1)), (-3.5, 2), (1234.5678, 3)] {
            let s = Self.ping(theta: theta, n: 30, fro: fro)
            let o = try XCTUnwrap(ClockSync.estimate(s))
            XCTAssertEqual(o.samples, 30)
            XCTAssertLessThanOrEqual(abs(o.offset - theta), o.uncertainty + 1e-12)
            XCTAssertLessThan(o.uncertainty, 0.02)
            // Bättre än ett enskilt slumpvis prov i snitt: inom 10 ms.
            XCTAssertLessThan(abs(o.offset - theta), 0.01)
        }
    }

    func testFormelnOchOgiltigaProv() throws {
        let p = PingSample(t0: 10, t1: 15.004, t2: 15.005, t3: 10.011)
        XCTAssertEqual(p.theta, 5.0 - 0.001, accuracy: 1e-9)          // (5,004 + 4,994) / 2
        XCTAssertEqual(p.delta, 0.010, accuracy: 1e-9)
        XCTAssertNil(ClockSync.estimate([]))
        XCTAssertNil(ClockSync.estimate([PingSample(t0: 0, t1: 1, t2: 2, t3: 0.5)]))      // δ < 0
        let o = try XCTUnwrap(ClockSync.estimate([p, PingSample(t0: .nan, t1: 1, t2: 1, t3: 1)]))
        XCTAssertEqual(o.samples, 1)
        XCTAssertEqual(o.offset, p.theta)
        XCTAssertEqual(o.uncertainty, 0.005, accuracy: 1e-12)
    }

    func testDriften() {
        let a = ClockOffset(offset: 0.1, uncertainty: 0.001, samples: 30)
        let b = ClockOffset(offset: 0.1001, uncertainty: 0.001, samples: 30)
        XCTAssertEqual(ClockSync.drift(a, at: 0, b, at: 100), 1.0, accuracy: 1e-6)
        XCTAssertEqual(ClockSync.drift(a, at: 5, b, at: 5), 0)
    }

    // MARK: Parningen

    static let a = [1.0, 3.2, 5.9, 8.4, 11.0, 13.3, 16.05]
    static let jitter = [0.0012, -0.0021, 0.0035, -0.0008, 0.0017, -0.0031, 0.0004]

    /// b = a + d med jitter, utan a:s femte, med ett eget klick; a får också ett eget.
    static func listor(_ d: Double) -> (a: [Double], b: [Double]) {
        var b = zip(a, jitter).map { $0 + d + $1 }
        b.remove(at: 4)
        b.append(9.9 + d + 0.37)
        return (a + [7.15], b.sorted())
    }

    func testKandForskjutningMedOchUtanPrior() {
        let (a, b) = Self.listor(2.347)
        for prior in [nil, 2.30, 2.5] as [Double?] {
            let p = ClickPairing.pair(a, b, prior: prior)
            XCTAssertEqual(p.offset, 2.347, accuracy: 0.002, "\(String(describing: prior))")
            XCTAssertEqual(p.pairs.count, 6)
            XCTAssertFalse(p.pairs.contains { $0.a == 4 || $0.a == 7 })    // det b missade och a:s eget
            XCTAssertLessThan(p.medianAbsResidual ?? 1, 0.003)
            for x in p.pairs {
                XCTAssertEqual(x.residual, a[x.a] + p.offset - b[x.b], accuracy: 1e-12)
            }
        }
        let neg = Self.listor(-7.25)
        XCTAssertEqual(ClickPairing.pair(neg.a, neg.b, prior: nil).offset, -7.25, accuracy: 0.002)
    }

    func testPriorUtanforFonstretParadeInget() {
        let (a, b) = Self.listor(2.347)
        let p = ClickPairing.pair(a, b, prior: 1.0)
        XCTAssertEqual(p.offset, 1.0)
        XCTAssertTrue(p.pairs.isEmpty)
        XCTAssertNil(p.medianAbsResidual)
        // Ingen ping efter stopp: fönstret vidgas till ± 0,5 s (S2_SPEC §7.4).
        XCTAssertEqual(ClickPairing.pair(a, b, prior: 2.0, priorWindow: 0.5).pairs.count, 6)
        XCTAssertEqual(ClickPairing.pair([], b, prior: nil), ClickPairing(offset: 0, pairs: []))
    }

    func testLjudetsVag() {
        XCTAssertEqual(ClickPairing.soundDelay(distance: 3.0), 0.008746, accuracy: 1e-6)
        XCTAssertEqual(ClickPairing.soundDelay(distance: 0.5) * 1000, 1.458, accuracy: 0.001)
    }
}
