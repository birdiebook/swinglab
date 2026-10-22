import Foundation
import XCTest
import Swing
@testable import Capture

/// S2c och S2d: ljudet i bitar ur en fil, passets tillstånd, kvittot och importens
/// kontroll, på påhittade värden (CLAUDE.md, Dataregeln). METOD MS3, MS4, MS11
final class InspelningTests: XCTestCase {

    /// Ett enkelt frö-slumptal för buffertstorlekarna (samma varje körning).
    struct Bitar {
        var s: UInt64
        mutating func next(_ max: Int) -> Int {
            s = (6_364_136_223_846_793_005 &* s &+ 1_442_695_040_888_963_407)
            return Int((s >> 33) % UInt64(max)) + 1
        }
    }

    /// Matar segmenteraren i buffertar av slumpad storlek och samlar bitarna.
    func segmentera(count: Int, sr: Double, segment: Double, overlap: Double, fro: UInt64,
                    maxBuffer: Int) -> [AudioSegmenter.Segment] {
        var seg = AudioSegmenter(sampleRate: sr, segment: segment, overlap: overlap)
        var ut: [AudioSegmenter.Segment] = []
        var r = Bitar(s: fro)
        var i = 0
        while i < count {
            let n = min(r.next(maxBuffer), count - i)
            seg.feed((i..<(i + n)).map { Float($0) }) { ut.append($0) }
            i += n
        }
        seg.finish { ut.append($0) }
        return ut
    }

    // MARK: Bitarna ur filen

    /// Bitarna börjar och slutar på samma prov som `ClickDetector.segments` (och
    /// PC:ns `bitar()`), hur buffertarna än faller, och bär rätt prov och inre gränser.
    func testSegmenterarenKlipperVidSammaProvSomSegments() {
        let sr = 1000.0
        let (l, steg) = ClickDetector.segmentSamples(sampleRate: sr, segment: 3, overlap: 1)
        XCTAssertEqual(l, 3000)
        XCTAssertEqual(steg, 2000)
        for count in [0, 1, 999, l - 1, l, l + 1, l + steg, l + steg + 1, l + 2 * steg, 10_007] {
            for (fro, maxBuf) in [(UInt64(1), 1), (2, 37), (3, 4096), (4, 50_000)] {
                let bitar = segmentera(count: count, sr: sr, segment: 3, overlap: 1, fro: fro, maxBuffer: maxBuf)
                let vantat = ClickDetector.segments(count: count, sampleRate: sr, segment: 3, overlap: 1)
                XCTAssertEqual(bitar.map(\.range), vantat, "count \(count), buffert ≤ \(maxBuf)")
                for (k, b) in bitar.enumerated() {
                    XCTAssertEqual(b.samples, b.range.map { Float($0) }, "proven i bit \(k)")
                    XCTAssertEqual(b.innerStart, b.range.lowerBound > 0)
                    XCTAssertEqual(b.innerEnd, b.range.upperBound < count)
                }
            }
        }
    }

    /// Klicken ur en ström i små buffertar är exakt `detectSegmented` på hela signalen
    /// och Pythons bitar (`klick_i_bitar`) på samma prov, även med klick i överlappen
    /// och vid en bitgräns (recepten `lang` och `bitgrans`). METOD MS4
    func testStrommenGerSammaKlickSomHelaSignalenIBitar() throws {
        for namn in ["lang", "bitgrans", "tre_klapp"] {
            let r = try XCTUnwrap(KlickTests.fil.klick.first { $0.namn == namn })
            let x = KlickTests.signal(r)
            var strom = ClickStream(sampleRate: r.sr)
            var rnd = Bitar(s: 7)
            var i = 0
            while i < x.count {
                let n = min(rnd.next(20_000), x.count - i)
                strom.feed(Array(x[i..<(i + n)]))
                i += n
            }
            XCTAssertEqual(strom.sampleCount, x.count)
            let klick = strom.finish()
            let hela = ClickDetector.detectSegmented(x, sampleRate: r.sr)
            XCTAssertEqual(klick, hela, namn)
            XCTAssertEqual(klick.map { KlickTests.prov($0, r.sr) }, r.bitar.map { Int($0[0]) }, namn)
            for (k, p) in zip(klick, r.bitar) {
                XCTAssertEqual(k.strength, p[1], accuracy: 1e-6 * p[1], namn)
            }
        }
    }

