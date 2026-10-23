import AVFoundation
import SwiftUI
import UIKit
import Swing
import Capture

/// Granskningen av ett slag (PLAN S4, S4b; BESLUT B32, B35): seriens video med utsnittet
/// (S2i), spela och pausa i 1/8 fart och stega ruta för ruta på slagets eget rutnät, med
/// alla 13 leder och linjerna mellan dem ovanpå som Vision gav dem (en osäker led ihålig,
/// dess linjer streckade), en växel som döljer dem, positionsraden P1–P10 som hoppar dit,
/// och under videon slagets mått vid positionen. Menyn märker slaget "Detection wrong"
/// (räknas inte i passets mått, går att ångra). B13: ingen figur, ingen förklarande text.
/// Menyn öppnar också "Mark club" (S7a, bakifrån): klubban markeras för hand per position
/// (`ClubMarkContent`), och det som är markerat syns som en tunn linje i rutan. METOD MS14,
/// MS15, M45
struct ShotReviewView: View {
    let passID: String
    let shotID: String
    var onClose: () -> Void

    @Environment(Store.self) private var store
    @State private var pass: PassState?
    @State private var review: ShotReview?
    @State private var player = AVPlayer()
    /// Videons tid − seriens tid: 0 för seriens fil, klippets förskjutning när originalet är borttaget.
    @State private var offset = 0.0
    @State private var frame = 0
    @State private var position = "P4"
    @State private var overlayOn = true
    @State private var playing = false
    @State private var observer: Any?
    @State private var baseline: [String: [Double]] = [:]
    /// Felen i Att jobba på (BESLUT B31).
    @State private var ovas: Set<String> = []
    @State private var seeking = false
    @State private var pendingFrame: Int?
    /// Märkningen av klubban (S7a); nil = granskningen.
    @State private var marking: ClubMarking?
    @State private var series: JointSeries?
    /// Riktpinnen: nästa två tryck sätter den (S7a, METOD M48).
    @State private var stickMode = false
    @State private var stickPoints: [KlubbPunkt] = []
    /// Rutan som stillbild för glaset (toleransen 0), och vilken ruta den är.
    @State private var loupeImage: (frame: Int, image: CGImage)?
    /// Ett steg till en annan ruta när punkter är satta: frågan om de ska tömmas.
    @State private var pendingStep: Int?
    @State private var askDiscard = false
    /// Sparningen utanför huvudtråden; bara den senaste skrivs.
    @State private var saveCount = 0

    private var shot: ShotRecord? { pass?.shots.first { $0.id == shotID } }

