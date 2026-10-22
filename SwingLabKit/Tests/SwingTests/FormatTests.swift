import XCTest
@testable import Swing

/// Indataformatet (docs/FORMAT.md, METOD M1).
final class FormatTests: XCTestCase {
    /// En ruta med 13 leder kring `bas`, alla med konfidensen `konf`.
    static func ruta(_ t: Double, _ bas: Double, konf: Double = 0.9) -> String {
        let leder = (0..<13).map { j in "[\(bas + Double(j)), \(bas + 100.0 + Double(j)), \(konf)]" }
        return "{\"t\": \(t), \"leder\": [\(leder.joined(separator: ", "))]}"
    }

    static func sving(vy: String = "fo", hand: String = "hoger", riktning: String = "\"x_mot_malet\": 1,",
                      rutor: String? = nil) -> String {
        let r = rutor ?? "\(ruta(0.5, 100)), \(ruta(0.2, 300))"
        return """
        {"format": 1, "vy": "\(vy)", "hand": "\(hand)", \(riktning)
         "spelarens_langd_m": 1.8, "t_klick": 1.0, "rutor": [\(r)]}
        """
    }

    func testRutornaSorterasPaTiden() throws {
        let s = try Sving.las(json: Self.sving())
        XCTAssertEqual(s.t, [0.2, 0.5])
        XCTAssertEqual(s.led(.nasa)[0].x, 300.0)
        XCTAssertEqual(s.led(.axelF)[1].x, 101.0)           // främre = vänster för höger
        XCTAssertEqual(s.led(.fotledB)[1].y, 212.0)
    }

    func testVansterspelarenByterSidaOchSpeglarX() throws {
        let s = try Sving.las(json: Self.sving(hand: "vanster", riktning: "\"x_mot_malet\": -1,"))
        XCTAssertEqual(s.led(.axelF)[1].x, -102.0)          // främre = höger, x vänt
        XCTAssertEqual(s.led(.axelB)[1].x, -101.0)
        XCTAssertEqual(s.led(.nasa)[1].y, 200.0)
        let utan = try Sving.las(json: Self.sving(hand: "vanster", riktning: ""))
        XCTAssertEqual(utan.xTecken, -1.0)
        let hoger = try Sving.las(json: Self.sving(riktning: ""))
        XCTAssertEqual(hoger.xTecken, 1.0)
    }

    func testLagKonfidensArSaknad() throws {
        let s = try Sving.las(json: Self.sving(rutor: "\(Self.ruta(0.1, 100, konf: 0.29)), \(Self.ruta(0.2, 100))"))
        XCTAssertFalse(s.led(.hoftF)[0].hel)
        XCTAssertTrue(s.led(.hoftF)[1].hel)
    }

    func testFixturernaGarAttLasa() throws {
        for f in Fixturer.svingar {
            let s = try Sving.las(json: f.indata)
            XCTAssertGreaterThan(s.t.count, 400, f.namn)
            XCTAssertEqual(s.leder.count, 13)
            XCTAssertTrue(zip(s.t, s.t.dropFirst()).allSatisfy { $0 < $1 }, f.namn)
            // Ojämna steg: en del av 240-rutnätet saknas.
            let steg = zip(s.t, s.t.dropFirst()).map { $1 - $0 }
            XCTAssertGreaterThan(steg.max()!, 1.5 / 240, f.namn)
        }
    }

    func assertFel(_ json: String, innehaller: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try Sving.las(json: json), file: file, line: line) { fel in
            XCTAssertTrue("\(fel)".contains(innehaller), "\(fel)", file: file, line: line)
        }
    }

    func testFelenNamnerFaltet() {
        assertFel(Self.sving(vy: "sida"), innehaller: "vy")
        assertFel(Self.sving(hand: "båda"), innehaller: "hand")
        assertFel(Self.sving(riktning: "\"x_mot_malet\": 2,"), innehaller: "x_mot_malet")
        assertFel(Self.sving(rutor: ""), innehaller: "rutor")
        assertFel("{\"format\": 1,", innehaller: "JSON")
        let tolv = (0..<12).map { _ in "[1.0, 2.0, 0.9]" }.joined(separator: ", ")
        assertFel(Self.sving(rutor: "{\"t\": 0.1, \"leder\": [\(tolv)]}"), innehaller: "ruta 0")
    }

    func testFeletVisarAldrigVardet() {
        let ond = "{\"t\": 0.3, \"leder\": [[123.456, \"x\", 0.9]]}"
        XCTAssertThrowsError(try Sving.las(json: Self.sving(rutor: "\(Self.ruta(0.1, 100)), \(ond)"))) { fel in
            XCTAssertTrue("\(fel)".contains("rutor"), "\(fel)")
            XCTAssertFalse("\(fel)".contains("123.456"), "\(fel)")
            XCTAssertFalse("\(fel)".contains("\"x\""), "\(fel)")
        }
    }
}
