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
        Data((0..<n).map { UInt8(truncatingIfNeeded: ($0 &* 2_654_435_761) >> 7) })
    }

    func testBitarnaKommerFramOchDubbletterSlangs() {
        let d = Self.innehall(3 * Overforing.delBytes + 1000)
        var s = PartSender()
        let delar = s.enqueue(Overforing.dela(kind: Overforing.slag, pass: Self.pass, data: d))
        XCTAssertEqual(delar.count, 4)
        XCTAssertEqual(Set(delar.map(\.id)), [Overforing.summa(d)])
        var r = PartReceiver(tillatna: [Overforing.slag])
        var hel: Data?
        for p in [delar[0], delar[2], delar[1], delar[1], delar[3]] {
            switch r.receive(p) {
            case let .kvittera(a):
                XCTAssertEqual(a.map(\.index), [p.index])
                for k in a { XCTAssertEqual(s.receive(k), .inget) }
            case let .hel(kind, pass, id, bytes, bitar, a):
                XCTAssertEqual(kind, Overforing.slag)
                XCTAssertEqual(a.map(\.index), [p.index])
                hel = Overforing.foga(id: id, bytes: bytes, delar: bitar)
                for k in a { _ = s.receive(k) }
                XCTAssertEqual(s.unacked(), [])
                XCTAssertEqual(s.count, 1, "helheten är inte kvitterad")
                let klar = r.svara(kind: kind, pass: pass, id: id, .sparad)!
                XCTAssertEqual(s.receive(klar), .klar(kind: kind, pass: pass, id: id))
            }
        }
        XCTAssertEqual(hel, d)
        XCTAssertEqual(s.count, 0)
        // En bit som kommer igen efter helheten får helhetens kvittens igen.
        guard case let .kvittera(a) = r.receive(delar[2]) else { return XCTFail("biten togs emot på nytt") }
        XCTAssertEqual(a.map(\.index), [2, nil])
        XCTAssertEqual(a.last?.ok, true)
    }

    /// Mottagaren startas om mitt i: avsändaren skickar allt igen vid nästa hello (`alla`), och en
    /// bit för en överföring som mottagaren inte känner ger "börja om".
    func testOmstartMittIOchOkandOverforing() {
        let d = Self.innehall(2 * Overforing.delBytes + 5)
        var s = PartSender()
        let delar = s.enqueue(kind: Overforing.slag, pass: Self.pass, data: d)
        var r = PartReceiver(tillatna: [Overforing.slag])
        for p in delar.prefix(2) {
            guard case let .kvittera(a) = r.receive(p) else { return XCTFail() }
            for k in a { _ = s.receive(k) }
        }
        XCTAssertEqual(s.unacked().map(\.index), [2])
        // Omstart: en ny mottagare. Den sista biten ensam ger "börja om".
        r = PartReceiver(tillatna: [Overforing.slag])
        guard case let .kvittera(a) = r.receive(delar[2]) else { return XCTFail() }
        XCTAssertEqual(a, [LinkPartAck(kind: Overforing.slag, pass: Self.pass, id: delar[0].id, index: nil, ok: false)])
        XCTAssertEqual(s.receive(a[0]), .igen(delar))
        // Och allt vid nästa hello.
        let igen = s.alla()
        XCTAssertEqual(igen, delar)
        var fick: Data?
        for p in igen {
            if case let .hel(_, _, id, bytes, bitar, _) = r.receive(p) { fick = Overforing.foga(id: id, bytes: bytes, delar: bitar) }
        }
        XCTAssertEqual(fick, d)
    }

    func testFelSummaSkickarAlltIgen() {
        let d = Self.innehall(Overforing.delBytes + 10)
        var s = PartSender()
        var delar = s.enqueue(kind: Overforing.treD, pass: Self.pass, data: d)
        var b = [UInt8](Data(base64Encoded: delar[1].data)!)
        b[0] ^= 0xFF
        delar[1].data = Data(b).base64EncodedString()
        var r = PartReceiver(tillatna: [Overforing.treD])
        _ = r.receive(delar[0])
        guard case let .hel(kind, pass, id, bytes, bitar, _) = r.receive(delar[1]) else { return XCTFail("inte hel") }
        XCTAssertNil(Overforing.foga(id: id, bytes: bytes, delar: bitar))
        let a = r.svara(kind: kind, pass: pass, id: id, .felSumma)!
        XCTAssertEqual(a.ok, false)
        XCTAssertNil(a.fel)
        XCTAssertEqual(s.receive(a), .igen(s.pagaende[Overforing.treD]!.delar))
    }

    /// Granskningen: count 2 index 0, sedan count 6 index 5 för samma id. Förut kraschade
    /// ihopfogningen; nu börjar den senare biten en ny överföring, och den börjar inte med 0.
    func testFelaktigaBitarKrascharInte() {
        var r = PartReceiver(tillatna: [Overforing.slag])
        let a = LinkPart(kind: Overforing.slag, pass: Self.pass, id: "x-1", index: 0, count: 2,
                         bytes: Overforing.delBytes + 1, data: Data([1]).base64EncodedString())
        XCTAssertEqual(r.receive(a), .kvittera([LinkPartAck(kind: Overforing.slag, pass: Self.pass, id: "x-1", index: 0, ok: true)]))
        let b = LinkPart(kind: Overforing.slag, pass: Self.pass, id: "x-1", index: 5, count: 6,
                         bytes: 5 * Overforing.delBytes + 1, data: Data([2]).base64EncodedString())
        XCTAssertEqual(r.receive(b), .kvittera([LinkPartAck(kind: Overforing.slag, pass: Self.pass, id: "x-1", index: nil, ok: false)]))
        // Fel storlek mot antalet, ett negativt index och för stora: läses inte.
        var c = a
        c.count = 3
        XCTAssertEqual(r.receive(c), .kvittera([]))
        c = a
        c.index = -1
        XCTAssertEqual(r.receive(c), .kvittera([]))
        c = a
        c.bytes = SlagBunt.maxBytes + 1
        c.count = Overforing.antal(c.bytes)
        XCTAssertEqual(r.receive(c), .kvittera([]))
        // En bit med fel storlek fogas inte ihop.
        let d = Self.innehall(Overforing.delBytes + 1)
        let delar = Overforing.dela(kind: Overforing.slag, pass: Self.pass, data: d)
        XCTAssertNil(Overforing.foga(id: delar[0].id, bytes: d.count, delar: [delar[0].data, delar[0].data]))
        XCTAssertNil(Overforing.foga(id: delar[0].id, bytes: d.count, delar: [delar[0].data]))
        XCTAssertEqual(Overforing.foga(id: delar[0].id, bytes: d.count, delar: delar.map(\.data)), d)
    }

    func testNejOchSkalen() {
        var r = PartReceiver(tillatna: [Overforing.slag])
        let p = Overforing.dela(kind: Overforing.slag, pass: Self.pass, data: Self.innehall(100))[0]
        var v = p
        v.v = 2
        XCTAssertEqual(r.receive(v), .kvittera([LinkPartAck(kind: p.kind, pass: p.pass, id: p.id, index: nil, ok: false,
                                                            fel: Overforing.felVersion)]))
        var k = p
        k.kind = Overforing.treD                                    // den styrande tar bara slagen
        XCTAssertEqual(r.receive(k), .kvittera([LinkPartAck(kind: k.kind, pass: p.pass, id: p.id, index: nil, ok: false,
                                                            fel: Overforing.felFormat)]))
        // Ett nej från appen gäller också en bit som kommer igen.
        guard case let .hel(kind, pass, id, _, _, _) = r.receive(p) else { return XCTFail() }
        let nej = r.svara(kind: kind, pass: pass, id: id, .nej(Overforing.felFormat))
        XCTAssertEqual(nej?.fel, Overforing.felFormat)
        guard case let .kvittera(a) = r.receive(p) else { return XCTFail() }
        XCTAssertEqual(a.last?.fel, Overforing.felFormat)
        var s = PartSender()
        _ = s.enqueue([p])
        XCTAssertEqual(s.receive(nej!), .nekad(kind: kind, pass: pass, fel: Overforing.felFormat))
        XCTAssertEqual(s.count, 0, "efter ett nej skickas inget mer")
        // Osparad: ingen kvittens, och biten tas emot igen.
        var r2 = PartReceiver(tillatna: [Overforing.slag])
        guard case .hel = r2.receive(p) else { return XCTFail() }
        XCTAssertNil(r2.svara(kind: p.kind, pass: p.pass, id: p.id, .osparad))
        guard case .hel = r2.receive(p) else { return XCTFail("osparad togs inte emot igen") }
    }

    func testEnBitRymsIRamenOchOkandTypHoppasOver() throws {
        let d = Self.innehall(Overforing.delBytes)
        let p = Overforing.dela(kind: Overforing.slag, pass: Self.pass, data: d)[0]
        let ram = try Wire.frame(.part(p))
        XCTAssertLessThan(ram.count, Wire.maxLength)
        XCTAssertLessThan(ram.count, 270_000)
        let a = LinkPartAck(kind: Overforing.slag, pass: Self.pass, id: p.id, index: nil, ok: false, fel: "pass")
        // En okänd typ (en senare app) mellan två kända: hoppas över, förbindelsen lever.
        let okand = Data(#"{"type":"framtid","x":[1,2]}"#.utf8)
        var strom = ram
        strom.append(Data([0, 0, 0, UInt8(okand.count)]) + okand)
        strom.append(try Wire.frame(.partAck(a)))
        var r = Wire.Reader()
        XCTAssertEqual(try r.feed(strom), [.part(p), .partAck(a)])
        XCTAssertEqual(r.skipped, 1)
        let json = String(decoding: try Wire.frame(.partAck(a)).dropFirst(4), as: UTF8.self)
        XCTAssertTrue(json.contains(#""type":"part_ack""#), json)
        // Ett hello från en senare app med okända nycklar läses, och ett från en äldre utan syfte och
        // förmågor räknas som inspelning utan bitar.
        let nytt = Data(#"{"type":"hello","hello":{"role":"folj","device":"B","model":"m","app":"9","view":"fo","mode":"pass","caps":["part1","part2"],"ny":1}}"#.utf8)
        let gammalt = Data(#"{"type":"hello","hello":{"role":"folj","device":"B","model":"m","app":"0.1","view":"fo"}}"#.utf8)
        guard case let .hello(h1) = try JSONDecoder().decode(LinkMessage.self, from: nytt),
              case let .hello(h2) = try JSONDecoder().decode(LinkMessage.self, from: gammalt) else { return XCTFail() }
        XCTAssertEqual(h1.syfte, .pass)
        XCTAssertTrue(h1.kanDelar)
        XCTAssertEqual(h2.syfte, .record)
        XCTAssertFalse(h2.kanDelar)
    }

    // MARK: Telefonerna

    static let ledare = LinkHello(role: .lead, device: "A", model: "iPhone18,3", app: "0.1.0", view: .dtl, mode: .pass)
    static let foljare = LinkHello(role: .follow, device: "B", model: "iPhone14,5", app: "0.1.0", view: .fo, mode: .pass)

    /// Nätet i minnet: meddelandena går genom Wire, och appens svar på en hel överföring
    /// (`svar`) körs som PhoneLink gör det.
    final class Nat {
        var f: LinkFollower
        var l: LinkLeader
        var peer = 1
        var uppe = false
        var tillLedare = Wire.Reader()
        var tillFoljare = Wire.Reader()
        var ledarensSvar: Mottagning = .sparad
        var foljarensSvar: Mottagning = .sparad
        var ledarenFick: [Data] = []
        var foljarenFick: [Data] = []
        var levererat: [String] = []
        var nekat: [String] = []
        var stangt: [Int] = []
        /// Släpp den här bitens svar (ett tapp precis efter).
        var tappaEfter: ((LinkMessage) -> Bool)?

        init(f: LinkFollower = LinkFollower(hello: OverforingTests.foljare),
             l: LinkLeader = LinkLeader(hello: OverforingTests.ledare, passID: OverforingTests.pass)) {
            self.f = f
            self.l = l
        }

        func anslut() {
            uppe = true
            peer += 1
            tillLedare = Wire.Reader()
            tillFoljare = Wire.Reader()
            // Följarens hello går först (det skickas när förbindelsen är uppe), sedan den styrandes.
            foljare(f.connected())
            ledare(l.connected(peer: peer))
        }

        func tapp() {
            uppe = false
            l.disconnected(peer: peer)
            f.disconnected()
        }

        func ledare(_ a: [LinkLeader.Action]) {
            for x in a {
                switch x {
                case let .send(p, m):
                    guard uppe, p == peer else { continue }
                    for m in try! tillFoljare.feed(try! Wire.frame(m)) { foljare(f.receive(m, at: 0, now: { 0 })) }
                case let .received(dev, kind, pass, id, bytes, delar):
                    let d = Overforing.foga(id: id, bytes: bytes, delar: delar)
                    if let d, ledarensSvar == .sparad { ledarenFick.append(d) }
                    ledare(l.svara(device: dev, kind: kind, pass: pass, id: id, d == nil ? .felSumma : ledarensSvar))
                case let .close(p): stangt.append(p)
                case .paired, .store, .stream, .streamRefused: break
                }
            }
        }

        func foljare(_ a: [LinkFollower.Action]) {
            for x in a {
                switch x {
                case let .send(m):
                    guard uppe else { continue }
                    let tappa = tappaEfter?(m) == true
                    for m in try! tillLedare.feed(try! Wire.frame(m)) {
                        let svar = l.receive(m, from: peer, at: 0)
                        if tappa {
                            tappaEfter = nil
                            tapp()
                            continue
                        }
                        ledare(svar)
                    }
                case let .received(kind, pass, id, bytes, delar):
                    let d = Overforing.foga(id: id, bytes: bytes, delar: delar)
                    if let d, foljarensSvar == .sparad { foljarenFick.append(d) }
                    foljare(f.svara(kind: kind, pass: pass, id: id, d == nil ? .felSumma : foljarensSvar))
                case let .delivered(kind, _, _): levererat.append(kind)
                case let .refused(_, _, fel): nekat.append(fel)
                case .startRecording, .stopRecording, .streamAck: break
                }
            }
        }
    }

    /// Följaren skickar sina slag under ett tapp, ett tapp mitt i, och den styrande tar emot dem
    /// när kopplingen kommer tillbaka; 3D går tillbaka till följaren, även till en som ansluter senare.
    func testSlagenOchTreDMellanTelefonerna() {
        let n = Nat()
        let slag = Self.innehall(3 * Overforing.delBytes + 77)
        let delar = Overforing.dela(kind: Overforing.slag, pass: Self.pass, data: slag)
        n.foljare(n.f.send(delar))                                   // nere: väntar
        XCTAssertEqual(n.f.parts.count, 1)
        // Uppe, men tappet efter andra biten.
        var bitar = 0
        n.tappaEfter = { m in
            if case .part = m { bitar += 1 }
            return bitar == 2
        }
        n.anslut()
        XCTAssertFalse(n.uppe)
        XCTAssertEqual(n.ledarenFick, [])
        // Tillbaka: allt igen, och den styrande fogar ihop.
        n.anslut()
        XCTAssertEqual(n.ledarenFick, [slag])
        XCTAssertEqual(n.levererat, [Overforing.slag])
        XCTAssertEqual(n.f.parts.count, 0)

        // 3D tillbaka.
        let tred = Self.innehall(5000)
        n.ledare(n.l.sendToFollowers(Overforing.dela(kind: Overforing.treD, pass: Self.pass, data: tred)))
        XCTAssertEqual(n.foljarenFick, [tred])
        XCTAssertEqual(n.l.unsentParts, 0)
        // Samma följare igen (nytt hello): får den inte igen.
        n.tapp()
        n.anslut()
        XCTAssertEqual(n.foljarenFick, [tred])
        // En ny följare som ansluter efteråt får 3D vid sitt hello.
        let ny = LinkHello(role: .follow, device: "C", model: "m", app: "1", view: .fo, mode: .pass)
        let svar = n.l.receive(.hello(ny), from: 99, at: 0)
        XCTAssertTrue(svar.contains { if case .send(99, .part) = $0 { return true } else { return false } })
    }

    /// Den styrande startas om mitt i (en ny LinkLeader): följaren skickar allt igen vid dess hello.
    func testDenStyrandeStartasOmMittI() {
        let n = Nat()
        let slag = Self.innehall(2 * Overforing.delBytes + 1)
        var bitar = 0
        n.tappaEfter = { m in
            if case .part = m { bitar += 1 }
            return bitar == 2
        }
        n.anslut()
        n.foljare(n.f.send(Overforing.dela(kind: Overforing.slag, pass: Self.pass, data: slag)))
        XCTAssertFalse(n.uppe)
        n.l = LinkLeader(hello: Self.ledare, passID: Self.pass)
        n.anslut()
        XCTAssertEqual(n.ledarenFick, [slag])
        XCTAssertEqual(n.levererat, [Overforing.slag])
    }

    /// Sparningen misslyckas hos den styrande: ingen kvittens, och allt kommer igen när
    /// kopplingen kommer tillbaka (`osparad`).
    func testOsparadKommerIgen() {
        let n = Nat()
        n.ledarensSvar = .osparad
        n.anslut()
        let slag = Self.innehall(1000)
        n.foljare(n.f.send(Overforing.dela(kind: Overforing.slag, pass: Self.pass, data: slag)))
        XCTAssertEqual(n.levererat, [])
        XCTAssertEqual(n.f.parts.count, 1)
        n.ledarensSvar = .sparad
        n.tapp()
        n.anslut()
        XCTAssertEqual(n.ledarenFick, [slag])
        XCTAssertEqual(n.levererat, [Overforing.slag])
    }

    /// Ett annat pass hos den styrande: nej med skälet, och följaren slutar skicka.
    func testAnnatPassFarNej() {
        let n = Nat(l: LinkLeader(hello: Self.ledare, passID: "20261103-190000"))
        n.anslut()
        n.foljare(n.f.send(Overforing.dela(kind: Overforing.slag, pass: Self.pass, data: Self.innehall(10))))
        XCTAssertEqual(n.nekat, [Overforing.felPass])
        XCTAssertEqual(n.f.parts.count, 0)
        n.tapp()
        n.anslut()
        XCTAssertEqual(n.ledarenFick, [])
        XCTAssertEqual(n.nekat, [Overforing.felPass], "inget skickades igen efter nejet")
    }

    /// Syftet: passets 3D kopplar inte till inspelningen, och en annan telefon än passets partner
    /// kopplas bort (BESLUT B61).
    func testSyftetOchPartnern() {
        var l = LinkLeader(hello: LinkHello(role: .lead, device: "A", model: "m", app: "1", view: .dtl, mode: .record))
        XCTAssertEqual(l.receive(.hello(Self.foljare), from: 1, at: 0), [.close(peer: 1)])
        XCTAssertTrue(l.followers.isEmpty)
        var f = LinkFollower(hello: Self.foljare)
        _ = f.receive(.hello(LinkHello(role: .lead, device: "A", model: "m", app: "1", view: .dtl, mode: .record)),
                      at: 0, now: { 0 })
        XCTAssertNil(f.lead)
        var p = LinkLeader(hello: Self.ledare, passID: Self.pass)
        p.partner = "Z"
        XCTAssertEqual(p.receive(.hello(Self.foljare), from: 1, at: 0), [.close(peer: 1)])
        p.partner = "B"
        XCTAssertNotEqual(p.receive(.hello(Self.foljare), from: 2, at: 0), [.close(peer: 2)])
        XCTAssertEqual(p.followers.count, 1)
    }

    /// Förmågorna: en äldre app utan "part1" får inga bitar, åt något håll.
    func testUtanFormaganSkickasInget() {
        let gammal = LinkHello(role: .lead, device: "A", model: "m", app: "0.1", view: .dtl, mode: .pass, caps: nil)
        var f = LinkFollower(hello: Self.foljare)
        _ = f.connected()
        _ = f.receive(.hello(gammal), at: 0, now: { 0 })
        XCTAssertEqual(f.send(Overforing.dela(kind: Overforing.slag, pass: Self.pass, data: Self.innehall(10))), [])
        XCTAssertEqual(f.parts.count, 1)
        var l = LinkLeader(hello: Self.ledare, passID: Self.pass)
        _ = l.receive(.hello(LinkHello(role: .follow, device: "B", model: "m", app: "0.1", view: .fo, mode: .pass, caps: nil)),
                      from: 1, at: 0)
        XCTAssertEqual(l.sendToFollowers(Overforing.dela(kind: Overforing.treD, pass: Self.pass, data: Self.innehall(10))), [])
    }

    /// Minnet: högst `maxMottagare` följare tas emot samtidigt.
    func testHogstFyraMottagare() {
        var l = LinkLeader(hello: Self.ledare, passID: Self.pass)
        let d = Overforing.dela(kind: Overforing.slag, pass: Self.pass, data: Self.innehall(2 * Overforing.delBytes))
        for i in 0..<5 {
            _ = l.receive(.hello(LinkHello(role: .follow, device: "F\(i)", model: "m", app: "1", view: .fo, mode: .pass)),
                          from: 10 + i, at: 0)
            let svar = l.receive(.part(d[0]), from: 10 + i, at: 0)
            XCTAssertEqual(svar.isEmpty, i == LinkLeader.maxMottagare, "följare \(i)")
        }
    }
}
