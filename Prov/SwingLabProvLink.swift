// SIMULATORPROVET FÖR TVÅ TELEFONER (S2_SPEC §10.2 steg 9, §12 S2g). Två PhoneLink i samma
// process, den styrande och följaren, över Network.framework på loopback (127.0.0.1)
// utan Bonjour: appens egen kod för förbindelsen, ramarna, pingen, kvittenserna och
// återanslutningen. Bonjour och frågan om lokalt nätverk går bara att se på telefonerna
// (S2_SPEC §11.3). Klicken är PÅHITTADE, med känd förskjutning.
//
// PROV-raderna i loggen samlas i resultat/<sha>.kompilera.txt.

import XCTest
import Network
import Swing
import Capture
@testable import SwingLab

@MainActor
final class SwingLabProvLink: XCTestCase {

    static let pass = "20261022-101500"
    /// Den styrandes klick i filen, s, och följarens jitter.
    static let a = [1.5, 4.25, 7.9, 12.05, 15.6, 19.3]
    static let jitter = [0.0009, -0.0012, 0.0004, -0.0007, 0.0011, -0.0003]
    /// Följarens filtid = den styrandes + den här, för samma klick.
    static let kand = 0.4123

    /// Steg 9: anslutning, ping/pong, start och stopp, ett tapp mitt i serien som inte
    /// förlorar något, och parningen av klicken inom 5 ms. BESLUT B21, B22. METOD MS9, MS10
    func testTvaTelefonerOverLoopback() throws {
        let styr = PhoneLink(role: .lead, view: .dtl, bonjour: false)
        var parade: [PairEntry] = []
        styr.onPaired = { parade.append($0) }
        styr.start()
        defer { styr.stop() }
        let port = try XCTUnwrap(väntaPå(10) { styr.port }, "lyssnaren fick ingen port")
        let nwPort = try XCTUnwrap(NWEndpoint.Port(rawValue: port))
        let folj = PhoneLink(role: .follow, view: .fo, endpoint: .hostPort(host: "127.0.0.1", port: nwPort),
                             bonjour: false)
        var starter: [String] = []
        var stopp: [Int] = []
        folj.onStart = { p, n in starter.append("\(p)/\(n)") }
        folj.onStop = { stopp.append($0) }
        folj.start()
        defer { folj.stop() }

        // Följaren ansluter av sig själv; båda ser den andra.
        XCTAssertTrue(vänta(15) { styr.peers.first?.connected == true && folj.peers.first?.connected == true },
                      "ingen anslutning")
        XCTAssertEqual(styr.peers.first?.view, .fo)
        XCTAssertEqual(folj.peers.first?.view, .dtl)

        // Ping/pong: skuren vid anslutningen. Samma klocka i samma process, så θ ≈ 0.
        XCTAssertTrue(vänta(10) { styr.sampleCount >= LinkLeader.burst }, "pingen kom inte fram")
        let k = try XCTUnwrap(styr.clock)
        print(String(format: "PROV: link klocka θ %.3f ms, osäkerhet %.3f ms, %ld prov",
                     k.offset * 1000, k.uncertainty * 1000, k.samples))
        XCTAssertLessThan(abs(k.offset), 0.005)
        XCTAssertLessThanOrEqual(abs(k.offset), k.uncertainty + 1e-9)

        // Start på den styrande startar följaren.
        styr.startSeries(passID: Self.pass, series: 1)
        XCTAssertTrue(vänta(5) { starter == ["\(Self.pass)/1"] }, "starten kom inte fram")
        folj.report(recording: true, freeBytes: 50_000_000_000, pressure: .nominal)
        XCTAssertTrue(vänta(5) { styr.peers.first?.recording == true }, "följarens läge kom inte fram")

        // Flygplansläge på följaren i 3 s mitt i serien: stoppet når inte fram.
        folj.suspend(3)
        XCTAssertTrue(vänta(8) { styr.peers.first?.connected == false }, "den styrande såg inte tappet")
        styr.stopSeries()
        _ = vänta(0.5) { false }
        XCTAssertTrue(stopp.isEmpty, "stoppet gick fram under tappet")
        // Tillbaka av sig själv: stoppet når fram, och starten görs inte om.
        XCTAssertTrue(vänta(15) { stopp == [1] }, "stoppet kom inte fram efter tappet")
        XCTAssertEqual(starter.count, 1)
        XCTAssertTrue(vänta(5) { styr.peers.first?.connected == true })
        print("PROV: link tapp 3 s mitt i serien: start 1, stopp 1 efter återanslutningen")

        // Ett nytt tapp medan följaren läser sin fil: klicken väntar och går fram sedan.
        folj.suspend(2)
        XCTAssertTrue(vänta(8) { styr.peers.first?.connected == false })
        let sl = LinkClock.now()
        let sf = sl - Self.kand                      // samma klocka: b = a + SL − SF
        let b = zip(Self.a, Self.jitter).map { Click(time: $0 + Self.kand + $1, strength: 20) }
        folj.finished(LinkSeries(series: 1, localSeries: 1, passID: Self.pass, startHost: sf, frameRate: 240,
                                 clicks: b, view: .fo, distance: 3))
        XCTAssertEqual(folj.unacknowledged, 1)
        styr.ownFinished(LinkSeries(series: 1, localSeries: 1, passID: Self.pass, startHost: sl, frameRate: 240,
                                    clicks: Self.a.map { Click(time: $0, strength: 30) }, view: .dtl, distance: 3))
        XCTAssertTrue(parade.isEmpty)
        XCTAssertTrue(vänta(15) { !parade.isEmpty && folj.unacknowledged == 0 }, "klicken kom inte fram efter tappet")
        // Pingen efter återanslutningen kan para om med smalare fönster: vänta ut skuren.
        _ = vänta(1.5) { false }
        let e = try XCTUnwrap(parade.last)
        print(String(format: "PROV: link par %ld av %ld, förskjutning %.4f s (känd %.4f), median |rest| %.2f ms, klocka %@, osäker %@",
                     e.pairCount, Self.a.count, e.offset, Self.kand, (e.medianAbsResidual ?? .nan) * 1000,
                     e.clockSource.rawValue, e.uncertain ? "ja" : "nej"))
        XCTAssertEqual(e.offset, Self.kand, accuracy: 0.005)
        XCTAssertEqual(e.pairCount, Self.a.count)
        XCTAssertFalse(e.uncertain)
        XCTAssertLessThan(try XCTUnwrap(e.medianAbsResidual), 0.005)
        XCTAssertNotEqual(e.clockSource, PairEntry.ClockSource.none)

        // par.json i den styrandes pass, som RecordView skriver det.
        let rot = FileManager.default.temporaryDirectory.appending(path: "swinglab-prov/link-\(UUID().uuidString)")
        let store = Store(root: rot, exportFolder: rot.appending(path: "Export"))
        let p = store.newPass(setup: PassSetup(view: .dtl, role: .lead))
        store.savePair(e, passID: p.id, model: PhoneLink.model(), view: .dtl)
        let fil = try XCTUnwrap(store.pairs(p.id), "par.json gick inte att läsa")
        XCTAssertEqual(fil.format, PairFile.formatName)
        XCTAssertEqual(fil.entries, [e])
        XCTAssertNil(store.problem)
    }