    /// Filmens standardtidsskala 600 avrundar 1/240 s till steg om 2 och 3 enheter;
    /// rutnätet är ändå 240 (simulatorprovet S2c gav 300 med percentilen ensam). METOD MS3
    func testRutnatetTalGrovTidsskala() {
        let t = (0..<768).filter { $0 % 3 != 2 }.map { (Double($0) / 240 * 600).rounded() / 600 }
        let f = FrameTiming.analyze(t)
        XCTAssertEqual(f.gridRate, 240)
        XCTAssertEqual(f.missingFraction, 1.0 / 3, accuracy: 0.01)
        let hela = FrameTiming.analyze((0..<768).map { (Double($0) / 240 * 600).rounded() / 600 })
        XCTAssertEqual(hela.gridRate, 240)
        XCTAssertEqual(hela.missingFraction, 0, accuracy: 0.01)
    }

    /// Tider med skakning (±0,3 ms) och var tredje ruta borta: rutnätet 240, inte 260.
    func testRutnatetTalSkakning() {
        var r = Bitar(s: 3)
        let t = (0..<2400).filter { $0 % 3 != 2 }.map { Double($0) / 240 + (Double(r.next(601)) - 301) * 1e-6 }
        XCTAssertEqual(FrameTiming.analyze(t).gridRate, 240)
    }

    func testTomStromGerInget() {
        var s = ClickStream()
        XCTAssertEqual(s.finish(), [])
    }

    // MARK: Passet

    func testUppstallningen() throws {
        XCTAssertEqual(PassSetup.clampDistance(3.2), 3.0)
        XCTAssertEqual(PassSetup.clampDistance(3.3), 3.5)
        XCTAssertEqual(PassSetup.clampDistance(0.1), 1.0)
        XCTAssertEqual(PassSetup.clampDistance(40), 8.0)
        XCTAssertEqual(PassSetup.clampDistance(.nan), 3.0)
        XCTAssertEqual(PassSetup.clubLabel("j7"), "J7")
        XCTAssertEqual(PassSetup.clubLabel("dr"), "Dr")
        XCTAssertTrue(PassSetup.clubs.contains(PassSetup().club))
        XCTAssertEqual(PassSetup().soundDelay, 3.0 / 343, accuracy: 1e-12)
        // Manifestets nycklar (S2_SPEC §8.3).
        let json = String(decoding: try PassCoding.encoder().encode(PassSetup(view: .fo, hand: .vanster)), as: UTF8.self)
        for nyckel in ["\"vy\" : \"fo\"", "\"klubba\" : \"j7\"", "\"avstand_m\" : 3", "\"spelhand\" : \"vanster\""] {
            XCTAssertTrue(json.contains(nyckel), "\(nyckel) saknas i \(json)")
        }
    }

    func facts(transform: [Double] = [0, 1, -1, 0]) -> FileFacts {
        let t = (0..<720).filter { $0 % 3 != 2 }.map { Double($0) / 240 }
        return FileFacts(frameTimes: t, clicks: [Click(time: 1, strength: 80), Click(time: 2.2, strength: 60)],
                         audio: AudioInfo(sampleRate: 48_000, channels: 1, codec: "aac", microphone: "MicrophoneBuiltIn"),
                         transform: transform, storedWidth: 480, storedHeight: 270, bytes: 15_000_000, duration: 3)
    }

    func testSerienUrFilen() {
        let s = SeriesRecord.make(nr: 1, source: .recording, club: "j7", file: PassState.videoPath(nr: 1),
                                  start: Date(timeIntervalSince1970: 0), startHost: 123.5, facts: facts())
        XCTAssertEqual(s.file, "Video/01.mov")
        XCTAssertEqual(s.orientation, 6)
        XCTAssertEqual(s.uprightWidth, 270)
        XCTAssertEqual(s.uprightHeight, 480)
        XCTAssertEqual(s.timing.gridRate, 240)
        XCTAssertEqual(s.timing.missingFraction, 1.0 / 3, accuracy: 0.002)
        XCTAssertEqual(s.megabytesPerMinute, 300, accuracy: 1e-9)
        XCTAssertEqual(s.clicks.count, 2)
        // En okänd längd tas ur rutornas tider.
        var f = facts(transform: [])
        f.duration = .nan
        let u = SeriesRecord.make(nr: 2, source: .photos, club: "j7", file: "Video/02.mov",
                                  start: Date(), startHost: nil, facts: f)
        XCTAssertEqual(u.orientation, 1)
        XCTAssertEqual(u.duration, 718.0 / 240, accuracy: 1e-9)
    }

