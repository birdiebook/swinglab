import AVFoundation
import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import Swing
import Capture

/// Hur stroboskopet gick (S7-2, METOD MF7).
enum KlubbStrobSvar {
    /// Bilden, och filmen när den gick att skriva.
    case klar(CGImage, film: URL?, huvuden: Int, rutor: Int)
    /// Varför ingen bild blev, i klartext.
    case fel(String)
    case avbruten
}

/// Stroboskopet för ett slag (PLAN S7-2, METOD MF7) i full upplösning, tre varv i filen som
/// `strob` i tools/pc/formarkare.py: (1) varje ruta från P1 till P9 skärs ut kring händerna och
/// klubbmodellen (`KlubbModellKorning`) letar efter huvudet där; grundbilden vid P1 och
/// medianbildens rutor (halv upplösning, minnet) sparas. (2) Varje huvud jämförs med samma del av
/// rutan före och efter där huvudet var någon annanstans (`KlubbStrob.grannar`) och med medianen,
/// så att bara huvudet blir ett lager. (3) Filmen: rutorna med huvudena pålagda efter hand, 8 gånger
/// långsammare. Bara utsnitten och lagren hålls i minnet. Bara för ögat (B92); inget sparas i
/// passet, och filmen ligger i appens tillfälliga mapp.
enum KlubbStrobLasare {
    /// Medianbilden mot rutorna (1080 × 1920 → 540 × 960): minnet för 25 rutor på telefonen.
    static let medianSkala = 0.5
    /// Filmens bilder per sekund: 240 bilder/s blir 8 gånger långsammare (formarkare.STROB_FPS).
    static let filmFps: Int32 = 30
    /// Varvens del av förloppet: modellen tar det mesta.
    static let andel = (huvud: 0.6, lager: 0.15)

