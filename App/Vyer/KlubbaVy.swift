import SwiftUI
import Swing
import Capture

/// Läget "Mark club" i granskningen (PLAN S7a, BESLUT B47, METOD M45), DTL först: rutan för
/// positionen, ett tryck på greppet (eller på ringen ur handlederna) och sedan på hoseln, och
/// positionen sparas av sig själv; förstoringsglaset under fingret, en punkt flyttas genom att
/// dra den mer än 4 pt, ångra, hoppa över en position där klubban inte syns, och P1–P10 i
/// ordning. Riktpinnen (valfri, en gång per serie) sätts med två tryck. B13: svartvitt, bara
/// punkterna och linjen mellan dem. Allt som avgör vad ett tryck blir står i `ClubMarking`
/// (SwingLabKit). Innehållet tar sina värden utifrån, så att provet kan rita det med en
/// stillbild och ett finger på ytan.
struct ClubMarkContent<Surface: View, Loupe: View>: View {
    /// Ytan för ett utsnitt: videon i appen, en stillbild i provet.
    let surface: (CropRect) -> Surface
    /// Glasets yta för ett utsnitt: rutan som stillbild ur filen (toleransen 0).
    let loupe: (CropRect) -> Loupe
    let marking: ClubMarking
    /// "−0.250 s" från träffen.
    let time: String
    /// Ringen ur handlederna i rutan (förslaget till greppet), i hela bildens pixlar.
    var ring: KlubbPunkt? = nil
    /// Riktpinnens punkter (0–2) och om nästa tryck sätter den.
    var stick: [KlubbPunkt] = []
    var stickMode = false
    /// Ett finger på ytan för provets bild (0–1 i utsnittet); i appen fingret självt.
    var previewTouch: (u: Double, v: Double)? = nil
    var onTap: (Double, Double) -> Void = { _, _ in }
    var onMove: (ClubMarking.Point, Double, Double) -> Void = { _, _, _ in }
    var onStep: (Int) -> Void = { _ in }
    var onUndo: () -> Void = {}
    var onSkip: () -> Void = {}
    var onNext: () -> Void = {}
    var onStick: () -> Void = {}
    var onPosition: (String) -> Void = { _ in }
    var onClose: () -> Void = {}

    /// Fingret: var det började, var det är, och punkten det tog (en flytt). Nollställs när
    /// gesten slutar eller ScrollView tar över den.
    struct Drag: Equatable {
        var start: CGPoint
        var now: CGPoint
        var grabbed: ClubMarking.Point?
    }

    @GestureState private var drag: Drag? = nil

    static var stageHeight: CGFloat { 460 }
    static var loupeSize: CGFloat { 124 }

    /// Var glaset ska visa: den dragna punktens nya plats, annars fingret.
    private func shown(_ size: CGSize) -> (u: Double, v: Double)? {
        guard let d = drag else { return previewTouch }
        let u = Double(d.now.x / max(1, size.width)), v = Double(d.now.y / max(1, size.height))
        guard let g = d.grabbed, let o = punkt(g) else { return (u, v) }
        let dx = Double(d.now.x - d.start.x), dy = Double(d.now.y - d.start.y)
        guard ClubMarking.isDrag(dx: dx, dy: dy) else { return (u, v) }
        let s = marking.surfacePoint(o)
        return (s.u + dx / Double(max(1, size.width)), s.v + dy / Double(max(1, size.height)))
    }

