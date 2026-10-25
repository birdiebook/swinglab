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
    /// Infobladet som ett tryck på raden öppnar (BESLUT B41).
    public var info: Infoblad? = nil
    /// Läget mot bandet eller den egna baslinjen: prick, ring eller pil (METOD M62, BESLUT B87).
    public var lage: Bandlage = .ingen

    /// Raden i ord för VoiceOver.
    public var upplasning: String {
        var d = [varde == "—" ? namn : "\(namn) \(Tal.medEnhet(varde, enhet))"]
        if let u = under { d.append(u) }
        if let l = lage.upplasning(baslinje: spann?.arBaslinje ?? false) { d.append(l) }
        if let s = spann, !s.upplasning.isEmpty { d.append(s.upplasning) }
        if let m = markning { d.append(m.upplasning) }
        return d.joined(separator: ", ")
    }
}

/// Måtten vid en position (BESLUT B32): katalogens fel och mått vars `positioner` har den,
/// i den vy som spelas (och de som mäts i båda, `Vyfilter`, BESLUT B64), i katalogens ordning
/// (felen först). Dom (b) visas inte (`visas: false`, BESLUT B86) utom ett fel som övas; ett fel
/// med klubbans källa tar klubbmåttet på slag där klubban är markerad (BESLUT B88). METOD M29, M62
public enum Positionsmatt {
    /// `varden` = slagets mått, `baslinje` = måttens värden i tidigare pass (den egna
    /// baslinjen, METOD M27), `ovas` = felen i Att jobba på, `klubba` = passets klubba (järnets
    /// band bara på järnpass, BESLUT B86; nil = järn).
    /// `flyktpunktAntagen` = bakifrån utan riktpinne: källraden för across/laid off säger att
    /// flyktpunkten är antagen (METOD M48).
    public static func rader(_ k: Katalog, vy: Vy, position: String, varden: [String: Double],
                             baslinje: [String: [Double]] = [:], ovas: Set<String> = [],
                             flyktpunktAntagen: Bool = false, klubba: String? = nil) -> [Positionsrad] {
        var ut: [Positionsrad] = []
        var tagna = Set<String>()
        for f0 in k.fel where Vyfilter.visas(f0.vy, i: vy) && f0.visas(ovas: ovas) {
            let markerad = f0.klubba.map { varden[$0.matt] != nil } ?? false
            let f = f0.medKalla(klubbaMarkerad: markerad).medKlubba(klubba)
            if f.matt != f0.matt { tagna.insert(f.matt) }
            guard f.positioner.contains(position) else { continue }
            var r = rad(f.matt, varden: varden, gront: f.gront, golv: f.golv, samre: f.samre, aktiv: f.aktiv,
                        markning: Markning.fran(f), baslinje: baslinje[f.matt] ?? [],
                        under: f.fas == "efter_traff" ? Texter.afterImpact : nil)
            r.ovas = ovas.contains(f.id)
            r.info = Infoblad(f, namn: r.namn)
            ut.append(r)
        }
        for m in k.matt where m.visas && Vyfilter.visas(m.vy, i: vy) && m.positioner.contains(position)
            && !tagna.contains(m.matt) {
            // Ett mått per position (skaftets vinkel, METOD M46) har positionens värde. Klubbans
            // mått visas bara på ett slag där klubban är markerad (S7a): inget "—" på alla andra.
            let nyckel = Klubba.nyckel(m.matt, position)
            let arKlubba = Vy(rawValue: m.vy).map { Klubba.katalognamn($0).contains(m.matt) } ?? false
            if arKlubba && varden[nyckel] == nil { continue }
            var r = rad(nyckel, etikett: m.matt, varden: varden, gront: m.band(klubba), golv: m.golv, samre: m.samre,
                        aktiv: true, markning: Markning.fran(m, klubba: klubba), baslinje: baslinje[nyckel] ?? [],
                        under: nil)
            r.ovas = m.fel.map { ovas.contains($0) } ?? false
            r.info = Infoblad(m, namn: r.namn)
            if flyktpunktAntagen, Klubba.flyktpunktsmatt.contains(m.matt), let b = r.info {
                r.info = Infoblad(namn: b.namn, vad: b.vad, varfor: b.varfor, tecken: b.tecken,
                                  kalla: "\(b.kalla), \(Texter.flyktpunktAntagen)")
            }
            ut.append(r)
        }
        return ut
    }

    static func rad(_ matt: String, etikett: String? = nil, varden: [String: Double], gront: [Double?]?, golv: Double?,
                    samre: String?, aktiv: Bool, markning: Markning?, baslinje: [Double], under: String?) -> Positionsrad {
        let e = Etiketter.etikett(etikett ?? matt)
        let enhet = e.enhet == ": 1" ? "" : e.enhet
        guard aktiv, let v = varden[matt], v.isFinite else {
            return Positionsrad(matt: matt, namn: e.namn, under: under, markning: markning, varde: "—", enhet: enhet,
                                spann: nil)
        }
        let bas = Baslinje.spann(baslinje)
        let spann = gront == nil && bas == nil
            ? nil
            : Spann(nu: v, spridning: nil, forra: nil, gront: gront, baslinje: bas, decimaler: e.decimaler, enhet: enhet)
        var r = Positionsrad(matt: matt, namn: e.namn, under: under, markning: markning,
                             varde: Mattkort.text(Avrundning.avrunda(matt, v), e), enhet: enhet, spann: spann)
        // Läget på det visade (avrundade) talet. METOD M62
        r.lage = Bandlage.lage(Avrundning.avrunda(matt, v) ?? v, gront: gront, golv: golv, samre: samre,
                               baslinje: baslinje, klubba: nil)
        return r
    }
}
