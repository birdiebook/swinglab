import SwiftUI
import Swing
import Capture
import TreD

// Figuren i 3D (PLAN S6d, BESLUT B72, B73, METOD MK10, MK11): kedjans triangulerade leder som en
// figur av streck och leder, vit på svart (B13: ett mätinstrument, ingen modellerad kropp), med en
// tunn markyta och mållinjen, att vrida med ett finger och nypa, de färdiga vinklarna Face on,
// Down the line och Top, uppspelningen i takt med svingen med P1–P10 som i granskningen, spåren
// i 3D (S4f:s val och linjestilar, ingen accent, B31) och telefonerna där kalibreringen placerade
// dem. Ritas med Canvas och en egen projektion (B73), så att simulatorprovet kan rita den.

/// Skärmen: läser bara det slag som visas (och avbryter läsningen när slaget byts), spelar upp
/// och håller vinkeln. Passets figur kommer som index; slagen ur passets mapp.
struct TreDFigurSkarm: View {
    let passID: String
    let index: TreDFigurIndex
    /// Slagens nummer i passet (som listan): slagets id på den här telefonen → nummer.
    let nummer: [String: Int]
    let vy: Vy
    var onClose: () -> Void

    @Environment(Store.self) private var store
    @State private var valt = 0
    @State private var figur: TreDFigur?
    @State private var laddar = false
    @State private var nu = 0.0
    @State private var spelar = false
    @State private var fart = 0
    @State private var vinkel = TreDVinkel.faceOn
    @State private var betraktare: TreDBetraktare?
    @State private var kameror = false
    @State private var spar: [TreDSpar] = []
    /// Riktningarna ur slagets figur (eller kamerorna), räknade en gång per slag.
    @State private var riktning: TreDRiktning?
    /// Vyn som fingret lämnade per vinkel, så att den står kvar när vinkeln väljs igen (per slag).
    @State private var sparad: [TreDVinkel: TreDBetraktare] = [:]
    /// Fingret vrider figuren: sidan rullar inte under tiden.
    @State private var dragar = false

    private var post: TreDFigurIndex.Post? { index.slag.indices.contains(valt) ? index.slag[valt] : nil }
    /// Slagets uppställning; utan slag den första som har kameror.
    private var uppstallning: TreDFigurUppstallning? {
        if let i = post?.uppstallning, index.uppstallningar.indices.contains(i) { return index.uppstallningar[i] }
        return index.uppstallningar.first { $0.kameror != nil }
    }
    private var rubrik: String {
        guard let post else { return Texter.treD }
        let id = vy == .dtl ? post.dtl : post.fo
        return String(localized: "Shot \(nummer[id] ?? valt + 1)")
    }
    /// Utan figur visas telefonerna (det är det som finns att se).
    private var visaKameror: Bool { kameror || index.slag.isEmpty }

    var body: some View {
        ScrollView {
            innehall
                .padding(.vertical, 8)
        }
        .scrollDisabled(dragar)
        .background(Theme.ground, ignoresSafeAreaEdges: .all)
        .preferredColorScheme(.dark)
        .task(id: valt) { await ladda() }
        .task(id: spelar) { await spelaUpp() }
    }

    private var innehall: TreDFigurInnehall {
        var v = TreDFigurInnehall(index: index, figur: figur, uppstallning: uppstallning, riktning: riktning,
                                  betraktare: betraktare, rubrik: rubrik, nu: nu)
        v.spelar = spelar
        v.fart = fart
        v.vinkel = vinkel
        v.kameror = visaKameror
        v.spar = spar
        v.sparVal = store.settings.sparVal
        v.laddar = laddar
        v.forra = valt > 0
        v.nasta = valt + 1 < index.slag.count
        v.onClose = onClose
        v.onSlag = byt
        v.onSpela = spela
        v.onRuta = tillRuta
        v.onPosition = tillPosition
        v.onFart = { fart = $0 }
        v.onVinkel = valjVinkel
        v.onKameror = vaxlaKameror
        v.onSpar = vaxlaSpar
        v.onBetraktare = { b in
            betraktare = b
            sparad[vinkel] = b
        }
        v.onDragar = { dragar = $0 }
        v.onAterstall = aterstall
        return v
    }

