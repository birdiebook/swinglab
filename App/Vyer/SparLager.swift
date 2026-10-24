import SwiftUI
import Swing
import Capture

/// Det som spårlagret ritar (PLAN S4f, BESLUT B70): punktserierna i hela bildens pixlar med
/// tider, räknade en gång till ytans koordinater (0–1 i utsnittet, samma avbildning som lederna,
/// `ShotReview.yta`) och delade i delar. Byggs när valet eller slaget ändras, inte per ruta.
struct SparBild: Equatable {
    let serier: [SparSerie]
    /// Ytans punkter per serie (0–1), samma index som seriens.
    let yta: [[Punkt]]
    /// Seriens delar (avbrotten), utan hänsyn till tiden.
    let delar: [[SparSerie.Del]]
    /// P1-skaftets linje bakifrån (S7b, METOD M47), greppet och hoseln i ytans koordinater:
    /// klubbhuvudets bana ses mot den förlängda linjen. nil = ingen.
    let plan: [Punkt]?

    init(serier: [SparSerie], bredd: Int, hojd: Int, crop: CropRect, plan: (grepp: Punkt, hosel: Punkt)? = nil) {
        self.serier = serier
        yta = serier.map { s in
            s.p.map { q -> Punkt in
                guard q.hel else { return .saknad }
                let l = ShotReview.yta(x: q.x, y: q.y, bredd: bredd, hojd: hojd, crop: crop)
                return Punkt(l.x, l.y)
            }
        }
        delar = serier.map { $0.delar() }
        self.plan = plan.map { p in
            [p.grepp, p.hosel].map { q in
                let l = ShotReview.yta(x: q.x, y: q.y, bredd: bredd, hojd: hojd, crop: crop)
                return Punkt(l.x, l.y)
            }
        }
    }
}

/// Spårlagret (PLAN S4f, BESLUT B70, METOD M60): en tunn linje per serie, svartvitt med
/// gråton och linjestil per punkt (B13), ingen accent (B31: ett spår är inget mått), och en
/// mörk kant under varje linje så att den syns mot en ljus bakgrund. Hela banan ritas svagt en
/// gång (oberoende av rutan), och det som spelats upp ritas fast ovanpå, så att banans form syns
/// från första rutan och det spelade växer med videon. Klubbhuvudets interpolerade rutor (S7b)
/// är streckade. Punktens läge i rutan är en liten prick.
struct SparLager: View {
    let bild: SparBild
    /// s relativt klicket: det som är spelat (t ≤ nu) ritas fast.
    let nu: Double

    /// Svagt för det som inte spelats än. METOD M60
    static let kvarOpacitet = 0.30
    /// Den mörka kanten under linjen: opaciteten och hur mycket bredare den är, pt.
    static let kantOpacitet = 0.5, kantBredd: CGFloat = 1.5

    /// Stilen per punkt: färg, bredd och streck (B13: gråtoner och linjestil). Strecken har
    /// raka ändar och längre glapp än en osäker leds linje (streck 3, mellanrum 3): huvudet korta
    /// streck, höfterna långa. Klubbhuvudet är bredast och har en ring där det är i rutan, så att
    /// det skiljer sig från händernas linje med prick.
    static func stil(_ p: SparPunkt) -> (farg: Color, bredd: CGFloat, streck: [CGFloat]) {
        switch p {
        case .hands: return (Theme.text, 1.5, [])
        case .shoulders: return (Theme.secondary, 1.2, [])
        case .hips: return (Theme.secondary, 1.2, [8, 5])
        case .head: return (Theme.text, 1.4, [2, 5])
        case .club: return (Theme.text, 2.4, [])
        }
    }

    /// Klubbhuvudets interpolerade rutor (S7b): streck med glapp.
    static let interpoleradStreck: [CGFloat] = [4, 6]

