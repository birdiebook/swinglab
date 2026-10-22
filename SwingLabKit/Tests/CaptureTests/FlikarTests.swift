import Foundation
import XCTest
import Swing
import SwingDemo
@testable import Capture

/// S4c: flikarna med riktig data. Passets egen längd (Jag är standarden för nya pass),
/// Jags spelhand och klubbor, och vilka pass Idag och Utveckling tar, på PÅHITTADE pass
/// (SwingDemo, CLAUDE.md: Dataregeln). METOD MS16
final class FlikarTests: XCTestCase {
    static let dag0 = Date(timeIntervalSince1970: 1_792_000_000)

    /// Ett pass med påhittade leder, mätt med sin egen längd.
    static func matt(_ id: String, dag: Double, club: String = "j7", heightM: Double? = 1.82,
                     sway: [Double] = [-3, -2, -1, -2, -3]) -> PassState {
        let d = DemoPass.fo(id: id, created: dag0.addingTimeInterval(dag * 86_400), club: club, heightM: heightM, sway: sway)
        var p = d.pass
        XCTAssertTrue(p.measureShots { d.leder[$0.id] })
        return p
    }

    // MARK: Passets längd

    /// Passet mäts med sin egen längd; en annan längd i passet mäter om bara det.
    func testPassetMatsMedSinEgenLangd() throws {
        let d = DemoPass.fo(id: "20261110-120000", created: Self.dag0, heightM: 1.90, sway: [-4, -2, -3])
        var p = d.pass
        XCTAssertEqual(p.shots.count, 3)
        XCTAssertEqual(p.series.map(\.nr), [1])
        XCTAssertTrue(p.measureShots { d.leder[$0.id] })
        XCTAssertEqual(p.measuredHeight?.heightM, 1.90)
        XCTAssertEqual(p.measuredHeight?.assumed, false)
        let sway190 = p.shots.map { $0.measure?.values["backen_sway_topp"] ?? .nan }
        for (v, s) in zip(sway190, [-4.0, -2, -3]) { XCTAssertEqual(v, s * 1.90 / 1.80, accuracy: 0.5) }
        XCTAssertFalse(p.measureShots { d.leder[$0.id] }, "allt är mätt med passets längd")
        p.heightM = nil
        XCTAssertTrue(p.measureShots { d.leder[$0.id] })
        XCTAssertEqual(p.measuredHeight?.assumed, true)
        let sway180 = p.shots.map { $0.measure?.values["backen_sway_topp"] ?? .nan }
        XCTAssertEqual(sway190[0] / sway180[0], 1.90 / 1.80, accuracy: 1e-6)
        // Åtta slag: fem i serie 1, tre i serie 2; första serien är de fem.
        let atta = Self.matt("20261111-120000", dag: 1, sway: [-1, -2, -3, -4, -5, -6, -7, -8])
        XCTAssertEqual(atta.series.map(\.nr), [1, 2])
        XCTAssertEqual(atta.countedSwings.count, 8)
        XCTAssertEqual(atta.visningsPass.serie1, 5)
    }

    /// Längden står i pass.json; ett pass från före S4c tar längden som slagen mättes med.
    func testLangdenIPassJson() throws {
        let p = Self.matt("20261110-120000", dag: 0, heightM: 1.86)
        let json = try PassCoding.encoder().encode(p)
        XCTAssertEqual(try PassCoding.decoder().decode(PassState.self, from: json), p)
        // Före S4c: ingen längd i filen.
        var gammal = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        XCTAssertEqual((gammal["heightM"] as? NSNumber)?.doubleValue, 1.86)
        gammal["heightM"] = nil
        let utan = try JSONSerialization.data(withJSONObject: gammal)
        XCTAssertEqual(try PassCoding.decoder().decode(PassState.self, from: utan).heightM, 1.86, "slagens längd")
        let antagen = Self.matt("20261110-120000", dag: 0, heightM: nil)
        var g2 = try XCTUnwrap(JSONSerialization.jsonObject(with: PassCoding.encoder().encode(antagen)) as? [String: Any])
        XCTAssertTrue(g2["heightM"] is NSNull, "antagen står som null")
        XCTAssertFalse(try PassCoding.decoder().decode(PassState.self, from: JSONSerialization.data(withJSONObject: g2))
            .heightPending)
        g2["heightM"] = nil
        XCTAssertNil(try PassCoding.decoder().decode(PassState.self, from: JSONSerialization.data(withJSONObject: g2)).heightM)
        let omatt = DemoPass.fo(id: "20261110-120000", created: Self.dag0, sway: [-1]).pass
        XCTAssertNil(try PassCoding.decoder().decode(PassState.self, from: PassCoding.encoder().encode(omatt)).heightM)
    }

