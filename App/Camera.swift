import AVFoundation
import Observation
import SwiftUI
import UIKit
import Capture

/// Bakre kameran i 1080p 240 bilder/s med låst slutartid, fokus och vitbalans, och
/// ljudet i samma fil (S2_SPEC §2). Grunden är Airtimes CameraRecorder; formatet och
/// exponeringen räknas i SwingLabKit så att inget tal lämnar formatets gränser (risk R2).
/// BESLUT B15, B16, B17
@Observable
final class Camera: NSObject, AVCaptureFileOutputRecordingDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    enum Phase: Equatable { case idle, starting, metering, ready, recording, probing, failed }

    /// En avslutad serie.
    struct Finished: Equatable {
        let url: URL
        /// Filens tid noll på värdklockan (startPTS), s.
        let startHost: Double?
        let started: Date
        let pressure: Pressure
        let ok: Bool
        /// Gravitationen under serien (S6b): lodlinjen räknas ur den i SwingLabKit. METOD MS17
        var gravity: [GravitySample] = []
    }

    let session = AVCaptureSession()
    @ObservationIgnored private let output = AVCaptureMovieFileOutput()
    @ObservationIgnored private let queue = DispatchQueue(label: "swinglab.kamera")
    @ObservationIgnored private var device: AVCaptureDevice?
    @ObservationIgnored private var pressureObservation: NSKeyValueObservation?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var startHosts: [URL: Double] = [:]
    @ObservationIgnored private var seriesStart = Date()
    /// Lodlinjens inspelare för pågående serie (S6b). METOD MS17
    @ObservationIgnored private var gravityToken: Int?
    @ObservationIgnored private var probeURL: URL?
    @ObservationIgnored private var probeWaiter: CheckedContinuation<Bool, Never>?
    @ObservationIgnored private var probeDone: Bool?
    @ObservationIgnored private var seriesWaiter: CheckedContinuation<Finished?, Never>?
    /// Följarens förhandsbild till den styrande (S2k, BESLUT B90): sätts före `start()`. Rutorna
    /// kommer ur en egen videoutgång i förhandsbildens storlek (`deliversPreviewSizedOutputBuffers`),
    /// som är avstängd när ingen tar emot och under varje inspelning. METOD MS35
    @ObservationIgnored var forhandsbild: ForhandsKalla?
    @ObservationIgnored private var dataOutput: AVCaptureVideoDataOutput?
    @ObservationIgnored private let forhandsQueue = DispatchQueue(label: "swinglab.forhandsbild")
    /// Den styrande vill ha bilden (takten över noll); kamerans kö.
    @ObservationIgnored private var forhandsPa = false

    private(set) var phase: Phase = .idle
    /// Rutnätet som ställdes in, bilder/s.
    private(set) var frameRate: Double = 0
    /// Formatet når 240 (annars visas frekvensen i signalfärgen). METOD MS1
    private(set) var reachesWanted = false
    /// Alla format telefonen rapporterade och det valda (till enhet.json i S2f).
    private(set) var formats: [CameraFormat] = []
    private(set) var chosen: CameraFormat?
    private(set) var exposure: ExposureRecord?
    private(set) var pressure: Pressure = .nominal
    /// Det högsta trycket under pågående serie.
    @ObservationIgnored private var seriesPressure: Pressure = .nominal
    /// Mikrofonens porttyp, och om den inte är den inbyggda (risk R9).
    private(set) var microphone: String?
    private(set) var micWarning = false
    private(set) var audioDenied = false
    var problem: String?
    /// Sätts när en serie är inspelad.
    var finished: Finished?

    // MARK: Start och stopp

    @MainActor
    func start() async {
        guard phase == .idle || phase == .failed else { return }
        phase = .starting
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            problem = String(localized: "Camera access is off for SwingLab in Settings.")
            phase = .failed
            return
        }
        let audio = await AVCaptureDevice.requestAccess(for: .audio)
        audioDenied = !audio
        UIApplication.shared.isIdleTimerDisabled = true
        observeInterruptions()
        do {
            if chosen == nil {                               // en gång per kamera: in- och utgångar finns sedan
                let described = try await onQueueThrowing { try self.configure(audio: audio) }
                let (active, rate) = await onQueue { self.readBack(described) }
                formats = described
                chosen = active
                frameRate = rate.rounded()
                // Det som ställdes in, inte det som begärdes. METOD MS1
                reachesWanted = FormatChoice.reaches(rate: rate)
                guard active != nil, rate > 0 else { throw CameraError.noFormat }
            }
            if pressureObservation == nil, let device {
                pressureObservation = device.observe(\.systemPressureState, options: [.initial, .new]) { [weak self] d, _ in
                    let p = Pressure(rawValue: d.systemPressureState.level.rawValue) ?? .nominal
                    DispatchQueue.main.async { self?.pressureChanged(p) }
                }
            }
            await onQueue {
                self.session.startRunning()
                self.kontrolleraForhandsbild()
            }
            checkMicrophone()
            phase = .metering
            exposure = await onQueue { self.meterAndLock() }
            phase = .ready
        } catch {
            // Sessionen rivs, så att nästa start() börjar från noll.
            await onQueue { self.tearDown() }
            chosen = nil
            problem = (error as? CameraError) == .noFormat
                ? String(localized: "No 1080p format with at least 120 fps.")
                : String(localized: "The camera could not start.")
            phase = .failed
        }
    }

    @MainActor
    func stop() {
        UIApplication.shared.isIdleTimerDisabled = false
        for o in observers { NotificationCenter.default.removeObserver(o) }
        observers = []
        pressureObservation = nil
        queue.async { [self] in
            if output.isRecording { output.stopRecording() }
            session.stopRunning()
        }
        if phase != .failed { phase = .idle }
    }

    // MARK: Serien

    /// Startar en serie till `url` (passets Video/nn.mov). Disken kontrolleras först. METOD MS11
    @MainActor
    func startSeries(to url: URL, available: Int64?) {
        guard phase == .ready else { return }
        guard PassStorage.canStart(available: available) else {
            problem = String(localized: "Less than 4 GB free.")
            return
        }
        problem = nil
        seriesStart = Date()
        seriesPressure = pressure
        phase = .recording
        gravityToken = GravityRecorder.shared.start()                 // lodlinjen (S6b), METOD MS17
        queue.async { [self] in
            setForhandsConnection(false)                                // ingen förhandsbild under serien (MS35)
            output.startRecording(to: url, recordingDelegate: self)
        }
    }

    /// Avslutar en pågående serie och väntar på filen, när vyn försvinner mitt i en
    /// serie: serien sparas i stället för att bli en fil utan ägare. nil = ingen serie.
    @MainActor
    func finishSeries() async -> Finished? {
        guard phase == .recording else { return nil }
        return await withCheckedContinuation { c in
            seriesWaiter = c
            stopSeries()
        }
    }

    func stopSeries() {
        queue.async { [self] in if output.isRecording { output.stopRecording() } }
    }

    // MARK: Ljusprovet (S2_SPEC §2.7)

    /// Mäter ljuset igen, låser och spelar in 2 s till tmp/. Svarar filen och planen;
    /// `LightProbe.analyze` läser den. METOD MS3
    @MainActor
    func recordProbe() async -> (url: URL, exposure: ExposureRecord)? {
        guard phase == .ready else { return nil }
        phase = .probing
        exposure = await onQueue { self.meterAndLock() }
        guard let rec = self.exposure else { phase = .ready; return nil }
        let url = FileManager.default.temporaryDirectory.appending(path: "ljusprov-\(UUID().uuidString).mov")
        probeURL = url
        probeDone = nil
        queue.async { [self] in
            setForhandsConnection(false)                                // inte under ljusprovet (MS35)
            output.startRecording(to: url, recordingDelegate: self)
        }
        try? await Task.sleep(for: .seconds(LightProbe.seconds + 0.3))
        let ok: Bool = await withCheckedContinuation { c in
            if let done = probeDone {
                c.resume(returning: done)
            } else {
                probeWaiter = c
                queue.async { [self] in if output.isRecording { output.stopRecording() } }
            }
        }
        probeURL = nil
        phase = .ready
        if !ok { try? FileManager.default.removeItem(at: url) }       // ingen fil utan ägare
        return ok ? (url, rec) : nil
    }

    // MARK: Delegaten

    /// Filens första ruta på sessionens klocka, omräknad till värdklockan (S2_SPEC §2.1). BESLUT B19
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, startPTS: CMTime,
                    from connections: [AVCaptureConnection]) {
        let clock = session.synchronizationClock ?? CMClock.hostTimeClock
        let host = CMSyncConvertTime(startPTS, from: clock, to: CMClock.hostTimeClock)
        DispatchQueue.main.async { self.startHosts[fileURL] = host.isValid ? host.seconds : nil }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: Error?) {
        let ok = error == nil
            || ((error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool ?? false)
        DispatchQueue.main.async { self.didFinish(outputFileURL, ok: ok) }
    }

    private func didFinish(_ url: URL, ok: Bool) {
        if url == probeURL {
            if let w = probeWaiter {
                probeWaiter = nil
                w.resume(returning: ok)
            } else {
                probeDone = ok
            }
            return
        }
        if !ok { problem = String(localized: "The recording was interrupted.") }
        let f = Finished(url: url, startHost: startHosts.removeValue(forKey: url), started: seriesStart,
                         pressure: seriesPressure, ok: ok,
                         gravity: gravityToken.map { GravityRecorder.shared.stop($0) } ?? [])
        gravityToken = nil
        if phase == .recording { phase = .ready }
        if let w = seriesWaiter {
            seriesWaiter = nil
            w.resume(returning: f)                                       // vyn som försvann sparar den
        } else {
            finished = f
        }
    }

    // MARK: Inställningen (körs på kön)

    enum CameraError: Error { case noCamera, noFormat, cannotAdd }

    /// Körs på `queue`. Formatet väljs först, ur det telefonen rapporterar, så att
    /// ett saknat format inte lämnar halva sessionen kvar; sedan in- och utgångar,
    /// formatet och bildtiden (S2_SPEC §2.2). Vid fel rivs sessionen, så att nästa
    /// `start()` börjar om från noll.
    private func configure(audio: Bool) throws -> [CameraFormat] {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.noCamera
        }
        let described = Self.describe(device.formats)
        guard let index = FormatChoice.choose(described), index < device.formats.count else { throw CameraError.noFormat }
        let format = device.formats[index]
        let input = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        do {
            guard session.canAddInput(input) else { throw CameraError.cannotAdd }
            session.addInput(input)
            if audio, let mic = AVCaptureDevice.default(for: .audio),
               let micInput = try? AVCaptureDeviceInput(device: mic), session.canAddInput(micInput) {
                session.addInput(micInput)
            }
            guard session.canAddOutput(output) else { throw CameraError.cannotAdd }
            session.addOutput(output)
            output.minFreeDiskSpaceLimit = PassStorage.recordingFloor
            addForhandsOutput()

            try device.lockForConfiguration()
            device.activeFormat = format                                  // sessionens preset blir .inputPriority
            if let range = format.videoSupportedFrameRateRanges.max(by: { $0.maxFrameRate < $1.maxFrameRate }) {
                device.activeVideoMinFrameDuration = range.minFrameDuration   // ur intervallet, inte 1/240 (risk R3)
                device.activeVideoMaxFrameDuration = range.minFrameDuration   // fast takt: ingen sänkning i mörker
            }
            device.videoZoomFactor = 1.0
            if format.isVideoHDRSupported {
                device.automaticallyAdjustsVideoHDREnabled = false
                device.isVideoHDREnabled = false
            }
            device.unlockForConfiguration()
        } catch {
            for i in session.inputs { session.removeInput(i) }
            for o in session.outputs { session.removeOutput(o) }
            dataOutput = nil
            throw error
        }
        if let c = output.connection(with: .video) {
            if c.isVideoRotationAngleSupported(90) { c.videoRotationAngle = 90 }
            if c.isVideoStabilizationSupported { c.preferredVideoStabilizationMode = .off }
        }
        self.device = device
        return described
    }

    // MARK: Förhandsbilden (S2k, BESLUT B90, METOD MS35)

    /// Körs på `queue` i konfigurationen: följarens egen videoutgång i förhandsbildens storlek, som
    /// kameran skalar själv. Avstängd tills den styrande tar emot. Går den inte att lägga till blir
    /// det ingen förhandsbild, och inspelningen är som förut.
    private func addForhandsOutput() {
        guard forhandsbild != nil, dataOutput == nil else { return }
        let d = AVCaptureVideoDataOutput()
        d.alwaysDiscardsLateVideoFrames = true
        d.automaticallyConfiguresOutputBufferDimensions = false
        d.deliversPreviewSizedOutputBuffers = true
        guard session.canAddOutput(d) else { return }
        session.addOutput(d)
        d.setSampleBufferDelegate(self, queue: forhandsQueue)
        d.connection(with: .video)?.isEnabled = false
        dataOutput = d
    }

    /// Körs på `queue` när sessionen gått igång: filens koppling måste vara aktiv med utgången
    /// bredvid. Är den inte det tas förhandsbildens utgång bort, så att inspelningen aldrig betalar
    /// för bilden (den säkra vägen, MS35).
    private func kontrolleraForhandsbild() {
        guard let d = dataOutput else { return }
        guard let film = output.connection(with: .video), film.isActive, film.isEnabled else {
            session.beginConfiguration()
            session.removeOutput(d)
            session.commitConfiguration()
            dataOutput = nil
            return
        }
        setForhandsConnection(forhandsPa)
    }

    /// Den styrande tar emot förhandsbilden (takten över noll) eller inte. Under en serie och
    /// ljusprovet förblir utgången avstängd.
    func setForhandsbild(_ pa: Bool) {
        queue.async { [self] in
            forhandsPa = pa
            setForhandsConnection(pa && !output.isRecording)
        }
    }

    /// Körs på `queue`.
    private func setForhandsConnection(_ pa: Bool) {
        guard let c = dataOutput?.connection(with: .video), c.isEnabled != pa else { return }
        c.isEnabled = pa
    }

    /// Förhandsbildens ruta (`forhandsQueue`): tiden på värdklockan, som filens start (B19).
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let k = forhandsbild, let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let clock = session.synchronizationClock ?? CMClock.hostTimeClock
        let host = CMSyncConvertTime(pts, from: clock, to: CMClock.hostTimeClock)
        k.ruta(pb, tid: host.isValid ? host.seconds : LinkClock.now())
    }

    /// Körs på `queue`: tar bort in- och utgångar.
    private func tearDown() {
        session.stopRunning()
        session.beginConfiguration()
        for i in session.inputs { session.removeInput(i) }
        for o in session.outputs { session.removeOutput(o) }
        session.commitConfiguration()
        dataOutput = nil
        device = nil
    }

    /// Körs på `queue` efter `commitConfiguration`: formatet och bildtiden som faktiskt
    /// ställdes in, inte de som begärdes. METOD MS1
    private func readBack(_ described: [CameraFormat]) -> (format: CameraFormat?, rate: Double) {
        guard let device else { return (nil, 0) }
        let index = device.formats.firstIndex(of: device.activeFormat)
        let format = index.flatMap { $0 < described.count ? described[$0] : nil }
        let d = device.activeVideoMinFrameDuration
        let rate = d.isValid && d.seconds > 0 ? 1 / d.seconds : 0
        return (format, rate)
    }

    /// Formaten som värden för SwingLabKit (S2_SPEC §2.2). METOD MS1
    static func describe(_ formats: [AVCaptureDevice.Format]) -> [CameraFormat] {
        formats.enumerated().map { i, f in
            let dims = CMVideoFormatDescriptionGetDimensions(f.formatDescription)
            let sub = CMFormatDescriptionGetMediaSubType(f.formatDescription)
            return CameraFormat(index: i, width: Int(dims.width), height: Int(dims.height),
                                maxFrameRate: f.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0,
                                fieldOfView: Double(f.videoFieldOfView), binned: f.isVideoBinned,
                                minISO: Double(f.minISO), maxISO: Double(f.maxISO),
                                minExposure: f.minExposureDuration.seconds, maxExposure: f.maxExposureDuration.seconds,
                                tenBit: FourCC.isTenBit(sub), hdrSupported: f.isVideoHDRSupported)
        }
    }

    /// Steg 1 och 2 i S2_SPEC §2.3–2.4, på `queue`: autoexponering med taket 1/2000 s,
    /// fokus och vitbalans söker i mitten; när exponeringen stått still i 0,5 s (och
    /// vitbalansen fått 1 s) låses tid och ISO ur `Exposure.plan`, fokus och vitbalans.
    /// METOD MS2, BESLUT B16
    private func meterAndLock() -> ExposureRecord? {
        guard let device, let chosen else { return nil }
        let format = device.activeFormat
        let tak = Self.safeDuration(Exposure.lockedDuration(format: chosen), format)
        do {
            try device.lockForConfiguration()
            if device.isExposurePointOfInterestSupported { device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5) }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
                device.activeMaxExposureDuration = tak
            }
            if device.isFocusPointOfInterestSupported { device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5) }
            if device.isFocusModeSupported(.autoFocus) { device.focusMode = .autoFocus }
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            device.unlockForConfiguration()
        } catch {
            return nil
        }
        // Vänta: minst 1 s, exponeringen still i 0,5 s och fokus klart, högst 4 s.
        let start = Date()
        var still: Date?
        while Date().timeIntervalSince(start) < 4 {
            Thread.sleep(forTimeInterval: 0.05)
            if device.isAdjustingExposure || device.isAdjustingFocus {
                still = nil
            } else if still == nil {
                still = Date()
            }
            if let still, Date().timeIntervalSince(still) >= 0.5, Date().timeIntervalSince(start) >= 1 { break }
        }
        let plan = Exposure.plan(aeDuration: device.exposureDuration.seconds, aeISO: Double(device.iso),
                                 aeOffsetEV: Double(device.exposureTargetOffset), format: chosen)
        do {
            try device.lockForConfiguration()
            if device.isExposureModeSupported(.custom) {
                let iso = min(max(Float(plan.iso), format.minISO), format.maxISO)
                device.setExposureModeCustom(duration: Self.safeDuration(plan.duration, format), iso: iso,
                                             completionHandler: nil)
            }
            if device.isFocusModeSupported(.locked) { device.focusMode = .locked }
            if device.isWhiteBalanceModeSupported(.locked) { device.whiteBalanceMode = .locked }
            device.unlockForConfiguration()
        } catch {
            return ExposureRecord(plan: plan)
        }
        let distortion = device.isGeometricDistortionCorrectionSupported
            ? device.isGeometricDistortionCorrectionEnabled : nil
        return ExposureRecord(plan: plan, lensPosition: Double(device.lensPosition), distortionCorrection: distortion)
    }

    /// En tid som aldrig lämnar formatets gränser, även efter avrundningen till CMTime (risk R2).
    static func safeDuration(_ seconds: Double, _ format: AVCaptureDevice.Format) -> CMTime {
        let t = CMTime(seconds: seconds, preferredTimescale: 1_000_000)
        return CMTimeMaximum(format.minExposureDuration, CMTimeMinimum(t, format.maxExposureDuration))
    }

    // MARK: Tryck, avbrott och mikrofonen

    private func pressureChanged(_ p: Pressure) {
        pressure = p
        if phase == .recording { seriesPressure = max(seriesPressure, p) }
    }

    /// Avbrott (samtal, appen i bakgrunden): inspelningen avslutas och filen sparas (S2_SPEC §2.6).
    @MainActor
    private func observeInterruptions() {
        guard observers.isEmpty else { return }
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session,
                                        queue: .main) { [weak self] _ in
            guard let self else { return }
            self.problem = String(localized: "Interrupted.")
            self.stopSeries()
        })
        observers.append(nc.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session,
                                        queue: .main) { [weak self] _ in
            self?.problem = String(localized: "The camera stopped.")
            self?.stopSeries()
        })
    }

    /// Ljudkanalens topp i dB i den inspelade filens koppling, för svingarna i REC-pillen under
    /// serien (S2j). Rör inte inspelningen: ingen egen ljudutgång (BESLUT B85). METOD MS32
    @MainActor
    func ljudtopp() -> Double? {
        guard phase == .recording, let ch = output.connection(with: .audio)?.audioChannels.first else { return nil }
        let v = Double(ch.peakHoldLevel)
        return v.isFinite ? v : nil
    }

    /// AirPods eller annan Bluetooth-mikrofon: ljudet kan komma hundratals ms sent (risk R9).
    @MainActor
    private func checkMicrophone() {
        guard let port = AVAudioSession.sharedInstance().currentRoute.inputs.first?.portType else { return }
        microphone = port.rawValue
        micWarning = port != .builtInMic
    }

    // MARK: Hjälp

    private func onQueueThrowing<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { c in
            queue.async { c.resume(with: Result { try work() }) }
        }
    }

    private func onQueue<T>(_ work: @escaping () -> T) async -> T {
        await withCheckedContinuation { c in queue.async { c.resume(returning: work()) } }
    }
}

/// Kamerans bild på skärmen (Airtime).
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        if let c = view.previewLayer.connection, c.isVideoRotationAngleSupported(90) { c.videoRotationAngle = 90 }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

/// Ljusprovets läsning av filen (S2_SPEC §2.7): rutornas tider och ljusheten ger
/// tappade rutor och flimmer. Samma kod körs i simulatorprovet på en påhittad film. METOD MS3
enum LightProbe {
    /// Provfilmens längd, s.
    static let seconds = 2.0

    static func analyze(_ url: URL, exposure: ExposurePlan) async throws -> LightCheck {
        let times = try await MediaReader.frameTimes(url)
        let l = try await MediaReader.luma(url)
        return Flicker.check(exposure: exposure, timing: FrameTiming.analyze(times), luma: l.luma, times: l.times)
    }
}
