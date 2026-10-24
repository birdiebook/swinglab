// 3D MELLAN TVÅ TELEFONER I SIMULATORN (S6c-2, BESLUT B61, METOD MS19). Två PhoneLink i samma
// process över loopback (som SwingLabProvLink): följaren skickar sina slag (bunten, i bitar)
// med ett tapp mitt i, den styrande räknar 3D med TreD i Task.detached och skickar tre_d.json
// tillbaka. Passet är PÅHITTAT (tools/tests/fixturer/tre_d/, CLAUDE.md, Dataregeln), och talen
// jämförs med Pythons inom 0,05° per slag (PLAN S6c-2). Raderna "PROV: TreD …" hamnar i
// kompilera.txt.

import XCTest
import Network
import Swing
import Capture
import TreD
@testable import SwingLab

/// Fixturerna för 3D, lästa som i SwingLabProvTreD.
enum TreDFixtur {
    static let mapp = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("tools/tests/fixturer/tre_d")

    static func las(_ namn: String) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(contentsOf: mapp.appendingPathComponent("\(namn).json")))
            as! [String: Any]
    }

    /// Kompakta leder (int32-tider i 1e-4 s, int16-leder i 0,1 px och 0,001) → JointSeries.
    static func leder(_ k: [String: Any]) -> JointSeries {
        let t = Data(base64Encoded: k["t"] as! String)!, j = Data(base64Encoded: k["j"] as! String)!
        let tider: [Int32] = t.withUnsafeBytes { r in
            (0..<(t.count / 4)).map { Int32(littleEndian: r.loadUnaligned(fromByteOffset: $0 * 4, as: Int32.self)) }
        }
        let tal: [Int16] = j.withUnsafeBytes { r in
            (0..<(j.count / 2)).map { Int16(littleEndian: r.loadUnaligned(fromByteOffset: $0 * 2, as: Int16.self)) }
        }
        let frames = tider.indices.map { i in
            PoseFrame(t: Double(tider[i]) / 1e4, pts: 0, joints: (0..<13).map { m -> PoseJoint? in
                let b = (i * 13 + m) * 3
                return tal[b + 2] == 0 ? nil : PoseJoint(x: Double(tal[b]) / 10, y: Double(tal[b + 1]) / 10,
                                                         c: Double(tal[b + 2]) / 1000)
            }, confidence: 0.9)
        }
        return JointSeries(source: "pahittad-3d-r1", width: (k["width"] as! NSNumber).intValue,
                           height: (k["height"] as! NSNumber).intValue, frames: frames)
    }

    /// Passets två telefoner som TreD läser dem (dtl, fo).
    static func indata(_ pass: String) throws -> (dtl: TreDIndata, fo: TreDIndata) {
        let d = try las("indata/\(pass)")
        var ut: [String: TreDIndata] = [:]
        for vy in ["dtl", "fo"] {
            let p = (d["paket"] as! [String: Any])[vy] as! [String: Any]
            ut[vy] = TreDIndata(manifest: Data((p["manifest"] as! String).utf8),
                                lederna: (p["leder"] as! [String: Any]).mapValues { leder($0 as! [String: Any]) },
                                par: (p["par"] as? String).map { Data($0.utf8) },
                                enhet: (p["enhet"] as? String).map { Data($0.utf8) })
        }
        return (ut["dtl"]!, ut["fo"]!)
    }
}

/// Svaret från räkningen utanför huvudtråden.
private final class Ruta: @unchecked Sendable {
    var ut: TreDUt?
    var tid = 0.0
}

@MainActor
final class SwingLabProvTreDLink: XCTestCase {

    static let pass = "20261103-180000"