    /// Ett omätt pass från före S4c (ingen längd i filen) tar Me:s längd när det läses, som
    /// förut; ett med mätta slag behåller slagens, och ett nytt pass rörs aldrig. METOD MS16
    func testGamlaOmattaPassTarMesLangd() throws {
        let omatt = DemoPass.fo(id: "20261110-120000", created: Self.dag0, sway: [-1, -2, -3])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: PassCoding.encoder().encode(omatt.pass)) as? [String: Any])
        json["heightM"] = nil
        var p = try PassCoding.decoder().decode(PassState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(p.heightPending)
        XCTAssertNil(p.heightM)
        p.fillMissingHeight(1.84)
        XCTAssertEqual(p.heightM, 1.84)
        XCTAssertFalse(p.heightPending)
        p.fillMissingHeight(1.70)
        XCTAssertEqual(p.heightM, 1.84, "en gång")
        XCTAssertTrue(p.measureShots { omatt.leder[$0.id] })
        XCTAssertEqual(p.measuredHeight?.heightM, 1.84, "mätt med Me:s längd")
        // Sparad står längden i filen: nästa läsning fyller inget.
        let igen = try PassCoding.decoder().decode(PassState.self, from: PassCoding.encoder().encode(p))
        XCTAssertFalse(igen.heightPending)
        XCTAssertEqual(igen, p)
        XCTAssertFalse(String(decoding: try PassCoding.encoder().encode(p), as: UTF8.self).contains("heightPending"))
        // Med mätta slag: slagens längd, inget att fylla.
        let matt = Self.matt("20261110-120000", dag: 0, heightM: 1.86)
        var g = try XCTUnwrap(JSONSerialization.jsonObject(with: PassCoding.encoder().encode(matt)) as? [String: Any])
        g["heightM"] = nil
        var m = try PassCoding.decoder().decode(PassState.self, from: JSONSerialization.data(withJSONObject: g))
        XCTAssertFalse(m.heightPending)
        m.fillMissingHeight(1.70)
        XCTAssertEqual(m.heightM, 1.86)
        // Ett nytt pass med längden antagen (null i filen) är inte gammalt: det rörs inte.
        let ny = DemoPass.fo(id: "20261110-120000", created: Self.dag0, sway: [-1]).pass
        let lasd = try PassCoding.decoder().decode(PassState.self, from: PassCoding.encoder().encode(ny))
        XCTAssertFalse(lasd.heightPending)
        XCTAssertEqual(lasd, ny)
    }

    // MARK: Filerna från PC:n och manifestet

    /// Filerna i AttJobbaPa/ äldst först (S2f:s namn), och alla som går igenom kontrollen.
    func testFokusFilerna() throws {
        XCTAssertEqual(FocusInbox.all(["att_jobba_pa-20270109-180000.json", "x.json", "att_jobba_pa-20261110-180000.json",
                                       "att_jobba_pa-.json", "att_jobba_pa-20261110-180000.json.part"]),
                       ["att_jobba_pa-20261110-180000.json", "att_jobba_pa-20270109-180000.json"])
        XCTAssertEqual(FocusInbox.latest(["att_jobba_pa-20261110-180000.json", "att_jobba_pa-20270109-180000.json"]),
                       "att_jobba_pa-20270109-180000.json")
        let mapp = FileManager.default.temporaryDirectory.appendingPathComponent("fokus-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: mapp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: mapp) }
        let gammal = Demo.attJobbaPaJSON
            .replacingOccurrences(of: "\"pass\": \"20270109-180000\"", with: "\"pass\": \"20261110-180000\"")
        try Data(gammal.utf8).write(to: mapp.appendingPathComponent("att_jobba_pa-20261110-180000.json"))
        try Data(Demo.attJobbaPaJSON.utf8).write(to: mapp.appendingPathComponent("att_jobba_pa-20270109-180000.json"))
        try Data("{".utf8).write(to: mapp.appendingPathComponent("att_jobba_pa-20270110-180000.json"))
        XCTAssertEqual(FocusInbox.readAll(in: mapp).map(\.pass), ["20261110-180000", "20270109-180000"], "den trasiga hoppas över")
    }

    /// Manifestet bär passets längd, så att PC:n mäter med samma skala (BESLUT B12); antagen
    /// står den inte med.
    func testManifestetBarLangden() throws {
        let app = PackageManifest.AppInfo(version: "0.1.0", build: "1")
        let tel = PackageManifest.PhoneInfo(model: "iPhone", ios: "18.2")
        func manifest(_ p: PassState) throws -> String {
            let m = PackageManifest.make(pass: p, app: app, phone: tel, created: Self.dag0,
                                         timeZone: TimeZone(identifier: "Europe/Stockholm")!, includeClips: false)
            let e = JSONEncoder()
            e.outputFormatting = [.sortedKeys]
            return String(decoding: try e.encode(m), as: UTF8.self)
        }
        let med = try manifest(Self.matt("20261110-120000", dag: 0, heightM: 1.86))
        XCTAssertTrue(med.contains("\"spelarens_langd_m\":1.86"), med)
        let utan = try manifest(Self.matt("20261110-120000", dag: 0, heightM: nil))
        XCTAssertFalse(utan.contains("spelarens_langd_m"))
        let tillbaka = try JSONDecoder().decode(PackageManifest.self, from: Data(med.utf8))
        XCTAssertEqual(tillbaka.playerHeight, 1.86)
    }

    // MARK: Jag

    /// Spelhanden och klubborna i Jag, och uppställningen för ett nytt pass.
    func testJag() throws {
        var s = try PassCoding.decoder().decode(AppSettings.self, from: Data(#"{"keepOriginals": true, "heightM": 1.82}"#.utf8))
        XCTAssertNil(s.hand)
        XCTAssertNil(s.clubs)
        XCTAssertEqual(s.bag, PassSetup.clubs, "alla när inga är valda")
        XCTAssertEqual(s.newSetup().club, "j7")
        XCTAssertEqual(s.newSetup().hand, .hoger)
        s.hand = .vanster
        s.clubs = ["dr", "j7"]
        XCTAssertEqual(s.newSetup(lastClub: "dr").club, "dr")
        XCTAssertEqual(s.newSetup(lastClub: "pw").club, "j7", "förra klubban finns inte i Jag")
        XCTAssertEqual(s.newSetup().hand, .vanster)
        s.toggleClub("j7")
        XCTAssertEqual(s.bag, ["dr"])
        XCTAssertEqual(s.newSetup().club, "dr")
        s.toggleClub("dr")
        XCTAssertEqual(s.bag, ["dr"], "den sista tas aldrig bort")
        s.toggleClub("pw")
        s.toggleClub("t3")
        s.toggleClub("okand")
        XCTAssertEqual(s.bag, ["dr", "t3", "pw"], "i uppställningens ordning")
        let tillbaka = try PassCoding.decoder().decode(AppSettings.self, from: PassCoding.encoder().encode(s))
        XCTAssertEqual(tillbaka, s)
    }

    // MARK: Vilka pass flikarna tar

    /// Idag: det senaste passet med slag som räknas, mot de tidigare med samma klubba, vy och
    /// längd. Utveckling: samma klubba och längd som det senaste; de andra med samma klubba
    /// räknas, en annan klubba hör inte hit.
    func testIdagOchUtvecklingTarRattPass() throws {
        let a = Self.matt("20261101-120000", dag: 1)
        let b = Self.matt("20261105-120000", dag: 5)
        let antagen = Self.matt("20261103-120000", dag: 3, heightM: nil)
        let driver = Self.matt("20261108-120000", dag: 8, club: "dr")
        let omatt = DemoPass.fo(id: "20261109-120000", created: Self.dag0.addingTimeInterval(9 * 86_400), sway: [-1]).pass
        let nu = Self.matt("20261107-120000", dag: 7)
        let alla = [nu, antagen, driver, a, omatt, b]
        XCTAssertEqual(PassHistory.latest(alla)?.id, "20261108-120000", "det senaste med slag som räknas")
        XCTAssertEqual(PassHistory.latest(alla.filter { $0.setup.club == "j7" })?.id, nu.id, "omätt räknas inte")
        XCTAssertNil(PassHistory.latest([omatt]))

        let j7 = alla.filter { $0.id != driver.id }
        let u = PassHistory.progress(j7)
        XCTAssertEqual(u.passes.map(\.id), [a.id, b.id, nu.id], "samma klubba och längd, äldst först")
        XCTAssertEqual(u.unmeasured, 1, "det omätta")
        XCTAssertEqual(u.otherHeight, 1, "den antagna längden")
        XCTAssertEqual(PassHistory.earlier(nu, among: j7).map(\.id), [a.id, b.id])
        let dr = PassHistory.progress(alla)
        XCTAssertEqual(dr.passes.map(\.id), [driver.id])
        XCTAssertEqual(dr.unmeasured + dr.otherHeight, 0, "en annan klubba räknas inte")
        XCTAssertTrue(PassHistory.progress([]).passes.isEmpty)
    }
}
