// SIMULATORPROVET FÖR INSPELNINGEN OCH IMPORTEN (S2_SPEC §10.2 steg 1–5, §12 S2c–S2d).
// Kameran finns inte i simulatorn. Provet skriver därför en egen PÅHITTAD film med
// AVAssetWriter (CLAUDE.md, Dataregeln): H.264 480 × 270 lagrat med 90° i
// transformen, 240 bilder/s på rutnätet med var tredje ruta utelämnad, en vit ruta
// vid 1,000 s och 2,200 s, och ljud med ett klick (5 ms brus) på samma tider. Sedan
// kör det appens egen MediaReader, klickjakt, kvitto, ljusprovets läsning, lagring
// och importens kontroll på den. Allt utom kameran och Bilder är alltså bevisat här.
//
// PROV-raderna i loggen samlas i resultat/<sha>.kompilera.txt, och kvittot ritas
// till /tmp/swinglab_prov/kvitto.png (kompilera.yml lägger det på ci-resultat).

import XCTest
import AVFoundation
import CoreMedia
import CoreVideo
import SwiftUI
import Swing
import Capture
@testable import SwingLab

/// Den påhittade filmen. METOD MS3, MS4, MS7
enum SyntheticMovie {
    enum Sound {
        /// 48 kHz mono 16-bitars LPCM: inget att omsampla, klicket på provet.
        case lpcm
        /// AAC 44,1 kHz stereo: prövar omsamplingen till 48 kHz, nedmixningen och AAC:s priming.
        case aac
        /// Inget ljudspår.
        case none
    }

    /// Klicken och de vita rutorna, s.
    static let flashes = [1.000, 2.200]

