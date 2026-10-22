import Foundation
import XCTest
import Swing
@testable import Capture

/// Två telefoner (S2_SPEC §7, S2g): meddelandena på tråden och vad telefonerna säger
/// till varandra, med ett nät i minnet som går att dra ur. Påhittade klick och ping.
/// METOD MS6, MS9, MS10, BESLUT B21, B22
final class LinkTests: XCTestCase {

    static let lead = LinkHello(role: .lead, device: "A", model: "iPhone18,3", app: "0.1.0", view: .dtl)
    static let follow = LinkHello(role: .follow, device: "B", model: "iPhone14,5", app: "0.1.0", view: .fo)
    static let serie = LinkSeries(series: 2, localSeries: 1, passID: "20261022-101500", startHost: 81234.512345,
                                  frameRate: 240, clicks: [Click(time: 1.25, strength: 31.5), Click(time: 4.5, strength: 9)],
                                  view: .fo, distance: 3.5)

    static let alla: [LinkMessage] = [
        .hello(lead), .hello(follow),
        .ping(id: 7, t0: 81234.123456789),
        .pong(id: 7, t0: 81234.123456789, t1: 99.000001, t2: 99.000301),
        .start(passID: "20261022-101500", series: 3),
        .stop(series: 3),
        .recorded(serie),
        .recorded(LinkSeries(series: 1, localSeries: 1, passID: "x", startHost: nil, frameRate: 0, clicks: [],
                             view: .dtl, distance: 3)),
        .status(recording: true, freeGB: 41.5, pressure: "fair"),
        .ack(.start, series: 3), .ack(.stop, series: 3), .ack(.recorded, series: 2),
    ]

    // MARK: Tråden

    func testVarjeMeddelandeTurOchRetur() throws {
        var strom = Data()
        for m in Self.alla { strom.append(try Wire.frame(m)) }
        // Allt i en bit.
        var r = Wire.Reader()
        XCTAssertEqual(try r.feed(strom), Self.alla)
        XCTAssertEqual(r.count, Self.alla.count)
        // En byte i taget: inget kommer förrän ramen är hel.
        var r1 = Wire.Reader()
        var ut: [LinkMessage] = []
        for b in strom { ut += try r1.feed(Data([b])) }
        XCTAssertEqual(ut, Self.alla)
        // Ojämna bitar.
        var r2 = Wire.Reader()
        ut = []
        var i = 0
        var steg = 1
        while i < strom.count {
            let j = min(strom.count, i + steg)
            ut += try r2.feed(strom.subdata(in: i..<j))
            i = j
            steg = steg * 3 % 97 + 1
        }
        XCTAssertEqual(ut, Self.alla)
    }

    func testRamensHuvudArLangdenBigEndian() throws {
        let d = try Wire.frame(.stop(series: 1))
        let json = d.dropFirst(4)
        XCTAssertEqual(Array(d.prefix(4)), [0, 0, UInt8(json.count >> 8), UInt8(json.count & 0xFF)])
        let text = String(decoding: json, as: UTF8.self)
        XCTAssertTrue(text.contains("\"type\":\"stop\""), text)
        XCTAssertTrue(text.contains("\"series\":1"), text)
        // Pingen bär värdklockan med full upplösning (mikrosekunder räcker gott).
        let p = try Wire.frame(.ping(id: 1, t0: 81234.123456789))
        var r = Wire.Reader()
        guard case let .ping(_, t0)? = try r.feed(p).first else { return XCTFail("ingen ping") }
        XCTAssertEqual(t0, 81234.123456789, accuracy: 1e-9)
    }