    private func byt(_ steg: Int) {
        spelar = false
        valt = min(max(0, valt + steg), max(0, index.slag.count - 1))
    }

    private func tillRuta(_ k: Int) {
        spelar = false
        if let f = figur { nu = f.t(k) }
    }

    private func tillPosition(_ name: String) {
        spelar = false
        guard let f = figur, let k = f.positionsRutor().first(where: { $0.name == name })?.index else { return }
        nu = f.t(k)
    }

    private func valjVinkel(_ v: TreDVinkel) {
        vinkel = v
        if let b = sparad[v] { betraktare = b } else { forinstallning() }
    }

    /// Dubbeltryck: vinkeln som den var från början.
    private func aterstall() {
        sparad[vinkel] = nil
        forinstallning()
    }

    private func vaxlaKameror() {
        kameror.toggle()
        sparad = [:]
        forinstallning()
    }

    private func vaxlaSpar(_ p: SparPunkt) {
        store.toggleTrail(p)
        bygSpar()
    }

    /// Slaget som visas, utanför huvudtråden; avbryts när slaget byts (`task(id:)`).
    private func ladda() async {
        guard let post else {
            figur = nil
            riktning = nil
            forinstallning()
            return
        }
        laddar = true
        let folder = store.passFolder(passID), fil = post.fil
        let t = Task.detached(priority: .userInitiated) { Store.lasFigur(folder, fil: fil) }
        let f = await withTaskCancellationHandler { await t.value } onCancel: { t.cancel() }
        guard !Task.isCancelled else { return }
        laddar = false
        figur = f
        sparad = [:]
        riktning = uppstallning.flatMap { TreDRiktning.ur(f, uppstallning: $0, hand: index.hand) }
        if let f {
            let p1 = f.positionsRutor().first(where: { $0.name == "P1" })?.index
            nu = p1.map { f.t($0) } ?? f.t0
        } else {
            nu = 0
        }
        bygSpar()
        forinstallning()
    }

    private func bygSpar() {
        spar = figur.map { TreDSpar.spar($0, val: Array(store.settings.sparVal)) } ?? []
    }

    private func forinstallning() {
        if riktning == nil { riktning = uppstallning.flatMap { TreDRiktning.ur(figur, uppstallning: $0, hand: index.hand) } }
        guard let r = riktning else {
            betraktare = nil
            return
        }
        let c = visaKameror ? (uppstallning?.kameror?.values.map(\.c) ?? []) : []
        betraktare = TreDBetraktare.vinkel(vinkel, r, kameror: c)
    }

    /// Spelar från rutan, eller från början när den står vid slutet (som granskningen, MS15).
    private func spela() {
        guard let f = figur else { return }
        if !spelar && nu >= f.tSista - f.steg / 2 { nu = f.t0 }
        spelar.toggle()
    }

    private func spelaUpp() async {
        guard spelar, let f = figur else { return }
        var forra = ContinuousClock.now
        while spelar, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(16))
            let n = ContinuousClock.now
            let d = (n - forra).components
            forra = n
            // 1/8 som granskningen (240 bilder/s som 30, MS15), 1/4 och verklig tid; läst varje
            // steg, så att farten kan bytas medan den spelar.
            let takt = [0.125, 0.25, 1.0][min(max(0, fart), 2)]
            let dt: Double = Double(d.seconds) + Double(d.attoseconds) * 1e-18
            nu += dt * takt
            if nu >= f.tSista {
                nu = f.tSista
                spelar = false
            }
        }
    }
}

