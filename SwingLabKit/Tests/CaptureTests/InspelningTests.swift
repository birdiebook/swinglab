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
    static func skala600(_ i: Int) -> Double {
        let enheter = (Double(i) * 2.5).rounded()
        return enheter / 600
    }

    func testRutnatetTalGrovTidsskala() {
        let t = (0..<768).filter { $0 % 3 != 2 }.map(Self.skala600)
        let f = FrameTiming.analyze(t)
        XCTAssertEqual(f.gridRate, 240)
        XCTAssertEqual(f.missingFraction, 1.0 / 3, accuracy: 0.01)
        let hela = FrameTiming.analyze((0..<768).map(Self.skala600))
        XCTAssertEqual(hela.gridRate, 240)
        XCTAssertEqual(hela.missingFraction, 0, accuracy: 0.01)
    }

    /// Tider med skakning (±0,3 ms) och var tredje ruta borta: rutnätet 240, inte 260.
    func testRutnatetTalSkakning() {
        var r = Bitar(s: 3)
        var t: [Double] = []
        for i in 0..<2400 where i % 3 != 2 {
            let skak = Double(r.next(601) - 301) * 1e-6
            t.append(Double(i) / 240 + skak)
        }
        XCTAssertEqual(FrameTiming.analyze(t).gridRate, 240)
    }

    /// Rutornas tider som `tools/pc/tre_d/kamera.py` `bildtider`: 240-rutnätet med
    /// slumpad fas och tappade rutor i skurar (Markovkedja), avrundade till tidsskalan
    /// och med likformig skakning. Påhittade tider.
    struct Slump {
        var s: UInt64
        mutating func u() -> Double {
            s = s &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(s >> 11) / Double(UInt64(1) << 53)
        }
    }

    static func skurtider(sekunder: Double, tapp: Double, skur: Double, skala: Double?, skak: Double = 0,
                          fro: UInt64, rate: Double = 240) -> [Double] {
        var r = Slump(s: fro)
        let n = Int(sekunder * 240)
        let fas = r.u() / rate
        let b = 1 / skur
        let a = tapp * b / (1 - tapp)
        var kvar = r.u() > tapp
        var ut: [Double] = []
        for k in 0..<n {
            if kvar {
                var t = Double(k) / rate + fas
                t += skak * (2 * r.u() - 1)
                if let skala { t = (t * skala).rounded() / skala }
                ut.append(t)
            }
            kvar = kvar ? r.u() > a : r.u() < b
        }
        return ut
    }

    /// Skurar av tappade rutor i tidsskalan 600: 0,5 s, 3 s och 10 s med 36 % (skurar om
    /// 1,5) och 60 % (skurar om 2 och 5) ger 240 i 50 av 50 (granskningen fick 229–249
    /// utan förfiningen). Skakning ±0,3 ms likaså. METOD MS3
    func testRutnatetVidSkurarAvTappadeRutor() {
        let fall: [(Double, Double, Double, Double?, Double)] = [
            (0.5, 0.36, 1.5, 600, 0), (3, 0.36, 1.5, 600, 0), (10, 0.36, 1.5, 600, 0),
            (10, 0.6, 2, 600, 0), (3, 0.6, 5, 600, 0), (3, 0.36, 1.5, nil, 0.0003), (3, 0.36, 1.5, 600, 0.0003),
        ]
        for (sek, tapp, skur, skala, skak) in fall {
            for fro in UInt64(1)...50 {
                let t = Self.skurtider(sekunder: sek, tapp: tapp, skur: skur, skala: skala, skak: skak, fro: fro)
                let f = FrameTiming.analyze(t)
                XCTAssertEqual(f.gridRate, 240, "\(sek) s, \(tapp) tappade, skurar \(skur), skala \(skala ?? 0), frö \(fro)")
                XCTAssertEqual(f.missingFraction, tapp, accuracy: sek < 1 ? 0.25 : 0.1)
            }
        }
    }

    /// Johannes första import (2026-10-22) visade 239 på ett 240-original. Rutnätsregeln
    /// svarade den uppmätta klockan avrundad, och en klocka som går 0,25 % långsamt
    /// (239,4) avrundas till 239. Nu: den kända frekvensen inom ±1 % när rutorna passar
    /// den, och den uppmätta klockan bredvid. Drift (239,4, 238,5, 241,5), skakning
    /// (likformig ±0,5 ms, och ±0,8 ms utan grov tidsskala), tidsskalorna 600 och 90 000,
    /// 3 s och 9 s, 36 % tappade i skurar: 240 i alla. METOD MS3
    func testKlockanSomGarFelGerAnda240() {
        let skalor: [Double?] = [nil, 600, 90_000]
        for rate in [240, 239.4, 238.5, 241.5] {
            for skala in skalor {
                for skak in skala == 600 ? [0, 0.0005] : [0, 0.0005, 0.0008] {
                    for sek in [3.0, 9.0] {
                        for fro in UInt64(1)...20 {
                            let t = Self.skurtider(sekunder: sek, tapp: 0.36, skur: 1.5, skala: skala, skak: skak,
                                                   fro: fro, rate: rate)
                            let f = FrameTiming.analyze(t)
                            let fall = "klocka \(rate), skala \(skala ?? 0), skak \(skak), \(sek) s, frö \(fro)"
                            XCTAssertEqual(f.gridRate, 240, fall)
                            XCTAssertEqual(f.missingFraction, 0.36, accuracy: 0.1, fall)
                            if skak == 0 { XCTAssertEqual(f.measuredRate ?? 0, rate, accuracy: 0.05, fall) }
                        }
                    }
                }
            }
        }
        // Som Johannes klipp: 9 s med en tredjedel borta, klockan 239,4 i tidsskalan 600.
        let t = Self.skurtider(sekunder: 9, tapp: 0.36, skur: 1.5, skala: 600, fro: 3, rate: 239.4)
        let f = FrameTiming.analyze(t)
        XCTAssertEqual(t.count, 1356)
        XCTAssertEqual(f.gridRate, 240)
        XCTAssertEqual(f.measuredRate ?? 0, 239.4, accuracy: 0.01)
        XCTAssertEqual(Receipt.rateText(f), "240 (239.4)")
        XCTAssertEqual(f.missingFraction, 0.37, accuracy: 0.01)
        // Den gamla regeln (de korta stegen, förfinade, avrundade) gav 239 på samma tider.
        let steg = zip(t.dropFirst(), t).map { $0 - $1 }.filter { $0 > 0 }.sorted()
        let p = FrameTiming.percentile(steg, FrameTiming.gridPercentile)
        let korta = steg.filter { $0 <= FrameTiming.shortStepFactor * p }
        let gammal = FrameTiming.refine(Double(korta.count) / korta.reduce(0, +), steps: steg, span: t.last! - t.first!)
        XCTAssertEqual(gammal.rounded(), 239)
    }

    /// Andra kända frekvenser och klockor nära dem (29,97, 119,88) ger den kända; en film
    /// i en frekvens utanför listan behåller sitt rutnät, och en multipel tas inte (40 är
    /// inte 120 med två tredjedelar tappade). METOD MS3
    func testKandaFrekvenserOchAndra() {
        let fall: [(Double, Double)] = [(30, 30), (29.97, 30), (60, 60), (120, 120), (119.88, 120), (25, 25),
                                        (24, 24), (200, 200), (90, 90), (40, 40), (300, 300)]
        for (klocka, grid) in fall {
            for skala in [nil, 600] as [Double?] {
                for fro in UInt64(1)...10 {
                    let t = Self.skurtider(sekunder: 3, tapp: 0.36, skur: 1.5, skala: skala, fro: fro, rate: klocka)
                    let f = FrameTiming.analyze(t)
                    XCTAssertEqual(f.gridRate, grid, "klocka \(klocka), skala \(skala ?? 0), frö \(fro)")
                    XCTAssertEqual(f.measuredRate ?? 0, klocka, accuracy: 0.02, "klocka \(klocka), skala \(skala ?? 0)")
                }
            }
        }
        // Exakt på rutnätet: ingen parentes i kvittot.
        let jamn = FrameTiming.analyze((0..<480).map { Double($0) / 240 })
        XCTAssertEqual(Receipt.rateText(jamn), "240")
    }

    /// Kvittots "Dropped" efter källan: en egen inspelning varnar från 1 %, ett importerat
    /// Kamera-original (30–40 % är det normala) först över 45 %. METOD MS11
    func testTappadeRutorEfterKallan() {
        var s = SeriesRecord.make(nr: 1, source: .photos, club: "j7", file: "Video/01.mov",
                                  start: Date(), startHost: nil, facts: facts())
        s.timing.missingFraction = 0.36
        XCTAssertEqual(Receipt.rows(s)[1], ReceiptRow("Dropped", "36%", .good))
        s.timing.missingFraction = 0.50
        XCTAssertEqual(Receipt.rows(s)[1].light, .marginal)
        s.timing.missingFraction = 0.60
        XCTAssertEqual(Receipt.rows(s)[1].light, .tooDark)
        s.source = .recording
        s.timing.missingFraction = 0.36
        XCTAssertEqual(Receipt.rows(s)[1].light, .tooDark)
        s.timing.missingFraction = 0.005
        XCTAssertEqual(Receipt.rows(s)[1].light, .good)
        XCTAssertEqual(Flicker.grade(importMissing: 0.45), .good)
        XCTAssertEqual(Flicker.grade(importMissing: 0.55), .marginal)
        XCTAssertEqual(Flicker.grade(importMissing: .nan), .tooDark)
    }

    func testTomStromGerInget() {
        var s = ClickStream()
        XCTAssertEqual(s.finish(), [])
    }

    /// Luckor och överlapp i ljudets buffertar, och längden ur spåret. METOD MS11
    func testLjudetsTidslinje() {
        // En buffert som börjar 0,1 s för sent: 4 800 nollor först.
        XCTAssertEqual(AudioTimeline.correction(first: 0, count: 48_000, bufferStart: 1.1), 4800)
        // Avrundning inom 1 ms är ingen lucka.
        XCTAssertEqual(AudioTimeline.correction(first: 0.02, count: 48_000, bufferStart: 1.0205), 0)
        // Ett överlapp: hoppa över 960 prov.
        XCTAssertEqual(AudioTimeline.correction(first: 0, count: 48_000, bufferStart: 0.98), -960)
        XCTAssertEqual(AudioTimeline.correction(first: .nan, count: 0, bufferStart: 1), 0)
        XCTAssertEqual(AudioTimeline.length(first: 0, trackEnd: 3.2), 153_600)
        XCTAssertEqual(AudioTimeline.length(first: 0.5, trackEnd: 0.5 + 1.0 / 48_000 * 10.5), 10)
        XCTAssertNil(AudioTimeline.length(first: 1, trackEnd: .nan))
        XCTAssertNil(AudioTimeline.length(first: 1, trackEnd: 0.5))
    }

    // MARK: Passet

    func testUppstallningen() throws {
        XCTAssertEqual(PassSetup.clampDistance(3.2), 3.0)
        XCTAssertEqual(PassSetup.clampDistance(3.3), 3.5)
        XCTAssertEqual(PassSetup.clampDistance(0.1), 1.0)
        XCTAssertEqual(PassSetup.clampDistance(40), 8.0)
        XCTAssertEqual(PassSetup.clampDistance(.nan), 3.0)
        // Engelska etiketter (BESLUT B30), manifestets id oförändrade.
        XCTAssertEqual(PassSetup.clubLabel("j7"), "7i")
        XCTAssertEqual(PassSetup.clubLabel("t3"), "3W")
        XCTAssertEqual(PassSetup.clubLabel("h4"), "4H")
        XCTAssertEqual(PassSetup.clubLabel("pw"), "PW")
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
        XCTAssertEqual(r.map(\.label), ["fps", "Dropped", "Frames", "Clicks", "MB/min", "Length", "Heat"])
        XCTAssertEqual(r[0], ReceiptRow("fps", "240", .good))
        XCTAssertEqual(r[1].value, "33%")
        XCTAssertEqual(r[1].light, .tooDark)
        XCTAssertEqual(r[2].value, "480")
        XCTAssertEqual(r[3].value, "2")
        XCTAssertEqual(r[4].value, "300")
        XCTAssertEqual(r[5].value, "0:03")
        XCTAssertEqual(r[6], ReceiptRow("Heat", "serious", .marginal))
        // Inga svenska tecken i det kvittot visar (BESLUT B30).
        for p in Pressure.allCases { XCTAssertNil(Receipt.pressureName(p).rangeOfCharacter(from: Self.svenska), "\(p)") }
        for rad in r { XCTAssertNil((rad.label + rad.value).rangeOfCharacter(from: Self.svenska), rad.label) }
        XCTAssertNil(ImportCheck.refusal.rangeOfCharacter(from: Self.svenska))
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
        XCTAssertEqual(r[0], ReceiptRow("Light", "Too dark: 1.3 stops", .tooDark))
        XCTAssertEqual(r[1], ReceiptRow("Flicker", "0%", .good))
        XCTAssertEqual(r[2], ReceiptRow("Frames", "240 fps, 0% dropped", .good))
        XCTAssertEqual(r[3], ReceiptRow("Brightness", "30%", .good))
        for rad in r { XCTAssertNil((rad.label + rad.value).rangeOfCharacter(from: Self.svenska), rad.label) }
        let ljust = Exposure.plan(aeDuration: 1.0 / 2000, aeISO: 640, aeOffsetEV: 0, format: format)
        let c2 = Flicker.check(exposure: ljust, timing: timing, luma: t.map { _ in 0.3 }, times: t)
        XCTAssertEqual(Receipt.rows(c2)[0], ReceiptRow("ISO", "640", .good))
    }

    /// Å, ä och ö: får inte stå i något som appen visar (BESLUT B30).
    static let svenska = CharacterSet(charactersIn: "åäöÅÄÖ")

    func testTalPaEngelska() {
        XCTAssertEqual(Taltext.integer(43_776), "43,776")
        XCTAssertEqual(Taltext.integer(2176), "2176")
        XCTAssertEqual(Taltext.integer(-5), "−5")
        XCTAssertEqual(Taltext.decimal(1.26, digits: 1), "1.3")
        XCTAssertEqual(Taltext.decimal(-0.01, digits: 1), "0.0")
        XCTAssertEqual(Taltext.decimal(-2.4, digits: 1), "−2.4")
        XCTAssertEqual(Taltext.percent(0.0004), "0%")
        XCTAssertEqual(Taltext.percent(0.0006), "0.1%")
        XCTAssertEqual(Taltext.percent(0.004), "0.4%")
        XCTAssertEqual(Taltext.percent(0.123), "12%")
        XCTAssertEqual(Taltext.percent(0), "0%")
        XCTAssertEqual(Taltext.duration(182.4), "3:02")
        XCTAssertEqual(Taltext.integer(.nan), "–")
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
