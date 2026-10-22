import SwiftUI
import Swing

/// Granskningen (skissens skärm 4): vyn FO eller DTL, mätytan, tidslinjen,
/// faserna och slagen. Ingen figur (BESLUT B13, regel 2): en neutral videoyta
/// med bara de uppmätta linjerna och punkterna, som ett mätinstrument.
struct GranskningVy: View {
    let fo: Granskningsvisning
    let dtl: Granskningsvisning
    var tillbaka: () -> Void = {}
    var passet: () -> Void = {}
    @State private var vy: Vy
    @State private var tid: Double?
    @State private var slag: Int?
    @State private var visaForra: Bool

    init(fo: Granskningsvisning, dtl: Granskningsvisning, vy: Vy = .fo, fas: Fas = .topp, visaForra: Bool = false,
         tillbaka: @escaping () -> Void = {}, passet: @escaping () -> Void = {}) {
        self.fo = fo
        self.dtl = dtl
        self.tillbaka = tillbaka
        self.passet = passet
        let g = vy == .fo ? fo : dtl
        _vy = State(initialValue: vy)
        _tid = State(initialValue: g.yta.fastider.first { $0.fas == fas }?.t)
        _slag = State(initialValue: nil)
        _visaForra = State(initialValue: visaForra)
    }

    private var g: Granskningsvisning { vy == .fo ? fo : dtl }
    private var nu: Double { tid ?? g.yta.faser.topp }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Segment(alternativ: ["DTL", "FO"], valt: Binding(
                    get: { vy == .dtl ? 0 : 1 },
                    set: { ny in
                        vy = ny == 0 ? .dtl : .fo
                        tid = nil
                    }))
                HStack {
                    Button(action: tillbaka) {
                        Image(systemName: "chevron.left")
                            .typsnitt(17, .medium)
                            .foregroundStyle(Theme.secondary)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button("Passet", action: passet)
                        .typsnitt(15, .semibold)
                        .foregroundStyle(Theme.text)
                        .buttonStyle(.plain)
                }
            }
            .frame(minHeight: 44)
            .padding(.bottom, 8)

            ZStack(alignment: .topLeading) {
                Matytan(yta: g.yta, forra: visaForra ? g.forra : nil, t: nu)
                    .aspectRatio(350.0 / 400.0, contentMode: .fit)
                VStack(alignment: .leading, spacing: 2) {
                    Etikett(text: "\(g.yta.namn) · ", farg: Theme.secondary, efter: g.yta.tidText(nu))
                    StortTal(varde: Tal.tecken(g.yta.lage(nu)?.matt, decimaler: 1), enhet: "cm",
                             storlek: 30, enhetStorlek: 13)
                }
                .padding(.leading, 14)
                .padding(.top, 12)
            }
            .background(Theme.cam)
            .clipShape(.rect(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.hair, lineWidth: 1))

            Tidslinjen(yta: g.yta, forra: visaForra ? g.forra : nil, t: nu)
                .aspectRatio(350.0 / 70.0, contentMode: .fit)
                .padding(.top, 14)
                // VoiceOver: svep upp och ner för att gå mellan faserna.
                .accessibilityElement()
                .accessibilityLabel("\(g.yta.namn), tidslinje")
                .accessibilityValue("\(g.yta.tidText(nu)), \(Tal.tecken(g.yta.lage(nu)?.matt, decimaler: 1)) cm")
                .accessibilityAdjustableAction { riktning in
                    let faser = g.yta.fastider.map { $0.t }
                    switch riktning {
                    case .increment: tid = faser.first { $0 > nu + 0.001 } ?? g.yta.till
                    case .decrement: tid = faser.last { $0 < nu - 0.001 } ?? g.yta.fran
                    @unknown default: break
                    }
                }
                .overlay {
                    GeometryReader { geo in
                        Color.clear
                            .contentShape(.rect)
                            .gesture(DragGesture(minimumDistance: 0).onChanged { d in
                                let a = min(1, max(0, d.location.x / max(1, geo.size.width)))
                                tid = g.yta.fran + a * (g.yta.till - g.yta.fran)
                            })
                    }
                }

