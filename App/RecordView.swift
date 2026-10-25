import SwiftUI
import Swing
import Capture

/// Inspelningen (S2_SPEC §2, §12 S2c): förhandsbilden med hjälplinjerna, start och stopp, och
/// kvittot efter varje serie. Grunden är Airtimes RecordView. Skärmen ovanpå (S2j, BESLUT B85):
/// bara statusen, en varning som kräver handling och lutningen när den är för stor; frekvensen,
/// värmen, parningen, lagringen och ljusprovet bakom kugghjulet (`InspelningsLager`).
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
    /// Serien som spelas in: numret och filen i passet, och den styrandes serie när
    /// följaren startades av den (S2g).
    @State private var current: (nr: Int, file: String, lead: Int?)?
    /// Två telefoner (S2g): kopplingen, och en start från den styrande som väntar på kameran.
    @State private var link: PhoneLink?
    @State private var pendingStart: Int?
    /// Den andra telefonen (dess id), passets partner för 3D (S6c-2, BESLUT B61).
    @State private var partner: String?
    /// Continue i kvittot: passet öppnas när kvittot har stängts.
    @State private var continueAfterReceipt = false

    /// Inspelningens skärm (S2j, BESLUT B85): kugghjulets blad, lutningen och räknarna.
    @State private var visaInstallningar = false
    @State private var lutning: Lutning?
    @State private var visaLutning = false
    @State private var andraStoppade = false
    @State private var antalSvingar: Int?
    @State private var serieStart: Date?
    /// Stopp är tryckt men filen inte klar: vakten för den andra telefonen tystnar direkt, så att
    /// en följare som blir klar med sin fil först inte ger falsklarm (METOD MS32).
    @State private var stopparSerie = false
    @State private var nu = Date()
    @State private var ledigt: Int64?
    @State private var raknare = Raknare()

    /// Räknarna som uppdateras 20 gånger i sekunden utan att rita om vyn; bara det som syns
    /// läggs i vyns tillstånd när det ändras. METOD MS32
    @MainActor final class Raknare {
        var visare = LutningsVisare()
        var vakt = AndraStoppadeVakt()
        var svingar = LevandeSvingar()
        var ledigtLast = Date.distantPast
    }

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()
            CameraPreview(session: camera.session).ignoresSafeArea()
            if store.settings.visaHjalplinjer {
                GuideLines().allowsHitTesting(false).accessibilityHidden(true)
            }
            InspelningsLager(
                status: status,
                varning: InspelningsVarning.av(fakta),
                lutning: visaLutning ? lutning : nil,
                stangEtikett: pass.series.isEmpty ? LocalizedStringKey("Close") : LocalizedStringKey("Continue"),
                stangAktiv: !(camera.phase == .recording || camera.phase == .probing || working),
                kanSpelaIn: (camera.phase == .ready || camera.phase == .recording) && !working,
                arbetar: working || camera.phase == .metering || camera.phase == .probing || camera.phase == .starting,
                ljusprov: light.map { Receipt.rows($0) },
                onStang: stang,
                onInstallningar: { visaInstallningar = true },
                onKnapp: toggle,
                onByt: bytVy)
        }
        .preferredColorScheme(.dark)
        .task {
            startLink()
            await camera.start()
        }
        .task { await levande() }
        .onChange(of: camera.phase) { _, phase in
            link?.report(recording: phase == .recording, freeBytes: store.availableBytes(), pressure: camera.pressure)
            stopparSerie = false
            if phase == .recording {
                serieStart = Date()
                nu = Date()
                raknare.svingar = LevandeSvingar()
                antalSvingar = nil
            } else {
                serieStart = nil
            }
            startPendingIfReady()
        }
        .onDisappear {
            link?.stop()
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
        .sheet(isPresented: $visaInstallningar) {
            ScrollView {
                InspelningsInstallningar(
                    rader: installningsrader,
                    hjalplinjer: Binding(get: { store.settings.visaHjalplinjer }, set: { store.setGuideLines($0) }),
                    ljusprovAktivt: camera.phase == .ready && !working,
                    onLjusprov: {
                        visaInstallningar = false
                        Task { await lightProbe() }
                    },
                    onKlar: { visaInstallningar = false })
            }
            .background(Theme.surface, ignoresSafeAreaEdges: .all)
            .presentationDetents([.medium, .large])
            .preferredColorScheme(.dark)
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

    // MARK: Skärmen (S2j, BESLUT B85, METOD MS32)

    /// Den andra telefonen eller telefonerna, som skärmens logik ser dem.
    private var andra: [AndraTelefonen] {
        (link?.peers ?? []).map { AndraTelefonen(vy: $0.view, kopplad: $0.connected, inspelar: $0.recording) }
    }

    private var status: InspelningsStatus {
        let sek = serieStart.map { nu.timeIntervalSince($0) } ?? 0
        return InspelningsStatus.av(roll: pass.setup.role, inspelar: camera.phase == .recording, sekunder: sek,
                                    svingar: antalSvingar, andra: andra, natAv: link?.blocked ?? false)
    }

    private var fakta: Inspelningsfakta {
        var f = Inspelningsfakta(roll: pass.setup.role, vy: pass.setup.view, inspelar: camera.phase == .recording)
        f.problem = camera.problem ?? store.problem
        f.andra = andra
        f.andraStoppade = andraStoppade
        f.natAv = link?.blocked ?? false
        f.kanByta = pass.series.isEmpty
        f.tryck = camera.pressure
        f.ledigaByte = ledigt
        f.mikrofonAv = camera.audioDenied
        f.externMikrofon = camera.micWarning
        f.bildfrekvens = camera.frameRate
        f.narOnskad = camera.reachesWanted
        return f
    }

    private var installningsrader: [InspelningsInstallningar.Rad] {
        let peer = link?.peers.first
        let parad = link?.peers.first { $0.pairs != nil }
        let horda = parad.map { p in (par: p.pairs ?? 0, av: p.leadClicks ?? p.pairs ?? 0, rest: p.residual) }
        let mb = pass.series.last { $0.source == .recording }?.megabytesPerMinute
        let mik: InspelningsInstallningar.Mikrofon? = camera.audioDenied ? .av
            : camera.microphone == nil ? nil : (camera.micWarning ? .extern : .inbyggd)
        return InspelningsInstallningar.rader(
            roll: pass.setup.role, vy: pass.setup.view, andraVy: peer?.view, fps: camera.frameRate,
            lutning: lutning, horda: horda, minuter: Lagringstid.minuter(ledigt: ledigt, mbPerMinut: mb),
            tryck: camera.pressure, mikrofon: mik)
    }

    /// Lutningen, svingarna, vakten för den andra telefonen och disken medan vyn är öppen: 20 gånger
    /// i sekunden, och vyns tillstånd bara när det som syns ändras.
    private func levande() async {
        GravityRecorder.shared.startLive()
        defer { GravityRecorder.shared.stopLive() }
        let r = raknare
        while !Task.isCancelled {
            let t = Date()
            if let g = GravityRecorder.shared.latest, let l = Lutning(gravity: [g.x, g.y, g.z]) {
                let visas = r.visare.uppdatera(l)
                if visas != visaLutning { visaLutning = visas }
                if lutning == nil || abs(l.sida - (lutning?.sida ?? 0)) >= 0.1 || l.forStorFor3D != lutning?.forStorFor3D {
                    lutning = l
                }
            }
            let inspelar = camera.phase == .recording
            if inspelar, let start = serieStart {
                if Int(t.timeIntervalSince(start)) != Int(nu.timeIntervalSince(start)) { nu = t }
                if let topp = camera.ljudtopp() {
                    r.svingar.prov(tid: t.timeIntervalSince(start), topp: topp)
                    if antalSvingar != r.svingar.antal { antalSvingar = r.svingar.antal }
                }
            }
            let stoppade = r.vakt.uppdatera(roll: pass.setup.role, egenInspelar: inspelar && !stopparSerie,
                                            tid: t.timeIntervalSinceReferenceDate, andra: andra)
            if stoppade != andraStoppade { andraStoppade = stoppade }
            if t.timeIntervalSince(r.ledigtLast) >= 5 {
                r.ledigtLast = t
                let b = store.availableBytes()
                if b != ledigt { ledigt = b }
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    /// Close utan serier, annars Continue till slagen.
    private func stang() {
        if pass.series.isEmpty {
            camera.stop()
            onClose()
        } else {
            finish()
        }
    }

    /// Vidare till passet: kameran stannar och slagen öppnas.
    private func finish() {
        camera.stop()
        onContinue()
    }

    private func toggle() {
        if camera.phase == .recording {
            stopparSerie = true
            camera.stopSeries()
            // Stopp på den styrande stoppar följarna; på följaren bara den själv.
            link?.stopSeries()
            link?.stoppedLocally()
            return
        }
        guard let nr = begin(lead: nil) else { return }
        link?.startSeries(passID: pass.id, series: nr)
    }

    /// Startar en serie i passet; svarar dess nummer. `lead` är den styrandes serie när
    /// följaren startas av den.
    @discardableResult
    private func begin(lead: Int?) -> Int? {
        guard camera.phase == .ready else { return nil }
        let nr = pass.nextSeriesNumber
        let file = PassState.videoPath(nr: nr)
        let url = store.url(file, in: pass.id)
        // En fil som inget i passet pekar på (en avbruten start) skrivs över:
        // utgången vägrar annars att börja.
        if !pass.series.contains(where: { $0.file == file }) { try? FileManager.default.removeItem(at: url) }
        current = (nr, file, lead)
        camera.startSeries(to: url, available: store.availableBytes())
        return nr
    }

    // MARK: Två telefoner (S2g, S2_SPEC §7.3–7.4)

    /// Kopplingen startas med vyn när rollen är styr eller följ. Varje telefon spelar in
    /// och sparar själv; kopplingen bär bara start, stopp, ping och klicken. BESLUT B22
    private func startLink() {
        guard link == nil, pass.setup.role != .solo else { return }
        let l = PhoneLink(role: pass.setup.role, view: pass.setup.view)
        l.onStart = { passID, n in linkStart(passID: passID, series: n) }
        l.onPartner = { partner = $0 }
        l.onStop = { n in linkStop(n) }
        // Den styrande: passets serier och följarnas sparade läses in, och par.json skrivs i passet.
        if pass.setup.role == .lead { l.attachLead(store: store, pass: pass) }
        l.start()
        link = l
    }

    /// Byter den här telefonens vy (S6g, BESLUT B83): bara före första serien. Kopplingen startas
    /// om, så att den andra telefonen hör den nya vyn i hello.
    private func bytVy() {
        guard pass.series.isEmpty, camera.phase != .recording else { return }
        pass.setup.view = Vyvakt.annan(pass.setup.view)
        store.save(pass)
        link?.stop()
        link = nil
        startLink()
    }

    /// Följaren: den styrande startade. Ett tomt pass tar den styrandes id.
    private func linkStart(passID: String, series n: Int) {
        if pass.id != passID, let p = store.adopt(pass, id: passID) { pass = p }
        pendingStart = n
        if camera.phase == .recording { camera.stopSeries() }      // ett missat stopp
        startPendingIfReady()
    }

    /// Följaren: den styrande stoppade.
    private func linkStop(_ n: Int) {
        if let p = pendingStart, p <= n { pendingStart = nil }
        if camera.phase == .recording, current?.lead != nil { camera.stopSeries() }
    }

    /// En väntande start tas när kameran är redo och förra serien är läst.
    private func startPendingIfReady() {
        guard let n = pendingStart, camera.phase == .ready, current == nil, camera.finished == nil, !working else { return }
        pendingStart = nil
        begin(lead: n)
    }

    /// Serien är sparad: den styrande parar, följaren skickar klicken (nu eller efter ett tapp).
    private func linkFinished(_ s: SeriesRecord, lead: Int?) {
        guard let link else { return }
        // Passets partner, när passets id är det slutliga (efter adopt). BESLUT B61
        if let partner { store.savePartner(partner, passID: pass.id) }
        switch pass.setup.role {
        case .lead:
            link.ownFinished(LinkSeries(record: s, series: s.nr, passID: pass.id, setup: pass.setup))
        case .follow:
            guard let lead else { return }
            link.finished(LinkSeries(record: s, series: lead, passID: pass.id, setup: pass.setup))
        case .solo:
            break
        }
    }

    /// Serien läses ur filen: tiderna, klicken och geometrin, sedan kvittot.
    private func analyze(_ f: Camera.Finished) async {
        guard let current else { return }
        self.current = nil
        working = true
        defer {
            working = false
            startPendingIfReady()
        }
        do {
            if let r = try await Self.save(f, nr: current.nr, file: current.file, passID: pass.id,
                                           club: pass.setup.club, camera: camera, store: store) {
                pass = r.pass
                linkFinished(r.series, lead: current.lead)
                // Följaren styrs av den styrande: kvittot visas inte mellan serierna.
                if current.lead == nil { receipt = r.series }
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
        s.setPlumb(f.gravity)                                           // lodlinjen (S6b), METOD MS17
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
