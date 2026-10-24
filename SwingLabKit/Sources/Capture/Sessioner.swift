import Foundation
import Swing

/// En rad i sessionslistan (PLAN S4e, BESLUT B64): vyn, dagen och klockslaget, klubban och
/// svingarna, och om passet hör ihop med en andra telefon. Byggs ur passet, så att listan kan
/// läsas utanför huvudtråden och provas på Linux. METOD MS20
public struct Sessionsrad: Identifiable, Equatable, Sendable {
    public let id: String
    public let vy: Vy
    /// "Down the line", "Face on"
    public let vyNamn: String
    /// "Sat, Jan 9 · 18:05"
    public let tid: String
    /// "7i", eller "7i, PW" när serierna har olika klubbor.
    public let klubba: String
    /// Svingarna som räknas (som i sessionen); nil = analysen är inte klar.
    public let svingar: Int?
    /// Passet filmades med två telefoner (styr eller följ, BESLUT B21): den andra telefonens
    /// rad står i dess egen lista.
    public let parad: Bool
    /// Den styrandes rad för ett parat pass, "Paired" (S6g, BESLUT B82): passet har båda vyerna
    /// och växlar mellan dem inne i passet. Följaren har kvar sin egen rad med sin vy.
    public let styr: Bool
    /// Raden i ord för VoiceOver.
    public let upplasning: String

    public init(_ p: PassState) {
        id = p.id
        vy = p.setup.view
        styr = p.setup.role == .lead
        vyNamn = styr ? Texter.paradRubrik : Texter.vyNamn(p.setup.view)
        let dag = Tal.dag(p.created), klocka = Tal.klocka(p.created)
        tid = dag + Texter.skilje + klocka
        klubba = Self.klubbor(p).map(PassSetup.clubLabel).joined(separator: ", ")
        svingar = Self.svingar(p)
        parad = p.setup.role != .solo
        upplasning = styr
            ? Texter.sessionsrad(vy: vyNamn + ", " + Texter.badaVyerna, dag: dag, klocka: klocka, klubba: klubba,
                                 svingar: svingar, parad: false)
            : Texter.sessionsrad(vy: vyNamn, dag: dag, klocka: klocka, klubba: klubba, svingar: svingar, parad: parad)
    }

    /// Seriernas klubbor i ordning, utan dubbletter; uppställningens när passet saknar serier.
    static func klubbor(_ p: PassState) -> [String] {
        var ut: [String] = []
        for s in p.series where !ut.contains(s.club) { ut.append(s.club) }
        return ut.isEmpty ? [p.setup.club] : ut
    }

    /// Svingarna som räknas i passets mått (`countedSwings`: sving eller osäker, mätt och inte
    /// "Detection wrong"), samma tal som sessionens rad ("7i · 8"), men först när analysen är klar
    /// (`ShotPlan.next == nil`, som när Analyze försvinner); 0 för ett pass utan klick; annars nil
    /// ("Not analyzed"). METOD MS20
    static func svingar(_ p: PassState) -> Int? {
        if p.shots.isEmpty { return p.clickCount == 0 ? 0 : nil }
        return ShotPlan.next(p) == nil ? p.countedSwings.count : nil
    }

    /// Raderna, senaste först (som passens index).
    public static func rader(_ passes: [PassState]) -> [Sessionsrad] {
        passes.sorted { ($0.created, $0.id) > ($1.created, $1.id) }.map(Sessionsrad.init)
    }
}
