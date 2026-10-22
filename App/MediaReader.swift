import AVFoundation
import CoreMedia
import CoreVideo
import Capture

/// Rutornas tider, ljudet, geometrin och ljusheten ur en fil (S2_SPEC §3.1). Samma
/// kod läser en egen inspelning, ett importerat original och provets påhittade film.
/// Allt som går att räkna utan AVFoundation bor i SwingLabKit.
enum MediaReader {
    enum ReadError: LocalizedError {
        case noVideo, cannotRead, blockCopy
        var errorDescription: String? {
            switch self {
            case .noVideo: return "Filen har ingen video."
            case .cannotRead: return "Filen gick inte att läsa."
            case .blockCopy: return "Ljudet gick inte att läsa."
            }
        }
    }

    /// Ljudet som klickjakten vill ha det: 48 kHz mono Float32 (S2_SPEC §2.5). METOD MS4
    static let sampleRate = 48_000.0

    // MARK: Rutornas tider

    /// Varje rutas visningstid i sekunder, sorterade. Avkodar inte (outputSettings: nil).
    /// Från Airtime VideoFrames.load. METOD MS3
    static func frameTimes(_ url: URL) async throws -> [Double] {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw ReadError.noVideo }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw ReadError.cannotRead }
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? ReadError.cannotRead }
        var times: [Double] = []
        while let buffer = output.copyNextSampleBuffer() {
            guard CMSampleBufferGetNumSamples(buffer) > 0 else { continue }
            let t = CMSampleBufferGetPresentationTimeStamp(buffer)
            if t.isValid { times.append(t.seconds) }
        }
        if reader.status == .failed { throw reader.error ?? ReadError.cannotRead }
        return times.sorted()
    }

    // MARK: Ljudet

    /// Läser ljudet som 48 kHz mono Float32 i de buffertar AVAssetReader ger, och
    /// svarar tiden för filens första ljudprov (nil = inget ljudspår). Omsamplingen och
    /// nedmixningen görs av läsaren (S2_SPEC §3.1).
    static func readAudio(_ url: URL, _ chunk: ([Float]) throws -> Void) async throws -> Double? {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { return nil }
        let reader = try AVAssetReader(asset: asset)
        var mono = AudioChannelLayout()
        mono.mChannelLayoutTag = kAudioChannelLayoutTag_Mono
        let layout = Data(bytes: &mono, count: MemoryLayout<AudioChannelLayout>.size)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVChannelLayoutKey: layout,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw ReadError.cannotRead }
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? ReadError.cannotRead }
        var first: Double?
        while let buffer = output.copyNextSampleBuffer() {
            guard CMSampleBufferGetNumSamples(buffer) > 0, let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
            if first == nil {
                let t = CMSampleBufferGetPresentationTimeStamp(buffer)
                first = t.isValid ? t.seconds : 0
            }
            let n = CMBlockBufferGetDataLength(block) / MemoryLayout<Float>.size
            guard n > 0 else { continue }
            var samples = [Float](repeating: 0, count: n)
            let status = samples.withUnsafeMutableBytes { raw -> OSStatus in
                guard let base = raw.baseAddress else { return kCMBlockBufferBadCustomBlockSourceErr }
                return CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: n * MemoryLayout<Float>.size,
                                                  destination: base)
            }
            guard status == kCMBlockBufferNoErr else { throw ReadError.blockCopy }
            try chunk(samples)
        }
        if reader.status == .failed { throw reader.error ?? ReadError.cannotRead }
        return first ?? 0
    }

    /// Ljudet i bitar om högst `segment` s med `overlap` s överlapp, klippta exakt vid
    /// `ClickDetector.segments`-proven räknat från filens första ljudprov, så att PC:ns
    /// bitar får samma medianer (S2_SPEC §12 S2c). Svarar tiden för första provet.
    @discardableResult
    static func audio(_ url: URL, segment: Double = ClickDetector.segmentSeconds,
                      overlap: Double = ClickDetector.overlapSeconds,
                      _ each: (AudioSegmenter.Segment) throws -> Void) async throws -> Double? {
        var segmenter = AudioSegmenter(sampleRate: sampleRate, segment: segment, overlap: overlap)
        let first = try await readAudio(url) { try segmenter.feed($0, emit: each) }
        guard first != nil else { return nil }
        try segmenter.finish(emit: each)
        return first
    }

    /// Klicken i filen, med tiden i filens tidslinje (första ljudprovets tid + prov / 48 000).
    /// METOD MS4
    static func clicks(_ url: URL, segment: Double = ClickDetector.segmentSeconds,
                       overlap: Double = ClickDetector.overlapSeconds) async throws -> [Click] {
        var stream = ClickStream(sampleRate: sampleRate, segment: segment, overlap: overlap)
        guard let first = try await readAudio(url, { stream.feed($0) }) else { return [] }
        return stream.finish().map { Click(time: first + $0.time, strength: $0.strength) }
    }

    /// Ljudspårets format som det står i filen (S2_SPEC §2.5): frekvens, kanaler, kodek.
    static func audioInfo(_ url: URL) async throws -> AudioInfo? {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { return nil }
        let descriptions = try await track.load(.formatDescriptions)
        guard let d = descriptions.first,
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(d)?.pointee else { return nil }
        return AudioInfo(sampleRate: asbd.mSampleRate, channels: Int(asbd.mChannelsPerFrame),
                         codec: FourCC.string(asbd.mFormatID))
    }

    // MARK: Geometrin

    struct Geometry: Equatable {
        var a: Double, b: Double, c: Double, d: Double
        var width: Int, height: Int
        var exif: UInt32 { Orientation.exif(a: a, b: b, c: c, d: d) }
    }

    /// Spårets preferredTransform (a, b, c, d) och lagrade storlek (S2_SPEC §6.2). METOD MS7
    static func geometry(_ url: URL) async throws -> Geometry {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw ReadError.noVideo }
        let (size, t) = try await track.load(.naturalSize, .preferredTransform)
        return Geometry(a: Double(t.a), b: Double(t.b), c: Double(t.c), d: Double(t.d),
                        width: Int(size.width.rounded()), height: Int(size.height.rounded()))
    }

    // MARK: Ljusheten

    /// Medelljusheten 0–1 per ruta: Y-planet i bildens mittersta tredjedel, nedskalat
    /// till högst 480 × 270 (S2_SPEC §2.7). Tiderna är rutornas egna. METOD MS3
    static func luma(_ url: URL) async throws -> (times: [Double], luma: [Double]) {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw ReadError.noVideo }
        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferWidthKey as String: 480,
            kCVPixelBufferHeightKey as String: 270,
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw ReadError.cannotRead }
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? ReadError.cannotRead }
        var rader: [(Double, Double)] = []
        while let buffer = output.copyNextSampleBuffer() {
            autoreleasepool {
                guard let pixels = CMSampleBufferGetImageBuffer(buffer) else { return }
                let t = CMSampleBufferGetPresentationTimeStamp(buffer)
                guard t.isValid, let y = meanLuma(pixels) else { return }
                rader.append((t.seconds, y))
            }
        }
        if reader.status == .failed { throw reader.error ?? ReadError.cannotRead }
        rader.sort { $0.0 < $1.0 }
        return (rader.map(\.0), rader.map(\.1))
    }

    /// Medel av Y-planet i mittersta tredjedelen, 0–1.
    static func meanLuma(_ pb: CVPixelBuffer) -> Double? {
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        let plane = CVPixelBufferIsPlanar(pb) ? 0 : -1
        let base = plane == 0 ? CVPixelBufferGetBaseAddressOfPlane(pb, 0) : CVPixelBufferGetBaseAddress(pb)
        guard let base else { return nil }
        let w = plane == 0 ? CVPixelBufferGetWidthOfPlane(pb, 0) : CVPixelBufferGetWidth(pb)
        let h = plane == 0 ? CVPixelBufferGetHeightOfPlane(pb, 0) : CVPixelBufferGetHeight(pb)
        let rad = plane == 0 ? CVPixelBufferGetBytesPerRowOfPlane(pb, 0) : CVPixelBufferGetBytesPerRow(pb)
        guard w >= 3, h >= 3 else { return nil }
        let p = base.assumingMemoryBound(to: UInt8.self)
        var sum = 0
        var n = 0
        for y in (h / 3)..<(2 * h / 3) {
            let r = p + y * rad
            for x in (w / 3)..<(2 * w / 3) { sum += Int(r[x]) }
            n += 2 * w / 3 - w / 3
        }
        return n > 0 ? Double(sum) / Double(n) / 255 : nil
    }

    // MARK: Allt för en serie

    /// Det kvittot och passet behöver ur en fil: tiderna, klicken, ljudet, geometrin,
    /// storleken och längden.
    static func facts(_ url: URL, microphone: String? = nil) async throws -> FileFacts {
        let times = try await frameTimes(url)
        let geo = try await geometry(url)
        let klick = try await clicks(url)
        var audio = try await audioInfo(url)
        audio?.microphone = microphone
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map { Int64($0) } ?? 0
        let duration = try await AVURLAsset(url: url).load(.duration).seconds
        return FileFacts(frameTimes: times, clicks: klick, audio: audio, transform: [geo.a, geo.b, geo.c, geo.d],
                         storedWidth: geo.width, storedHeight: geo.height, bytes: bytes, duration: duration)
    }
}