    /// Granskningen av S2g: Continue på den styrande innan följarens serie kommit, och
    /// kameran öppnas igen. Serien paras ändå och hamnar i par.json: den styrandes
    /// serier läses ur passet, och följarens sparas i foljare.json innan kvittensen.
    /// BESLUT B22. METOD MS10
    func testParningenEfterAttVynStangts() throws {
        let rot = FileManager.default.temporaryDirectory.appending(path: "swinglab-prov/omstart-\(UUID().uuidString)")
        let store = Store(root: rot, exportFolder: rot.appending(path: "Export"))
        var pass = store.newPass(setup: PassSetup(view: .dtl, role: .lead))
        let a1 = PhoneLink(role: .lead, view: .dtl, bonjour: false)
        a1.attachLead(store: store, pass: pass)
        a1.start()
        let port = try XCTUnwrap(väntaPå(10) { a1.port }, "lyssnaren fick ingen port")
        let nwPort = try XCTUnwrap(NWEndpoint.Port(rawValue: port))
        let folj = PhoneLink(role: .follow, view: .fo, endpoint: .hostPort(host: "127.0.0.1", port: nwPort), bonjour: false)
        var starter = 0
        var stopp = 0
        folj.onStart = { _, _ in starter += 1 }
        folj.onStop = { _ in stopp += 1 }
        folj.start()
        defer { folj.stop() }
        XCTAssertTrue(vänta(15) { a1.peers.first?.connected == true }, "ingen anslutning")
        a1.startSeries(passID: pass.id, series: 1)
        XCTAssertTrue(vänta(5) { starter == 1 })
        a1.stopSeries()
        XCTAssertTrue(vänta(5) { stopp == 1 })

        // Den styrandes serie är läst och sparad i passet.
        let sl = LinkClock.now()
        let sf = sl - Self.kand
        pass.series.append(SeriesRecord(nr: 1, source: .recording, club: "j7", file: "Video/01.mov", start: Date(),
                                        startHost: sl, duration: 25, bytes: 1,
                                        timing: FrameTiming.analyze((0..<240).map { Double($0) / 240 }),
                                        clicks: Self.a.map { Click(time: $0, strength: 30) }, orientation: 6,
                                        uprightWidth: 1080, uprightHeight: 1920))
        store.save(pass)
        a1.ownFinished(LinkSeries(record: pass.series[0], series: 1, passID: pass.id, setup: pass.setup))
        // Continue: kameran stängs innan följaren läst sin fil.
        a1.stop()
        XCTAssertTrue(vänta(8) { folj.peers.first?.connected == false }, "följaren såg inte att den styrande gick")
        let b = zip(Self.a, Self.jitter).map { Click(time: $0 + Self.kand + $1, strength: 20) }
        folj.finished(LinkSeries(series: 1, localSeries: 1, passID: pass.id, startHost: sf, frameRate: 240,
                                 clicks: b, view: .fo, distance: 3))
        XCTAssertEqual(folj.unacknowledged, 1)
        XCTAssertNil(store.pairs(pass.id))

        // Kameran öppnas igen, som RecordView gör det: på samma port, så att följaren hittar den.
        let a2 = PhoneLink(role: .lead, view: .dtl, port: port, bonjour: false)
        a2.attachLead(store: store, pass: try XCTUnwrap(store.load(pass.id)))
        a2.start()
        defer { a2.stop() }
        XCTAssertTrue(vänta(20) { store.pairs(pass.id)?.entries.isEmpty == false && folj.unacknowledged == 0 },
                      "serien parades inte efter att kameran öppnats igen")
        let e = try XCTUnwrap(store.pairs(pass.id)?.entries.first)
        XCTAssertEqual(e.offset, Self.kand, accuracy: 0.005)
        XCTAssertEqual(e.pairCount, Self.a.count)
        XCTAssertEqual(store.followerRecords(pass.id).map(\.series.series), [1])
        // Etiketten på den styrande: antal par och median |rest|.
        XCTAssertTrue(vänta(5) { a2.peers.first?.pairs == Self.a.count }, "parningen syns inte på den styrande")
        XCTAssertEqual(a2.peers.first?.uncertain, false)
        print(String(format: "PROV: link efter Continue: par %ld, förskjutning %.4f s (känd %.4f), median |rest| %.2f ms",
                     e.pairCount, e.offset, Self.kand, (e.medianAbsResidual ?? .nan) * 1000))

        // En tredje gång, utan följare: båda serierna läses från disken och paras igen.
        let a3 = PhoneLink(role: .lead, view: .dtl, bonjour: false)
        var igen: [PairEntry] = []
        a3.onPaired = { igen.append($0) }
        a3.attachLead(store: store, pass: try XCTUnwrap(store.load(pass.id)))
        XCTAssertEqual(igen.count, 1)
        XCTAssertEqual(igen.first?.offset ?? 0, Self.kand, accuracy: 0.005)
    }

