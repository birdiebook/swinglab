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
/// Menyn öppnar också "Mark club" (S7a, bakifrån och framifrån, BESLUT B47, B57, B58): klubban
/// markeras för hand per position (`ClubMarkContent`), och det som är markerat syns som en tunn
/// linje i rutan. METOD MS14, MS15, M45
struct ShotReviewView: View {
    let passID: String
    let shotID: String
    /// Vyn att börja i, i ett parat pass på den styrande (S6g, BESLUT B82): den andra telefonens
    /// när passet visade den. nil = den här telefonens.
    var startVy: Vy? = nil
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
    /// Riktpinnens steg före P1 (bakifrån, en gång per serie, BESLUT B59, METOD M48) och dess tryck.
    @State private var stickStep = false
    @State private var stickPoints: [KlubbPunkt] = []
    /// Guiden till märkningen (BESLUT B59): sidan som visas, nil = ingen guide.
    @State private var guidePage: Int?
    /// Senaste trycket ändrade märkningen (ett dubbeltryck ångrar det).
    @State private var lastTapChanged = false
    /// Rutan som stillbild för glaset (toleransen 0), och vilken ruta den är.
    @State private var loupeImage: (frame: Int, image: CGImage)?
    /// Ett steg till en annan ruta när punkter är satta: frågan om de ska tömmas.
    @State private var pendingStep: Int?
    @State private var askDiscard = false
    /// Sparningen utanför huvudtråden; bara den senaste skrivs.
    @State private var saveCount = 0
    /// Spåren som visas (S4f, BESLUT B70), räknade när valet eller slaget ändras.
    @State private var spar: SparBild?
    /// Den andra telefonens video för slaget (S6g, BESLUT B82, METOD MS31): filen, videons tid −
    /// den här seriens tid (synkat på träffen) och bildens proportioner; nil = ingen.
    @State private var annanKalla: ParadKalla?
    @State private var egenKalla: ParadKalla?
    /// Den andra vyns pass och slag, för raderna per position i den vyn.
    @State private var annanSlag: (pass: PassState, shot: ShotRecord)?
    /// Den andra vyn visas.
    @State private var visarAnnan = false
    /// Den andra telefonens klipp kom utan klick: synken tar det väntade (MS31), och det sägs.
    @State private var annanUtanKlick = false

    private var shot: ShotRecord? { pass?.shots.first { $0.id == shotID } }

