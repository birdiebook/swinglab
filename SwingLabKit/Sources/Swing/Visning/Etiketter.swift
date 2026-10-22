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
    /// "top", "top–impact" …
    public let fas: String
    /// Visas med tecken (+/−), för mått där noll är adressen.
    public let tecken: Bool
    /// Åt vilket håll + pekar: "target" eller "ball". nil = inget håll.
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
    public static let tabell: [String: Mattetikett] = {
        // Namnen och faserna står i Texter (BESLUT B33); decimalerna följer PC:ns regel.
        func e(_ m: String, _ enhet: String, _ fas: String, tecken: Bool = false, plus: String? = nil,
               vy: String? = nil, geometri: Geometrityp? = nil) -> (String, Mattetikett) {
            (m, Mattetikett(Texter.mattnamn[m] ?? m, enhet, Avrundning.decimaler(m), fas, tecken: tecken,
                            plus: plus, vy: vy, geometri: geometri))
        }
        let T = Texter.self
        return Dictionary(uniqueKeysWithValues: [
            // Tilläggen mot Sportsbox i 2D (PLAN S1b, METOD M30–M37).
            e("backen_bojning_adress", "°", T.address, tecken: true),
            e("backen_bojning_topp", "°", T.top, tecken: true),
            e("backen_bojning_traff", "°", T.impact, tecken: true),
            e("framre_kna_adress", "°", T.address),
            e("framre_kna_topp", "°", T.top),
            e("framre_kna_traff", "°", T.impact),
            e("brost_lyft_topp", "cm", T.top, tecken: true),
            e("brost_lyft_traff", "cm", T.impact, tecken: true),
            e("brost_lyft_finish", "cm", T.finish, tecken: true),
            e("hand_lyft_topp", "cm", T.top, tecken: true),
            e("hand_lyft_traff", "cm", T.impact, tecken: true),
            e("hand_lyft_finish", "cm", T.finish, tecken: true),
            e("framre_kna_sway_topp", "cm", T.top, tecken: true, plus: T.target),
            e("framre_kna_sway_traff", "cm", T.impact, tecken: true, plus: T.target),
            e("framre_kna_sway_finish", "cm", T.finish, tecken: true, plus: T.target),
            e("bakre_kna_sway_topp", "cm", T.top, tecken: true, plus: T.target),
            e("bakre_kna_sway_traff", "cm", T.impact, tecken: true, plus: T.target),
            e("bakre_kna_sway_finish", "cm", T.finish, tecken: true, plus: T.target),
            e("genomsving_s", "s", T.impactToFinish),
            e("handfart_max", "cm/s", T.downswing),
            e("handfart_max_fore_traff_ms", "ms", T.beforeImpact),
            e("framre_arm_vinkelfart_max", "°/s", T.downswing),
            e("backen_sway_topp", "cm", T.top, tecken: true, plus: T.target),
            e("backen_resa_framat", "cm", T.topToImpact, plus: T.target),
            e("backen_thrust_traff", "cm", T.impact, tecken: true, plus: T.ball),
            e("brost_bojning_tapp", "°", T.addressToImpact, tecken: true, geometri: .bojning),
            e("tempo", ": 1", T.startTopImpact, vy: T.ljud, geometri: .tempo),
            e("sway_gap_traff", "cm", T.impact, tecken: true, plus: T.target),
            e("axellinje_lutning_traff", "°", T.impact, tecken: true),
            e("sidbojning_topp", "°", T.top, tecken: true),
            e("framre_armbage_efter_traff", "°", T.afterImpact),
            e("bakre_armbage_topp", "°", T.top, tecken: true),
            e("handbana", "cm", T.downswing, tecken: true),
            e("framre_armbage_topp", "°", T.top),
            // Granskningens mått vid en position (katalogens `matt`, METOD M29).
            e("brost_bojning_adress", "°", T.address),
            e("bakre_kna_adress", "°", T.address),
            e("stans_bredd", "", T.address),
            e("axellinje_lutning_adress", "°", T.address, tecken: true),
            e("hoftlinje_lutning_adress", "°", T.address, tecken: true),
            e("backen_sway_p3", "cm", "P3", tecken: true, plus: T.target),
            e("framre_armbage_p3", "°", "P3"),
            e("backen_resa_p5", "cm", "P5", tecken: true, plus: T.target),
            e("hander_fore_adress_traff", "cm", T.impact, tecken: true, plus: T.target),
            e("huvud_backen_finish", "cm", T.finish, tecken: true, plus: T.target),
        ])
    }()

    /// Etiketten för ett mått. Ett mått utan rad visas med sitt nyckelnamn, så att
    /// det syns i provet och får en rad.
    /// Decimalerna följer PC:ns regel (Avrundning); ett okänt mått får enheten ur regeln.
    public static func etikett(_ matt: String) -> Mattetikett {
        tabell[matt] ?? Mattetikett(matt, Avrundning.enhet(matt), Avrundning.decimaler(matt), "")
    }

    /// "FO", "DTL" eller "FO+DTL" ur katalogens vy.
    public static func vy(_ katalogvy: String) -> String {
        switch katalogvy {
        case "fo": return "FO"
        case "dtl": return "DTL"
        default: return "FO+DTL"
        }
    }

    /// Kortets översta rad: "FO · top · + to target".
    public static func rubrik(_ fel: Katalog.Fel) -> String {
        let e = etikett(fel.matt)
        var delar = [e.vy ?? vy(fel.vy)]
        if !e.fas.isEmpty { delar.append(e.fas) }
        if let p = e.plus { delar.append(Texter.plus(p)) }
        return delar.joined(separator: " · ")
    }
}
