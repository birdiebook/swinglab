// SIMULATORPROVET FÖR CLAUDE-APPEN PÅ TELEFONEN (PLAN S5b-2, BESLUT B52, B54, B60; METOD MS18).
//
// Vad som bevisas här, på PÅHITTADE pass och PÅHITTADE leder (SwingDemo; inga riktiga svingar,
// CLAUDE.md: Dataregeln), genom appens egen väg (ClaudeApp, som knapparna kör):
//   Ask Claude         passen mäts som i passets skärm, texten byggs utanför huvudtråden och
//                      läggs i urklippet; urklippet är tecken för tecken ClaudeUnderlag för samma
//                      pass, räknat här ur de sparade passen;
//   Paste from Claude  ett påhittat giltigt svar (byggt ur mallen, som skillen gör) läses ur
//                      urklippet, visas i bladet och blir Focus efter "Use": Store.focus, Today och
//                      accenten följer med;
//   ogiltigt           ett svar med en siffra i tanken ger raden med fältet och koden, utan värdet,
//                      och Focus är orört;
//   en fil finns       samma svar en gång till: bladet frågar innan filen skrivs över.
// Bilderna: claude-passet (knapparna i passet, med Copied och Open Claude), claude-idag (Today),
// claude-blad (bladet med svaret), claude-blad-ersatt (frågan) och claude-fel (felraden).
// iOS fråga om tillåtelse att klistra in syns inte här: provet läser det appen själv lagt i
// urklippet. FRÅGAN OCH CLAUDE-APPEN PROVAS BARA PÅ TELEFONEN.

import XCTest
import SwiftUI
import UIKit
import Swing
import Capture
import SwingDemo
@testable import SwingLab

extension SwingLabProvVyer {
    /// Swayen vid toppen per slag, cm: två FO-pass med 7i, tre dagar isär (som ClaudeKontextTests).
    static let claudePass: [(dag: Date, sway: [Double])] = [
        (Tal.dag(2026, 11, 10, timme: 12), [-6, -5, -7, -6, -5, -6, -7, -6]),
        (Tal.dag(2026, 11, 13, timme: 12), [-6, -7, -6, -5, -6, -7, -6, -5]),
    ]

    /// Svaret som skillen bygger det ur mallen för swayen, med rapporten runt om.
    func claudeSvar(_ u: ClaudeUnderlag, tanke: String) throws -> String {
        let data = u.data
        let mall = try XCTUnwrap(data["mallar"]?.somLista?.first(where: { $0["fel"] == .text("sway_topp") }),
                                 "mallen för swayen")
        var sak = JSONVarde.Objekt([("ordning", .i(1))])
        for f in ["fel", "namn", "vy", "matt", "enhet", "nu", "spann", "markning"] { sak[f] = mall[f] }
        let ov = try XCTUnwrap(mall["ovning_val"]?.somLista?.first)
        sak["ovning"] = .o([("id", ov["id"]!), ("text", ov["text"]!), ("tanke", .text(tanke)),
                            ("kalla", ov["kalla"]!), ("steg", try XCTUnwrap(mall["steg_val"]?.somLista?.first))])
        for f in ["klart_nar", "foljdfel"] { sak[f] = mall[f] }
        sak["typ"] = .text("teknik")
        sak["fysik"] = .null
        sak["block"] = mall["block"]
        var fil = try XCTUnwrap(data["fil"]?.somObjekt)
        fil["saker"] = .lista([.objekt(sak)])
        return "Hip sway at top is the cause.\n\n```json\n" + JSONVarde.objekt(fil).skriv() + "\n```\n"
    }

