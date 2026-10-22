import XCTest
@testable import Swing

/// Sessionen (METOD M25, M26) mot Pythons tal och mot handräknade.
final class SessionTests: XCTestCase {
    static let tolerans = 1e-9

    func testPercentilenOchMedianen() {
        let s = [1.0, 2.0, 3.0, 4.0]
        XCTAssertEqual(Session.percentil(s, 0.5), 2.5)
        XCTAssertEqual(Session.percentil(s, 0.25), 1.75)
        XCTAssertEqual(Session.percentil([7.0], 0.75), 7.0)
    }

    func testRangernaOchTrenden() {
        XCTAssertEqual(Session.rang([10, 30, 20, 20]), [1, 4, 2.5, 2.5])
        XCTAssertEqual(Session.spearman([0, 1, 2, 3], [1, 5, 6, 90]), 1.0, accuracy: 1e-12)
        XCTAssertEqual(Session.spearman([0, 1, 2, 3], [9, 5, 2, 1]), -1.0, accuracy: 1e-12)
        XCTAssertEqual(Session.spearman([0, 1, 2], [4, 4, 4]), 0.0)
    }

    func testHandraknat() {
        let s = Session.sammanfatta([1.0, 2.0, 3.0, 4.0, 100.0].map { ["a": $0] })["a"]!
        XCTAssertEqual([Double(s.n), s.median, s.q1, s.q3, s.min, s.max], [5, 3, 2, 4, 1, 100])
        XCTAssertEqual(s.avvikare, [4])                     // MAD 1 → gränsen 4,45 från medianen
        XCTAssertEqual(s.trend, 1.0, accuracy: 1e-12)
        XCTAssertTrue(Session.sammanfatta([["a": 1.0], ["a": 2.0]]).isEmpty)  // för få
    }

    func testSammanfattningenSomPython() throws {
        let py = try avkoda(PythonSession.self, Fixturer.session)
        var jamforda = 0
        for (pass, svingar) in [("nu", py.nu), ("forra", py.forra)] {
            let swift = Session.sammanfattaSession(svingar)
            for grupp in Session.grupper {
                let a = swift[grupp]!, b = py.sammanfattning[pass]![grupp]!
                XCTAssertEqual(Set(a.keys), Set(b.keys), "\(pass) \(grupp)")
                for (k, p) in b {
                    guard let s = a[k] else { continue }
                    let namn = "\(pass) \(grupp) \(k)"
                    XCTAssertEqual(s.n, p.n, namn)
                    XCTAssertEqual(s.avvikare, p.avvikare, namn)
                    for (x, y) in [(s.median, p.median), (s.q1, p.q1), (s.q3, p.q3), (s.sd, p.sd),
                                   (s.min, p.min), (s.max, p.max), (s.trend, p.trend)] {
                        XCTAssertEqual(x, y, accuracy: Self.tolerans, namn)
                    }
                    jamforda += 1
                }
            }
        }
        XCTAssertGreaterThan(jamforda, 150)
    }

    func testJamforelsenSomPython() throws {
        let py = try avkoda(PythonSession.self, Fixturer.session)
        let nu = Session.sammanfattaSession(py.nu), forra = Session.sammanfattaSession(py.forra)
        var tydliga = 0
        for grupp in Session.grupper {
            let j = Session.jamfor(nu: nu[grupp]!, forra: forra[grupp]!)
            let p = py.jamforelse[grupp]!
            XCTAssertEqual(Set(j.keys), Set(p.keys), grupp)
            for (k, v) in p {
                guard let s = j[k] else { continue }
                XCTAssertEqual(s.skillnad, v.skillnad, accuracy: Self.tolerans, "\(grupp) \(k)")
                XCTAssertEqual(s.spridning, v.spridning, accuracy: Self.tolerans, "\(grupp) \(k)")
                XCTAssertEqual(s.tydlig, v.tydlig, "\(grupp) \(k)")
                tydliga += s.tydlig ? 1 : 0
            }
        }
        XCTAssertGreaterThan(tydliga, 0)                    // thrusten stiger genom passet
    }
}
