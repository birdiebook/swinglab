import SwiftUI
import Capture

/// Inspelningen (S2_SPEC §2, §12 S2c): förhandsbilden med hjälplinjerna, frekvensen,
/// ljusprovet, start och stopp, och kvittot efter varje serie. Grunden är Airtimes
/// RecordView. Lite text (BESLUT B13): etiketter och tal, signalfärgen bara för varningar.
struct RecordView: View {
    @Binding var pass: PassState
    var onClose: () -> Void
    /// Vidare till passet med slagen och Analyze (S2e).
    var onContinue: () -> Void = {}

    @Environment(Store.self) private var store
    @State private var camera = Camera()
    @State private var light: LightCheck?
    @State private var receipt: SeriesRecord?
    @State private var working = false
    /// Serien som spelas in: numret och filen i passet.
    @State private var current: (nr: Int, file: String)?
    /// Continue i kvittot: passet öppnas när kvittot har stängts.
    @State private var continueAfterReceipt = false

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()
            CameraPreview(session: camera.session).ignoresSafeArea()
            GuideLines().allowsHitTesting(false).accessibilityHidden(true)

            VStack(spacing: 10) {
                topBar
                warnings
                Spacer()
                if let light {
                    ReceiptCard(rows: Receipt.rows(light)).padding(.horizontal, 20)
                }
                if let problem = camera.problem ?? store.problem {
                    Text(problem)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.flag)
                        .padding(.horizontal, 20)
                }
                controls
            }
        }
        .preferredColorScheme(.dark)
        .task { await camera.start() }
        .onDisappear {
            // En serie som pågår när vyn försvinner avslutas och sparas i passet:
            // ingen fil utan ägare.
            let cam = camera, pending = current, id = pass.id, club = pass.setup.club, butik = store
            Task { @MainActor in
                if let f = await cam.finishSeries(), let pending {
                    _ = try? await Self.save(f, nr: pending.nr, file: pending.file, passID: id, club: club,
                                             camera: cam, store: butik)
                }
                cam.stop()
            }
        }
        .onChange(of: camera.finished) { _, f in
            guard let f else { return }
            camera.finished = nil
            Task { await analyze(f) }
        }
        .sheet(isPresented: Binding(get: { receipt != nil }, set: { if !$0 { receipt = nil } }),
               onDismiss: {
                   guard continueAfterReceipt else { return }
                   continueAfterReceipt = false
                   finish()
               }) {
            if let receipt {
                ReceiptSheet(series: receipt, onNext: { self.receipt = nil }, onContinue: {
                    continueAfterReceipt = true
                    self.receipt = nil
                })
                .presentationDetents([.medium])
            }
        }
    }

    private var topBar: some View {
        HStack {
            // Med en serie i passet leder knappen vidare till slagen, annars stänger den.
            Button(pass.series.isEmpty ? LocalizedStringKey("Close") : LocalizedStringKey("Continue")) {
                if pass.series.isEmpty {
                    camera.stop()
                    onClose()
                } else {
                    finish()
                }
            }
            .disabled(camera.phase == .recording || camera.phase == .probing || working)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(.black.opacity(0.6), in: .rect(cornerRadius: 4))
            Spacer()
            if camera.frameRate > 0 {
                HStack(spacing: 8) {
                    if camera.phase == .recording {
                        Circle().fill(Theme.text).frame(width: 8, height: 8)
                    }
                    Text("\(Int(camera.frameRate)) fps").font(Theme.number(17))
                }
                .foregroundStyle(camera.reachesWanted ? Theme.text : Theme.flag)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(.black.opacity(0.6), in: .rect(cornerRadius: 4))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    @ViewBuilder private var warnings: some View {
        VStack(alignment: .leading, spacing: 4) {
            if camera.pressure.warns {
                Text(verbatim: "\(Receipt.pressureLabel): \(Receipt.pressureName(camera.pressure))")
            }
            if camera.micWarning {
                Text("External microphone")
            }
            if camera.audioDenied {
                Text("Microphone off")
            }
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Theme.flag)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private var controls: some View {
        HStack {
            Button("Light test") { Task { await lightProbe() } }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(minWidth: 96, minHeight: 44)
                .background(.black.opacity(0.6), in: .rect(cornerRadius: 4))
                .disabled(camera.phase != .ready || working)
            Spacer()
            Button { toggle() } label: {
                ZStack {
                    Circle().stroke(Theme.text, lineWidth: 4).frame(width: 80, height: 80)
                    RoundedRectangle(cornerRadius: camera.phase == .recording ? 4 : 30)
                        .fill(Theme.text)
                        .frame(width: camera.phase == .recording ? 28 : 60, height: camera.phase == .recording ? 28 : 60)
                }
            }
            .disabled(!(camera.phase == .ready || camera.phase == .recording) || working)
            .opacity(camera.phase == .ready || camera.phase == .recording ? 1 : 0.4)
            .accessibilityLabel(camera.phase == .recording ? Text("Stop") : Text("Record"))
            Spacer()
            ZStack {
                if working || camera.phase == .metering || camera.phase == .probing || camera.phase == .starting {
                    ProgressView().tint(Theme.text)
                }
            }
            .frame(minWidth: 96, minHeight: 44)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    /// Vidare till passet: kameran stannar och slagen öppnas.
    private func finish() {
        camera.stop()
        onContinue()
    }

    private func toggle() {
        if camera.phase == .recording {
            camera.stopSeries()
            return
        }
        let nr = pass.nextSeriesNumber
        let file = PassState.videoPath(nr: nr)
        let url = store.url(file, in: pass.id)
        // En fil som inget i passet pekar på (en avbruten start) skrivs över:
        // utgången vägrar annars att börja.
        if !pass.series.contains(where: { $0.file == file }) { try? FileManager.default.removeItem(at: url) }
        current = (nr, file)
        camera.startSeries(to: url, available: store.availableBytes())
    }

    /// Serien läses ur filen: tiderna, klicken och geometrin, sedan kvittot.
    private func analyze(_ f: Camera.Finished) async {
        guard let current else { return }
        self.current = nil
        working = true
        defer { working = false }
        do {
            if let r = try await Self.save(f, nr: current.nr, file: current.file, passID: pass.id,
                                           club: pass.setup.club, camera: camera, store: store) {
                pass = r.pass
                receipt = r.series
            }
        } catch {
            camera.problem = String(localized: "\(current.file) could not be read.")
        }
    }

    /// Läser serien ur filen och lägger den i passet som det står på disken, så att
    /// det fungerar även när vyn redan har försvunnit. nil = ingen fil.
    @MainActor
    static func save(_ f: Camera.Finished, nr: Int, file: String, passID: String, club: String,
                     camera: Camera, store: Store) async throws -> (pass: PassState, series: SeriesRecord)? {
        guard FileManager.default.fileExists(atPath: f.url.path), var pass = store.load(passID) else { return nil }
        var s = try await SeriesMaker.make(url: f.url, nr: nr, file: file, source: .recording, club: club,
                                           start: f.started, startHost: f.startHost, microphone: camera.microphone)
        s.format = camera.chosen
        s.exposure = camera.exposure
        s.pressure = f.pressure
        pass.series.removeAll { $0.file == file }
        pass.series.append(s)
        store.save(pass)
        return (pass, s)
    }

    /// Ljusprovet: 2 s med låst exponering, läst och borttaget (S2_SPEC §2.7).
    private func lightProbe() async {
        guard let r = await camera.recordProbe() else { return }
        working = true
        defer {
            working = false
            try? FileManager.default.removeItem(at: r.url)
        }
        do {
            let c = try await LightProbe.analyze(r.url, exposure: r.exposure.plan)
            light = c
            pass.lightCheck = c
            store.save(pass)
        } catch {
            camera.problem = String(localized: "The light test could not be read.")
        }
    }
}

/// Kvittot efter en serie (S2_SPEC §12 S2c): nästa serie, eller Continue till passet
/// med slagen och Analyze (S2e). METOD MS11
struct ReceiptSheet: View {
    let series: SeriesRecord
    var onNext: () -> Void
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ReceiptCard(title: String(localized: "Set \(series.nr)"), rows: Receipt.rows(series))
            Button("Continue", action: onContinue).buttonStyle(PrimaryButtonStyle())
            Button("Next set", action: onNext).buttonStyle(RowButtonStyle())
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.ground, ignoresSafeAreaEdges: .all)
        .preferredColorScheme(.dark)
    }
}

/// Hjälplinjerna (S2_SPEC §2.2): fötterna i nedre femtedelen, huvudet under övre fjärdedelen.
struct GuideLines: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in
                for y in [geo.size.height * 0.25, geo.size.height * 0.8] {
                    p.move(to: CGPoint(x: 20, y: y))
                    p.addLine(to: CGPoint(x: geo.size.width - 20, y: y))
                }
            }
            .stroke(Theme.text.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
        }
    }
}