    func testPassetSparasOchLasesTillbaka() throws {
        let start = Date(timeIntervalSince1970: 1_792_000_000)
        var p = PassState(id: PassID.make(start, timeZone: TimeZone(identifier: "Europe/Stockholm")!),
                          created: start, setup: PassSetup(view: .fo, club: "pw", distance: 2.5, hand: .hoger))
        XCTAssertEqual(p.nextSeriesNumber, 1)
        var s = SeriesRecord.make(nr: p.nextSeriesNumber, source: .recording, club: p.setup.club,
                                  file: PassState.videoPath(nr: 1), start: start, startHost: 81_234.512345, facts: facts())
        s.pressure = .serious
        s.format = CameraFormat(index: 31, width: 1920, height: 1080, maxFrameRate: 240, fieldOfView: 69.4, binned: true,
                                minISO: 34, maxISO: 2176, minExposure: 1.0 / 24_000, maxExposure: 1.0 / 3,
                                tenBit: false, hdrSupported: false)
        s.exposure = ExposureRecord(plan: ExposurePlan(duration: 0.0005, iso: 1250, neededISO: 1250, deficitEV: 0,
                                                       light: .marginal), lensPosition: 0.62, distortionCorrection: true)
        p.series.append(s)
        XCTAssertEqual(p.nextSeriesNumber, 2)
        XCTAssertEqual(p.clickCount, 2)
        let data = try PassCoding.encoder().encode(p)
        let tillbaka = try PassCoding.decoder().decode(PassState.self, from: data)
        XCTAssertEqual(tillbaka, p)
        XCTAssertEqual(tillbaka.format, "swinglab-pass/1")
        XCTAssertEqual(p.entry.series, 1)
        XCTAssertEqual(p.entry.clicks, 2)
    }

    func testPassID() {
        let sthlm = TimeZone(identifier: "Europe/Stockholm")!
        // 2026-10-24 13:30:12 UTC = 15:30:12 svensk sommartid.
        let d = Date(timeIntervalSince1970: 1_792_848_612)
        XCTAssertEqual(PassID.make(d, timeZone: TimeZone(identifier: "UTC")!), "20261024-133012")
        XCTAssertEqual(PassID.make(d, timeZone: sthlm), "20261024-153012")
        XCTAssertEqual(PassID.unique("20261024-153012", taken: []), "20261024-153012")
        XCTAssertEqual(PassID.unique("a", taken: ["a", "a-2"]), "a-3")
        XCTAssertTrue(PassID.isValid("20261024-153012-2"))
        XCTAssertFalse(PassID.isValid("../x"))
        XCTAssertFalse(PassID.isValid(""))
    }

    func testIndexetSenastForst() {
        var i = PassIndex()
        let a = PassIndex.Entry(id: "a", created: Date(timeIntervalSince1970: 10), series: 1, clicks: 3, status: .recorded)
        let b = PassIndex.Entry(id: "b", created: Date(timeIntervalSince1970: 20), series: 0, clicks: 0, status: .recorded)
        i.upsert(a)
        i.upsert(b)
        XCTAssertEqual(i.passes.map(\.id), ["b", "a"])
        var a2 = a
        a2.clicks = 9
        i.upsert(a2)
        XCTAssertEqual(i.passes.map(\.id), ["b", "a"])
        XCTAssertEqual(i.passes.last?.clicks, 9)
    }

    func testLagringen() {
        XCTAssertTrue(PassStorage.canStart(available: 5_000_000_000))
        XCTAssertFalse(PassStorage.canStart(available: 3_999_999_999))
        XCTAssertTrue(PassStorage.canStart(available: nil))
        XCTAssertTrue(AppSettings().keepOriginals, "BESLUT B26 väntar: standard är att behålla")
        XCTAssertFalse(PassStorage.mayDeleteOriginals(keepOriginals: true, status: .exported))
        XCTAssertFalse(PassStorage.mayDeleteOriginals(keepOriginals: false, status: .recorded))
        XCTAssertTrue(PassStorage.mayDeleteOriginals(keepOriginals: false, status: .exported))
    }

    // MARK: Kvittot

    func testKvittot() {
        var s = SeriesRecord.make(nr: 1, source: .recording, club: "j7", file: "Video/01.mov",
                                  start: Date(), startHost: nil, facts: facts())
        s.pressure = .serious
        let r = Receipt.rows(s)
        XCTAssertEqual(r.map(\.label), ["Bilder/s", "Tappade", "Rutor", "Klick", "MB/min", "Längd", "Tryck"])
        XCTAssertEqual(r[0], ReceiptRow("Bilder/s", "240", .good))
        XCTAssertEqual(r[1].value, "33 %")
        XCTAssertEqual(r[1].light, .tooDark)
        XCTAssertEqual(r[2].value, "480")
        XCTAssertEqual(r[3].value, "2")
        XCTAssertEqual(r[4].value, "300")
        XCTAssertEqual(r[5].value, "0:03")
        XCTAssertEqual(r[6], ReceiptRow("Tryck", "högt", .marginal))
        // 120 bilder/s är slowmotion men inte 240: gul. 30 är inte slowmotion: röd.
        XCTAssertEqual(Receipt.rateLight(FrameTiming.analyze((0..<240).map { Double($0) / 120 })), .marginal)
        XCTAssertEqual(Receipt.rateLight(FrameTiming.analyze((0..<90).map { Double($0) / 30 })), .tooDark)
    }