    private func punkt(_ p: ClubMarking.Point) -> KlubbPunkt? { p == .grip ? marking.grip : marking.hosel }

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
                    ClubPoints(marking: marking, ring: marking.next == .grip && !stickMode ? ring : nil, stick: stick)
                    if !time.isEmpty {
                        Text(verbatim: time)
                            .typsnitt(11, .medium, siffror: true)
                            .foregroundStyle(Theme.secondary)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    if let t = shown(geo.size) { loupeView(t, size: geo.size) }
                }
                .contentShape(.rect)
                .gesture(DragGesture(minimumDistance: 0)
                    .updating($drag) { v, state, _ in
                        if state == nil {
                            let s = ClubMarking.surface(x: Double(v.startLocation.x), y: Double(v.startLocation.y),
                                                        width: Double(geo.size.width), height: Double(geo.size.height))
                            state = Drag(start: v.startLocation, now: v.location,
                                         grabbed: stickMode ? nil : marking.grab(u: s.u, v: s.v))
                        } else {
                            state?.now = v.location
                        }
                    }
                    .onEnded { v in
                        let w = Double(geo.size.width), h = Double(geo.size.height)
                        let s = ClubMarking.surface(x: Double(v.startLocation.x), y: Double(v.startLocation.y),
                                                    width: w, height: h)
                        let e = ClubMarking.surface(x: Double(v.location.x), y: Double(v.location.y), width: w, height: h)
                        let dx = Double(v.location.x - v.startLocation.x), dy = Double(v.location.y - v.startLocation.y)
                        // En satt punkt flyttas först när fingret rört sig mer än 4 pt, och behåller
                        // avståndet mellan finger och punkt. METOD M45
                        if !stickMode, let g = marking.grab(u: s.u, v: s.v), ClubMarking.isDrag(dx: dx, dy: dy),
                           let o = punkt(g) {
                            let p = marking.surfacePoint(o)
                            onMove(g, p.u + dx / w, p.v + dy / h)
                        } else {
                            onTap(e.u, e.v)
                        }
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
                if stickMode {
                    Text("Stick").typsnitt(13, .medium).foregroundStyle(Theme.secondary).padding(.leading, 6)
                } else if let n = marking.next, !marking.done {
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
                .disabled(marking.done || stickMode)
            }
            .padding(.top, 8)

            strip.padding(.top, 6)

            HStack(spacing: 12) {
                Button(action: onUndo) {
                    Text("Undo").typsnitt(16, .medium).foregroundStyle(marking.canUndo ? Theme.text : Theme.tertiary)
                        .frame(minWidth: 64, minHeight: 52)
                }
                .buttonStyle(.plain)
                .disabled(!marking.canUndo)
                Button(action: onStick) {
                    Text("Stick").typsnitt(16, .medium)
                        .foregroundStyle(stickMode || stick.count == 2 ? Theme.text : Theme.secondary)
                        .frame(minWidth: 56, minHeight: 52)
                }
                .buttonStyle(.plain)
                Button(marking.done ? LocalizedStringKey("Done") : LocalizedStringKey("Next"),
                       action: marking.done ? onClose : onNext)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!marking.done && (marking.grip == nil || marking.hosel == nil))
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
                .accessibilityLabel(Text(verbatim: p))
                .accessibilityValue(nu ? Text("current") : m?.hoppad == true ? Text("skipped")
                                    : m?.markerad == true ? Text("marked") : Text(verbatim: ""))
                .accessibilityAddTraits(nu ? .isSelected : [])
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hair).frame(height: 1) }
    }

    /// Glaset: rutan förstorad 3 × i punkter kring fingret, med hårkorset och de satta
    /// punkterna, bredvid fingret där det inte täcker fingret eller en satt punkt. METOD M45, M46
    private func loupeView(_ t: (u: Double, v: Double), size: CGSize) -> some View {
        let s = Self.loupeSize
        let lc = marking.loupeCrop(u: t.u, v: t.v, surfaceWidthPt: Double(size.width), loupePt: Double(s))
        let cx = (marking.crop.x + t.u * marking.crop.width - lc.x) / lc.width
        let cy = (marking.crop.y + t.v * marking.crop.height - lc.y) / lc.height
        let fx = CGFloat(t.u) * size.width, fy = CGFloat(t.v) * size.height
        let satta = [marking.grip, marking.hosel].compactMap { $0 }.map { k -> CGPoint in
            let l = marking.surfacePoint(k)
            return CGPoint(x: CGFloat(l.u) * size.width, y: CGFloat(l.v) * size.height)
        }
        let kandidater = [CGPoint(x: fx - s / 2, y: fy - s - 40), CGPoint(x: fx - s / 2, y: fy + 40),
                          CGPoint(x: fx - s - 40, y: fy - s / 2), CGPoint(x: fx + 40, y: fy - s / 2)]
        func inom(_ o: CGPoint) -> CGPoint {
            CGPoint(x: min(max(0, o.x), max(0, size.width - s)), y: min(max(0, o.y), max(0, size.height - s)))
        }
        func tacker(_ o: CGPoint) -> Bool {
            let r = CGRect(x: o.x - 8, y: o.y - 8, width: s + 16, height: s + 16)
            return (satta + [CGPoint(x: fx, y: fy)]).contains { r.contains($0) }
        }
        let vald = kandidater.map(inom).first { !tacker($0) } ?? inom(kandidater[0])
        return ZStack {
            loupe(lc)
            Canvas { c, z in
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
        .offset(x: vald.x, y: vald.y)
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

/// Glasets yta: rutan som stillbild, skuren till glasets utsnitt; svart innan den lästs.
struct LoupeImage: View {
    let image: CGImage?
    let crop: CropRect

    var body: some View {
        if let image {
            Image(decorative: ShotImages.cropped(image, crop), scale: 1).resizable().interpolation(.none)
        } else {
            Color.black
        }
    }
}

/// Punkterna som är satta på positionen (greppet fyllt, hoseln ihålig, en tunn linje mellan
/// dem), ringen ur handlederna som förslag till greppet (streckad), och riktpinnen.
struct ClubPoints: View {
    let marking: ClubMarking
    var ring: KlubbPunkt? = nil
    var stick: [KlubbPunkt] = []

    var body: some View {
        Canvas { c, s in
            func p(_ q: KlubbPunkt) -> CGPoint {
                let l = marking.surfacePoint(q)
                return CGPoint(x: CGFloat(l.u) * s.width, y: CGFloat(l.v) * s.height)
            }
            if stick.count == 2 { c.linje(p(stick[0]), p(stick[1]), Theme.secondary, 1, streckad: [4, 4]) }
            for q in stick { c.prick(p(q), 2.5, Theme.secondary) }
            if let r = ring {
                let m = p(r), radie = CGFloat(ClubMarking.grabRadius) * s.width
                c.stroke(Path(ellipseIn: CGRect(x: m.x - radie, y: m.y - radie, width: 2 * radie, height: 2 * radie)),
                         with: .color(Theme.text), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
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
