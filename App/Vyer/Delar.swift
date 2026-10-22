import SwiftUI
import Swing

// Delarna som skärmarna i S4 delar (BESLUT B13, design/skiss.html): etiketten,
// det stora talet, sektionen med en tunn linje ovanför, segmentet och märkningen.
// Inga ScrollView eller UIKit-delar här, så att provet kan rita vyerna med
// ImageRenderer; skärmarna läggs i en ScrollView när de kopplas in i navigeringen.

/// Typsnittet skalas med textstorleken (Dynamisk text): storleken är den vid
/// standardstorleken, och `relativeTo` väljs efter storleken så att stora tal och
/// små etiketter växer i samma takt som systemets stilar.
struct Typsnitt: ViewModifier {
    @ScaledMetric var storlek: CGFloat
    let vikt: Font.Weight
    let siffror: Bool

    init(_ storlek: CGFloat, _ vikt: Font.Weight, siffror: Bool) {
        _storlek = ScaledMetric(wrappedValue: storlek, relativeTo: Typsnitt.stil(storlek))
        self.vikt = vikt
        self.siffror = siffror
    }

    static func stil(_ storlek: CGFloat) -> Font.TextStyle {
        storlek >= 28 ? .largeTitle : storlek >= 20 ? .title3 : storlek >= 15 ? .body : storlek >= 13 ? .footnote : .caption
    }

    func body(content: Content) -> some View {
        content.font(siffror ? Font.system(size: storlek, weight: vikt).monospacedDigit()
                             : Font.system(size: storlek, weight: vikt))
    }
}

extension View {
    /// Systemtypsnittet i `storlek` punkter vid standardstorleken, skalat med Dynamisk text.
    func typsnitt(_ storlek: CGFloat, _ vikt: Font.Weight = .regular, siffror: Bool = false) -> some View {
        modifier(Typsnitt(storlek, vikt, siffror: siffror))
    }
}

/// Liten etikett i versaler: "FO · TOPP", "ÖVNING".
struct Etikett: View {
    let text: String
    var farg: Color = Theme.tertiary
    /// Enheten efter talet behåller sin form ("s", inte "S").
    var efter: String = ""

    var body: some View {
        Text(text.uppercased() + efter)
            .tracking(1.1)
            .monospacedDigit()
            .typsnitt(11, .semibold)
            .foregroundStyle(farg)
    }
}

/// Sekundär text: datum, antal, förändringen.
struct Under: View {
    let text: String

    var body: some View {
        Text(text)
            .monospacedDigit()
            .typsnitt(13)
            .foregroundStyle(Theme.secondary)
    }
}

/// Ett stort tal med enheten liten och grå bredvid (regel 7).
struct StortTal: View {
    let varde: String
    let enhet: String
    var storlek: CGFloat = 46
    var enhetStorlek: CGFloat = 16
    var avstangt = false

    var body: some View {
        // Gradtecknet sitter vid talet; andra enheter står en bit ifrån.
        HStack(alignment: .firstTextBaseline, spacing: enhet == "°" ? 0 : 5) {
            Text(varde)
                .tracking(-storlek * 0.02)
                .typsnitt(storlek, .medium, siffror: true)
                .foregroundStyle(avstangt ? Theme.tertiary : Theme.text)
            if !enhet.isEmpty {
                Text(enhet)
                    .typsnitt(enhetStorlek, .medium)
                    .foregroundStyle(Theme.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}

/// En sektion: en tunn linje ovanför och luft runt innehållet.
struct Sektion<Innehall: View>: View {
    var etikett: String? = nil
    var hoger: String? = nil
    @ViewBuilder let innehall: () -> Innehall

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if etikett != nil || hoger != nil {
                // Bredvid varandra när de får plats, annars under varandra (stor text).
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        if let etikett { Etikett(text: etikett).fixedSize() }
                        Spacer(minLength: 10)
                        if let hoger { Under(text: hoger).fixedSize() }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        if let etikett { Etikett(text: etikett) }
                        if let hoger { Under(text: hoger) }
                    }
                }
                .padding(.bottom, 12)
            }
            innehall()
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.hair).frame(height: 1)
        }
    }
}

/// Raden överst i ett flöde: tillbaka, titeln i mitten och något till höger.
struct Navrad<Hoger: View>: View {
    let titel: String
    @ViewBuilder var hoger: () -> Hoger
    var tillbaka: () -> Void = {}

