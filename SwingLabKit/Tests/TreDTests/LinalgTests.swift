import Foundation
import XCTest
@testable import TreD

/// Den egna linjära algebran (BESLUT B48, METOD M50). Talen i jämförelserna är numpys,
/// räknade i Python och skrivna här (repr, alltså exakta).
final class LinalgTests: XCTestCase {
    func testArangeSomNumpy() {
        // np.arange(-1.8403, 1.4467, 1/240) och (-0.4105, 0.1605, 0.0005): längd och värden.
        let a = LA.arange(-1.8403, 1.4467, 1.0 / 240)
        XCTAssertEqual(a.count, 789)
        XCTAssertEqual(a[1], -1.8361333333333334)
        XCTAssertEqual(a[2], -1.8319666666666667)
        XCTAssertEqual(a[394], -0.1986333333333392)
        XCTAssertEqual(a[788], 1.4430333333333216)
        let b = LA.arange(-0.4105, 0.1605, 0.0005)
        XCTAssertEqual(b.count, 1142)
        XCTAssertEqual(b[1], -0.41)
        XCTAssertEqual(b[571], -0.12499999999999972)
        XCTAssertEqual(b[1141], 0.16000000000000048)
        XCTAssertEqual(LA.arange(0.05, 3.2, 1.0 / 60).count, 190)
        XCTAssertEqual(LA.arange(1, 1, 0.1), [])
    }

    func testSummanArNumpysParvisa() {
        let v = (0..<1000).map { 1.0 / Double($0 + 3) + Double($0) * 0.1 }
        XCTAssertEqual(LA.summa(v), 49955.98746786553)            // numpy; i tur och ordning: …496
        XCTAssertEqual(LA.summa(Array(v[0..<37])), 69.35354303893638)
        XCTAssertEqual(LA.medel(Array(v[0..<600])), 29.959130505741747)
    }

    func testMedianOchAvrundning() {
        XCTAssertEqual(LA.median([3, 1, 2, 10]), 2.5)
        XCTAssertEqual(LA.median([3, 1, 2]), 2)
        XCTAssertTrue(LA.nanmedian([.nan, .nan]).isNaN)
        XCTAssertEqual(LA.nanmedian([.nan, 4, 1]), 2.5)
        // Pythons round: det binära talet, lika till jämnt.
        XCTAssertEqual(LA.avrunda(2.675, 2), 2.67)
        XCTAssertEqual(LA.avrunda(0.125, 2), 0.12)
        XCTAssertEqual(LA.avrunda(4.305, 2), 4.3)
        XCTAssertEqual(LA.avrunda(-1.25, 1), -1.2)
        XCTAssertEqual(LA.avrunda(17.15, 1), 17.1)
    }

    func testSokningOchInterpolation() {
        let x = [0.0, 1, 1, 2, 4]
        XCTAssertEqual(LA.vanster(x, 1), 1)
        XCTAssertEqual(LA.hoger(x, 1), 3)
        XCTAssertEqual(LA.interp(3, [0, 2, 4], [0, 10, 30]), 20)
        XCTAssertEqual(LA.interp(4, [0, 2, 4], [0, 10, 30]), 30)
        XCTAssertEqual(LA.interp(-1, [0, 2, 4], [5, 10, 30]), 5)
    }

    func testLosMedPivotering() throws {
        let a: [Double] = [0, 2, 1, 1, 1, 1, 2, 1, 0]
        let x: [Double] = [1, -2, 3]
        let b = LA.mul(a, x, 3, 3, 1)
        let l = try LA.los(a, b, 3, 1)
        for i in 0..<3 { XCTAssertEqual(l[i], x[i], accuracy: 1e-12) }
        XCTAssertThrowsError(try LA.los([1, 2, 2, 4], [1, 1], 2, 1))
        let inv = try LA.inv([1444, 0, 540, 0, 1444, 960, 0, 0, 1], 3)
        XCTAssertEqual(Array(inv[6...]), [0, 0, 1])
        XCTAssertEqual(inv[2], -540.0 / 1444, accuracy: 1e-15)
    }

    func testJacobiGerOrtogonalaVektorerOchRattNollrum() {
        // Rang 3 i 4 kolumner: nollvektorn är (1, −1, 2, 1)/√7 upp till tecknet.
        let n: [Double] = [1, -1, 2, 1]
        var rader: [[Double]] = []
        for k in 0..<6 {
            let r = [Double(k) + 1, Double(k * k % 5), Double(k % 3) - 1, 0.5 * Double(k)]
            // Ta bort komponenten längs n så att A·n = 0.
            let s = zip(r, n).map(*).reduce(0, +) / 7
            rader.append(zip(r, n).map { $0 - s * $1 })
        }
        var a = [Double](repeating: 0, count: 24)
        for i in 0..<6 { for j in 0..<4 { a[j * 6 + i] = rader[i][j] } }
        let v = LA.nollvektor(&a, 6, 4)
        let tecken = v[0] > 0 ? 1.0 : -1.0
        for i in 0..<4 { XCTAssertEqual(tecken * v[i], n[i] / 7.0.squareRoot(), accuracy: 1e-12) }
    }

    func testSvd3AterskaparMatrisen() {
        let e: [Double] = [0.2, -1.3, 0.4, 0.9, 0.1, -0.7, -0.3, 0.8, 1.1]
        let (u, s, v) = LA.svd3(e)
        XCTAssertGreaterThanOrEqual(s[0], s[1])
        XCTAssertGreaterThanOrEqual(s[1], s[2])
        XCTAssertEqual(LA.det3(u), 1, accuracy: 1e-12)
        for i in 0..<3 {
            for j in 0..<3 {
                var x = 0.0
                for k in 0..<3 { x += u[i * 3 + k] * s[k] * v[j * 3 + k] }
                XCTAssertEqual(x, e[i * 3 + j], accuracy: 1e-12)
            }
        }
    }

    func testRodriguesOchVarlden() {
        let r = LA.rodrigues([0, 0, Double.pi / 2])
        let x = LA.mulv3(r, [1, 0, 0])
        XCTAssertEqual(x[0], 0, accuracy: 1e-15)
        XCTAssertEqual(x[1], 1, accuracy: 1e-15)
        XCTAssertEqual(LA.rodrigues([0, 0, 0]), LA.enhet3)
        // Världen: z = uppåt (A:s −y), x = A:s blickriktning.
        let (a, _) = Kalibrering.varld(LA.enhet3, LA.enhet3, LA.enhet3, [1, 0, 0], [0, -1, 0])
        XCTAssertEqual(a.r[2], 0)
        XCTAssertEqual(a.r[1], -1)
        XCTAssertEqual(a.r[5], -1)
        XCTAssertEqual(a.r[6], 1)
    }

    func testUrvaletArEnPermutationSomPythons() {
        // Samma index som tools/pc/tva_kameror.urval (test_tre_d_fixturer.py). METOD M50, BESLUT B48
        XCTAssertEqual(TvaKameror.urval(10, 4), [0, 7, 4, 1])
        let v = TvaKameror.urval(18_731, 5000)
        XCTAssertEqual(Array(v.prefix(3)), [0, 11_576, 4_421])
        XCTAssertEqual(Set(v).count, 5000)
        XCTAssertEqual(TvaKameror.urval(26, 26).sorted(), Array(0..<26))
    }
}