    func testFelenSagerVarInteVad() throws {
        var r = Wire.Reader()
        XCTAssertThrowsError(try r.feed(Data([0, 0, 0, 0]))) { XCTAssertEqual($0 as? Wire.WireError, .badLength(message: 1)) }
        var r2 = Wire.Reader()
        XCTAssertThrowsError(try r2.feed(Data([0x7F, 0, 0, 0]))) { XCTAssertEqual($0 as? Wire.WireError, .badLength(message: 1)) }
        // Ett giltigt, sedan skräp: felet pekar på det andra.
        var r3 = Wire.Reader()
        var d = try Wire.frame(.stop(series: 1))
        let skrap = Data("{\"type\":\"sv\u{e4}ng\",\"series\":1}".utf8)
        d.append(contentsOf: [0, 0, 0, UInt8(skrap.count)])
        d.append(skrap)
        XCTAssertThrowsError(try r3.feed(d)) { e in
            XCTAssertEqual(e as? Wire.WireError, .badMessage(message: 2))
            // Felet bär inte meddelandets text.
            XCTAssertFalse(String(describing: e).contains("sv\u{e4}ng"))
        }
        XCTAssertThrowsError(try Wire.frame(.ping(id: 1, t0: .nan))) { XCTAssertEqual($0 as? Wire.WireError, .unencodable) }
    }

    // MARK: Telefonerna över ett nät i minnet

    /// Två telefoner och ett nät som går att dra ur. Den styrandes värdklocka är `klocka`;
    /// följarens går `theta` före. Varje meddelande går genom Wire.
    final class Nat {
        var leader = LinkLeader(hello: LinkTests.lead)
        var follower = LinkFollower(hello: LinkTests.follow)
        var uppe = false
        var peer = 0
        var klocka = 5000.0
        let theta: Double
        var fram = Wire.Reader(), tillbaka = Wire.Reader()
        var nr = 0
        /// Följarens inspelning: start och stopp i den ordning de kom.
        var logg: [LinkFollower.Action] = []
        var parade: [PairEntry] = []
        var stangda: [Int] = []

        init(theta: Double) { self.theta = theta }

        /// Vägen fram och tillbaka: 2–9 ms, olika varje gång (osymmetrisk).
        func vag() -> Double {
            nr += 1
            return 0.002 + 0.001 * Double((nr * 7) % 8)
        }

        func ledare(_ a: [LinkLeader.Action]) {
            for x in a {
                switch x {
                case let .send(p, m):
                    guard uppe, p == peer else { continue }
                    klocka += vag()
                    let ut = try! fram.feed(try! Wire.frame(m))
                    for m in ut {
                        let t1 = klocka + theta
                        foljare(follower.receive(m, at: t1, now: { self.klocka += 0.0003; return self.klocka + self.theta }))
                    }
                case let .paired(e): parade.append(e)
                case let .close(p): stangda.append(p)
                }
            }
        }

        func foljare(_ a: [LinkFollower.Action]) {
            for x in a {
                switch x {
                case let .send(m):
                    guard uppe else { continue }
                    klocka += vag()
                    for m in try! tillbaka.feed(try! Wire.frame(m)) {
                        ledare(leader.receive(m, from: peer, at: klocka))
                    }
                case .startRecording, .stopRecording: logg.append(x)
                }
            }
        }

        func anslut() {
            uppe = true
            peer += 1
            fram = Wire.Reader()
            tillbaka = Wire.Reader()
            ledare(leader.connected(peer: peer))
            foljare(follower.connected())
        }

        func tapp() {
            uppe = false
            leader.disconnected(peer: peer)
            follower.disconnected()
        }

        /// 30 ping med 20 ms mellanrum (S2_SPEC §7.2).
        func skur() {
            for _ in 0..<LinkLeader.burst {
                if let m = leader.ping(peer: peer, now: klocka) { ledare([.send(peer: peer, m)]) }
                klocka += LinkLeader.burstInterval
            }
            ledare(leader.pairAgain())
        }
    }

    static let pass = "20261022-101500"
    /// Den styrandes klick i filen, s.
    static let a = [2.0, 5.3, 9.1, 14.6, 20.2, 26.75]
    static let jitter = [0.0011, -0.0014, 0.0006, -0.0009, 0.0013, -0.0004]

