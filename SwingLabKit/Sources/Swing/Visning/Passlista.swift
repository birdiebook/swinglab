import Foundation

/// Läget som ordning (PLAN S4h, research 8 punkt 2): rött först, sedan gult, grönt och sist det
/// utan läge ("Your usual" utan avvikelse, ett mått utan band). Inom varje grupp står korten och
/// raderna kvar i katalogens ordning (sorteringen är stabil). METOD M63
public enum Lageordning {
    /// 0 rött, 1 gult, 2 grönt, 3 utan läge.
    public static func grupp(_ l: Bandlage) -> Int {
        switch l.lage {
        case .rod: return 0
        case .gul: return 1
        case .gron: return 2
        case .ingen: return 3
        }
    }

    /// `x` i lägets ordning, stabilt: lika grupp behåller sin plats inbördes.
    public static func sortera<T>(_ x: [T], lage: (T) -> Bandlage) -> [T] {
        x.enumerated()
            .sorted { a, b in
                let ga = grupp(lage(a.element)), gb = grupp(lage(b.element))
                return ga != gb ? ga < gb : a.offset < b.offset
            }
            .map { $0.element }
    }

    /// Granskningens rader vid en position, i samma ordning som passets kort.
    public static func sortera(_ rader: [Positionsrad]) -> [Positionsrad] { sortera(rader) { $0.lage } }
}

/// Passets skärm i den ordning spelaren läser den (PLAN S4h, research 8 punkt 2 och 3, BESLUT B94):
/// överst ett kort med det viktiga, sedan korten efter läget, och sist "More measures (n)" med de
/// mått som inte kan säga bra eller dåligt (VISION: ett mått som visas ska kunna säga bra eller
/// dåligt). Inget tas bort: de dolda korten ligger ett tryck bort, och urklippet och exporten
/// byggs inte av den här listan. METOD M63
public struct Passlista: Equatable, Sendable {
    /// Det överst: Focus (måtten som övas, i den här vyn) eller de röda måtten; nil när allt är
    /// grönt eller gult och inget övas.
    public enum Topp: Equatable, Sendable {
        case focus([Mattkort])
        case roda([Mattkort])

        public var kort: [Mattkort] {
            switch self {
            case let .focus(k), let .roda(k): return k
            }
        }

        /// "Focus" eller "Outside range", ovanför raden.
        public var rubrik: String {
            switch self {
            case .focus: return Texter.fokus
            case .roda: return Texter.utanforBandet
            }
        }
    }

    public let topp: Topp?
    /// Korten som visas: rött, gult, grönt och sist utan läge (bara det som övas), i katalogens
    /// ordning inom varje grupp.
    public let kort: [Mattkort]
    /// Korten under "More measures (n)": utan läge, oprövade eller utan tal. I katalogens ordning.
    public let fler: [Mattkort]

    /// Ett kort kan säga bra eller dåligt och visas: det har ett läge (grönt, gult eller rött mot
    /// bandet, eller rött mot den egna baslinjen åt måttets sämre håll), ett tal och är prövat på
    /// telefonen. Ett kort som övas visas alltid (BESLUT B86: det Claude valt syns). METOD M63
    public static func visas(_ k: Mattkort) -> Bool {
        if k.ovas { return true }
        return k.lage.lage != .ingen && k.varde != "—" && k.markning != .oprovad
    }

    public init(_ alla: [Mattkort]) {
        let synliga = alla.filter(Self.visas)
        kort = Lageordning.sortera(synliga) { $0.lage }
        fler = alla.filter { !Self.visas($0) }
        let ovas = kort.filter(\.ovas)
        let roda = kort.filter { $0.lage.lage == .rod }
        if !ovas.isEmpty {
            topp = .focus(ovas)
        } else if !roda.isEmpty {
            topp = .roda(roda)
        } else {
            topp = nil
        }
    }

    /// Raden under korten: "More measures (3)"; nil när inget är dolt.
    public var flerRad: String? { fler.isEmpty ? nil : Texter.flerMatt(fler.count) }

    /// Det översta kortet i ord för VoiceOver: "Focus: Hip sway −3.0 cm, below range".
    public var toppUpplasning: String? {
        guard let t = topp else { return nil }
        let delar = t.kort.map { k -> String in
            var d = k.varde == "—" ? k.namn : "\(k.namn) \(Tal.medEnhet(k.varde, k.enhet == ": 1" ? "" : k.enhet))"
            if let l = k.lage.upplasning(baslinje: k.spann?.arBaslinje ?? false) { d += ", \(l)" }
            return d
        }
        return "\(t.rubrik): " + delar.joined(separator: "; ")
    }
}

extension Passvisning {
    /// Sessionens vy i läsordningen (PLAN S4h): toppen, korten efter läget och de dolda.
    public func lista(i vy: Vy) -> Passlista { Passlista(kort(i: vy)) }

    /// Filtrets kort i läsordningen.
    public func lista(_ f: Filter) -> Passlista { Passlista(filtrerat(f)) }
}

/// Bandets nyckel (PLAN S4h, research 8 punkt 4): vad varje tecken på spannet betyder, en gång,
/// ett tryck bort (ett tryck på bandet eller ⓘ). Appen ritar tecknet; texten står här. METOD M63
public enum Bandnyckel {
    public enum Tecken: String, CaseIterable, Sendable {
        /// Det grå fältet: bra-området.
        case bandet
        /// Grön prick, gul ring och röd triangel (BESLUT B87).
        case inne, nara, ute
        /// Den vita linjen: passets kvartiler (METOD M25).
        case slagen
        /// Det grå strecket: förra passets median.
        case forra
        /// Ramen: den egna baslinjen (METOD M27).
        case vanligt
    }

    public static let rubrik = Texter.nyckelRubrik

    public static func text(_ t: Tecken) -> String {
        switch t {
        case .bandet: return Texter.nyckelBandet
        case .inne: return Texter.nyckelInne
        case .nara: return Texter.nyckelNara
        case .ute: return Texter.nyckelUte
        case .slagen: return Texter.nyckelSlagen
        case .forra: return Texter.nyckelForra
        case .vanligt: return Texter.nyckelVanligt
        }
    }

    /// Nyckelns rader i ordning: bandet och lägena först, sedan linjerna.
    public static var poster: [(tecken: Tecken, text: String)] { Tecken.allCases.map { ($0, text($0)) } }
}