/// Skärmens innehåll som värden (ingen ScrollView och ingen UIKit-del), så att provet kan rita
/// den med ImageRenderer.
struct TreDFigurInnehall: View {
    let index: TreDFigurIndex
    let figur: TreDFigur?
    let uppstallning: TreDFigurUppstallning?
    let riktning: TreDRiktning?
    let betraktare: TreDBetraktare?
    let rubrik: String
    let nu: Double
    var spelar = false
    var fart = 0
    var vinkel = TreDVinkel.faceOn
    var kameror = false
    var spar: [TreDSpar] = []
    var sparVal: Set<SparPunkt> = []
    var laddar = false
    var forra = false
    var nasta = false
    var onClose: () -> Void = {}
    var onSlag: (Int) -> Void = { _ in }
    var onSpela: () -> Void = {}
    var onRuta: (Int) -> Void = { _ in }
    var onPosition: (String) -> Void = { _ in }
    var onFart: (Int) -> Void = { _ in }
    var onVinkel: (TreDVinkel) -> Void = { _ in }
    var onKameror: () -> Void = {}
    var onSpar: (SparPunkt) -> Void = { _ in }
    var onBetraktare: (TreDBetraktare) -> Void = { _ in }
    /// Fingret börjar och slutar vrida (sidan rullar inte under tiden).
    var onDragar: (Bool) -> Void = { _ in }
    /// Dubbeltryck på ytan: vinkeln som från början.
    var onAterstall: () -> Void = {}

    @State private var dragFran: CGSize = .zero
    @State private var zoomFran: Double?

    static var stageHeight: CGFloat { ReviewContent<EmptyView>.stageHeight }

    private var ruta: Int { figur?.ruta(nu) ?? 0 }
    private var positioner: [(name: String, index: Int?)] {
        figur?.positionsRutor() ?? Klubba.positioner.map { (name: $0, index: nil) }
    }
    private var position: String {
        positioner.first { $0.index == ruta }?.name ?? ""
    }

