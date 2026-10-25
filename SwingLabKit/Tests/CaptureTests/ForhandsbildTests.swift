import Foundation
import XCTest
import Swing
@testable import Capture

/// Den andra telefonens bild live (PLAN S2k, BESLUT B90, METOD MS35): meddelandena på tråden,
/// förmågan i hello, mottrycket (högst en bild i flykt), takten och den styrandes ruta. Bilderna
/// är påhittade bytes, ingen riktig JPEG behövs här (appen kodar; simulatorprovet prövar den).
final class ForhandsbildTests: XCTestCase {
    static let lead = LinkHello(role: .lead, device: "A", model: "iPhone18,3", app: "0.1.0", view: .dtl)
    static let follow = LinkHello(role: .follow, device: "B", model: "iPhone14,5", app: "0.1.0", view: .fo)
    /// En styrande och en följare från bygget före S2k: bitar och klipp, ingen förhandsbild.
    static let gammalLead = LinkHello(role: .lead, device: "A", model: "m", app: "0.0.9", view: .dtl,
                                      caps: ["part1", "video1"])
    static let gammalFolj = LinkHello(role: .follow, device: "B", model: "m", app: "0.0.9", view: .fo,
                                      caps: ["part1", "video1"])

    static func bild(_ n: Int, t: Double = 100, bytes: Int = 24_000) -> LinkPreview {
        LinkPreview(n: n, t: t, w: 360, h: 640, jpeg: Data((0..<bytes).map { UInt8(($0 * 31 + n) & 0xFF) }))
    }

    // MARK: Tråden

    func testBildenOchKvittensenTurOchRetur() throws {
        let alla: [LinkMessage] = [.preview(Self.bild(7)), .previewAck(n: 7), .preview(Self.bild(8, bytes: 1))]
        var strom = Data()
        for m in alla { strom.append(try Wire.frame(m)) }
        var r = Wire.Reader()
        XCTAssertEqual(try r.feed(strom), alla)
        // En byte i taget.
        var r1 = Wire.Reader()
        var ut: [LinkMessage] = []
        for b in strom { ut += try r1.feed(Data([b])) }
        XCTAssertEqual(ut, alla)
        // Formen på tråden (docs/FORMAT.md): JPEG som base64, kvittensen med numret.
        let text = String(decoding: try Wire.frame(.previewAck(n: 7)).dropFirst(4), as: UTF8.self)
        XCTAssertTrue(text.contains("\"type\":\"preview_ack\""), text)
        XCTAssertTrue(text.contains("\"n\":7"), text)
        let b = String(decoding: try Wire.frame(.preview(Self.bild(3, bytes: 3))).dropFirst(4), as: UTF8.self)
        XCTAssertTrue(b.contains("\"type\":\"preview\""), b)
        XCTAssertTrue(b.contains("\"jpeg\":\"\(Self.bild(3, bytes: 3).jpeg.base64EncodedString())\""), b)
    }

    /// Den största bilden ryms i en ram, och en bild på 24 kB blir cirka 32 kB på tråden (MS35).
    func testBildenRymsIEnRam() throws {
        let stor = try Wire.frame(.preview(Self.bild(1, bytes: LinkPreview.maxBytes)))
        XCTAssertLessThanOrEqual(stor.count, Wire.maxLength)
        let vanlig = try Wire.frame(.preview(Self.bild(1)))
        XCTAssertEqual(Double(vanlig.count), 24_000 * 4 / 3, accuracy: 300)
    }