    var body: some View {
        Group {
            if let shot, let review, let m = marking {
                ScrollView {
                    ClubMarkContent(surface: { CroppedPlayerSurface(player: player, crop: $0) },
                                    loupe: { LoupeImage(image: loupeImage?.frame == frame ? loupeImage?.image : nil, crop: $0) },
                                    marking: m, time: timeText(review, shot), ring: ring(review),
                                    stick: stickMode ? stickPoints : (pass?.riktpinne(series: shot.series) ?? []),
                                    stickMode: stickMode, onTap: tapped, onMove: { g, u, v in change { $0.move(g, u: u, v: v) } },
                                    onStep: markingStep, onUndo: { change { $0.undo() } },
                                    onSkip: { change { $0.skip(t: review.frames[frame].t) } },
                                    onNext: { change { $0.advance() } }, onStick: toggleStick,
                                    onPosition: { p in change { $0.go(to: p) } }, onClose: closeMarking)
                        .padding(.vertical, 8)
                }
                .task(id: frame) { await readLoupe() }
                .confirmationDialog(Text("Clear the points?"), isPresented: Binding(
                    get: { pendingStep != nil }, set: { if !$0 { pendingStep = nil } }), titleVisibility: .visible) {
                    Button("Clear", role: .destructive) {
                        let n = pendingStep ?? 0
                        pendingStep = nil
                        if var m = marking {
                            m.clearPoints()
                            marking = m
                        }
                        step(n)
                    }
                }
                .confirmationDialog(Text("Discard the grip?"), isPresented: $askDiscard, titleVisibility: .visible) {
                    Button("Discard", role: .destructive) { finishMarking() }
                }
            } else if let pass, let shot, let review {
                ScrollView {
                    ReviewContent(surface: CroppedPlayerSurface(player: player, crop: review.crop), review: review,
                                  number: ShotRecord.number(shot.id) ?? 0, frame: frame, overlayOn: overlayOn,
                                  playing: playing, position: position, positions: review.positions(shot.measure),
                                  rows: ReviewRows.rows(pass: pass, shot: shot, position: position, baseline: baseline,
                                                        ovas: ovas),
                                  detectionWrong: shot.detectionWrong == true, impact: shot.impact - shot.click.time,
                                  shaft: review.shaft(frame, marks: shot.klubba),
                                  onClose: close, onPlay: togglePlay, onStep: step, onScrub: { pause(); seek($0) },
                                  onPosition: jump, onOverlay: { overlayOn.toggle() }, onDetectionWrong: setWrong,
                                  onMarkClub: pass.setup.view == .dtl ? startMarking : nil)
                        .padding(.vertical, 8)
                }
            } else {
                VStack(alignment: .leading) {
                    Navrad(titel: "", hoger: { EmptyView() }, tillbaka: close)
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Theme.ground, ignoresSafeAreaEdges: .all)
        .preferredColorScheme(.dark)
        .task { load() }
        .onDisappear {
            player.pause()
            if let observer { player.removeTimeObserver(observer) }
            observer = nil
        }
    }

    private func load() {
        guard review == nil, let p = store.load(passID), let s = p.shots.first(where: { $0.id == shotID }),
              let rel = s.joints, let series = store.joints(rel, in: passID),
              let serie = p.series.first(where: { $0.nr == s.series }) else { return }
        pass = p
        self.series = series
        ovas = store.focus?.ovas ?? []
        let r = ShotReview(series: series, crop: serie.activeCrop)
        review = r
        // Baslinjen ur de tidigare passen med samma längd, mätta utanför huvudtråden (METOD MS14).
        Task { baseline = PassHistory.baseline(await PassMeasures.load(p, store: store).earlier) }
        // Seriens fil, eller klippet när originalet är borttaget (BESLUT B26, METOD MS12).
        var url = store.url(serie.file, in: passID)
        if !FileManager.default.fileExists(atPath: url.path), let clip = s.clip, let o = ShotImages.clipOffset(s) {
            url = store.url(clip, in: passID)
            offset = o
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.isMuted = true
        player.actionAtItemEnd = .pause
        // Rutan följer videon; uppspelningen stannar vid slagets sista ruta.
        // Var 1/240 s, och rutan som visas är den senaste med tid ≤ spelarens (golv). METOD MS15
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 240), queue: .main) { t in
            MainActor.assumeIsolated {
                guard t.isValid, !seeking, let r = review, let k = r.index(atPts: t.seconds - offset) else { return }
                frame = k
                if playing, k >= r.frames.count - 1 {
                    player.pause()
                    playing = false
                }
            }
        }
        // Toppen först, annars träffen.
        let pos = r.positions(s.measure)
        if let p4 = pos.first(where: { $0.name == "P4" })?.index {
            position = "P4"
            seek(p4)
        } else {
            position = "P7"
            seek(r.index(nearestT: s.impact - s.click.time) ?? 0)
        }
    }

    /// Exakt till ruta k (bildens egen tid). Bara en seek åt gången; under tiden sparas det
    /// senaste målet och tas när den förra är klar.
    private func seek(_ k: Int) {
        guard let r = review, !r.frames.isEmpty else { return }
        let k = min(max(0, k), r.frames.count - 1)
        frame = k
        if seeking {
            pendingFrame = k
            return
        }
        seeking = true
        // En fjärdedels ruta in i rutan, så att just den visas trots avrundade tider. METOD MS15
        let t = (r.seekTime(k) ?? r.frames[k].pts) + offset
        player.seek(to: CMTime(seconds: max(0, t), preferredTimescale: 48_000), toleranceBefore: .zero,
                    toleranceAfter: .zero) { _ in
            Task { @MainActor in
                seeking = false
                if let p = pendingFrame {
                    pendingFrame = nil
                    seek(p)
                }
            }
        }
    }

    /// Pausar; efter uppspelning söks exakt till rutan som spelaren står på, så att bilden och
    /// lederna är samma ruta. METOD MS15
    private func pause() {
        let spelade = playing
        player.pause()
        playing = false
        if spelade, let r = review, let k = r.index(atPts: player.currentTime().seconds - offset) {
            seek(k)
        }
    }

    /// Spelar i 1/8 fart från rutan, eller från början när den står vid slutet. METOD MS15
    private func togglePlay() {
        guard let r = review else { return }
        if playing {
            pause()
            return
        }
        if frame >= r.frames.count - 1 { seek(0) }
        player.playImmediately(atRate: Float(ShotReview.playbackRate))
        playing = true
    }

    private func step(_ n: Int) {
        pause()
        seek(frame + n)
    }

    /// En position: videon dit och positionens mått under.
    private func jump(_ name: String) {
        guard let k = review?.positions(shot?.measure).first(where: { $0.name == name })?.index else { return }
        pause()
        position = name
        seek(k)
    }

    /// "Detection wrong", sparat i passet; går att ångra. BESLUT B35
    private func setWrong(_ wrong: Bool) {
        guard var p = pass else { return }
        p.setDetectionWrong(wrong, shot: shotID)
        store.save(p)
        pass = p
    }

    private func close() {
        pause()
        onClose()
    }

    // MARK: klubban (S7a)

    private func timeText(_ r: ShotReview, _ s: ShotRecord) -> String {
        guard r.frames.indices.contains(frame) else { return "" }
        return Tal.tecken(r.frames[frame].t - (s.impact - s.click.time), decimaler: 3) + " s"
    }

    /// "Mark club": märkningen börjar på den första positionen utan markering. METOD M45
    private func startMarking() {
        guard let review, let shot else { return }
        pause()
        let serie = pass?.series.first { $0.nr == shot.series }
        marking = ClubMarking(existing: shot.klubba, width: review.width, height: review.height,
                              crop: serie?.activeCrop)
        seekToPosition()
    }

    /// Rutan för positionen som märks: punkternas, markeringens, annars förslaget ur kroppens
    /// positioner (METOD M45).
    private func seekToPosition() {
        guard let m = marking, !m.done, let review, let shot else { return }
        seek(review.index(nearestT: m.shownTime(measure: shot.measure, impact: shot.impact - shot.click.time)) ?? frame)
    }

    /// Ringen ur handlederna i rutan (förslaget till greppet, BESLUT B47): handledernas mitt,
    /// eller den som syns.
    private func ring(_ r: ShotReview) -> KlubbPunkt? {
        guard r.frames.indices.contains(frame) else { return nil }
        let h = [5, 6].compactMap { i -> PoseJoint? in
            guard i < r.frames[frame].joints.count, let j = r.frames[frame].joints[i], j.c >= Sving.minKonfidens else {
                return nil
            }
            return j
        }
        guard !h.isEmpty else { return nil }
        return KlubbPunkt(x: h.map(\.x).reduce(0, +) / Double(h.count), y: h.map(\.y).reduce(0, +) / Double(h.count))
    }

    /// Ett tryck: riktpinnens punkt i det läget, annars nästa punkt i rutan.
    private func tapped(_ u: Double, _ v: Double) {
        guard let m = marking, let review, review.frames.indices.contains(frame) else { return }
        if stickMode {
            guard let p = m.imagePoint(u: u, v: v) else { return }
            stickPoints.append(p)
            if stickPoints.count == 2 { saveStick(stickPoints) }
            return
        }
        let t = review.frames[frame].t
        let r = ring(review)
        change { $0.tap(u: u, v: v, t: t, ring: r) }
    }

    /// Riktpinnen (valfri, en gång per serie): två tryck på en pinne på marken, parallell med
    /// mållinjen; ett tryck på knappen när den finns tar bort den. METOD M48
    private func toggleStick() {
        guard let shot else { return }
        if stickMode {
            stickMode = false
            stickPoints = []
        } else if pass?.riktpinne(series: shot.series) != nil {
            saveStick(nil)
        } else {
            stickMode = true
            stickPoints = []
        }
    }

    private func saveStick(_ pinne: [KlubbPunkt]?) {
        guard var p = pass, let shot, let series else { return }
        stickMode = false
        stickPoints = []
        let id = shotID, nr = shot.series, passID = p.id
        p.setRiktpinne(pinne, series: nr) { s in s.id == id ? series : store.joints(s.joints ?? "", in: passID) }
        store.save(p)
        pass = p
    }

    /// Ett steg i rutorna: med punkter satta på en annan ruta frågas först om de ska tömmas.
    private func markingStep(_ n: Int) {
        if marking?.hasPoints == true {
            pendingStep = n
        } else {
            step(n)
        }
    }

    /// En ändring i märkningen; sparas i passet när markeringarna ändrats, och rutan följer
    /// positionen (efter ett ångra den sparade rutan).
    private func change(_ f: (inout ClubMarking) -> Void) {
        guard var m = marking else { return }
        let fore = (m.position, m.frameT)
        let foreMarks = m.result
        f(&m)
        marking = m
        if m.result != foreMarks { saveMarks(m.result) }
        if m.position != fore.0 || m.frameT != fore.1 || m.done { seekToPosition() }
    }

    /// Markeringarna sparas och slaget mäts om utanför huvudtråden; bara den senaste
    /// sparningen skrivs (METOD MS14).
    private func saveMarks(_ marks: [KlubbMarkering]) {
        guard let p = pass, let series else { return }
        saveCount += 1
        let nr = saveCount, id = shotID
        Task {
            let q = await Task.detached(priority: .userInitiated) { () -> PassState in
                var q = p
                q.setClubMarks(marks, shot: id, joints: series)
                return q
            }.value
            // Bara slaget byts in, så att en riktpinne som sparats under tiden står kvar.
            guard nr == saveCount, var cur = pass, let i = cur.shots.firstIndex(where: { $0.id == id }),
                  let ny = q.shots.first(where: { $0.id == id }) else { return }
            cur.shots[i] = ny
            store.save(cur)
            pass = cur
        }
    }

    /// Glasets stillbild för rutan, ur filen med toleransen 0.
    private func readLoupe() async {
        guard marking != nil, let p = pass, let s = shot, let review, review.frames.indices.contains(frame) else { return }
        let k = frame
        if loupeImage?.frame == k { return }
        if let img = try? await ShotImages.fullFrame(pass: p, shot: s, store: store,
                                                     at: (review.seekTime(k) ?? review.frames[k].pts)) {
            loupeImage = (k, img)
        }
    }

    /// Done: en ensam punkt på positionen ger en fråga; annars stängs märkningen.
    private func closeMarking() {
        if let m = marking, m.grip != nil, m.hosel == nil {
            askDiscard = true
            return
        }
        finishMarking()
    }

    private func finishMarking() {
        askDiscard = false
        marking = nil
        stickMode = false
        stickPoints = []
    }
}

/// Måtten under videon: slagets vid positionen, i slagets vy (METOD M29, MS15). `ovas` =
/// felen i Att jobba på: deras rader bär accenten (BESLUT B31).
enum ReviewRows {
    static func rows(pass: PassState, shot: ShotRecord, position: String, baseline: [String: [Double]],
                     ovas: Set<String> = []) -> [Positionsrad] {
        guard let k = AppKatalog.katalog, let m = shot.measure else { return [] }
        return Positionsmatt.rader(k, vy: pass.setup.view, position: position, varden: m.values, baslinje: baseline,
                                   ovas: ovas, flyktpunktAntagen: m.klubbaFlyktpunktAntagen == true)
    }
}

/// Granskningens innehåll som värden (videoytan är utbytbar), så att provet kan rita den med
/// en stillbild ur filen i stället för spelaren. Ingen ScrollView och ingen UIKit-del utom ytan.
struct ReviewContent<Surface: View>: View {
    let surface: Surface
    let review: ShotReview
    let number: Int
    let frame: Int
    var overlayOn = true
    var playing = false
    let position: String
    let positions: [(name: String, index: Int?)]
    let rows: [Positionsrad]
    var detectionWrong = false
    /// Träffen i s relativt klicket: tiden i hörnet räknas från den.
    let impact: Double
    /// Skaftet som är markerat i rutan (S7a), i ytans koordinater; nil = inget.
    var shaft: (grip: (x: Double, y: Double), hosel: (x: Double, y: Double))? = nil
    /// Menyn är en UIKit-del som provets ImageRenderer inte ritar; utan den bara symbolen.
    var editable = true
    var onClose: () -> Void = {}
    var onPlay: () -> Void = {}
    var onStep: (Int) -> Void = { _ in }
    var onScrub: (Int) -> Void = { _ in }
    var onPosition: (String) -> Void = { _ in }
    var onOverlay: () -> Void = {}
    var onDetectionWrong: (Bool) -> Void = { _ in }
    /// "Mark club" i menyn (S7a); nil = inte i den här vyn (framifrån väntar, PLAN S7a).
    var onMarkClub: (() -> Void)? = nil