    /// Följarens klick för samma slag: b = a + (SL − SF + θ) + ljudets längre väg + jitter.
    static func foljarensKlick(sl: Double, sf: Double, theta: Double, dA: Double, dB: Double) -> [Click] {
        let d = sl - sf + theta + (dB - dA) / 343
        return zip(a, jitter).map { Click(time: $0 + d + $1, strength: 20) }
    }

    func testTappMittISerienForlorarInget() throws {
        let n = Nat(theta: 0.734)
        n.anslut()
        XCTAssertEqual(n.follower.lead, Self.lead)
        XCTAssertEqual(n.leader.follower(peer: n.peer)?.hello, Self.follow)
        n.skur()
        let k0 = try XCTUnwrap(n.leader.follower(peer: n.peer)?.latestClock)
        XCTAssertLessThanOrEqual(abs(k0.offset - 0.734), k0.uncertainty + 1e-9)
        XCTAssertLessThan(abs(k0.offset - 0.734), 0.005)

        // Start på den styrande styr följaren.
        n.ledare(n.leader.start(passID: Self.pass, series: 1))
        XCTAssertEqual(n.logg, [.startRecording(passID: Self.pass, series: 1)])
        XCTAssertEqual(n.leader.follower(peer: n.peer)?.ackedStart, 1)
        let sl = n.klocka + 0.05
        let sf = n.klocka + 0.734 + 0.18                // följaren kom igång 180 ms senare
        n.skur()

        // Flygplansläge på följaren mitt i serien: stoppet når inte fram, följaren spelar vidare.
        n.tapp()
        n.ledare(n.leader.stop())
        XCTAssertEqual(n.follower.recording, 1)
        XCTAssertEqual(n.logg.count, 1)
        n.klocka += 10
        // Tillbaka: stoppet når fram.
        n.anslut()
        XCTAssertEqual(n.logg, [.startRecording(passID: Self.pass, series: 1), .stopRecording(series: 1)])
        XCTAssertNil(n.follower.recording)
        XCTAssertEqual(n.leader.follower(peer: n.peer)?.ackedStop, 1)
        n.skur()

        // Ett nytt tapp medan följaren läser sin fil: serien väntar i utkorgen.
        n.tapp()
        let b = Self.foljarensKlick(sl: sl, sf: sf, theta: 0.734, dA: 3.0, dB: 3.5)
        n.foljare(n.follower.finished(LinkSeries(series: 1, localSeries: 1, passID: Self.pass, startHost: sf,
                                                 frameRate: 240, clicks: b, view: .fo, distance: 3.5)))
        XCTAssertEqual(n.follower.outbox.count, 1)
        n.ledare(n.leader.ownFinished(LinkSeries(series: 1, localSeries: 1, passID: Self.pass, startHost: sl,
                                                 frameRate: 240, clicks: Self.a.map { Click(time: $0, strength: 30) },
                                                 view: .dtl, distance: 3.0)))
        XCTAssertTrue(n.parade.isEmpty)
        n.anslut()
        XCTAssertTrue(n.follower.outbox.isEmpty, "serien kvitterades inte")
        let e = try XCTUnwrap(n.parade.last)
        let sann = sl - sf + 0.734
        XCTAssertEqual(e.series, 1)
        XCTAssertEqual(e.offset, sann + 0.5 / 343, accuracy: 0.005)
        XCTAssertEqual(e.hitOffset, sann, accuracy: 0.005)
        XCTAssertEqual(e.hitOffset, sann, accuracy: 0.002)
        XCTAssertEqual(e.pairCount, 6)
        XCTAssertEqual(e.unpairedLead, 0)
        XCTAssertEqual(e.unpairedFollower, 0)
        XCTAssertFalse(e.uncertain)
        XCTAssertLessThan(try XCTUnwrap(e.medianAbsResidual), 0.005)
        XCTAssertEqual(e.clockSource, .after)
        XCTAssertEqual(e.window, PairEntry.windowAfter)
        XCTAssertEqual(e.follower.view, .fo)
        XCTAssertEqual(e.follower.model, "iPhone14,5")
        // Två förbindelser till samma telefon: ingen stängdes i onödan, och den senaste gäller.
        XCTAssertTrue(n.stangda.isEmpty)
        XCTAssertEqual(n.leader.connectedPeers, [n.peer])
    }

