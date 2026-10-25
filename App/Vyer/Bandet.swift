import SwiftUI
import Swing

/// Bandets tre färger (BESLUT B87, undantaget från B13 regel 6 bara för läget mot bandet):
/// iOS systemfärger i mörkt läge, läsbara på svart. Grönt och rött är samma nyanser som
/// inspelningens skärm (B85); gult är systemets gula.
extension Theme {
    /// Innanför bandet.
    static let inne = Color(hex: 0x30D158)
    /// Utanför bandet men inom måttets brusgolv: kan vara mätfel.
    static let nara = Color(hex: 0xFFD60A)
    /// Utanför med mer än golvet, med pilen åt det håll värdet ligger.
    static let ute = Color(hex: 0xFF3B30)

    static func farg(_ l: Bandlage) -> Color {
        switch l.lage {
        case .gron: return inne
        case .gul: return nara
        case .rod: return ute
        case .ingen: return text
        }
    }
}

extension GraphicsContext {
    /// Läget som form, så att det går att läsa utan färg (BESLUT B87): en fylld prick innanför,
    /// en ring inom golvet och en fylld triangel som pekar åt det håll värdet ligger.
    /// `vagrat` = pilen pekar höger (över) eller vänster (under), som på spannets axel;
    /// annars upp eller ner, som bredvid talet. `r` = halva storleken.
    func lage(_ l: Bandlage, _ c: CGPoint, _ r: CGFloat, vagrat: Bool) {
        let f = Theme.farg(l)
        switch l.lage {
        case .gron:
            fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(f))
        case .gul:
            let ring = CGRect(x: c.x - r + 0.9, y: c.y - r + 0.9, width: 2 * r - 1.8, height: 2 * r - 1.8)
            fill(Path(ellipseIn: ring), with: .color(Theme.ground))
            stroke(Path(ellipseIn: ring), with: .color(f), lineWidth: 1.8)
        case .rod:
            var p = Path()
            let s = r * 1.15
            switch (vagrat, l.pil == .under) {
            case (true, false):                  // höger
                p.move(to: CGPoint(x: c.x + s, y: c.y))
                p.addLine(to: CGPoint(x: c.x - s * 0.8, y: c.y - s))
                p.addLine(to: CGPoint(x: c.x - s * 0.8, y: c.y + s))
            case (true, true):                   // vänster
                p.move(to: CGPoint(x: c.x - s, y: c.y))
                p.addLine(to: CGPoint(x: c.x + s * 0.8, y: c.y - s))
                p.addLine(to: CGPoint(x: c.x + s * 0.8, y: c.y + s))
            case (false, false):                 // upp
                p.move(to: CGPoint(x: c.x, y: c.y - s))
                p.addLine(to: CGPoint(x: c.x - s, y: c.y + s * 0.8))
                p.addLine(to: CGPoint(x: c.x + s, y: c.y + s * 0.8))
            case (false, true):                  // ner
                p.move(to: CGPoint(x: c.x, y: c.y + s))
                p.addLine(to: CGPoint(x: c.x - s, y: c.y - s * 0.8))
                p.addLine(to: CGPoint(x: c.x + s, y: c.y - s * 0.8))
            }
            p.closeSubpath()
            fill(p, with: .color(f))
        case .ingen:
            break
        }
    }
}

/// Läget bredvid talet: prick, ring eller pil upp/ner (METOD M62, BESLUT B87). Inga ord; VoiceOver
/// läser läget ur kortets eller radens uppläsning.
struct LageSymbol: View {
    let lage: Bandlage
    var storlek: CGFloat = 12

    var body: some View {
        if lage.lage != .ingen {
            Canvas { c, s in
                c.lage(lage, CGPoint(x: s.width / 2, y: s.height / 2), storlek / 2 - 0.5, vagrat: false)
            }
            .frame(width: storlek, height: storlek)
            .accessibilityHidden(true)
        }
    }
}