    /// Två telefoner för över ett påhittat pass: slagen med ett tapp, 3D på den styrande inom
    /// 0,05° från Python per slag, och resultatet tillbaka. METOD MS19, M50
    func testTvaTelefonerForOverEttPassOchRaknar() throws {
        let (dtl, fo) = try TreDFixtur.indata("utan_brus")
        let bunt = try SlagBunt.make(manifest: fo.manifest, enhet: fo.enhet, par: fo.par, leder: fo.lederna)
        let buntData = try bunt.data()

        let styr = PhoneLink(role: .lead, view: .dtl, mode: .pass, bonjour: false, device: "prov-styr")
        styr.forPass(Self.pass)
        var mottaget: Data?
        styr.onData = { kind, pass, d in
            if kind == Overforing.slag && pass == Self.pass { mottaget = d }
            return .sparad
        }
        styr.start()
        defer { styr.stop() }
        let port = try XCTUnwrap(väntaPå(10) { styr.port }, "lyssnaren fick ingen port")
        let folj = PhoneLink(role: .follow, view: .fo, mode: .pass, partner: "prov-styr",
                             endpoint: .hostPort(host: "127.0.0.1", port: try XCTUnwrap(NWEndpoint.Port(rawValue: port))),
                             bonjour: false, device: "prov-folj")
        var treD: Data?
        var levererat = false
        folj.onData = { kind, _, d in
            if kind == Overforing.treD { treD = d }
            return .sparad
        }
        folj.onDelivered = { kind, _ in if kind == Overforing.slag { levererat = true } }
        folj.start()
        defer { folj.stop() }
        XCTAssertTrue(vänta(15) { styr.peers.first?.connected == true && folj.peers.first?.connected == true },
                      "ingen anslutning")

        // Slagen, och flygplansläge på följaren mitt i: det som inte kvitterats går igen.
        var start = Date()
        folj.send(Overforing.dela(kind: Overforing.slag, pass: Self.pass, data: buntData))
        folj.suspend(2)
        XCTAssertTrue(vänta(40) { mottaget != nil && levererat && folj.pendingTransfers == 0 },
                      "slagen kom inte fram efter tappet")
        let medTapp = Date().timeIntervalSince(start)
        XCTAssertEqual(mottaget, buntData)
        let bitar = Overforing.antal(buntData.count)
        print(String(format: "PROV: TreD överföring %ld slag, bunten %ld byte (%ld per slag) i %ld bitar, %.1f s med ett tapp om 2 s",
                     bunt.leder.count, buntData.count, buntData.count / max(1, bunt.leder.count), bitar, medTapp))

        // Samma bunt igen utan tapp: tiden på loopback.
        mottaget = nil
        levererat = false
        start = Date()
        var andra = bunt
        andra.enhet = (andra.enhet ?? "") + " "                // ett nytt innehåll, en ny överföring
        let andraData = try andra.data()
        folj.send(Overforing.dela(kind: Overforing.slag, pass: Self.pass, data: andraData))
        XCTAssertTrue(vänta(20) { mottaget == andraData && levererat }, "andra överföringen kom inte fram")
        print(String(format: "PROV: TreD överföring utan tapp %.2f s på loopback", Date().timeIntervalSince(start)))

        // Den styrande räknar utanför huvudtråden.
        let m = try XCTUnwrap(mottaget)
        let ruta = Ruta()
        Task.detached(priority: .userInitiated) {
            let a = try! TreDIndata(try! SlagBunt.las(m))
            let t0 = Date()
            let ut = TreDTelefon.rakna(a, dtl)
            ruta.tid = Date().timeIntervalSince(t0)
            await MainActor.run { ruta.ut = ut }
        }
        XCTAssertTrue(vänta(60) { ruta.ut != nil }, "3D räknades inte")
        guard case let .resultat(r) = try XCTUnwrap(ruta.ut) else { return XCTFail("3D hoppades över: \(ruta.ut!)") }

        // Mot Pythons fixtur, per slag.
        let fx = try TreDFixtur.las("utan_brus")
        let py = ((fx["varianter"] as! [String: Any])["grund"] as! [String: Any])["python"] as! [String: Any]
        let pslag = py["slag"] as! [[String: Any]]
        XCTAssertEqual(r.slag.count, pslag.count)
        XCTAssertEqual(r.parning.par, ((py["parning"] as! [String: Any])["par"] as! NSNumber).intValue)
        XCTAssertEqual(r.osaker, py["osaker"] as? [String])
        var storst = 0.0
        for (s, q) in zip(r.slag, pslag) {
            XCTAssertEqual(s.dtl, q["dtl"] as? String)
            XCTAssertEqual(s.fo, q["fo"] as? String)
            let pm = (q["matt"] as? [String: Any]) ?? [:]
            XCTAssertEqual(Set((s.matt ?? [:]).keys), Set(pm.keys))
            for (k, v) in pm {
                let d = abs((s.matt?[k] ?? .nan) - (v as! NSNumber).doubleValue)
                storst = max(storst, d.isNaN ? .infinity : d)
            }
        }
        print(String(format: "PROV: TreD på telefonens väg (2D-faserna och bunten) %ld slag på %.2f s i simulatorn, största avvikelse mot Python %.2e° per slag",
                     r.slag.count, ruta.tid, storst))
        XCTAssertLessThanOrEqual(storst, 0.05)                                 // PLAN S6c-2

        // Resultatet tillbaka till följaren.
        let fil = TreDFil(pass: Self.pass, raknad: Date(), raknadAv: .dtl,
                          kallor: ["dtl": Overforing.summa(Data()), "fo": Overforing.summa(m)], sekunder: ruta.tid,
                          ut: .resultat(r))
        let filData = try fil.data()
        styr.send(Overforing.dela(kind: Overforing.treD, pass: Self.pass, data: filData))
        XCTAssertTrue(vänta(20) { treD == filData && styr.pendingTransfers == 0 }, "3D kom inte tillbaka")
        XCTAssertEqual(try TreDFil.las(try XCTUnwrap(treD)).treD?.slag.count, r.slag.count)
        print("PROV: TreD tillbaka till följaren, tre_d.json \(filData.count) byte")

        // Båda telefonerna sparar samma fil i passet, och medianerna i pass.json.
        let rot = FileManager.default.temporaryDirectory.appending(path: "swinglab-prov/tred-\(UUID().uuidString)")
        let store = Store(root: rot, exportFolder: rot.appending(path: "Export"))
        let p = store.newPass(setup: PassSetup(view: .fo, role: .follow))
        XCTAssertTrue(store.saveTreD(try TreDFil.las(treD!), passID: p.id))
        XCTAssertEqual(store.treD(p.id)?.treD?.slag, r.slag)
        XCTAssertEqual(store.treD(p.id)?.kallor, fil.kallor)
        XCTAssertEqual(store.load(p.id)?.treD?.keys.sorted(), TvaKameror.matt.sorted())
        XCTAssertEqual(store.load(p.id)?.visningsPass.treD["xfaktor_topp"]?.median, r.session["xfaktor_topp"]?.median)
        XCTAssertTrue(store.saveOtherPhone(buntData, passID: p.id))
        XCTAssertTrue(store.hasOtherPhone(p.id))
        XCTAssertNil(store.problem)
    }