    func testUtanPingEfterStoppVidgasFonstret() throws {
        let n = Nat(theta: -2.5)
        n.anslut()
        n.ledare(n.leader.start(passID: Self.pass, series: 1))
        n.skur()
        let sl = n.klocka, sf = n.klocka - 2.5 + 0.3
        n.ledare(n.leader.stop())
        let b = Self.foljarensKlick(sl: sl, sf: sf, theta: -2.5, dA: 3, dB: 3)
        n.foljare(n.follower.finished(LinkSeries(series: 1, localSeries: 4, passID: "annat", startHost: sf,
                                                 frameRate: 240, clicks: b, view: .fo, distance: 3)))
        n.ledare(n.leader.ownFinished(LinkSeries(series: 1, localSeries: 1, passID: Self.pass, startHost: sl,
                                                 frameRate: 240, clicks: Self.a.map { Click(time: $0, strength: 1) },
                                                 view: .dtl, distance: 3)))
        let e = try XCTUnwrap(n.parade.last)
        XCTAssertEqual(e.clockSource, .before)
        XCTAssertEqual(e.window, PairEntry.windowBeforeOnly)
        XCTAssertEqual(e.offset, sl - sf - 2.5, accuracy: 0.005)
        XCTAssertEqual(e.follower.series, 4)
        XCTAssertEqual(e.follower.passID, "annat")
        // Pingen efter stopp kommer senare: parningen görs om, med smalare fönster.
        n.skur()
        let f = try XCTUnwrap(n.parade.last)
        XCTAssertEqual(f.clockSource, .after)
        XCTAssertEqual(f.window, PairEntry.windowAfter)
        XCTAssertEqual(f.offset, sl - sf - 2.5, accuracy: 0.005)
        // Inget ändrat: ingen ny rad.
        let antal = n.parade.count
        n.ledare(n.leader.pairAgain())
        XCTAssertEqual(n.parade.count, antal)
    }

    func testUtanKlockaSoksTioSekunder() {
        let a = LinkSeries(series: 1, localSeries: 1, passID: Self.pass, startHost: nil, frameRate: 240,
                           clicks: Self.a.map { Click(time: $0, strength: 1) }, view: .dtl, distance: 3)
        var b = a
        b.clicks = Self.a.enumerated().map { Click(time: $1 + 3.21 + Self.jitter[$0], strength: 1) }
        b.view = .fo
        let e = PairEntry.make(lead: a, follower: b, followerModel: "m", before: [], after: [])
        XCTAssertNil(e.prior)
        XCTAssertNil(e.clock)
        XCTAssertEqual(e.clockSource, PairEntry.ClockSource.none)
        XCTAssertEqual(e.window, ClickPairing.defaultSearch)
        XCTAssertEqual(e.offset, 3.21, accuracy: 0.003)
        XCTAssertFalse(e.uncertain)
    }

    func testFoljarenStoppadForHandStartarInteOm() {
        let n = Nat(theta: 0)
        n.anslut()
        n.ledare(n.leader.start(passID: Self.pass, series: 1))
        n.tapp()
        // Johannes stoppar följaren för hand under tappet; den styrande spelar vidare.
        n.follower.stoppedLocally()
        n.anslut()                                     // start(1) kommer igen
        XCTAssertEqual(n.logg, [.startRecording(passID: Self.pass, series: 1)])
        XCTAssertNil(n.follower.recording)
        // Ett missat stopp och en ny start under ett tapp: den gamla stoppas, den nya startar.
        n.ledare(n.leader.stop())
        n.ledare(n.leader.start(passID: Self.pass, series: 2))
        n.tapp()
        n.ledare(n.leader.stop())
        n.ledare(n.leader.start(passID: Self.pass, series: 3))
        n.anslut()
        XCTAssertEqual(n.logg.suffix(3), [.startRecording(passID: Self.pass, series: 2), .stopRecording(series: 2),
                                          .startRecording(passID: Self.pass, series: 3)])
        XCTAssertEqual(n.follower.recording, 3)
    }

