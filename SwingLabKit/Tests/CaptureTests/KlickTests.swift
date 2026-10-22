import Foundation
import XCTest
@testable import Capture

/// Klicket (METOD MS4) och parningen (METOD MS10) mot Pythons tal (KlickFixturer.swift),
/// som i sin tur är Golf SG:s klick() (tools/tests/test_klick.py). BESLUT B12.
final class KlickTests: XCTestCase {
    struct Recept: Decodable {
        struct K: Decodable {
            let prov: Int
            let amp: Double
        }

        let namn: String
        let sr: Double
        let langd_s: Double
        let fro: UInt64
        let brus: Double
        let klick: [K]
        let hela: [[Double]]
        let bitar: [[Double]]
    }

    struct Para: Decodable {
        let namn: String
        let a: [Double]
        let b: [Double]
        let prior: Double?
        let forskjutning: Double
        let par: [[Double]]
        let antal: Int
        let nast_bast: Double?
        let nast_antal: Int
        let osaker: Bool
        let prior_fonster: Double?
    }

    struct Fil: Decodable {
        let klick: [Recept]
        let para: [Para]
    }

    static let fil: Fil = try! JSONDecoder().decode(Fil.self, from: Data(KlickFixturer.json.utf8))

    /// Receptets signal, som tools/pc/klickljud.py signal(): LCG-brus och klick, i Double, sist Float.
    static func signal(_ r: Recept) -> [Float] {
        let n = Int((r.langd_s * r.sr).rounded())
        var s = r.fro
        var x = [Double](repeating: 0, count: n)
        for i in 0..<n {
            s = (1_103_515_245 &* s &+ 12345) % 2_147_483_648
            let u = Double(s)
            x[i] = (2.0 * (u / 2_147_483_648.0) - 1.0) * r.brus
        }
        for k in r.klick {
            for j in 0..<10 where k.prov + j < n {
                x[k.prov + j] += j % 2 == 0 ? k.amp : -k.amp
            }
        }
        return x.map { Float($0) }
    }

    static func prov(_ c: Click, _ sr: Double) -> Int { Int((c.time * sr).rounded()) }

    func jamfor(_ swift: [Click], _ python: [[Double]], sr: Double, _ namn: String) {
        XCTAssertEqual(swift.map { Self.prov($0, sr) }, python.map { Int($0[0]) }, "\(namn): ansatsens prov")
        guard swift.count == python.count else { return }
        for (c, p) in zip(swift, python) {
            XCTAssertLessThan(abs(c.strength / p[1] - 1), 1e-6, "\(namn): styrkan")
        }
    }

    func testSammaKlickSomPythonPaHelaSignalen() {
        for r in Self.fil.klick {
            jamfor(ClickDetector.detect(Self.signal(r), sampleRate: r.sr), r.hela, sr: r.sr, r.namn)
        }
    }

    func testSammaKlickSomPythonIBitar() {
        for r in Self.fil.klick {
            jamfor(ClickDetector.detectSegmented(Self.signal(r), sampleRate: r.sr), r.bitar, sr: r.sr, r.namn)
        }
    }

    func testRecepetProvarDetDetSka() {
        let lang = Self.fil.klick.first { $0.namn == "lang" }!
        XCTAssertEqual(ClickDetector.segments(count: Int(lang.langd_s * lang.sr)).count, 3)
        XCTAssertEqual(lang.hela.map { $0[0] }, lang.bitar.map { $0[0] })      // klicken i överlappen en gång
        let grans = Self.fil.klick.first { $0.namn == "bitgrans" }!
        XCTAssertEqual(grans.hela.count, 4)
        XCTAssertEqual(grans.hela.map { $0[0] }, grans.bitar.map { $0[0] })    // klicken vid bitgränserna
        XCTAssertEqual(ClickDetector.edge(), 1056)
        XCTAssertTrue(Self.fil.klick.contains { $0.namn == "bara_brus" && $0.hela.isEmpty })
        XCTAssertTrue(Self.fil.klick.contains { $0.sr == 44100 })
    }