    /// Passets 3D kopplar inte till den andra telefonens inspelning, och inte till en annan telefon
    /// än passets partner; ett annat pass ger ett nej som följaren visar (BESLUT B61, METOD MS19).
    func testSyftetPartnernOchNej() throws {
        // DTL:s inspelning lyssnar; FO:s passvy hittar den men kopplar inte.
        let insp = PhoneLink(role: .lead, view: .dtl, mode: .record, bonjour: false, device: "prov-insp")
        insp.start()
        defer { insp.stop() }
        let port = try XCTUnwrap(väntaPå(10) { insp.port }, "lyssnaren fick ingen port")
        let ep = NWEndpoint.hostPort(host: "127.0.0.1", port: try XCTUnwrap(NWEndpoint.Port(rawValue: port)))
        let passvy = PhoneLink(role: .follow, view: .fo, mode: .pass, endpoint: ep, bonjour: false, device: "prov-folj")
        passvy.start()
        defer { passvy.stop() }
        XCTAssertFalse(vänta(5) { !insp.peers.isEmpty || !passvy.peers.isEmpty }, "passvyn kopplade till inspelningen")
        passvy.stop()

        // En passvy hos DTL, men följaren är låst till en annan partner.
        let styr = PhoneLink(role: .lead, view: .dtl, mode: .pass, bonjour: false, device: "prov-styr")
        styr.forPass(Self.pass)
        styr.start()
        defer { styr.stop() }
        let p2 = try XCTUnwrap(väntaPå(10) { styr.port })
        let ep2 = NWEndpoint.hostPort(host: "127.0.0.1", port: try XCTUnwrap(NWEndpoint.Port(rawValue: p2)))
        let fel = PhoneLink(role: .follow, view: .fo, mode: .pass, partner: "en-annan", endpoint: ep2, bonjour: false,
                            device: "prov-folj")
        fel.start()
        XCTAssertFalse(vänta(4) { !styr.peers.isEmpty || !fel.peers.isEmpty }, "kopplade till fel partner")
        fel.stop()

        // Rätt partner men ett annat pass: nej, och följaren slutar skicka.
        let folj = PhoneLink(role: .follow, view: .fo, mode: .pass, partner: "prov-styr", endpoint: ep2, bonjour: false,
                             device: "prov-folj")
        var nej: [String] = []
        folj.onRefused = { _, _, f in nej.append(f) }
        folj.start()
        defer { folj.stop() }
        XCTAssertTrue(vänta(15) { styr.peers.first?.connected == true && folj.peers.first?.connected == true })
        folj.send(Overforing.dela(kind: Overforing.slag, pass: "20261103-190000", data: Data(repeating: 1, count: 1000)))
        XCTAssertTrue(vänta(10) { nej == [Overforing.felPass] && folj.pendingTransfers == 0 }, "inget nej")
        print("PROV: TreD passvyn kopplar inte till inspelningen eller fel partner; ett annat pass får nej (\(nej))")
    }

