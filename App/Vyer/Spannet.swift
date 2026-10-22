import SwiftUI
import Swing

/// Spannet (BESLUT B13, regel 3 och 4): en tunn linje; gränsen som ett tjockare
/// grått segment eller den egna baslinjen som en ram; förra passet som ett grått
/// streck; passets kvartiler som en tunn vit linje och medianen som en vit prick.
/// Talen under linjen är axelns och gränsens ändar. Inga ord om läget.
struct SpannVy: View {
    let spann: Spann
    var kompakt = false

    var body: some View {
        Canvas { c, s in
            let x0: CGFloat = kompakt ? 4 : 6, x1 = s.width - x0
            let y: CGFloat = kompakt ? 7 : 12
            func x(_ v: Double) -> CGFloat { x0 + CGFloat(spann.axel.andel(v)) * (x1 - x0) }

            c.linje(CGPoint(x: x0, y: y), CGPoint(x: x1, y: y), Theme.line, 1.5)
            switch spann.zon {
            case let .grans(lo, hi)?:
                c.linje(CGPoint(x: x(lo), y: y), CGPoint(x: x(hi), y: y), Theme.secondary, kompakt ? 3 : 4)
            case let .baslinje(lo, hi)?:
                let h: CGFloat = kompakt ? 6 : 8
                let ram = CGRect(x: x(lo), y: y - h / 2, width: max(1, x(hi) - x(lo)), height: h)
                c.stroke(Path(roundedRect: ram, cornerRadius: 1.5), with: .color(Theme.secondary), lineWidth: 1.3)
            case nil:
                break
            }
            if !kompakt {
                if let sp = spann.spridning {
                    c.linje(CGPoint(x: x(sp.lo), y: y), CGPoint(x: x(sp.hi), y: y), Theme.text, 1.5)
                }
                if let f = spann.forra {
                    c.linje(CGPoint(x: x(f), y: y - 7), CGPoint(x: x(f), y: y + 7), Theme.tertiary, 1.5)
                }
                // Talen: zonens ändar först (i mitten under sin punkt), sedan axelns ändar
                // (förankrade inåt) där de inte krockar med ett tal som redan står.
                let e = spann.etiketter
                var upptaget: [ClosedRange<CGFloat>] = []
                func bredd(_ t: String) -> CGFloat { CGFloat(t.count) * 6 + 2 }
                func ledigt(_ r: ClosedRange<CGFloat>) -> Bool {
                    !upptaget.contains { $0.lowerBound - 6 <= r.upperBound && r.lowerBound <= $0.upperBound + 6 }
                }
                if e.count > 2 {
                    for z in e[1..<(e.count - 1)] {
                        let px = x(z.varde), w = bredd(z.text)
                        let r = (px - w / 2)...(px + w / 2)
                        guard ledigt(r) else { continue }
                        c.etikett(z.text, CGPoint(x: px, y: y + 14), ankare: .top)
                        upptaget.append(r)
                    }
                }
                if let forst = e.first {
                    let px = x(forst.varde), r = px...(px + bredd(forst.text))
                    if ledigt(r) { c.etikett(forst.text, CGPoint(x: px, y: y + 14), ankare: .topLeading) }
                }
                if e.count > 1, let sist = e.last {
                    let px = x(sist.varde), r = (px - bredd(sist.text))...px
                    if ledigt(r) { c.etikett(sist.text, CGPoint(x: px, y: y + 14), ankare: .topTrailing) }
                }
            }
            c.prick(CGPoint(x: x(spann.nu), y: y), kompakt ? 3.5 : 5, Theme.text)
        }
        .frame(height: kompakt ? 14 : 40)
        .accessibilityHidden(true)
    }
}

/// Geometrin där den är själva måttet: bröstets lutning i adressen (streckad) och
/// vid träffen (vit), i sina riktiga vinklar; tempot som baksvingen och nedsvingen.
struct GeometriVy: View {
    let geometri: Geometri

    var body: some View {
        Canvas { c, s in
            switch geometri {
            case let .bojning(adress, traff):
                let o = CGPoint(x: 30, y: s.height - 6), r: CGFloat = 52
                func spets(_ grader: Double) -> CGPoint {
                    let a = grader * .pi / 180
                    return CGPoint(x: o.x + r * CGFloat(sin(a)), y: o.y - r * CGFloat(cos(a)))
                }
                c.linje(o, spets(adress), Theme.tertiary, 1, streckad: [3, 3])
                c.linje(o, spets(traff), Theme.text, 1.6)
                c.prick(o, 2.5, Theme.text)
            case let .tempo(bak, ned, bakText, nedText):
                let bredd = s.width - 4
                let k = bredd / CGFloat(bak + ned)
                let y: CGFloat = 34
                c.linje(CGPoint(x: 2, y: y), CGPoint(x: 2 + k * CGFloat(bak) - 1, y: y), Theme.secondary, 3)
                c.linje(CGPoint(x: 2 + k * CGFloat(bak) + 1, y: y), CGPoint(x: s.width - 2, y: y), Theme.text, 3)
                c.etikett(bakText, CGPoint(x: 2, y: y - 8), ankare: .bottomLeading)
                c.etikett(nedText, CGPoint(x: s.width - 2, y: y - 8), ankare: .bottomTrailing)
                c.etikett("s", CGPoint(x: s.width - 2, y: y + 8), ankare: .topTrailing)
            }
        }
        .frame(width: 96, height: 64)
        .accessibilityHidden(true)
    }
}

/// Ett mått i passet: rubriken och märkningen, namnet, talet med enheten, förändringen
/// mot förra passet, geometrin där den är måttet och spannet.
struct MattkortVy: View {
    let kort: Mattkort

    var body: some View {
        Sektion {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Etikett(text: kort.rubrik)
                    Spacer(minLength: 8)
                    if let m = kort.markning { MarkningVy(markning: m) }
                }
                Text(kort.namn)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                if let spann = kort.spann {
                    HStack(alignment: .bottom, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            StortTal(varde: kort.varde, enhet: kort.enhet)
                            if let d = kort.skillnad { Under(text: d) }
                        }
                        Spacer(minLength: 0)
                        if let g = kort.geometri { GeometriVy(geometri: g) }
                    }
                    SpannVy(spann: spann)
                        .padding(.top, 12)
                } else {
                    StortTal(varde: kort.varde, enhet: kort.enhet, avstangt: true)
                }
            }
        }
    }
}
