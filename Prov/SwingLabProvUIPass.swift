// PÅHITTADE PASS TILL UI-PROVET (PLAN S4i, BESLUT B101, METOD MS42). Två analyserade pass,
// ett FO och ett DTL, i en egen Store i /tmp/swinglab_prov/ui-store. SwingLabProvUI startar
// sedan appen på riktigt med SWINGLAB_PROV_ROT pekad hit (bara i simulatorn, SwingLabApp), så
// att Sessions, passet och Me granskas med data i stället för tomma.
//
// Samma väg som SwingLabProvSessioner: appens Store, DemoPass och lederna på disk. DATAN ÄR
// PÅHITTAD (SwingDemo, CLAUDE.md: Dataregeln).

import XCTest
import Swing
import Capture
import SwingDemo
@testable import SwingLab

@MainActor
final class SwingLabProvUIPass: XCTestCase {

    static let rot = "/tmp/swinglab_prov/ui-store"

    func testPassenTillUIProvet() throws {
        let rot = URL(fileURLWithPath: Self.rot, isDirectory: true)
        try? FileManager.default.removeItem(at: rot)
        let store = Store(root: rot, exportFolder: rot.appending(path: "Export"))
        store.setHeight(1.82)

        func spara(_ vy: Vy, _ dag: Date, varden: [Double]) throws -> String {
            var p = store.newPass(setup: PassSetup(view: vy, club: "j7", distance: 3, hand: .hoger, role: .solo), at: dag)
            let demo = vy == .fo
                ? DemoPass.fo(id: p.id, created: p.created, club: "j7", heightM: p.heightM, sway: varden)
                : DemoPass.dtl(id: p.id, created: p.created, club: "j7", heightM: p.heightM, thrust: varden)
            p.series = demo.pass.series
            p.shots = demo.pass.shots
            p.lastShotNumber = demo.pass.lastShotNumber
            p.status = .analyzed
            for s in p.shots {
                _ = try store.writeJoints(try XCTUnwrap(demo.leder[s.id]), shot: s.id, in: p.id)
            }
            try store.write(p)
            return p.id
        }
        // Tisdag 10 november (FO, öppnas av UI-provet) och fredag 13 november (DTL).
        let fo = try spara(.fo, Tal.dag(2026, 11, 10, timme: 18), varden: [-5, -4, -6, -5, -4, -5, -6, -4])
        let dtl = try spara(.dtl, Tal.dag(2026, 11, 13, timme: 18), varden: [-2, -1, -3, -2, -1, -2, -3, -1])

        let igen = Store(root: rot, exportFolder: rot.appending(path: "Export"))
        XCTAssertEqual(Set(igen.index.passes.map(\.id)), [fo, dtl], "passen sparade i UI-provets Store")
        XCTAssertEqual(igen.settings.heightM, 1.82)
        print("PROV: UI-provets pass \(fo) (FO) och \(dtl) (DTL) i \(Self.rot)")
    }
}
