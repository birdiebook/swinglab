import AVFoundation
import CoreImage
import CoreMedia
import Foundation
import ImageIO
import Vision
import Capture

/// Vision på rutorna i ett fönster av filen (S2_SPEC §6.1): `VNDetectHumanBodyPoseRequest`
/// (revision 1) på varje ruta ur `AVAssetReader`, med rutans egen tid och
/// EXIF-orienteringen ur spårets transform så att personen står upp. Valet av person,
/// domen och allt annat görs i SwingLabKit på värdena härifrån. Ett fel från Vision
/// kastas vidare; ingenting sväljs (analysen stannar på slaget och fortsätter därifrån).
/// BESLUT B25, B29. METOD MS7, MS8, MS12
struct VisionPoseSource: PoseSource {
    enum PoseError: LocalizedError {
        case noVideo, cannotRead
        var errorDescription: String? {
            switch self {
            case .noVideo: return String(localized: "The file has no video.")
            case .cannotRead: return String(localized: "The file could not be read.")
            }
        }
    }

    /// Visions leder i `JointSeries.names` ordning (S2_SPEC §6.3). Vänster är personens
    /// vänster (WWDC20 10653). BESLUT B29
    static let joints: [VNHumanBodyPoseObservation.JointName] = [
        .nose, .leftShoulder, .rightShoulder, .leftElbow, .rightElbow, .leftWrist, .rightWrist,
        .leftHip, .rightHip, .leftKnee, .rightKnee, .leftAnkle, .rightAnkle,
    ]

    /// Bilden Vision får för en ruta. Utan utsnitt rutan som den är, med EXIF-orienteringen
    /// (vägen från S2e). Med utsnitt den upprätta bilden utskuren till rutan (`cutOut`), med
    /// origo i (0, 0) och orienteringen `.up`: Visions punkter blir då normaliserade mot just
    /// den bild den fick (WWDC20 10653), utan `regionOfInterest` vars koordinater för
    /// kroppens leder inte är dokumenterade. METOD MS13, BESLUT B34
    enum Input {
        case buffer(CMSampleBuffer, CGImagePropertyOrientation)
        case image(CIImage)
    }

    /// Visions anrop på en ruta: personerna i bilden.
    typealias Detect = (Input) throws -> [VNHumanBodyPoseObservation]

    /// Gör anropet för en körning. Standard är Vision (`vision()`). Simulatorprovet byter
    /// det mot ett som räknar rutorna och svarar inga personer, eftersom Vision inte går
    /// att starta i simulatorn (METOD MS12); läsningen runt omkring är densamma.
    let makeDetect: () throws -> Detect

    init(makeDetect: @escaping () throws -> Detect = VisionPoseSource.vision) {
        self.makeDetect = makeDetect
    }

    /// `VNDetectHumanBodyPoseRequest` revision 1, en fråga per körning som återanvänds för
    /// varje ruta (tillståndslös). I simulatorn kastar `perform` "Unable to setup request"
    /// (Vision kod 9), även på CPU (simulatorprovet 2026-10-22). METOD MS12
    static func vision() throws -> Detect {
        let request = VNDetectHumanBodyPoseRequest()
        request.revision = VNDetectHumanBodyPoseRequestRevision1
        return { input in
            switch input {
            case .buffer(let sb, let orientation):
                try VNImageRequestHandler(cmSampleBuffer: sb, orientation: orientation, options: [:]).perform([request])
            case .image(let image):
                try VNImageRequestHandler(ciImage: image, orientation: .up, options: [:]).perform([request])
            }
            return request.results ?? []
        }
    }

