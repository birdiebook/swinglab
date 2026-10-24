import Foundation
import XCTest
import Swing
import SwingDemo
@testable import Capture

/// S5b: underlaget ur telefonens pass och svaret tillbaka till Focus, på PÅHITTADE pass
/// (SwingDemo, CLAUDE.md: Dataregeln). BESLUT B52, B54
final class ClaudeKontextTests: XCTestCase {
    static let rot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let dag0 = Date(timeIntervalSince1970: 1_792_000_000)

    func katalog() throws -> Katalog {
        try Katalog.las(Data(contentsOf: Self.rot.appendingPathComponent("katalog.json")))
    }

    static func matt(_ id: String, dag: Double, sway: [Double]) -> PassState {
        let d = DemoPass.fo(id: id, created: dag0.addingTimeInterval(dag * 86_400), heightM: 1.80, sway: sway)
        var p = d.pass
        XCTAssertTrue(p.measureShots { d.leder[$0.id] })
        return p
    }

    func testUnderlagetOchSvaretTillbaka() throws {
        let k = try katalog()
        let forra = Self.matt("20261110-120000", dag: 0, sway: [-6, -5, -7, -6, -5, -6, -7, -6])
        let nu = Self.matt("20261113-120000", dag: 3, sway: [-6, -7, -6, -5, -6, -7, -6, -5])
        XCTAssertEqual(nu.claudeRader.slag.filter(\.forstaSerien).count, 5)
        XCTAssertNil(ClaudeKontext.underlag(nu: PassState(id: "20261114-120000", created: Self.dag0,
                                                         setup: nu.setup), alla: [], filer: [], katalog: k))
        let u = try XCTUnwrap(ClaudeKontext.underlag(nu: nu, alla: [forra, nu], filer: [], katalog: k,
                                                     skapad: Self.dag0, zon: TimeZone(secondsFromGMT: 3600)!))
        XCTAssertEqual(u.analyser.map(\.pass), ["20261110-120000", "20261113-120000"])
        XCTAssertTrue(u.text.hasPrefix(ClaudeUnderlag.rubrik + "20261113-120000\n\n" + ClaudeKallor.instruktion))
        let data = u.data
        XCTAssertEqual(data["fil"]?["skapad"]?.somText, ClaudeKontext.skapad(Self.dag0, zon: TimeZone(secondsFromGMT: 3600)!))
        XCTAssertEqual(data["slag"]?["fo"], .i(8))
        let mall = try XCTUnwrap(data["mallar"]?.somLista?.first(where: { $0["fel"] == .text("sway_topp") }))

        // Svaret som skillen bygger det ur mallen, med rapporten runt om.
        var sak = JSONVarde.Objekt([("ordning", .i(1))])
        for f in ["fel", "namn", "vy", "matt", "enhet", "nu", "spann", "markning"] { sak[f] = mall[f] }
        let ov = try XCTUnwrap(mall["ovning_val"]?.somLista?.first)
        sak["ovning"] = .o([("id", ov["id"]!), ("text", ov["text"]!), ("tanke", .text("Leave the stick standing.")),
                            ("kalla", ov["kalla"]!), ("steg", mall["steg_val"]!.somLista![0])])
        for f in ["klart_nar", "foljdfel"] { sak[f] = mall[f] }
        sak["typ"] = .text("teknik")
        sak["fysik"] = .null
        sak["block"] = mall["block"]
        var fil = try XCTUnwrap(data["fil"]?.somObjekt)
        fil["saker"] = .lista([.objekt(sak)])
        let svar = "Pass 13 nov.\n\n```json\n" + JSONVarde.objekt(fil).skriv() + "\n```\n"
        guard case let .accepted(focus, namn, bytes) = FocusInbox.acceptClaude(svar, underlag: u) else {
            return XCTFail("svaret togs inte emot: \(FocusInbox.acceptClaude(svar, underlag: u))")
        }
        XCTAssertEqual(namn, "att_jobba_pa-20261113-120000.json")
        XCTAssertEqual(focus.saker.first?.fel, "sway_topp")
        XCTAssertEqual(focus.saker.first?.ovning.id, ov["id"]?.somText)
        XCTAssertEqual(try FocusInbox.accept(bytes).fileName, namn)

        // Ett val för ett pass med en annan klubba rör inte minnet (BESLUT B56).
        let dr = DemoPass.fo(id: "20261111-120000", created: Self.dag0.addingTimeInterval(86_400), club: "dr",
                             heightM: 1.80, sway: [-6, -5, -7, -6, -5, -6, -7, -6])
        var drPass = dr.pass
        XCTAssertTrue(drPass.measureShots { dr.leder[$0.id] })
        var drFil = fil
        drFil["pass"] = .text(drPass.id)
        let drFocus = try AttJobbaPa.las(Data(JSONVarde.objekt(drFil).skriv().utf8))
        let u2 = try XCTUnwrap(ClaudeKontext.underlag(nu: nu, alla: [forra, drPass, nu], filer: [drFocus], katalog: k))
        XCTAssertEqual(u2.analyser.map(\.pass), ["20261110-120000", "20261113-120000"])
        XCTAssertTrue(u2.ovningar.isEmpty)
        XCTAssertTrue(u2.filer.isEmpty)
        XCTAssertEqual(nu.claudeRader.slag.first?.klubba, "j7")

        // Ett annat pass än underlagets, och ett svar utan block: inget tas emot.
        fil["pass"] = .text("20261110-120000")
        guard case let .rejected(f) = FocusInbox.acceptClaude("```json\n" + JSONVarde.objekt(fil).skriv() + "\n```",
                                                               underlag: u) else { return XCTFail() }
        XCTAssertTrue(f.contains(Kontrollfel("pass", "inte_analysens")))
        guard case let .rejected(g) = FocusInbox.acceptClaude("I need the miss first.", underlag: u) else {
            return XCTFail()
        }
        XCTAssertEqual(g.map(\.text), ["svaret: no code block from Claude"])
    }
}
