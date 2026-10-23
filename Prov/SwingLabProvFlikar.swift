// SIMULATORPROVET FÖR FLIKARNA MED RIKTIG DATA (PLAN S4, S4c; METOD MS16).
//
// Vad som bevisas här, på PÅHITTADE pass och PÅHITTADE leder (SwingDemo; inga riktiga
// svingar, CLAUDE.md: Dataregeln):
//   passen    åtta pass på olika dagar i appens Store (sju med 7i, ett med Dr; det första
//             före längden i Jag, alltså antagen), slagen med leder men utan mått;
//   mätningen appens egen väg (Flikdata.load: Store.reading och Store.measuring utanför huvudtråden)
//             mäter varje pass med sin egen längd och sparar det;
//   fokus     två påhittade att_jobba_pa.json i AttJobbaPa/ (som "Import focus" sparar dem):
//             den senaste är Att jobba på, båda ger blocken i Utveckling;
//   flikarna  Idag (senaste passet, mätt och jämfört med de tidigare), Utveckling (medianen
//             per pass, spridningen, serie 1, baslinjen eller gränsen, samma klubba och längd)
//             och Jag ritas med talen ur passen;
//   längden   en ny längd i Jag rör inga gamla pass, och ett nytt pass får den;
//   accenten  bara på det som övas (swayen), i Idag, Passet, Utveckling och granskningens
//             rader; utan fil syns den inte alls (BESLUT B31).
//   bladet    infobladet för swayen ur passets kort: namnet och fyra rader, svartvitt (BESLUT B41).
// Bilderna: flik-idag, flik-idag-utan-fokus, flik-utveckling, flik-utveckling-resa,
// flik-jag, flik-jobba, flik-passet, infoblad.

import XCTest
import SwiftUI
import UIKit
import Swing
import Capture
import SwingDemo
@testable import SwingLab

extension SwingLabProvVyer {
    /// Swayen vid toppen per slag, cm, för passen med 7i i tidsordning: den kryper mot noll.
    static let flikPass: [(dag: Date, club: String, sway: [Double])] = [
        (Tal.dag(2026, 11, 3, timme: 18), "j7", [-7.5, -6.8, -7.0, -6.2, -7.9, -6.5, -7.1, -6.0]),
        (Tal.dag(2026, 11, 10, timme: 18), "j7", [-6.8, -6.0, -6.4, -5.5, -7.0, -5.9, -6.2, -5.8]),
        (Tal.dag(2026, 11, 24, timme: 18), "j7", [-6.0, -5.2, -5.8, -4.9, -6.3, -5.1, -5.5, -5.0]),
        (Tal.dag(2026, 12, 1, timme: 18), "dr", [-8.0, -7.5, -8.4, -7.9, -8.8]),
        (Tal.dag(2026, 12, 8, timme: 18), "j7", [-5.1, -4.6, -5.4, -4.2, -5.0, -4.4, -4.8, -4.5]),
        (Tal.dag(2026, 12, 15, timme: 18), "j7", [-4.4, -3.6, -4.9, -3.8, -4.1, -3.2, -3.9, -3.5]),
        (Tal.dag(2027, 1, 5, timme: 18), "j7", [-3.5, -3.0, -3.8, -2.6, -3.2, -2.4, -2.9, -2.8]),
        (Tal.dag(2027, 1, 9, timme: 18), "j7", [-2.9, -2.2, -3.1, -1.8, -2.6, -1.9, -2.3, -2.0]),
    ]