    func scan(_ r: PoseScanRequest, progress: @escaping @Sendable (Double) -> Void) async throws -> PoseScan {
        let asset = AVURLAsset(url: r.file)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw PoseError.noVideo }
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(start: CMTime(seconds: max(0, r.from), preferredTimescale: 48_000),
                                       end: CMTime(seconds: r.to, preferredTimescale: 48_000))
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw PoseError.cannotRead }
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? PoseError.cannotRead }

        let orientation = CGImagePropertyOrientation(rawValue: r.exif) ?? .up
        let detect = try makeDetect()
        let stride = max(1, r.stride)
        let span = max(r.to - r.from, 1e-6)
        let start = Date()
        var frames: [ScannedFrame] = []
        var decoded = 0
        var visionSeconds = 0.0
        var k = 0
        while let sb = output.copyNextSampleBuffer() {
            try autoreleasepool {                                // annars växer minnet med varje pixelbuffert
                guard CMSampleBufferGetNumSamples(sb) > 0 else { return }
                let pts = CMSampleBufferGetPresentationTimeStamp(sb)
                guard pts.isValid else { return }
                let t = pts.seconds
                // Läsaren kan ge en ruta strax före fönstret; den räknas inte.
                guard t >= r.from - 1e-6, t <= r.to + 1e-6 else { return }
                decoded += 1
                defer { k += 1 }
                guard k % stride == 0 else { return }
                let v0 = Date()
                let candidates: [PoseFrame]
                if let crop = r.crop {
                    guard let pb = CMSampleBufferGetImageBuffer(sb) else { throw PoseError.cannotRead }
                    let cut = Self.cutOut(pb, orientation: orientation, crop: crop)
                    candidates = try detect(.image(cut.image)).map { try Self.frame($0, pts: t, r, crop: cut.crop) }
                } else {
                    candidates = try detect(.buffer(sb, orientation)).map { try Self.frame($0, pts: t, r, crop: nil) }
                }
                visionSeconds += Date().timeIntervalSince(v0)
                frames.append(ScannedFrame(pts: t, candidates: candidates))
                if frames.count % 16 == 0 { progress(min(1, max(0, (t - r.from) / span))) }
            }
        }
        if reader.status == .failed { throw reader.error ?? PoseError.cannotRead }
        return PoseScan(frames: frames, decodedFrames: decoded, visionSeconds: visionSeconds,
                        wallSeconds: Date().timeIntervalSince(start))
    }

    /// Rutan ur en lagrad pixelbuffert: upprätt (`oriented`), utskuren till utsnittet på
    /// hela pixlar (Core Image räknar y nerifrån: `CropRect.pixelsFromBottom`) och flyttad
    /// till origo, så att bilden Vision får börjar i (0, 0). Svarar också rutan som skars ut,
    /// som andelar (`CropRect.snapped`), som punkterna förs tillbaka genom. METOD MS13
    static func cutOut(_ pb: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                       crop: CropRect) -> (image: CIImage, crop: CropRect) {
        let upright = CIImage(cvPixelBuffer: pb).oriented(orientation)
        let e = upright.extent
        let w = Int(e.width.rounded()), h = Int(e.height.rounded())
        let p = crop.pixelsFromBottom(width: w, height: h)
        let r = CGRect(x: e.minX + CGFloat(p.x), y: e.minY + CGFloat(p.y), width: CGFloat(p.width),
                       height: CGFloat(p.height))
        let image = upright.cropped(to: r).transformed(by: CGAffineTransform(translationX: -r.minX, y: -r.minY))
        return (image, crop.snapped(width: w, height: h))
    }

    /// En observation till värden: punkterna per namn, normaliserade i bilden Vision fick
    /// (den upprätta, eller den utskurna rutan), till pixlar i hela den upprätta bilden i
    /// SwingLabKit. Konfidens 0 = ogiltig (Apple), sparas som saknad. METOD MS13
    static func frame(_ o: VNHumanBodyPoseObservation, pts: Double, _ r: PoseScanRequest,
                      crop: CropRect?) throws -> PoseFrame {
        let all = try o.recognizedPoints(.all)
        let points = joints.map { name -> PoseJoint? in
            guard let p = all[name] else { return nil }
            return PoseJoint(x: Double(p.location.x), y: Double(p.location.y), c: Double(p.confidence))
        }
        return PoseFrame.fromVision(pts: pts, points: points, confidence: Double(o.confidence),
                                    uprightWidth: r.uprightWidth, uprightHeight: r.uprightHeight, crop: crop)
    }
}
