import Foundation

/// Geometri visas bara där den är själva måttet (BESLUT B13, regel 3).
public enum Geometrityp: Sendable {
    /// Bröstets lutning i adressen och vid träffen: två linjer, vinkeln mellan dem är måttet.
    case bojning
    /// Baksvingen och nedsvingen som två sträckor i sekunder.
    case tempo
}

/// Hur ett mått visas: kort namn, enhet, decimaler och fasen (BESLUT B13: ett mått
/// är namn, tal, enhet och spannet). Katalogens `namn` är en beskrivning och visas
/// inte (regel 5).
public struct Mattetikett: Equatable, Sendable {
    public let namn: String
    public let enhet: String
    public let decimaler: Int
    /// "topp", "topp–träff" …
    public let fas: String
    /// Visas med tecken (+/−), för mått där noll är adressen.
    public let tecken: Bool
    /// Åt vilket håll + pekar: "mål" eller "boll". nil = inget håll.
    public let plus: String?
    /// Vyns etikett när den inte är katalogens (tempot kommer ur klicket).
    public let vy: String?
    public let geometri: Geometrityp?

    public init(_ namn: String, _ enhet: String, _ decimaler: Int, _ fas: String, tecken: Bool = false,
                plus: String? = nil, vy: String? = nil, geometri: Geometrityp? = nil) {
        self.namn = namn
        self.enhet = enhet
        self.decimaler = decimaler
        self.fas = fas
        self.tecken = tecken
        self.plus = plus
        self.vy = vy
        self.geometri = geometri
    }
}

public enum Etiketter {
    /// Måtten som katalogen pekar på (Matt.namnDTL/namnFO), i vyns ord.
    public static let tabell: [String: Mattetikett] = [
        "backen_sway_topp": Mattetikett("Sway", "cm", 1, "topp", tecken: true, plus: "mål"),
        "backen_resa_framat": Mattetikett("Resa framåt", "cm", 1, "topp–träff", plus: "mål"),
        "backen_thrust_traff": Mattetikett("Thrust", "cm", 1, "träff", tecken: true, plus: "boll"),
        "brost_bojning_tapp": Mattetikett("Böjning", "°", 0, "adress–träff", tecken: true, geometri: .bojning),
        "tempo": Mattetikett("Tempo", ": 1", 1, "start–topp–träff", vy: "Klick", geometri: .tempo),
        "sway_gap_traff": Mattetikett("Sway gap", "cm", 1, "träff", tecken: true, plus: "mål"),
        "axellinje_lutning_traff": Mattetikett("Axellutning", "°", 0, "träff", tecken: true),
        "sidbojning_topp": Mattetikett("Sidböjning", "°", 0, "topp", tecken: true),
        "framre_armbage_efter_traff": Mattetikett("Främre armbåge", "°", 0, "efter träff"),
        "bakre_armbage_topp": Mattetikett("Bakre armbåge", "°", 0, "topp", tecken: true),
        "handbana": Mattetikett("Handens bana", "cm", 1, "nedsving", tecken: true),
        "framre_armbage_topp": Mattetikett("Främre arm", "°", 0, "topp"),
    ]

    /// Etiketten för ett mått. Ett mått utan rad visas med sitt nyckelnamn, så att
    /// det syns i provet och får en rad.
    public static func etikett(_ matt: String) -> Mattetikett {
        tabell[matt] ?? Mattetikett(matt, "", 1, "")
    }

    /// "FO", "DTL" eller "FO+DTL" ur katalogens vy.
    public static func vy(_ katalogvy: String) -> String {
        switch katalogvy {
        case "fo": return "FO"
        case "dtl": return "DTL"
        default: return "FO+DTL"
        }
    }

    /// Kortets översta rad: "FO · topp · + mot mål".
    public static func rubrik(_ fel: Katalog.Fel) -> String {
        let e = etikett(fel.matt)
        var delar = [e.vy ?? vy(fel.vy)]
        if !e.fas.isEmpty { delar.append(e.fas) }
        if let p = e.plus { delar.append("+ mot \(p)") }
        return delar.joined(separator: " · ")
    }
}
