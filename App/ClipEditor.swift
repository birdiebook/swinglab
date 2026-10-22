import AVFoundation
import SwiftUI
import UIKit
import Capture

/// Redigeraren (PLAN.md S2i): efter en import eller inspelning, före Analyze, och från
/// passet för en serie. Videon med uppspelning och stegning ruta för ruta, tidslinjen med
/// två handtag för start och slut (klicken som streck: vita inom fönstret, grå utanför),
/// och rutan för utsnittet som dras, nyps och dras i hörnen runt spelaren; ett dubbeltryck
/// ger hela bilden. Originalfilen ändras aldrig: Done sparar fönstret och utsnittet i
/// passet (`Store.saveEdit`). B13: svart och vitt, tunna linjer, bara handtagen, rutan och
/// tiden. Logiken (klampningen, rutans rörelser, tidslinjen) är SwingLabKits `Edit.swift`.
/// METOD MS13, BESLUT B34
struct ClipEditorView: View {
    let passID: String
    let seriesNr: Int
    /// Efter Done (sparat) eller Close (inget sparat).
    var onDone: () -> Void

    @Environment(Store.self) private var store
    @State private var series: SeriesRecord?
    @State private var player = AVPlayer()
    @State private var window = TimeWindow(start: 0, end: 0)
    @State private var crop = CropRect.full
    @State private var current = 0.0
    @State private var playing = false
    @State private var observer: Any?
    @State private var problem: String?

    var body: some View {
        Group {
            if let series {
                EditorContent(surface: PlayerSurface(player: player), uprightWidth: series.uprightWidth,
                              uprightHeight: series.uprightHeight, duration: series.duration, clicks: series.clicks,
                              window: window, crop: $crop, current: current, playing: playing, problem: problem,
                              onStart: { setStart($0) }, onEnd: { setEnd($0) }, onScrub: { seek($0) },
                              onPlay: togglePlay, onStep: step, onClose: close, onDone: done)
            } else {
                Theme.ground
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
        guard series == nil, let pass = store.load(passID),
              let s = pass.series.first(where: { $0.nr == seriesNr }) else { return }
        series = s
        window = s.activeWindow
        crop = s.edit?.crop ?? .full
        current = window.start
        let url = store.url(s.file, in: passID)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.actionAtItemEnd = .pause
        // Spelhuvudet följer videon; uppspelningen stannar vid fönstrets slut.
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 60), queue: .main) { t in
            MainActor.assumeIsolated {
                guard t.isValid else { return }
                current = t.seconds
                if playing, current >= window.end {
                    player.pause()
                    playing = false
                }
            }
        }
        seek(window.start)
    }