    /// Videons höjd i punkter; bredden följer utsnittets proportioner.
    static var stageHeight: CGFloat { 440 }

    private var meny: some View {
        Image(systemName: "ellipsis")
            .typsnitt(17, .medium)
            .foregroundStyle(Theme.secondary)
            .frame(width: 40, height: 40)
    }

    /// Positionerna på tidslinjen: rutan och om den är vald.
    private var ticks: [(index: Int, selected: Bool)] {
        var ut: [(index: Int, selected: Bool)] = []
        for p in positions {
            if let k = p.index { ut.append((index: k, selected: p.name == position)) }
        }
        return ut
    }

    /// "−0.250 s" från träffen.
    var timeText: String {
        guard review.frames.indices.contains(frame) else { return "" }
        return Tal.tecken(review.frames[frame].t - impact, decimaler: 3) + " s"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Navrad(titel: String(localized: "Shot \(number)"), hoger: {
                HStack(spacing: 4) {
                    Button(action: onOverlay) {
                        Image(systemName: overlayOn ? "eye" : "eye.slash")
                            .typsnitt(17, .medium)
                            .foregroundStyle(overlayOn ? Theme.text : Theme.tertiary)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Joints"))
                    if editable {
                        Menu {
                            Toggle("Detection wrong", isOn: Binding(get: { detectionWrong }, set: onDetectionWrong))
                            if let onMarkClub {
                                Button("Mark club", action: onMarkClub)
                            }
                        } label: {
                            meny
                        }
                        .accessibilityLabel(Text("Detection wrong"))
                    } else {
                        meny
                    }
                }
            }, tillbaka: onClose)
            if detectionWrong {
                Etikett(text: String(localized: "Detection wrong"))
                    .padding(.bottom, 8)
            }

            ReviewStage(surface: surface, overlay: review.overlay(frame), overlayOn: overlayOn, time: timeText,
                        shaft: shaft)
                .aspectRatio(CGFloat(review.aspect), contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(height: Self.stageHeight)

            HStack(spacing: 2) {
                symbol("backward.frame.fill", "Previous frame") { onStep(-1) }
                symbol(playing ? "pause.fill" : "play.fill",
                       playing ? LocalizedStringKey("Pause") : LocalizedStringKey("Play"), onPlay)
                symbol("forward.frame.fill", "Next frame") { onStep(1) }
                ReviewTimeline(count: review.frames.count, frame: frame, ticks: ticks, onScrub: onScrub)
                .frame(height: 34)
                .padding(.leading, 8)
            }
            .padding(.top, 8)

            // Positionerna på en rad; de som saknas (armen aldrig vågrät) är grå och går inte att välja.
            HStack(spacing: 0) {
                ForEach(positions.indices, id: \.self) { i in
                    positionButton(positions[i].name, available: positions[i].index != nil)
                }
            }
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.hair).frame(height: 1) }
            .padding(.top, 8)

            VStack(spacing: 0) {
                ForEach(rows) { r in PositionsradVy(rad: r) }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
    }

    static func label(_ position: String) -> String? {
        switch position {
        case "P1": return String(localized: "Address")
        case "P4": return String(localized: "Top")
        case "P7": return String(localized: "Impact")
        case "P10": return String(localized: "Finish")
        default: return nil
        }
    }

    private func positionButton(_ name: String, available: Bool) -> some View {
        let vald = name == position
        return Button {
            onPosition(name)
        } label: {
            VStack(spacing: 1) {
                Text(verbatim: name)
                    .typsnitt(13.5, .semibold, siffror: true)
                Text(verbatim: Self.label(name) ?? " ")
                    .typsnitt(10, .medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(vald ? Theme.text : Theme.tertiary)
            .opacity(available ? 1 : 0.4)
            .frame(maxWidth: .infinity, minHeight: 44)
            .overlay(alignment: .bottom) {
                Rectangle().fill(vald ? Theme.text : Color.clear).frame(height: 2)
            }
        }
        .buttonStyle(.plain)
        .disabled(!available)
    }

    private func symbol(_ name: String, _ label: LocalizedStringKey, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Theme.text)
                .frame(width: 36, height: 40)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

/// Videoytan med lederna ovanpå och tiden i hörnet. Ytan har utsnittets proportioner, och
/// lederna står i utsnittets koordinater (0–1), så att en led hamnar på sin pixel i bilden.
/// METOD MS13, MS15
struct ReviewStage<Surface: View>: View {
    let surface: Surface
    let overlay: ShotReview.Overlay
    var overlayOn = true
    var time: String = ""
    /// Skaftet som är markerat i rutan (S7a): en tunn linje mellan greppet och hoseln.
    var shaft: (grip: (x: Double, y: Double), hosel: (x: Double, y: Double))? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            surface
            if overlayOn { LedOverlay(overlay: overlay) }
            if overlayOn { ShaftOverlay(shaft: shaft) }
            if !time.isEmpty {
                Text(verbatim: time)
                    .typsnitt(11, .medium, siffror: true)
                    .foregroundStyle(Theme.secondary)
                    .padding(8)
            }
        }
        .background(Theme.cam)
        .clipped()
    }
}

/// Lederna och linjerna (B13: tunna linjer och punkter, ingen figur): fylld punkt för en led
/// som mäts, ihålig för en osäker, linjerna streckade mot en osäker led, näsan lite större.
struct LedOverlay: View {
    let overlay: ShotReview.Overlay

    var body: some View {
        Canvas { c, s in
            func p(_ q: ShotReview.Point) -> CGPoint { CGPoint(x: CGFloat(q.x) * s.width, y: CGFloat(q.y) * s.height) }
            for l in overlay.lines {
                guard overlay.points.indices.contains(l.from), overlay.points.indices.contains(l.to),
                      let a = overlay.points[l.from], let b = overlay.points[l.to] else { continue }
                c.linje(p(a), p(b), Theme.text, 1.2, streckad: l.measured ? [] : [3, 3])
            }
            for (i, q) in overlay.points.enumerated() {
                guard let q else { continue }
                c.prick(p(q), i == 0 ? 3.5 : 2.6, Theme.text, ihalig: q.state == .weak)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Tidslinjen över slagets rutor: positionerna som streck (den valda högre och vit),
/// spelhuvudet som en prick; dra för att stega.
struct ReviewTimeline: View {
    let count: Int
    let frame: Int
    let ticks: [(index: Int, selected: Bool)]
    var onScrub: (Int) -> Void = { _ in }

    var body: some View {
        GeometryReader { geo in
            Canvas { c, s in
                let x0: CGFloat = 4, x1 = s.width - 4, y = s.height / 2
                func x(_ k: Int) -> CGFloat { x0 + (count > 1 ? CGFloat(k) / CGFloat(count - 1) : 0) * (x1 - x0) }
                c.linje(CGPoint(x: x0, y: y), CGPoint(x: x1, y: y), Theme.line, 1.5)
                for t in ticks {
                    let h: CGFloat = t.selected ? 8 : 5
                    c.linje(CGPoint(x: x(t.index), y: y - h), CGPoint(x: x(t.index), y: y + h),
                            t.selected ? Theme.text : Theme.tertiary, 1.2)
                }
                c.linje(CGPoint(x: x0, y: y), CGPoint(x: x(frame), y: y), Theme.secondary, 1.5)
                c.prick(CGPoint(x: x(frame), y: y), 4, Theme.text)
            }
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0).onChanged { d in
                guard count > 1 else { return }
                let a = min(1, max(0, (d.location.x - 4) / max(1, geo.size.width - 8)))
                onScrub(Int((a * CGFloat(count - 1)).rounded()))
            })
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Frame"))
        .accessibilityValue(Text(verbatim: "\(frame + 1) / \(count)"))
        .accessibilityAdjustableAction { riktning in
            switch riktning {
            case .increment: onScrub(min(count - 1, frame + 1))
            case .decrement: onScrub(max(0, frame - 1))
            @unknown default: break
            }
        }
    }
}

/// En rad under videon: namnet (i accenten när det övas, BESLUT B31), märkningen, spannet
/// kompakt och talet med enheten.
struct PositionsradVy: View {
    let rad: Positionsrad

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(rad.namn)
                    .typsnitt(14)
                    .foregroundStyle(rad.ovas ? Theme.acc : Theme.secondary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if let m = rad.markning { MarkningVy(markning: m) }
                    if let u = rad.under {
                        Text(u)
                            .typsnitt(11, .semibold)
                            .foregroundStyle(Theme.tertiary)
                    }
                }
            }
            Spacer(minLength: 6)
            if let s = rad.spann {
                SpannVy(spann: s, kompakt: true, accent: rad.ovas)
                    .frame(width: 84)
            }
            HStack(alignment: .firstTextBaseline, spacing: rad.enhet == "°" ? 0 : 3) {
                Text(rad.varde)
                    .typsnitt(15, .medium, siffror: true)
                    .foregroundStyle(rad.varde == "—" ? Theme.tertiary : Theme.text)
                if !rad.enhet.isEmpty && rad.varde != "—" {
                    Text(rad.enhet)
                        .typsnitt(11)
                        .foregroundStyle(Theme.tertiary)
                }
            }
            .frame(minWidth: 70, alignment: .trailing)
        }
        .padding(.vertical, 7)
        .frame(minHeight: 38)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hair).frame(height: 1) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rad.upplasning)
        .infoblad(rad.info)                      // BESLUT B41
    }
}

/// Videon i en AVPlayerLayer, skuren till utsnittet: lagret är hela bilden, flyttat och
/// förstorat så att utsnittet fyller ytan (som har utsnittets proportioner), och ytan klipper
/// resten. Samma koordinater som lederna (METOD MS13, MS15). Lagret syns inte i simulatorns
/// bilder; provet ritar ytan med rutan ur filen i stället (BESLUT B35).
struct CroppedPlayerSurface: UIViewRepresentable {
    let player: AVPlayer
    let crop: CropRect

    final class Surface: UIView {
        let playerLayer = AVPlayerLayer()
        var crop = CropRect.full {
            didSet { setNeedsLayout() }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            clipsToBounds = true
            backgroundColor = .black
            playerLayer.videoGravity = .resize
            layer.addSublayer(playerLayer)
        }

        required init?(coder: NSCoder) { nil }

        override func layoutSubviews() {
            super.layoutSubviews()
            let w = bounds.width / CGFloat(max(crop.width, 1e-3))
            let h = bounds.height / CGFloat(max(crop.height, 1e-3))
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            playerLayer.frame = CGRect(x: -CGFloat(crop.x) * w, y: -CGFloat(crop.y) * h, width: w, height: h)
            CATransaction.commit()
        }
    }

    func makeUIView(context: Context) -> Surface {
        let v = Surface(frame: .zero)
        v.playerLayer.player = player
        v.crop = crop
        return v
    }

    func updateUIView(_ v: Surface, context: Context) {
        if v.playerLayer.player !== player { v.playerLayer.player = player }
        if v.crop != crop { v.crop = crop }
    }
}
