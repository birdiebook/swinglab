import SwiftUI
import Swing
import Capture

/// Slagen i ett pass (S2_SPEC §9, §12 S2e): analysen med förloppet, och listan med
/// domen och en miniatyr vid träffen med de uppmätta linjerna. Formspråket är BESLUT
/// B13: ingen figur, bara linjer över bilden, tal och etiketter; signalfärgen bara för
/// varningar. Accenten (BESLUT B31) är för det som övas och används inte här: listan
/// visar slagen, inga mått.
struct PassShotsView: View {
    let passID: String
    var onClose: () -> Void

    @Environment(Store.self) private var store
    @State private var pass: PassState?
    @State private var analysis = Analysis()
    @State private var images: [String: CGImage] = [:]
    @State private var overlays: [String: ImpactOverlay] = [:]
    @State private var job: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let pass {
                    ShotsContent(pass: pass, images: images, overlays: overlays, analysis: AnalysisState(analysis),
                                 onAnalyze: analyze, onVerdict: setVerdict)
                        .padding(20)
                }
            }
            .background(Theme.ground, ignoresSafeAreaEdges: .all)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose).disabled(analysis.running)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { reload() }
        .onDisappear { job?.cancel() }
    }

    private func reload() {
        pass = store.load(passID)
        guard let pass else { return }
        Task { await loadImages(pass) }
    }

    private func analyze() {
        guard !analysis.running else { return }
        job = Task {
            if let p = await analysis.run(passID: passID, store: store) {
                pass = p
                await loadImages(p)
            }
        }
    }

    private func setVerdict(_ v: SwingVerdict, _ id: String) {
        guard var p = pass, !analysis.running else { return }
        p.setVerdict(v, shot: id)
        store.save(p)
        pass = p
    }

    /// Miniatyrerna och linjerna för slagen som har dom; ett slag som inte går att läsa
    /// får den tomma ytan (vyn visar då bara linjerna, eller inget).
    private func loadImages(_ p: PassState) async {
        for s in p.shots where s.verdict != nil {
            if let o = ShotImages.overlay(shot: s, pass: p, store: store) { overlays[s.id] = o }
            if images[s.id] == nil, let img = try? await ShotImages.impactFrame(pass: p, shot: s, store: store) {
                images[s.id] = img
            }
        }
    }
}

/// Analysens läge som värden, så att provet kan rita vyn utan att köra den.
struct AnalysisState: Equatable {
    var running = false
    var shot = 0
    var shots = 0
    var fraction = 0.0
    var problem: String?

    init(running: Bool = false, shot: Int = 0, shots: Int = 0, fraction: Double = 0, problem: String? = nil) {
        self.running = running
        self.shot = shot
        self.shots = shots
        self.fraction = fraction
        self.problem = problem
    }

    @MainActor
    init(_ a: Analysis) {
        self.init(running: a.running, shot: a.shotNumber, shots: a.shotTotal, fraction: a.fraction, problem: a.problem)
    }
}

/// Innehållet: rubriken, slagen per dom, analysen och listan. Ingen ScrollView och
/// ingen UIKit-del, så att provet kan rita den med ImageRenderer.
struct ShotsContent: View {
    let pass: PassState
    let images: [String: CGImage]
    let overlays: [String: ImpactOverlay]
    let analysis: AnalysisState
    var editable = true
    var onAnalyze: () -> Void = {}
    var onVerdict: (SwingVerdict, String) -> Void = { _, _ in }

    var body: some View {
        let rows = ShotRow.rows(pass)
        let n = ShotRow.counts(pass)
        VStack(alignment: .leading, spacing: 14) {
            Skarmrubrik("Shots")
            HStack(alignment: .top, spacing: 22) {
                count(n.swing, "Swing")
                count(n.notSwing, "Not a swing")
                if n.uncertain > 0 { count(n.uncertain, "Uncertain", flag: true) }
                Spacer(minLength: 0)
            }
            if let ms = n.msPerFrame {
                Under(text: String(localized: "\(ms) ms/frame"))
            }
            if pass.orientationSuspect {
                Text("Orientation suspect")
                    .typsnitt(15, .semibold)
                    .foregroundStyle(Theme.flag)
            }
            if analysis.running {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Shot \(analysis.shot) of \(analysis.shots)")
                        .typsnitt(15, siffror: true)
                        .foregroundStyle(Theme.secondary)
                    ProgressView(value: analysis.fraction).tint(Theme.text)
                }
            } else if ShotPlan.next(pass) != nil || (pass.shots.isEmpty && pass.clickCount > 0) {
                Button("Analyze", action: onAnalyze).buttonStyle(PrimaryButtonStyle())
            }
            if let problem = analysis.problem {
                Text(verbatim: problem)
                    .typsnitt(13, .semibold)
                    .foregroundStyle(Theme.flag)
            }
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    ShotRowView(row: row, image: images[row.id], overlay: overlays[row.id], editable: editable,
                                onVerdict: { onVerdict($0, row.id) })
                }
            }
        }
    }

    private func count(_ n: Int, _ label: LocalizedStringKey, flag: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            StortTal(varde: "\(n)", enhet: "", storlek: 30)
            Text(label)
                .typsnitt(13)
                .foregroundStyle(flag ? Theme.flag : Theme.secondary)
        }
    }
}