    /// En app från före S6c-2 stänger vid en okänd typ, en senare hoppar över den: därför skickas
    /// bilden bara till en telefon med "preview1". Den här appens läsare hoppar över en okänd typ.
    func testForHelloOchEnSenareApp() throws {
        XCTAssertTrue(LinkHello.ourCaps.contains(LinkPreview.cap))
        XCTAssertTrue(Self.lead.kanForhandsbild)
        XCTAssertFalse(Self.gammalLead.kanForhandsbild)
        XCTAssertFalse(LinkHello(role: .lead, device: "A", model: "m", app: "0", view: .dtl, caps: nil).kanForhandsbild)
        var d = try Wire.frame(.stop(series: 1))
        let okand = Data(#"{"type":"preview2","n":1}"#.utf8)
        d.append(contentsOf: [0, 0, 0, UInt8(okand.count)])
        d.append(okand)
        var r = Wire.Reader()
        XCTAssertEqual(try r.feed(d), [.stop(series: 1)])
        XCTAssertEqual(r.skipped, 1)
    }

    // MARK: Förmågan

    func testFoljarenSkickarBaraTillEnStyrandeMedForhandsbild() {
        var f = LinkFollower(hello: Self.follow)
        // Inte kopplad: inget.
        XCTAssertEqual(f.sendPreview(Self.bild(1)), [])
        _ = f.connected()
        // Kopplad men inget hello än: inget.
        XCTAssertFalse(f.kanForhandsbild)
        XCTAssertEqual(f.sendPreview(Self.bild(1)), [])
        // En äldre styrande: inget, och inget annat ändras.
        _ = f.receive(.hello(Self.gammalLead), at: 0, now: { 0 })
        XCTAssertFalse(f.kanForhandsbild)
        XCTAssertEqual(f.sendPreview(Self.bild(1)), [])
        // En styrande med "preview1": bilden går.
        _ = f.receive(.hello(Self.lead), at: 0, now: { 0 })
        XCTAssertTrue(f.kanForhandsbild)
        XCTAssertEqual(f.sendPreview(Self.bild(2)), [.send(.preview(Self.bild(2)))])
        // Kvittensen går till appen.
        XCTAssertEqual(f.receive(.previewAck(n: 2), at: 0, now: { 0 }), [.previewAck(2)])
        // Tappad: inget, och bilden sparas inte för senare (B90).
        f.disconnected()
        XCTAssertEqual(f.sendPreview(Self.bild(3)), [])
        XCTAssertEqual(f.connected(), [.send(.hello(Self.follow))])
    }

    func testDenStyrandeKvitterarOchVisar() {
        var l = LinkLeader(hello: Self.lead)
        _ = l.connected(peer: 1)
        // En bild från en okänd förbindelse: inget.
        XCTAssertEqual(l.receive(.preview(Self.bild(1)), from: 1, at: 0), [])
        _ = l.receive(.hello(Self.follow), from: 1, at: 0)
        XCTAssertEqual(l.receive(.preview(Self.bild(4)), from: 1, at: 0),
                       [.send(peer: 1, .previewAck(n: 4)), .preview(device: "B", Self.bild(4))])
        // En senare version: kvitteras men visas inte.
        var v2 = Self.bild(5)
        v2.v = 2
        XCTAssertEqual(l.receive(.preview(v2), from: 1, at: 0), [.send(peer: 1, .previewAck(n: 5))])
        // En följare utan förmågan: ingen kvittens och ingen bild.
        _ = l.connected(peer: 2)
        _ = l.receive(.hello(LinkHello(role: .follow, device: "C", model: "m", app: "0.0.9", view: .fo,
                                       caps: ["part1", "video1"])), from: 2, at: 0)
        XCTAssertEqual(l.receive(.preview(Self.bild(1)), from: 2, at: 0), [])
        // Kvittensen åt andra hållet betyder inget för den styrande.
        XCTAssertEqual(l.receive(.previewAck(n: 1), from: 1, at: 0), [])
    }

    // MARK: Mottrycket

    /// Högst en bild i flykt: kameran ger rutor i 240 bilder/s, men nästa bild tas först när den
    /// förra är kvitterad, och aldrig tätare än takten. METOD MS35
    func testHogstEnIFlykt() {
        var s = ForhandsSandare()
        let hz = Forhandstakt.aktiv
        var t = 10.0
        XCTAssertEqual(s.ta(nu: t, hz: hz), 1)
        XCTAssertEqual(s.iFlykt, 1)
        // Rutor i 240 bilder/s utan kvittens: ingen ny bild.
        var tagna: [Int] = []
        for _ in 0..<200 {
            t += 1 / 240
            if let n = s.ta(nu: t, hz: hz) { tagna.append(n) }
        }
        XCTAssertEqual(tagna, [])
        // En kvittens för en annan bild släpper inte.
        s.kvitterad(7)
        XCTAssertEqual(s.iFlykt, 1)
        // Kvittensen: nästa ruta blir bild 2 (takten har redan gått).
        s.kvitterad(1)
        XCTAssertNil(s.iFlykt)
        t += 1 / 240
        XCTAssertEqual(s.ta(nu: t, hz: hz), 2)
    }

    /// Med kvittens direkt blir det takten, inte kamerans 240 bilder/s.
    func testTaktenMedKvittensDirekt() {
        var s = ForhandsSandare()
        var tagna = 0
        var t = 0.0
        for _ in 0..<(240 * 10) {
            t += 1 / 240
            if let n = s.ta(nu: t, hz: Forhandstakt.aktiv) {
                tagna += 1
                s.kvitterad(n)
            }
        }
        // 12 bilder/s på kamerans rutnät (marginalen tar den 20:e rutan: 12 bilder/s).
        XCTAssertEqual(Double(tagna) / 10, Forhandstakt.aktiv, accuracy: 0.6)
    }

    /// Ett långsamt nät: kvittensen tar 0,25 s. Bilderna glesnar, fördröjningen växer inte.
    func testLangsamtNatGlesarBildernaInteFordrojningen() {
        var s = ForhandsSandare()
        var t = 0.0
        var flykt: (n: Int, svar: Double)?
        var alder: [Double] = []
        for _ in 0..<(240 * 10) {
            t += 1 / 240
            if let f = flykt, t >= f.svar {
                s.kvitterad(f.n)
                alder.append(0.25)
                flykt = nil
            }
            if let n = s.ta(nu: t, hz: Forhandstakt.aktiv) { flykt = (n, t + 0.25) }
        }
        XCTAssertEqual(Double(alder.count), 39.5, accuracy: 1.5)     // cirka 4 bilder/s
        XCTAssertEqual(alder.max(), 0.25)
    }

    /// En kvittens som aldrig kommer (en bild tappad vid ett tapp) släpper efter `kvittensTid`.
    func testKvittensSomAldrigKommer() {
        var s = ForhandsSandare()
        XCTAssertEqual(s.ta(nu: 0, hz: 12), 1)
        XCTAssertNil(s.ta(nu: ForhandsSandare.kvittensTid - 0.01, hz: 12))
        XCTAssertEqual(s.ta(nu: ForhandsSandare.kvittensTid + 0.001, hz: 12), 2)
        // En sen kvittens för bild 1 släpper inte bild 2.
        s.kvitterad(1)
        XCTAssertEqual(s.iFlykt, 2)
        // Nollställd (kopplingen föll): ingen väntar, numren fortsätter.
        s.nollstall()
        XCTAssertNil(s.iFlykt)
        XCTAssertEqual(s.ta(nu: 5, hz: 12), 3)
        s.slapp(3)
        XCTAssertNil(s.iFlykt)
        // Takten noll: ingen bild.
        XCTAssertNil(s.ta(nu: 10, hz: 0))
        XCTAssertNil(s.ta(nu: .nan, hz: 12))
    }

    // MARK: Takten

    func testTakten() {
        XCTAssertEqual(Forhandstakt.hz(kanSkicka: true, inspelar: false, tryck: .nominal), 12)
        // Pausad under inspelningen (den säkra vägen, MS35).
        XCTAssertEqual(Forhandstakt.hz(kanSkicka: true, inspelar: true, tryck: .nominal), 0)
        // Sänkt när telefonen är varm, av från "serious".
        XCTAssertEqual(Forhandstakt.hz(kanSkicka: true, inspelar: false, tryck: .fair), 6)
        XCTAssertEqual(Forhandstakt.hz(kanSkicka: true, inspelar: false, tryck: .serious), 0)
        XCTAssertEqual(Forhandstakt.hz(kanSkicka: true, inspelar: false, tryck: .critical), 0)
        XCTAssertEqual(Forhandstakt.hz(kanSkicka: true, inspelar: true, tryck: .fair), 0)
        // Ingen styrande som tar emot: ingen bild.
        XCTAssertEqual(Forhandstakt.hz(kanSkicka: false, inspelar: false, tryck: .nominal), 0)
    }

    func testStorleken() {
        func s(_ b: Int, _ h: Int) -> [Int] {
            let x = LinkPreview.storlek(bredd: b, hojd: h)
            return [x.w, x.h]
        }
        XCTAssertEqual(s(1080, 1920), [360, 640])
        XCTAssertEqual(s(1920, 1080), [640, 360])
        XCTAssertEqual(s(1440, 1080), [480, 360])
        // Aldrig uppskalad.
        XCTAssertEqual(s(200, 300), [200, 300])
        XCTAssertEqual(s(0, 300), [0, 0])
    }

    // MARK: Den styrandes ruta

    func testRutanFordrojningenOchTakten() {
        var m = ForhandsMottagare()
        XCTAssertFalse(m.visas(nu: 0, kopplad: true, inspelar: false))
        XCTAssertNil(m.fordrojning)
        // Följarens klocka går 3 s före; bilderna kommer 0,1 s efter att de togs, 12 i sekunden.
        let k = ClockOffset(offset: 3, uncertainty: 0.001, samples: 30)
        var nu = 1000.0
        for n in 1...30 {
            nu += 1 / 12
            m.ta(liten(n, t: nu - 0.1 + 3), fran: "B", nu: nu, klocka: k)
        }
        XCTAssertEqual(m.senaste, 30)
        XCTAssertEqual(try XCTUnwrap(m.fordrojning), 0.1, accuracy: 1e-9)
        XCTAssertEqual(m.takt(nu: nu), 12, accuracy: 0.5)
        XCTAssertTrue(m.visas(nu: nu, kopplad: true, inspelar: false))
        // Under inspelningen och utan koppling: ingen ruta.
        XCTAssertFalse(m.visas(nu: nu, kopplad: true, inspelar: true))
        XCTAssertFalse(m.visas(nu: nu, kopplad: false, inspelar: false))
        // Följaren slutade skicka (spelar in, varm): rutan går efter `gammal`.
        XCTAssertTrue(m.visas(nu: nu + ForhandsMottagare.gammal, kopplad: true, inspelar: false))
        XCTAssertFalse(m.visas(nu: nu + ForhandsMottagare.gammal + 0.01, kopplad: true, inspelar: false))
        XCTAssertEqual(m.takt(nu: nu + 3), 0)
        // Utan klocka: ingen ny fördröjning, men bilden räknas.
        m.ta(liten(31, t: .nan), fran: "B", nu: nu + 0.1, klocka: nil)
        XCTAssertEqual(m.senaste, 31)
        // En annan följare börjar om.
        m.ta(liten(1, t: 0), fran: "C", nu: nu + 0.2, klocka: nil)
        XCTAssertEqual(m.enhet, "C")
        XCTAssertNil(m.fordrojning)
        m.nollstall()
        XCTAssertNil(m.senaste)
        XCTAssertFalse(m.visas(nu: nu + 0.2, kopplad: true, inspelar: false))
    }

    func testTextenIKugghjulet() {
        XCTAssertEqual(Texter.inspForhandsbild(sekunder: "0.12", fps: 12), "0.12 s\u{00A0}\u{00B7} 12 fps")
        XCTAssertEqual(Texter.inspForhandsbild(sekunder: nil, fps: 6), "6 fps")
    }

    private func liten(_ n: Int, t: Double) -> LinkPreview { Self.bild(n, t: t, bytes: 10) }
}