    func testFlikarnaMedPassenPaTelefonen() async throws {
        let k = try katalog()
        let rot = FileManager.default.temporaryDirectory
            .appending(path: "swinglab-flikar-\(UUID().uuidString)", directoryHint: .isDirectory)
        let store = Store(root: rot, exportFolder: rot.appending(path: "Export"))
        let langd = 1.82

        // Passen som appen sparar dem: id och längd ur Store, slagen och lederna ur SwingDemo.
        var ids: [String] = []
        for (i, f) in Self.flikPass.enumerated() {
            if i == 1 { store.setHeight(langd) }            // det första passet: före längden i Jag
            var p = store.newPass(setup: PassSetup(view: .fo, club: f.club, distance: 3, hand: .hoger), at: f.dag)
            let demo = DemoPass.fo(id: p.id, created: p.created, club: f.club, heightM: p.heightM, sway: f.sway)
            p.series = demo.pass.series
            p.shots = demo.pass.shots
            p.lastShotNumber = demo.pass.lastShotNumber
            p.status = .analyzed
            for s in p.shots {
                _ = try store.writeJoints(try XCTUnwrap(demo.leder[s.id]), shot: s.id, in: p.id)
            }
            try store.write(p)
            ids.append(p.id)
            // Det första passet mäts före längden i Me: antaget, och det behåller sin skala.
            if i == 0 { _ = store.measured(try XCTUnwrap(store.load(p.id))) }
        }
        XCTAssertNil(store.load(ids[0])?.heightM, "före Jag: antagen")
        XCTAssertEqual(store.load(ids[1])?.heightM, langd, "Jags längd följer med passet")

        // Två filer från PC:n genom "Import focus" (S2f:s Store.importFocus, BESLUT B28), och
        // en trasig fil bredvid som hoppas över.
        let gammal = Demo.attJobbaPaJSON
            .replacingOccurrences(of: "\"pass\": \"20270109-180000\"", with: "\"pass\": \"20261110-180000\"")
            .replacingOccurrences(of: "\"start\": \"2026-12-12\"", with: "\"start\": \"2026-11-05\"")
        try store.importFocus(Data(Demo.attJobbaPaJSON.utf8))
        try store.importFocus(Data(gammal.utf8))
        XCTAssertEqual(store.focus?.pass, "20270109-180000", "den senaste, inte den sist hämtade")
        try Data("{".utf8).write(to: store.focusFolder.appending(path: "att_jobba_pa-20261201-180000.json"))

        // Appens väg: passen läses, mäts med sin egen längd och sparas, utanför huvudtråden.
        let (data, passes) = await Flikdata.load(store, katalog: k, idag: Tal.dag(2027, 1, 13))
        for id in ids {
            let p = try XCTUnwrap(store.load(id))
            XCTAssertTrue(p.shots.allSatisfy { $0.measure?.ok == true }, "\(id) mätt och sparat")
        }
        XCTAssertEqual(store.load(ids[0])?.measuredHeight?.assumed, true)
        XCTAssertEqual(store.load(ids[7])?.measuredHeight?.heightM, langd)
        XCTAssertEqual(Store.readingFocus(root: rot).map(\.pass), ["20261110-180000", "20270109-180000"],
                       "den trasiga hoppas över")

        // Idag: det senaste passet, swayen är medianen av dess mått, och bara den bär accenten.
        let senaste = try XCTUnwrap(store.load(ids[7]))
        XCTAssertEqual(data.senaste, senaste.id)
        let idag = data.idag
        XCTAssertEqual(idag.senaste, "Sat, Jan 9\u{00A0}· 7i\u{00A0}· 8")
        let sway = senaste.shots.compactMap { $0.measure?.values["backen_sway_topp"] }
        let median = Session.percentil(sway.sorted(), 0.5)
        let rad = try XCTUnwrap(idag.rader.first { $0.id == "sway_topp" })
        XCTAssertEqual(rad.varde, Tal.tecken(Avrundning.avrunda("backen_sway_topp", median), decimaler: 1))
        XCTAssertEqual(idag.rader.filter(\.ovas).map(\.id), ["sway_topp"])
        XCTAssertEqual(idag.fokus.map(\.namn), ["Hip sway", "Trail elbow flare"])
        XCTAssertEqual(idag.vecka, "week 5")
        print("PROV: flikarna Idag: \(idag.senaste ?? "-"), sway \(rad.varde) \(rad.enhet), \(idag.rader.count) rader, "
              + "fokus \(idag.fokus.map(\.namn))")

        // Utveckling: 7i med längden 1,82 (sex pass), det antagna räknas, Dr hör inte hit.
        let u = data.utveckling
        XCTAssertEqual(u.period, "7i\u{00A0}· Nov–Jan\u{00A0}· 6")
        XCTAssertEqual(u.ejMatta, "1 at another height", "det antagna är mätt, med en annan längd")
        let us = try XCTUnwrap(u.matt.first { $0.id == "sway_topp" })
        XCTAssertTrue(us.ovas)
        let j7 = ids.indices.filter { $0 > 0 && Self.flikPass[$0].club == "j7" }
        XCTAssertEqual(us.punkter.count, j7.count)
        for (pt, i) in zip(us.punkter, j7) {
            let v = try XCTUnwrap(store.load(ids[i])).shots.compactMap { $0.measure?.values["backen_sway_topp"] }
            XCTAssertEqual(pt.pass, Session.percentil(v.sorted(), 0.5), accuracy: 1e-9, "passets median")
            XCTAssertNotNil(pt.serie1, "serie 1: de fem första")
            XCTAssertNotNil(pt.q1)
        }
        // Blocken: B1 började före det första passet (5 nov), B2 den 12 dec mellan 8 och 15 dec.
        XCTAssertEqual(us.block.map(\.text), ["B2"])
        XCTAssertEqual(us.block.map(\.index), [3])
        XCTAssertEqual(us.skillnad.map { $0.hasSuffix("vs Nov 10") }, true)
        print("PROV: flikarna Utveckling: \(u.period), \(u.ejMatta ?? "-"), sway \(us.punkter.map { String(format: "%.2f", $0.pass) }), "
              + "block \(us.block.map(\.index))")

        // Att jobba på: den senaste filen.
        let jobba = try XCTUnwrap(data.jobba)
        XCTAssertEqual(jobba.fran, "Jan 9")
        XCTAssertEqual(jobba.saker.count, 2)

        // Passet och granskningens rader: accenten på swayen.
        let ovas = store.focus?.ovas ?? []
        XCTAssertEqual(ovas, ["sway_topp", "flying_elbow"])
        let pv = try XCTUnwrap(PassShotsView.visning(senaste, earlier: PassHistory.earlier(senaste, among: passes), ovas: ovas))
        XCTAssertEqual(pv.kort.filter(\.ovas).map(\.id).sorted(), ["flying_elbow", "sway_topp"])
        XCTAssertNotNil(pv.kort.first { $0.id == "sway_topp" }?.skillnad, "vs förra passet")
        let rader = ReviewRows.rows(pass: senaste, shot: senaste.shots[0], position: "P4", baseline: [:], ovas: ovas)
        XCTAssertEqual(rader.first { $0.matt == "backen_sway_topp" }?.ovas, true)
        XCTAssertTrue(ReviewRows.rows(pass: senaste, shot: senaste.shots[0], position: "P4", baseline: [:]).allSatisfy { !$0.ovas })

        // Bilderna.
        try rendera(IdagVy(visning: idag, importera: {}), namn: "flik-idag")
        let utan = Flikdata.bygg(passes: passes, fokus: nil, filer: [], katalog: k, idag: Tal.dag(2027, 1, 13))
        XCTAssertTrue(utan.idag.rader.allSatisfy { !$0.ovas } && utan.idag.fokus.isEmpty)
        try rendera(IdagVy(visning: utan.idag, importera: {}), namn: "flik-idag-utan-fokus", accent: false)
        try rendera(UtvecklingVy(visning: u), namn: "flik-utveckling")
        try rendera(UtvecklingVy(visning: u, valt: "backens_resa_framat"), namn: "flik-utveckling-resa", accent: false)
        try rendera(AttJobbaPaVy(visning: jobba), namn: "flik-jobba")
        try rendera(PassetVy(visning: pv, filter: .fo), namn: "flik-passet")
        // Infobladet (BESLUT B41): swayens kort bär sitt blad, med positionen i namnet (B40).
        let blad = try XCTUnwrap(pv.kort.first { $0.id == "sway_topp" }?.info)
        XCTAssertEqual(blad.namn, "Hip sway at top")
        XCTAssertEqual(blad.tecken, "+ toward target · − away")
        XCTAssertTrue(blad.kalla.hasSuffix("not verified"), blad.kalla)
        XCTAssertNotNil(idag.rader.first?.info, "Today: ⓘ på raden")
        XCTAssertNotNil(u.matt.first?.info)
        try rendera(InfobladVy(blad: blad), namn: "infoblad", accent: false)
        print("PROV: infobladet \(blad.namn): \(blad.kalla)")

        // Jag: en ny längd rör inga gamla pass; ett nytt pass får den.
        store.setHand(.hoger)
        store.toggleClub("lw")
        XCTAssertFalse(store.settings.bag.contains("lw"))
        store.setHeight(1.90)
        let efter = await Flikdata.load(store, katalog: k).passes
        XCTAssertEqual(efter, passes, "inget pass mättes om")
        XCTAssertEqual(store.load(ids[7])?.measuredHeight?.heightM, langd)
        let ny = store.newPass(setup: store.settings.newSetup(lastClub: "j7"), at: Tal.dag(2027, 1, 13, timme: 18))
        XCTAssertEqual(ny.heightM, 1.90)
        XCTAssertEqual(ny.setup.club, "j7")
        let jag = Store(root: rot, exportFolder: rot.appending(path: "Export")).settings
        XCTAssertEqual(jag.heightM, 1.90, "Jag sparad")
        try rendera(JagVy(heightM: jag.heightM, hand: jag.hand ?? .hoger, clubs: jag.bag,
                          sessions: store.index.passes.count, editable: false),
                    namn: "flik-jag", accent: false)
        print("PROV: flikarna Jag: \(jag.heightM ?? 0) m, \(jag.bag.count) klubbor, \(store.index.passes.count) pass")
    }
}
