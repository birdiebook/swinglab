import SwiftUI
import Swing
import Capture

/// Läget "Mark club" i granskningen (PLAN S7a, S7c; BESLUT B47, B57, B58, B59; METOD M45),
/// bakifrån och framifrån. Överst står vad nästa tryck gör i klartext ("1 · Tap the grip",
/// "2 · Tap the clubhead") bredvid en skiss av en klubba där punkten lyser; det är märkningens
/// enda instruktionsrad, ett undantag från B13 som bara gäller här (B59). Ytan öppnas inzoomad
/// kring händerna; nyp zoomar, dra panorerar och dubbeltryck växlar mot hela bilden. Punkterna
/// heter 1 och 2, och skaftlinjen dras mellan dem. Appens gissning av greppet är en ihålig punkt
/// "1?". Positionen sparas av sig själv när punkt 2 är satt. Under ytan står positionen i
/// klartext ("P4 · Top of backswing · 3 of 10"), raden med positionerna i märkningens ordning,
/// Undo och Skip. Bakifrån kommer riktpinnen som ett eget valfritt steg före P1. Allt som avgör
/// vad ett tryck blir står i `ClubMarking` (SwingLabKit). Innehållet tar sina värden utifrån,
/// så att provet kan rita det med en stillbild och ett finger på ytan.
struct ClubMarkContent<Surface: View, Loupe: View>: View {
    /// Ytan för ett utsnitt: videon i appen, en stillbild i provet.
    let surface: (CropRect) -> Surface
    /// Glasets yta för ett utsnitt: rutan som stillbild ur filen (toleransen 0).
    let loupe: (CropRect) -> Loupe
    let marking: ClubMarking
    /// "−0.250 s" från träffen.
    let time: String
    /// Appens gissning av greppet (handledernas mitt), i hela bildens pixlar: "1?".
    var ring: KlubbPunkt? = nil
    /// Riktpinnens steg (bara bakifrån, före P1, BESLUT B59) och dess punkter (0–2).
    var stickStep = false
    var stick: [KlubbPunkt] = []
    /// Ett finger på ytan för provets bild (0–1 i det som syns); i appen fingret självt.
    var previewTouch: (u: Double, v: Double)? = nil
    var onTap: (Double, Double) -> Void = { _, _ in }
    var onMove: (ClubMarking.Point, Double, Double) -> Void = { _, _, _ in }
    var onPan: (Double, Double) -> Void = { _, _ in }
    var onZoom: (Double, Double, Double) -> Void = { _, _, _ in }
    var onDoubleTap: () -> Void = {}
    var onStep: (Int) -> Void = { _ in }
    var onUndo: () -> Void = {}
    var onSkip: () -> Void = {}
    var onStickSkip: () -> Void = {}
    /// Seriens riktpinne finns redan: steget öppnat ur menyn, där den kan sättas om eller tas bort.
    var hasStick = false
    var onStickRemove: () -> Void = {}
    var onStickMenu: () -> Void = {}
    /// Menyn som riktig meny; provet ritar bara symbolen (ImageRenderer ritar inte UIKit-menyer,
    /// som `ReviewContent.editable`).
    var editable = true
    var onStickDone: () -> Void = {}
    var onPosition: (String) -> Void = { _ in }
    var onHelp: () -> Void = {}
    var onClose: () -> Void = {}

    /// Fingret: var det började, var det är, och punkten det tog (en flytt). Nollställs när
    /// gesten slutar eller ScrollView tar över den.
    struct Drag: Equatable {
        var start: CGPoint
        var now: CGPoint
        var grabbed: ClubMarking.Point?
    }

    @GestureState private var drag: Drag? = nil
    /// Senaste läget under en panorering och ett nyp, för stegen mellan två uppdateringar.
    @State private var panLast: CGPoint? = nil
    @State private var magnifyLast: CGFloat? = nil
    /// Ett nyp pågår eller har pågått i gesten: draget blir varken panorering eller tryck förrän
    /// alla fingrar släppt (METOD M45).
    @State private var nyper = false
    /// Senaste trycket, för dubbeltrycket.
    @State private var lastTap: (date: Date, at: CGPoint)? = nil

    static var stageHeight: CGFloat { 460 }
    static var loupeSize: CGFloat { 124 }
    /// Två tryck inom så kort tid och så nära varandra är ett dubbeltryck. METOD M45
    static var doubleTapS: Double { 0.3 }
    static var doubleTapPt: CGFloat { 20 }