    var body: some View {
        ZStack {
            Text(titel)
                .monospacedDigit()
                .typsnitt(16, .semibold)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .padding(.horizontal, 56)
            HStack {
                Button(action: tillbaka) {
                    Image(systemName: "chevron.left")
                        .typsnitt(17, .medium)
                        .foregroundStyle(Theme.secondary)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                Spacer()
                hoger()
            }
        }
        .frame(minHeight: 44)
        .padding(.bottom, 8)
    }
}

/// Segmentet (FO/DTL, Alla/FO/DTL): en tunn ram och det valda som vitt fält.
struct Segment: View {
    let alternativ: [String]
    @Binding var valt: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(alternativ.indices, id: \.self) { i in
                Button {
                    valt = i
                } label: {
                    Text(alternativ[i])
                        .typsnitt(13, .semibold)
                        .foregroundStyle(i == valt ? Theme.ground : Theme.secondary)
                        .padding(.horizontal, 13)
                        .frame(minHeight: 30)
                        .background(i == valt ? Theme.text : Color.clear, in: .rect(cornerRadius: 2))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.line, lineWidth: 1))
    }
}

/// Ett val bland flera (måtten i Utveckling): en tunn ram, vald = vit ram och text.
struct Chip: View {
    let text: String
    let vald: Bool
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(text)
                .typsnitt(13.5, .medium)
                .foregroundStyle(vald ? Theme.text : Theme.secondary)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(vald ? Theme.text : Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Raderna bryts när de inte får plats, så att inget val göms bakom en rullning.
struct Flode: Layout {
    var mellan: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let bredd = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rad: CGFloat = 0, mest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > bredd {
                y += rad + mellan
                x = 0
                rad = 0
            }
            x += s.width + mellan
            rad = max(rad, s.height)
            mest = max(mest, x - mellan)
        }
        return CGSize(width: proposal.width ?? mest, height: y + rad)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rad: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX {
                y += rad + mellan
                x = bounds.minX
                rad = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + mellan
            rad = max(rad, s.height)
        }
    }
}

/// Flode som vy, med avståndet som argument.
struct Radbrytning<Innehall: View>: View {
    var mellan: CGFloat = 6
    @ViewBuilder let innehall: () -> Innehall

    var body: some View {
        Flode(mellan: mellan).callAsFunction(innehall)
    }
}

/// Märkningen: en liten symbol och en kort etikett (regel 5). Streckad ring = B10
/// (gränsen ej läst i original), ram = egen baslinje, överstruken ring = avstängt.
struct MarkningVy: View {
    let markning: Markning

    var body: some View {
        HStack(spacing: 5) {
            Canvas { c, s in
                let k = s.width / 12
                switch markning {
                case .b10:
                    let ring = Path(ellipseIn: CGRect(x: 1.4 * k, y: 1.4 * k, width: 9.2 * k, height: 9.2 * k))
                    c.stroke(ring, with: .color(Theme.tertiary), style: StrokeStyle(lineWidth: 1.4, dash: [2.2, 1.8]))
                case .egen:
                    let ram = Path(roundedRect: CGRect(x: 1.2 * k, y: 3.5 * k, width: 9.6 * k, height: 5 * k), cornerRadius: k)
                    c.stroke(ram, with: .color(Theme.tertiary), lineWidth: 1.4)
                case .av:
                    let ring = Path(ellipseIn: CGRect(x: 1.4 * k, y: 1.4 * k, width: 9.2 * k, height: 9.2 * k))
                    c.stroke(ring, with: .color(Theme.tertiary), lineWidth: 1.4)
                    var streck = Path()
                    streck.move(to: CGPoint(x: 2.8 * k, y: 9.2 * k))
                    streck.addLine(to: CGPoint(x: 9.2 * k, y: 2.8 * k))
                    c.stroke(streck, with: .color(Theme.tertiary), lineWidth: 1.4)
                }
            }
            .frame(width: 11, height: 11)
            Text(markning.etikett)
                .typsnitt(11, .semibold)
                .foregroundStyle(Theme.tertiary)
        }
    }
}

extension GraphicsContext {
    /// En rak linje.
    func linje(_ a: CGPoint, _ b: CGPoint, _ farg: Color, _ bredd: CGFloat = 1, streckad: [CGFloat] = []) {
        var p = Path()
        p.move(to: a)
        p.addLine(to: b)
        stroke(p, with: .color(farg), style: StrokeStyle(lineWidth: bredd, lineCap: .butt, dash: streckad))
    }

    /// En prick, fylld eller ihålig (mot botten).
    func prick(_ c: CGPoint, _ r: CGFloat, _ farg: Color, ihalig: Bool = false) {
        let ruta = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
        if ihalig {
            fill(Path(ellipseIn: ruta), with: .color(Theme.ground))
            stroke(Path(ellipseIn: ruta), with: .color(farg), lineWidth: 1.5)
        } else {
            fill(Path(ellipseIn: ruta), with: .color(farg))
        }
    }

    /// Ett litet tal i tabellsiffror.
    func etikett(_ text: String, _ p: CGPoint, ankare: UnitPoint, farg: Color = Theme.tertiary,
                 storlek: CGFloat = 10.5, vikt: Font.Weight = .medium) {
        draw(Text(text).font(.system(size: storlek, weight: vikt).monospacedDigit()).foregroundColor(farg),
             at: p, anchor: ankare)
    }
}