    private func seek(_ t: Double) {
        let d = series?.duration ?? 0
        let t = min(max(0, t), max(0, d))
        current = t
        player.seek(to: CMTime(seconds: t, preferredTimescale: 48_000), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func setStart(_ t: Double) {
        guard let s = series else { return }
        window = window.withStart(t, duration: s.duration)
        pause()
        seek(window.start)
    }

    private func setEnd(_ t: Double) {
        guard let s = series else { return }
        window = window.withEnd(t, duration: s.duration)
        pause()
        seek(window.end)
    }

    private func pause() {
        player.pause()
        playing = false
    }

    /// Spelar fönstret: från starten om spelhuvudet står utanför eller vid slutet.
    private func togglePlay() {
        if playing {
            pause()
            return
        }
        if current < window.start || current >= window.end - 0.01 { seek(window.start) }
        player.play()
        playing = true
    }

    /// En ruta bakåt eller framåt.
    private func step(_ n: Int) {
        pause()
        player.currentItem?.step(byCount: n)
    }

    private func close() {
        pause()
        onDone()
    }

    private func done() {
        pause()
        do {
            _ = try store.saveEdit(SeriesEdit(window: window, crop: crop), series: seriesNr, in: passID)
            onDone()
        } catch {
            problem = String(localized: "pass.json could not be saved.")
        }
    }
}

/// Redigerarens innehåll som värden (videoytan är utbytbar), så att provet kan rita den
/// med en stillbild i stället för spelaren. Ingen ScrollView och ingen UIKit-del utom ytan.
struct EditorContent<Surface: View>: View {
    let surface: Surface
    let uprightWidth: Int
    let uprightHeight: Int
    let duration: Double
    let clicks: [Click]
    let window: TimeWindow
    @Binding var crop: CropRect
    let current: Double
    let playing: Bool
    var problem: String?
    var onStart: (Double) -> Void = { _ in }
    var onEnd: (Double) -> Void = { _ in }
    var onScrub: (Double) -> Void = { _ in }
    var onPlay: () -> Void = {}
    var onStep: (Int) -> Void = { _ in }
    var onClose: () -> Void = {}
    var onDone: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Close", action: onClose)
                    .typsnitt(15, .semibold)
                    .foregroundStyle(Theme.secondary)
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                Spacer()
            }
            ZStack {
                surface
                CropOverlay(crop: $crop)
            }
            .aspectRatio(CGFloat(max(1, uprightWidth)) / CGFloat(max(1, uprightHeight)), contentMode: .fit)
            .background(Theme.cam)
            .clipShape(.rect(cornerRadius: 2))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TrimBar(timeline: TrimTimeline(window: window, duration: duration, current: current, clicks: clicks),
                    duration: duration, onStart: onStart, onEnd: onEnd, onScrub: onScrub)
                .frame(height: 44)
            HStack {
                Text(verbatim: Taltext.decimal(window.start, digits: 2))
                Spacer()
                Text(String(localized: "\(Taltext.decimal(current, digits: 2)) s"))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(verbatim: Taltext.decimal(window.end, digits: 2))
            }
            .typsnitt(13, siffror: true)
            .foregroundStyle(Theme.secondary)

            HStack(spacing: 36) {
                symbol("backward.frame.fill", "Previous frame") { onStep(-1) }
                symbol(playing ? "pause.fill" : "play.fill", playing ? LocalizedStringKey("Pause") : LocalizedStringKey("Play"),
                       onPlay)
                symbol("forward.frame.fill", "Next frame") { onStep(1) }
            }
            if let problem {
                Text(verbatim: problem)
                    .typsnitt(13, .semibold)
                    .foregroundStyle(Theme.flag)
            }
            Button("Done", action: onDone).buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private func symbol(_ name: String, _ label: LocalizedStringKey, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Theme.text)
                .frame(width: 48, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

/// Rutan för utsnittet över videon: utanför rutan dämpat, rutan en tunn vit linje med
/// hörnen som handtag. Dra inuti flyttar, dra ett hörn ändrar storleken (fria proportioner),
/// nyp skalar kring mitten, dubbeltryck ger hela bilden. Rutan är normaliserad i den
/// upprätta bilden; ytan har bildens proportioner. METOD MS13
struct CropOverlay: View {
    @Binding var crop: CropRect

    private enum Mode {
        case move
        case corner(CropRect.Corner)
    }

    @State private var drag: (mode: Mode, start: CropRect)?
    @State private var pinch: CropRect?

    /// Ett tryck så nära ett hörn tar hörnet, punkter.
    static let cornerReach: CGFloat = 32

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            Canvas { c, s in
                let full = CGRect(origin: .zero, size: s)
                let r = Self.rect(crop, in: s)
                var dim = Path()
                dim.addRect(full)
                dim.addRect(r)
                c.fill(dim, with: .color(.black.opacity(0.55)), style: FillStyle(eoFill: true))
                c.stroke(Path(r.insetBy(dx: 0.5, dy: 0.5)), with: .color(Theme.text), lineWidth: 1)
                // Hörnen: korta, lite tjockare linjer innanför rutan.
                let l = min(16, r.width / 4, r.height / 4)
                var horn = Path()
                let hornen: [(CGPoint, CGFloat, CGFloat)] = [
                    (CGPoint(x: r.minX, y: r.minY), 1, 1), (CGPoint(x: r.maxX, y: r.minY), -1, 1),
                    (CGPoint(x: r.minX, y: r.maxY), 1, -1), (CGPoint(x: r.maxX, y: r.maxY), -1, -1),
                ]
                for (p, dx, dy) in hornen {
                    let q = CGPoint(x: p.x + dx * 1.5, y: p.y + dy * 1.5)
                    horn.move(to: CGPoint(x: q.x + dx * l, y: q.y))
                    horn.addLine(to: q)
                    horn.addLine(to: CGPoint(x: q.x, y: q.y + dy * l))
                }
                c.stroke(horn, with: .color(Theme.text), lineWidth: 3)
            }
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if drag == nil {
                            guard let m = mode(at: v.startLocation, size: size) else { return }
                            drag = (m, crop)
                        }
                        guard let d = drag, size.width > 0, size.height > 0 else { return }
                        let dx = Double(v.translation.width / size.width), dy = Double(v.translation.height / size.height)
                        switch d.mode {
                        case .move:
                            crop = d.start.moved(dx: dx, dy: dy)
                        case .corner(let k):
                            let p = d.start.point(k)
                            crop = d.start.dragging(k, to: p.x + dx, p.y + dy)
                        }
                    }
                    .onEnded { _ in drag = nil }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { v in
                        if pinch == nil { pinch = crop }
                        crop = (pinch ?? crop).scaled(by: Double(v.magnification))
                    }
                    .onEnded { _ in pinch = nil }
            )
            .onTapGesture(count: 2) { crop = .full }
            .accessibilityElement()
            .accessibilityLabel(Text("Crop"))
        }
    }

    /// Hörnet närmast trycket inom räckvidden, annars flytt om trycket ligger i rutan.
    private func mode(at p: CGPoint, size: CGSize) -> Mode? {
        let r = Self.rect(crop, in: size)
        var bast: (CropRect.Corner, CGFloat)?
        for k in CropRect.Corner.allCases {
            let q = crop.point(k)
            let d = hypot(p.x - CGFloat(q.x) * size.width, p.y - CGFloat(q.y) * size.height)
            if d <= Self.cornerReach, d < (bast?.1 ?? .infinity) { bast = (k, d) }
        }
        if let bast { return .corner(bast.0) }
        return r.contains(p) ? .move : nil
    }

    static func rect(_ c: CropRect, in s: CGSize) -> CGRect {
        CGRect(x: CGFloat(c.x) * s.width, y: CGFloat(c.y) * s.height,
               width: CGFloat(c.width) * s.width, height: CGFloat(c.height) * s.height)
    }
}