    func testEnImpulsGerAnsatsen47ProvFore() {
        var x = [Float](repeating: 0, count: 48000)
        x[20000] = 0.5
        let k = ClickDetector.detect(x)
        XCTAssertEqual(k.count, 1)
        XCTAssertEqual(k.first.map { Self.prov($0, 48000) }, 20000 - 47)
    }

    func testTvaKlickNaraBlirEtt() {
        let r = Self.fil.klick.first { $0.namn == "nara" }!
        let k = ClickDetector.detect(Self.signal(r))
        XCTAssertEqual(k.count, 1)
        XCTAssertEqual(k[0].time, 1.4, accuracy: 0.002)
    }

    func testKantregelnKastarDetKapadeKlicket() {
        // Utan regeln hittas klicket 13 prov in i bit 2 med kapad energi, på fel prov.
        let r = Self.fil.klick.first { $0.namn == "bitgrans" }!
        let x = Self.signal(r)
        let bit = Array(x[1_392_000..<2_832_000])
        let kapat = ClickDetector.detect(bit)
        XCTAssertNotEqual(kapat.first.map { 1_392_000 + Self.prov($0, 48000) }, Int(r.hela[0][0]))
        let med = ClickDetector.detect(bit, innerStart: true, innerEnd: true)
        XCTAssertEqual(med.count, kapat.count - 2)      // klicket vid början och det i bitens sista prov
    }

    func testKortSignalGerInget() {
        XCTAssertEqual(ClickDetector.detect([Float](repeating: 0, count: 5)), [])
        XCTAssertEqual(ClickDetector.detect([Float](repeating: 0.1, count: 50)), [])
        XCTAssertEqual(ClickDetector.detect([]), [])
    }

    func testBitarna() {
        XCTAssertEqual(ClickDetector.segments(count: 480_000), [0..<480_000])
        XCTAssertEqual(ClickDetector.segments(count: 61 * 48000),
                       [0..<1_440_000, 1_392_000..<2_832_000, 2_784_000..<2_928_000])
        XCTAssertEqual(ClickDetector.segments(count: 30 * 48000), [0..<1_440_000])
        XCTAssertEqual(ClickDetector.segments(count: 0), [0..<0])
    }

    func testSlaIhopTarDetStarkaste() {
        let k = ClickDetector.merge([
            (start: 0, clicks: [Click(time: 1.0, strength: 50), Click(time: 29.5, strength: 40)]),
            (start: 29, clicks: [Click(time: 0.5001, strength: 45), Click(time: 5.0, strength: 30)]),
        ])
        XCTAssertEqual(k.map(\.strength), [50, 45, 30])
        XCTAssertEqual(k[1].time, 29.5001, accuracy: 1e-12)
    }

    func testParningenSomPython() {
        for p in Self.fil.para {
            let r = ClickPairing.pair(p.a, p.b, prior: p.prior,
                                      priorWindow: p.prior_fonster ?? ClickPairing.defaultPriorWindow)
            XCTAssertEqual(r.offset, p.forskjutning, accuracy: 1e-9, p.namn)
            XCTAssertEqual(r.count, p.antal, p.namn)
            XCTAssertEqual(r.secondBestCount, p.nast_antal, p.namn)
            XCTAssertEqual(r.uncertain, p.osaker, p.namn)
            XCTAssertEqual(r.secondBestOffset == nil, p.nast_bast == nil, p.namn)
            if let x = r.secondBestOffset, let y = p.nast_bast { XCTAssertEqual(x, y, accuracy: 1e-9, p.namn) }
            XCTAssertEqual(r.pairs.map { [$0.a, $0.b] }, p.par.map { [Int($0[0]), Int($0[1])] }, p.namn)
            for (x, y) in zip(r.pairs, p.par) {
                XCTAssertEqual(x.residual, y[2], accuracy: 1e-9, p.namn)
            }
        }
    }
}