    func testLjusprovetsKort() {
        let format = CameraFormat(index: 0, width: 1920, height: 1080, maxFrameRate: 240, fieldOfView: 70, binned: true,
                                  minISO: 50, maxISO: 2000, minExposure: 1.0 / 24_000, maxExposure: 0.5,
                                  tenBit: false, hdrSupported: false)
        let t = (0..<480).map { Double($0) / 240 }
        let timing = FrameTiming.analyze(t)
        let morkt = Exposure.plan(aeDuration: 1.0 / 2000, aeISO: 2000, aeOffsetEV: -1.3, format: format)
        let c = Flicker.check(exposure: morkt, timing: timing, luma: t.map { _ in 0.3 }, times: t)
        let r = Receipt.rows(c)
        XCTAssertEqual(r[0], ReceiptRow("Ljus", "För mörkt: 1,3 steg", .tooDark))
        XCTAssertEqual(r[1], ReceiptRow("Flimmer", "0 %", .good))
        XCTAssertEqual(r[2], ReceiptRow("Rutor", "240 bilder/s, 0 % tappade", .good))
        XCTAssertEqual(r[3], ReceiptRow("Ljushet", "30 %", .good))
        let ljust = Exposure.plan(aeDuration: 1.0 / 2000, aeISO: 640, aeOffsetEV: 0, format: format)
        let c2 = Flicker.check(exposure: ljust, timing: timing, luma: t.map { _ in 0.3 }, times: t)
        XCTAssertEqual(Receipt.rows(c2)[0], ReceiptRow("ISO", "640", .good))
    }

    func testSvenskaTal() {
        XCTAssertEqual(Swedish.integer(43_776), "43\u{00A0}776")
        XCTAssertEqual(Swedish.integer(2176), "2176")
        XCTAssertEqual(Swedish.integer(-5), "−5")
        XCTAssertEqual(Swedish.decimal(1.26, digits: 1), "1,3")
        XCTAssertEqual(Swedish.decimal(-0.01, digits: 1), "0,0")
        XCTAssertEqual(Swedish.percent(0.0004), "0 %")
        XCTAssertEqual(Swedish.percent(0.0006), "0,1 %")
        XCTAssertEqual(Swedish.percent(0.004), "0,4 %")
        XCTAssertEqual(Swedish.percent(0.123), "12 %")
        XCTAssertEqual(Swedish.percent(0), "0 %")
        XCTAssertEqual(Swedish.duration(182.4), "3:02")
        XCTAssertEqual(Swedish.integer(.nan), "–")
    }

    // MARK: Importen

    func testImportenVagrarEnOmraknadFil() {
        XCTAssertEqual(ImportCheck.original([.fullSizeVideo, .other, .video]), 2)
        XCTAssertNil(ImportCheck.original([.fullSizeVideo]))
        // Oktobers klipp: 240-rutnätet med en tredjedel borta (påhittade tider).
        let slowmo = (0..<2400).filter { $0 % 3 != 2 }.map { Double($0) / 240 }
        XCTAssertEqual(ImportCheck.verdict(FrameTiming.analyze(slowmo)), .accept)
        // Den omräknade: 30 bilder/s.
        XCTAssertEqual(ImportCheck.verdict(FrameTiming.analyze((0..<300).map { Double($0) / 30 })), .notSlowMotion)
        XCTAssertEqual(ImportCheck.verdict(FrameTiming.analyze([0, 1.0 / 240])), .tooFewFrames)
    }

    func testFyraTecken() {
        XCTAssertEqual(FourCC.string(FourCC.code("aac ")), "aac")
        XCTAssertEqual(FourCC.string(FourCC.code("lpcm")), "lpcm")
        XCTAssertEqual(FourCC.code("x420"), 0x7834_3230)
        XCTAssertTrue(FourCC.isTenBit(FourCC.code("x420")))
        XCTAssertTrue(FourCC.isTenBit(FourCC.code("xf22")))
        XCTAssertFalse(FourCC.isTenBit(FourCC.code("420f")))
    }

    func testTrycketOrdnat() {
        XCTAssertLessThan(Pressure.fair, Pressure.serious)
        XCTAssertFalse(Pressure.fair.warns)
        XCTAssertTrue(Pressure.serious.warns)
        XCTAssertEqual([Pressure.nominal, .critical, .fair].max(), .critical)
    }
}
