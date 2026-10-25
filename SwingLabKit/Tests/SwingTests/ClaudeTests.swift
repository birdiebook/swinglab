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
    func historik(_ h: JSONVarde) throws -> (passen: [Passrader], filer: [AttJobbaPa], skapad: String, nu: String) {
        let passen = try XCTUnwrap(h["pass"]?.somLista).map { p -> Passrader in
            let slag = (p["slag"]?.somLista ?? []).map { s -> Slagrad in
                var matt: [String: Double] = [:]
                for (k, v) in s["matt"]?.somObjekt?.par ?? [] { matt[k] = v.somTal }
                return Slagrad(vy: s["vy"]?.somText == "dtl" ? .dtl : .fo, klubba: s["klubba"]?.somText, matt: matt,
                               forstaSerien: s["forsta_serien"] == .bool(true))
            }
            return Passrader(pass: p["pass"]?.somText ?? "", langd: p["langd"]?.somTal, slag: slag)
        }
        let filer = try (h["att_jobba_pa"]?.somLista ?? []).map { try AttJobbaPa.las(Data($0.skriv().utf8)) }
        return (passen, filer, h["skapad"]?.somText ?? "", h["nu"]?.somText ?? "")
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
        XCTAssertEqual(Self.facit["historiker"]?.somLista?.count, 8)
    }

    /// Underlaget för en historik ur facit.
    func underlag(_ h: JSONVarde) throws -> ClaudeUnderlag {
        let (passen, filer, skapad, nu) = try historik(try XCTUnwrap(h["historik"]))
        return try XCTUnwrap(ClaudeUnderlag(passen: passen, nu: nu, filer: filer, skapad: skapad, katalog: try katalog()))
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
            let (passen, filer, skapad, nu) = try historik(try XCTUnwrap(h["historik"]))
            let u = try XCTUnwrap(ClaudeUnderlag(passen: passen, nu: nu, filer: filer, skapad: skapad, katalog: k))
            let python = h["text"]?.somText ?? ""
            XCTAssertEqual(u.text, python, "\(namn): \(skillnad(u.text, python))")
        }
    }

    /// Svarstexterna: samma godkända och samma felkoder som Python, i varje historik.
    func testSvarenSomPython() throws {
        var antal = 0
        for h in try XCTUnwrap(Self.facit["historiker"]?.somLista) {
            let u = try underlag(h)
            for s in h["svar"]?.somLista ?? [] {
                antal += 1
                let namn = (h["namn"]?.somText ?? "") + "/" + (s["namn"]?.somText ?? "")
                let r = u.svar(s["text"]?.somText ?? "")
                let python = (s["fel"]?.somLista ?? []).map { f in
                    Kontrollfel(f.somLista?[0].somText ?? "", f.somLista?[1].somText ?? "")
                }
                XCTAssertEqual(r.felen, python, namn)
                if case let .godkand(data, focus) = r {
                    XCTAssertEqual(s["godkand"], .bool(true), namn)
                    XCTAssertEqual(focus.pass, u.analys.pass, namn)
                    XCTAssertEqual(try AttJobbaPa.las(data).saker.count, focus.saker.count)
                } else {
                    XCTAssertEqual(s["godkand"], .bool(false), namn)
                }
            }
        }
        XCTAssertGreaterThanOrEqual(antal, 70)
    }

    /// Dataregeln: felen nämner fältet, aldrig det som stod i svaret.
    func testFelenNamnerFaltAldrigVarden() throws {
        for h in try XCTUnwrap(Self.facit["historiker"]?.somLista) {
            let u = try underlag(h)
            for s in h["svar"]?.somLista ?? [] {
                let felen = u.svar(s["text"]?.somText ?? "").felen
                for f in felen {
                    XCTAssertNotEqual(Texter.kontrollfel(f.kod), "invalid", f.kod)
                    for v in ["slice", "great", "Great", "Well", "igår", "-1", "20261399", "kg"] {
                        XCTAssertFalse(f.text.contains(v), "\(f.text) bär \(v)")
                    }
                }
                // Felet på enkel engelska (PLAN S4h): inget värde och inga svenska nycklar.
                let klar = Texter.kontrollfelKlartext(felen)
                XCTAssertEqual(klar.isEmpty, felen.isEmpty)
                for v in ["slice", "great", "Great", "Well", "igår", "-1", "20261399", "kg", "saker", "ovning", "tanke"] {
                    XCTAssertFalse(klar.contains(v), "\(klar) bär \(v)")
                }
                // Appens rad (S5b-2): det första felet och antalet till, inget värde.
                let rad = Texter.kontrollfelRad(felen)
                XCTAssertEqual(rad.isEmpty, felen.isEmpty)
                if let f = felen.first { XCTAssertTrue(rad.hasPrefix(Texter.kontrollfelText(f)), rad) }
                for v in ["slice", "great", "Great", "Well", "igår", "-1", "20261399", "kg"] {
                    XCTAssertFalse(rad.contains(v), "\(rad) bär \(v)")
                }
            }
        }
    }

    /// Felet på enkel engelska (PLAN S4h, BESLUT B94): delen och felet, och vad man gör; fältet
    /// står under "Details" (`kontrollfelRad`).
    func testFeletPaEnkelEngelska() {
        XCTAssertEqual(Texter.kontrollfelKlartext([]), "")
        XCTAssertEqual(Texter.kontrollfelKlartext([Kontrollfel("saker[0].ovning.tanke", "siffror")]),
                       "Claude's reply can't be used: the swing thought has digits. Ask Claude to try again.")
        XCTAssertEqual(Texter.kontrollfelKlartext([Kontrollfel("svaret", "inget_block"), Kontrollfel("skapad", "iso")]),
                       "Claude's reply can't be used: it has no Focus code block. Ask Claude to try again.")
        XCTAssertEqual(Texter.kontrollfelSak(Kontrollfel("saker[1].klart_nar.grans", "grans_tal")), "the done-when rule has the wrong form")
        XCTAssertEqual(Texter.kontrollfelSak(Kontrollfel("saker[0].ovning.text", "for_lang")), "the drill is too long")
        XCTAssertEqual(Texter.kontrollfelSak(Kontrollfel("saker[0].fel", "inte_flaggat")), "the fault does not match this session")
        XCTAssertEqual(Texter.kontrollfelSak(Kontrollfel("pass", "ej_i_analysen")), "this session has no measures yet")
        // En okänd nyckel är Claudes text: den står aldrig i meningen.
        XCTAssertEqual(Texter.kontrollfelSak(Kontrollfel("saker[0].ovning.hemligt", "okand_nyckel")),
                       "the drill has an unknown field")
    }

    /// "Paste from Claude": felraden i appen (BESLUT B60, METOD MS18).
    func testFelraden() {
        XCTAssertEqual(Texter.kontrollfelRad([]), "")
        XCTAssertEqual(Texter.kontrollfelRad([Kontrollfel("svaret", "inget_block")]), "svaret: no code block from Claude")
        XCTAssertEqual(Texter.kontrollfelRad([Kontrollfel("saker[0].ovning.tanke", "for_lang"), Kontrollfel("skapad", "iso"),
                                              Kontrollfel("pass", "inte_analysens")]),
                       "saker[0].ovning.tanke: too long\u{00A0}\u{00B7} +2")
        // En okänd nyckel är Claudes text: den kortas till 24 tecken, fältet före står kvar.
        let lang = String(repeating: "x", count: 40)
        XCTAssertEqual(Texter.kontrollfelRad([Kontrollfel("saker[0].ovning." + lang, "okand_nyckel")]),
                       "saker[0].ovning." + String(repeating: "x", count: 23) + "…: unknown key")
        XCTAssertEqual(Texter.kontrollfelText(Kontrollfel(lang, "okand_nyckel")),
                       String(repeating: "x", count: 23) + "…: unknown key")
        XCTAssertEqual(Texter.kontrollfelText(Kontrollfel("saker[0].kort", "okand_nyckel")), "saker[0].kort: unknown key")
        XCTAssertEqual(Texter.kontrollfelAlla([Kontrollfel("pass", "inte_analysens"), Kontrollfel("skapad", "iso")]),
                       ["pass: is not this session", "skapad: must be an ISO 8601 time"])
        XCTAssertEqual(Texter.focusSparadesInte, "file: could not be saved")
    }

    /// Instruktionen under 8 KiB, ett typiskt pass under 8 KiB data med marginal, varje
    /// historik under 24 KiB. METOD MT11
    func testStorleken() throws {
        let instr = ClaudeKallor.instruktion.utf8.count
        XCTAssertLessThanOrEqual(instr, 8 * 1024)
        for h in try XCTUnwrap(Self.facit["historiker"]?.somLista) {
            let text = try underlag(h).text
            XCTAssertLessThanOrEqual(text.utf8.count, 24 * 1024)
            if h["namn"] == .text("typiskt") { XCTAssertLessThanOrEqual(text.utf8.count - instr, 7680) }
        }
    }

    /// Avrundningen som Pythons round(): 0,35 blir 0,3 och 0,25 blir 0,2. METOD MT3
    func testAvrundningenSomPython() throws {
        XCTAssertEqual(Avrundning.pyRound(0.35, 1), 0.3)
        XCTAssertEqual(Avrundning.pyRound(0.25, 1), 0.2)
        XCTAssertEqual(Avrundning.pyRound(2.5, 0), 2)
        for f in try XCTUnwrap(Self.facit["avrundning"]?.somLista) {
            let l = try XCTUnwrap(f.somLista)
            let m = l[0].somText ?? "", v = l[1].somTal ?? .nan
            XCTAssertEqual(Avrundning.avrunda(m, v), l[2].somTal, "\(m) \(v)")
        }
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
        XCTAssertFalse(JSONVarde.bool(true).lika(.tal(1)))
        XCTAssertTrue(JSONVarde.tal(1).lika(.tal(1.0)))
        XCTAssertNoThrow(try JSONVarde.las(String(repeating: "[", count: 32) + String(repeating: "]", count: 32)))
        XCTAssertThrowsError(try JSONVarde.las(String(repeating: "[", count: 33) + String(repeating: "]", count: 33)))
        XCTAssertNotEqual(JSONVarde.text("e\u{301}"), JSONVarde.text("\u{e9}"))
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
