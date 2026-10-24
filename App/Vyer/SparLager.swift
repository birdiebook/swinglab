import SwiftUI
import Swing
import Capture

/// Det som spårlagret ritar (PLAN S4f, BESLUT B70): punktserierna i hela bildens pixlar med
/// tider, tiden som spelats upp till, bildens storlek och utsnittet som ytan visar. Kroppens
/// spår, klubbhuvudets bana (S7b) och senare 3D (S6d) ges i samma form.
struct SparBild {
    var serier: [SparSerie]
    /// s relativt klicket: det som är spelat (t ≤ nu) ritas fast, resten svagt.
    var nu: Double
    var bredd: Int
    var hojd: Int
    var crop: CropRect
    /// P1-skaftets linje bakifrån (S7b, METOD M47), förlängd: klubbhuvudets bana ses mot den.
    var plan: (grepp: Punkt, hosel: Punkt)? = nil
}

/// Spårlagret (PLAN S4f, BESLUT B70, METOD M60): en tunn linje per serie, svartvitt med
/// gråton och linjestil per punkt (B13), ingen accent (B31: ett spår är inget mått). Det som
/// spelats upp ritas fast och resten svagt, så att banans form syns från första rutan och det
/// spelade växer med videon. Klubbhuvudets interpolerade rutor (S7b) är streckade: där har
/// banan gissats mellan säkra punkter. Punktens läge i rutan är en liten prick.
struct SparLager: View {
    let bild: SparBild

    /// Svagt för det som inte spelats än.
    static let kvarOpacitet = 0.22

    /// Stilen per punkt: färg, bredd och streck (B13: gråtoner och linjestil).
    static func stil(_ p: SparPunkt) -> (farg: Color, bredd: CGFloat, streck: [CGFloat]) {
        switch p {
        case .hands: return (Theme.text, 1.6, [])
        case .shoulders: return (Theme.secondary, 1.2, [])
        case .hips: return (Theme.secondary, 1.2, [5, 3])
        case .head: return (Theme.text, 1.2, [1.5, 2.5])
        case .club: return (Theme.text, 2.0, [])
        }
    }

    var body: some View {
        Canvas { c, s in
            let w = Double(max(bild.bredd, 1)), h = Double(max(bild.hojd, 1))
            func p(_ q: Punkt) -> CGPoint {
                let l = bild.crop.local(x: q.x / w, y: q.y / h)
                return CGPoint(x: CGFloat(l.x) * s.width, y: CGFloat(l.y) * s.height)
            }
            if let plan = bild.plan {
                // Linjen genom P1:s grepp och hosel, långt åt båda hållen (ytan klipper).
                let a = p(plan.grepp), b = p(plan.hosel)
                let dx = b.x - a.x, dy = b.y - a.y, n = max(1, (dx * dx + dy * dy).squareRoot())
                let k = 4 * max(s.width, s.height) / n
                c.linje(CGPoint(x: a.x - dx * k, y: a.y - dy * k), CGPoint(x: b.x + dx * k, y: b.y + dy * k),
                        Theme.tertiary, 1, streckad: [4, 4])
            }
            for serie in bild.serier {
                let st = Self.stil(serie.punkt)
                for del in serie.delar(nu: bild.nu) {
                    var path = Path()
                    path.move(to: p(del.punkter[0]))
                    for q in del.punkter.dropFirst() { path.addLine(to: p(q)) }
                    let streck = del.interpolerad ? [2, 4] : st.streck
                    let farg = del.spelad ? st.farg : st.farg.opacity(Self.kvarOpacitet)
                    c.stroke(path, with: .color(farg),
                             style: StrokeStyle(lineWidth: st.bredd, lineCap: .round, lineJoin: .round, dash: streck))
                }
                if let q = serie.punkt(nu: bild.nu) { c.prick(p(q), serie.punkt == .club ? 3 : 2.2, st.farg) }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Valet av spår (PLAN S4f, BESLUT B70): ett chip per punkt, ett tryck slår på eller av. Ett
/// påslaget chip visar sin linje (gråton och streck) och fungerar som teckenförklaring; ett
/// avslaget är grått. "Club" går bara att välja när klubban kan spåras (S7b: minst två
/// markerade positioner) och visar en ring medan banan räknas.
struct SparVal: View {
    let valda: Set<SparPunkt>
    var klubbaMojlig = false
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

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Theme.tertiary)
                .accessibilityLabel(Text("Trails"))
            ForEach(SparPunkt.allCases, id: \.self) { p in chip(p) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chip(_ p: SparPunkt) -> some View {
        let pa = valda.contains(p)
        let mojlig = p != .club || klubbaMojlig
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
        .disabled(!mojlig)
        .opacity(mojlig ? 1 : 0.4)
        .accessibilityLabel(Text(verbatim: Self.namn(p)))
        .accessibilityAddTraits(pa ? .isSelected : [])
    }
}
