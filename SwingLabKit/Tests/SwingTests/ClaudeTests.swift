import Foundation
import XCTest
@testable import Swing

/// S5b: underlaget till Claude-appen och svaret tillbaka. Python är facit (BESLUT B12, B53, B54):
/// tools/tests/fixturer/claude_facit.json bär påhittade passhistoriker, Pythons text för dem
/// och svarstexter med Pythons felkoder (`python3 tools/pc/underlag.py --swift`).
final class ClaudeTests: XCTestCase {
    static let rot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    static let facit: JSONVarde = {
        let url = rot.appendingPathComponent("tools/tests/fixturer/claude_facit.json")
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        return (try? JSONVarde.las(text)) ?? .null
    }()

    func katalog() throws -> Katalog {
        try Katalog.las(Data(contentsOf: Self.rot.appendingPathComponent("katalog.json")))
    }

    /// En påhittad historik ur facit: passen som rader och valen som filer.
    func historik(_ h: JSONVarde) throws -> (passen: [Passrader], filer: [AttJobbaPa], skapad: String) {
        let passen = try XCTUnwrap(h["pass"]?.somLista).map { p -> Passrader in
            let slag = (p["slag"]?.somLista ?? []).map { s -> Slagrad in
                var matt: [String: Double] = [:]
                for (k, v) in s["matt"]?.somObjekt?.par ?? [] { matt[k] = v.somTal }
                return Slagrad(vy: s["vy"]?.somText == "dtl" ? .dtl : .fo, klubba: s["klubba"]?.somText, matt: matt,
                               forstaSerien: s["forsta_serien"] == .bool(true))
            }
            return Passrader(pass: p["pass"]?.somText ?? "", slag: slag)
        }
        let filer = try (h["att_jobba_pa"]?.somLista ?? []).map { try AttJobbaPa.las(Data($0.skriv().utf8)) }
        return (passen, filer, h["skapad"]?.somText ?? "")
    }

    /// Den första raden där texterna skiljer sig, för ett läsbart fel i Actions.
    func skillnad(_ a: String, _ b: String) -> String {
        let x = a.components(separatedBy: "\n"), y = b.components(separatedBy: "\n")
        for i in 0..<max(x.count, y.count) {
            let r = i < x.count ? x[i] : "<slut>", s = i < y.count ? y[i] : "<slut>"
            if r != s { return "rad \(i + 1):\nSwift:  \(r)\nPython: \(s)" }
        }
        return "lika"
    }

    func testFacitFinns() {
        XCTAssertNotEqual(Self.facit, .null, "tools/tests/fixturer/claude_facit.json saknas eller går inte att läsa")
        XCTAssertEqual(Self.facit["historiker"]?.somLista?.count, 3)
    }

    /// BESLUT B53: appen bär skillens avsnitt och kedjorna ordagrant.
    func testInstruktionenOchKedjornaArKallornas() throws {
        XCTAssertEqual(ClaudeKallor.instruktion, Self.facit["instruktion"]?.somText)
        let kedjor = try String(contentsOf: Self.rot.appendingPathComponent("tools/pc/kedjor.json"), encoding: .utf8)
        XCTAssertEqual(ClaudeKallor.kedjor + "\n", kedjor)
        XCTAssertEqual(Kedjor.appens.faser.first, "adress")
        XCTAssertEqual(Kedjor.appens.orsaker("early_extension").map(\.vag),
                       [["reverse_spine", "early_extension"], ["sway_topp", "reverse_spine", "early_extension"]])
    }

    func testKodblocken() throws {
        for fall in try XCTUnwrap(Self.facit["kodblock"]?.somLista) {
            let l = try XCTUnwrap(fall.somLista)
            XCTAssertEqual(ClaudeSvar.kodblock(l[0].somText ?? ""), l[1].somLista?.compactMap(\.somText),
                           l[0].somText ?? "")
        }
    }

    /// Samma påhittade passhistorik ger samma text som Python, tecken för tecken.
    func testTextenArPythons() throws {
        let k = try katalog()
        for h in try XCTUnwrap(Self.facit["historiker"]?.somLista) {
            let namn = h["namn"]?.somText ?? ""
            let (passen, filer, skapad) = try historik(try XCTUnwrap(h["historik"]))
            let u = try XCTUnwrap(ClaudeUnderlag(passen: passen, filer: filer, skapad: skapad, katalog: k))
            let python = h["text"]?.somText ?? ""
            XCTAssertEqual(u.text, python, "\(namn): \(skillnad(u.text, python))")
        }
    }

