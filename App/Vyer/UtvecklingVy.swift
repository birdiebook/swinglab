import SwiftUI
import Swing

/// Utveckling (skissens skärm 7): perioden, måtten att välja bland, och det valda
/// måttet över passen mot gränsen eller den egna baslinjen, med serie 1 under.
struct UtvecklingVy: View {
    let visning: Utvecklingsvisning
    @State private var valt: String

    init(visning: Utvecklingsvisning, valt: String? = nil) {
        self.visning = visning
        _valt = State(initialValue: valt ?? visning.matt.first?.id ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Utveckling")
                    .font(.system(size: 30, weight: .semibold))
                    .tracking(-0.6)
                    .foregroundStyle(Theme.text)
                Spacer()
                Under(text: visning.period)
            }
            .padding(.top, 8)
            .padding(.bottom, 18)

            Flode {
                ForEach(visning.matt, id: \.id) { m in
                    Chip(text: m.namn, vald: m.id == valt) { valt = m.id }
                }
            }

            if let m = visning.matt.first(where: { $0.id == valt }) {
                UtvecklingKort(u: m)
                    .padding(.top, 18)
            }
        }
        .padding(.horizontal, 20)
        .background(Theme.ground)
    }
}

/// Ett mått över passen: rubriken, talet nu och förändringen sedan första passet, diagrammet.
struct UtvecklingKort: View {
    let u: Utveckling

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Etikett(text: u.rubrik)
                Spacer()
                if let m = u.markning { MarkningVy(markning: m) }
            }
            HStack(alignment: .lastTextBaseline) {
                StortTal(varde: u.varde, enhet: u.enhet)
                Spacer()
                if let d = u.skillnad { Under(text: d) }
            }
            .padding(.top, 10)
            .padding(.bottom, 16)
            Diagram(u: u)
                .aspectRatio(350.0 / 220.0, contentMode: .fit)
            if u.harSerie1 {
                HStack(spacing: 16) {
                    nyckel(ihalig: false, "pass")
                    nyckel(ihalig: true, "serie 1")
                }
                .padding(.top, 8)
            }
        }
    }

    private func nyckel(ihalig: Bool, _ text: String) -> some View {
        HStack(spacing: 6) {
            Canvas { c, s in
                c.prick(CGPoint(x: s.width / 2, y: s.height / 2), 3.2, ihalig ? Theme.tertiary : Theme.text, ihalig: ihalig)
            }
            .frame(width: 10, height: 10)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Theme.tertiary)
        }
    }
}

/// Diagrammet: rutnätet med talen, bandet (gränsen fylld, baslinjen streckad),
/// blocken, månaderna, serie 1 som ihåliga prickar under passen, och passen som
/// en tunn linje med det senaste som en stor vit prick.
struct Diagram: View {
    let u: Utveckling

    var body: some View {
        Canvas { c, s in
            let l: CGFloat = 30, r: CGFloat = 8, t: CGFloat = 18, b: CGFloat = 22
            let n = u.punkter.count
            func x(_ i: Int) -> CGFloat {
                n > 1 ? l + CGFloat(i) * (s.width - l - r) / CGFloat(n - 1) : (l + s.width - r) / 2
            }
            func y(_ v: Double) -> CGFloat {
                t + CGFloat(1 - u.axel.andel(v)) * (s.height - t - b)
            }
            for e in u.axelText {
                c.linje(CGPoint(x: l, y: y(e.varde)), CGPoint(x: s.width - r, y: y(e.varde)), Theme.hair)
                c.etikett(e.text, CGPoint(x: l - 8, y: y(e.varde)), ankare: .trailing)
            }
            switch u.band {
            case let .grans(lo, hi)?:
                let y0 = y(hi), y1 = y(lo)
                if y1 > y0 {
                    c.fill(Path(CGRect(x: l, y: y0, width: s.width - r - l, height: y1 - y0)),
                           with: .color(Theme.secondary.opacity(0.13)))
                }
            case let .baslinje(lo, hi)?:
                let y0 = y(hi), y1 = y(lo)
                c.stroke(Path(CGRect(x: l, y: y0, width: s.width - r - l, height: max(1, y1 - y0))),
                         with: .color(Theme.secondary.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            case nil:
                break
            }
            for blk in u.block {
                let bx = (x(blk.index) + x(blk.index - 1)) / 2
                c.linje(CGPoint(x: bx, y: t - 8), CGPoint(x: bx, y: s.height - b), Theme.line)
                c.etikett(blk.text, CGPoint(x: bx + 4, y: t - 2), ankare: .bottomLeading)
            }
            for m in u.manader {
                let ankare: UnitPoint = m.index == 0 ? .bottomLeading : .bottom
                c.etikett(m.text, CGPoint(x: m.index == 0 ? x(0) - 4 : x(m.index), y: s.height - 2), ankare: ankare)
            }
            for (i, p) in u.punkter.enumerated() {
                if let s1 = p.serie1 {
                    c.linje(CGPoint(x: x(i), y: y(s1)), CGPoint(x: x(i), y: y(p.pass)), Theme.line)
                    c.prick(CGPoint(x: x(i), y: y(s1)), 3, Theme.tertiary, ihalig: true)
                }
            }
            var linje = Path()
            for (i, p) in u.punkter.enumerated() {
                let q = CGPoint(x: x(i), y: y(p.pass))
                if i == 0 { linje.move(to: q) } else { linje.addLine(to: q) }
            }
            c.stroke(linje, with: .color(Theme.secondary), lineWidth: 1.2)
            for (i, p) in u.punkter.enumerated() {
                c.prick(CGPoint(x: x(i), y: y(p.pass)), i == n - 1 ? 5 : 2.6, Theme.text)
            }
        }
        .accessibilityHidden(true)
    }
}
