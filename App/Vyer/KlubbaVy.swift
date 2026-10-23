import SwiftUI
import Swing
import Capture

/// Läget "Mark club" i granskningen (PLAN S7a, BESLUT B47, METOD M45), DTL först: rutan för
/// positionen, ett tryck på greppet och sedan på hoseln med förstoringsglaset under fingret,
/// flytta en punkt genom att dra den, ångra, hoppa över en position där klubban inte syns,
/// och P1–P10 i ordning. B13: svartvitt, bara punkterna och linjen mellan dem; raden under
/// ytan säger vilken punkt nästa tryck sätter. Allt som avgör vad ett tryck blir står i
/// `ClubMarking` (SwingLabKit). Innehållet tar sina värden utifrån, så att provet kan rita
/// det med en stillbild och ett finger på ytan.
struct ClubMarkContent<Surface: View>: View {
    /// Ytan för ett utsnitt: videon i appen, en stillbild i provet. Samma yta ritas i glaset.
    let surface: (CropRect) -> Surface
    let marking: ClubMarking
    /// "−0.250 s" från träffen.
    let time: String
    /// Fingret på ytan (0–1 i utsnittet): glaset visas där.
    var touch: (u: Double, v: Double)? = nil
    var onTouch: (Double, Double) -> Void = { _, _ in }
    var onRelease: (Double, Double) -> Void = { _, _ in }
    var onStep: (Int) -> Void = { _ in }
    var onUndo: () -> Void = {}
    var onSkip: () -> Void = {}
    var onNext: () -> Void = {}
    var onPosition: (String) -> Void = { _ in }
    var onClose: () -> Void = {}

    static var stageHeight: CGFloat { 460 }
    static var loupeSize: CGFloat { 124 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Navrad(titel: String(localized: "Mark club"), hoger: {
                Button(action: onClose) {
                    Text("Done").typsnitt(15, .semibold).foregroundStyle(Theme.text).frame(minWidth: 44, minHeight: 40)
                }
                .buttonStyle(.plain)
            }, tillbaka: onClose)

            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    surface(marking.crop)
                    ClubPoints(marking: marking)
                    if !time.isEmpty {
                        Text(verbatim: time)
                            .typsnitt(11, .medium, siffror: true)
                            .foregroundStyle(Theme.secondary)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    if let t = touch { loupe(t, size: geo.size) }
                }
                .contentShape(.rect)
                .gesture(DragGesture(minimumDistance: 0).onChanged { d in
                    onTouch(Double(d.location.x / max(1, geo.size.width)), Double(d.location.y / max(1, geo.size.height)))
                }.onEnded { d in
                    onRelease(Double(d.location.x / max(1, geo.size.width)), Double(d.location.y / max(1, geo.size.height)))
                })
            }
            .background(Theme.cam)
            .clipped()
            .aspectRatio(CGFloat(marking.aspect), contentMode: .fit)
            .frame(maxWidth: .infinity)
            .frame(height: Self.stageHeight)
            .accessibilityElement()
            .accessibilityLabel(Text("Frame"))

            HStack(spacing: 2) {
                symbol("backward.frame.fill", "Previous frame") { onStep(-1) }
                symbol("forward.frame.fill", "Next frame") { onStep(1) }
                Spacer(minLength: 8)
                Text(verbatim: marking.done ? "" : marking.position)
                    .typsnitt(15, .semibold, siffror: true)
                    .foregroundStyle(Theme.text)
                if let n = marking.next, !marking.done {
                    Text(n == .grip ? LocalizedStringKey("Grip") : LocalizedStringKey("Hosel"))
                        .typsnitt(13, .medium)
                        .foregroundStyle(Theme.secondary)
                        .padding(.leading, 6)
                }
                Spacer(minLength: 8)
                Button(action: onSkip) {
                    Text("Not visible").typsnitt(14, .medium).foregroundStyle(Theme.secondary).frame(minHeight: 40)
                }
                .buttonStyle(.plain)
                .disabled(marking.done)
            }
            .padding(.top, 8)

            strip.padding(.top, 6)

