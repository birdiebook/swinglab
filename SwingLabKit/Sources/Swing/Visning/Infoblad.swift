import Foundation

/// Infobladet (BESLUT B41): namnet och fyra rader om ett mått, ur katalogen. Den enda
/// platsen med beskrivande text; skärmarna visar bara namn, tal och spann (BESLUT B13).
/// Öppnas med ett tryck på en måttrad eller ⓘ i Today, Progress, passet och granskningen.
public struct Infoblad: Equatable, Sendable {
    public let namn: String
    /// Vad som mäts och mellan vilka punkter.
    public let vad: String
    /// Varför det spelar roll, med felets namn när det finns.
    public let varfor: String
    /// Tecknet: "+ toward ball · − away".
    public let tecken: String
    /// Källan ur `status` och `kalla`: "Assumption, own baseline". Visas i grått efter
    /// `Texter.kallaRubrik`.
    public let kalla: String

    public init(namn: String, vad: String, varfor: String, tecken: String, kalla: String) {
        self.namn = namn
        self.vad = vad
        self.varfor = varfor
        self.tecken = tecken
        self.kalla = kalla
    }

    /// Ett fel i katalogen. Källans webbplatser ur `kalla` (" · "-skilda adresser).
    public init(_ fel: Katalog.Fel, namn: String) {
        self.init(namn: namn, vad: fel.vad, varfor: fel.varfor, tecken: fel.tecken,
                  kalla: Texter.kalla(status: fel.status, kontrollerad: fel.kontrollerad, gransFinns: fel.gront != nil,
                                      varden: Self.webbplatser(fel.kalla)))
    }

    /// Ett mått i katalogens `matt`: egen baslinje, farterna oprövade.
    public init(_ post: Katalog.Mattpost, namn: String) {
        self.init(namn: namn, vad: post.vad, varfor: post.varfor, tecken: post.tecken,
                  kalla: Texter.kallaMatt(oprovad: post.status == "oprovad"))
    }

    /// Bladet för ett mått i en vy: felet som har måttet, annars posten i `matt`.
    public static func fran(_ k: Katalog, matt: String, vy: Vy?) -> Infoblad? {
        let namn = Etiketter.etikett(matt).namn
        if let f = k.fel.first(where: { $0.matt == matt && (vy == nil || $0.vy == "bada" || $0.vy == vy!.rawValue) }) {
            return Infoblad(f, namn: namn)
        }
        if let p = k.matt.first(where: { $0.matt == matt && (vy == nil || $0.vy == vy!.rawValue) }) {
            return Infoblad(p, namn: namn)
        }
        return nil
    }

    /// "golf.com" ur "https://golf.com/instruction/… · https://www.golftec.co.za/swingtru".
    static func webbplatser(_ kalla: String) -> [String] {
        var ut: [String] = []
        for del in kalla.components(separatedBy: " · ") {
            guard let h = URL(string: del.trimmingCharacters(in: .whitespaces))?.host else { continue }
            let w = h.hasPrefix("www.") ? String(h.dropFirst(4)) : h
            if !ut.contains(w) { ut.append(w) }
        }
        return ut
    }

    /// Bladet i ord för VoiceOver.
    public var upplasning: String {
        "\(namn). \(vad) \(varfor) \(tecken). \(Texter.kallaRubrik): \(kalla)"
    }
}
