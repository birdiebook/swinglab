import AVFoundation
import CoreGraphics
import Foundation
import Observation
import UIKit
import Capture

/// Passets analys (S2_SPEC §4.3, §6, §8.2, §12 S2e): serien → klicken → det glesa
/// Vision-passet och domen → det täta passet med lederna → klippen kring slagen →
/// passet. Ordningen, fönstren, personvalet och domen står i SwingLabKit (`ShotPlan`,
/// `PoseTrack`, `SwingCheck`); här körs stegen med AVFoundation och Vision.
///
/// I förgrunden med skärmen på, ett steg i taget, och passet sparas efter varje steg:
/// avbryts appen fortsätter analysen nästa gång från första slag som saknar något.
/// Passet publiceras efter varje sparning (`pass`), så att listan fylls under analysen.
/// Ett fel stoppar analysen på slaget och visas, även när passet inte gick att spara;
/// ingenting sväljs. BESLUT B25. METOD MS12
@MainActor
@Observable
final class Analysis {
    private(set) var running = false
    private(set) var step: AnalysisStep?
    /// Passet som det senast sparades, för listan under analysen.
    private(set) var pass: PassState?
    /// Slagets plats i listan och antalet slag ("Shot 7 of 23").
    private(set) var shotNumber = 0
    private(set) var shotTotal = 0
    /// Stegen gjorda och alla steg, och hur långt det pågående steget kommit (0–1).
    private(set) var done = 0
    private(set) var total = 0
    private(set) var stepFraction = 0.0
    /// Felet som stoppade analysen, för vyn och provet.
    private(set) var problem: String?
    private(set) var lastError: Error?
    /// Stegen som gjordes i den senaste körningen (provet prövar återupptagningen med dem).
    private(set) var stepsRun: [AnalysisStep] = []

    var fraction: Double { total > 0 ? min(1, (Double(done) + stepFraction) / Double(total)) : 0 }

    /// Sparar passet och publicerar det; ett fel kastas (analysen stannar). BESLUT B25
    private func persist(_ p: PassState, _ store: Store) throws {
        try store.write(p)
        pass = p
    }

    /// Kör alla steg som saknas och svarar passet som det står på disken efteråt.
    @discardableResult
    func run(passID: String, store: Store, source: PoseSource = VisionPoseSource()) async -> PassState? {
        guard !running, var pass = store.load(passID) else { return nil }
        running = true
        problem = nil
        lastError = nil
        stepsRun = []
        self.pass = pass
        UIApplication.shared.isIdleTimerDisabled = true
        defer {
            running = false
            step = nil
            UIApplication.shared.isIdleTimerDisabled = false
        }
        do {
            pass.syncShots()
            // Ett pass från före S4b: slagen med leder får sina mått först (METOD MS14).
            let id = pass.id
            pass.measureShots(height: store.settings.heightM) { s in s.joints.flatMap { store.joints($0, in: id) } }
            try persist(pass, store)
            while let next = ShotPlan.next(pass), !Task.isCancelled {
                step = next
                stepFraction = 0
                let p = ShotPlan.progress(pass)
                done = p.done
                total = p.total
                shotNumber = next.shot + 1
                shotTotal = pass.shots.count
                do {
                    pass = try await perform(next, pass: pass, store: store, source: source)
                } catch {
                    lastError = error
                    problem = String(localized: "Shot \(shotNumber) could not be analyzed: \(error.localizedDescription)")
                    try? persist(pass, store)
                    return pass
                }
                stepsRun.append(next)
                try persist(pass, store)
            }
            if ShotPlan.next(pass) == nil, pass.status == .recorded {
                pass.status = .analyzed
                try persist(pass, store)
            }
        } catch {
            // Passet gick inte att spara: analysen stannar här och säger det.
            lastError = error
            problem = String(localized: "pass.json could not be saved.")
            return store.load(passID)
        }
        let p = ShotPlan.progress(pass)
        done = p.done
        total = p.total
        return pass
    }

    enum AnalysisError: LocalizedError {
        case outsideFile
        var errorDescription: String? { String(localized: "The click is outside the file.") }
    }

    /// Ett steg: Vision-passet (domen eller lederna) eller klippet.
    private func perform(_ step: AnalysisStep, pass: PassState, store: Store,
                         source: PoseSource) async throws -> PassState {
        var pass = pass
        let i = step.shot
        let shot = pass.shots[i]
        guard let serie = pass.series.first(where: { $0.nr == shot.series }) else { return pass }
        let file = store.url(serie.file, in: pass.id)
        switch step {
        case .sparse, .dense:
            guard let request = ShotPlan.request(step, pass: pass, file: file) else { throw AnalysisError.outsideFile }
            let vy = self
            let scan = try await Task.detached(priority: .userInitiated) {
                try await source.scan(request) { f in
                    Task { @MainActor in vy.stepFraction = f }
                }
            }.value
            let series = PoseTrack.series(scan.frames, click: shot.click.time, width: serie.uprightWidth,
                                          height: serie.uprightHeight, crop: request.crop)
            var stats = pass.vision ?? VisionStats()
            stats.add(scan, picked: series.frames.filter { $0.confidence >= PoseRules.observationConfidence }.count)
            pass.vision = stats
            if case .sparse = step {
                pass.shots[i].verdict = SwingCheck.verdict(series)
            } else {
                pass.shots[i].joints = try store.writeJoints(series, shot: shot.id, in: pass.id)
                pass.shots[i].jointFrames = series.frames.count
                pass.shots[i].orientationSuspect = series.orientationSuspect
                // Måtten ur samma avrundade leder som filen och paketet (METOD MS12, MS14).
                pass.shots[i].measure = ShotMeasuring.measure(series.rounded(), shot: pass.shots[i], setup: pass.setup,
                                                              height: store.settings.heightM)
            }
        case .clip:
            // Klippet inom seriens fönster ur redigeraren (METOD MS13).
            guard let w = ShotPlan.window(ShotPlan.clipWindow, click: shot.click.time, series: serie) else {
                throw AnalysisError.outsideFile
            }
            let rel = ShotRecord.clipPath(shot.id)
            let url = store.url(rel, in: pass.id)
            try await Clips.export(file, range: w, to: url)
            let klick = try await MediaReader.clicks(url)
            let m = ClipCheck.measure(klick, expected: shot.click.time - w.lowerBound)
            pass.shots[i].clip = rel
            pass.shots[i].clipStart = w.lowerBound
            pass.shots[i].clickInClip = m.time
            pass.shots[i].clipFlagged = m.flagged
        }
        return pass
    }
}