    var body: some View {
        Group {
            if marking != nil, let page = guidePage {
                ScrollView {
                    ClubGuideContent(page: page, onNext: { guidePage = page + 1 }, onClose: closeGuide)
                        .padding(.vertical, 8)
                }
            } else if let shot, let review, let m = marking {
                ScrollView {
                    ClubMarkContent(surface: { CroppedPlayerSurface(player: player, crop: $0) },
                                    loupe: { LoupeImage(image: loupeImage?.frame == frame ? loupeImage?.image : nil, crop: $0) },
                                    marking: m, time: timeText(review, shot), ring: ring(review),
                                    suggestion: frameT(review).flatMap { m.shownSuggestion(t: $0) },
                                    canUse: frameT(review).map { m.canUseSuggestion(t: $0) } ?? false,
                                    onUse: useSuggestion,
                                    stickStep: stickStep, stick: stickPoints,
                                    onTap: tapped, onMove: { g, u, v in change { $0.move(g, u: u, v: v) } },
                                    onPan: { du, dv in marking?.pan(du: du, dv: dv) },
                                    onZoom: { k, u, v in marking?.zoom(by: k, u: u, v: v) },
                                    onDoubleTap: doubleTapped,
                                    onStep: markingStep, onUndo: { change { $0.undo() } },
                                    onSkip: { change { $0.skip(t: review.frames[frame].t) } },
                                    onStickSkip: skipStick,
                                    hasStick: pass?.riktpinne(series: shot.series) != nil, onStickRemove: removeStick,
                                    onStickMenu: openStickStep, onStickDone: { saveStick(stickPoints) },
                                    onPosition: { p in change { $0.go(to: p) } }, onHelp: { guidePage = 0 },
                                    onClose: closeMarking)
                        .padding(.vertical, 8)
                }
                // Ytans drag och nyp är märkningens; sidan rullar inte under dem (granskningen av S7c).
                .scrollDisabled(true)
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
                    // Den andra vyn (S6g): samma rutor, positioner och stegning på den här seriens
                    // tid, videon den andra telefonens synkad på träffen; lederna och spåren är den
                    // här vyns och visas inte där, raderna är den andra vyns.
                    let annan = visarAnnan && annanKalla != nil
                    ReviewContent(surface: CroppedPlayerSurface(player: player, crop: annan ? .full : review.crop),
                                  review: review,
                                  number: ShotRecord.number(shot.id) ?? 0, frame: frame, overlayOn: overlayOn && !annan,
                                  playing: playing, position: position, positions: review.positions(shot.measure),
                                  rows: annan ? annanRader : ReviewRows.rows(pass: pass, shot: shot, position: position,
                                                                             baseline: baseline, ovas: ovas),
                                  detectionWrong: shot.detectionWrong == true, impact: shot.impact - shot.click.time,
                                  shaft: annan ? nil : review.shaft(frame, marks: shot.klubba),
                                  spar: annan ? nil : spar, sparVal: store.settings.sparVal, onSpar: sparTryck,
                                  klubba: klubbChip(shot), klubbaFel: store.klubbaFel[klubbNyckel],
                                  onClose: close, onPlay: togglePlay, onStep: step, onScrub: { pause(); seek($0) },
                                  onPosition: jump, onOverlay: { overlayOn.toggle() }, onDetectionWrong: setWrong,
                                  onMarkClub: startMarking,
                                  vyval: annanKalla == nil ? nil : AnyView(vyval(pass.setup.view)),
                                  aspekt: annan ? annanKalla?.aspekt : nil)
                        .padding(.vertical, 8)
                }
                .task(id: SparNyckel(trails: store.settings.trails, klubba: shot.klubba)) { uppdateraSpar() }
                .onChange(of: store.klubbaRaknar) { fore, nu in
                    // Banan är räknad och sparad i passet: läs om det och rita.
                    if fore == klubbNyckel, nu == nil, let p = store.load(passID) {
                        self.pass = p
                        uppdateraSpar()
                    }
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
            if store.klubbaRaknar == klubbNyckel { store.avbrytKlubbBana() }
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
        egenKalla = ParadKalla(url: url, offset: offset, aspekt: r.aspect)
        let finns = FileManager.default.fileExists(atPath: url.path)
        // Den andra telefonens video kan finnas fast den här seriens original är borttaget (S6g).
        guard finns || p.setup.role == .lead else { return }
        if finns { player.replaceCurrentItem(with: AVPlayerItem(url: url)) }
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
        laddaAnnan(p, s)
    }

    // MARK: den andra vyn (S6g)

    /// Växlingen DTL/FO ovanför videon.
    private func vyval(_ egen: Vy) -> some View {
        let annan = Vyvakt.annan(egen)
        let vyer = egen == .dtl ? [egen, annan] : [annan, egen]
        return VStack(alignment: .leading, spacing: 4) {
            Segment(alternativ: vyer.map(Texter.vyKort), valt: Binding(
                get: { vyer.firstIndex(of: visarAnnan ? annan : egen) ?? 0 },
                set: { visa(vyer[$0] != egen) }))
            if visarAnnan && annanUtanKlick {
                Text(verbatim: Texter.ingetKlick)
                    .typsnitt(13)
                    .foregroundStyle(Theme.tertiary)
            }
        }
    }

    /// Raderna per position i den andra vyn (dess mått för samma sving), när dess slag finns.
    private var annanRader: [Positionsrad] {
        guard let a = annanSlag else { return [] }
        return ReviewRows.rows(pass: a.pass, shot: a.shot, position: position, baseline: [:], ovas: ovas)
    }

    /// Den andra telefonens video för slaget, och dess slag ur bunten (för raderna). METOD MS31
    private func laddaAnnan(_ p: PassState, _ s: ShotRecord) {
        guard p.setup.role == .lead, let v = store.annanVideo(passID),
              let e = KlippBegaran.parning(store.pairs(passID), serie: s.series, vy: p.setup.view),
              let k = v.kalla(slag: s, par: e) else { return }
        let url = store.url(k.fil, in: passID)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        annanKalla = ParadKalla(url: url, offset: k.offset, aspekt: 9.0 / 16)
        annanUtanKlick = v.utanKlick.contains(s.id)
        let folder = store.passFolder(passID)
        Task {
            let r = await Task.detached(priority: .userInitiated) { () -> (PassState, ShotRecord, Double)? in
                guard let d = Store.otherPhoneData(folder), let b = try? SlagBunt.las(d),
                      let ap = try? AnnanSession.pass(b, lead: p), let fs = AnnanSession.slag(s, i: ap, par: e) else { return nil }
                let l = try? b.lederna()[fs.id]
                return (ap, fs, l.map { Double($0.width) / Double(max(1, $0.height)) } ?? 9.0 / 16)
            }.value
            guard let r else { return }
            annanSlag = (r.0, r.1)
            annanKalla?.aspekt = r.2
        }
        if startVy == Vyvakt.annan(p.setup.view) { visa(true) }
    }

    /// Byter video: samma ruta, den andra telefonens synkad på träffen (eller tillbaka).
    private func visa(_ annan: Bool) {
        guard let k = annan ? annanKalla : egenKalla, annan != visarAnnan || player.currentItem == nil else { return }
        pause()
        visarAnnan = annan
        offset = k.offset
        player.replaceCurrentItem(with: AVPlayerItem(url: k.url))
        seek(frame)
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

    // MARK: spåren (S4f) och klubbhuvudets bana (S7b)

    /// Spåren för valet: kroppens ur lederna, och klubbhuvudets när banan är räknad ur dagens
    /// markeringar (BESLUT B70, B71). Banan räknas bara när Club slås på eller trycks.
    private func uppdateraSpar() {
        guard let review, let shot else { return }
        let val = store.settings.sparVal
        var s = review.spar(Array(val))
        if val.contains(.club), let b = shot.klubbaBana, b.aktuell(shot.klubba) { s.append(SparSerie(bana: b)) }
        spar = s.isEmpty ? nil : SparBild(serier: s, bredd: review.width, hojd: review.height, crop: review.crop,
                                          plan: sparPlan(shot))
    }

    private var klubbNyckel: String { "\(passID)/\(shotID)" }

    /// Club-chipets läge (B71): dolt utan två grannpositioner, räknas, inte räknat eller klart.
    private func klubbChip(_ shot: ShotRecord) -> KlubbChip {
        KlubbLage.chip(klubba: shot.klubba, bana: shot.klubbaBana, raknar: store.klubbaRaknar == klubbNyckel,
                       clubPa: store.settings.sparVal.contains(.club))
    }

    /// Ett tryck på ett chip. Club räknar banan när den slås på, och när den är på men banan inte
    /// är räknad för slaget; av under räkningen avbryter den (METOD M61).
    private func sparTryck(_ p: SparPunkt) {
        guard let shot else { return }
        let pa = store.settings.sparVal.contains(p)
        if p == .club {
            switch klubbChip(shot) {
            case .ejRaknad:
                store.raknaKlubbBana(passID: passID, shotID: shotID)
                return
            case .raknar:
                store.avbrytKlubbBana()
            default:
                break
            }
        }
        store.toggleTrail(p)
        if p == .club, !pa, case .mojlig = klubbChip(shot) {
            store.raknaKlubbBana(passID: passID, shotID: shotID)
        }
    }

    /// P1-skaftets linje bakifrån när klubbhuvudets aktuella bana visas (M47, B71).
    private func sparPlan(_ shot: ShotRecord) -> (grepp: Punkt, hosel: Punkt)? {
        guard let vy = pass?.setup.view else { return nil }
        return KlubbLage.plan(vy: vy, clubPa: store.settings.sparVal.contains(.club), klubba: shot.klubba,
                              bana: shot.klubbaBana)
    }

    // MARK: klubban (S7a)

    private func timeText(_ r: ShotReview, _ s: ShotRecord) -> String {
        guard r.frames.indices.contains(frame) else { return "" }
        return Tal.tecken(r.frames[frame].t - (s.impact - s.click.time), decimaler: 3) + " s"
    }

    /// "Mark club": märkningen börjar på den första positionen utan markering i märkningens
    /// ordning (kroppens först, skaftets sist, BESLUT B58), i passets vy (framifrån utan
    /// riktpinne, P2/P6/P8 ur skaftets vinkel, B57), med svingens `xTecken`. Bakifrån kommer
    /// riktpinnens steg först när serien inte har någon och steget inte hoppats över, och guiden
    /// första gången (B59). METOD M45
    private func startMarking() {
        guard let review, let shot, let pass, let series else { return }
        pause()
        let vy = pass.setup.view, hand = pass.setup.hand, langd = pass.heightM ?? ShotMeasuring.assumedHeightM
        let traff = shot.impact - shot.click.time
        // Modellens förslag för slaget, när en fil är hämtad för passet och vyn (S7d, BESLUT B93).
        let forslagFil = store.clubSuggestionFile(pass)
        Task {
            // Svingen (för xTecken) och förslagen (upp till 20 MB) läses utanför huvudtråden.
            let xTecken = await Task.detached(priority: .userInitiated) { () -> Double? in
                (try? ShotMeasuring.sving(series, view: vy, hand: hand, heightM: langd, impact: traff))?.xTecken
            }.value
            let forslag = await Task.detached(priority: .userInitiated) { () -> KlubbForslagFil? in
                forslagFil.flatMap { Store.clubSuggestions(at: $0) }
            }.value
            guard let xTecken, marking == nil, let pass = self.pass, let shot = self.shot else { return }
            let serie = pass.series.first { $0.nr == shot.series }
            marking = ClubMarking(existing: shot.klubba, width: review.width, height: review.height,
                                  crop: serie?.activeCrop, view: vy, xTecken: xTecken,
                                  suggestions: forslag?.rutor(slag: shot.id, bredd: review.width, hojd: review.height) ?? [],
                                  suggestionModel: forslag?.modell ?? "")
            stickStep = pass.asksForRiktpinne(series: shot.series)
            stickPoints = []
            guidePage = store.settings.clubGuideSeen == true ? nil : 0
            seekToPosition(zoom: !stickStep)
        }
    }

    /// Guiden stängs: den har visats (en inställning per användare, B59).
    private func closeGuide() {
        guidePage = nil
        store.setClubGuideSeen()
    }

    /// Rutan för positionen som märks: punkternas, annars förslaget (METOD M45). Med `zoom`
    /// öppnas positionen inzoomad kring händerna i den rutan.
    private func seekToPosition(zoom: Bool = true) {
        guard let m = marking, !m.done, let review, let shot else { return }
        let k = review.index(nearestT: m.shownTime(measure: shot.measure, impact: shot.impact - shot.click.time)) ?? frame
        seek(k)
        if zoom {
            let t = review.frames.indices.contains(k) ? review.frames[k].t : nil
            marking?.startZoom(hands: ring(review, at: k), cmPerPx: shot.measure?.cmPerPx, t: t)
        }
    }

    /// Appens gissning av greppet i rutan (BESLUT B47, B59): handledernas mitt, eller den som syns.
    private func ring(_ r: ShotReview, at k: Int? = nil) -> KlubbPunkt? {
        let k = k ?? frame
        guard r.frames.indices.contains(k) else { return nil }
        let h = [5, 6].compactMap { i -> PoseJoint? in
            guard i < r.frames[k].joints.count, let j = r.frames[k].joints[i], j.c >= Sving.minKonfidens else {
                return nil
            }
            return j
        }
        guard !h.isEmpty else { return nil }
        return KlubbPunkt(x: h.map(\.x).reduce(0, +) / Double(h.count), y: h.map(\.y).reduce(0, +) / Double(h.count))
    }

    /// Den visade rutans Visions-tid, s relativt klicket.
    private func frameT(_ r: ShotReview) -> Double? {
        r.frames.indices.contains(frame) ? r.frames[frame].t : nil
    }

    /// ✓: modellens förslag i rutan godkänt med ett tryck (S7d, BESLUT B93).
    private func useSuggestion() {
        guard let review, let t = frameT(review) else { return }
        change { $0.useSuggestion(t: t) }
        lastTapChanged = false
    }

    /// Ett tryck: riktpinnens ände i det steget, annars nästa punkt i rutan.
    private func tapped(_ u: Double, _ v: Double) {
        guard let m = marking, let review, review.frames.indices.contains(frame) else { return }
        if stickStep {
            guard let p = m.imagePoint(u: u, v: v) else {
                lastTapChanged = false
                return
            }
            stickPoints = Array((stickPoints + [p]).suffix(2))
            lastTapChanged = true
            return
        }
        let t = review.frames[frame].t
        let r = ring(review)
        let fore = m
        change { $0.tap(u: u, v: v, t: t, ring: r) }
        lastTapChanged = marking != fore
    }

    /// Dubbeltrycket: hela bilden, eller tillbaka till startzoomen; ett första tryck som satte en
    /// punkt ångras (METOD M45).
    private func doubleTapped() {
        guard var m = marking, let review, let shot else { return }
        if lastTapChanged && stickStep {
            // Dubbeltrycket i riktpinnens steg ångrar stegets första tryck.
            if !stickPoints.isEmpty { stickPoints.removeLast() }
        } else if lastTapChanged {
            change { $0.undo() }
            m = marking ?? m
        }
        lastTapChanged = false
        if m.zoom == m.crop {
            m.startZoom(hands: ring(review), cmPerPx: shot.measure?.cmPerPx, t: frameT(review))
        } else {
            m.showWhole()
        }
        marking = m
    }

    /// Riktpinnen sparas (två tryck på en pinne på marken, parallell med mållinjen), och märkningen
    /// går vidare till P1. METOD M48
    private func saveStick(_ pinne: [KlubbPunkt]) {
        guard var p = pass, let shot, let series, pinne.count == 2 else { return }
        let id = shotID, nr = shot.series, passID = p.id
        p.setRiktpinne(pinne, series: nr) { s in s.id == id ? series : store.joints(s.joints ?? "", in: passID) }
        store.save(p)
        pass = p
        endStickStep()
    }

    /// Riktpinnens steg hoppas över för serien; märkningen frågar inte igen (BESLUT B59).
    private func skipStick() {
        guard var p = pass, let shot else { return }
        p.skipRiktpinne(series: shot.series)
        store.save(p)
        pass = p
        endStickStep()
    }

    /// Riktpinnen ur menyn (bakifrån): steget igen, med seriens pinne om den finns, för att sätta
    /// om den eller ta bort den (B59).
    private func openStickStep() {
        guard let shot, marking?.stickAvailable == true else { return }
        stickPoints = pass?.riktpinne(series: shot.series) ?? []
        stickStep = true
        marking?.showWhole()
    }

    /// Riktpinnen tas bort; steget frågar inte igen för serien (flyktpunkten är då bildens mitt, M48).
    private func removeStick() {
        guard var p = pass, let shot, let series else { return }
        let id = shotID, nr = shot.series, passID = p.id
        p.setRiktpinne(nil, series: nr) { s in s.id == id ? series : store.joints(s.joints ?? "", in: passID) }
        p.skipRiktpinne(series: nr)
        store.save(p)
        pass = p
        endStickStep()
    }

    private func endStickStep() {
        stickStep = false
        stickPoints = []
        marking?.showWhole()
        seekToPosition()
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
        if m.position != fore.0 { seekToPosition() } else if m.frameT != fore.1 || m.done { seekToPosition(zoom: false) }
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
        stickStep = false
        stickPoints = []
        guidePage = nil
    }
}

/// Måtten under videon: slagets vid positionen, i slagets vy (METOD M29, MS15). `ovas` =
/// felen i Att jobba på: deras rader bär accenten (BESLUT B31).
enum ReviewRows {
    static func rows(pass: PassState, shot: ShotRecord, position: String, baseline: [String: [Double]],
                     ovas: Set<String> = []) -> [Positionsrad] {
        guard let k = AppKatalog.katalog, let m = shot.measure else { return [] }
        // Rött, gult, grönt och sist utan läge, som passets kort (PLAN S4h, METOD M63).
        return Lageordning.sortera(Positionsmatt.rader(k, vy: pass.setup.view, position: position, varden: m.values,
                                                       baslinje: baseline, ovas: ovas,
                                                       flyktpunktAntagen: m.klubbaFlyktpunktAntagen == true,
                                                       klubba: pass.setup.club))
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
    /// Spåren (S4f, BESLUT B70): serierna, valet och ett tryck på ett chip; nil = inget val.
    var spar: SparBild? = nil
    var sparVal: Set<SparPunkt> = []
    var onSpar: ((SparPunkt) -> Void)? = nil
    /// Klubbhuvudets spår (S7b): går att välja, räknas, och P1-linjen bakifrån.
    var klubba: KlubbChip = .dold
    /// Varför klubbhuvudets bana saknas (grå rad under chipsen); nil = inget att säga.
    var klubbaFel: String? = nil
    /// Menyn är en UIKit-del som provets ImageRenderer inte ritar; utan den bara symbolen.
    var editable = true
    var onClose: () -> Void = {}
    var onPlay: () -> Void = {}
    var onStep: (Int) -> Void = { _ in }
    var onScrub: (Int) -> Void = { _ in }
    var onPosition: (String) -> Void = { _ in }
    var onOverlay: () -> Void = {}
    var onDetectionWrong: (Bool) -> Void = { _ in }
    /// "Mark club" i menyn (S7a, båda vyerna); nil = ingen märkning (provets bilder).
    var onMarkClub: (() -> Void)? = nil
    /// Växlingen DTL/FO i ett parat pass (S6g, BESLUT B82); nil = en vy.
    var vyval: AnyView? = nil
    /// Bildens proportioner när den andra vyns video visas (hela bilden, inget utsnitt).
    var aspekt: Double? = nil

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

    /// Rutans tid: spåren är spelade fram till den (S4f).
    private var sparNu: Double { review.frames.indices.contains(frame) ? review.frames[frame].t : -.infinity }

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
            if let vyval {
                vyval.padding(.bottom, 8)
            }

            ReviewStage(surface: surface, overlay: review.overlay(frame), overlayOn: overlayOn, time: timeText,
                        shaft: shaft, spar: spar, sparNu: sparNu)
                .aspectRatio(CGFloat(aspekt ?? review.aspect), contentMode: .fit)
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

            if let onSpar {
                SparVal(valda: sparVal, klubba: klubba, onToggle: onSpar)
                    .padding(.top, 6)
                if let klubbaFel, sparVal.contains(.club) {
                    Text(verbatim: klubbaFel)
                        .typsnitt(11)
                        .foregroundStyle(Theme.tertiary)
                        .padding(.top, 4)
                }
            }

            // Positionerna på en rad; de som saknas (armen aldrig vågrät) är grå och går inte att välja.
            HStack(spacing: 0) {
                ForEach(positions.indices, id: \.self) { i in
                    positionButton(positions[i].name, available: positions[i].index != nil)
                }
            }
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.hair).frame(height: 1) }
            .padding(.top, 8)

            // Positionen med namnet först, "Top of backswing (P4)" (PLAN S4h, BESLUT B94).
            if !position.isEmpty {
                Text(verbatim: Texter.positionMedNamn(position))
                    .typsnitt(13, .semibold)
                    .foregroundStyle(Theme.text)
                    .padding(.top, 10)
                    .accessibilityAddTraits(.isHeader)
            }

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
    /// Spåren (S4f, BESLUT B70): ett eget lager under lederna, oberoende av ögat.
    var spar: SparBild? = nil
    var sparNu = 0.0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            surface
            if let spar { SparLager(bild: spar, nu: sparNu) }
            // Med spåren påslagna dämpas lederna, så att spåren skiljer sig från dem (B70).
            if overlayOn { LedOverlay(overlay: overlay, dampad: spar != nil) }
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
    /// Grå i stället för vit, när spåren visas (S4f, BESLUT B70).
    var dampad = false

    var body: some View {
        Canvas { c, s in
            func p(_ q: ShotReview.Point) -> CGPoint { CGPoint(x: CGFloat(q.x) * s.width, y: CGFloat(q.y) * s.height) }
            for l in overlay.lines {
                guard overlay.points.indices.contains(l.from), overlay.points.indices.contains(l.to),
                      let a = overlay.points[l.from], let b = overlay.points[l.to] else { continue }
                c.linje(p(a), p(b), dampad ? Theme.secondary : Theme.text, 1.2, streckad: l.measured ? [] : [3, 3])
            }
            for (i, q) in overlay.points.enumerated() {
                guard let q else { continue }
                c.prick(p(q), i == 0 ? 3.5 : 2.6, dampad ? Theme.secondary : Theme.text, ihalig: q.state == .weak)
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
                SpannVy(spann: s, kompakt: true, accent: rad.ovas, lage: rad.lage)
                    .frame(width: 84)
            }
            LageSymbol(lage: rad.lage, storlek: 10)              // BESLUT B87
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

/// Spåren räknas om när valet eller markeringarna ändras (S4f, S7b).
private struct SparNyckel: Equatable {
    var trails: [String]?
    var klubba: [KlubbMarkering]?
}

/// Club-chipets läge och P1-planet ur slagets markeringar och bana (S7b, BESLUT B71), som
/// värden så att provet kan pröva dem i båda vyerna.
enum KlubbLage {
    /// Dolt utan två grannpositioner, räknas, inte räknat (Club på) eller klart.
    static func chip(klubba: [KlubbMarkering]?, bana: KlubbBana?, raknar: Bool, clubPa: Bool) -> KlubbChip {
        guard KlubbBana.mojlig(klubba) else { return .dold }
        if raknar { return .raknar }
        if let b = bana, b.aktuell(klubba) {
            return .klar(interpolerade: b.punkter.filter { $0.kalla == KlubbSpar.kallaInterpolerad }.count,
                         av: b.punkter.count)
        }
        return clubPa ? .ejRaknad : .mojlig
    }

    /// P1-skaftets linje: bara bakifrån, med Club på och en bana räknad ur dagens markeringar (M47).
    static func plan(vy: Vy, clubPa: Bool, klubba: [KlubbMarkering]?, bana: KlubbBana?) -> (grepp: Punkt, hosel: Punkt)? {
        guard vy == .dtl, clubPa, let b = bana, b.aktuell(klubba),
              let p1 = klubba?.first(where: { $0.position == "P1" && $0.markerad }),
              let g = p1.grepp, let h = p1.hosel else { return nil }
        return (Punkt(g.x, g.y), Punkt(h.x, h.y))
    }
}

/// En video i granskningen av ett parat pass (S6g): filen, videons tid − seriens tid och bildens
/// proportioner (bredd / höjd).
struct ParadKalla {
    let url: URL
    let offset: Double
    var aspekt: Double
}