    /// Vad nästa tryck gör, i klartext (BESLUT B59).
    var instruction: String {
        if stickStep { return String(localized: "Optional: tap both ends of an alignment stick on the ground") }
        if marking.done { return String(localized: "All positions done") }
        switch marking.next {
        case .grip: return String(localized: "1 · Tap the grip")
        case .hosel: return String(localized: "2 · Tap the clubhead")
        case nil: return String(localized: "Drag a point to move it")
        }
    }

    private var sketch: ClubSketch.Focus {
        if stickStep { return .stick }
        switch marking.next {
        case .grip: return marking.done ? .both : .grip
        case .hosel: return .clubhead
        case nil: return .both
        }
    }

    /// Var glaset ska visa: den dragna punktens nya plats, annars fingret (inte under en panorering).
    private func shown(_ size: CGSize) -> (u: Double, v: Double)? {
        guard let d = drag else { return previewTouch }
        let u = Double(d.now.x / max(1, size.width)), v = Double(d.now.y / max(1, size.height))
        let dx = Double(d.now.x - d.start.x), dy = Double(d.now.y - d.start.y)
        guard let g = d.grabbed, let o = punkt(g) else {
            return ClubMarking.isDrag(dx: dx, dy: dy) ? nil : (u, v)
        }
        guard ClubMarking.isDrag(dx: dx, dy: dy) else { return (u, v) }
        let s = marking.surfacePoint(o)
        return (s.u + dx / Double(max(1, size.width)), s.v + dy / Double(max(1, size.height)))
    }