            HStack(spacing: 12) {
                Button(action: onUndo) {
                    Text("Undo").typsnitt(16, .medium).foregroundStyle(marking.canUndo ? Theme.text : Theme.tertiary)
                        .frame(minWidth: 72, minHeight: 52)
                }
                .buttonStyle(.plain)
                .disabled(!marking.canUndo)
                Button(marking.done ? LocalizedStringKey("Done") : LocalizedStringKey("Next"), action: marking.done ? onClose : onNext)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!marking.done && marking.next != nil)
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 20)
    }

    /// P1–P10: markerad vit, hoppad grå med streck, den som märks understruken; ett tryck går dit.
    private var strip: some View {
        HStack(spacing: 0) {
            ForEach(ClubMarking.order, id: \.self) { p in
                let m = marking.marks[p]
                let nu = !marking.done && p == marking.position
                Button { onPosition(p) } label: {
                    Text(verbatim: p)
                        .typsnitt(12.5, .semibold, siffror: true)
                        .strikethrough(m?.hoppad == true)
                        .foregroundStyle(nu || m?.markerad == true ? Theme.text : Theme.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(nu ? Theme.text : Color.clear).frame(height: 2)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hair).frame(height: 1) }
    }

    /// Glaset: ytan förstorad kring fingret med ett hårkors där fingret är och de satta
    /// punkterna, bredvid fingret där det inte täcker en satt punkt. METOD M45
    private func loupe(_ t: (u: Double, v: Double), size: CGSize) -> some View {
        let s = Self.loupeSize
        let lc = marking.loupeCrop(u: t.u, v: t.v)
        let cx = (marking.crop.x + t.u * marking.crop.width - lc.x) / lc.width
        let cy = (marking.crop.y + t.v * marking.crop.height - lc.y) / lc.height
        let fx = CGFloat(t.u) * size.width, fy = CGFloat(t.v) * size.height
        // Ovanför fingret, annars under, till vänster eller höger: där glaset ryms och inte
        // täcker en satt punkt (greppet ligger ofta rakt ovanför hoseln).
        let satta = [marking.grip, marking.hosel].compactMap { $0 }.map { k -> CGPoint in
            let l = marking.surfacePoint(k)
            return CGPoint(x: CGFloat(l.u) * size.width, y: CGFloat(l.v) * size.height)
        }
        let kandidater = [CGPoint(x: fx - s / 2, y: fy - s - 40), CGPoint(x: fx - s / 2, y: fy + 40),
                          CGPoint(x: fx - s - 40, y: fy - s / 2), CGPoint(x: fx + 40, y: fy - s / 2)]
        func ryms(_ o: CGPoint) -> Bool { o.x >= 0 && o.y >= 0 && o.x + s <= size.width && o.y + s <= size.height }
        func tacker(_ o: CGPoint) -> Bool {
            satta.contains { CGRect(x: o.x - 8, y: o.y - 8, width: s + 16, height: s + 16).contains($0) }
        }
        let vald = kandidater.first { ryms($0) && !tacker($0) } ?? kandidater.first(where: ryms) ?? kandidater[0]
        let x = min(max(0, vald.x), max(0, size.width - s)), y = min(max(0, vald.y), max(0, size.height - s))
        return ZStack {
            surface(lc)
            Canvas { c, z in
                // De satta punkterna och linjen syns också i glaset, förstorade.
                func q(_ k: KlubbPunkt) -> CGPoint {
                    CGPoint(x: CGFloat((k.x / Double(marking.width) - lc.x) / lc.width) * z.width,
                            y: CGFloat((k.y / Double(marking.height) - lc.y) / lc.height) * z.height)
                }
                if let g = marking.grip, let h = marking.hosel { c.linje(q(g), q(h), Theme.text, 1.2) }
                if let g = marking.grip { c.prick(q(g), 3.5, Theme.text) }
                if let h = marking.hosel { c.prick(q(h), 4.5, Theme.text, ihalig: true) }
                let p = CGPoint(x: CGFloat(cx) * z.width, y: CGFloat(cy) * z.height)
                c.linje(CGPoint(x: p.x - 14, y: p.y), CGPoint(x: p.x - 4, y: p.y), Theme.text, 1)
                c.linje(CGPoint(x: p.x + 4, y: p.y), CGPoint(x: p.x + 14, y: p.y), Theme.text, 1)
                c.linje(CGPoint(x: p.x, y: p.y - 14), CGPoint(x: p.x, y: p.y - 4), Theme.text, 1)
                c.linje(CGPoint(x: p.x, y: p.y + 4), CGPoint(x: p.x, y: p.y + 14), Theme.text, 1)
            }
        }
        .frame(width: s, height: s)
        .clipShape(Circle())
        .overlay(Circle().stroke(Theme.text, lineWidth: 1))
        .offset(x: x, y: y)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func symbol(_ name: String, _ label: LocalizedStringKey, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Theme.text)
                .frame(width: 44, height: 40)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

/// Punkterna som är satta på positionen: greppet fyllt, hoseln ihålig, och en tunn linje mellan dem.
struct ClubPoints: View {
    let marking: ClubMarking

    var body: some View {
        Canvas { c, s in
            func p(_ q: KlubbPunkt) -> CGPoint {
                let l = marking.surfacePoint(q)
                return CGPoint(x: CGFloat(l.u) * s.width, y: CGFloat(l.v) * s.height)
            }
            if let g = marking.grip, let h = marking.hosel { c.linje(p(g), p(h), Theme.text, 1.2) }
            if let g = marking.grip { c.prick(p(g), 3.5, Theme.text) }
            if let h = marking.hosel { c.prick(p(h), 4.5, Theme.text, ihalig: true) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Skaftet som är markerat i granskningens ruta: en tunn linje mellan greppet och hoseln (B13).
struct ShaftOverlay: View {
    let shaft: (grip: (x: Double, y: Double), hosel: (x: Double, y: Double))?

    var body: some View {
        Canvas { c, s in
            guard let sh = shaft else { return }
            let a = CGPoint(x: CGFloat(sh.grip.x) * s.width, y: CGFloat(sh.grip.y) * s.height)
            let b = CGPoint(x: CGFloat(sh.hosel.x) * s.width, y: CGFloat(sh.hosel.y) * s.height)
            c.linje(a, b, Theme.text, 1.2)
            c.prick(b, 2.6, Theme.text, ihalig: true)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
