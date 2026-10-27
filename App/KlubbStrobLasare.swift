import AVFoundation
import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import Swing
import Capture

/// Hur stroboskopet gick (S7-2, METOD MF7).
enum KlubbStrobSvar {
    case klar(CGImage, huvuden: Int, rutor: Int)
    /// Varför ingen bild blev, i klartext.
    case fel(String)
    case avbruten
}

/// Stroboskopet för ett slag (PLAN S7-2, METOD MF7): rutorna från P1 till P9 läses ur filen
/// en gång, upprätta i halv upplösning. Varje ruta skärs ut kring händerna, och klubbmodellen
/// (`KlubbModellKorning`) letar efter huvudet där. Bara huvudenas delar av bilden, grundbilden
/// vid P1 och medianbildens rutor hålls i minnet. SwingLabKits `KlubbStrob` klistrar sedan in
/// huvudena, som `strob` i tools/pc/formarkare.py. Bara för ögat (B92); inget sparas i passet.
enum KlubbStrobLasare {
    /// Bilden mot seriens (1080 × 1920 → 540 × 960): minnet och tiden på telefonen.
    static let skala = 0.5

    static func rakna(shot: ShotRecord, series: JointSeries, url: URL, offset: Double,
                      framsteg: @escaping @Sendable (Double) -> Void) async -> KlubbStrobSvar {
        guard let m = shot.measure, let fran = m.positions["P1"],
              let till = m.positions["P9"] ?? m.positions["P10"] else {
            return .fel(String(localized: "Address and finish are missing"))
        }
        let rutor = series.frames.filter { $0.t >= fran - 0.002 && $0.t <= till + 0.002 }.sorted { $0.t < $1.t }
        guard rutor.count >= 3, let kropp = KlubbStrob.kroppen(rutor) else {
            return .fel(String(localized: "Address and finish are missing"))
        }
        let geo: MediaReader.Geometry
        let asset = AVURLAsset(url: url)
        let track: AVAssetTrack
        do {
            geo = try await MediaReader.geometry(url)
            guard let s = try await asset.loadTracks(withMediaType: .video).first else {
                return .fel(String(localized: "The video could not be read"))
            }
            track = s
        } catch {
            return .fel(String(localized: "The video could not be read"))
        }
        let jobb = Task.detached(priority: .userInitiated) { () -> KlubbStrobSvar in
            do {
                guard let modell = try KlubbModellKorning.iAppen() else {
                    return .fel(String(localized: "The club model is not in this build"))
                }
                return try lasOchKlistra(rutor: rutor, kropp: kropp, series: series, asset: asset, track: track, offset: offset,
                                         exif: geo.exif, modell: modell, framsteg: framsteg)
            } catch is CancellationError {
                return .avbruten
            } catch {
                return .fel(String(localized: "The video could not be read"))
            }
        }
        return await withTaskCancellationHandler { await jobb.value } onCancel: { jobb.cancel() }
    }