    private func punkt(_ p: ClubMarking.Point) -> KlubbPunkt? { p == .grip ? marking.grip : marking.hosel }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Navrad(titel: String(localized: "Mark club"), hoger: {
                HStack(spacing: 2) {
                    // Riktpinnen sätts om eller tas bort för serien (bara bakifrån, B59).
                    if marking.stickAvailable && !stickStep {
                        if editable {
                            Menu {
                                Button("Alignment stick", action: onStickMenu)
                            } label: {
                                menyEtikett
                            }
                            .accessibilityLabel(Text("Alignment stick"))
                        } else {
                            menyEtikett
                        }
                    }
                    Button(action: onHelp) {
                        Text(verbatim: "?").typsnitt(17, .semibold).foregroundStyle(Theme.text)
                            .frame(minWidth: 44, minHeight: 40)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Guide"))
                    // I riktpinnens steg har steget sitt eget Done; märkningen stängs med pilen.
                    if !stickStep {
                        Button(action: onClose) {
                            Text("Done").typsnitt(15, .semibold).foregroundStyle(Theme.text)
                                .frame(minWidth: 44, minHeight: 40)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }, tillbaka: onClose)

            // Instruktionen: skissen och vad nästa tryck gör (BESLUT B59). VoiceOver läser texten.
            HStack(spacing: 12) {
                ClubSketch(focus: sketch).frame(width: 34, height: 48)
                Text(instruction)
                    .typsnitt(17, .semibold)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 10)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(instruction))
            .accessibilityAddTraits(.isHeader)

            stage

            HStack(spacing: 2) {
                symbol("backward.frame.fill", "Previous frame") { onStep(-1) }
                symbol("forward.frame.fill", "Next frame") { onStep(1) }
                Spacer(minLength: 8)
                if !stickStep, let rad = marking.positionLine {
                    Text(verbatim: rad)
                        .typsnitt(13.5, .medium, siffror: true)
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel(Text(verbatim: rad))
                }
            }
            .padding(.top, 8)

            if !stickStep { strip.padding(.top, 6) }

            HStack(spacing: 12) {
                if stickStep {
                    Button(action: hasStick ? onStickRemove : onStickSkip) {
                        Text(hasStick ? LocalizedStringKey("Remove") : LocalizedStringKey("Skip"))
                            .typsnitt(16, .medium).foregroundStyle(Theme.text).frame(minWidth: 64, minHeight: 52)
                    }
                    .buttonStyle(.plain)
                    Button("Done", action: onStickDone)
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(stick.count < 2)
                } else {
                    Button(action: onUndo) {
                        Text("Undo").typsnitt(16, .medium).foregroundStyle(marking.canUndo ? Theme.text : Theme.tertiary)
                            .frame(minWidth: 64, minHeight: 52)
                    }
                    .buttonStyle(.plain)
                    .disabled(!marking.canUndo)
                    Spacer(minLength: 8)
                    // På en markerad position går knappen vidare utan att ändra den (Next); annars
                    // hoppas positionen över (Skip). B59
                    Button(action: onSkip) {
                        Text(marking.isMarked ? LocalizedStringKey("Next") : LocalizedStringKey("Skip"))
                            .typsnitt(16, .medium)
                            .foregroundStyle(marking.done ? Theme.tertiary : Theme.text)
                            .frame(minWidth: 64, minHeight: 52)
                    }
                    .buttonStyle(.plain)
                    .disabled(marking.done)
                }
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 20)
    }

    /// Ytan: det som syns av bilden (`marking.zoom`), punkterna, tiden och glaset. Ett tryck
    /// sätter en punkt, ett drag på en punkt flyttar den, ett drag någon annanstans panorerar,
    /// nypet zoomar och ett dubbeltryck växlar mot hela bilden (METOD M45).
    private var stage: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                surface(marking.zoom)
                ClubPoints(marking: marking, ring: !stickStep && marking.next == .grip ? ring : nil,
                           stick: stickStep ? stick : [], stickStep: stickStep)
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
                                     grabbed: stickStep ? nil : marking.grab(u: s.u, v: s.v))
                    } else {
                        state?.now = v.location
                    }
                }
                .onChanged { v in
                    // Panorera när fingret inte tog en punkt och rört sig mer än 4 pt, och aldrig under ett nyp.
                    guard !nyper else { return }
                    let w = Double(geo.size.width), h = Double(geo.size.height)
                    let s = ClubMarking.surface(x: Double(v.startLocation.x), y: Double(v.startLocation.y), width: w, height: h)
                    let dx = Double(v.location.x - v.startLocation.x), dy = Double(v.location.y - v.startLocation.y)
                    guard (stickStep || marking.grab(u: s.u, v: s.v) == nil), ClubMarking.isDrag(dx: dx, dy: dy) else { return }
                    let forra = panLast ?? v.startLocation
                    onPan(Double(v.location.x - forra.x) / w, Double(v.location.y - forra.y) / h)
                    panLast = v.location
                }
                .onEnded { v in
                    let w = Double(geo.size.width), h = Double(geo.size.height)
                    let panorerade = panLast != nil, nypte = nyper
                    panLast = nil
                    magnifyLast = nil
                    nyper = false
                    if nypte { return }
                    let s = ClubMarking.surface(x: Double(v.startLocation.x), y: Double(v.startLocation.y),
                                                width: w, height: h)
                    let e = ClubMarking.surface(x: Double(v.location.x), y: Double(v.location.y), width: w, height: h)
                    let dx = Double(v.location.x - v.startLocation.x), dy = Double(v.location.y - v.startLocation.y)
                    if panorerade { return }
                    // En satt punkt flyttas först när fingret rört sig mer än 4 pt, och behåller
                    // avståndet mellan finger och punkt. METOD M45
                    if !stickStep, let g = marking.grab(u: s.u, v: s.v), ClubMarking.isDrag(dx: dx, dy: dy),
                       let o = punkt(g) {
                        let p = marking.surfacePoint(o)
                        onMove(g, p.u + dx / w, p.v + dy / h)
                        return
                    }
                    let nu = Date()
                    if let l = lastTap, nu.timeIntervalSince(l.date) < Self.doubleTapS,
                       hypot(l.at.x - v.location.x, l.at.y - v.location.y) < Self.doubleTapPt {
                        lastTap = nil
                        onDoubleTap()
                    } else {
                        lastTap = (nu, v.location)
                        onTap(e.u, e.v)
                    }
                })
            .simultaneousGesture(MagnifyGesture()
                .onChanged { v in
                    nyper = true
                    let forra = magnifyLast ?? 1
                    onZoom(Double(v.magnification / forra), Double(v.startAnchor.x), Double(v.startAnchor.y))
                    magnifyLast = v.magnification
                }
                .onEnded { _ in magnifyLast = nil })
            // En gest som avbryts (ScrollView, ett samtal) når aldrig onEnded: nollställ efteråt.
            .onChange(of: drag == nil) { _, slut in
                guard slut else { return }
                DispatchQueue.main.async {
                    panLast = nil
                    magnifyLast = nil
                    nyper = false
                }
            }
        }
        .background(Theme.cam)
        .clipped()
        .aspectRatio(CGFloat(marking.aspect), contentMode: .fit)
        .frame(maxWidth: .infinity)
        .frame(height: Self.stageHeight)
        .accessibilityElement()
        .accessibilityLabel(Text("Frame"))
        .accessibilityHint(Text(instruction))
    }

    private var menyEtikett: some View {
        Image(systemName: "ellipsis").typsnitt(17, .medium).foregroundStyle(Theme.text).frame(width: 40, height: 40)
    }

    /// Positionerna i märkningens ordning (BESLUT B58): markerad vit, hoppad grå med streck, den
    /// som märks understruken; ett tryck går dit.
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
                .accessibilityLabel(Text(verbatim: Texter.positionsnamn[p].map { "\(p), \($0)" } ?? p))
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
        let cx = (marking.zoom.x + t.u * marking.zoom.width - lc.x) / lc.width
        let cy = (marking.zoom.y + t.v * marking.zoom.height - lc.y) / lc.height
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
                if let h = marking.hosel { c.prick(q(h), 3.5, Theme.text) }
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

