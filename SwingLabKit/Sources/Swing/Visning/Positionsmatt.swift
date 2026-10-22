import Foundation

/// En rad under videon i granskningen: ett mått vid en position för ett slag (BESLUT B32,
/// METOD M29), med namnet, märkningen, talet och spannet. Det du övar på bär accenten (B31).
public struct Positionsrad: Identifiable, Equatable, Sendable {
    public var id: String { matt }
    public let matt: String
    public let namn: String
    /// "after impact" när måttet inte räknas i positionens ögonblick (chicken wing vid P9,
    /// METOD M29); nil annars.
    public let under: String?
    public let markning: Markning?
    /// "−2.4"; "—" när måttet saknas eller är avstängt.
    public let varde: String
    public let enhet: String
    /// Gränsen eller den egna baslinjen med slagets värde; nil utan någon av dem.
    public let spann: Spann?
    public var ovas = false

    /// Raden i ord för VoiceOver.
    public var upplasning: String {
        var d = [varde == "—" ? namn : "\(namn) \(Tal.medEnhet(varde, enhet))"]
        if let u = under { d.append(u) }
        if let s = spann, !s.upplasning.isEmpty { d.append(s.upplasning) }
        if let m = markning { d.append(m.upplasning) }
        return d.joined(separator: ", ")
    }
}

/// Måtten vid en position (BESLUT B32): katalogens fel och mått vars `positioner` har den,
/// i den vy som spelas, i katalogens ordning (felen först). METOD M29
public enum Positionsmatt {
    /// `varden` = slagets mått, `baslinje` = måttens värden i tidigare pass (den egna
    /// baslinjen, METOD M27), `ovas` = felen i Att jobba på.
    public static func rader(_ k: Katalog, vy: Vy, position: String, varden: [String: Double],
                             baslinje: [String: [Double]] = [:], ovas: Set<String> = []) -> [Positionsrad] {
        var ut: [Positionsrad] = []
        for f in k.fel where f.vy == vy.rawValue && f.positioner.contains(position) {
            var r = rad(f.matt, varden: varden, gront: f.gront, aktiv: f.aktiv, markning: Markning.fran(f),
                        baslinje: baslinje[f.matt] ?? [], under: f.fas == "efter_traff" ? Texter.afterImpact : nil)
            r.ovas = ovas.contains(f.id)
            ut.append(r)
        }
        for m in k.matt where m.vy == vy.rawValue && m.positioner.contains(position) {
            var r = rad(m.matt, varden: varden, gront: nil, aktiv: true, markning: .egen,
                        baslinje: baslinje[m.matt] ?? [], under: nil)
            r.ovas = m.fel.map { ovas.contains($0) } ?? false
            ut.append(r)
        }
        return ut
    }

    static func rad(_ matt: String, varden: [String: Double], gront: [Double?]?, aktiv: Bool, markning: Markning?,
                    baslinje: [Double], under: String?) -> Positionsrad {
        let e = Etiketter.etikett(matt)
        let enhet = e.enhet == ": 1" ? "" : e.enhet
        guard aktiv, let v = varden[matt], v.isFinite else {
            return Positionsrad(matt: matt, namn: e.namn, under: under, markning: markning, varde: "—", enhet: enhet,
                                spann: nil)
        }
        let bas = Baslinje.spann(baslinje)
        let spann = gront == nil && bas == nil
            ? nil
            : Spann(nu: v, spridning: nil, forra: nil, gront: gront, baslinje: bas, decimaler: e.decimaler, enhet: enhet)
        return Positionsrad(matt: matt, namn: e.namn, under: under, markning: markning,
                            varde: Mattkort.text(Avrundning.avrunda(matt, v), e), enhet: enhet, spann: spann)
    }
}
