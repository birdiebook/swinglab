import Foundation
import XCTest
@testable import Capture

/// Uppställningens lutning (S6c-2, METOD MS19): påhittade telefoner i stående läge.
final class LutningTests: XCTestCase {
    func testRakTelefonLutarInte() throws {
        let l = try XCTUnwrap(Lutning(gravity: [0, -1, 0]))
        XCTAssertEqual(l.sida, 0, accuracy: 1e-12)
        XCTAssertEqual(l.franLodlinjen, 0, accuracy: 1e-6)
        XCTAssertFalse(l.forStorFor3D)
    }

    func testAtSidanOchFramat() throws {
        let v = 10.0 * .pi / 180
        // Vriden runt skärmens normal: lutningen åt sidan är vinkeln.
        let a = try XCTUnwrap(Lutning(gravity: [sin(v), -cos(v), 0]))
        XCTAssertEqual(abs(a.sida), 10, accuracy: 1e-9)
        XCTAssertEqual(a.franLodlinjen, 10, accuracy: 1e-6)
        let b = try XCTUnwrap(Lutning(gravity: [-sin(v), -cos(v), 0]))
        XCTAssertEqual(b.sida, -a.sida, accuracy: 1e-9)
        // Framåt (kameran mot marken): ingen lutning åt sidan, men bort från lodlinjen.
        let p = 20.0 * .pi / 180
        let c = try XCTUnwrap(Lutning(gravity: [0, -cos(p), -sin(p)]))
        XCTAssertEqual(c.sida, 0, accuracy: 1e-9)
        XCTAssertEqual(c.franLodlinjen, 20, accuracy: 1e-6)
    }

    func testOver45GraderArForMycketFor3D() throws {
        let v = 50.0 * .pi / 180
        XCTAssertTrue(try XCTUnwrap(Lutning(gravity: [sin(v), -cos(v), 0])).forStorFor3D)
        // Liggande telefon i en stående fil: 90°.
        XCTAssertTrue(try XCTUnwrap(Lutning(gravity: [-1, 0, 0])).forStorFor3D)
    }

    func testTrasigaProvGerIngenLutning() {
        XCTAssertNil(Lutning(gravity: [0, 0, 0]))
        XCTAssertNil(Lutning(gravity: [.nan, -1, 0]))
        XCTAssertNil(Lutning(gravity: [0, -1]))
    }
}