            HStack(spacing: 0) {
                ForEach(g.yta.fastider.indices, id: \.self) { i in
                    let f = g.yta.fastider[i]
                    let vald = abs(f.t - nu) < 0.12
                    Button {
                        tid = f.t
                    } label: {
                        Text(Self.fasnamn(f.fas))
                            .typsnitt(13.5, .medium)
                            .foregroundStyle(vald ? Theme.text : Theme.tertiary)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(vald ? Theme.text : Color.clear).frame(height: 2)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.hair).frame(height: 1) }
            .padding(.top, 10)

            HStack {
                Etikett(text: "Slag")
                Spacer()
                if let d = g.forraDatum {
                    Button {
                        visaForra.toggle()
                    } label: {
                        HStack(spacing: 8) {
                            Circle().stroke(lineWidth: 1.5).frame(width: 10, height: 10)
                            Text(d).typsnitt(13, siffror: true)
                        }
                        .foregroundStyle(visaForra ? Theme.text : Theme.tertiary)
                        .frame(minHeight: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Slagen: medianen först. Raden rullar i appen; här visas de som får plats.
            HStack(spacing: 6) {
                ForEach(Array(g.slag.prefix(6).enumerated()), id: \.offset) { _, s in
                    let vald = s.nr == slag
                    Button {
                        slag = s.nr
                    } label: {
                        VStack(spacing: 2) {
                            Text(s.nr.map { "\($0)" } ?? "median")
                                .typsnitt(11, .semibold)
                                .foregroundStyle(Theme.tertiary)
                            Text(s.text)
                                .typsnitt(14, .medium, siffror: true)
                                .foregroundStyle(Theme.text)
                        }
                        .padding(.horizontal, 8)
                        .frame(minWidth: 52, minHeight: 52)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(vald ? Theme.text : Theme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        }
        .padding(.horizontal, 20)
        .background(Theme.ground)
    }

    static func fasnamn(_ f: Fas) -> String {
        switch f {
        case .adress: return "Adress"
        case .topp: return "Topp"
        case .traff: return "Träff"
        case .finish: return "Finish"
        }
    }
}

/// Mätytan: rutnät på 10 cm, adressens läge som streckad lodlinje, bäckenet nu
/// (FO: höftlinjen, DTL: bålen mot axlarna, adressens bål streckad), avståndet från
/// adressen som ett mått, och förra passet som en ihålig prick.
struct Matytan: View {
    let yta: Matyta
    let forra: Matyta?
    let t: Double

    /// Ytan visar 60 cm i bredd.
    static let bredCm = 60.0

    var body: some View {
        Canvas { c, s in
            let k = s.width / CGFloat(Self.bredCm)
            let o = CGPoint(x: s.width * (yta.vy == .fo ? 0.5 : 0.3), y: s.height * (yta.vy == .fo ? 0.62 : 0.85))
            func p(_ q: Punkt) -> CGPoint { CGPoint(x: o.x + CGFloat(q.x) * k, y: o.y - CGFloat(q.y) * k) }

            c.fill(Path(CGRect(origin: .zero, size: s)), with: .color(Theme.cam))
            let rut = 10 * k
            var gx = o.x.truncatingRemainder(dividingBy: rut)
            while gx < s.width {
                c.linje(CGPoint(x: gx, y: 0), CGPoint(x: gx, y: s.height), Theme.hair)
                gx += rut
            }
            var gy = o.y.truncatingRemainder(dividingBy: rut)
            while gy < s.height {
                c.linje(CGPoint(x: 0, y: gy), CGPoint(x: s.width, y: gy), Theme.hair)
                gy += rut
            }
            // Under avläsningen i hörnet, så att linjen inte går genom talet.
            c.linje(CGPoint(x: o.x, y: 84), CGPoint(x: o.x, y: s.height), Theme.secondary, 1, streckad: [4, 4])

            guard let l = yta.lage(t) else { return }
            if let f = forra, let fl = f.lage(yta.motsvarande(t, i: f)) {
                c.prick(p(fl.backen), 5, Theme.secondary, ihalig: true)
            }
            let m = p(l.backen)
            switch yta.vy {
            case .fo:
                c.linje(p(l.hoftB), p(l.hoftF), Theme.text, 1.6)
                c.prick(p(l.hoftB), 3, Theme.text)
                c.prick(p(l.hoftF), 3, Theme.text)
            case .dtl:
                if let a = yta.lage(.adress) {
                    let bal = Punkt(a.axlar.x - a.backen.x, a.axlar.y - a.backen.y)
                    c.linje(m, p(Punkt(l.backen.x + bal.x, l.backen.y + bal.y)), Theme.tertiary, 1, streckad: [3, 3])
                }
                c.linje(m, p(l.axlar), Theme.text, 1.6)
                c.prick(p(l.axlar), 3, Theme.text)
            }
            // Avståndet från adressen: ett mått med ändstreck under bäckenet.
            let my = m.y + 22
            c.linje(CGPoint(x: o.x, y: my), CGPoint(x: m.x, y: my), Theme.text)
            c.linje(CGPoint(x: o.x, y: my - 5), CGPoint(x: o.x, y: my + 5), Theme.text)
            c.linje(CGPoint(x: m.x, y: my - 5), CGPoint(x: m.x, y: my + 5), Theme.text)
            c.prick(m, 4.5, Theme.text)
        }
        .accessibilityHidden(true)
    }
}

/// Tidslinjen: måttet över hela svingen som en tunn kurva, faserna som streck,
/// nollan som en linje, förra passet streckat och ögonblicket i vitt.
struct Tidslinjen: View {
    let yta: Matyta
    let forra: Matyta?
    let t: Double

    var body: some View {
        Canvas { c, s in
            let x0: CGFloat = 4, x1 = s.width - 4
            let kurva = yta.kurva()
            // Förra passet i linje efter faserna: dess tider förs över till den här svingens.
            let gammal: [(t: Double, v: Double)] = forra.map { f in f.kurva().map { (t: f.motsvarande($0.t, i: yta), v: $0.v) } } ?? []
            let alla = kurva.map { $0.v } + gammal.map { $0.v }
            let lo = min(-6, alla.min() ?? -6), hi = max(8, alla.max() ?? 8)
            func x(_ tc: Double) -> CGFloat { x0 + CGFloat((tc - yta.fran) / (yta.till - yta.fran)) * (x1 - x0) }
            func y(_ v: Double) -> CGFloat { 8 + CGFloat((hi - v) / (hi - lo)) * (s.height - 24) }

            c.linje(CGPoint(x: x0, y: y(0)), CGPoint(x: x1, y: y(0)), Theme.line)
            for f in yta.fastider {
                c.linje(CGPoint(x: x(f.t), y: 4), CGPoint(x: x(f.t), y: s.height - 12), Theme.hair)
            }
            func linje(_ k: [(t: Double, v: Double)]) -> Path {
                var p = Path()
                for (i, q) in k.enumerated() {
                    let pt = CGPoint(x: x(q.t), y: y(q.v))
                    if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
                return p
            }
            if !gammal.isEmpty {
                c.stroke(linje(gammal), with: .color(Theme.tertiary), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            c.stroke(linje(kurva), with: .color(Theme.secondary), lineWidth: 1.3)
            c.etikett("0 cm", CGPoint(x: x0, y: y(0) - 3), ankare: .bottomLeading, storlek: 9.5)
            c.linje(CGPoint(x: x(t), y: 0), CGPoint(x: x(t), y: s.height - 8), Theme.text, 1.5)
            if let l = yta.lage(t) {
                c.prick(CGPoint(x: x(t), y: y(l.matt)), 3.5, Theme.text)
            }
        }
    }
}