    static func rakna(shot: ShotRecord, series: JointSeries, url: URL, offset: Double, film: URL,
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
                return try await lasOchKlistra(rutor: rutor, kropp: kropp, series: series, asset: asset, track: track,
                                               offset: offset, exif: geo.exif, modell: modell, film: film,
                                               framsteg: framsteg)
            } catch is CancellationError {
                return .avbruten
            } catch {
                return .fel(String(localized: "The video could not be read"))
            }
        }
        return await withTaskCancellationHandler { await jobb.value } onCancel: { jobb.cancel() }
    }

    private static func lasOchKlistra(rutor: [PoseFrame], kropp: (hojd: Double, x: Double, y: Double),
                                      series: JointSeries, asset: AVAsset, track: AVAssetTrack, offset: Double,
                                      exif: UInt32, modell: KlubbModellKorning, film: URL,
                                      framsteg: @escaping @Sendable (Double) -> Void) async throws -> KlubbStrobSvar {
        let ci = CIContext(options: [.cacheIntermediates: false])
        let ut = (w: series.width, h: series.height)
        let hel = CGRect(x: 0, y: 0, width: ut.w, height: ut.h)
        let halv = (w: Int((Double(ut.w) * medianSkala).rounded()), h: Int((Double(ut.h) * medianSkala).rounded()))
        let pts = rutor.map { $0.pts + offset }
        let sida = modell.beskrivning.sida
        let medianIndex = KlubbStrob.medianIndex(forsta: 0, sista: rutor.count - 1)

        // (1) Huvudena i ledernas px (= bildens), grundbilden och medianbildens rutor.
        var bas: RGBABild?
        var prov: [RGBABild] = []
        var huvud: [Int: [Double]] = [:]
        var lasta = 0
        try varjeRuta(asset: asset, track: track, pts: pts, exif: exif, ut: ut) { k, bild in
            guard let cg = ci.createCGImage(bild, from: hel) else { return }
            if k == 0 { bas = rgba(cg, bredd: ut.w, hojd: ut.h) }
            if medianIndex.contains(k),
               let liten = ci.createCGImage(bild.transformed(by: CGAffineTransform(scaleX: medianSkala, y: medianSkala)),
                                            from: CGRect(x: 0, y: 0, width: halv.w, height: halv.h)) {
                prov.append(rgba(liten, bredd: halv.w, hojd: halv.h))
            }
            let u = KlubbStrob.utsnitt(rutor[k], kropp: kropp, bredd: ut.w, hojd: ut.h)
            let x0 = Double(u.x0), y0 = Double(u.y0), us = Double(u.sida)
            let det = try modell.detektioner(rgba: utsnitt(cg, x0: x0, y0: y0, sida: us, mal: sida),
                                             troskel: KlubbStrob.konfidens, bredd: us, hojd: us)
            if let b = det.first(where: { $0.klass == "klubbhuvud" }) {
                let box = [x0 + b.bbox[0], y0 + b.bbox[1], b.bbox[2], b.bbox[3]]
                if KlubbStrob.ruta(box, bredd: ut.w, hojd: ut.h) != nil { huvud[k] = box }
            }
            lasta += 1
            framsteg(andel.huvud * Double(lasta) / Double(rutor.count))
        }
        try Task.checkCancellation()
        guard var bild = bas else { return .fel(String(localized: "The video could not be read")) }
        let median = KlubbStrob.median(prov)
        prov.removeAll()
        for k in KlubbStrob.ensamma(huvud) { huvud[k] = nil }

        // (2) Lagren: varje huvud mot samma del av rutorna före och efter där huvudet var någon
        // annanstans, och av medianen. Ett utsnitt hålls bara tills huvudets tre rutor är lästa.
        let grannar = KlubbStrob.grannar(huvud, bredd: ut.w, hojd: ut.h)
        var behov: [Int: [Int]] = [:]
        for (k, g) in grannar {
            for n in [k, g.fore, g.efter].compactMap({ $0 }) { behov[n, default: []].append(k) }
        }
        var delar: [Int: [Int: [UInt8]]] = [:]
        var lager: [Int: StrobLager] = [:]
        let sista = max(1, behov.keys.max() ?? 1)
        try varjeRuta(asset: asset, track: track, pts: pts, exif: exif, ut: ut) { n, bild in
            guard let vilka = behov[n], let cg = ci.createCGImage(bild, from: hel) else { return }
            for k in vilka {
                guard let box = huvud[k], let g = grannar[k], let r = KlubbStrob.ruta(box, bredd: ut.w, hojd: ut.h),
                      let bit = cg.cropping(to: CGRect(x: r.x0, y: r.y0, width: r.bredd, height: r.hojd)) else { continue }
                delar[k, default: [:]][n] = rgba(bit, bredd: r.bredd, hojd: r.hojd).pixlar
                let d = delar[k] ?? [:]
                guard let egen = d[k], [g.fore, g.efter].allSatisfy({ $0 == nil || d[$0!] != nil }) else { continue }
                let medianDel = median.map {
                    KlubbStrob.del($0, x0: r.x0, y0: r.y0, bredd: r.bredd, hojd: r.hojd, skala: medianSkala)
                }
                lager[k] = KlubbStrob.lager(pixlar: egen, x0: r.x0, y0: r.y0, bredd: r.bredd, hojd: r.hojd,
                                            referenser: [g.fore.flatMap { d[$0] }, g.efter.flatMap { d[$0] }, medianDel])
                delar[k] = nil
            }
            framsteg(andel.huvud + andel.lager * Double(n) / Double(sista))
        }
        try Task.checkCancellation()
        let ordning = lager.keys.sorted()
        guard !ordning.isEmpty else { return .fel(String(localized: "No club head was found")) }
        for k in ordning { KlubbStrob.lagg(lager[k]!, i: &bild) }
        guard let cg = cgImage(bild) else { return .fel(String(localized: "The video could not be read")) }

        // (3) Filmen. Går den inte att skriva visas bilden ändå.
        let resten = 1 - andel.huvud - andel.lager
        let filmen = try await skrivFilm(asset: asset, track: track, pts: pts, exif: exif, ut: ut, lager: lager, ci: ci,
                                         till: film) { v in framsteg(andel.huvud + andel.lager + resten * v) }
        return .klar(cg, film: filmen, huvuden: ordning.count, rutor: rutor.count)
    }

    /// Rutorna från P1 till P9 med huvudena pålagda efter hand, H.264 i `filmFps`. nil när filmen
    /// inte gick att skriva.
    private static func skrivFilm(asset: AVAsset, track: AVAssetTrack, pts: [Double], exif: UInt32,
                                  ut: (w: Int, h: Int), lager: [Int: StrobLager], ci: CIContext, till url: URL,
                                  framsteg: (Double) -> Void) async throws -> URL? {
        try? FileManager.default.removeItem(at: url)
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return nil }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: ut.w,
            AVVideoHeightKey: ut.h,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 12_000_000],
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: ut.w,
            kCVPixelBufferHeightKey as String: ut.h,
        ])
        guard writer.canAdd(input) else { return nil }
        writer.add(input)
        guard writer.startWriting() else { return nil }
        writer.startSession(atSourceTime: .zero)
        let rymd = CGColorSpace(name: CGColorSpace.sRGB)!
        var pa: [StrobLager] = []
        var nr: Int64 = 0
        var gick = true
        try varjeRuta(asset: asset, track: track, pts: pts, exif: exif, ut: ut) { k, bild in
            guard gick, let pool = adaptor.pixelBufferPool else {
                gick = false
                return
            }
            var buffert: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffert) == kCVReturnSuccess, let pb = buffert else {
                gick = false
                return
            }
            ci.render(bild, to: pb, bounds: CGRect(x: 0, y: 0, width: ut.w, height: ut.h), colorSpace: rymd)
            if let l = lager[k] { pa.append(l) }
            lagg(pa, i: pb)
            while !input.isReadyForMoreMediaData {
                try Task.checkCancellation()
                Thread.sleep(forTimeInterval: 0.002)
            }
            gick = adaptor.append(pb, withPresentationTime: CMTime(value: nr, timescale: filmFps))
            nr += 1
            framsteg(Double(k + 1) / Double(pts.count))
        }
        input.markAsFinished()
        guard gick, nr > 0 else {
            writer.cancelWriting()
            return nil
        }
        await writer.finishWriting()
        return writer.status == .completed ? url : nil
    }

    /// Lagren (RGBA) in i en BGRA-buffert.
    private static func lagg(_ lager: [StrobLager], i pb: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }
        guard let bas = CVPixelBufferGetBaseAddress(pb)?.assumingMemoryBound(to: UInt8.self) else { return }
        let rad = CVPixelBufferGetBytesPerRow(pb)
        let b = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb)
        for l in lager where l.x0 + l.bredd <= b && l.y0 + l.hojd <= h {
            for y in 0..<l.hojd {
                for x in 0..<l.bredd where l.mask[y * l.bredd + x] {
                    let i = (y * l.bredd + x) * 4, j = (l.y0 + y) * rad + (l.x0 + x) * 4
                    bas[j] = l.pixlar[i + 2]
                    bas[j + 1] = l.pixlar[i + 1]
                    bas[j + 2] = l.pixlar[i]
                }
            }
        }
    }

    /// Slagets rutor ur filen i tidsordning: (rutans plats i `pts`, bilden upprätt i `ut` px med
    /// origo i (0, 0)). Varje ruta högst en gång; en bild längre än en halv ruta (240/s) från alla
    /// `pts` hoppas över.
    private static func varjeRuta(asset: AVAsset, track: AVAssetTrack, pts: [Double], exif: UInt32,
                                  ut: (w: Int, h: Int), _ gor: (Int, CIImage) throws -> Void) throws {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw MediaReader.ReadError.cannotRead }
        reader.add(output)
        reader.timeRange = CMTimeRange(start: CMTime(seconds: max(0, pts[0] - 0.02), preferredTimescale: 48_000),
                                       end: CMTime(seconds: pts[pts.count - 1] + 0.02, preferredTimescale: 48_000))
        guard reader.startReading() else { throw reader.error ?? MediaReader.ReadError.cannotRead }
        defer { reader.cancelReading() }
        let orientering = CGImagePropertyOrientation(rawValue: exif) ?? .up
        var lasta = Set<Int>()
        while let buffer = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            try autoreleasepool {
                guard let pb = CMSampleBufferGetImageBuffer(buffer) else { return }
                let t = CMSampleBufferGetPresentationTimeStamp(buffer).seconds
                guard let k = pts.indices.min(by: { abs(pts[$0] - t) < abs(pts[$1] - t) }),
                      abs(pts[k] - t) <= 0.5 / 240, !lasta.contains(k) else { return }
                lasta.insert(k)
                var bild = CIImage(cvPixelBuffer: pb).oriented(orientering)
                bild = bild.transformed(by: CGAffineTransform(translationX: -bild.extent.minX, y: -bild.extent.minY))
                bild = bild.transformed(by: CGAffineTransform(scaleX: CGFloat(ut.w) / bild.extent.width,
                                                              y: CGFloat(ut.h) / bild.extent.height))
                try gor(k, bild)
            }
        }
        if reader.status == .failed { throw reader.error ?? MediaReader.ReadError.cannotRead }
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
