import Foundation
import XCTest
import Swing
import SwingDemo
@testable import Capture

/// S4e: sessionslistans rader (vyn, tiden, klubban, svingarna och paret) och filtret per vy i
/// sessionen och granskningen, genom katalogens `vy`, på PÅHITTADE pass (SwingDemo, CLAUDE.md:
/// Dataregeln). METOD MS20, BESLUT B64
final class SessionerTests: XCTestCase {
    static let rot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    func katalog() throws -> Katalog {
        try Katalog.las(Data(contentsOf: Self.rot.appendingPathComponent("katalog.json")))
    }

    /// Passet med sina mått (passets egen längd, METOD MS16).
    static func matt(_ d: (pass: PassState, leder: [String: JointSeries])) -> PassState {
        var p = d.pass
        XCTAssertTrue(p.measureShots { d.leder[$0.id] })
        return p
    }

    func testRadernaSenastForstMedVyTidKlubbaSvingarOchPar() throws {
        let fo = Self.matt(DemoPass.fo(id: "20261110-180500",
                                       created: Tal.dag(2026, 11, 10, timme: 18).addingTimeInterval(300),
                                       sway: [-3, -2, -4, -3, -2, -3, -4, -2]))
        var d = DemoPass.dtl(id: "20261113-180000", created: Tal.dag(2026, 11, 13, timme: 18), club: "pw",
                             thrust: [-2, -1, -3, -2, -1])
        d.pass.setup.role = .lead
        d.pass.shots[1].verdict = .notSwing
        let dtl = Self.matt(d)
        // Följaren: ett slag märkt "Detection wrong" räknas inte, varken i listan eller i sessionen.
        var f = DemoPass.fo(id: "20261114-090000", created: Tal.dag(2026, 11, 14, timme: 9), sway: [-3, -2, -4])
        f.pass.setup.role = .follow
        f.pass.shots[0].detectionWrong = true
        let foljer = Self.matt(f)
        // Halvanalyserat: ett slag saknar klippet, så analysen är inte klar (Analyze står kvar).
        var halv = Self.matt(DemoPass.fo(id: "20261109-120000", created: Tal.dag(2026, 11, 9), sway: [-3, -2, -4, -3]))
        halv.shots[3].clip = nil
        XCTAssertNotNil(ShotPlan.next(halv))
        // Ett pass som inte är analyserat: klicken finns, ingen dom; serie 2 med en annan klubba.
        var ny = DemoPass.dtl(id: "20261115-120000", created: Tal.dag(2026, 11, 15), thrust: [-2, -1, -3, -2, -1, -2]).pass
        for i in ny.shots.indices { ny.shots[i].verdict = nil }
        ny.series[1].club = "pw"
        let tom = PassState(id: "20261101-120000", created: Tal.dag(2026, 11, 1), setup: PassSetup(view: .fo, club: "dr"))

        let rader = Sessionsrad.rader([fo, dtl, tom, halv, ny, foljer], parade: [dtl.id])
        // Utan par.json eller den andra telefonens slag är den styrandes rad sin vy (S6g).
        XCTAssertEqual(Sessionsrad(dtl).vyNamn, "Down the line")
        XCTAssertFalse(Sessionsrad(dtl).styr)
        XCTAssertEqual(rader.map(\.id), ["20261115-120000", "20261114-090000", "20261113-180000", "20261110-180500",
                                         "20261109-120000", "20261101-120000"], "senaste först")
        // Den styrandes parade pass är en rad "Paired" (S6g, BESLUT B82); följaren behåller sin vy.
        XCTAssertEqual(rader.map(\.vyNamn), ["Down the line", "Face on", "Paired", "Face on", "Face on", "Face on"])
        XCTAssertEqual(rader.map(\.styr), [false, false, true, false, false, false])
        XCTAssertEqual(rader.map(\.vy), [.dtl, .fo, .dtl, .fo, .fo, .fo])
        XCTAssertEqual(rader.map(\.svingar), [nil, 2, 4, 8, nil, 0])
        // Samma tal som sessionens rad ("7i · 2").
        XCTAssertEqual(rader[1].svingar, foljer.visningsPass.slag)
        XCTAssertEqual(rader[2].svingar, dtl.visningsPass.slag)
        XCTAssertEqual(rader.map(\.parad), [false, true, true, false, false, false])
        XCTAssertEqual(rader.map(\.klubba), ["7i, PW", "7i", "PW", "7i", "7i", "Dr"])
        XCTAssertEqual(rader[3].tid, "Tue, Nov 10\u{00A0}· 18:05")
        XCTAssertEqual(rader[2].upplasning, "Paired, Down the line and Face on, Fri, Nov 13, 18:00, PW, 4 swings")
        XCTAssertEqual(rader[1].upplasning, "Face on, Sat, Nov 14, 09:00, 7i, 2 swings, paired")
        XCTAssertEqual(rader[0].upplasning, "Down the line, Sun, Nov 15, 12:00, 7i, PW, Not analyzed")
        XCTAssertEqual(Texter.sessionsrad(vy: "Face on", dag: "Sat, Jan 9", klocka: "09:00", klubba: "7i", svingar: 1,
                                          parad: false), "Face on, Sat, Jan 9, 09:00, 7i, 1 swing")
        for r in rader {
            XCTAssertNil((r.vyNamn + r.tid + r.klubba + r.upplasning).range(of: "[åäöÅÄÖ]", options: .regularExpression))
        }
    }

