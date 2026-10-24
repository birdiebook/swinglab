import AVFoundation
import Foundation
import Swing
import Capture

/// Klubbhuvudets bana för ett slag (PLAN S7b, BESLUT B71, METOD M61): rutorna mellan första
/// och sista markeringen läses ur seriens fil (eller klippet) som Y-planet, vrids upprätt i
/// lägre upplösning (`KlubbRutor`), och SwingLabKit:s `KlubbSpar` spårar klubbhuvudet mellan
/// ankarna. Tar några sekunder; körs utanför huvudtråden.
enum KlubbSparLasare {
    /// Banan ur slagets markeringar, eller nil (färre än två markerade positioner, ingen fil).
    static func bana(pass: PassState, shot: ShotRecord, series: JointSeries, store: Store) async throws -> KlubbBana? {
        guard KlubbBana.mojlig(shot.klubba), let serie = pass.series.first(where: { $0.nr == shot.series }) else {
            return nil
        }
        let frames = series.frames.sorted { $0.t < $1.t }
        guard let spann = KlubbRutor.spann(frames, ankare: shot.klubba ?? []) else { return nil }
        // Seriens fil, eller klippet när originalet är borttaget (som granskningen, METOD MS12).
        var url = store.url(serie.file, in: pass.id)
        var offset = 0.0
        if !FileManager.default.fileExists(atPath: url.path) {
            guard let clip = shot.clip, let o = ShotImages.clipOffset(shot) else { return nil }
            url = store.url(clip, in: pass.id)
            offset = o
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let geo = try await MediaReader.geometry(url)
        let upp = Orientation.uprightSize(width: geo.width, height: geo.height, exif: geo.exif)
        let skala = KlubbRutor.skala(uprightWidth: upp.width, uprightHeight: upp.height)
        let utvalda = Array(frames[spann])
        let bilder = try await lasRutor(url: url, pts: utvalda.map { $0.pts + offset }, exif: geo.exif, skala: skala)
        let w = max(1, Int(Double(upp.width) * skala)), h = max(1, Int(Double(upp.height) * skala))
        let rutor = zip(utvalda, bilder).map { f, b in KlubbSpar.Ruta(t: f.t, bild: b ?? [], leder: KlubbRutor.leder(f)) }
        let marks = shot.klubba
        return await Task.detached(priority: .userInitiated) {
            KlubbBana(KlubbSpar.spara(rutor, bredd: w, hojd: h, skala: skala, ankare: marks ?? []), ankare: marks)
        }.value
    }

    /// Y-planet för rutorna på tiderna `pts` (filens tid), upprätt i `skala`; nil där ingen
    /// ruta låg inom en halv ruta (spårningen tappar den rutan och interpolerar, M61).
    static func lasRutor(url: URL, pts: [Double], exif: UInt32, skala: Double) async throws -> [[UInt8]?] {
        guard let forsta = pts.first, let sista = pts.last else { return [] }
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { return pts.map { _ in nil } }
        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { return pts.map { _ in nil } }
        reader.add(output)
        let start = max(0, forsta - 0.02)
        reader.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 48_000),
                                       end: CMTime(seconds: sista + 0.02, preferredTimescale: 48_000))
        guard reader.startReading() else { throw reader.error ?? MediaReader.ReadError.cannotRead }
        var ut = [[UInt8]?](repeating: nil, count: pts.count)
        let halv = 0.5 / 240
        while let buffer = output.copyNextSampleBuffer() {
            autoreleasepool {
                guard let pb = CMSampleBufferGetImageBuffer(buffer) else { return }
                let t = CMSampleBufferGetPresentationTimeStamp(buffer).seconds
                // Rutan med närmast tid.
                var lo = 0, hi = pts.count - 1
                while lo < hi {
                    let m = (lo + hi) / 2
                    if pts[m] < t { lo = m + 1 } else { hi = m }
                }
                var k = lo
                if k > 0 && abs(pts[k - 1] - t) <= abs(pts[k] - t) { k -= 1 }
                guard abs(pts[k] - t) <= halv, ut[k] == nil else { return }
                ut[k] = gra(pb, exif: exif, skala: skala)
            }
        }
        return ut
    }

    /// Y-planet som upprätt gråskala (KlubbRutor.upratt).
    static func gra(_ pb: CVPixelBuffer, exif: UInt32, skala: Double) -> [UInt8]? {
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
        return KlubbRutor.upratt(plan, radBytes: rad, width: w, height: h, exif: exif, skala: skala).bild
    }
}