/// En rad: miniatyren vid träffen, numret, serien, klubban och tiden, och domen.
struct ShotRowView: View {
    let row: ShotRow
    let image: CGImage?
    let overlay: ImpactOverlay?
    var editable = true
    var onVerdict: (SwingVerdict) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 14) {
            ImpactThumb(image: image, overlay: overlay)
                .frame(width: 54, height: 96)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "\(row.number)")
                    .typsnitt(22, .medium, siffror: true)
                    .foregroundStyle(Theme.text)
                Under(text: detail)
            }
            Spacer(minLength: 8)
            if editable {
                Menu {
                    Button("Swing") { onVerdict(.swing) }
                    Button("Not a swing") { onVerdict(.notSwing) }
                    Button("Uncertain") { onVerdict(.uncertain) }
                } label: { verdictLabel }
            } else {
                verdictLabel
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) { Rectangle().fill(Theme.hair).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        var delar = [String(localized: "Set \(row.series)")]
        if let c = row.club { delar.append(c) }
        delar.append(String(localized: "\(row.time) s"))
        return delar.joined(separator: Texter.skilje)
    }

    private var verdictLabel: some View {
        HStack(spacing: 6) {
            if row.changedByJohannes {
                Image(systemName: "pencil")
                    .typsnitt(13)
                    .foregroundStyle(Theme.tertiary)
                    .accessibilityHidden(true)
            }
            Text(verdictText)
                .typsnitt(15, .medium)
                .foregroundStyle(row.warning ? Theme.flag : row.verdict == .swing ? Theme.text : Theme.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private var verdictText: LocalizedStringKey {
        switch row.verdict {
        case .swing: return "Swing"
        case .notSwing: return "Not a swing"
        case .uncertain: return "Uncertain"
        case nil: return "Not analyzed"
        }
    }
}

/// Rutan vid träffen med de uppmätta linjerna (BESLUT B13: ingen figur): axellinjen,
/// höftlinjen, och handlederna med personens vänstra fylld och högra ihålig, så att
/// vänster och höger syns i klapprovet (T2).
struct ImpactThumb: View {
    let image: CGImage?
    let overlay: ImpactOverlay?

    var body: some View {
        Canvas { c, s in
            c.fill(Path(CGRect(origin: .zero, size: s)), with: .color(Theme.cam))
            // Bilden ryms hel (upprätt); utan bild gäller 9 : 16.
            let aspect = image.map { CGFloat($0.width) / CGFloat(max(1, $0.height)) } ?? 9.0 / 16
            var r = CGRect(origin: .zero, size: s)
            if s.width / s.height > aspect {
                r.size.width = s.height * aspect
                r.origin.x = (s.width - r.width) / 2
            } else {
                r.size.height = s.width / aspect
                r.origin.y = (s.height - r.height) / 2
            }
            if let image { c.draw(Image(decorative: image, scale: 1), in: r) }
            guard let o = overlay else { return }
            func p(_ q: ImpactOverlay.Point) -> CGPoint {
                CGPoint(x: r.minX + CGFloat(q.x) * r.width, y: r.minY + CGFloat(q.y) * r.height)
            }
            for linje in [o.shoulders, o.hips] where linje.count == 2 {
                var path = Path()
                path.move(to: p(linje[0]))
                path.addLine(to: p(linje[1]))
                c.stroke(path, with: .color(Theme.text), lineWidth: 1.5)
            }
            let radie: CGFloat = 3
            if let v = o.leftWrist {
                let q = p(v)
                c.fill(Path(ellipseIn: CGRect(x: q.x - radie, y: q.y - radie, width: 2 * radie, height: 2 * radie)),
                       with: .color(Theme.text))
            }
            if let h = o.rightWrist {
                let q = p(h)
                c.stroke(Path(ellipseIn: CGRect(x: q.x - radie, y: q.y - radie, width: 2 * radie, height: 2 * radie)),
                         with: .color(Theme.text), lineWidth: 1.2)
            }
        }
        .clipShape(.rect(cornerRadius: 2))
        .accessibilityHidden(true)
    }
}

/// Passen på telefonen i startvyn: dagen, klockslaget och antalet klick. Ett tryck
/// öppnar slagen.
struct PassListSection: View {
    let entries: [PassIndex.Entry]
    var onOpen: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Etikett(text: String(localized: "Sessions"))
                .padding(.bottom, 6)
            ForEach(entries, id: \.id) { e in
                Button { onOpen(e.id) } label: {
                    HStack {
                        Text(verbatim: "\(Tal.dag(e.created)) · \(Self.clock(e.id))")
                        Spacer(minLength: 8)
                        Text(verbatim: "\(e.clicks)")
                            .monospacedDigit()
                            .foregroundStyle(Theme.secondary)
                    }
                }
                .buttonStyle(RowButtonStyle())
            }
        }
    }

    /// "15:30" ur id:t (yyyyMMdd-HHmmss).
    static func clock(_ id: String) -> String {
        let c = Array(id)
        guard c.count >= 13 else { return id }
        return "\(String(c[9...10])):\(String(c[11...12]))"
    }
}
