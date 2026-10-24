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

    init(serier: [SparSerie], bredd: Int, hojd: Int, crop: CropRect) {
        self.serier = serier
        yta = serier.map { s in
            s.p.map { q -> Punkt in
                guard q.hel else { return .saknad }
                let l = ShotReview.yta(x: q.x, y: q.y, bredd: bredd, hojd: hojd, crop: crop)
                return Punkt(l.x, l.y)
            }
        }
        delar = serier.map { $0.delar() }
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

    /// Stilen per punkt: färg, bredd och streck (B13: gråtoner och linjestil). Huvudet är
    /// prickat (runda prickar) och höfterna långa streck, så att ingen liknar en osäker leds
    /// linje (streck 3, mellanrum 3).
    static func stil(_ p: SparPunkt) -> (farg: Color, bredd: CGFloat, streck: [CGFloat]) {
        switch p {
        case .hands: return (Theme.text, 1.6, [])
        case .shoulders: return (Theme.secondary, 1.2, [])
        case .hips: return (Theme.secondary, 1.2, [8, 3])
        case .head: return (Theme.text, 1.4, [0.01, 3.2])
        case .club: return (Theme.text, 2.0, [])
        }
    }

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
        let streck = del.interpolerad ? [2, 4] : st.streck
        let fas = langd.indices.contains(del.start) ? langd[del.start] : 0
        c.stroke(path, with: .color(.black.opacity(kantOpacitet * opacitet)),
                 style: StrokeStyle(lineWidth: st.bredd + kantBredd, lineCap: .round, lineJoin: .round,
                                    dash: streck, dashPhase: fas))
        c.stroke(path, with: .color(st.farg.opacity(opacitet)),
                 style: StrokeStyle(lineWidth: st.bredd, lineCap: .round, lineJoin: .round, dash: streck, dashPhase: fas))
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
                    c.prick(m, serie.punkt == .club ? 3.5 : 2.8, .black.opacity(SparLager.kantOpacitet))
                    c.prick(m, serie.punkt == .club ? 3 : 2.2, st.farg)
                }
            }
        }
    }
}

/// Valet av spår (PLAN S4f, BESLUT B70): ett chip per punkt, ett tryck slår på eller av. Ett
/// påslaget chip visar sin linje (gråton och streck) och fungerar som teckenförklaring; ett
/// avslaget är grått. "Club" visas först när klubbhuvudets bana kan räknas (S7b), och visar en
/// ring medan den räknas.
struct SparVal: View {
    let valda: Set<SparPunkt>
    var visaKlubba = false
    var klubbaRaknas = false
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

    private var punkter: [SparPunkt] { SparPunkt.allCases.filter { $0 != .club || visaKlubba } }

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
        return Button {
            onToggle(p)
        } label: {
            HStack(spacing: 4) {
                if pa {
                    if p == .club && klubbaRaknas {
                        ProgressView().controlSize(.mini).tint(Theme.secondary)
                    } else {
                        Canvas { c, s in
                            var path = Path()
                            path.move(to: CGPoint(x: 0, y: s.height / 2))
                            path.addLine(to: CGPoint(x: s.width, y: s.height / 2))
                            c.stroke(path, with: .color(st.farg),
                                     style: StrokeStyle(lineWidth: st.bredd, lineCap: .round, dash: st.streck))
                        }
                        .frame(width: 10, height: 8)
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
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(pa ? Theme.secondary : Theme.line, lineWidth: 1))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: Self.upplasning(p)))
        .accessibilityAddTraits(pa ? [.isToggle, .isSelected] : [.isToggle])
    }
}
