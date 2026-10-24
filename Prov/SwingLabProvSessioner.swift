// SIMULATORPROVET FÖR SESSIONS OCH ME (PLAN S4e, BESLUT B64; METOD MS20).
//
// Vad som bevisas här, på PÅHITTADE pass och PÅHITTADE leder (SwingDemo; inga riktiga
// svingar, CLAUDE.md: Dataregeln):
//   listan     fyra pass i appens Store: FO ensam, DTL med två telefoner (styr), FO med två
//              telefoner (följ) och ett DTL-pass med två klubbor som inte är analyserat; appens
//              väg (Sessionslista.load, utanför huvudtråden) ger raderna senaste först med vyn,
//              tiden, klubban, svingarna och "paired";
//   vyn        FO-sessionen visar inga DTL-kort och DTL-sessionen inga FO-kort, tempot står i båda
//              (katalogens vy, Vyfilter); granskningens rader per position likadant; 3D-kortet
//              (S6c-2) står i båda;
//   raderingen frågan ritas (och med felet när den vägras); Delete tar bort passets mapp och
//              paketet men inte att_jobba_pa, inget skriver det raderade passet igen, de andra
//              passen står kvar, ett pass som exporteras eller spelas in tas inte bort, och den
//              andra telefonens pass med samma id rörs inte;
//   Me         längden, handen, klubborna och Import focus; en ny längd rör inga gamla pass.
// Bilderna: sessions (listan ur ett riktigt fönster, med svepets List), sessions-radera,
// sessions-radera-vagrad, session-fo (det parade FO-passet), session-dtl och me.

import XCTest
import SwiftUI
import UIKit
import Swing
import Capture
import SwingDemo
import TreD
@testable import SwingLab