    /// En FO-session visar inga DTL-kort och tvärtom; tempot ("bada") står i båda.
    func testSessionenVisarBaraSinVy() throws {
        let k = try katalog()
        let fo = Self.matt(DemoPass.fo(id: "20261110-180000", created: Tal.dag(2026, 11, 10, timme: 18),
                                       sway: [-3, -2, -4, -3, -2, -3]))
        let dtl = Self.matt(DemoPass.dtl(id: "20261110-180000", created: Tal.dag(2026, 11, 10, timme: 18),
                                         thrust: [-2, -1, -3, -2, -1, -2]))
        let vfo = Passvisning(katalog: k, pass: [fo.visningsPass])
        let vdtl = Passvisning(katalog: k, pass: [dtl.visningsPass])
        let kfo = vfo.kort(i: .fo), kdtl = vdtl.kort(i: .dtl)
        XCTAssertFalse(kfo.isEmpty)
        XCTAssertFalse(kdtl.isEmpty)
        XCTAssertTrue(kfo.allSatisfy { $0.vy != .dtl }, "\(kfo.filter { $0.vy == .dtl }.map(\.id))")
        XCTAssertTrue(kdtl.allSatisfy { $0.vy != .fo }, "\(kdtl.filter { $0.vy == .fo }.map(\.id))")
        XCTAssertTrue(kfo.contains { $0.id == "tempo" } && kdtl.contains { $0.id == "tempo" }, "bada i båda")
        XCTAssertTrue(kfo.contains { $0.id == "sway_topp" })
        XCTAssertFalse(kfo.contains { $0.id == "early_extension" })
        XCTAssertTrue(kdtl.contains { $0.id == "early_extension" })
        XCTAssertFalse(kdtl.contains { $0.id == "sway_topp" })
        // Genom katalogens vy: varje fel i katalogen hamnar i rätt session.
        for f in k.fel where f.aktiv && f.visas {                   // dom (b) visas inte (BESLUT B86)
            XCTAssertEqual(kfo.contains { $0.id == f.id }, f.vy != "dtl", f.id)
            XCTAssertEqual(kdtl.contains { $0.id == f.id }, f.vy != "fo", f.id)
        }
        // Samma kort som det gamla filtret FO/DTL.
        XCTAssertEqual(kfo.map(\.id), vfo.filtrerat(.fo).map(\.id))
        XCTAssertEqual(kdtl.map(\.id), vdtl.filtrerat(.dtl).map(\.id))

        // Granskningens rader per position: inget mått som bara finns i den andra vyn.
        func bara(_ vy: String) -> Set<String> {
            let i = Set(k.fel.filter { $0.vy == vy }.map(\.matt) + k.matt.filter { $0.vy == vy }.map(\.matt))
            let andra = Set(k.fel.filter { $0.vy != vy }.map(\.matt) + k.matt.filter { $0.vy != vy }.map(\.matt))
            return i.subtracting(andra)
        }
        let baraFO = bara("fo"), baraDTL = bara("dtl")
        XCTAssertTrue(baraDTL.contains("backen_thrust_traff") && baraFO.contains("sway_gap_traff"))
        let positioner = (1...10).map { "P\($0)" }
        var nFO = 0, nDTL = 0
        for p in positioner {
            let rfo = Positionsmatt.rader(k, vy: .fo, position: p, varden: fo.shots[0].measure?.values ?? [:])
            let rdtl = Positionsmatt.rader(k, vy: .dtl, position: p, varden: dtl.shots[0].measure?.values ?? [:])
            nFO += rfo.count
            nDTL += rdtl.count
            XCTAssertTrue(Set(rfo.map(\.matt)).isDisjoint(with: baraDTL), "FO \(p): \(rfo.map(\.matt))")
            XCTAssertTrue(Set(rdtl.map(\.matt)).isDisjoint(with: baraFO), "DTL \(p): \(rdtl.map(\.matt))")
        }
        XCTAssertGreaterThan(nFO, 0)
        XCTAssertGreaterThan(nDTL, 0)
        XCTAssertTrue(Positionsmatt.rader(k, vy: .dtl, position: "P7", varden: [:]).contains { $0.matt == "backen_thrust_traff" })
        XCTAssertFalse(Positionsmatt.rader(k, vy: .fo, position: "P7", varden: [:]).contains { $0.matt == "backen_thrust_traff" })

        XCTAssertTrue(Vyfilter.visas("bada", i: .fo) && Vyfilter.visas("bada", i: .dtl))
        XCTAssertTrue(Vyfilter.visas("fo", i: .fo) && !Vyfilter.visas("fo", i: .dtl))
        XCTAssertTrue(Vyfilter.visas("dtl", i: .dtl) && !Vyfilter.visas("dtl", i: .fo))
    }
}