    var body: some View {
        ZStack {
            SparBas(bild: bild).equatable()
            SparSpelat(bild: bild, nu: nu)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// En del som linje i ytan, med strecken räknade från seriens start (båglängden, så att
    /// strecken inte kryper när rutan byts).
    static func rita(_ c: GraphicsContext, _ s: CGSize, yta: [Punkt], del: SparSerie.Del, langd: [CGFloat],
                     stil st: (farg: Color, bredd: CGFloat, streck: [CGFloat]), opacitet: Double) {
        func p(_ q: Punkt) -> CGPoint { CGPoint(x: CGFloat(q.x) * s.width, y: CGFloat(q.y) * s.height) }
        var path = Path()
        path.move(to: p(yta[del.start]))
        for i in (del.start + 1)...del.slut { path.addLine(to: p(yta[i])) }
        let streck = del.interpolerad ? interpoleradStreck : st.streck
        let anden: CGLineCap = streck.isEmpty ? .round : .butt
        let fas = langd.indices.contains(del.start) ? langd[del.start] : 0
        c.stroke(path, with: .color(.black.opacity(kantOpacitet * opacitet)),
                 style: StrokeStyle(lineWidth: st.bredd + kantBredd, lineCap: anden, lineJoin: .round,
                                    dash: streck, dashPhase: fas))
        c.stroke(path, with: .color(st.farg.opacity(opacitet)),
                 style: StrokeStyle(lineWidth: st.bredd, lineCap: anden, lineJoin: .round, dash: streck, dashPhase: fas))
    }

    /// Klubbhuvudets ring: vit, med den mörka kanten utanför och innanför.
    static func ring(_ c: GraphicsContext, _ m: CGPoint, r: CGFloat = 4.5) {
        let ruta = CGRect(x: m.x - r, y: m.y - r, width: 2 * r, height: 2 * r)
        c.stroke(Path(ellipseIn: ruta), with: .color(.black.opacity(kantOpacitet)), lineWidth: 3.2)
        c.stroke(Path(ellipseIn: ruta), with: .color(Theme.text), lineWidth: 1.6)
    }

    /// Båglängden i ytan från seriens start till varje punkt, pt (avbrott räknas inte).
    static func langd(_ yta: [Punkt], _ s: CGSize) -> [CGFloat] {
        var ut = [CGFloat](repeating: 0, count: yta.count)
        var acc: CGFloat = 0
        for i in yta.indices {
            if i > 0, yta[i].hel, yta[i - 1].hel {
                let dx = CGFloat(yta[i].x - yta[i - 1].x) * s.width, dy = CGFloat(yta[i].y - yta[i - 1].y) * s.height
                acc += (dx * dx + dy * dy).squareRoot()
            }
            ut[i] = acc
        }
        return ut
    }
}

/// Hela banan svagt; ritas om bara när bilden ändras.
private struct SparBas: View, Equatable {
    let bild: SparBild

    var body: some View {
        Canvas { c, s in
            if let plan = bild.plan, plan.count == 2 {
                // Linjen genom P1:s grepp och hosel, långt åt båda hållen (ytan klipper).
                let a = CGPoint(x: CGFloat(plan[0].x) * s.width, y: CGFloat(plan[0].y) * s.height)
                let b = CGPoint(x: CGFloat(plan[1].x) * s.width, y: CGFloat(plan[1].y) * s.height)
                let dx = b.x - a.x, dy = b.y - a.y, n = max(1, (dx * dx + dy * dy).squareRoot())
                let k = 4 * max(s.width, s.height) / n
                c.linje(CGPoint(x: a.x - dx * k, y: a.y - dy * k), CGPoint(x: b.x + dx * k, y: b.y + dy * k),
                        Theme.secondary, 1, streckad: [4, 4])
                // Etiketten vid P1:s grepp, som ligger inne i bilden: linjen är P1-planet (M47).
                c.draw(Text("P1 plane").font(.system(size: 10, weight: .medium)).foregroundColor(Theme.secondary),
                       at: CGPoint(x: a.x + 6, y: a.y), anchor: .leading)
            }
            for (i, serie) in bild.serier.enumerated() {
                let st = SparLager.stil(serie.punkt), langd = SparLager.langd(bild.yta[i], s)
                for d in bild.delar[i] {
                    SparLager.rita(c, s, yta: bild.yta[i], del: d, langd: langd, stil: st, opacitet: SparLager.kvarOpacitet)
                }
            }
        }
    }
}

/// Det spelade fast ovanpå, och punkten i rutan.
private struct SparSpelat: View {
    let bild: SparBild
    let nu: Double

    var body: some View {
        Canvas { c, s in
            for (i, serie) in bild.serier.enumerated() {
                let st = SparLager.stil(serie.punkt), langd = SparLager.langd(bild.yta[i], s)
                let k = serie.grans(nu: nu)
                for d in SparSerie.spelade(bild.delar[i], till: k) {
                    SparLager.rita(c, s, yta: bild.yta[i], del: d, langd: langd, stil: st, opacitet: 1)
                }
                if let k, bild.yta[i][k].hel {
                    let q = bild.yta[i][k]
                    let m = CGPoint(x: CGFloat(q.x) * s.width, y: CGFloat(q.y) * s.height)
                    if serie.punkt == .club {
                        SparLager.ring(c, m)
                    } else {
                        c.prick(m, 2.8, .black.opacity(SparLager.kantOpacitet))
                        c.prick(m, 2.2, st.farg)
                    }
                }
            }
        }
    }
}

/// Club-chipets läge (S7b, BESLUT B71).
enum KlubbChip: Equatable {
    /// Inga två markerade grannpositioner: chipet visas inte.
    case dold
    /// Går att slå på (räknas då).
    case mojlig
    /// Räknas just nu.
    case raknar
    /// Påslaget, men banan är inte räknad för det här slaget: ett tryck räknar den.
    case ejRaknad
    /// Räknad: så många av rutorna är interpolerade.
    case klar(interpolerade: Int, av: Int)
}

/// Valet av spår (PLAN S4f, BESLUT B70): ett chip per punkt, ett tryck slår på eller av. Ett
/// påslaget chip visar sin linje (gråton och streck) och fungerar som teckenförklaring; ett
/// avslaget är grått. "Club" visas först när klubbhuvudets bana kan räknas (S7b, B71): en ring
/// medan den räknas, en streckad kant när den inte är räknad för slaget, och linjen med ringen
/// när den är klar.
struct SparVal: View {
    let valda: Set<SparPunkt>
    var klubba: KlubbChip = .dold
    var onToggle: (SparPunkt) -> Void = { _ in }

    static func namn(_ p: SparPunkt) -> String {
        switch p {
        case .hands: return String(localized: "Hands")
        case .shoulders: return String(localized: "Shoulders")
        case .hips: return String(localized: "Hips")
        case .head: return String(localized: "Head")
        case .club: return String(localized: "Club")
        }
    }

    /// VoiceOver: "Hands trail" osv.
    static func upplasning(_ p: SparPunkt) -> String {
        switch p {
        case .hands: return String(localized: "Hands trail")
        case .shoulders: return String(localized: "Shoulders trail")
        case .hips: return String(localized: "Hips trail")
        case .head: return String(localized: "Head trail")
        case .club: return String(localized: "Club trail")
        }
    }

    /// VoiceOver: Club-chipets läge (räknas, inte räknad, andelen interpolerade).
    static func varde(_ k: KlubbChip) -> String? {
        switch k {
        case .raknar: return String(localized: "Computing")
        case .ejRaknad: return String(localized: "Not computed, double-tap to compute")
        case let .klar(i, n): return String(localized: "\(i) of \(n) frames interpolated")
        default: return nil
        }
    }

    private var punkter: [SparPunkt] { SparPunkt.allCases.filter { $0 != .club || klubba != .dold } }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Theme.tertiary)
                .accessibilityHidden(true)
            ForEach(punkter, id: \.self) { p in chip(p) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Trails"))
    }

    private func chip(_ p: SparPunkt) -> some View {
        let pa = valda.contains(p)
        let st = SparLager.stil(p)
        let ejRaknad = p == .club && pa && klubba == .ejRaknad
        return Button {
            onToggle(p)
        } label: {
            HStack(spacing: 4) {
                if pa {
                    if p == .club && klubba == .raknar {
                        ProgressView().controlSize(.mini).tint(Theme.secondary)
                    } else if !ejRaknad {
                        Canvas { c, s in
                            var path = Path()
                            path.move(to: CGPoint(x: 0, y: s.height / 2))
                            path.addLine(to: CGPoint(x: p == .club ? s.width - 4 : s.width, y: s.height / 2))
                            c.stroke(path, with: .color(st.farg),
                                     style: StrokeStyle(lineWidth: st.bredd, lineCap: st.streck.isEmpty ? .round : .butt,
                                                        dash: st.streck))
                            if p == .club { SparLager.ring(c, CGPoint(x: s.width - 3, y: s.height / 2), r: 2.6) }
                        }
                        .frame(width: p == .club ? 14 : 10, height: 8)
                    }
                }
                Text(verbatim: Self.namn(p))
                    .typsnitt(12, .medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(pa ? Theme.text : Theme.tertiary)
            .padding(.horizontal, 7)
            .frame(height: 28)
            .overlay(RoundedRectangle(cornerRadius: 3)
                .stroke(pa ? Theme.secondary : Theme.line, style: StrokeStyle(lineWidth: 1, dash: ejRaknad ? [3, 3] : [])))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: Self.upplasning(p)))
        .accessibilityValue(Text(verbatim: p == .club ? (Self.varde(klubba) ?? "") : ""))
        .accessibilityAddTraits(pa ? [.isToggle, .isSelected] : [.isToggle])
    }
}
