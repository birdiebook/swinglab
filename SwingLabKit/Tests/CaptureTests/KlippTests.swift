import Foundation
import XCTest
import Swing
import SwingDemo
@testable import Capture

/// S6g: klippen mellan telefonerna (Klipp.swift, Parad.swift, METOD MS30, MS31, BESLUT B80–B83).
/// Passen, lederna och "videorna" är PÅHITTADE (CLAUDE.md, Dataregeln): videorna är slumpbyte.
final class KlippTests: XCTestCase {
    static let pass = "20261024-153012"

    func tmp() throws -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("klipp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    /// Slumpbyte i en fil, som en video.
    func fil(_ url: URL, bytes: Int, fro: UInt64 = 7) throws {
        var g = fro
        var d = Data(count: bytes)
        d.withUnsafeMutableBytes { (b: UnsafeMutableRawBufferPointer) in
            for i in 0..<bytes {
                g = g &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                b[i] = UInt8(truncatingIfNeeded: g >> 33)
            }
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try d.write(to: url)
    }

    /// Den styrandes DTL-pass med tre slag i serie 1 (sving, inte sving, osäker) och ett i serie 2
    /// utan parning, och par.json för serie 1 med följaren 0,25 s efter och 1 m längre bort.
    func ledare() -> (pass: PassState, par: PairFile) {
        var p = PassState(id: Self.pass, created: Date(timeIntervalSince1970: 1_792_848_612),
                          setup: PassSetup(view: .dtl, club: "j7", distance: 3, hand: .hoger, role: .lead))
        let timing = FrameTiming.analyze((0..<10).map { Double($0) / 240 })
        for nr in 1...2 {
            p.series.append(SeriesRecord(nr: nr, source: .recording, club: "j7", file: PassState.videoPath(nr: nr),
                                         start: p.created, startHost: 100, duration: 60, bytes: 1, timing: timing,
                                         clicks: nr == 1 ? [5, 20, 35].map { Click(time: $0, strength: 30) }
                                             : [Click(time: 3, strength: 30)],
                                         orientation: 6, uprightWidth: 1080, uprightHeight: 1920))
        }
        p.syncShots()
        p.shots[0].verdict = .swing
        p.shots[1].verdict = .notSwing
        p.shots[2].verdict = .uncertain
        p.shots[3].verdict = .swing
        let styr = LinkSeries(series: 1, localSeries: 1, passID: Self.pass, startHost: 100, frameRate: 240,
                              clicks: p.series[0].clicks, view: .dtl, distance: 3)
        // Följaren hörde inte det andra klicket (20 s): parningen tar de två andra.
        let folj = LinkSeries(series: 1, localSeries: 2, passID: Self.pass, startHost: 99.75, frameRate: 240,
                              clicks: [5, 35].map { Click(time: $0 + 0.25, strength: 30) }, view: .fo, distance: 4)
        var par = PairFile(pass: Self.pass, model: "prov", view: .dtl)
        par.upsert(PairEntry.make(lead: styr, follower: folj, followerModel: "prov-fo", before: [], after: []))
        return (p, par)
    }

    // MARK: Begäran

    func testBegaranSvingarnasKlippIFoljarensFil() throws {
        let (p, par) = ledare()
        let e = try XCTUnwrap(par.entries.first)
        XCTAssertEqual(e.offset, 0.25, accuracy: 1e-9)
        let (b, utan) = KlippBegaran.make(pass: p, par: par, nr: 1, framme: [])
        XCTAssertEqual(utan, 1, "serie 2 har ingen parning")
        // "Not a swing" begärs inte; det missade klicket (s02 är inte sving, s03 osäker) begärs ändå.
        XCTAssertEqual(b.klipp.map(\.namn), ["s01", "s03"])
        XCTAssertTrue(b.klipp.allSatisfy { $0.serie == 2 }, "följarens serie")
        let s1 = b.klipp[0]
        let traff = p.shots[0].impact + e.hitOffset
        XCTAssertEqual(try XCTUnwrap(s1.fran), traff - 4, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(s1.till), traff + 2.5, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(s1.klick), 5.25, accuracy: 1e-9)
        // Träffen hos följaren: dess klick − dess ljudväg (4 m).
        XCTAssertEqual(traff, 5.25 - 4 / 343, accuracy: 1e-9)
        XCTAssertFalse(b.alltFramme)
        XCTAssertEqual(b.nasta(utom: [])?.namn, "s01")
        XCTAssertEqual(b.nasta(utom: ["s01"])?.namn, "s03")

        // Det som kommit, ett påbörjat och hela videon.
        let (b2, _) = KlippBegaran.make(pass: p, par: par, nr: 2, framme: ["s01"], pagaende: ["s03": ("abc-1", 4)],
                                        hela: true)
        XCTAssertEqual(b2.klipp.map(\.namn), ["s01", "s03", "video-02"])
        XCTAssertEqual(b2.klipp.map(\.klar), [true, false, false])
        XCTAssertEqual(b2.klipp[1].harId, "abc-1")
        XCTAssertEqual(b2.klipp[1].har, 4)
        XCTAssertNil(b2.klipp[2].fran)
        XCTAssertEqual(b2.nasta(utom: [])?.namn, "s03")
        let (b3, _) = KlippBegaran.make(pass: p, par: par, nr: 3, framme: ["s01", "s03", "video-02"], hela: true)
        XCTAssertTrue(b3.alltFramme)

        // JSON tur och retur, och fel namn vägras.
        let d = try b2.data()
        XCTAssertEqual(try KlippBegaran.las(d), b2)
        var trasig = b2
        trasig.klipp[0].namn = "../x"
        XCTAssertThrowsError(try KlippBegaran.las(try trasig.data()))
        XCTAssertTrue(KlippPost.giltigt("s03") && KlippPost.giltigt("video-01"))
        XCTAssertFalse(KlippPost.giltigt("S03") || KlippPost.giltigt("a/b") || KlippPost.giltigt("") || KlippPost.giltigt("-x"))
        XCTAssertEqual(AnnanVideo.fil(vy: .fo, namn: "s03"), "fo/Klipp/s03.mov")
        XCTAssertEqual(AnnanVideo.fil(vy: .fo, namn: "video-02"), "fo/Video/02.mov")
        // Fönstret inom följarens fil.
        XCTAssertEqual(KlippPost(namn: "s01", serie: 1, fran: -1, till: 5).fonster(langd: 3), 0...3)
        XCTAssertNil(KlippPost(namn: "s01", serie: 1, fran: 4, till: 5).fonster(langd: 3))
        XCTAssertEqual(KlippPost(namn: "video-01", serie: 1).fonster(langd: 30), 0...30)
    }

    // MARK: Strömmen

    /// Låter bitarna gå mellan sändaren och mottagaren tills inget mer skickas, eller `tapp` bitar
    /// gått (då "faller kopplingen"). Svarar det klara klippet, om det blev klart.
    func kor(_ s: inout KlippSandare, _ m: KlippMottagare, kalla: URL, namn: String, id: String, bytes: Int,
             start: [Int], onskade: Set<String>, klara: [String: String] = [:], tapp: Int? = nil,
             bitar: inout Int) throws -> String? {
        var ko = start
        var klar: String?
        var skickade = 0
        while !ko.isEmpty {
            let i = ko.removeFirst()
            if let tapp, skickade >= tapp {
                s.avbrott()
                return nil
            }
            skickade += 1
            bitar += 1
            let bit = try Klippfil.bit(kalla, index: i, pass: Self.pass, namn: namn, id: id, bytes: bytes)
            switch m.taEmot(bit, onskade: onskade, klara: klara) {
            case let .kvittera(a):
                for x in a {
                    if case let .skicka(n) = s.kvittens(x) { ko += n }
                }
            case let .klar(n, fil, b, i2, kvittens):
                XCTAssertEqual(b, bytes)
                XCTAssertEqual(i2, id)
                XCTAssertEqual(fil, AnnanVideo.fil(vy: .fo, namn: n))
                if case let .skicka(n2) = s.kvittens(kvittens) { ko += n2 }
                if case .klar = s.kvittens(m.helKvittens(namn: n, id: id)) { klar = n }
            }
        }
        return klar
    }

    func testStrommenMedAvbrottOchAterupptag() throws {
        let rot = try tmp()
        let kalla = rot.appendingPathComponent("folj/Utskick/s01.mov")
        let bytes = 7 * Overforing.delBytes + 1234           // åtta bitar, den sista kort
        try fil(kalla, bytes: bytes)
        let id = try Klippfil.summa(kalla)
        XCTAssertEqual(id, Overforing.summa(try Data(contentsOf: kalla)), "summan läst i bitar = hela")
        let mapp = rot.appendingPathComponent("styr")
        try FileManager.default.createDirectory(at: mapp, withIntermediateDirectories: true)
        var m = KlippMottagare(mapp: mapp, vy: .fo, pass: Self.pass)
        var s = KlippSandare()
        var bitar = 0

        // Fönstret: högst 8 i luften (här alla 8), och kopplingen faller efter 5 bitar.
        let forsta = s.borja(namn: "s01", id: id, bytes: bytes)
        XCTAssertEqual(forsta, Array(0..<8))
        XCTAssertNil(try kor(&s, m, kalla: kalla, namn: "s01", id: id, bytes: bytes, start: forsta, onskade: ["s01"],
                             tapp: 5, bitar: &bitar))
        XCTAssertNil(s.strom)
        let har = try XCTUnwrap(m.har("s01"))
        XCTAssertEqual(har.id, id)
        XCTAssertEqual(har.har, 5, "fem hela bitar på disken")

        // Appen startas om: en ny mottagare läser förloppet ur filen, begäran bär det, och
        // strömmen fortsätter vid bit 5.
        m = KlippMottagare(mapp: mapp, vy: .fo, pass: Self.pass)
        let (b, _) = KlippBegaran.make(pass: ledare().pass, par: ledare().par, nr: 2, framme: [],
                                       pagaende: m.pagaende(["s01", "s03"]))
        XCTAssertEqual(b.klipp.first?.har, 5)
        let igen = s.borja(namn: "s01", id: id, bytes: bytes, fran: b.klipp.first?.harId == id ? b.klipp.first?.har ?? 0 : 0)
        XCTAssertEqual(igen, [5, 6, 7])
        let fore = bitar
        let klar = try kor(&s, m, kalla: kalla, namn: "s01", id: id, bytes: bytes, start: igen, onskade: ["s01"],
                           bitar: &bitar)
        XCTAssertEqual(klar, "s01")
        XCTAssertEqual(bitar - fore, 3, "bara de tre som saknades")
        let mal = mapp.appendingPathComponent("fo/Klipp/s01.mov")
        XCTAssertEqual(try Data(contentsOf: mal), try Data(contentsOf: kalla))
        XCTAssertNil(m.har("s01"), ".part är flyttad")

        // En bit av ett klipp som redan är framme kvitteras hel igen.
        let p = try Klippfil.bit(kalla, index: 2, pass: Self.pass, namn: "s01", id: id, bytes: bytes)
        guard case let .kvittera(a) = m.taEmot(p, onskade: ["s01"], klara: ["s01": id]) else { return XCTFail() }
        XCTAssertEqual(a.map(\.index), [2, nil])
        XCTAssertTrue(a.allSatisfy(\.ok))
    }

    func testDubbletterLuckorOchFelSumma() throws {
        let rot = try tmp()
        let kalla = rot.appendingPathComponent("v.mov")
        let bytes = 3 * Overforing.delBytes
        try fil(kalla, bytes: bytes)
        let id = try Klippfil.summa(kalla)
        try FileManager.default.createDirectory(at: rot.appendingPathComponent("styr"), withIntermediateDirectories: true)
        let m = KlippMottagare(mapp: rot.appendingPathComponent("styr"), vy: .fo, pass: Self.pass)
        func bit(_ i: Int, id: String? = nil) throws -> LinkPart {
            try Klippfil.bit(kalla, index: i, pass: Self.pass, namn: "s02", id: id ?? Klippfil.summa(kalla), bytes: bytes)
        }
        guard case let .kvittera(a0) = m.taEmot(try bit(0), onskade: ["s02"], klara: [:]) else { return XCTFail() }
        XCTAssertEqual(a0.map(\.index), [0])
        // Samma bit igen: kvitteras, skrivs inte två gånger.
        guard case let .kvittera(a1) = m.taEmot(try bit(0), onskade: ["s02"], klara: [:]) else { return XCTFail() }
        XCTAssertEqual(a1.map(\.index), [0])
        XCTAssertEqual(m.har("s02")?.har, 1)
        // En lucka: börja vid 1.
        guard case let .kvittera(a2) = m.taEmot(try bit(2), onskade: ["s02"], klara: [:]) else { return XCTFail() }
        XCTAssertEqual(a2.first?.ok, false)
        XCTAssertNil(a2.first?.fel)
        XCTAssertEqual(a2.first?.har, 1)
        var s = KlippSandare()
        _ = s.borja(namn: "s02", id: id, bytes: bytes)
        XCTAssertEqual(s.kvittens(a2[0]), .skicka([1, 2]))

        // Ett påhittat id som inte är summan: alla bitar kommer, summan stämmer inte, och klippet
        // börjar om från början.
        let falskt = "00000000-\(bytes)"
        for i in 0..<2 { _ = m.taEmot(try bit(i, id: falskt), onskade: ["s02"], klara: [:]) }
        guard case let .kvittera(a3) = m.taEmot(try bit(2, id: falskt), onskade: ["s02"], klara: [:]) else {
            return XCTFail("fel summa togs emot")
        }
        XCTAssertEqual(a3.last?.ok, false)
        XCTAssertEqual(a3.last?.har, 0)
        XCTAssertNil(m.har("s02"), "fel summa: delen är borta")
        XCTAssertFalse(FileManager.default.fileExists(atPath: rot.appendingPathComponent("styr/fo/Klipp/s02.mov").path))

        // Ett namn som inte begärts, ett annat pass och en annan version: nej med skäl.
        guard case let .kvittera(n1) = m.taEmot(try bit(0), onskade: ["s01"], klara: [:]) else { return XCTFail() }
        XCTAssertEqual(n1.first?.fel, Overforing.felFormat)
        var annat = try bit(0)
        annat.pass = "20261024-160000"
        guard case let .kvittera(n2) = m.taEmot(annat, onskade: ["s02"], klara: [:]) else { return XCTFail() }
        XCTAssertEqual(n2.first?.fel, Overforing.felPass)
        var v2 = try bit(0)
        v2.v = 2
        guard case let .kvittera(n3) = m.taEmot(v2, onskade: ["s02"], klara: [:]) else { return XCTFail() }
        XCTAssertEqual(n3.first?.fel, Overforing.felVersion)
        XCTAssertEqual(s.kvittens(LinkPartAck(kind: Overforing.klipp, pass: Self.pass, id: id, index: nil, ok: false,
                                              fel: Overforing.felPass, namn: "s02")), .nej("s02", Overforing.felPass))
        XCTAssertNil(s.strom)
        // En trasig bit (fel storlek) läses inte.
        var kort = try bit(0)
        kort.count = 9
        XCTAssertEqual(m.taEmot(kort, onskade: ["s02"], klara: [:]), .kvittera([]))
    }

    /// Ett klipp på 30 MB (6,5 s, METOD MS30) går i 153 bitar om 192 kB, och varje meddelande
    /// ryms i ramen.
    func testStorlekenPaKopplingen() throws {
        let bytes = 30_000_000
        XCTAssertEqual(Overforing.antal(bytes), 153)
        let rot = try tmp()
        let kalla = rot.appendingPathComponent("v.mov")
        try fil(kalla, bytes: Overforing.delBytes + 10)
        let bit = try Klippfil.bit(kalla, index: 0, pass: Self.pass, namn: "s01", id: "x-1", bytes: Overforing.delBytes + 10)
        let ram = try Wire.frame(.part(bit))
        XCTAssertLessThan(ram.count, Wire.maxLength)
        print(String(format: "KLIPP: en bit %ld byte på kopplingen (%.2f av innehållet)", ram.count,
                     Double(ram.count) / Double(Overforing.delBytes)))
    }

    // MARK: Synken och raden

    func testSynkenPaTraffenOchRaden() throws {
        let (p0, par) = ledare()
        var p = p0
        let e = try XCTUnwrap(par.entries.first)
        let s1 = p.shots[0]
        let (b, _) = KlippBegaran.make(pass: p, par: par, nr: 1, framme: [])
        let post = b.klipp[0]
        // Klicket hördes 3 ms från det väntade i klippet.
        let iKlippet = try XCTUnwrap(post.klick) - post.fran! + 0.003
        var v = AnnanVideo(pass: Self.pass, vy: .fo)
        v.klipp["s01"] = AnnanVideo.Klipp(fil: AnnanVideo.fil(vy: .fo, namn: "s01"), serie: 2, fran: post.fran,
                                          klick: post.klick, klickIKlipp: iKlippet, langd: 6.5, bytes: 1, id: "a-1")
        let k = try XCTUnwrap(v.kalla(slag: s1, par: e))
        XCTAssertEqual(k.fil, "fo/Klipp/s01.mov")
        // Den styrandes träff hamnar på följarens träff i klippet: 4 s in (+ 3 ms).
        XCTAssertEqual(s1.impact + k.offset, 4.003, accuracy: 1e-9)
        // Med hela videon i stället: förskjutningen är träffens.
        var hel = AnnanVideo(pass: Self.pass, vy: .fo)
        hel.klipp["video-02"] = AnnanVideo.Klipp(fil: "fo/Video/02.mov", serie: 2, bytes: 1, id: "b-1")
        let h = try XCTUnwrap(hel.kalla(slag: s1, par: e))
        XCTAssertEqual(h.offset, e.hitOffset, accuracy: 1e-12)
        XCTAssertEqual(s1.impact + h.offset - post.fran!, 4, accuracy: 1e-9, "samma träff som klippet")
        XCTAssertNil(v.kalla(slag: p.shots[2], par: e), "s03 har inget klipp än")

        // "14 swings · 12 from both phones": här mäts slagen påhittat.
        for i in p.shots.indices {
            p.shots[i].measure = ShotMeasure(heightM: 1.8, heightAssumed: false)
        }
        XCTAssertEqual(Parstatus.text(pass: p, par: par, video: v), "3 swings\u{00A0}· 1 from both phones")
        XCTAssertEqual(Parstatus.text(pass: p, par: par, video: nil), "3 swings\u{00A0}· 0 from both phones")
        XCTAssertEqual(Parstatus.procent(Parstatus.andel(b, pagaende: ["s01": 30], antal: ["s01": 60])), 25)
        XCTAssertEqual(Parstatus.procent(Parstatus.andel(KlippBegaran.make(pass: p, par: par, nr: 1,
                                                                          framme: ["s01", "s03", "s04"]).begaran)), 100)
        XCTAssertEqual(Texter.hamtar(60), "Getting video from other phone\u{00A0}· 60 %")
        XCTAssertEqual(Texter.sammaVy(.dtl), "Both phones are DTL")
        XCTAssertEqual(Texter.bytVy(Vyvakt.annan(.dtl)), "Switch to FO")
        XCTAssertTrue(Vyvakt.sammaVy(egen: .dtl, andra: [.dtl]))
        XCTAssertFalse(Vyvakt.sammaVy(egen: .dtl, andra: [.fo]))
        XCTAssertFalse(Vyvakt.sammaVy(egen: .dtl, andra: []))
    }

    // MARK: Den andra vyns pass och paket

    /// Följarens bunt (FO, åtta slag), dess slag mätta med den styrandes längd, och paketet för
    /// FO från den styrande med klippen som kommit: samma format som följarens eget.
    func testAndraVynsPassOchPaket() throws {
        let fo = DemoPass.fo(id: Self.pass, created: Date(timeIntervalSince1970: 1_792_848_612), sway: [-3, -2, -4])
        var fp = fo.pass
        fp.setup.role = .follow
        let manifest = PackageManifest.make(pass: fp, app: .init(version: "1", build: "1"),
                                            phone: .init(model: "prov", ios: "18"), created: fp.created,
                                            timeZone: TimeZone(identifier: "Europe/Stockholm")!, includeClips: false)
        let bunt = try SlagBunt.make(manifest: try PassPackage.encoder().encode(manifest), enhet: Data("{}".utf8),
                                     par: nil, leder: fo.leder)
        var lead = PassState(id: Self.pass, created: fp.created, setup: PassSetup(view: .dtl, role: .lead), heightM: 1.8)
        lead.shots = []
        let annan = try AnnanSession.pass(bunt, lead: lead)
        XCTAssertEqual(annan.setup.view, .fo)
        XCTAssertEqual(annan.shots.map(\.id), ["s01", "s02", "s03"])
        XCTAssertEqual(annan.countedSwings.count, 3)
        XCTAssertTrue(annan.shots.allSatisfy { $0.measure?.heightM == 1.8 })
        XCTAssertNotNil(annan.countedSwings.first?.matt["backen_sway_topp"])

        // Klippen: s01 kom med ett klick, "s09" är ett klipp för ett slag som följaren inte hörde.
        let rot = try tmp()
        try fil(rot.appendingPathComponent("fo/Klipp/s01.mov"), bytes: 1000)
        try fil(rot.appendingPathComponent("fo/Klipp/s09.mov"), bytes: 1000)
        var v = AnnanVideo(pass: Self.pass, vy: .fo)
        let k1 = fp.shots[0].click.time
        v.klipp["s01"] = AnnanVideo.Klipp(fil: "fo/Klipp/s01.mov", serie: 1, fran: k1 - 4 + 0.01, klick: k1 + 0.002,
                                          klickIKlipp: 3.992, langd: 6.5, bytes: 1000, id: "a-1")
        v.klipp["s09"] = AnnanVideo.Klipp(fil: "fo/Klipp/s09.mov", serie: 1, fran: 0, klick: 1, klickIKlipp: 1,
                                          langd: 6.5, bytes: 1000, id: "b-1")
        let url = rot.appendingPathComponent("Export/\(AnnanPaket.filnamn(bunt))")
        let sum = try AnnanPaket.write(bunt: bunt, video: v, folder: rot, to: url, scratch: rot.appendingPathComponent("tmp"),
                                       created: fp.created, medKlipp: true)
        XCTAssertEqual(url.lastPathComponent, "swinglab-\(Self.pass)-fo.zip")
        XCTAssertEqual(sum.names, ["manifest.json", "enhet.json", "slag/s01.json", "slag/s02.json", "slag/s03.json",
                                   "klipp/s01.mov"])
        XCTAssertEqual(sum.clips, 1)
        let z = try ZipLasare(url: url)
        let m = try JSONDecoder().decode(PackageManifest.self, from: try XCTUnwrap(z.data("manifest.json", max: 1 << 20)))
        XCTAssertEqual(m.view, .fo)
        XCTAssertEqual(m.phone.role, "folj")
        XCTAssertEqual(m.shots[0].clip, "klipp/s01.mov")
        // Följarens klick ligger 2 ms före det väntade: klicket i klippet flyttas lika mycket.
        XCTAssertEqual(try XCTUnwrap(m.shots[0].clickInClip), 3.990, accuracy: 1e-9)
        XCTAssertEqual(m.shots[0].clipDuration, 6.5)
        XCTAssertNil(m.shots[1].clip)
        let l1 = try JSONDecoder().decode(JointSeries.self, from: try XCTUnwrap(z.data("slag/s01.json", max: 1 << 24)))
        XCTAssertEqual(l1.frames.map(\.t), try bunt.lederna()["s01"]!.rounded().frames.map(\.t))
        // Reserven: "Import other phone" på den styrande tar klippet ur paketet, under den
        // styrandes slag med samma klick (utan par.json: seriernas klick paras).
        let dtl = DemoPass.dtl(id: Self.pass, created: fp.created, thrust: [-2, -1, -3]).pass
        let styrMapp = try tmp()
        let imp = try XCTUnwrap(try ImportKlipp.importera(zip: url, lead: dtl, par: nil, vy: .fo, mapp: styrMapp,
                                                          tidigare: nil))
        XCTAssertEqual(Array(imp.klipp.keys), ["s01"])
        XCTAssertEqual(try Data(contentsOf: styrMapp.appendingPathComponent("fo/Klipp/s01.mov")),
                       try Data(contentsOf: rot.appendingPathComponent("fo/Klipp/s01.mov")))
        XCTAssertEqual(try XCTUnwrap(imp.klipp["s01"]?.klickIKlipp), 3.990, accuracy: 1e-9)
        XCTAssertEqual(imp.klipp["s01"]?.id, Overforing.summa(try Data(contentsOf: rot.appendingPathComponent("fo/Klipp/s01.mov"))))
        XCTAssertNil(try ImportKlipp.importera(zip: url, lead: dtl, par: nil, vy: .dtl, mapp: styrMapp, tidigare: nil),
                     "samma vy som den här telefonen")
        // Utan klipp.
        let utan = try AnnanPaket.write(bunt: bunt, video: v, folder: rot, to: url, scratch: rot.appendingPathComponent("tmp"),
                                        created: fp.created, medKlipp: false)
        XCTAssertEqual(utan.clips, 0)
        XCTAssertEqual(utan.names.count, 5)
        // Den andra vyns slag för den styrandes: klicket inom 30 ms.
        let e = PairEntry.make(lead: LinkSeries(series: 1, localSeries: 1, passID: Self.pass, startHost: nil, frameRate: 240,
                                                clicks: fp.series[0].clicks, view: .dtl, distance: 3),
                               follower: LinkSeries(series: 1, localSeries: 1, passID: Self.pass, startHost: nil,
                                                    frameRate: 240, clicks: fp.series[0].clicks, view: .fo, distance: 3),
                               followerModel: "prov", before: [], after: [])
        let styrSlag = ShotRecord(id: "s01", series: 1, click: Click(time: k1 + 0.02, strength: 1), impact: k1)
        XCTAssertEqual(AnnanSession.slag(styrSlag, i: annan, par: e)?.id, "s01")
    }

    // MARK: Kopplingen

    /// Den styrande lämnar klippens bitar till appen bara från en följare med "video1", och
    /// följaren lämnar kvittenserna till appen; en äldre följare får inga klipp.
    func testKlippenGarTillAppen() throws {
        var l = LinkLeader(hello: LinkHello(role: .lead, device: "A", model: "m", app: "1", view: .dtl, mode: .pass),
                           passID: Self.pass)
        _ = l.receive(.hello(LinkHello(role: .follow, device: "B", model: "m", app: "1", view: .fo, mode: .pass)),
                      from: 7, at: 0)
        let bit = LinkPart(kind: Overforing.klipp, pass: Self.pass, id: "a-1", index: 0, count: 1, bytes: 1, data: "AA==",
                           namn: "s01")
        XCTAssertEqual(l.receive(.part(bit), from: 7, at: 0), [.stream(device: "B", bit)])
        let a = LinkPartAck(kind: Overforing.klipp, pass: Self.pass, id: "a-1", index: 0, ok: true, namn: "s01")
        XCTAssertEqual(l.streamAck(device: "B", a), [.send(peer: 7, .partAck(a))])
        XCTAssertEqual(l.streamAck(device: "C", a), [])
        // En äldre följare (bara "part1").
        _ = l.receive(.hello(LinkHello(role: .follow, device: "C", model: "m", app: "0.9", view: .fo, mode: .pass,
                                       caps: ["part1"])), from: 8, at: 0)
        XCTAssertEqual(l.receive(.part(bit), from: 8, at: 0), [])

        var f = LinkFollower(hello: LinkHello(role: .follow, device: "B", model: "m", app: "1", view: .fo, mode: .pass))
        XCTAssertEqual(f.sendStream([bit]), [], "inte uppkopplad")
        _ = f.connected()
        _ = f.receive(.hello(LinkHello(role: .lead, device: "A", model: "m", app: "1", view: .dtl, mode: .pass)), at: 0,
                      now: { 0 })
        XCTAssertTrue(f.kanVideo)
        XCTAssertEqual(f.sendStream([bit]), [.send(.part(bit))])
        XCTAssertEqual(f.receive(.partAck(a), at: 0, now: { 0 }), [.streamAck(a)])
        // Begäran är en vanlig överföring till följaren.
        let (b, _) = KlippBegaran.make(pass: ledare().pass, par: ledare().par, nr: 1, framme: [])
        var styr = l
        let delar = Overforing.dela(kind: Overforing.begaran, pass: Self.pass, data: try b.data())
        let ut = styr.sendToFollowers(delar)
        XCTAssertTrue(ut.contains { if case .send(7, .part) = $0 { return true } else { return false } })
        var fick: [LinkFollower.Action] = []
        for d in delar { fick += f.receive(.part(d), at: 0, now: { 0 }) }
        guard let r = fick.first(where: { if case .received = $0 { return true } else { return false } }),
              case let .received(kind, _, id, bytes, bitar) = r else { return XCTFail("begäran togs inte emot") }
        XCTAssertEqual(kind, Overforing.begaran)
        XCTAssertEqual(try KlippBegaran.las(try XCTUnwrap(Overforing.foga(id: id, bytes: bytes, delar: bitar))), b)
        // Hello bär förmågan.
        XCTAssertTrue(LinkHello.ourCaps.contains("video1"))
        let gammal = LinkHello(role: .lead, device: "A", model: "m", app: "0.9", view: .dtl, mode: .pass, caps: ["part1"])
        XCTAssertFalse(gammal.kanVideo)
    }

    // MARK: Granskningen (S6g): starten, klicket, disken, nejen, ordningen och originalen

    /// Ett klipp som börjar på en tidigare I-ruta (ingen edit list, 0,4 s längre än begärt) och ett
    /// falskt ljud 0,3 s från det väntade: starten läses ur klippet, ljudet räknas inte, och synken
    /// tar det väntade från den verkliga starten.
    func testTidigareIRutaOchFalsktLjud() throws {
        XCTAssertEqual(KlippStart.start(fran: 5.0, till: 11.5, langd: 6.5, trimmad: true), 5.0)
        XCTAssertEqual(KlippStart.start(fran: 5.0, till: 11.5, langd: 6.9, trimmad: false), 4.6, accuracy: 1e-12)
        XCTAssertEqual(KlippStart.start(fran: 0.2, till: 6.7, langd: 7.0, trimmad: false), 0, "inte före filen")
        XCTAssertEqual(KlippStart.start(fran: 9.0, till: 15.5, langd: 3.0, trimmad: false), 9.0, "kortare i filens slut")
        // Väntat klick 4,4 s in i klippet som börjar 4,6 (klicket 9,0 i filen).
        XCTAssertEqual(KlippStart.klick([Click(time: 4.408, strength: 9)], vantat: 4.4), 4.408)
        XCTAssertNil(KlippStart.klick([Click(time: 4.7, strength: 9)], vantat: 4.4), "ett annat ljud 0,3 s bort")
        XCTAssertNil(KlippStart.klick([], vantat: 4.4))
        let (p, par) = ledare()
        let e = try XCTUnwrap(par.entries.first)
        let s1 = p.shots[0]
        var v = AnnanVideo(pass: Self.pass, vy: .fo)
        let klick = s1.click.time + e.offset
        let fran = max(0, s1.impact + e.hitOffset - 4)
        v.klipp["s01"] = AnnanVideo.Klipp(fil: "fo/Klipp/s01.mov", serie: 2, fran: fran, start: max(0, fran - 0.4),
                                          klick: klick, klickIKlipp: nil, langd: 6.9, bytes: 1, id: "a-1")
        let k = try XCTUnwrap(v.kalla(slag: s1, par: e))
        // Följarens träff i klippet = klicket − den verkliga starten − ljudvägen.
        XCTAssertEqual(s1.impact + k.offset, klick - max(0, fran - 0.4) - 4.0 / 343, accuracy: 1e-9)
        XCTAssertEqual(v.utanKlick, ["s01"], "slaget märks: inget klick i klippet")
    }

    func testDiskenIdtOchMappen() throws {
        let rot = try tmp()
        let kalla = rot.appendingPathComponent("v.mov")
        try fil(kalla, bytes: 1000)
        let id = try Klippfil.summa(kalla)
        let mapp = rot.appendingPathComponent("styr")
        let m = KlippMottagare(mapp: mapp, vy: .fo, pass: Self.pass)
        let bit = try Klippfil.bit(kalla, index: 0, pass: Self.pass, namn: "s01", id: id, bytes: 1000)
        // Passets mapp finns inte (raderat): inget skrivs, inget svar.
        XCTAssertEqual(m.taEmot(bit, onskade: ["s01"], klara: [:]), .kvittera([]))
        XCTAssertFalse(FileManager.default.fileExists(atPath: mapp.path))
        try FileManager.default.createDirectory(at: mapp, withIntermediateDirectories: true)
        // För lite ledigt: nej med skälet disk före första biten.
        guard case let .kvittera(a) = m.taEmot(bit, onskade: ["s01"], klara: [:], ledigt: 50 << 20) else { return XCTFail() }
        XCTAssertEqual(a.first?.fel, Overforing.felDisk)
        var s = KlippSandare()
        _ = s.borja(namn: "s01", id: id, bytes: 1000)
        XCTAssertEqual(s.kvittens(a[0]), .nej("s01", Overforing.felDisk))
        // Gott om plats: tas emot.
        guard case .klar = m.taEmot(bit, onskade: ["s01"], klara: [:], ledigt: 1 << 40) else { return XCTFail() }
        // Summan måste ha formen och längden ska vara bitens.
        XCTAssertTrue(KlippMottagare.giltigtId("1a2b3c4d-1000", bytes: 1000))
        XCTAssertFalse(KlippMottagare.giltigtId("1a2b3c4d-999", bytes: 1000))
        XCTAssertFalse(KlippMottagare.giltigtId("1A2B3C4D-1000", bytes: 1000))
        XCTAssertFalse(KlippMottagare.giltigtId("../x-1000", bytes: 1000))
        XCTAssertFalse(KlippMottagare.giltigtId("1a2b3c4d-10-00", bytes: 1000))
        var fel = bit
        fel.id = "ffffffff-12"
        guard case let .kvittera(n) = m.taEmot(fel, onskade: ["s01"], klara: [:]) else { return XCTFail() }
        XCTAssertEqual(n.first?.fel, Overforing.felFormat)
        // Taket per klipp.
        XCTAssertEqual(KlippMottagare.maxKlipp, 128 << 20)
        // Rensningen: delar utanför begäran tas bort.
        let delar = mapp.appendingPathComponent("fo/Delar")
        try FileManager.default.createDirectory(at: delar, withIntermediateDirectories: true)
        for f in ["s02~a.part", "video-01~b.part"] { FileManager.default.createFile(atPath: delar.appendingPathComponent(f).path, contents: Data([1])) }
        m.rensa(behall: ["s02"])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: delar.path), ["s02~a.part"])
    }