/// Tidslinjen: hela filen som en tunn grå linje, fönstret vitt mellan handtagen, klicken
/// som korta streck (vita inom fönstret, grå utanför: de räknas inte som slag) och
/// spelhuvudet. Handtagen dras; ett tryck eller drag på linjen flyttar spelhuvudet.
struct TrimBar: View {
    let timeline: TrimTimeline
    let duration: Double
    var onStart: (Double) -> Void
    var onEnd: (Double) -> Void
    var onScrub: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width), h = geo.size.height
            let x = { (f: Double) in CGFloat(f) * w }
            ZStack(alignment: .topLeading) {
                Canvas { c, s in
                    let mitt = s.height / 2
                    func linje(_ a: CGFloat, _ b: CGFloat, _ farg: Color, _ bredd: CGFloat) {
                        var p = Path()
                        p.move(to: CGPoint(x: a, y: mitt))
                        p.addLine(to: CGPoint(x: b, y: mitt))
                        c.stroke(p, with: .color(farg), lineWidth: bredd)
                    }
                    linje(0, s.width, Theme.line, 2)
                    linje(x(timeline.start), x(timeline.end), Theme.text, 2)
                    for t in timeline.ticks {
                        var p = Path()
                        p.move(to: CGPoint(x: x(t.position), y: mitt - 7))
                        p.addLine(to: CGPoint(x: x(t.position), y: mitt + 7))
                        c.stroke(p, with: .color(t.counted ? Theme.text : Theme.tertiary), lineWidth: 1.5)
                    }
                    var spel = Path()
                    spel.move(to: CGPoint(x: x(timeline.playhead), y: 2))
                    spel.addLine(to: CGPoint(x: x(timeline.playhead), y: s.height - 2))
                    c.stroke(spel, with: .color(Theme.secondary), lineWidth: 1)
                }
                .contentShape(.rect)
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    onScrub(TrimTimeline.time(at: Double(v.location.x / w), duration: duration))
                })
                handle(at: x(timeline.start), height: h, label: "Start", onStart, width: w)
                handle(at: x(timeline.end), height: h, label: "End", onEnd, width: w)
            }
            .coordinateSpace(.named("trim"))
        }
    }

    /// Ett handtag: en smal vit stapel med en bred yta att ta i.
    private func handle(at px: CGFloat, height: CGFloat, label: LocalizedStringKey, _ set: @escaping (Double) -> Void,
                        width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Theme.text)
            .frame(width: 4, height: height * 0.7)
            .frame(width: 44, height: height)
            .contentShape(.rect)
            .offset(x: px - 22)
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("trim")).onChanged { v in
                set(TrimTimeline.time(at: Double(v.location.x / width), duration: duration))
            })
            .accessibilityLabel(Text(label))
    }
}

/// Videon i en AVPlayerLayer, med bildens proportioner (ytan runt omkring har samma).
struct PlayerSurface: UIViewRepresentable {
    let player: AVPlayer

    final class LayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> LayerView {
        let v = LayerView()
        v.playerLayer.videoGravity = .resizeAspect
        v.playerLayer.player = player
        v.backgroundColor = .black
        return v
    }

    func updateUIView(_ v: LayerView, context: Context) {
        if v.playerLayer.player !== player { v.playerLayer.player = player }
    }
}
