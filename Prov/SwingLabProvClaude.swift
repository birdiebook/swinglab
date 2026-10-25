// SIMULATORPROVET FÖR CLAUDE-APPEN PÅ TELEFONEN (PLAN S5b-2, BESLUT B52, B54, B60; METOD MS18).
//
// Vad som bevisas här, på PÅHITTADE pass och PÅHITTADE leder (SwingDemo; inga riktiga svingar,
// CLAUDE.md: Dataregeln), genom appens egen väg (ClaudeApp och Bladsteg, som knapparna kör):
//   Ask Claude         passen mäts som i passets skärm, texten byggs utanför huvudtråden och
//                      läggs i urklippet; urklippet är tecken för tecken ClaudeUnderlag för samma
//                      pass, räknat här ur de sparade passen;
//   Paste from Claude  ett påhittat giltigt svar (byggt ur mallen, som skillen gör) läses ur
//                      urklippet, visas i bladet och blir Focus efter "Use": Store.focus och
//                      accenten i passet följer med, och urklippet töms;
//   ogiltigt           ett svar med en siffra i tanken ger raden med fältet och koden, utan värdet,
//                      ett svar för ett annat pass ger "pass: is not this session" först, och Focus
//                      är orört;
//   en fil finns       ett nytt svar för samma pass: "Use" frågar, "Cancel" sparar inget,
//                      "Replace" skriver över;
//   ett äldre pass     ett svar för det förra passet sparas, men Focus är kvar på det senaste, och
//                      bladet säger det.
// Bilderna: claude-passet (knapparna i passet, med Copied och Open Claude; Today är dold sedan
// S4e, BESLUT B64), claude-blad (bladet med svaret), claude-blad-ersatt (frågan),
// claude-blad-aldre (ett äldre pass), claude-fel (felet på enkel engelska) och claude-fel-detaljer
// (fältet och koden under "Details", S4h).
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
        func focusTanke() -> String? { store.focus?.saker.first?.ovning.tanke }

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
        XCTAssertTrue(m.blirFocus)
        XCTAssertNil(m.focusFran)
        XCTAssertNil(store.focus, "inget sparat före Use")
        XCTAssertEqual(m.fileName, "att_jobba_pa-\(nuID).json")
        var steg = Bladsteg(finns: m.finns)
        XCTAssertEqual(steg.tryck(.anvand), .spara, "utan fil: Use sparar direkt")
        let blad = AttJobbaPaVisning(m.focus, katalog: k)
        XCTAssertEqual(blad.saker.count, 1)
        try rendera(ClaudeSvarsblad(visning: blad, steg: Bladsteg(finns: false)), namn: "claude-blad", accent: nil)
        try ClaudeApp.anvand(m, store: store)
        XCTAssertEqual(store.focus?.pass, nuID)
        XCTAssertEqual(store.focus?.ovas, ["sway_topp"])
        XCTAssertFalse(UIPasteboard.general.hasStrings, "svaret lämnar urklippet efter Use (Dataregeln)")
        // Accenten i passet följer med (BESLUT B31). Today är dold sedan S4e (BESLUT B64).
        let alla = store.allPasses()
        let nu = try XCTUnwrap(store.load(nuID))
        let pv = PassShotsView.visning(nu, earlier: PassHistory.earlier(nu, among: alla), ovas: store.focus?.ovas ?? [])
        XCTAssertNotNil(pv, "passet är mätt: raden visas")
        XCTAssertEqual(pv?.kort(i: .fo).filter(\.ovas).map(\.id), ["sway_topp"])
        print("PROV: Paste from Claude: Focus \(store.focus?.saker.map(\.fel) ?? []), accent \(pv?.kort(i: .fo).filter(\.ovas).map(\.id) ?? [])")

        // Bilderna: knapparna i passet (efter Ask: Copied och Open Claude).
        try rendera(PassScreenContent(pass: nu, visning: pv, images: [:], overlays: [:], analysis: AnalysisState(),
                                      editable: false, claude: AnyView(ClaudeRad(lage: .kopierat, oppna: true))),
                    namn: "claude-passet", skala: 2)

        // 3. Ogiltiga svar: raden nämner fältet och koden, aldrig värdet, och Focus är orört.
        let fore = try Data(contentsOf: store.focusFolder.appending(path: m.fileName))
        UIPasteboard.general.string = try claudeSvar(u, tanke: "Keep 7 inches of room.")
        guard case let .fel(f) = await ClaudeApp.klistra(passID: nuID, store: store, katalog: k) else {
            return XCTFail("ett svar med siffror togs emot")
        }
        XCTAssertTrue(f.contains(Kontrollfel("saker[0].ovning.tanke", "siffror")), "\(f)")
        let rad = Texter.kontrollfelRad(f)
        XCTAssertTrue(Texter.kontrollfelAlla(f).contains("saker[0].ovning.tanke: no digits"), rad)
        XCTAssertFalse(rad.contains("7") || rad.contains("inches"), "värdet i raden: \(rad)")
        XCTAssertEqual(try Data(contentsOf: store.focusFolder.appending(path: m.fileName)), fore, "inget ändrat")
        XCTAssertEqual(store.focus?.pass, nuID)
        // Svaret för det senaste passet, inklistrat i det förra: fel pass först.
        UIPasteboard.general.string = try claudeSvar(u, tanke: "Leave the stick standing.")
        guard case let .fel(annat) = await ClaudeApp.klistra(passID: ids[0], store: store, katalog: k) else {
            return XCTFail("ett svar för ett annat pass togs emot")
        }
        XCTAssertEqual(annat.first, Kontrollfel("pass", "inte_analysens"), "\(annat)")
        UIPasteboard.general.string = "I need the miss first."
        guard case let .fel(g) = await ClaudeApp.klistra(passID: nuID, store: store, katalog: k) else {
            return XCTFail("ett svar utan block togs emot")
        }
        XCTAssertEqual(Texter.kontrollfelRad(g), "svaret: no code block from Claude")
        XCTAssertEqual(store.focus?.pass, nuID)
        XCTAssertEqual(try Data(contentsOf: store.focusFolder.appending(path: m.fileName)), fore, "inget ändrat")
        // Felet på enkel engelska överst, fältet och koden under "Details" (PLAN S4h, BESLUT B94).
        let klartext = Texter.kontrollfelKlartext(f)
        XCTAssertTrue(klartext.hasPrefix("Claude's reply can't be used: "), klartext)
        print("PROV: Claude-felet på enkel engelska: \(klartext)")
        XCTAssertFalse(klartext.contains("7") || klartext.contains("inches") || klartext.contains("tanke"), klartext)
        let felLage = ClaudeRad.Lage.fel(klartext: klartext, rad: rad, alla: Texter.kontrollfelAlla(f))
        try rendera(ClaudeRad(lage: felLage), namn: "claude-fel", accent: false)
        try rendera(ClaudeRad(lage: felLage, visaDetaljer: true), namn: "claude-fel-detaljer", accent: false)
        print("PROV: ogiltigt svar: \(rad); fel pass: \(Texter.kontrollfelRad(annat))")

        // 4. Passet har redan en fil: "Use" frågar, "Cancel" sparar inget, "Replace" skriver över.
        UIPasteboard.general.string = try claudeSvar(u, tanke: "Keep the stick still.")
        guard case let .mottaget(m2) = await ClaudeApp.klistra(passID: nuID, store: store, katalog: k) else {
            return XCTFail("svaret togs inte emot andra gången")
        }
        XCTAssertTrue(m2.finns, "filen finns: bladet frågar")
        XCTAssertTrue(m2.blirFocus)
        steg = Bladsteg(finns: m2.finns)
        XCTAssertEqual(steg.tryck(.anvand), .fraga)
        XCTAssertTrue(steg.fragar)
        try rendera(ClaudeSvarsblad(visning: AttJobbaPaVisning(m2.focus, katalog: k), steg: steg),
                    namn: "claude-blad-ersatt", accent: nil)
        XCTAssertEqual(steg.tryck(.avbryt), .stang)
        XCTAssertEqual(focusTanke(), "Leave the stick standing.", "Cancel sparar inget")
        XCTAssertEqual(try Data(contentsOf: store.focusFolder.appending(path: m.fileName)), fore)
        steg = Bladsteg(finns: m2.finns)
        XCTAssertEqual(steg.tryck(.anvand), .fraga)
        XCTAssertEqual(steg.tryck(.ersatt), .spara)
        try ClaudeApp.anvand(m2, store: store)
        XCTAssertEqual(focusTanke(), "Keep the stick still.", "Replace skriver över")
        print("PROV: en fil finns: Use frågar, Cancel sparar inget, Replace skriver över")

        // 5. Ett svar för det förra passet sparas, men Focus är kvar på det senaste.
        let u0 = try XCTUnwrap(ClaudeKontext.underlag(nu: passen[0], alla: passen, filer: [], katalog: k,
                                                      skapad: skapad))
        UIPasteboard.general.string = try claudeSvar(u0, tanke: "Leave the stick standing.")
        guard case let .mottaget(m0) = await ClaudeApp.klistra(passID: ids[0], store: store, katalog: k) else {
            return XCTFail("svaret för det förra passet togs inte emot")
        }
        XCTAssertFalse(m0.finns)
        XCTAssertFalse(m0.blirFocus, "ett äldre pass blir inte Focus")
        XCTAssertEqual(m0.focusFran, "Nov 13")
        let blad0 = AttJobbaPaVisning(m0.focus, katalog: k)
        XCTAssertEqual(blad0.fran, "Nov 10")
        try rendera(ClaudeSvarsblad(visning: blad0, steg: Bladsteg(finns: false), blirFocus: false, focusFran: m0.focusFran),
                    namn: "claude-blad-aldre", accent: nil)
        try ClaudeApp.anvand(m0, store: store)
        XCTAssertEqual(store.focus?.pass, nuID, "Focus är kvar på det senaste passet")
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.focusFolder.appending(path: m0.fileName).path),
                      "sparad för det förra passet")
        print("PROV: ett äldre pass: sparat som \(m0.fileName), Focus kvar \(store.focus?.pass ?? "-")")
    }
}