/// En liten skiss av en klubba, svartvit (BESLUT B59, design/README regel 6): greppet som ett
/// tjockare stycke överst, skaftet och huvudet. Punkten som nästa tryck sätter lyser: 1 mitt på
/// greppet (mitt mellan händerna), 2 där skaftet går in i huvudet. Riktpinnen är en pinne på
/// marken med sina två ändar.
struct ClubSketch: View {
    enum Focus: Equatable { case grip, clubhead, both, stick }
    let focus: Focus

    var body: some View {
        Canvas { c, s in
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s.width, y: y * s.height) }
            let r = max(2.5, s.width * 0.09)
            if focus == .stick {
                // Marken och pinnen på den, i perspektiv, med ändarna.
                c.linje(p(0.02, 0.92), p(0.98, 0.92), Theme.line, 1)
                let a = p(0.22, 0.86), b = p(0.78, 0.40)
                c.linje(a, b, Theme.secondary, max(1.5, s.width * 0.05))
                c.prick(a, r, Theme.text)
                c.prick(b, r, Theme.text)
                return
            }
            let topp = p(0.30, 0.04), greppSlut = p(0.42, 0.34), hosel = p(0.66, 0.80)
            c.linje(topp, greppSlut, Theme.secondary, max(3, s.width * 0.16))
            c.linje(greppSlut, hosel, Theme.secondary, max(1, s.width * 0.04))
            var huvud = Path()
            huvud.move(to: hosel)
            huvud.addLine(to: p(0.98, 0.86))
            huvud.addLine(to: p(0.96, 0.98))
            huvud.addLine(to: p(0.60, 0.95))
            huvud.closeSubpath()
            c.fill(huvud, with: .color(Theme.line))
            c.stroke(huvud, with: .color(Theme.secondary), lineWidth: 1)
            let grepp = p(0.36, 0.19)
            let tand1 = focus == .grip || focus == .both, tand2 = focus == .clubhead || focus == .both
            c.prick(grepp, r, tand1 ? Theme.text : Theme.tertiary, ihalig: !tand1)
            c.prick(hosel, r, tand2 ? Theme.text : Theme.tertiary, ihalig: !tand2)
            // I guidens stora skiss står punkternas nummer, som på ytan.
            if s.width >= 80 {
                for (text, a, tand) in [("1", grepp, tand1), ("2", hosel, tand2)] {
                    c.draw(Text(verbatim: text).font(.system(size: 15, weight: .bold))
                        .foregroundStyle(tand ? Theme.text : Theme.tertiary), at: CGPoint(x: a.x - r - 14, y: a.y))
                }
            }
        }
        .accessibilityHidden(true)
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

/// Punkterna 1 (greppet) och 2 (klubbhuvudet) med skaftlinjen mellan dem när båda är satta,
/// appens gissning av greppet som en ihålig punkt "1?", och riktpinnens ändar (BESLUT B59).
struct ClubPoints: View {
    let marking: ClubMarking
    var ring: KlubbPunkt? = nil
    var stick: [KlubbPunkt] = []
    var stickStep = false

