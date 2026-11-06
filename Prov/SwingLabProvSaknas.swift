// VARFÖR ETT MÅTT SAKNAS, RITAT TILL PNG (PLAN S3b lager 1, BESLUT B109, METOD MS21, MS22).
//
// Vad som bevisas här, på PÅHITTADE slag (inga riktiga svingar, CLAUDE.md: Dataregeln): slagens tal
// och mätningens orsaker (`ShotMeasure.missing`, mätningens version 6) skrivs för hand i ett pass,
// och appens egna vägar ritar dem (`PassShotsView.visning`, `ReviewRows.rows`):
//   passet FO      åtta svingar: tempot i fem (två där klippet börjar sent, en mätt före version 6
//                  utan kod), främre armbågen vid toppen i sex (en med armen mot kameran) och chicken
//                  wing i ingen (fem med en punkt fel, två utan punkt); "More measures" utfällt;
//   bladen         infobladet för tempot och chicken wing: raden och orsakerna med antalen;
//   Focus          chicken wing övas men saknas i alla svingar: toppen säger "Not measured";
//   granskningen   raderna vid P4 för slaget med armen mot kameran och vid P9 för slaget före
//                  version 6: "Not measured" där talet skulle stå, sist bland raderna, och bladen med
//                  och utan orsak; samma rader med största textstorleken;
//   passet DTL     sex svingar utan tempo (fyra med osäker start, två utan start): kortet under "More
//                  measures" med raden, och bladet med orsakerna i stället för M40:s källrad.
// Bilderna: saknas-passet-fo, saknas-blad-tempo, saknas-blad-chicken-wing, saknas-passet-focus, saknas-granskning,
// saknas-granskning-stor, saknas-blad-slag, saknas-blad-slag-utan-orsak, saknas-passet-dtl,
// saknas-blad-tempo-dtl.

import XCTest
import SwiftUI
import UIKit
import Swing
import Capture
@testable import SwingLab

extension SwingLabProvVyer {
    /// Ett påhittat slag med talen och orsakerna för hand. `version` = mätningens: före 6 utan koder.
    func saknasSlag(_ nr: Int, _ varden: [String: Double], saknas: [String: String]?,
                    version: Int = ShotMeasuring.version) -> ShotRecord {
        var m = ShotMeasure(heightM: ShotMeasuring.assumedHeightM, heightAssumed: true,
                            positions: ["P1": -1.25, "P3": -0.75, "P4": -0.3, "P5": -0.15, "P7": 0, "P9": 0.12, "P10": 1.1],
                            values: varden)
        m.version = version
        m.missing = saknas
        let klick = 2.5 + Double(nr - 1) * 3.5
        return ShotRecord(id: ShotRecord.id(nr), series: 1, click: Click(time: klick, strength: 12), impact: klick,
                          verdict: .swing, measure: m)
    }

    /// Ett analyserat pass med 7i i vyn, med slagen.
    func saknasPass(_ vy: Vy, dag: Int, _ slag: [ShotRecord]) -> PassState {
        PassState(id: String(format: "202701%02d-101500", dag), created: Tal.dag(2027, 1, dag),
                  setup: PassSetup(view: vy, club: "j7", distance: 3, hand: .hoger), status: .analyzed, shots: slag,
                  lastShotNumber: slag.count)
    }