    func testClaudeAppen() async throws {
        let k = try katalog()
        let rot = FileManager.default.temporaryDirectory
            .appending(path: "swinglab-claude-\(UUID().uuidString)", directoryHint: .isDirectory)
        let store = Store(root: rot, exportFolder: rot.appending(path: "Export"))
        store.setHeight(1.80)

        // Passen som appen sparar dem: slagen med leder men utan mått (knapparna mäter dem).
        var ids: [String] = []
        for f in Self.claudePass {
            var p = store.newPass(setup: PassSetup(view: .fo, club: "j7", distance: 3, hand: .hoger), at: f.dag)
            let demo = DemoPass.fo(id: p.id, created: p.created, club: "j7", heightM: p.heightM, sway: f.sway)
            p.series = demo.pass.series
            p.shots = demo.pass.shots
            p.lastShotNumber = demo.pass.lastShotNumber
            p.status = .analyzed
            for s in p.shots {
                _ = try store.writeJoints(try XCTUnwrap(demo.leder[s.id]), shot: s.id, in: p.id)
            }
            try store.write(p)
            ids.append(p.id)
        }
        let nuID = ids[1]

        // 1. Ask Claude: texten i urklippet, samma som ClaudeUnderlag för samma pass.
        UIPasteboard.general.string = ""
        let skapad = Tal.dag(2026, 11, 13, timme: 20)
        let kopierad = await ClaudeApp.fraga(passID: nuID, store: store, katalog: k, skapad: skapad)
        let text = try XCTUnwrap(kopierad, "Ask Claude kopierade inget")
        XCTAssertEqual(UIPasteboard.general.string, text, "urklippet")
        let passen = try ids.map { try XCTUnwrap(store.load($0)) }
        XCTAssertTrue(passen.allSatisfy { p in p.shots.allSatisfy { $0.measure?.ok == true } }, "mätta och sparade")
        let u = try XCTUnwrap(ClaudeKontext.underlag(nu: passen[1], alla: passen, filer: [], katalog: k, skapad: skapad))
        XCTAssertEqual(UIPasteboard.general.string, u.text, "urklippet är ClaudeUnderlag för passet")
        XCTAssertTrue(text.hasPrefix(ClaudeUnderlag.rubrik + nuID))
        XCTAssertEqual(u.analyser.map(\.pass), ids)
        print("PROV: Ask Claude \(text.utf8.count) byte i urklippet, pass \(u.analyser.map(\.pass))")

        // 2. Paste from Claude: ett giltigt svar visas i bladet och blir Focus efter "Use".
        XCTAssertNil(store.focus)
        UIPasteboard.general.string = try claudeSvar(u, tanke: "Leave the stick standing.")
        guard case let .mottaget(m) = await ClaudeApp.klistra(passID: nuID, store: store, katalog: k) else {
            return XCTFail("svaret togs inte emot")
        }
        XCTAssertFalse(m.finns, "ingen fil för passet än")
        XCTAssertNil(store.focus, "inget sparat före Use")
        XCTAssertEqual(m.fileName, "att_jobba_pa-\(nuID).json")
        let blad = AttJobbaPaVisning(m.focus, katalog: k)
        XCTAssertEqual(blad.saker.count, 1)
        try rendera(ClaudeSvarsblad(visning: blad, finns: false), namn: "claude-blad", accent: nil)
        try ClaudeApp.anvand(m, store: store)
        XCTAssertEqual(store.focus?.pass, nuID)
        XCTAssertEqual(store.focus?.ovas, ["sway_topp"])
        // Today och accenten följer med (BESLUT B31, B36).
        let (data, alla) = await Flikdata.load(store, katalog: k, idag: Tal.dag(2026, 11, 14))
        XCTAssertEqual(data.senaste, nuID)
        XCTAssertEqual(data.idag.fokus.map(\.namn), ["Hip sway"])
        XCTAssertEqual(data.idag.rader.filter(\.ovas).map(\.id), ["sway_topp"])
        print("PROV: Paste from Claude: Focus \(data.idag.fokus.map(\.namn)), accent \(data.idag.rader.filter(\.ovas).map(\.id))")

        // Bilderna: knapparna i passet (efter Ask: Copied och Open Claude) och på Today.
        let nu = try XCTUnwrap(store.load(nuID))
        let pv = PassShotsView.visning(nu, earlier: PassHistory.earlier(nu, among: alla), ovas: store.focus?.ovas ?? [])
        XCTAssertNotNil(pv, "passet är mätt: raden visas")
        try rendera(PassScreenContent(pass: nu, visning: pv, images: [:], overlays: [:], analysis: AnalysisState(),
                                      editable: false, claude: AnyView(ClaudeRad(lage: .kopierat, oppna: true))),
                    namn: "claude-passet", skala: 2)
        try rendera(IdagVy(visning: data.idag, importera: {}, claude: AnyView(ClaudeRad())), namn: "claude-idag")

        // 3. Ett ogiltigt svar: raden nämner fältet och koden, aldrig värdet, och Focus är orört.
        let fore = try Data(contentsOf: store.focusFolder.appending(path: m.fileName))
        UIPasteboard.general.string = try claudeSvar(u, tanke: "Keep 7 inches of room.")
        guard case let .fel(f) = await ClaudeApp.klistra(passID: nuID, store: store, katalog: k) else {
            return XCTFail("ett svar med siffror togs emot")
        }
        XCTAssertTrue(f.contains(Kontrollfel("saker[0].ovning.tanke", "siffror")), "\(f)")
        let rad = Texter.kontrollfelRad(f)
        XCTAssertTrue(f.map(\.text).contains("saker[0].ovning.tanke: no digits"), rad)
        XCTAssertFalse(rad.contains("7") || rad.contains("inches"), "värdet i raden: \(rad)")
        XCTAssertEqual(try Data(contentsOf: store.focusFolder.appending(path: m.fileName)), fore, "inget ändrat")
        XCTAssertEqual(store.focus?.pass, nuID)
        UIPasteboard.general.string = "I need the miss first."
        guard case let .fel(g) = await ClaudeApp.klistra(passID: nuID, store: store, katalog: k) else {
            return XCTFail("ett svar utan block togs emot")
        }
        XCTAssertEqual(Texter.kontrollfelRad(g), "svaret: no code block from Claude")
        try rendera(ClaudeRad(lage: .fel(rad)), namn: "claude-fel", accent: false)
        print("PROV: ogiltigt svar: \(rad)")

        // 4. Passet har redan en fil: samma svar igen ger frågan före "Use".
        UIPasteboard.general.string = try claudeSvar(u, tanke: "Leave the stick standing.")
        guard case let .mottaget(m2) = await ClaudeApp.klistra(passID: nuID, store: store, katalog: k) else {
            return XCTFail("svaret togs inte emot andra gången")
        }
        XCTAssertTrue(m2.finns, "filen finns: bladet frågar")
        try rendera(ClaudeSvarsblad(visning: AttJobbaPaVisning(m2.focus, katalog: k), finns: true, fragar: true),
                    namn: "claude-blad-ersatt", accent: nil)
        print("PROV: en fil finns: bladet frågar före Use")
    }
}