    static func write(to url: URL, sound: Sound, rate: Int = 240, dropEveryThird: Bool = true,
                      seconds: Double = 3.2) async throws {
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let w = 480, h = 270
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: w,
            AVVideoHeightKey: h,
            AVVideoCompressionPropertiesKey: [
                AVVideoAllowFrameReorderingKey: false,
                AVVideoAverageBitRateKey: 4_000_000,
            ] as [String: Any],
        ])
        video.expectsMediaDataInRealTime = false
        // Stående som kamerans filer: (0, 1, −1, 0) → EXIF 6 (METOD MS7).
        video.transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: CGFloat(h), ty: 0)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: w,
            kCVPixelBufferHeightKey as String: h,
        ])
        guard writer.canAdd(video) else { throw ProvFel("videon går inte att lägga till") }
        writer.add(video)

        let audioRate: Double = sound == .aac ? 44_100 : 48_000
        let channels = sound == .aac ? 2 : 1
        var audio: AVAssetWriterInput?
        if sound != .none {
            let settings: [String: Any] = sound == .aac
                ? [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: audioRate, AVNumberOfChannelsKey: channels,
                   AVEncoderBitRateKey: 128_000]
                : [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: audioRate, AVNumberOfChannelsKey: channels,
                   AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
                   AVLinearPCMIsNonInterleaved: false]
            let a = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
            a.expectsMediaDataInRealTime = false
            guard writer.canAdd(a) else { throw ProvFel("ljudet går inte att lägga till") }
            writer.add(a)
            audio = a
        }

        guard writer.startWriting() else { throw writer.error ?? ProvFel("startWriting") }
        writer.startSession(atSourceTime: .zero)

        // Rutorna.
        let n = Int(seconds * Double(rate))
        let vita = Set(flashes.map { Int(($0 * Double(rate)).rounded()) })
        var i = 0
        let nextFrame: () -> Bool = {
            while i < n, dropEveryThird, i % 3 == 2 { i += 1 }
            guard i < n, let pool = adaptor.pixelBufferPool else { return false }
            var pb: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb) == kCVReturnSuccess, let pb else { return false }
            fill(pb, value: vita.contains(i) ? 255 : 128)
            let ok = adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: CMTimeScale(rate)))
            i += 1
            return ok
        }

        // Ljudet: LCG-brus ±0,001 och klicket som 5 ms brus med amplituden 0,5 (S2_SPEC §10.2).
        let total = Int(seconds * audioRate)
        var signal = [Int16](repeating: 0, count: total * channels)
        var s: UInt64 = 1
        func lcg() -> Double {
            s = (1_103_515_245 &* s &+ 12345) % 2_147_483_648
            return 2 * Double(s) / 2_147_483_648 - 1
        }
        let klick = flashes.map { Int(($0 * audioRate).rounded()) }
        let skur = Int(0.005 * audioRate)
        for k in 0..<total {
            var x = lcg() * 0.001
            if klick.contains(where: { k >= $0 && k < $0 + skur }) { x = lcg() * 0.5 }
            let v = Int16(max(-32767, min(32767, (x * 32767).rounded())))
            for c in 0..<channels { signal[k * channels + c] = v }
        }
        var asbd = AudioStreamBasicDescription(
            mSampleRate: audioRate, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: UInt32(2 * channels), mFramesPerPacket: 1, mBytesPerFrame: UInt32(2 * channels),
            mChannelsPerFrame: UInt32(channels), mBitsPerChannel: 16, mReserved: 0)
        var format: CMAudioFormatDescription?
        let fs = CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &asbd, layoutSize: 0, layout: nil,
                                                magicCookieSize: 0, magicCookie: nil, extensions: nil,
                                                formatDescriptionOut: &format)
        guard fs == noErr, let format else { throw ProvFel("ljudformatet") }
        var pos = 0
        let nextAudio: () -> Bool = {
            guard pos < total, let a = audio else { return false }
            let frames = min(1024, total - pos)
            let bytes = frames * channels * 2
            var block: CMBlockBuffer?
            guard CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: bytes,
                                                     blockAllocator: kCFAllocatorDefault, customBlockSource: nil,
                                                     offsetToData: 0, dataLength: bytes,
                                                     flags: kCMBlockBufferAssureMemoryNowFlag,
                                                     blockBufferOut: &block) == kCMBlockBufferNoErr,
                  let block else { return false }
            let st = signal.withUnsafeBytes { raw in
                CMBlockBufferReplaceDataBytes(with: raw.baseAddress! + pos * channels * 2, blockBuffer: block,
                                              offsetIntoDestination: 0, dataLength: bytes)
            }
            guard st == kCMBlockBufferNoErr else { return false }
            var sb: CMSampleBuffer?
            guard CMAudioSampleBufferCreateReadyWithPacketDescriptions(
                allocator: kCFAllocatorDefault, dataBuffer: block, formatDescription: format,
                sampleCount: frames, presentationTimeStamp: CMTime(value: CMTimeValue(pos), timescale: CMTimeScale(audioRate)),
                packetDescriptions: nil, sampleBufferOut: &sb) == noErr, let sb else { return false }
            pos += frames
            return a.append(sb)
        }

        // Båda spåren matas samtidigt: skrivaren flätar dem och väntar annars på det andra.
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            let group = DispatchGroup()
            pump(video, "prov.video", nextFrame, group)
            if let audio { pump(audio, "prov.ljud", nextAudio, group) }
            group.notify(queue: .global()) { c.resume() }
        }
        await writer.finishWriting()
        if writer.status != .completed { throw writer.error ?? ProvFel("finishWriting") }
    }

    /// Fyller en BGRA-ruta med samma grå nivå.
    static func fill(_ pb: CVPixelBuffer, value: UInt8) {
        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }
        guard let base = CVPixelBufferGetBaseAddress(pb) else { return }
        let bytes = CVPixelBufferGetBytesPerRow(pb) * CVPixelBufferGetHeight(pb)
        memset(base, Int32(value), bytes)
    }

    /// Matar en ingång tills `next` svarar false, sedan markAsFinished.
    static func pump(_ input: AVAssetWriterInput, _ label: String, _ next: @escaping () -> Bool,
                     _ group: DispatchGroup) {
        group.enter()
        var klar = false
        input.requestMediaDataWhenReady(on: DispatchQueue(label: label)) {
            while !klar && input.isReadyForMoreMediaData {
                if !next() {
                    klar = true
                    input.markAsFinished()
                    group.leave()
                }
            }
        }
    }
}

struct ProvFel: Error, CustomStringConvertible {
    let description: String
    init(_ d: String) { description = d }
}

@MainActor
final class SwingLabProvInspelning: XCTestCase {
    static let ut = "/tmp/swinglab_prov"