    /// Följarens egen bunt ur ett pass: samma manifest som paketet, lederna ur Leder/.
    func testEgenBuntUrPasset() throws {
        let rot = FileManager.default.temporaryDirectory.appending(path: "swinglab-prov/egen-\(UUID().uuidString)")
        let store = Store(root: rot, exportFolder: rot.appending(path: "Export"))
        var p = store.newPass(setup: PassSetup(view: .fo, role: .follow))
        let (_, fo) = try TreDFixtur.indata("utan_brus")
        let js = try XCTUnwrap(fo.lederna["s01"])
        p.series = [SeriesRecord(nr: 1, source: .recording, club: "j7", file: "Video/01.mov", start: Date(),
                                 startHost: 1, duration: 20, bytes: 1, timing: FrameTiming.analyze((0..<240).map { Double($0) / 240 }),
                                 clicks: [Click(time: 5, strength: 20)], orientation: 6, uprightWidth: 1080, uprightHeight: 1920)]
        let rel = try store.writeJoints(js, shot: "s01", in: p.id)
        p.shots = [ShotRecord(id: "s01", series: 1, click: Click(time: 5, strength: 20), impact: 4.99, verdict: .swing,
                              joints: rel, jointFrames: js.frames.count)]
        store.save(p)
        let (b, d) = try TreDKoppling.egenBunt(p, folder: store.passFolder(p.id), app: Export.appInfo(),
                                               phone: Export.phoneInfo(), device: Export.deviceInfo(p))
        XCTAssertEqual(b.vy, .fo)
        XCTAssertEqual(b.pass, p.id)
        XCTAssertEqual(Array(b.leder.keys), ["s01"])
        XCTAssertEqual(try b.lederna()["s01"]?.frames.map(\.t), js.rounded().frames.map(\.t))
        // Samma pass, samma bunt och summa (kallorna i tre_d.json).
        let (_, d2) = try TreDKoppling.egenBunt(p, folder: store.passFolder(p.id), app: Export.appInfo(),
                                                phone: Export.phoneInfo(), device: Export.deviceInfo(p))
        XCTAssertEqual(Overforing.summa(d), Overforing.summa(d2))
        print("PROV: TreD egen bunt ett slag \(d.count) byte")
    }

    // MARK: - Hjälp

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
