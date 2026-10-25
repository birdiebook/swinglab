import SwiftUI
import Swing

/// Spannet (BESLUT B13, regel 3 och 4): en tunn linje; gränsen som ett tjockare
/// grått segment eller den egna baslinjen som en ram; förra passet som ett grått
/// streck; passets kvartiler som en tunn vit linje och medianen som en vit prick.
/// I passets kort står inga tal under linjen: kortet skriver bra-området med enhet under den
/// (`Spann.omrade`, PLAN S4h); `tal` ritar axelns och gränsens ändar där det behövs. Läget mot bandet är
/// markörens form och färg (METOD M62, BESLUT B87), en grön prick, en gul ring eller en röd pil
/// som pekar åt det håll värdet ligger; utan läge är markören vit (eller i accenten).
struct SpannVy: View {
    let spann: Spann
    var kompakt = false
    /// Det du övar på: markören och kvartilerna i accenten (BESLUT B31); med ett läge bär
    /// kvartilerna accenten och markören läget.
    var accent = false
    var lage: Bandlage = .ingen
    /// Axelns och gränsens tal under linjen (förut i passets kort; S4h ersatte dem med raden
    /// "Good: …" under kortets spann).
    var tal = false

    private var markor: Color { accent ? Theme.acc : Theme.text }

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
                    c.linje(CGPoint(x: x(sp.lo), y: y), CGPoint(x: x(sp.hi), y: y), markor, 1.5)
                }
                if let f = spann.forra {
                    c.linje(CGPoint(x: x(f), y: y - 7), CGPoint(x: x(f), y: y + 7), Theme.tertiary, 1.5)
                }
                // Talen: zonens ändar först (i mitten under sin punkt), sedan axelns ändar
                // (förankrade inåt) där de inte krockar med ett tal som redan står.
                let e = tal ? spann.etiketter : []
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
            if lage.lage == .ingen {
                c.prick(CGPoint(x: x(spann.nu), y: y), kompakt ? 3.5 : 5, markor)
            } else {
                c.lage(lage, CGPoint(x: x(spann.nu), y: y), kompakt ? 4.5 : 6, vagrat: true)
            }
        }
        .frame(height: kompakt ? 14 : (tal ? 40 : 24))
        .accessibilityElement()
        .accessibilityLabel(spann.upplasning)
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
    @State private var visaNyckel = false

    var body: some View {
        Sektion {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Etikett(text: kort.rubrik, farg: kort.ovas ? Theme.acc : Theme.tertiary)
                    Spacer(minLength: 8)
                    if let m = kort.markning { MarkningVy(markning: m) }
                }
                Text(kort.namn)
                    .typsnitt(16, .medium)
                    .foregroundStyle(Theme.text)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                if let spann = kort.spann {
                    HStack(alignment: .bottom, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .center, spacing: 10) {
                                StortTal(varde: kort.varde, enhet: kort.enhet)
                                LageSymbol(lage: kort.lage, storlek: 14)       // BESLUT B87
                            }
                            if let d = kort.skillnad { Under(text: d) }
                        }
                        Spacer(minLength: 0)
                        if let g = kort.geometri { GeometriVy(geometri: g) }
                    }
                    // Ett tryck på bandet eller ⓘ visar nyckeln (PLAN S4h, BESLUT B94).
                    SpannVy(spann: spann, accent: kort.ovas, lage: kort.lage)
                        .padding(.top, 12)
                        .contentShape(.rect)
                        .onTapGesture { visaNyckel = true }
                    HStack(alignment: .center, spacing: 6) {
                        if let o = spann.omrade {
                            Text(verbatim: o)
                                .typsnitt(12, .medium, siffror: true)
                                .foregroundStyle(Theme.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        NyckelKnapp { visaNyckel = true }
                    }
                } else {
                    // Ett saknat eller avstängt mått: bara strecket, utan enhet.
                    StortTal(varde: kort.varde, enhet: kort.varde == "—" ? "" : kort.enhet, avstangt: true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kort.upplasning)
        .accessibilityAction(named: Text(verbatim: Texter.nyckelKnapp)) { visaNyckel = true }
        .infoblad(kort.info)                     // BESLUT B41
        .sheet(isPresented: $visaNyckel) { BandnyckelArk() }
    }
}

/// Den lilla ⓘ som öppnar bandets nyckel: tryckytan 44×44 pt, men raden räknar den som 28 hög.
struct NyckelKnapp: View {
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .typsnitt(13)
                .foregroundStyle(Theme.tertiary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, -8)
        .accessibilityLabel(Text(verbatim: Texter.nyckelKnapp))
    }
}

/// Bandets nyckel (PLAN S4h, BESLUT B94, design/README regel 11): varje tecken på spannet ritat som
/// i kortet, med en kort rad. Texten är SwingLabKits (`Bandnyckel`).
struct BandnyckelVy: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: Bandnyckel.rubrik)
                .typsnitt(22, .semibold)
                .foregroundStyle(Theme.text)
                .padding(.bottom, 14)
            ForEach(Bandnyckel.Tecken.allCases, id: \.self) { t in
                HStack(spacing: 14) {
                    NyckelTecken(tecken: t)
                        .frame(width: 44, height: 20)
                    Text(verbatim: Bandnyckel.text(t))
                        .typsnitt(15)
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 9)
                .overlay(alignment: .top) { Rectangle().fill(Theme.hair).frame(height: 1) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: Bandnyckel.text(t)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 28)
    }
}

/// Ett tecken i nyckeln, med samma mått och färger som spannet (`SpannVy`).
struct NyckelTecken: View {
    let tecken: Bandnyckel.Tecken

    var body: some View {
        Canvas { c, s in
            let y = s.height / 2, x0: CGFloat = 2, x1 = s.width - 2
            let mitt = CGPoint(x: s.width / 2, y: y)
            switch tecken {
            case .bandet:
                c.linje(CGPoint(x: x0, y: y), CGPoint(x: x1, y: y), Theme.line, 1.5)
                c.linje(CGPoint(x: x0 + 8, y: y), CGPoint(x: x1 - 8, y: y), Theme.secondary, 4)
            case .inne:
                c.lage(Bandlage(.gron), mitt, 6, vagrat: true)
            case .nara:
                c.lage(Bandlage(.gul), mitt, 6, vagrat: true)
            case .ute:
                c.lage(Bandlage(.rod, pil: .over), mitt, 6, vagrat: true)
            case .slagen:
                c.linje(CGPoint(x: x0, y: y), CGPoint(x: x1, y: y), Theme.line, 1.5)
                c.linje(CGPoint(x: x0 + 10, y: y), CGPoint(x: x1 - 10, y: y), Theme.text, 1.5)
            case .forra:
                c.linje(CGPoint(x: x0, y: y), CGPoint(x: x1, y: y), Theme.line, 1.5)
                c.linje(CGPoint(x: mitt.x, y: y - 7), CGPoint(x: mitt.x, y: y + 7), Theme.tertiary, 1.5)
            case .vanligt:
                c.linje(CGPoint(x: x0, y: y), CGPoint(x: x1, y: y), Theme.line, 1.5)
                let ram = CGRect(x: x0 + 8, y: y - 4, width: x1 - x0 - 16, height: 8)
                c.stroke(Path(roundedRect: ram, cornerRadius: 1.5), with: .color(Theme.secondary), lineWidth: 1.3)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Nyckeln i ett sheet: halv höjd, svart botten (som infobladet).
struct BandnyckelArk: View {
    var body: some View {
        ScrollView { BandnyckelVy() }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.ground)
    }
}