    func tmp(_ namn: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: "swinglab-prov", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: namn)
    }

    // MARK: Steg 1–5

    /// Steg 1–5 med LPCM: rutnätet och hålen, orienteringen, klicken inom 1 ms, de vita
    /// rutorna på klicken, och att ljudet klipps exakt vid bitarnas prov.
    func testFilmenMedLPCM() async throws {
        let url = try tmp("lpcm.mov")
        try await SyntheticMovie.write(to: url, sound: .lpcm)

        // Steg 2: rutornas tider.
        let times = try await MediaReader.frameTimes(url)
        let timing = FrameTiming.analyze(times)
        var steg: [Int: Int] = [:]
        for (x, y) in zip(times, times.dropFirst()) { steg[Int(((y - x) * 1e5).rounded()), default: 0] += 1 }
        print("PROV: lpcm första tiderna \(times.prefix(12).map { String(format: "%.6f", $0) })")
        print("PROV: lpcm stegen i 10 µs: \(steg.sorted { $0.key < $1.key }.map { "\($0.key)×\($0.value)" })")
        print("PROV: lpcm rutor \(timing.count), rutnät \(timing.gridRate), saknas \(timing.missingFraction), "
              + "största hål \(timing.largestGap)")
        XCTAssertEqual(timing.gridRate, 240)
        XCTAssertEqual(timing.missingFraction, 1.0 / 3, accuracy: 0.01)
        XCTAssertEqual(timing.largestGap, 2.0 / 240, accuracy: 1e-4)
        XCTAssertTrue(timing.isSlowMotion)

        // Steg 3: orienteringen.
        let geo = try await MediaReader.geometry(url)
        let upp = Orientation.uprightSize(width: geo.width, height: geo.height, exif: geo.exif)
        print("PROV: lpcm transform (\(geo.a), \(geo.b), \(geo.c), \(geo.d)) \(geo.width)×\(geo.height) → exif \(geo.exif)")
        XCTAssertEqual(geo.exif, 6)
        XCTAssertEqual(upp.width, 270)
        XCTAssertEqual(upp.height, 480)

        // Steg 4: klicken.
        let klick = try await MediaReader.clicks(url)
        print("PROV: lpcm klick \(klick.map { String(format: "%.5f (%.0f)", $0.time, $0.strength) })")
        XCTAssertEqual(klick.count, 2)
        for (k, t) in zip(klick, SyntheticMovie.flashes) {
            XCTAssertEqual(k.time, t, accuracy: 0.001, "klicket vid \(t)")
        }
        try await provaBitarna(url, namn: "lpcm")

        // Steg 4b: ljudets format ur filen.
        let lastInfo = try await MediaReader.audioInfo(url)
        let info = try XCTUnwrap(lastInfo)
        XCTAssertEqual(info.sampleRate, 48_000)
        XCTAssertEqual(info.channels, 1)
        XCTAssertEqual(info.codec, "lpcm")

        // Steg 5: de vita rutorna ligger på klicken inom en ruta.
        let l = try await MediaReader.luma(url)
        XCTAssertEqual(l.times.count, timing.count)
        let vita = zip(l.times, l.luma).filter { $0.1 > 0.8 }.map(\.0)
        let gra = l.luma.filter { $0 < 0.8 }
        print("PROV: lpcm vita rutor \(vita), grå medel \(gra.reduce(0, +) / Double(max(1, gra.count)))")
        XCTAssertEqual(vita.count, 2)
        for (v, k) in zip(vita, klick) {
            XCTAssertEqual(v, k.time, accuracy: 1.0 / 240 + 0.001, "bild och ljud på samma tidslinje")
        }
        XCTAssertEqual(gra.reduce(0, +) / Double(max(1, gra.count)), 128.0 / 255, accuracy: 0.05)
    }

    /// Steg 4 med AAC 44,1 kHz stereo: omsamplingen till 48 kHz mono och AAC:s
    /// redigeringslista (priming). Klicken inom 3 ms.
    func testFilmenMedAAC() async throws {
        let url = try tmp("aac.mov")
        try await SyntheticMovie.write(to: url, sound: .aac)
        let klick = try await MediaReader.clicks(url)
        print("PROV: aac klick \(klick.map { String(format: "%.5f (%.0f)", $0.time, $0.strength) })")
        XCTAssertEqual(klick.count, 2)
        for (k, t) in zip(klick, SyntheticMovie.flashes) {
            XCTAssertEqual(k.time, t, accuracy: 0.003, "klicket vid \(t)")
        }
        let lastInfo = try await MediaReader.audioInfo(url)
        let info = try XCTUnwrap(lastInfo)
        print("PROV: aac i filen \(info.codec) \(info.sampleRate) Hz \(info.channels) kanaler")
        XCTAssertEqual(info.codec, "aac")
        XCTAssertEqual(info.channels, 2)
        try await provaBitarna(url, namn: "aac")
    }

    /// Ljudet ur filen klipps vid `ClickDetector.segments`-proven: med små bitar (1 s,
    /// 0,5 s överlapp) har läsarens bitar samma gränser som `segments` för det antal prov
    /// läsningen gav, samma prov i överlappen, och samma klick som `detectSegmented` på
    /// hela ljudet. Hela ljudet sätts ihop ur samma läsning: ett omsamplat ljud (AAC) kan
    /// ge ett prov mer eller mindre i en annan läsning. METOD MS4, MS11
    func provaBitarna(_ url: URL, namn: String) async throws {
        var bitar: [AudioSegmenter.Segment] = []
        let lasning = try await MediaReader.audio(url, segment: 1.0, overlap: 0.5) { bitar.append($0) }
        let read = try XCTUnwrap(lasning)
        let forsta = read.first
        var alla: [Float] = []
        for b in bitar where b.range.upperBound > alla.count {
            XCTAssertLessThanOrEqual(b.range.lowerBound, alla.count, "ett hål mellan bitarna")
            let overlapp = alla.count - b.range.lowerBound
            XCTAssertEqual(Array(b.samples.prefix(overlapp)), Array(alla.suffix(overlapp)), "överlappet i \(b.range)")
            alla.append(contentsOf: b.samples.dropFirst(overlapp))
        }
        print("PROV: \(namn) ljud \(alla.count) prov à 48 kHz (spåret \(read.length ?? -1)), första provet \(forsta) s, "
              + "\(bitar.count) bitar, luckor \(read.gaps) (\(read.filled) fyllda, \(read.skipped) överhoppade)")
        XCTAssertEqual(Double(alla.count), 3.2 * 48_000, accuracy: 2048, "omsamplat till 48 kHz mono")
        XCTAssertEqual(alla.count, read.samples)
        XCTAssertEqual(read.samples, read.length, "lika många prov som spåret, varje läsning")
        let igen = try await MediaReader.readAudio(url) { _ in }
        XCTAssertEqual(igen?.samples, read.samples, "en andra läsning ger lika många prov")
        XCTAssertEqual(bitar.map(\.range),
                       ClickDetector.segments(count: alla.count, sampleRate: 48_000, segment: 1.0, overlap: 0.5))
        for b in bitar {
            XCTAssertEqual(b.samples.count, b.range.count)
            XCTAssertEqual(b.innerStart, b.range.lowerBound > 0)
            XCTAssertEqual(b.innerEnd, b.range.upperBound < alla.count)
        }
        let urBitarna = ClickDetector.merge(bitar.map { b in
            (start: Double(b.range.lowerBound) / 48_000,
             clicks: ClickDetector.detect(b.samples, innerStart: b.innerStart, innerEnd: b.innerEnd))
        })
        XCTAssertEqual(urBitarna, ClickDetector.detectSegmented(alla, segment: 1.0, overlap: 0.5))
        XCTAssertEqual(urBitarna.count, 2)
        // Appens klickjakt i samma små bitar, i en egen läsning: samma klick inom ett prov.
        let iBitar = try await MediaReader.clicks(url, segment: 1.0, overlap: 0.5)
        XCTAssertEqual(iBitar.count, urBitarna.count)
        for (a, b) in zip(iBitar, urBitarna) { XCTAssertEqual(a.time, forsta + b.time, accuracy: 1.5 / 48_000) }
    }

    /// En lucka i ljudet: en komposition av den påhittade filmen där ljudet saknas
    /// 1,50–1,60 s (en tom redigering, som när telefonen tappar ljud). AVAssetWriter kan
    /// inte skriva en sådan lucka i LPCM (den lägger proven i följd: klicket hamnade på
    /// 2,114 s). Klicket efter luckan ligger ändå inom 1 ms från 2,200 s, eftersom varje
    /// buffert läggs på sin egen tid, och längden är spårets. METOD MS11
    func testLuckaILjudet() async throws {
        let kalla = try tmp("lucka-kalla.mov")
        try await SyntheticMovie.write(to: kalla, sound: .lpcm)
        let asset = AVURLAsset(url: kalla)
        let ljudspar = try await asset.loadTracks(withMediaType: .audio)
        let ljud = try XCTUnwrap(ljudspar.first)
        let comp = AVMutableComposition()
        let spar = try XCTUnwrap(comp.addMutableTrack(withMediaType: .audio,
                                                      preferredTrackID: kCMPersistentTrackID_Invalid))
        func tid(_ s: Double) -> CMTime { CMTime(value: CMTimeValue((s * 48_000).rounded()), timescale: 48_000) }
        try spar.insertTimeRange(CMTimeRange(start: .zero, end: tid(1.5)), of: ljud, at: .zero)
        spar.insertEmptyTimeRange(CMTimeRange(start: tid(1.5), end: tid(1.6)))
        try spar.insertTimeRange(CMTimeRange(start: tid(1.6), end: tid(3.2)), of: ljud, at: tid(1.6))

        let lasning = try await MediaReader.readAudio(asset: comp) { _ in }
        let read = try XCTUnwrap(lasning)
        let klick = try await MediaReader.clicks(asset: comp)
        print("PROV: lucka luckor \(read.gaps), \(read.filled) prov fyllda, \(read.skipped) överhoppade, "
              + "\(read.samples) prov (spåret \(read.length ?? -1)); klick \(klick.map { String(format: "%.5f", $0.time) })")
        XCTAssertEqual(klick.count, 2)
        for (k, t) in zip(klick, SyntheticMovie.flashes) {
            XCTAssertEqual(k.time, t, accuracy: 0.001, "klicket vid \(t), efter luckan")
        }
        XCTAssertEqual(read.samples, read.length)
        XCTAssertEqual(Double(read.samples), 3.2 * 48_000, accuracy: 1100)
    }

    // MARK: Kvittot och ljusprovet

    /// Appens egen väg från fil till kvitto (samma som efter en inspelad serie), och
    /// kvittot ritat till kvitto.png.
    func testKvittotUrFilen() async throws {
        let url = try tmp("kvitto.mov")
        try await SyntheticMovie.write(to: url, sound: .lpcm)
        let s = try await SeriesMaker.make(url: url, nr: 1, file: "Video/01.mov", source: .recording, club: "j7",
                                           start: Date(), startHost: nil, microphone: "MicrophoneBuiltIn")
        let rader = Receipt.rows(s)
        print("PROV: kvitto " + rader.map { "\($0.label) \($0.value)" }.joined(separator: " · "))
        XCTAssertEqual(rader.first { $0.label == "fps" }?.value, "240")
        XCTAssertEqual(rader.first { $0.label == "Clicks" }?.value, "2")
        XCTAssertEqual(rader.first { $0.label == "Dropped" }?.value, "33%")
        XCTAssertEqual(s.orientation, 6)
        XCTAssertGreaterThan(s.bytes, 0)
        XCTAssertEqual(s.duration, 3.2, accuracy: 0.05)

        let bild = ReceiptCard(title: String(localized: "Set \(1)"), rows: rader)
            .frame(width: 360)
            .padding(20)
            .background(Theme.ground)
            .environment(\.colorScheme, .dark)
        let r = ImageRenderer(content: bild)
        r.scale = 2
        let png = try XCTUnwrap(r.uiImage?.pngData())
        try FileManager.default.createDirectory(atPath: Self.ut, withIntermediateDirectories: true)
        try png.write(to: URL(fileURLWithPath: Self.ut + "/kvitto.png"))
    }

    /// Ljusprovets läsning (allt utom kameran): rutnätet, tappade rutor och flimret.
    func testLjusprovetsLasning() async throws {
        let url = try tmp("ljusprov.mov")
        try await SyntheticMovie.write(to: url, sound: .none, seconds: 2)
        let format = CameraFormat(index: 0, width: 1920, height: 1080, maxFrameRate: 240, fieldOfView: 70, binned: true,
                                  minISO: 50, maxISO: 2000, minExposure: 1.0 / 24_000, maxExposure: 0.5,
                                  tenBit: false, hdrSupported: false)
        let plan = Exposure.plan(aeDuration: 1.0 / 2000, aeISO: 800, aeOffsetEV: 0, format: format)
        let c = try await LightProbe.analyze(url, exposure: plan)
        print("PROV: ljusprov " + Receipt.rows(c).map { "\($0.label) \($0.value) \($0.light)" }.joined(separator: " · "))
        XCTAssertEqual(c.timing.gridRate, 240)
        XCTAssertEqual(c.timing.missingFraction, 1.0 / 3, accuracy: 0.01)
        XCTAssertEqual(c.verdict, .tooDark, "en tredjedel tappade rutor är rött")
        XCTAssertTrue(c.flicker100.isFinite && c.flicker120.isFinite)
        XCTAssertEqual(c.meanLuma, 128.0 / 255, accuracy: 0.06)
    }

    // MARK: Importen och lagringen

    /// Importens kontroll (S2_SPEC §5 steg 6): en omräknad fil (30 bilder/s) tas bort
    /// och vägras; originalet (240-rutnätet) godtas. BESLUT B24
    func testImportenVagrarDenOmraknade() async throws {
        let omraknad = try tmp("omraknad.mov")
        try await SyntheticMovie.write(to: omraknad, sound: .aac, rate: 30, dropEveryThird: false)
        let ok30 = try await PhotoImport.accept(omraknad)
        XCTAssertFalse(ok30)
        XCTAssertFalse(FileManager.default.fileExists(atPath: omraknad.path), "den vägrade filen är borttagen")

        let original = try tmp("original.mov")
        try await SyntheticMovie.write(to: original, sound: .aac)
        let ok240 = try await PhotoImport.accept(original)
        XCTAssertTrue(ok240)
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
        XCTAssertEqual(PhotoImport.fileExtension("IMG_0001.MOV"), "mov")
        XCTAssertEqual(PhotoImport.fileExtension("utan"), "mov")
    }

    /// Lagringen (S2_SPEC §8.1): passet sparas och läses tillbaka, en oläslig fil flyttas
    /// undan i stället för att skrivas över, och originalen tas bara bort när
    /// "Spara bara klippen" är valt och passet exporterat. BESLUT B26
    func testLagringen() throws {
        let rot = try tmp("lagring-\(UUID().uuidString)")
        let store = Store(root: rot, exportFolder: rot.appending(path: "Export"))
        XCTAssertTrue(store.settings.keepOriginals)
        // Hela sekunder: pass.json skriver tiderna i ISO 8601 utan bråkdelar.
        let tid = Date(timeIntervalSince1970: 1_792_848_612)
        var pass = store.newPass(setup: PassSetup(view: .fo, club: "j7", distance: 3, hand: .hoger), at: tid)
        XCTAssertTrue(PassID.isValid(pass.id))
        let video = store.passFolder(pass.id).appending(path: "Video")
        let backup = try video.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup
        XCTAssertEqual(backup, true, "Video/ utanför backupen")

        let fil = PassState.videoPath(nr: 1)
        try Data([1, 2, 3]).write(to: store.url(fil, in: pass.id))
        let timing = FrameTiming.analyze((0..<10).map { Double($0) / 240 })
        pass.series.append(SeriesRecord(nr: 1, source: .recording, club: "j7", file: fil, start: tid,
                                        startHost: 1.5, duration: 1, bytes: 3, timing: timing,
                                        clicks: [Click(time: 0.5, strength: 40)], orientation: 6,
                                        uprightWidth: 1080, uprightHeight: 1920))
        store.save(pass)
        let igen = Store(root: rot, exportFolder: rot.appending(path: "Export"))
        XCTAssertEqual(igen.load(pass.id), pass)
        XCTAssertEqual(igen.index.passes.first?.clicks, 1)

        // Behåll (standard): inget tas bort, även exporterat.
        pass.status = .exported
        XCTAssertEqual(igen.releaseOriginals(pass), 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: igen.url(fil, in: pass.id).path))
        // Spara bara klippen: originalet tas bort, passet finns kvar.
        igen.setKeepOriginals(false)
        XCTAssertEqual(Store(root: rot, exportFolder: rot.appending(path: "Export")).settings.keepOriginals, false)
        XCTAssertEqual(igen.releaseOriginals(pass), 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: igen.url(fil, in: pass.id).path))
        XCTAssertNotNil(igen.load(pass.id))

        // En oläslig pass.json flyttas undan och skrivs aldrig över.
        let passFil = store.passFolder(pass.id).appending(path: "pass.json")
        try Data("{inte json".utf8).write(to: passFil)
        XCTAssertNil(igen.load(pass.id))
        XCTAssertNotNil(igen.problem)
        let undan = try FileManager.default.contentsOfDirectory(atPath: store.passFolder(pass.id).path)
            .filter { $0.hasPrefix("pass-unreadable-") }
        XCTAssertEqual(undan.count, 1)
    }
}