extension SwingLabProvVyer {
    func testSessionerOchMe() async throws {
        let k = try katalog()
        let rot = FileManager.default.temporaryDirectory
            .appending(path: "swinglab-sessioner-\(UUID().uuidString)", directoryHint: .isDirectory)
        let store = Store(root: rot, exportFolder: rot.appending(path: "Export"))
        store.setHeight(1.82)

        /// Ett pass som appen sparar det: id och längd ur Store, slagen och lederna ur SwingDemo.
        func spara(_ vy: Vy, _ dag: Date, club: String = "j7", roll: LinkRole = .solo, varden: [Double],
                   analyserat: Bool = true) throws -> String {
            var p = store.newPass(setup: PassSetup(view: vy, club: club, distance: 3, hand: .hoger, role: roll), at: dag)
            let demo = vy == .fo
                ? DemoPass.fo(id: p.id, created: p.created, club: club, heightM: p.heightM, sway: varden)
                : DemoPass.dtl(id: p.id, created: p.created, club: club, heightM: p.heightM, thrust: varden)
            p.series = demo.pass.series
            p.shots = demo.pass.shots
            p.lastShotNumber = demo.pass.lastShotNumber
            if analyserat {
                p.status = .analyzed
                for s in p.shots {
                    _ = try store.writeJoints(try XCTUnwrap(demo.leder[s.id]), shot: s.id, in: p.id)
                }
            } else {
                for i in p.shots.indices {
                    p.shots[i].verdict = nil
                    p.shots[i].joints = nil
                }
            }
            try store.write(p)
            return p.id
        }
        let a = try spara(.fo, Tal.dag(2026, 11, 10, timme: 18), varden: [-5, -4, -6, -5, -4, -5, -6, -4])
        let b = try spara(.dtl, Tal.dag(2026, 11, 13, timme: 18), roll: .lead, varden: [-2, -1, -3, -2, -1, -2, -3, -1])
        let c = try spara(.fo, Tal.dag(2026, 11, 14, timme: 10), roll: .follow, varden: [-4, -3, -5])
        let d = try spara(.dtl, Tal.dag(2026, 11, 15, timme: 12), club: "pw", varden: [-2, -1, -3, -2, -1, -2],
                          analyserat: false)
        // Serie 2 i det oanalyserade passet med en annan klubba.
        var pd = try XCTUnwrap(store.load(d))
        pd.series[1].club = "j7"
        try store.write(pd)

        // Fokus för FO-passet (som "Import focus") och ett paket i Export: raderingen tar dem.
        let fokus = Demo.attJobbaPaJSON
            .replacingOccurrences(of: "\"pass\": \"20270109-180000\"", with: "\"pass\": \"\(a)\"")
            .replacingOccurrences(of: "\"start\": \"2026-12-12\"", with: "\"start\": \"2026-11-05\"")
            .replacingOccurrences(of: "\"start\": \"2027-01-09\"", with: "\"start\": \"2026-11-10\"")
        try store.importFocus(Data(fokus.utf8))
        XCTAssertEqual(store.focus?.pass, a)
        let paket = store.exportURL(try XCTUnwrap(store.load(a)))
        try FileManager.default.createDirectory(at: store.exportFolder, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: paket)

        // 1. Listan, appens väg: senaste först, vyn, tiden, klubban, svingarna och paret.
        let rader = await Sessionslista.load(store)
        XCTAssertEqual(rader.map(\.id), [d, c, b, a])
        // Det styrande passet här har varken par.json eller den andra telefonens slag: ingen rad
        // "Paired" (S6g, BESLUT B82), bara vyn och "paired".
        XCTAssertEqual(rader.map(\.vyNamn), ["Down the line", "Face on", "Down the line", "Face on"])
        XCTAssertEqual(rader.map(\.parad), [false, true, true, false])
        XCTAssertEqual(rader.map(\.svingar), [nil, 3, 8, 8])
        XCTAssertEqual(rader.map(\.klubba), ["PW, 7i", "7i", "7i", "7i"])
        XCTAssertEqual(rader[2].tid, "Fri, Nov 13\u{00A0}· 18:00")
        XCTAssertEqual(rader[2].upplasning, "Down the line, Fri, Nov 13, 18:00, 7i, 8 swings, paired")
        print("PROV: sessions \(rader.map { "\($0.vyNamn) \($0.tid) \($0.klubba) \($0.svingar.map(String.init) ?? "-")\($0.parad ? " paired" : "")" })")
        try await fanga(SessionsVy(rader: rader), namn: "sessions", accent: false)

        // 2. Sessionerna: bara sessionens vy, genom katalogens vy (Vyfilter).
        let ovas = store.focus?.ovas ?? []
        XCTAssertEqual(ovas, ["sway_topp", "flying_elbow"])
        func session(_ id: String) async throws -> (pass: PassState, visning: Passvisning) {
            let p0 = try XCTUnwrap(store.load(id))
            let r = await PassMeasures.load(p0, store: store)
            XCTAssertTrue(r.pass.shots.allSatisfy { $0.measure?.ok == true }, "\(id) mätt")
            return (r.pass, try XCTUnwrap(PassShotsView.visning(r.pass, earlier: r.earlier, ovas: ovas)))
        }
        // FO-sessionen är det parade FO-passet (följaren), DTL-sessionen det parade DTL-passet.
        let fo = try await session(c), dtl = try await session(b)
        // Svingarna i listan är samma tal som sessionens rad ("7i · 3").
        XCTAssertEqual(rader.first { $0.id == c }?.svingar, fo.pass.visningsPass.slag)
        XCTAssertEqual(rader.first { $0.id == b }?.svingar, dtl.pass.visningsPass.slag)
        let kfo = fo.visning.kort(i: .fo), kdtl = dtl.visning.kort(i: .dtl)
        XCTAssertTrue(kfo.allSatisfy { $0.vy != .dtl }, "FO-sessionen: \(kfo.filter { $0.vy == .dtl }.map(\.id))")
        XCTAssertTrue(kdtl.allSatisfy { $0.vy != .fo }, "DTL-sessionen: \(kdtl.filter { $0.vy == .fo }.map(\.id))")
        XCTAssertTrue(kfo.contains { $0.id == "tempo" } && kdtl.contains { $0.id == "tempo" }, "tempot i båda")
        XCTAssertTrue(kfo.contains { $0.id == "sway_topp" } && !kfo.contains { $0.id == "early_extension" })
        XCTAssertTrue(kdtl.contains { $0.id == "early_extension" } && !kdtl.contains { $0.id == "sway_topp" })
        XCTAssertEqual(kfo.filter(\.ovas).map(\.id), ["sway_topp"])
        XCTAssertEqual(kdtl.filter(\.ovas).map(\.id), ["flying_elbow"])
        let rfo = ReviewRows.rows(pass: fo.pass, shot: fo.pass.shots[0], position: "P7", baseline: [:])
        let rdtl = ReviewRows.rows(pass: dtl.pass, shot: dtl.pass.shots[0], position: "P7", baseline: [:])
        XCTAssertTrue(rfo.contains { $0.matt == "sway_gap_traff" } && !rfo.contains { $0.matt == "backen_thrust_traff" })
        XCTAssertTrue(rdtl.contains { $0.matt == "backen_thrust_traff" } && !rdtl.contains { $0.matt == "sway_gap_traff" })
        print("PROV: FO-sessionen \(kfo.count) kort, DTL-sessionen \(kdtl.count) kort; P7 FO \(rfo.map(\.matt)), DTL \(rdtl.map(\.matt))")
        // 3D-kortet (S6c-2) står i båda sessionerna, utanför filtret per vy.
        let kort3D = (try? treDFil()).map { TreDKort($0.0, katalog: k) }
        XCTAssertNotNil(kort3D, "3D-fixturen")
        try rendera(PassScreenContent(pass: fo.pass, visning: fo.visning, images: [:], overlays: [:], analysis: AnalysisState(),
                                      editable: false, treD: kort3D), namn: "session-fo", skala: 2)
        try rendera(PassScreenContent(pass: dtl.pass, visning: dtl.visning, images: [:], overlays: [:],
                                      analysis: AnalysisState(), editable: false, treD: kort3D), namn: "session-dtl", skala: 2)

        // 3. Raderingen: frågan (Cancel först och vit, Delete en grå rad), och Delete tar passets
        // filer utom att_jobba_pa, och inget annat.
        try rendera(RaderaPassVy(rad: rader[2]), namn: "sessions-radera", accent: false)
        let staleA = try XCTUnwrap(store.load(a))
        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: store.passFolder(a).path))
        let fokusfil = store.focusFolder.appending(path: try XCTUnwrap(FocusInbox.fileName(pass: a)))
        XCTAssertTrue(fm.fileExists(atPath: fokusfil.path))
        XCTAssertTrue(store.deletePass(a))
        XCTAssertFalse(fm.fileExists(atPath: store.passFolder(a).path), "passets mapp (video, leder, mått, 3D)")
        XCTAssertTrue(fm.fileExists(atPath: fokusfil.path), "att_jobba_pa ligger kvar (vägen tillbaka)")
        XCTAssertEqual(store.focus?.pass, a, "Focus är kvar")
        XCTAssertFalse(fm.fileExists(atPath: paket.path), "paketet i Export")
        XCTAssertNil(store.load(a))
        // Det raderade passet kommer inte tillbaka: en sparning efteråt (en serie som sparas när
        // vyn stängts, analysen, den andra telefonens slag, 3D) skriver inget.
        store.problem = nil
        store.save(staleA)
        XCTAssertNil(store.problem, "ingen felrad för ett raderat pass")
        XCTAssertThrowsError(try store.write(staleA))
        XCTAssertThrowsError(try store.writeJoints(JointSeries(width: 1, height: 1, frames: []), shot: "s01", in: a))
        XCTAssertFalse(store.saveOtherPhone(Data("{}".utf8), passID: a))
        if let f = try? treDFil() { XCTAssertFalse(store.saveTreD(f.0, passID: a)) }
        XCTAssertFalse(fm.fileExists(atPath: store.passFolder(a).path), "ingen mapp skrevs igen")
        XCTAssertNil(store.load(a))
        XCTAssertEqual(store.index.passes.map(\.id), [d, c, b])
        XCTAssertEqual(Store(root: rot, exportFolder: rot.appending(path: "Export")).index.passes.map(\.id), [d, c, b],
                       "indexet sparat")
        for id in [b, c, d] { XCTAssertNotNil(store.load(id), "\(id) kvar") }
        let efter = await Sessionslista.load(store)
        XCTAssertEqual(efter.map(\.id), [d, c, b])
        // Ett pass vars paket skrivs, eller som spelas in eller importeras, tas inte bort; felet säger det.
        store.setExporting(c, true)
        store.problem = nil
        XCTAssertFalse(store.deletePass(c))
        XCTAssertEqual(store.problem, "The session is in use.")
        XCTAssertNotNil(store.load(c))
        store.setExporting(c, false)
        store.setInFlow(c, true)
        XCTAssertFalse(store.deletePass(c))
        XCTAssertNotNil(store.load(c))
        store.setInFlow(c, false)
        store.problem = nil
        try rendera(RaderaPassVy(rad: rader[1], problem: String(localized: "The session is in use.")),
                    namn: "sessions-radera-vagrad", accent: false)
        // Den andra telefonen (en egen Store) har samma pass; raderingen här rör det inte.
        let rot2 = FileManager.default.temporaryDirectory
            .appending(path: "swinglab-sessioner-andra-\(UUID().uuidString)", directoryHint: .isDirectory)
        let andra = Store(root: rot2, exportFolder: rot2.appending(path: "Export"))
        let pb = try XCTUnwrap(store.load(b))
        var kopia = PassState(id: b, created: pb.created, setup: PassSetup(view: .fo, club: "j7", role: .follow))
        kopia.status = .analyzed
        try andra.write(kopia)
        XCTAssertTrue(store.deletePass(b))
        XCTAssertNotNil(andra.load(b), "den andra telefonens pass står kvar")
        XCTAssertEqual(andra.index.passes.map(\.id), [b])
        print("PROV: raderat \(a) och \(b): mappen och paketet borta, att_jobba_pa kvar, inget skrivs igen; kvar \(store.index.passes.map(\.id))")

        // 4. Me: en ny längd rör inga gamla pass; ett nytt pass får den.
        let fore = store.load(c)
        store.setHand(.hoger)
        store.toggleClub("lw")
        XCTAssertFalse(store.settings.bag.contains("lw"))
        store.setHeight(1.90)
        XCTAssertEqual(store.load(c), fore, "inget pass ändrades")
        let ny = store.newPass(setup: store.settings.newSetup(lastClub: "j7"), at: Tal.dag(2026, 11, 16, timme: 18))
        XCTAssertEqual(ny.heightM, 1.90)
        let jag = Store(root: rot, exportFolder: rot.appending(path: "Export")).settings
        XCTAssertEqual(jag.heightM, 1.90, "Me sparad")
        try rendera(JagVy(heightM: jag.heightM, hand: jag.hand ?? .hoger, clubs: jag.bag, editable: false,
                          importResult: String(localized: "Focus saved")),
                    namn: "me", accent: false)
        print("PROV: Me \(jag.heightM ?? 0) m, \(jag.bag.count) klubbor")
    }

    /// En skärm med UIKit-delar (List, svepet) ur ett riktigt fönster, 390 punkter bred, mörkt läge
    /// och svensk region, prövad mot formspråket som `rendera`.
    func fanga(_ vy: some View, namn: String, accent: Bool? = false) async throws {
        let scen = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let fonster = UIWindow(windowScene: scen)
        fonster.frame = CGRect(x: 0, y: 0, width: Self.bredd, height: 844)
        fonster.overrideUserInterfaceStyle = .dark
        let host = UIHostingController(rootView: AnyView(vy.environment(\.locale, Locale(identifier: "sv_SE"))))
        host.view.backgroundColor = .black
        fonster.rootViewController = host
        fonster.isHidden = false
        try await Task.sleep(for: .seconds(1.5))
        let bild = UIGraphicsImageRenderer(bounds: fonster.bounds).image { _ in
            _ = fonster.drawHierarchy(in: fonster.bounds, afterScreenUpdates: true)
        }
        fonster.isHidden = true
        try FileManager.default.createDirectory(atPath: Self.ut, withIntermediateDirectories: true)
        try XCTUnwrap(bild.pngData()).write(to: URL(fileURLWithPath: "\(Self.ut)/\(namn).png"))
        print("PROV: skrev \(namn).png ur ett fönster (\(Int(bild.size.width * bild.scale))×\(Int(bild.size.height * bild.scale)) px)")
        try provaFormspraket(bild, namn: namn, accent: accent)
    }
}