    private static func lasOchKlistra(rutor: [PoseFrame], kropp: (hojd: Double, x: Double, y: Double),
                                      series: JointSeries, asset: AVAsset, track: AVAssetTrack, offset: Double, exif: UInt32,
                                      modell: KlubbModellKorning,
                                      framsteg: @Sendable (Double) -> Void) throws -> KlubbStrobSvar {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { return .fel(String(localized: "The video could not be read")) }
        reader.add(output)
        let pts = rutor.map { $0.pts + offset }
        reader.timeRange = CMTimeRange(start: CMTime(seconds: max(0, pts[0] - 0.02), preferredTimescale: 48_000),
                                       end: CMTime(seconds: pts[pts.count - 1] + 0.02, preferredTimescale: 48_000))
        guard reader.startReading() else { throw reader.error ?? MediaReader.ReadError.cannotRead }
        defer { reader.cancelReading() }

        let ci = CIContext(options: [.cacheIntermediates: false])
        let ut = (w: Int((Double(series.width) * skala).rounded()), h: Int((Double(series.height) * skala).rounded()))
        let sida = modell.beskrivning.sida
        let medianIndex = KlubbStrob.medianIndex(forsta: 0, sista: rutor.count - 1)
        var bas: RGBABild?
        var prov: [RGBABild] = []
        var huvud: [Int: [Double]] = [:]
        var delar: [Int: (x0: Int, y0: Int, bredd: Int, hojd: Int, pixlar: [UInt8])] = [:]
        var lasta = Set<Int>()

        while let buffer = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            guard let pb = CMSampleBufferGetImageBuffer(buffer) else { continue }
            let t = CMSampleBufferGetPresentationTimeStamp(buffer).seconds
            guard let k = pts.indices.min(by: { abs(pts[$0] - t) < abs(pts[$1] - t) }),
                  abs(pts[k] - t) <= 0.5 / 240, !lasta.contains(k) else { continue }
            lasta.insert(k)
            // Upprätt, i halv upplösning, som RGBA.
            var bild = CIImage(cvPixelBuffer: pb).oriented(CGImagePropertyOrientation(rawValue: exif) ?? .up)
            bild = bild.transformed(by: CGAffineTransform(translationX: -bild.extent.minX, y: -bild.extent.minY))
            bild = bild.transformed(by: CGAffineTransform(scaleX: CGFloat(ut.w) / bild.extent.width,
                                                          y: CGFloat(ut.h) / bild.extent.height))
            guard let cg = ci.createCGImage(bild, from: CGRect(x: 0, y: 0, width: ut.w, height: ut.h)) else { continue }
            let hel = rgba(cg, bredd: ut.w, hojd: ut.h)
            if k == 0 { bas = hel }
            if medianIndex.contains(k) { prov.append(hel) }
            // Utsnittet kring händerna i ledernas px, i bildens px, skalat till modellens sida.
            let u = KlubbStrob.utsnitt(rutor[k], kropp: kropp, bredd: series.width, hojd: series.height)
            let s = Double(ut.w) / Double(series.width)
            let x0 = Double(u.x0) * s, y0 = Double(u.y0) * s, us = Double(u.sida) * s
            let indata = utsnitt(cg, x0: x0, y0: y0, sida: us, mal: sida)
            let det = try modell.detektioner(rgba: indata, troskel: KlubbStrob.konfidens, bredd: us, hojd: us)
            if let b = det.first(where: { $0.klass == "klubbhuvud" }) {
                let box = [x0 + b.bbox[0], y0 + b.bbox[1], b.bbox[2], b.bbox[3]]
                if let r = KlubbStrob.ruta(box, bredd: ut.w, hojd: ut.h) {
                    huvud[k] = box
                    delar[k] = (r.x0, r.y0, r.bredd, r.hojd, KlubbStrob.del(hel, x0: r.x0, y0: r.y0, bredd: r.bredd, hojd: r.hojd))
                }
            }
            framsteg(Double(lasta.count) / Double(rutor.count))
        }
        try Task.checkCancellation()
        guard var bild = bas else { return .fel(String(localized: "The video could not be read")) }
        let median = KlubbStrob.median(prov)
        prov.removeAll()
        let fel = KlubbStrob.ensamma(huvud)
        let grund = bild
        var antal = 0
        for k in delar.keys.sorted() where !fel.contains(k) {
            let d = delar[k]!
            if let l = KlubbStrob.lager(pixlar: d.pixlar, x0: d.x0, y0: d.y0, bredd: d.bredd, hojd: d.hojd,
                                        bas: grund, median: median) {
                KlubbStrob.lagg(l, i: &bild)
                antal += 1
            }
        }
        guard antal > 0 else { return .fel(String(localized: "No club head was found")) }
        guard let cg = cgImage(bild) else { return .fel(String(localized: "The video could not be read")) }
        return .klar(cg, huvuden: antal, rutor: rutor.count)
    }

    /// Bilden som RGBA, rad för rad uppifrån.
    static func rgba(_ cg: CGImage, bredd: Int, hojd: Int) -> RGBABild {
        var px = [UInt8](repeating: 0, count: bredd * hojd * 4)
        px.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: bredd, height: hojd, bitsPerComponent: 8,
                                      bytesPerRow: bredd * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: bredd, height: hojd))
        }
        return RGBABild(bredd: bredd, hojd: hojd, pixlar: px)
    }

    /// Utsnittet (x0, y0, sida i bildens px, uppifrån) skalat till `mal` × `mal` som RGBA, svart
    /// utanför bilden, som `skar` i formarkare.py. CGContext har origo nere till vänster.
    static func utsnitt(_ cg: CGImage, x0: Double, y0: Double, sida: Double, mal: Int) -> [UInt8] {
        var px = [UInt8](repeating: 0, count: mal * mal * 4)
        let k = Double(mal) / sida
        let w = Double(cg.width), h = Double(cg.height)
        px.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: mal, height: mal, bitsPerComponent: 8,
                                      bytesPerRow: mal * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return }
            ctx.interpolationQuality = .high
            ctx.draw(cg, in: CGRect(x: -x0 * k, y: -(h - y0 - sida) * k, width: w * k, height: h * k))
        }
        return px
    }

    static func cgImage(_ b: RGBABild) -> CGImage? {
        guard let data = CGDataProvider(data: Data(b.pixlar) as CFData) else { return nil }
        return CGImage(width: b.bredd, height: b.hojd, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: b.bredd * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: data, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