    /// Följarens nej (`saknas`), att en gammal begäran inte skickas igen vid hello eller vinner över
    /// en nyare, och originalens regel.
    func testNejOrdningenOchOriginalen() throws {
        var l = LinkLeader(hello: LinkHello(role: .lead, device: "A", model: "m", app: "1", view: .dtl, mode: .pass),
                           passID: Self.pass)
        let folj = LinkHello(role: .follow, device: "B", model: "m", app: "1", view: .fo, mode: .pass)
        _ = l.receive(.hello(folj), from: 7, at: 0)
        let (p, par) = ledare()
        let b1 = KlippBegaran.make(pass: p, par: par, nr: 1, framme: []).begaran
        _ = l.sendToFollowers(Overforing.dela(kind: Overforing.begaran, pass: Self.pass, data: try b1.data()))
        l.disconnected(peer: 7)
        let igen = l.receive(.hello(folj), from: 8, at: 0)
        XCTAssertFalse(igen.contains { if case .send(_, .part) = $0 { return true } else { return false } },
                       "begäran skickas inte igen ur broadcast")
        let saknas = LinkPartAck(kind: Overforing.klipp, pass: Self.pass, id: "", index: nil, ok: false,
                                 fel: Overforing.felSaknas, namn: "video-02")
        XCTAssertEqual(l.receive(.partAck(saknas), from: 8, at: 0), [.streamRefused(device: "B", saknas)])
        var f = LinkFollower(hello: folj)
        XCTAssertEqual(f.refuseStream(saknas), [])
        _ = f.connected()
        _ = f.receive(.hello(LinkHello(role: .lead, device: "A", model: "m", app: "1", view: .dtl, mode: .pass)), at: 0,
                      now: { 0 })
        XCTAssertEqual(f.refuseStream(saknas), [.send(.partAck(saknas))])

        // Den styrande begär inte det som saknas, och en äldre begäran vinner inte.
        let b2 = KlippBegaran.make(pass: p, par: par, nr: 2, framme: [], hela: true, saknas: ["video-02"]).begaran
        XCTAssertEqual(b2.klipp.map(\.namn), ["s01", "s03"])
        XCTAssertTrue(b1.aldre(an: b2))
        XCTAssertFalse(b2.aldre(an: b1))
        XCTAssertFalse(b1.aldre(an: nil))
        var v = AnnanVideo(pass: Self.pass, vy: .fo)
        v.saknas = ["video-02"]
        XCTAssertTrue(v.originalenBorta)
        let d = try v.data()
        XCTAssertEqual(try AnnanVideo.las(d).saknas, ["video-02"])

        // Originalen: tills allt är framme, inte utan klippen hos den styrande, och inte efter en vecka.
        let nu = Date(timeIntervalSince1970: 1_800_000_000)
        let klar = KlippBegaran.make(pass: p, par: par, nr: 3, framme: ["s01", "s03"]).begaran
        XCTAssertTrue(Originalen.behovs(roll: .follow, begaran: nil, utanVideo: false, skapad: nu, nu: nu))
        XCTAssertTrue(Originalen.behovs(roll: .follow, begaran: b1, utanVideo: false, skapad: nu, nu: nu))
        XCTAssertFalse(Originalen.behovs(roll: .follow, begaran: klar, utanVideo: false, skapad: nu, nu: nu))
        XCTAssertFalse(Originalen.behovs(roll: .follow, begaran: nil, utanVideo: true, skapad: nu, nu: nu))
        XCTAssertFalse(Originalen.behovs(roll: .follow, begaran: b1, utanVideo: false, skapad: nu,
                                         nu: nu.addingTimeInterval(Originalen.tidsgrans + 1)))
        XCTAssertFalse(Originalen.behovs(roll: .lead, begaran: nil, utanVideo: false, skapad: nu, nu: nu))
    }
}