    /// Följaren tar den styrandes pass-id när dess eget pass är tomt (S2_SPEC §7.4).
    func testFoljarenTarPassetsId() throws {
        let rot = FileManager.default.temporaryDirectory.appending(path: "swinglab-prov/adopt-\(UUID().uuidString)")
        let store = Store(root: rot, exportFolder: rot.appending(path: "Export"))
        let egen = store.newPass(setup: PassSetup(view: .fo, role: .follow), at: Date(timeIntervalSince1970: 1_792_848_000))
        let ny = try XCTUnwrap(store.adopt(egen, id: Self.pass))
        XCTAssertEqual(ny.id, Self.pass)
        XCTAssertEqual(ny.setup.role, .follow)
        XCTAssertEqual(ny.setup.view, .fo)
        XCTAssertEqual(store.index.passes.map(\.id), [Self.pass])
        XCTAssertNil(store.load(egen.id))
        // Ett pass med serier byter aldrig id.
        var med = store.newPass(setup: PassSetup(view: .fo, role: .follow), at: Date(timeIntervalSince1970: 1_792_848_100))
        med.series = [SeriesRecord(nr: 1, source: .recording, club: "j7", file: "Video/01.mov", start: Date(),
                                   startHost: 1, duration: 1, bytes: 1, timing: FrameTiming.analyze([0, 1 / 240.0]),
                                   clicks: [], orientation: 6, uprightWidth: 1080, uprightHeight: 1920)]
        store.save(med)
        XCTAssertNil(store.adopt(med, id: "20261022-120000"))
        XCTAssertEqual(store.load(med.id)?.series.count, 1)
        XCTAssertNil(store.load("20261022-120000"))
    }

    // MARK: - Hjälp

    /// Kör huvudtråden tills villkoret håller eller tiden gått.
    private func vänta(_ sekunder: TimeInterval, _ villkor: () -> Bool) -> Bool {
        let slut = Date().addingTimeInterval(sekunder)
        while Date() < slut {
            if villkor() { return true }
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        return villkor()
    }

    private func väntaPå<T>(_ sekunder: TimeInterval, _ värde: () -> T?) -> T? {
        var ut: T?
        _ = vänta(sekunder) {
            ut = värde()
            return ut != nil
        }
        return ut
    }
}
