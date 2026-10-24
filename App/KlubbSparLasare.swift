import AVFoundation
import Foundation
import Swing
import Capture

/// Hur räkningen av klubbhuvudets bana gick (S7b, BESLUT B71).
enum KlubbSvar {
    case klar(KlubbBana)
    /// Varför ingen bana sparades, i klartext (en grå rad under chipsen).
    case fel(String)
    case avbruten
}

/// Klubbhuvudets bana för ett slag (PLAN S7b, BESLUT B71, METOD M61): rutorna läses ur
/// seriens fil (eller klippet) en gång i tidsordning, som Y-planet vridet upprätt i lägre
/// upplösning (`KlubbRutor`), och bara de som spårningen behöver just nu hålls i minnet
/// (`RutStrom`, en ringbuffert). SwingLabKit:s `KlubbSpar` spårar mellan ankarna.
enum KlubbSparLasare {
    /// Mer än så av rutorna saknas: ingen bana sparas. METOD M61
    static let maxSaknade = 0.10

    /// Räknar banan utanför huvudtråden; avbryts med uppgiften (Task.cancel).
    static func rakna(pass: PassState, shot: ShotRecord, series: JointSeries, url: URL, offset: Double) async -> KlubbSvar {
        guard KlubbBana.mojlig(shot.klubba) else { return .fel(String(localized: "Mark two neighboring positions")) }
        let frames = series.frames.sorted { $0.t < $1.t }
        guard let spann = KlubbRutor.spann(frames, ankare: shot.klubba ?? []) else {
            return .fel(String(localized: "Mark two neighboring positions"))
        }
        let geo: MediaReader.Geometry
        do {
            geo = try await MediaReader.geometry(url)
        } catch {
            return .fel(String(localized: "The video could not be read"))
        }
        let upp = KlubbRutor.upprattStorlek(width: geo.width, height: geo.height, exif: geo.exif)
        let skala = KlubbRutor.skala(uprightWidth: upp.width, uprightHeight: upp.height)
        let w = max(1, Int(Double(upp.width) * skala)), h = max(1, Int(Double(upp.height) * skala))
        let marks = shot.klubba ?? []
        let utvalda = Array(frames[spann])
        guard let strom = try? await RutStrom.oppna(url: url, pts: utvalda.map { $0.pts + offset }, exif: geo.exif,
                                                    skala: skala, bredd: w, hojd: h) else {
            return .fel(String(localized: "The video could not be read"))
        }
        let jobb = Task.detached(priority: .userInitiated) { () -> KlubbSvar in
            guard let bana = KlubbSpar.sparaAvbrytbar(
                t: utvalda.map(\.t), leder: utvalda.map(KlubbRutor.leder), bredd: w, hojd: h, skala: skala, ankare: marks,
                bildBredd: series.width, bildHojd: series.height, avbruten: { Task.isCancelled }, bild: strom.bild)
            else { return .avbruten }
            if strom.andelSaknade > maxSaknade { return .fel(String(localized: "Too many frames are missing in the video")) }
            return .klar(KlubbBana(bana, ankare: marks))
        }
        return await withTaskCancellationHandler { await jobb.value } onCancel: { jobb.cancel() }
    }
}

/// Rutorna ur filen i tidsordning med en ringbuffert (S7b, METOD M61): `bild(k)` läser vidare
/// i filen tills ruta k (och det som ligger före) är läst, och glömmer rutor som ligger mer
/// än `minne` rutor bakom den senast begärda. Spårningen begär rutorna i tidsordning och högst
/// tre rutor bort, så det räcker med några få i minnet i stället för hela slaget.
final class RutStrom: @unchecked Sendable {
    /// Rutor bakom den senast begärda som hålls kvar.
    static let minne = 8

    private let reader: AVAssetReader
    private let output: AVAssetReaderTrackOutput
    private let pts: [Double]
    private let exif: UInt32
    private let skala: Double
    private let bredd: Int, hojd: Int
    private var cache: [Int: [UInt8]] = [:]
    /// Den högsta rutan som filen lästs fram till (alla före den är lästa eller saknas).
    private var last = -1
    private var slut = false
    private var begarda = Set<Int>(), saknade = Set<Int>()