    /// Svarstexterna: samma godkända och samma felkoder som Python.
    func testSvarenSomPython() throws {
        let k = try katalog()
        let h = try XCTUnwrap(Self.facit["historiker"]?.somLista?.first)
        let (passen, filer, skapad) = try historik(try XCTUnwrap(h["historik"]))
        let u = try XCTUnwrap(ClaudeUnderlag(passen: passen, filer: filer, skapad: skapad, katalog: k))
        let svar = try XCTUnwrap(h["svar"]?.somLista)
        XCTAssertGreaterThanOrEqual(svar.count, 10)
        for s in svar {
            let namn = s["namn"]?.somText ?? ""
            let r = u.svar(s["text"]?.somText ?? "")
            let python = (s["fel"]?.somLista ?? []).map { f in
                Kontrollfel(f.somLista?[0].somText ?? "", f.somLista?[1].somText ?? "")
            }
            XCTAssertEqual(r.felen, python, namn)
            if case let .godkand(data, focus) = r {
                XCTAssertEqual(s["godkand"], .bool(true), namn)
                XCTAssertEqual(focus.pass, "20261120-180000")
                XCTAssertEqual(try AttJobbaPa.las(data).saker.count, focus.saker.count)
            } else {
                XCTAssertEqual(s["godkand"], .bool(false), namn)
            }
        }
    }

    /// Dataregeln: felen nämner fältet, aldrig det som stod i svaret.
    func testFelenNamnerFaltAldrigVarden() throws {
        let k = try katalog()
        let h = try XCTUnwrap(Self.facit["historiker"]?.somLista?.first)
        let (passen, filer, skapad) = try historik(try XCTUnwrap(h["historik"]))
        let u = try XCTUnwrap(ClaudeUnderlag(passen: passen, filer: filer, skapad: skapad, katalog: k))
        for s in try XCTUnwrap(h["svar"]?.somLista) {
            for f in u.svar(s["text"]?.somText ?? "").felen {
                XCTAssertNotEqual(Texter.kontrollfel(f.kod), "invalid", f.kod)
                for v in ["slice", "Great", "good", "Feet together", "2026-13-01", "-1"] {
                    XCTAssertFalse(f.text.contains(v), "\(f.text) bär \(v)")
                }
            }
        }
    }

    /// Ett typiskt pass (två vyer, sex pass) ryms i cirka 8 kB data. METOD MT11
    func testStorleken() throws {
        let k = try katalog()
        let h = try XCTUnwrap(Self.facit["historiker"]?.somLista?.first)
        let (passen, filer, skapad) = try historik(try XCTUnwrap(h["historik"]))
        let u = try XCTUnwrap(ClaudeUnderlag(passen: passen, filer: filer, skapad: skapad, katalog: k))
        XCTAssertLessThanOrEqual(u.text.utf8.count - ClaudeKallor.instruktion.utf8.count, 8 * 1024)
        XCTAssertLessThanOrEqual(u.text.utf8.count, 16 * 1024)
    }

    func testJSONLasningOchSkrivning() throws {
        XCTAssertEqual(try JSONVarde.las(" {\"a\": [1, 2.5e1, -0.5, true, null, \"x\\u00e5\\n\"]} \r\n").skriv(),
                       "{\n\"a\":[\n1,\n25,\n-0.5,\ntrue,\nnull,\n\"x\u{e5}\\n\"\n]\n}")
        for fel in ["", "{", "[1,]", "{\"a\":1,}", "01", "1.", "NaN", "-Infinity", "\"a\nb\"", "{'a': 1}", "[1] x",
                    "\u{FEFF}{}"] {
            XCTAssertThrowsError(try JSONVarde.las(fel), fel)
        }
        XCTAssertEqual(try JSONVarde.las("{\"a\":1,\"b\":2,\"a\":3}").skriv(), "{\n\"a\":3,\n\"b\":2\n}")
        XCTAssertEqual(JSONVarde.talText(0.1), "0.1")
        XCTAssertEqual(JSONVarde.talText(-0.0), "0")
        XCTAssertEqual(JSONVarde.talText(1e-05), "1e-05")
        XCTAssertEqual(JSONVarde.textText("a\"\\\u{01}"), "\"a\\\"\\\\\\u0001\"")
        XCTAssertTrue(JSONVarde.bool(true).lika(.tal(1)))
        XCTAssertTrue(JSONVarde.spann([0, nil]).lika(try JSONVarde.las("[0.0, null]")))
    }

    func testVardeordOchTiden() {
        XCTAssertTrue(AttJobbaPaKontroll.harVardeord("Well   done"))
        XCTAssertTrue(AttJobbaPaKontroll.harVardeord("A GREAT turn"))
        XCTAssertFalse(AttJobbaPaKontroll.harVardeord("Welldone badge"))
        XCTAssertFalse(AttJobbaPaKontroll.harVardeord("Supination of the lead wrist"))
        for ok in ["2026-11-03", "2026-11-03T21:15:00+01:00", "2026-11-03T21:15Z", "2026-11-03 21:15:00.123456"] {
            XCTAssertTrue(AttJobbaPaKontroll.skapadOK(.text(ok)), ok)
        }
        for nej in ["2026-13-01", "2026-02-30", "2026-11-03T24:00", "3 nov", "2026-11-03T21:15:00.1234567"] {
            XCTAssertFalse(AttJobbaPaKontroll.skapadOK(.text(nej)), nej)
        }
    }
}