/// Klippen kring slagen (S2_SPEC §8.2): passthrough, utan omkodning. Var klippet exakt
/// börjar är inte dokumenterat; därför mäts klicket om i klippet (METOD MS12).
enum Clips {
    enum ClipError: LocalizedError {
        case cannotExport
        var errorDescription: String? { String(localized: "The clip could not be saved.") }
    }

    static func export(_ source: URL, range: ClosedRange<Double>, to url: URL) async throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let asset = AVURLAsset(url: source)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw ClipError.cannotExport
        }
        session.timeRange = CMTimeRange(start: CMTime(seconds: range.lowerBound, preferredTimescale: 48_000),
                                        end: CMTime(seconds: range.upperBound, preferredTimescale: 48_000))
        try await session.export(to: url, as: .mov)
    }
}

/// Miniatyren vid träffen: rutan ur seriens fil (eller klippet, om originalet är borttaget,
/// BESLUT B26) och de uppmätta linjerna ur lederna (BESLUT B13: ingen figur).
enum ShotImages {
    /// Den upprätta rutan vid träffen, skuren till seriens utsnitt (S2i), högst `maxSize`
    /// punkter. nil = ingen fil att läsa. METOD MS13
    static func impactFrame(pass: PassState, shot: ShotRecord, store: Store,
                            maxSize: CGSize = CGSize(width: 270, height: 480)) async throws -> CGImage? {
        try await frame(pass: pass, shot: shot, store: store, at: shot.impact, maxSize: maxSize)
    }

    /// Den upprätta rutan vid tiden t i seriens fil, skuren till utsnittet; ur klippet när
    /// originalet är borttaget. Granskningens prov läser sina stillbilder så. METOD MS13, MS15
    static func frame(pass: PassState, shot: ShotRecord, store: Store, at t0: Double,
                      maxSize: CGSize = CGSize(width: 270, height: 480)) async throws -> CGImage? {
        guard let serie = pass.series.first(where: { $0.nr == shot.series }) else { return nil }
        let crop = serie.activeCrop
        var url = store.url(serie.file, in: pass.id)
        var t = t0
        if !FileManager.default.fileExists(atPath: url.path) {
            guard let clip = shot.clip, let offset = clipOffset(shot) else { return nil }
            url = store.url(clip, in: pass.id)
            t = t0 + offset
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let g = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        g.appliesPreferredTrackTransform = true
        g.requestedTimeToleranceBefore = .zero
        g.requestedTimeToleranceAfter = .zero
        // Med utsnitt läses rutan större, så att den skurna delen får samma upplösning.
        g.maximumSize = crop.map { CGSize(width: maxSize.width / $0.width, height: maxSize.height / $0.height) } ?? maxSize
        let bild = try await g.image(at: CMTime(seconds: max(0, t), preferredTimescale: 48_000)).image
        return crop.map { cropped(bild, $0) } ?? bild
    }

    /// Den upprätta bilden skuren till utsnittet (normaliserat, origo uppe till vänster).
    static func cropped(_ image: CGImage, _ crop: CropRect) -> CGImage {
        let px = crop.pixels(width: image.width, height: image.height)
        let r = CGRect(x: px.x, y: px.y, width: px.width, height: px.height)
        return image.cropping(to: r) ?? image
    }

    /// Träffen i klippets tid: utgår från klicket som mättes i klippet (var passthrough-
    /// klippet börjar är inte dokumenterat), annars från den begärda starten. METOD MS12
    static func clipTime(_ shot: ShotRecord) -> Double? {
        clipOffset(shot).map { shot.impact + $0 }
    }

    /// Klippets tid − seriens tid: klicket mätt i klippet − klicket i serien, annars −den
    /// begärda starten. METOD MS12
    static func clipOffset(_ shot: ShotRecord) -> Double? {
        if let k = shot.clickInClip { return k - shot.click.time }
        return shot.clipStart.map { -$0 }
    }

    /// Linjerna vid träffen ur slagets leder, i utsnittets koordinater som miniatyren, eller
    /// nil före det täta passet. METOD MS13
    static func overlay(shot: ShotRecord, pass: PassState, store: Store) -> ImpactOverlay? {
        guard let rel = shot.joints, let series = store.joints(rel, in: pass.id) else { return nil }
        let crop = pass.series.first { $0.nr == shot.series }?.activeCrop
        return ImpactOverlay.at(series, t: shot.impact - shot.click.time)?.cropped(crop)
    }
}