    func testSammaTelefonIgenStangerDenGamlaForbindelsen() {
        var l = LinkLeader(hello: Self.lead)
        _ = l.connected(peer: 1)
        _ = l.receive(.hello(Self.follow), from: 1, at: 0)
        _ = l.connected(peer: 2)
        let a = l.receive(.hello(Self.follow), from: 2, at: 0)
        XCTAssertEqual(a, [.close(peer: 1)])
        XCTAssertEqual(l.connectedPeers, [2])
        XCTAssertEqual(l.followers.count, 1)
        // En ping till den gamla förbindelsen finns inte.
        XCTAssertNil(l.ping(peer: 1, now: 0))
        XCTAssertNotNil(l.ping(peer: 2, now: 0))
        // Ett svar med fel t0 eller från fel förbindelse räknas inte.
        _ = l.receive(.pong(id: 2, t0: 0, t1: 1, t2: 1), from: 2, at: 0.01)
        XCTAssertEqual(l.followers["B"]?.sampleCount, 0)
        _ = l.receive(.pong(id: 1, t0: 0, t1: 1, t2: 1), from: 2, at: 0.01)
        XCTAssertEqual(l.followers["B"]?.sampleCount, 1)
    }

    // MARK: par.json och rollen

    func testParJsonNycklarOchUppdatering() throws {
        let a = LinkSeries(series: 1, localSeries: 1, passID: Self.pass, startHost: 10, frameRate: 240,
                           clicks: Self.a.map { Click(time: $0, strength: 1) }, view: .dtl, distance: 3)
        var b = a
        b.view = .fo
        b.startHost = 10.4
        let ping = [PingSample(t0: 1, t1: 1.401, t2: 1.4012, t3: 1.0022)]
        let e = PairEntry.make(lead: a, follower: b, followerModel: "iPhone14,5", before: [], after: ping)
        var fil = PairFile(pass: Self.pass, model: "iPhone18,3", view: .dtl)
        fil.upsert(e)
        fil.upsert(e)
        XCTAssertEqual(fil.entries.count, 1)
        var e2 = e
        e2.series = 2
        fil.upsert(e2)
        XCTAssertEqual(fil.entries.map(\.series), [1, 2])
        let json = String(decoding: try PassCoding.encoder().encode(fil), as: UTF8.self)
        for nyckel in ["\"format\" : \"swinglab-par\\/1\"", "\"serier\"", "\"foljare\"", "\"forskjutning_s\"",
                       "\"traff_forskjutning_s\"", "\"antal_par\" : 6", "\"oparade_styr\" : 0", "\"median_rest_s\"",
                       "\"osaker\" : false", "\"klocka_ur\" : \"efter\"", "\"vy\" : \"fo\""] {
            XCTAssertTrue(json.contains(nyckel), nyckel)
        }
        XCTAssertEqual(try PassCoding.decoder().decode(PairFile.self, from: Data(json.utf8)), fil)
    }

    func testRollenIUppstallningen() throws {
        let gammal = Data(#"{"vy":"fo","klubba":"j7","avstand_m":3,"spelhand":"hoger"}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(PassSetup.self, from: gammal).role, .solo)
        let s = PassSetup(view: .fo, role: .follow)
        let json = String(decoding: try PassCoding.encoder().encode(s), as: UTF8.self)
        XCTAssertTrue(json.contains("\"roll\" : \"folj\""))
        XCTAssertEqual(try JSONDecoder().decode(PassSetup.self, from: Data(json.utf8)), s)
        XCTAssertEqual(LinkRole.allCases.map(\.rawValue), ["ensam", "styr", "folj"])
    }
}