    /// Öppnar filen och börjar läsa vid den första tiden.
    static func oppna(url: URL, pts: [Double], exif: UInt32, skala: Double, bredd: Int, hojd: Int) async throws -> RutStrom {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw MediaReader.ReadError.noVideo }
        return try RutStrom(asset: asset, track: track, pts: pts, exif: exif, skala: skala, bredd: bredd, hojd: hojd)
    }

    private init(asset: AVAsset, track: AVAssetTrack, pts: [Double], exif: UInt32, skala: Double, bredd: Int,
                 hojd: Int) throws {
        let r = try AVAssetReader(asset: asset)
        let o = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        ])
        o.alwaysCopiesSampleData = false
        guard r.canAdd(o) else { throw MediaReader.ReadError.cannotRead }
        r.add(o)
        if let a = pts.first, let b = pts.last {
            r.timeRange = CMTimeRange(start: CMTime(seconds: max(0, a - 0.02), preferredTimescale: 48_000),
                                      end: CMTime(seconds: b + 0.02, preferredTimescale: 48_000))
        }
        guard r.startReading() else { throw r.error ?? MediaReader.ReadError.cannotRead }
        reader = r
        output = o
        self.pts = pts
        self.exif = exif
        self.skala = skala
        self.bredd = bredd
        self.hojd = hojd
    }

    /// Andelen av de begärda rutorna som inte fanns i filen.
    var andelSaknade: Double { begarda.isEmpty ? 0 : Double(saknade.count) / Double(begarda.count) }

    /// Ruta k som upprätt gråskala, eller nil när den saknas i filen.
    func bild(_ k: Int) -> [UInt8]? {
        begarda.insert(k)
        while last < k, !slut, !Task.isCancelled { lasNasta() }
        for gammal in cache.keys where gammal < k - Self.minne { cache[gammal] = nil }
        guard let b = cache[k] else {
            saknade.insert(k)
            return nil
        }
        return b
    }

    private func lasNasta() {
        guard let buffer = output.copyNextSampleBuffer() else {
            slut = true
            return
        }
        guard let pb = CMSampleBufferGetImageBuffer(buffer) else { return }
        let t = CMSampleBufferGetPresentationTimeStamp(buffer).seconds
        // Rutan med närmast tid, inom en halv ruta.
        var lo = 0, hi = pts.count - 1
        while lo < hi {
            let m = (lo + hi) / 2
            if pts[m] < t { lo = m + 1 } else { hi = m }
        }
        // Rutorna före `lo` ligger före den här tiden: de är lästa eller saknas.
        last = max(last, lo - 1)
        var k = lo
        if k > 0 && abs(pts[k - 1] - t) <= abs(pts[k] - t) { k -= 1 }
        guard abs(pts[k] - t) <= 0.5 / 240 else { return }
        last = max(last, k)
        if cache[k] == nil, let g = gra(pb) { cache[k] = g }
    }

    /// Y-planet som upprätt gråskala; nil om storleken inte blir rutans (då saknas rutan).
    private func gra(_ pb: CVPixelBuffer) -> [UInt8]? {
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        let planar = CVPixelBufferIsPlanar(pb)
        guard let base = planar ? CVPixelBufferGetBaseAddressOfPlane(pb, 0) : CVPixelBufferGetBaseAddress(pb) else {
            return nil
        }
        let w = planar ? CVPixelBufferGetWidthOfPlane(pb, 0) : CVPixelBufferGetWidth(pb)
        let h = planar ? CVPixelBufferGetHeightOfPlane(pb, 0) : CVPixelBufferGetHeight(pb)
        let rad = planar ? CVPixelBufferGetBytesPerRowOfPlane(pb, 0) : CVPixelBufferGetBytesPerRow(pb)
        let plan = UnsafeBufferPointer(start: base.assumingMemoryBound(to: UInt8.self), count: rad * h)
        let r = KlubbRutor.upratt(plan, radBytes: rad, width: w, height: h, exif: exif, skala: skala)
        guard r.bredd == bredd, r.hojd == hojd else { return nil }
        return r.bild
    }

    /// Rutorna på tiderna `pts` (för provet): varje ruta eller nil.
    static func lasAlla(url: URL, pts: [Double], exif: UInt32, skala: Double, bredd: Int,
                        hojd: Int) async throws -> [[UInt8]?] {
        let s = try await oppna(url: url, pts: pts, exif: exif, skala: skala, bredd: bredd, hojd: hojd)
        return pts.indices.map { s.bild($0) }
    }
}
