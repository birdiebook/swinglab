import Foundation
import Swing

// Inspelningens skärm (PLAN S2j, BESLUT B85, METOD MS32): det som syns under inspelningen är
// bara det som kräver ställningstagande. Statusen överst (kopplad, söker, tappad eller REC med
// tiden och svingarna), en varning i taget när den kräver handling, och lutningen mitt på
// skärmen bara när den är för stor. Resten står bakom kugghjulet. Logiken här, så att den
// prövas på Linux (`InspelningslageTests`); appen ger bara värdena.

/// Den andra telefonen som inspelningen ser den.
public struct AndraTelefonen: Equatable, Sendable {
    public var vy: Vy
    public var kopplad: Bool
    /// Den andra telefonen spelar in (bara den styrande vet det: följarna rapporterar).
    public var inspelar: Bool

    public init(vy: Vy, kopplad: Bool, inspelar: Bool) {
        self.vy = vy
        self.kopplad = kopplad
        self.inspelar = inspelar
    }
}

/// Statusen överst i mitten. METOD MS32
public enum InspelningsStatus: Equatable, Sendable {
    /// Ensam telefon, eller lokalt nätverk av (varningen säger det): ingen statuspill.
    case ingen
    case soker
    case kopplad
    case tappad
    /// Serien spelas in: sekunder sedan start och svingarna hörda hittills (nil = okänt).
    case spelarIn(sekunder: Int, svingar: Int?)

    public static func av(roll: LinkRole, inspelar: Bool, sekunder: Double, svingar: Int?,
                          andra: [AndraTelefonen], natAv: Bool) -> InspelningsStatus {
        if inspelar {
            let s = sekunder.isFinite ? max(0, Int(sekunder.rounded(.down))) : 0
            return .spelarIn(sekunder: s, svingar: svingar)
        }
        guard roll != .solo, !natAv else { return .ingen }
        if andra.isEmpty { return .soker }
        // En tappad telefon kräver handling, också när en annan är kopplad.
        return andra.contains { !$0.kopplad } ? .tappad : .kopplad
    }

    /// Texten i pillen ("Connected", "REC 0:42 · 3 swings"); nil = ingen pill.
    public var text: String? {
        switch self {
        case .ingen: return nil
        case .soker: return Texter.inspSoker
        case .kopplad: return Texter.inspKopplad
        case .tappad: return Texter.inspTappad
        case let .spelarIn(s, n): return Texter.inspRec(Taltext.duration(Double(s)), svingar: n)
        }
    }
}

/// Allt varningarna väljs ur. Appen fyller i det kameran, kopplingen och disken säger.
public struct Inspelningsfakta: Equatable, Sendable {
    public var roll: LinkRole = .solo
    public var vy: Vy = .dtl
    public var inspelar = false
    /// Kamerans eller lagringens fel, redan i ord ("Interrupted.").
    public var problem: String?
    public var andra: [AndraTelefonen] = []
    /// Ur `AndraStoppadeVakt`.
    public var andraStoppade = false
    public var natAv = false
    /// Passet har inga serier än: vyn kan bytas (BESLUT B83).
    public var kanByta = false
    public var tryck: Pressure = .nominal
    public var ledigaByte: Int64?
    public var mikrofonAv = false
    public var externMikrofon = false
    /// Rutnätets frekvens som ställdes in (0 = inte än) och om den når 240 (MS1).
    public var bildfrekvens: Double = 0
    public var narOnskad = true

    public init(roll: LinkRole = .solo, vy: Vy = .dtl, inspelar: Bool = false) {
        self.roll = roll
        self.vy = vy
        self.inspelar = inspelar
    }
}

/// En varning som kräver handling: en i taget, i ordningen nedan. Det som bara är information
/// (värmen under kritisk, frekvensen när den är rätt, parningens restfel) står i kugghjulet.
/// METOD MS32
public enum InspelningsVarning: Equatable, Sendable {
    case problem(String)
    case andraStoppade
    case andraTappad
    case sammaVy(Vy, kanByta: Bool)
    case lokaltNatAv
    case varme(Pressure)
    case lagring
    case mikrofonAv
    case externMikrofon
    case bildfrekvens(Int)

    /// Alla varningar som gäller, viktigast först.
    public static func alla(_ f: Inspelningsfakta) -> [InspelningsVarning] {
        var v: [InspelningsVarning] = []
        if let p = f.problem, !p.isEmpty { v.append(.problem(p)) }
        let kopplade = f.andra.filter(\.kopplad)
        if f.roll == .lead, f.inspelar, f.andraStoppade { v.append(.andraStoppade) }
        // Utanför serien säger statuspillen "Other phone lost"; under serien visar den REC.
        if f.roll != .solo, f.inspelar, f.andra.contains(where: { !$0.kopplad }) { v.append(.andraTappad) }
        if f.roll != .solo, Vyvakt.sammaVy(egen: f.vy, andra: kopplade.map(\.vy)) {
            v.append(.sammaVy(f.vy, kanByta: f.kanByta && !f.inspelar))
        }
        if f.roll != .solo, f.natAv { v.append(.lokaltNatAv) }
        if f.tryck >= varmeGrans { v.append(.varme(f.tryck)) }
        if !PassStorage.canStart(available: f.ledigaByte) { v.append(.lagring) }
        if f.mikrofonAv { v.append(.mikrofonAv) }
        if f.externMikrofon, !f.mikrofonAv { v.append(.externMikrofon) }
        if f.bildfrekvens > 0, !f.narOnskad { v.append(.bildfrekvens(Int(f.bildfrekvens.rounded()))) }
        return v
    }

    /// Varningen som visas, eller ingen.
    public static func av(_ f: Inspelningsfakta) -> InspelningsVarning? { alla(f).first }

