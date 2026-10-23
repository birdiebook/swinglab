import SwiftUI
import Swing

/// Utveckling (skissens skärm 7, fliken Progress i S4c): perioden, måtten att välja bland,
/// och det valda måttet över passen (median, spridning och serie 1) mot gränsen eller den
/// egna baslinjen. Först valt är det som övas (BESLUT B31), annars det första. METOD MS16
struct UtvecklingVy: View {
    let visning: Utvecklingsvisning
    @State private var valt: String

    init(visning: Utvecklingsvisning, valt: String? = nil) {
        self.visning = visning
        _valt = State(initialValue: valt ?? visning.matt.first(where: \.ovas)?.id ?? visning.matt.first?.id ?? "")
    }

    /// Det valda måttets period: klubban, månaderna och passen med en punkt (METOD MS16).
    private var period: String {
        visning.matt.first { $0.id == valt }?.period ?? visning.period
    }

    private var rubrik: some View {
        Text("Progress")
            .tracking(-0.6)
            .typsnitt(30, .semibold)
            .foregroundStyle(Theme.text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Rubriken och perioden bredvid varandra, eller under varandra med stor text.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    rubrik.fixedSize()
                    Spacer()
                    Under(text: period).fixedSize()
                }
                VStack(alignment: .leading, spacing: 4) {
                    rubrik
                    Under(text: period)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, visning.ejMatta == nil ? 18 : 6)
            if let e = visning.ejMatta {
                Under(text: e)
                    .padding(.bottom, 14)
            }

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
                Etikett(text: u.rubrik, farg: u.ovas ? Theme.acc : Theme.tertiary)
                Spacer()
                if let m = u.markning { MarkningVy(markning: m) }
                InfoKnapp(blad: u.info)                  // BESLUT B41
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
                    nyckel(ihalig: false, String(localized: "session"))
                    nyckel(ihalig: true, String(localized: "set 1"))
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
                .typsnitt(12)
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
            // Passets spridning (kvartilerna) som en smal stapel bakom passets prick.
            for (i, p) in u.punkter.enumerated() {
                if let a = p.q1, let b = p.q3, b > a {
                    let y0 = y(b), y1 = y(a)
                    c.fill(Path(roundedRect: CGRect(x: x(i) - 2, y: y0, width: 4, height: max(1, y1 - y0)), cornerRadius: 1),
                           with: .color(Theme.line))
                }
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
            // Det du övar på: linjen och den senaste markören i accenten (BESLUT B31).
            c.stroke(linje, with: .color(u.ovas ? Theme.acc : Theme.secondary), lineWidth: 1.2)
            for (i, p) in u.punkter.enumerated() {
                c.prick(CGPoint(x: x(i), y: y(p.pass)), i == n - 1 ? 5 : 2.6,
                        i == n - 1 && u.ovas ? Theme.acc : Theme.text)
            }
        }
        .accessibilityHidden(true)
    }
}
