import AVFoundation
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
        let request = VNDetectHumanBodyPoseRequest()            // tillståndslös, återanvänds
        request.revision = VNDetectHumanBodyPoseRequestRevision1
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
                let handler = VNImageRequestHandler(cmSampleBuffer: sb, orientation: orientation, options: [:])
                try handler.perform([request])
                let candidates = try (request.results ?? []).map { try Self.frame($0, pts: t, r) }
                visionSeconds += Date().timeIntervalSince(v0)
                frames.append(ScannedFrame(pts: t, candidates: candidates))
                if frames.count % 16 == 0 { progress(min(1, max(0, (t - r.from) / span))) }
            }
        }
        if reader.status == .failed { throw reader.error ?? PoseError.cannotRead }
        return PoseScan(frames: frames, decodedFrames: decoded, visionSeconds: visionSeconds,
                        wallSeconds: Date().timeIntervalSince(start))
    }

    /// En observation till värden: punkterna per namn, normaliserade i den orienterade
    /// bilden, till pixlar i SwingLabKit. Konfidens 0 = ogiltig (Apple), sparas som saknad.
    static func frame(_ o: VNHumanBodyPoseObservation, pts: Double, _ r: PoseScanRequest) throws -> PoseFrame {
        let all = try o.recognizedPoints(.all)
        let points = joints.map { name -> PoseJoint? in
            guard let p = all[name] else { return nil }
            return PoseJoint(x: Double(p.location.x), y: Double(p.location.y), c: Double(p.confidence))
        }
        return PoseFrame.fromVision(pts: pts, points: points, confidence: Double(o.confidence),
                                    uprightWidth: r.uprightWidth, uprightHeight: r.uprightHeight)
    }
}
