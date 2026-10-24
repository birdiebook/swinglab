import Foundation
import XCTest
import Swing
@testable import Capture

/// S6c-2: följarens slag till den styrande och 3D tillbaka (Overforing.swift, METOD MS19,
/// BESLUT B61). Lederna är PÅHITTADE (CLAUDE.md, Dataregeln).
final class OverforingTests: XCTestCase {
    static let pass = "20261103-180000"

    /// Påhittade leder: 13 leder per ruta, ojämna tider, en saknad led och en med låg konfidens,
    /// avrundade som ledfilen (`JointSeries.rounded`).
    static func leder(rutor: Int = 300, fro: UInt64 = 1, x0: Double = 540) -> JointSeries {
        var g = fro &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        func slump() -> Double {
            g = g &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(g >> 11) / Double(1 << 53)
        }
        var frames: [PoseFrame] = []
        var t = -2.5
        for i in 0..<rutor {
            t += (i % 7 == 3 ? 2 : 1) / 240.0
            let js: [PoseJoint?] = (0..<13).map { m in
                if m == 4 && i % 5 == 0 { return nil }
                return PoseJoint(x: x0 + 300 * slump() + Double(m), y: 400 + 1200 * slump(), c: m == 9 ? 0.0002 : 0.2 + 0.8 * slump())
            }
            frames.append(PoseFrame(t: t, pts: 10 + t, joints: js, confidence: 0.9))
        }
        return JointSeries(width: 1080, height: 1920, frames: frames).rounded()
    }

    // MARK: Lederna

    func testKompaktaLedernaGerLedfilensTal() throws {
        let s = Self.leder()
        let k = try KompaktaLeder(s)
        XCTAssertEqual(k.enc, "i16")
        let u = try k.series()
        XCTAssertEqual(u.width, 1080)
        XCTAssertEqual(u.height, 1920)
        XCTAssertEqual(u.frames.count, s.frames.count)
        for (a, b) in zip(s.frames, u.frames) {
            XCTAssertEqual(a.t, b.t)                                  // exakt: n · steg
            for m in 0..<13 {
                if let ja = a.joints[m], (ja.c / KompaktaLeder.konfSteg).rounded() >= 1 {
                    let jb = try XCTUnwrap(b.joints[m])
                    XCTAssertEqual(ja.x, jb.x)
                    XCTAssertEqual(ja.y, jb.y)
                    XCTAssertEqual(ja.c, jb.c)
                } else {
                    XCTAssertNil(b.joints[m])                         // saknad, eller konfidensen 0
                }
            }
        }
        // Tur och retur igen ger samma byte.
        XCTAssertEqual(try KompaktaLeder(u), k)
    }

    func testStoraKoordinaterGarSomInt32() throws {
        let s = Self.leder(rutor: 20, x0: 3500)                       // 4K-bild: över int16 i 0,1 px
        let k = try KompaktaLeder(s)
        XCTAssertEqual(k.enc, "i32")
        let u = try k.series()
        XCTAssertEqual(u.frames[3].joints[0]?.x, s.frames[3].joints[0]?.x)
    }

    func testTrasigaLederGerFelUtanVarden() {
        var k = try! KompaktaLeder(Self.leder(rutor: 10))
        k.j = String(k.j.dropLast(8))
        XCTAssertThrowsError(try k.series()) { e in
            XCTAssertEqual((e as? OverforingFel)?.skal, "t och j har inte samma antal rutor")
        }
        k.t = "inte base64!"
        XCTAssertThrowsError(try k.series())
    }

    func testStorlekenPerSlag() throws {
        // 960 rutor (det täta fönstret, 4 s i 240 Hz): 4 + 13 · 6 byte per ruta, base64 4/3.
        let k = try KompaktaLeder(Self.leder(rutor: 960))
        let byte = k.t.count + k.j.count
        XCTAssertEqual(byte, (960 * 4 + 2) / 3 * 4 + (960 * 78 + 2) / 3 * 4)
        print("OVERFORING: ett slag om 960 rutor \(byte) byte i bunten")
    }

    // MARK: Bunten