    var body: some View {
        Canvas { c, s in
            func p(_ q: KlubbPunkt) -> CGPoint {
                let l = marking.surfacePoint(q)
                return CGPoint(x: CGFloat(l.u) * s.width, y: CGFloat(l.v) * s.height)
            }
            // Vitt med en svart kant, så att punkterna, linjen och siffrorna syns mot både ljus
            // och mörk bild (svartvitt, design/README regel 6).
            func etikett(_ text: String, vid a: CGPoint) {
                let t = c.resolve(Text(verbatim: text).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text))
                let sz = t.measure(in: CGSize(width: 100, height: 40))
                let mitt = CGPoint(x: a.x + 9 + sz.width / 2, y: a.y - 13)
                let ruta = CGRect(x: mitt.x - sz.width / 2 - 4, y: mitt.y - sz.height / 2 - 1, width: sz.width + 8,
                                  height: sz.height + 2)
                c.fill(Path(roundedRect: ruta, cornerRadius: 3), with: .color(Theme.ground.opacity(0.75)))
                c.draw(t, at: mitt)
            }
            func linje(_ a: CGPoint, _ b: CGPoint) {
                c.linje(a, b, Theme.ground.opacity(0.6), 3.2)
                c.linje(a, b, Theme.text, 1.4)
            }
            func punkt(_ a: CGPoint) {
                c.prick(a, 5.5, Theme.ground)
                c.prick(a, 4, Theme.text)
            }
            if stick.count == 2 { linje(p(stick[0]), p(stick[1])) }
            for (i, q) in stick.enumerated() {
                punkt(p(q))
                etikett("\(i + 1)", vid: p(q))
            }
            if stickStep { return }
            if let r = ring {
                // Gissningen: en ihålig ring, så att händerna syns genom den.
                let m = p(r)
                let ruta = CGRect(x: m.x - 8, y: m.y - 8, width: 16, height: 16)
                c.stroke(Path(ellipseIn: ruta), with: .color(Theme.ground.opacity(0.6)), lineWidth: 3.5)
                c.stroke(Path(ellipseIn: ruta), with: .color(Theme.text), lineWidth: 1.5)
                etikett("1?", vid: m)
            }
            if let g = marking.grip, let h = marking.hosel { linje(p(g), p(h)) }
            if let g = marking.grip {
                punkt(p(g))
                etikett("1", vid: p(g))
            }
            if let h = marking.hosel {
                punkt(p(h))
                etikett("2", vid: p(h))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Guiden första gången (BESLUT B59): tre bilder, greppet, klubbhuvudet och klart (skaftlinjen,
/// och att appen går vidare själv). Öppnas igen med "?".
struct ClubGuideContent: View {
    let page: Int
    var onNext: () -> Void = {}
    var onClose: () -> Void = {}

    static let pages = 3

    private var titel: String {
        switch page {
        case 0: return String(localized: "1 · Tap the grip")
        case 1: return String(localized: "2 · Tap the clubhead")
        default: return String(localized: "The next position opens automatically.")
        }
    }

    private var rad: String {
        switch page {
        case 0: return String(localized: "On the shaft, between the hands. Or tap 1? to use the app's guess.")
        case 1: return String(localized: "Where the shaft goes into the head.")
        default: return String(localized: "The shaft line is drawn. Pinch to zoom, double-tap for the whole picture, and Skip when the club is not visible.")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Navrad(titel: String(localized: "Mark club"), hoger: {
                Button(action: onClose) {
                    Text("Done").typsnitt(15, .semibold).foregroundStyle(Theme.text).frame(minWidth: 44, minHeight: 40)
                }
                .buttonStyle(.plain)
            }, tillbaka: onClose)
            Spacer(minLength: 24)
            ZStack {
                ClubSketch(focus: page == 0 ? .grip : page == 1 ? .clubhead : .both)
                    .frame(width: 150, height: 210)
                if page == 2 { GuideLine().frame(width: 150, height: 210) }
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 24)
            VStack(alignment: .leading, spacing: 8) {
                Text(titel).typsnitt(22, .semibold).foregroundStyle(Theme.text)
                Text(rad).typsnitt(15).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            HStack(spacing: 6) {
                ForEach(0..<Self.pages, id: \.self) { i in
                    Circle().fill(i == page ? Theme.text : Theme.line).frame(width: 6, height: 6)
                }
            }
            .padding(.top, 20)
            .accessibilityHidden(true)
            Button(page + 1 < Self.pages ? LocalizedStringKey("Next") : LocalizedStringKey("Start"),
                   action: page + 1 < Self.pages ? onNext : onClose)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 20)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}

/// Skaftlinjen i guidens sista bild: linjen mellan punkterna 1 och 2, som på ytan.
private struct GuideLine: View {
    var body: some View {
        Canvas { c, s in
            let a = CGPoint(x: 0.36 * s.width, y: 0.19 * s.height), b = CGPoint(x: 0.66 * s.width, y: 0.80 * s.height)
            c.linje(a, b, Theme.text, 1.5)
        }
        .accessibilityHidden(true)
    }
}

/// Skaftet som är markerat i granskningens ruta: en tunn linje mellan greppet och klubbhuvudet (B13).
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