    func testVarforMattSaknas() throws {
        // FO: åtta svingar, som SaknasTests.foPass (Linux).
        var slag: [ShotRecord] = []
        for i in 0..<8 {
            let d = Double(i % 3 - 1) * 0.1
            var v: [String: Double] = ["backen_sway_topp": -1.0 + d, "sidbojning_topp": 4.0 + d, "backen_resa_framat": 9.0 + d,
                                       "sway_gap_traff": 3.0 + d, "brost_lyft_topp": -1.0 + d, "hoftlinje_lutning_topp": -8.0 + d,
                                       "nedsving_s": 0.28]
            var koder: [String: String] = [:]
            if i < 5 { v["tempo"] = 2.8 + d; v["baksving_s"] = 0.84 }
            if i < 6 { v["framre_armbage_topp"] = 14 + d }
            if i >= 5 { koder["tempo"] = "start_osaker"; koder["baksving_s"] = "start_osaker" }
            if i == 6 { koder["framre_armbage_topp"] = "segment_kort" }
            koder["framre_armbage_efter_traff"] = i < 5 ? "segment_langt" : "led_saknas"
            // Sving 8 mättes före version 6: samma mått saknas, utan koder.
            slag.append(i < 7 ? saknasSlag(i + 1, v, saknas: koder) : saknasSlag(i + 1, v, saknas: nil, version: 5))
        }
        let fo = saknasPass(.fo, dag: 9, slag)
        XCTAssertEqual(fo.countedSwings.count, 8)
        XCTAssertEqual(fo.countedMissing.count, 8)
        let v = try XCTUnwrap(PassShotsView.visning(fo, earlier: []))
        let tempo = try XCTUnwrap(v.kort.first { $0.id == "tempo" })
        let cw = try XCTUnwrap(v.kort.first { $0.id == "chicken_wing" })
        let arm = try XCTUnwrap(v.kort.first { $0.id == "bojd_framre_arm" })
        XCTAssertEqual(tempo.saknas, "Measured in 5 of 8 swings")
        XCTAssertEqual(tempo.info?.saknas, ["Measured in 5 of 8 swings.", "2 swings: the clip starts after the takeaway began.",
                                            "1 swing: no reason recorded."])
        XCTAssertEqual(cw.varde, "—")
        XCTAssertEqual(cw.saknas, "Not measured in any of the 8 swings")
        XCTAssertEqual(arm.saknas, "Measured in 6 of 8 swings")
        XCTAssertNil(v.kort.first { $0.id == "sway_topp" }?.saknas)
        let l = v.lista(i: .fo)
        XCTAssertTrue(l.kort.contains { $0.id == "tempo" })
        XCTAssertTrue(l.fler.contains { $0.id == "chicken_wing" } && l.fler.contains { $0.id == "bojd_framre_arm" })
        print("PROV: saknas FO \(v.kort.compactMap { k in k.saknas.map { "\(k.id)=\($0)" } })")
        try ritaBand(PassetVy(visning: v, vy: .fo, visaFler: true), namn: "saknas-passet-fo", farger: [.gron, .gul, .rod],
                     accent: false)
        try rendera(InfobladVy(blad: try XCTUnwrap(tempo.info)), namn: "saknas-blad-tempo", accent: false)
        try rendera(InfobladVy(blad: try XCTUnwrap(cw.info)), namn: "saknas-blad-chicken-wing", accent: false)
        // Chicken wing övas (Focus) men saknas i alla svingar: toppen säger "Not measured".
        let vf = try XCTUnwrap(PassShotsView.visning(fo, earlier: [], ovas: ["chicken_wing"]))
        let lf = vf.lista(i: .fo)
        XCTAssertEqual(lf.topp?.kort.map(\.id), ["chicken_wing"])
        XCTAssertEqual(lf.toppUpplasning, "Focus: Lead arm fold, not measured")
        try ritaBand(PassetVy(visning: vf, vy: .fo), namn: "saknas-passet-focus", farger: [.gron, .gul, .rod], accent: true)

        // Granskningen: slag 7 vid toppen (armen mot kameran) och slag 8 vid P9 (före version 6).
        let p4 = ReviewRows.rows(pass: fo, shot: fo.shots[6], position: "P4", baseline: [:])
        let p9 = ReviewRows.rows(pass: fo, shot: fo.shots[7], position: "P9", baseline: [:])
        let armRad = try XCTUnwrap(p4.first { $0.matt == "framre_armbage_topp" })
        let cwRad = try XCTUnwrap(p9.first { $0.matt == "framre_armbage_efter_traff" })
        XCTAssertTrue(armRad.ejMatt)
        XCTAssertEqual(p4.last?.matt, "framre_armbage_topp", "det saknade sist (METOD M63)")
        XCTAssertEqual(armRad.info?.saknas,
                       ["Not measured in this swing: the lead arm pointed toward or away from the camera."])
        XCTAssertTrue(p4.filter { $0.matt != "framre_armbage_topp" }.allSatisfy { !$0.ejMatt })
        XCTAssertTrue(cwRad.ejMatt)
        XCTAssertNil(cwRad.orsak)
        XCTAssertEqual(cwRad.info?.saknas, ["Not measured in this swing."])
        print("PROV: saknas granskningen P4 \(p4.map { "\($0.matt)=\($0.ejMatt ? "saknas" : $0.varde)" }), "
              + "P9 \(p9.map { "\($0.matt)=\($0.ejMatt ? "saknas" : $0.varde)" })")
        func sektion(_ position: String, _ rader: [Positionsrad]) -> some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: Texter.positionMedNamn(position))
                    .typsnitt(13, .semibold)
                    .foregroundStyle(Theme.text)
                    .padding(.top, 10)
                VStack(spacing: 0) { ForEach(rader) { PositionsradVy(rad: $0) } }
                    .padding(.top, 4)
            }
        }
        let granskning = VStack(alignment: .leading, spacing: 14) {
            sektion("P4", p4)
            sektion("P9", p9)
        }
        .padding(.horizontal, 20)
        try ritaBand(granskning, namn: "saknas-granskning", farger: [.gron])
        try rendera(granskning, namn: "saknas-granskning-stor", textstorlek: .accessibility5, accent: false)
        try rendera(InfobladVy(blad: try XCTUnwrap(armRad.info)), namn: "saknas-blad-slag", accent: false)
        try rendera(InfobladVy(blad: try XCTUnwrap(cwRad.info)), namn: "saknas-blad-slag-utan-orsak", accent: false)

        // DTL: sex svingar utan tempo, fyra med osäker start (M40) och två utan start.
        let dslag = (0..<6).map { i -> ShotRecord in
            let o = i < 4 ? "start_osaker" : "start_saknas"
            var r = saknasSlag(i + 1, ["backen_thrust_traff": 1.0 + Double(i) * 0.1, "handbana": -1.0, "nedsving_s": 0.28,
                                       "brost_bojning_adress": 40, "brost_bojning_traff": 38, "brost_bojning_tapp": 2.0],
                               saknas: ["tempo": o, "baksving_s": o])
            if i < 4 { r.measure?.startUncertain = true }
            return r
        }
        let dtl = saknasPass(.dtl, dag: 10, dslag)
        let vd = try XCTUnwrap(PassShotsView.visning(dtl, earlier: []))
        let dtempo = try XCTUnwrap(vd.kort.first { $0.id == "tempo" })
        XCTAssertEqual(dtempo.varde, "—")
        XCTAssertEqual(dtempo.saknas, "Not measured in any of the 6 swings")
        XCTAssertEqual(dtempo.info?.saknas, ["Not measured in any of the 6 swings.",
                                             "4 swings: the backswing start was unclear from behind.",
                                             "2 swings: the backswing start was not found."])
        XCTAssertFalse(dtempo.info?.kalla.contains(Texter.startOsakerKalla) ?? true, "orsaken en gång")
        XCTAssertTrue(vd.lista(i: .dtl).fler.contains { $0.id == "tempo" })
        try ritaBand(PassetVy(visning: vd, vy: .dtl, visaFler: true), namn: "saknas-passet-dtl", farger: [.gron],
                     accent: false)
        try rendera(InfobladVy(blad: try XCTUnwrap(dtempo.info)), namn: "saknas-blad-tempo-dtl", accent: false)
    }
}