    /// Skälen i grått: varför figuren saknas, eller varför den är osäkrare (METOD MS19).
    private var skal: [String] {
        var ut: [String] = []
        if let h = index.hoppat {
            ut.append(uppstallning?.overSparren == true ? Texter.treDOverSparren : TreDKort.hoppat(h))
        } else if uppstallning?.overSparren == true {
            ut.append(Texter.treDOverSparren)
        }
        if uppstallning?.vinkelOk == false { ut.append(Texter.treDVinkel) }
        if !index.slag.isEmpty && figur == nil && !laddar { ut.append(Texter.treDIngenFigur) }
        return ut
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Navrad(titel: rubrik, hoger: {
                if !index.slag.isEmpty {
                    HStack(spacing: 0) {
                        pil("chevron.up", "Previous shot", aktiv: forra) { onSlag(-1) }
                        pil("chevron.down", "Next shot", aktiv: nasta) { onSlag(1) }
                    }
                }
            }, tillbaka: onClose)

            stage
                .frame(maxWidth: .infinity)
                .frame(height: Self.stageHeight)

            if let figur {
                HStack(spacing: 2) {
                    symbol("backward.frame.fill", "Previous frame") { onRuta(max(0, ruta - 1)) }
                    symbol(spelar ? "pause.fill" : "play.fill",
                           spelar ? LocalizedStringKey("Pause") : LocalizedStringKey("Play"), onSpela)
                    symbol("forward.frame.fill", "Next frame") { onRuta(min(figur.n - 1, ruta + 1)) }
                    ReviewTimeline(count: figur.n, frame: ruta,
                                   ticks: positioner.compactMap { p in p.index.map { (index: $0, selected: p.name == position) } },
                                   onScrub: onRuta)
                        .frame(height: 34)
                        .padding(.leading, 8)
                }
                .padding(.top, 8)
            }

            Segment(alternativ: [Texter.treDFaceOn, Texter.treDDtl, Texter.treDTop], valt: Binding(
                get: { TreDVinkel.allCases.firstIndex(of: vinkel) ?? 0 },
                set: { onVinkel(TreDVinkel.allCases[$0]) }))
                .padding(.top, 10)

            HStack(spacing: 8) {
                if figur != nil {
                    Segment(alternativ: Texter.treDFarter, valt: Binding(get: { fart }, set: { onFart($0) }))
                }
                Spacer(minLength: 0)
                if uppstallning?.kameror != nil && !index.slag.isEmpty {
                    Chip(text: Texter.treDKameror, vald: kameror, action: onKameror)
                }
            }
            .padding(.top, 8)

            if figur != nil {
                SparVal(valda: sparVal.subtracting([.club]), klubba: .dold, onToggle: onSpar)
                    .padding(.top, 8)
                HStack(spacing: 0) {
                    ForEach(positioner.indices, id: \.self) { i in
                        positionKnapp(positioner[i].name, available: positioner[i].index != nil)
                    }
                }
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.hair).frame(height: 1) }
                .padding(.top, 8)
            }

            if kameror, let u = uppstallning, u.kameror != nil {
                VStack(spacing: 0) {
                    // Kamerorna stämmer (✓) eller inte (✗); Sampson-felet i px litet under (PLAN S4h,
                    // BESLUT B94, METOD MK3).
                    talrad(Texter.treDSampson, u.sampsonPx.map { $0 <= TvaKameror.sampsonMaxPx ? Texter.bock : Texter.kryss },
                           under: Texter.treDKameraFel(u.sampsonPx.map { Tal.medEnhet(Tal.tal($0, decimaler: 1), "px") },
                                                       Tal.axel(TvaKameror.sampsonMaxPx, decimaler: 1)))
                    talrad(Texter.treDVinkelMellan, u.vinkel.map { Tal.medEnhet(Tal.tal($0, decimaler: 0), "°") },
                           under: Texter.treDVinkelSpann)
                }
                .padding(.top, 8)
            }

            ForEach(skal, id: \.self) { s in
                Text(verbatim: s)
                    .typsnitt(13)
                    .foregroundStyle(Theme.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: ytan

    private var stage: some View {
        ZStack(alignment: .topTrailing) {
            Theme.cam
            if let betraktare, let riktning {
                TreDScen(betraktare: betraktare, riktning: riktning, figur: figur, nu: nu, spar: spar,
                         kameror: kameror ? uppstallning?.kameror : nil)
            }
            if laddar {
                ProgressView().tint(Theme.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if betraktare == nil, let s = skal.first {
                Text(verbatim: s)
                    .typsnitt(13)
                    .foregroundStyle(Theme.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let figur {
                Text(verbatim: Tal.tecken(figur.t(ruta), decimaler: 3) + " s")
                    .typsnitt(11, .medium, siffror: true)
                    .foregroundStyle(Theme.secondary)
                    .padding(8)
            }
        }
        .clipShape(.rect(cornerRadius: 2))
        .contentShape(.rect)
        .highPriorityGesture(
            DragGesture(minimumDistance: 2)
                .onChanged { d in
                    if dragFran == .zero { onDragar(true) }
                    guard let b = betraktare else { return }
                    let dx = d.translation.width - dragFran.width, dy = d.translation.height - dragFran.height
                    dragFran = d.translation
                    onBetraktare(b.vriden(dx: dx, dy: dy))
                }
                .onEnded { _ in
                    dragFran = .zero
                    onDragar(false)
                }
                .simultaneously(with: MagnifyGesture()
                    .onChanged { m in
                        guard let b = betraktare else { return }
                        let fran = zoomFran ?? b.avstand
                        zoomFran = fran
                        onBetraktare(b.zoomad(m.magnification, fran: fran))
                    }
                    .onEnded { _ in zoomFran = nil })
        )
        .onTapGesture(count: 2) { onAterstall() }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: Texter.treD))
        .accessibilityValue(Text(verbatim: tillganglig))
        .accessibilityAdjustableAction { steg in
            guard let figur else { return }
            switch steg {
            case .increment: onRuta(min(figur.n - 1, ruta + 1))
            case .decrement: onRuta(max(0, ruta - 1))
            @unknown default: break
            }
        }
    }

    /// VoiceOver: vinkeln, positionen och tiden ("Face on, P4, −0.275 s").
    private var tillganglig: String {
        var delar = [vinkelNamn(vinkel)]
        if !position.isEmpty { delar.append(position) }
        if let figur { delar.append(Tal.tecken(figur.t(ruta), decimaler: 3) + " s") }
        return delar.joined(separator: ", ")
    }

    private func vinkelNamn(_ v: TreDVinkel) -> String {
        switch v {
        case .faceOn: return Texter.treDFaceOn
        case .dtl: return Texter.treDDtl
        case .top: return Texter.treDTop
        }
    }

    // MARK: delarna

    private func pil(_ namn: String, _ label: LocalizedStringKey, aktiv: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: namn)
                .typsnitt(17, .medium)
                .foregroundStyle(aktiv ? Theme.secondary : Theme.line)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .disabled(!aktiv)
        .accessibilityLabel(Text(label))
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

    private func positionKnapp(_ name: String, available: Bool) -> some View {
        let vald = name == position
        return Button {
            onPosition(name)
        } label: {
            VStack(spacing: 1) {
                Text(verbatim: name)
                    .typsnitt(13.5, .semibold, siffror: true)
                Text(verbatim: ReviewContent<EmptyView>.label(name) ?? " ")
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

    /// Ett tal med sin gräns under, som granskningens rader (namn, tal och enhet, spannet).
    private func talrad(_ namn: String, _ varde: String?, under: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: namn)
                    .typsnitt(14)
                    .foregroundStyle(Theme.secondary)
                Text(verbatim: under)
                    .typsnitt(11, .semibold)
                    .foregroundStyle(Theme.tertiary)
            }
            Spacer(minLength: 8)
            Text(verbatim: varde ?? "—")
                .typsnitt(17, .medium, siffror: true)
                .foregroundStyle(varde == nil ? Theme.tertiary : Theme.text)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .top) { Rectangle().fill(Theme.hair).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }
}

/// Scenen: marken, mållinjen, spåren, telefonerna och figuren i rutan som visas. Vänster sida
/// vit och fylld, höger grå och ihålig (som miniatyren vid träffen), och det som är längre bort
/// svagare, så att djupet syns utan ytor. METOD MK11
struct TreDScen: View {
    let betraktare: TreDBetraktare
    let riktning: TreDRiktning
    let figur: TreDFigur?
    let nu: Double
    var spar: [TreDSpar] = []
    /// Telefonerna ("fo", "dtl"), nil = visas inte.
    var kameror: [String: TreDFigurKamera]? = nil

    /// Markens rutnät: steget och hur långt det når från stansen, m.
    static let rutSteg = 0.5, rutUt = 2.0
    /// Telefonens pyramid: djupet i världen, m.
    static let pyramid = 0.35

    var body: some View {
        Canvas { ctx, s in
            let c = ctx
            let pr = TreDProjektion(betraktare, bredd: Double(s.width), hojd: Double(s.height))
            func cg(_ p: Punkt) -> CGPoint { CGPoint(x: p.x, y: p.y) }
            func linje(_ a: [Double], _ b: [Double], _ farg: Color, _ bredd: CGFloat, streck: [CGFloat] = []) {
                guard let l = pr.linje(a, b) else { return }
                c.linje(cg(l.0), cg(l.1), farg, bredd, streckad: streck)
            }
            let r = riktning, g = r.golv
            // Marken: ett tunt rutnät kring stansen (längre ut när telefonerna visas).
            let e = r.meter, steg = Self.rutSteg * e
            var ut = Self.rutUt * e
            for k in (kameror ?? [:]).values {
                let dx: Double = k.c[0] - r.stans[0], dy: Double = k.c[1] - r.stans[1]
                let d: Double = (dx * dx + dy * dy).squareRoot()
                ut = max(ut, d + 0.5 * e)
            }
            let n = min(40, Int((ut / steg).rounded(.up)))
            let u = r.mal, v = r.fram
            func mark(_ a: Double, _ b: Double) -> [Double] {
                let x: Double = r.stans[0] + a * u[0] + b * v[0]
                let y: Double = r.stans[1] + a * u[1] + b * v[1]
                return [x, y, g]
            }
            for i in -n...n {
                let a = Double(i) * steg, ytter = Double(n) * steg
                linje(mark(a, -ytter), mark(a, ytter), Theme.line, 0.6)
                linje(mark(-ytter, a), mark(ytter, a), Theme.line, 0.6)
            }
            // Mållinjen genom stansen, med en pil mot målet; bara ur en figur (ingen gissning).
            if r.urFigur {
                let fram = TreDRiktning.malFram * e
                let spets = mark(fram, 0)
                linje(mark(-TreDRiktning.malBak * e, 0), spets, Theme.secondary, 1, streck: [5, 4])
                linje(spets, mark(fram - 0.18 * e, 0.1 * e), Theme.secondary, 1)
                linje(spets, mark(fram - 0.18 * e, -0.1 * e), Theme.secondary, 1)
            }

            if let kameror { ritaKameror(c, pr, kameror, yta: s) }
            guard let f = figur else { return }
            let k = f.ruta(nu)
            ritaSpar(c, pr, f)
            // Figuren: djupet i rutan ger opaciteten (det bortre svagare).
            var djup: [Double] = []
            for j in 0..<TreDFigur.antalLeder { if let p = f.led(k, j), let q = pr.punkt(p) { djup.append(q.djup) } }
            let dmin = djup.min() ?? 0, dmax = djup.max() ?? 1
            func opacitet(_ d: Double) -> Double {
                guard dmax - dmin >= 0.05 else { return 1 }
                let a: Double = (d - dmin) / (dmax - dmin)
                return 1 - 0.45 * a
            }
            func ledDjup(_ j: Int) -> Double {
                guard let p = f.led(k, j), let q = pr.punkt(p) else { return 0 }
                return q.djup
            }
            // Det bortre först, så att det närmare ritas ovanpå.
            let streck = TreDStreck.ben.sorted { a, b in
                max(ledDjup(a.a), ledDjup(a.b)) > max(ledDjup(b.a), ledDjup(b.b))
            }
            // Halsen: axlarnas mitt till näsan, så att huvudet sitter på figuren.
            if let v = f.led(k, 1), let h = f.led(k, 2), let n = f.led(k, 0) {
                let m: [Double] = [(v[0] + h[0]) / 2, (v[1] + h[1]) / 2, (v[2] + h[2]) / 2]
                if let l = pr.linje(m, n) {
                    let d = max(pr.punkt(m)?.djup ?? dmax, pr.punkt(n)?.djup ?? dmax)
                    c.linje(cg(l.0), cg(l.1), Theme.text.opacity(opacitet(d)), 2)
                }
            }
            for b in streck {
                guard let pa = f.led(k, b.a), let pb = f.led(k, b.b), let l = pr.linje(pa, pb) else { continue }
                let d = max(pr.punkt(pa)?.djup ?? dmax, pr.punkt(pb)?.djup ?? dmax)
                let farg = b.sida == .hoger ? Theme.secondary : Theme.text
                c.linje(cg(l.0), cg(l.1), farg.opacity(opacitet(d)), 2)
            }
            for j in 0..<TreDFigur.antalLeder {
                guard let p = f.led(k, j), let q = pr.punkt(p) else { continue }
                let o = opacitet(q.djup)
                switch TreDStreck.sida(j) {
                case .mitt: c.prick(cg(q.p), 4.5, Theme.text.opacity(o))
                case .vanster: c.prick(cg(q.p), 3, Theme.text.opacity(o))
                case .hoger: c.prick(cg(q.p), 3, Theme.secondary.opacity(o), ihalig: true)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Spåren: hela banan svagt och det spelade fast (S4f:s delning och linjestilar, B70).
    private func ritaSpar(_ c: GraphicsContext, _ pr: TreDProjektion, _ f: TreDFigur) {
        for s in spar {
            let st = SparLager.stil(s.serie.punkt)
            let delar = s.serie.delar()
            let k = s.serie.grans(nu: nu)
            for (del, opacitet) in delar.map({ ($0, SparLager.kvarOpacitet) }) + SparSerie.spelade(delar, till: k).map({ ($0, 1.0) }) {
                var path = Path()
                var ny = true
                for i in del.start...del.slut {
                    guard let q = pr.punkt(s.punkt(i)) else {
                        ny = true
                        continue
                    }
                    if ny { path.move(to: CGPoint(x: q.p.x, y: q.p.y)) } else { path.addLine(to: CGPoint(x: q.p.x, y: q.p.y)) }
                    ny = false
                }
                c.stroke(path, with: .color(st.farg.opacity(opacitet)),
                         style: StrokeStyle(lineWidth: st.bredd, lineCap: st.streck.isEmpty ? .round : .butt,
                                            lineJoin: .round, dash: st.streck))
            }
            if let k, let q = pr.punkt(s.punkt(k)) { c.prick(CGPoint(x: q.p.x, y: q.p.y), 2.2, st.farg) }
        }
    }

    /// Telefonerna: en pyramid ur K och R med bildens överkant markerad, en streckad linje mot
    /// spelaren och vyns namn.
    private func ritaKameror(_ c: GraphicsContext, _ pr: TreDProjektion, _ kameror: [String: TreDFigurKamera],
                             yta: CGSize) {
        func linje(_ a: [Double], _ b: [Double], _ farg: Color, _ bredd: CGFloat, _ streck: [CGFloat]) {
            guard let l = pr.linje(a, b) else { return }
            c.linje(CGPoint(x: l.0.x, y: l.0.y), CGPoint(x: l.1.x, y: l.1.y), farg, bredd, streckad: streck)
        }
        for vy in ["fo", "dtl"] {
            guard let k = kameror[vy] else { continue }
            let f = k.k[0], cx = k.k[2], cy = k.k[5], s = Self.pyramid * riktning.meter
            func hornet(_ u: Double, _ v: Double) -> [Double] {
                let a: Double = (u - cx) / f, b: Double = (v - cy) / f
                var ut = [Double](repeating: 0, count: 3)
                for i in 0..<3 {
                    let riktning: Double = k.fram[i] + a * k.hoger[i] + b * k.ned[i]
                    ut[i] = k.c[i] + s * riktning
                }
                return ut
            }
            let h = [hornet(0, 0), hornet(Double(k.w), 0), hornet(Double(k.w), Double(k.h)), hornet(0, Double(k.h))]
            for i in 0..<4 {
                linje(k.c, h[i], Theme.text, 1, [])
                linje(h[i], h[(i + 1) % 4], Theme.text, 1, [])
            }
            // Bildens överkant: en kort pinne uppåt i bilden.
            var ovan = [Double](repeating: 0, count: 3), pinne = ovan
            for i in 0..<3 {
                ovan[i] = (h[0][i] + h[1][i]) / 2
                pinne[i] = ovan[i] - s * 0.4 * k.ned[i]
            }
            linje(ovan, pinne, Theme.text, 1.5, [])
            linje(k.c, [riktning.stans[0], riktning.stans[1], riktning.golv + riktning.meter], Theme.tertiary, 0.8, [3, 4])
            // Namnet utanför telefonen, på andra sidan från spelaren, så att det inte täcker pyramiden.
            if let q = pr.punkt(k.c) {
                var dx = 0.0, dy = -1.0
                if let m = pr.punkt([riktning.stans[0], riktning.stans[1], riktning.golv + riktning.meter]) {
                    let ex: Double = q.p.x - m.p.x, ey: Double = q.p.y - m.p.y
                    let n = (ex * ex + ey * ey).squareRoot()
                    if n > 1 { (dx, dy) = (ex / n, ey / n) }
                }
                c.draw(Text(verbatim: Texter.treDTelefon(vy.uppercased()))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.secondary),
                       at: CGPoint(x: min(max(q.p.x + 34 * dx, 44), Double(yta.width) - 44),
                                   y: min(max(q.p.y + 26 * dy, 12), Double(yta.height) - 12)), anchor: .center)
            }
        }
    }
}