    static func manifest(vy: Vy = .fo, slag: [String] = ["s01", "s02"]) -> Data {
        let s = slag.map { #"{"id": "\#($0)", "serie": 1, "klick_s": 2.5, "dom": "sving", "leder": "slag/\#($0).json"}"# }
        return Data(#"{"format": "swinglab-paket/1", "pass": "\#(pass)", "vy": "\#(vy.rawValue)", "spelhand": "hoger", "serier": [{"nr": 1}], "slag": [\#(s.joined(separator: ", "))]}"#.utf8)
    }

    func testBuntenTurOchRetur() throws {
        let leder = ["s01": Self.leder(fro: 1), "s02": Self.leder(fro: 2)]
        let b = try SlagBunt.make(manifest: Self.manifest(), enhet: Data(#"{"modell": "x"}"#.utf8), par: nil, leder: leder)
        XCTAssertEqual(b.pass, Self.pass)
        XCTAssertEqual(b.vy, .fo)
        XCTAssertEqual(b.manifestData, Self.manifest())
        XCTAssertNil(b.parData)
        let d = try b.data()
        XCTAssertEqual(try b.data(), d)                               // samma bunt, samma byte
        let l = try SlagBunt.las(d)
        XCTAssertEqual(l, b)
        XCTAssertEqual(try l.lederna()["s02"]?.frames.map(\.t), leder["s02"]?.frames.map(\.t))
        print("OVERFORING: bunt med två slag om 300 rutor \(d.count) byte, summa \(Overforing.summa(d))")
        XCTAssertThrowsError(try SlagBunt.las(Data("{}".utf8)))
        var fel = b
        fel.format = "swinglab-slag/9"
        XCTAssertThrowsError(try SlagBunt.las(try fel.data())) { e in
            XCTAssertEqual((e as? OverforingFel)?.skal, "annan_telefon.json: format ska vara swinglab-slag/1")
        }
        XCTAssertThrowsError(try SlagBunt.make(manifest: Data("[]".utf8), enhet: nil, par: nil, leder: [:]))
    }

    func testBuntenUrDenAndraTelefonensZip() throws {
        let mapp = FileManager.default.temporaryDirectory.appendingPathComponent("overforing-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: mapp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: mapp) }
        let leder = ["s01": Self.leder(fro: 1), "s02": Self.leder(fro: 2)]
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        let url = mapp.appendingPathComponent("swinglab-\(Self.pass)-fo.zip")
        let z = try ZipWriter(url: url)
        try z.add(name: "manifest.json", data: Self.manifest())
        try z.add(name: "enhet.json", data: Data(#"{"modell": "x"}"#.utf8))
        try z.add(name: "slag/s01.json", data: try e.encode(leder["s01"]!))
        try z.add(name: "klipp/s01.mov", data: Data(repeating: 7, count: 5000))
        try z.add(name: "slag/s02.json", data: try e.encode(leder["s02"]!))
        try z.finish()
        let b = try SlagBunt.ur(zip: url)
        XCTAssertEqual(b, try SlagBunt.make(manifest: Self.manifest(), enhet: Data(#"{"modell": "x"}"#.utf8), par: nil,
                                            leder: leder))
        XCTAssertEqual(try ZipLasare(url: url).namn.count, 5)

        // En ledfil som saknas, och en fil som inte är en zip.
        let url2 = mapp.appendingPathComponent("b.zip")
        let z2 = try ZipWriter(url: url2)
        try z2.add(name: "manifest.json", data: Self.manifest())
        try z2.add(name: "slag/s01.json", data: try e.encode(leder["s01"]!))
        try z2.finish()
        XCTAssertThrowsError(try SlagBunt.ur(zip: url2)) { e in
            XCTAssertEqual((e as? OverforingFel)?.skal, "slag/s02.json saknas")
        }
        let url3 = mapp.appendingPathComponent("c.zip")
        try Data("inte en zip".utf8).write(to: url3)
        XCTAssertThrowsError(try SlagBunt.ur(zip: url3))
    }

    // MARK: Bitarna

    static func innehall(_ n: Int) -> Data {
        Data((0..<n).map { UInt8(truncatingIfNeeded: $0 &* 2_654_435_761 >> 7) })
    }

    func testBitarnaKommerFramIOrdningOchUtan() {
        let d = Self.innehall(3 * Overforing.delBytes + 1000)
        var s = PartSender()
        let delar = s.enqueue(kind: Overforing.slag, pass: Self.pass, data: d)
        XCTAssertEqual(delar.count, 4)
        XCTAssertEqual(Set(delar.map(\.id)), [Overforing.summa(d)])
        var r = PartReceiver()
        var hel: Data?
        // Baklänges och en bit två gånger.
        for p in [delar[3], delar[1], delar[1], delar[0], delar[2]] {
            switch r.receive(p) {
            case let .kvittera(a):
                XCTAssertEqual(a.map(\.index), [p.index])
                for k in a { _ = s.receive(k) }
            case let .hel(kind, pass, id, data, a):
                XCTAssertEqual(kind, Overforing.slag)
                XCTAssertEqual(pass, Self.pass)
                XCTAssertEqual(a.map(\.index), [p.index])
                hel = data
                for k in a { _ = s.receive(k) }
                // Alla bitar kvitterade men inte helheten: den sista skickas igen vid ett tapp.
                XCTAssertEqual(s.unacked().map(\.index), [3])
                let klar = r.klar(kind: kind, pass: pass, id: id)
                XCTAssertTrue(s.receive(klar).done)
            }
        }
        XCTAssertEqual(hel, d)
        XCTAssertEqual(s.count, 0)
        XCTAssertEqual(s.unacked(), [])
        // En bit som kommer igen efter helheten får helhetens kvittens igen.
        if case let .kvittera(a) = r.receive(delar[2]) {
            XCTAssertEqual(a.map(\.index), [2, nil])
        } else {
            XCTFail("biten togs emot på nytt")
        }
    }

    func testFelSummaSkickarAlltIgen() {
        let d = Self.innehall(Overforing.delBytes + 10)
        var s = PartSender()
        var delar = s.enqueue(kind: Overforing.treD, pass: Self.pass, data: d)
        // En bit med fel innehåll men rätt storlek.
        var b = [UInt8](Data(base64Encoded: delar[1].data)!)
        b[0] ^= 0xFF
        delar[1].data = Data(b).base64EncodedString()
        var r = PartReceiver()
        _ = r.receive(delar[0])
        guard case let .kvittera(a) = r.receive(delar[1]) else { return XCTFail("fel summa togs emot") }
        XCTAssertEqual(a.last?.index, nil)
        XCTAssertEqual(a.last?.ok, false)
        let igen = s.receive(a.last!)
        XCTAssertFalse(igen.done)
        XCTAssertEqual(igen.resend.count, 2)
    }

    func testBitarSomInteGarAttLasaKvitterasInte() {
        let d = Self.innehall(100)
        var p = Overforing.dela(kind: Overforing.slag, pass: Self.pass, data: d)[0]
        var r = PartReceiver()
        var v = p
        v.v = 2                                                     // en senare version
        XCTAssertEqual(r.receive(v), .kvittera([]))
        v = p
        v.count = 3                                                 // fel antal för storleken
        XCTAssertEqual(r.receive(v), .kvittera([]))
        p.data = "!!"
        XCTAssertEqual(r.receive(p), .kvittera([]))
    }

    func testEnBitRymsIRamen() throws {
        let d = Self.innehall(Overforing.delBytes)
        let p = Overforing.dela(kind: Overforing.slag, pass: Self.pass, data: d)[0]
        let ram = try Wire.frame(.part(p))
        XCTAssertLessThan(ram.count, Wire.maxLength)
        var r = Wire.Reader()
        XCTAssertEqual(try r.feed(ram), [.part(p)])
        let a = LinkPartAck(kind: Overforing.slag, pass: Self.pass, id: p.id, index: nil, ok: true)
        var r2 = Wire.Reader()
        XCTAssertEqual(try r2.feed(try Wire.frame(.partAck(a))), [.partAck(a)])
        let json = String(decoding: try Wire.frame(.partAck(a)).dropFirst(4), as: UTF8.self)
        XCTAssertTrue(json.contains(#""type":"part_ack""#), json)
    }

    // MARK: Telefonerna

    /// Följaren skickar sina slag under ett tapp, den styrande tar emot dem när kopplingen
    /// kommer tillbaka, och 3D går tillbaka till följaren, även till en som ansluter senare.
    func testSlagenOchTreDMellanTelefonerna() {
        let lead = LinkHello(role: .lead, device: "A", model: "iPhone18,3", app: "0.1.0", view: .dtl)
        let follow = LinkHello(role: .follow, device: "B", model: "iPhone14,5", app: "0.1.0", view: .fo)
        var f = LinkFollower(hello: follow)
        var l = LinkLeader(hello: lead, passID: Self.pass)
        let slag = Self.innehall(2 * Overforing.delBytes + 77)

        // Tappad koppling: inget skickas, och biten väntar.
        XCTAssertEqual(f.send(kind: Overforing.slag, pass: Self.pass, data: slag), [])
        XCTAssertEqual(f.parts.count, 1)

        // Kopplingen uppe: hello och alla bitar; den styrande tar emot dem.
        var tillLedare: [LinkMessage] = f.connected().compactMap { if case let .send(m) = $0 { return m } else { return nil } }
        XCTAssertEqual(tillLedare.count, 1 + 3)
        _ = l.connected(peer: 1)
        var mottaget: Data?
        var tillFoljare: [LinkMessage] = []
        // Tappet: den sista bitens svar når inte fram.
        for (i, m) in tillLedare.enumerated() {
            for a in l.receive(m, from: 1, at: 0) {
                switch a {
                case let .received(dev, kind, pass, data):
                    XCTAssertEqual(dev, "B")
                    XCTAssertEqual(kind, Overforing.slag)
                    XCTAssertEqual(pass, Self.pass)
                    mottaget = data
                case let .send(_, m) where i < tillLedare.count - 1:
                    tillFoljare.append(m)
                default:
                    break
                }
            }
        }
        XCTAssertEqual(mottaget, slag)
        for m in tillFoljare { _ = f.receive(m, at: 0, now: { 0 }) }
        XCTAssertEqual(f.parts.count, 1, "helheten är inte kvitterad")

        // Tillbaka: den sista biten igen, och den styrande svarar med helhetens kvittens.
        f.disconnected()
        tillLedare = f.connected().compactMap { if case let .send(m) = $0 { return m } else { return nil } }
        XCTAssertEqual(tillLedare.count, 2)
        l.disconnected(peer: 1)
        _ = l.connected(peer: 2)
        var levererat = false
        for m in tillLedare {
            for a in l.receive(m, from: 2, at: 0) {
                if case .received = a { XCTFail("togs emot två gånger") }
                if case let .send(_, svar) = a {
                    for b in f.receive(svar, at: 0, now: { 0 }) {
                        if case .delivered(Overforing.slag, Self.pass, _) = b { levererat = true }
                    }
                }
            }
        }
        XCTAssertTrue(levererat)
        XCTAssertEqual(f.parts.count, 0)

        // 3D tillbaka till följaren.
        let tred = Self.innehall(5000)
        var tillF: [LinkMessage] = l.sendToFollowers(kind: Overforing.treD, pass: Self.pass, data: tred)
            .compactMap { if case let .send(2, m) = $0 { return m } else { return nil } }
        XCTAssertEqual(tillF.count, 1)
        var fick: Data?
        var svar: [LinkMessage] = []
        for m in tillF {
            for a in f.receive(m, at: 0, now: { 0 }) {
                if case let .received(kind, _, data) = a, kind == Overforing.treD { fick = data }
                if case let .send(s) = a { svar.append(s) }
            }
        }
        XCTAssertEqual(fick, tred)
        for s in svar { _ = l.receive(s, from: 2, at: 0) }
        XCTAssertEqual(l.unsentParts, 0)

        // En ny följare som ansluter efteråt får 3D vid sitt hello.
        let ny = LinkHello(role: .follow, device: "C", model: "iPhone14,5", app: "0.1.0", view: .fo)
        _ = l.connected(peer: 3)
        tillF = l.receive(.hello(ny), from: 3, at: 0).compactMap { if case let .send(3, m) = $0 { return m } else { return nil } }
        XCTAssertTrue(tillF.contains { if case .part = $0 { return true } else { return false } })
        // Och följaren B, som redan kvitterat, får den inte igen.
        _ = l.connected(peer: 4)
        tillF = l.receive(.hello(follow), from: 4, at: 0).compactMap { if case let .send(4, m) = $0 { return m } else { return nil } }
        XCTAssertFalse(tillF.contains { if case .part = $0 { return true } else { return false } })
    }

    /// En överföring för ett annat pass tas inte emot av den styrande.
    func testAnnatPassTasInteEmot() {
        let follow = LinkHello(role: .follow, device: "B", model: "iPhone14,5", app: "0.1.0", view: .fo)
        var l = LinkLeader(hello: LinkHello(role: .lead, device: "A", model: "m", app: "1", view: .dtl), passID: Self.pass)
        _ = l.receive(.hello(follow), from: 1, at: 0)
        let p = Overforing.dela(kind: Overforing.slag, pass: "20261103-190000", data: Self.innehall(10))[0]
        XCTAssertEqual(l.receive(.part(p), from: 1, at: 0), [])
    }
}