    /// Värmen varnar från kritisk (Apple: systemet sänker kvaliteten; vid shutdown avbryts
    /// sessionen). Under det står den i kugghjulet. METOD MS32
    public static let varmeGrans = Pressure.critical

    public var text: String {
        switch self {
        case let .problem(p): return p
        case .andraStoppade: return Texter.inspAndraStoppade
        case .andraTappad: return Texter.inspTappad
        case let .sammaVy(vy, _): return Texter.sammaVy(vy)
        case .lokaltNatAv: return Texter.inspNatAv
        case let .varme(p): return "\(Receipt.pressureLabel): \(Receipt.pressureName(p))"
        case .lagring: return Texter.inspLagring
        case .mikrofonAv: return Texter.inspMikrofonAv
        case .externMikrofon: return Texter.inspExternMikrofon
        case let .bildfrekvens(n): return Texter.inspBildfrekvens(n, onskad: Int(FormatChoice.wantedRate))
        }
    }

    /// Knappen i varningen: byt den här telefonens vy (BESLUT B83), bara före första serien.
    public var bytTill: Vy? {
        if case let .sammaVy(vy, kanByta) = self, kanByta { return Vyvakt.annan(vy) }
        return nil
    }
}

/// Lutningen mitt på skärmen bara när den är för stor, med hysteres så att den inte blinkar vid
/// gränsen: på över 2,0°, av under 1,5° (lutningen åt sidan). Över 45° från lodlinjen visas den
/// alltid ("Tilt too large for 3D", MS17). METOD MS32
public struct LutningsVisare: Equatable, Sendable {
    public static let pa = 2.0
    public static let av = 1.5

    public private(set) var visas = false

    public init() {}

    /// Nytt prov; svarar om lutningen visas. Utan prov (simulatorn, ett trasigt prov) visas inget.
    @discardableResult
    public mutating func uppdatera(_ l: Lutning?) -> Bool {
        guard let l, l.sida.isFinite else {
            visas = false
            return false
        }
        let s = abs(l.sida)
        if l.forStorFor3D { visas = true }
        else if visas { visas = !(s < Self.av) }
        else { visas = s > Self.pa }
        return visas
    }

    /// Talet i rutan: hela grader, "6°".
    public static func text(_ l: Lutning) -> String { "\(Int(abs(l.sida).rounded()))°" }
}

/// Den styrande ser att den andra telefonen slutade spela in mitt i serien: den har setts spela
/// in och slutat, eller har inte börjat efter `marginal` sekunder (följaren behöver en stund för
/// att starta kameran). Följaren vet inte om den styrande spelar in och varnar aldrig. METOD MS32
public struct AndraStoppadeVakt: Equatable, Sendable {
    public static let marginal = 3.0

    var start: Double?
    var sett = false

    public init() {}

    public mutating func uppdatera(roll: LinkRole, egenInspelar: Bool, tid: Double, andra: [AndraTelefonen]) -> Bool {
        guard roll == .lead, egenInspelar else {
            start = nil
            sett = false
            return false
        }
        if start == nil { start = tid }
        let kopplade = andra.filter(\.kopplad)
        guard !kopplade.isEmpty else { return false }            // tappad: en egen varning
        if kopplade.contains(where: \.inspelar) { sett = true }
        guard kopplade.contains(where: { !$0.inspelar }) else { return false }
        return sett || tid - (start ?? tid) >= Self.marginal
    }
}

/// Svingarna under serien, ur ljudkanalens nivå (`AVCaptureAudioChannel`: toppen och medlet i
/// dB, läst 20 gånger i sekunden): en topp minst `over` dB över medianen av topparna de senaste
/// `fonster` sekunderna är ett klick, högst ett per `minstaAvstand`, och nästa räknas först när
/// toppen fallit `aterstall` dB under gränsen. Bara för pillen; seriens klick hittas i filen
/// (MS4). METOD MS32
public struct LevandeSvingar: Equatable, Sendable {
    public static let over = 20.0
    public static let aterstall = 6.0
    public static let fonster = 3.0
    public static let minstaAvstand = 1.0
    /// Så länge baslinjen måste ha prov innan något räknas, s.
    public static let forsta = 0.5

    public private(set) var antal = 0
    var historik: [Prov] = []
    var senaste = -Double.infinity
    var armerad = true

    struct Prov: Equatable, Sendable {
        var tid: Double
        var topp: Double
    }

    public init() {}

    public mutating func prov(tid: Double, topp: Double) {
        guard tid.isFinite, topp.isFinite else { return }
        historik.removeAll { $0.tid < tid - Self.fonster }
        defer { historik.append(Prov(tid: tid, topp: topp)) }
        guard let forsta = historik.first, tid - forsta.tid >= Self.forsta else { return }
        let s = historik.map(\.topp).sorted()
        let bas = s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
        let over = topp - bas
        if armerad, over >= Self.over, tid - senaste >= Self.minstaAvstand {
            antal += 1
            senaste = tid
            armerad = false
        } else if !armerad, over < Self.over - Self.aterstall {
            armerad = true
        }
    }
}

/// Lagringen i kugghjulet: ungefär så många minuter till golvet som stoppar en serie (MS11), med
/// passets egen storlek per minut när en serie finns, annars 480 MB/min. METOD MS32
public enum Lagringstid {
    public static let antagetMBPerMinut = 480.0

    public static func minuter(ledigt: Int64?, mbPerMinut: Double?) -> Int? {
        guard let ledigt else { return nil }
        let mb = (mbPerMinut ?? 0) > 0 ? mbPerMinut! : antagetMBPerMinut
        let kvar = Double(ledigt - PassStorage.recordingFloor) / 1_000_000
        return max(0, Int((kvar / mb).rounded(.down)))
    }
}
