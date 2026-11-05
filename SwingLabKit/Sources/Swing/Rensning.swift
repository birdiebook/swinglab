import Foundation

/// Vad rensningen gjorde med ett slags leder. METOD M53
public struct Rensning: Equatable, Sendable {
    /// Grupp → antal rutor där sidorna byttes tillbaka.
    public var byten: [String: Int] = [:]
    /// Grupp → växlingar utan partner inom `Rensa.byteMaxS` (inte rättade).
    public var bytenOklara: [String: Int] = [:]
    /// Led → antal rutor som togs bort som spik.
    public var spikar: [String: Int] = [:]

    public init(byten: [String: Int] = [:], bytenOklara: [String: Int] = [:], spikar: [String: Int] = [:]) {
        self.byten = byten
        self.bytenOklara = bytenOklara
        self.spikar = spikar
    }

    /// Ingenting rensades.
    public var tom: Bool { byten.isEmpty && bytenOklara.isEmpty && spikar.isEmpty }
}

/// Rensningen av lederna före mätningen: byten mellan vänster och höger, och spikar.
/// Samma som `tools/pc/rensa.py` (PLAN S3b lager 1). METOD M53
///
/// - **Bytet:** i en grupp ligger rutans främre punkter närmare förra rutans bakre än sina
///   egna, och korsat är billigare än halva det raka, med sidorna isär. Ett kort byte (ut
///   och tillbaka inom 0,25 s) byts tillbaka; en ensam växling räknas men rättas inte.
/// - **Spiken:** en punkt hoppar ut fortare än leden kan röra sig och kommer tillbaka lika
///   fort inom tre rutor, åt motsatt håll. Rutorna i spiken räknas som saknade.
public enum Rensa {
    /// Högsta rimliga fart per led i bildens plan, m/s. METOD M53
    public static let fartMax: [Led: Double] = [
        .nasa: 6, .axelF: 6, .axelB: 6, .armbageF: 12, .armbageB: 12, .handledF: 15, .handledB: 15,
        .hoftF: 4, .hoftB: 4, .knaF: 5, .knaB: 5, .fotledF: 5, .fotledB: 5,
    ]
    /// En spik är högst så många rutor lång. METOD M53
    public static let spikMaxRutor = 3
    /// Ut och tillbaka = stegen mer än 120° isär. METOD M53
    public static let vandningCos = -0.5
    /// Steget tillbaka är minst halva steget ut. METOD M53
    public static let tillbakaAndel = 0.5
    /// Steget ut är minst så många bål (skakningen är inte en spik). METOD M53
    public static let spikMinBal = 0.25
    /// Längre mellan två rutor är en lucka, inget steg. METOD M53
    public static let maxStegS = 0.05
    /// Korsat under halva det raka = bytt. METOD M53
    public static let byteAndel = 0.5
    /// Sidorna minst så många bål isär, annars prövas inget byte. METOD M53
    public static let byteSepMin = 0.2
    /// Ett byte är högst så långt; längre rättas inte. METOD M53
    public static let byteMaxS = 0.25
    /// Bålen som farterna räknas om med (inte spelarens), så att faserna inte beror på
    /// längden. METOD M53
    public static let standardLangdM = 1.80

    /// Punkterna som byter sida tillsammans, i Pythons ordning. METOD M53
    public static let grupper: [(namn: String, par: [(Led, Led)])] = [
        ("armar", [(.armbageF, .armbageB), (.handledF, .handledB)]),
        ("ben", [(.knaF, .knaB), (.fotledF, .fotledB)]),
        ("hofter", [(.hoftF, .hoftB)]),
        ("axlar", [(.axelF, .axelB)]),
    ]

    /// Ledens namn som i Python (`format.LEDER`).
    public static let ledNamn = ["nasa", "axel_f", "axel_b", "armbage_f", "armbage_b", "handled_f", "handled_b",
                                 "hoft_f", "hoft_b", "kna_f", "kna_b", "fotled_f", "fotled_b"]

    /// Bålen i bild: medianen av avståndet axelmitt–höftmitt över rutorna där alla fyra
    /// syns, px (två mittersta medlas vid jämnt antal, som numpy). NaN utan sådana rutor. METOD M53
    public static func balPx(_ leder: [[Punkt]]) -> Double {
        var d: [Double] = []
        for k in leder[0].indices {
            let c = Punkt.mitt(leder[Led.axelF.rawValue][k], leder[Led.axelB.rawValue][k])
            let p = Punkt.mitt(leder[Led.hoftF.rawValue][k], leder[Led.hoftB.rawValue][k])
            let l = (c - p).langd
            if l.isFinite { d.append(l) }
        }
        guard !d.isEmpty else { return .nan }
        d.sort()
        let n = d.count
        return n % 2 == 1 ? d[n / 2] : (d[n / 2 - 1] + d[n / 2]) / 2
    }

    /// Byter tillbaka korta byten i `leder`. Ger (grupp → bytta rutor, grupp → växlingar
    /// utan partner). METOD M53
    static func byten(_ t: [Double], _ leder: inout [[Punkt]], u: Double) -> ([String: Int], [String: Int]) {
        var rattade: [String: Int] = [:], oklara: [String: Int] = [:]
        for (namn, par) in grupper {
            let idx = t.indices.filter { k in par.allSatisfy { leder[$0.0.rawValue][k].hel && leder[$0.1.rawValue][k].hel } }
            var vaxlingar: [Int] = []
            if idx.count > 1 {
                for i in 1..<idx.count {
                    let k = idx[i], q = idx[i - 1]
                    if t[k] - t[q] > maxStegS { continue }
                    var sep = -Double.infinity, rakt = 0.0, kors = 0.0
                    for (f, b) in par {
                        let fq = leder[f.rawValue][q], bq = leder[b.rawValue][q]
                        let fk = leder[f.rawValue][k], bk = leder[b.rawValue][k]
                        sep = max(sep, (fq - bq).langd)
                        rakt += (fk - fq).langd + (bk - bq).langd
                        kors += (fk - bq).langd + (bk - fq).langd
                    }
                    if sep >= byteSepMin * u && kors < byteAndel * rakt {
                        vaxlingar.append(i)
                    }
                }
            }
            var bytta: [Int] = []
            var utan = 0, v = 0
            while v < vaxlingar.count {
                let i0 = vaxlingar[v]
                if v + 1 < vaxlingar.count && t[idx[vaxlingar[v + 1]]] - t[idx[i0]] <= byteMaxS {
                    bytta += idx[i0..<vaxlingar[v + 1]]
                    v += 2
                } else {
                    utan += 1
                    v += 1
                }
            }
            for k in bytta {
                for (f, b) in par {
                    let tmp = leder[f.rawValue][k]
                    leder[f.rawValue][k] = leder[b.rawValue][k]
                    leder[b.rawValue][k] = tmp
                }
            }
            if !bytta.isEmpty { rattade[namn] = bytta.count }
            if utan > 0 { oklara[namn] = utan }
        }
        return (rattade, oklara)
    }

    /// Tar bort spikar i `leder` (rutorna blir saknade). Ger led → borttagna rutor. METOD M53
    static func spikar(_ t: [Double], _ leder: inout [[Punkt]], pxPerM: Double, u: Double) -> [String: Int] {
        var ut: [String: Int] = [:]
        for led in Led.allCases {
            let j = led.rawValue
            let grans = fartMax[led]! * pxPerM
            let idx = t.indices.filter { leder[j][$0].hel }
            let p = idx.map { leder[j][$0] }
            var bort: [Int] = []
            var i = 1
            while i < idx.count {
                let dt = t[idx[i]] - t[idx[i - 1]]
                let utSteg = p[i] - p[i - 1]
                let lu = utSteg.langd
                if dt > maxStegS || !(lu > grans * dt && lu >= spikMinBal * u) {
                    i += 1
                    continue
                }
                var hittad: Int? = nil
                let sista = min(i + spikMaxRutor, idx.count - 1)
                if i + 1 <= sista {
                    for m in (i + 1)...sista {
                        let dm = t[idx[m]] - t[idx[m - 1]]
                        if dm > maxStegS { break }
                        let tillbaka = p[m] - p[m - 1]
                        let lt = tillbaka.langd
                        let cos = lt > 0 ? (utSteg.x * tillbaka.x + utSteg.y * tillbaka.y) / (lu * lt) : 1.0
                        if lt > grans * dm && cos < vandningCos && lt >= tillbakaAndel * lu {
                            hittad = m
                            break
                        }
                    }
                }
                guard let h = hittad else {
                    i += 1
                    continue
                }
                bort += idx[i..<h]
                i = h + 1
            }
            for k in bort { leder[j][k] = .saknad }
            if !bort.isEmpty { ut[ledNamn[j]] = bort.count }
        }
        return ut
    }

    /// Lederna rensade, och vad som gjordes. Bytena först, så att ett kort byte inte ser
    /// ut som två spikar. Utan bålen i bild görs ingenting. METOD M53
    public static func rensa(_ t: [Double], _ leder: [[Punkt]]) -> ([[Punkt]], Rensning) {
        var ut = leder
        let u = balPx(ut)
        guard u > 0 else { return (ut, Rensning()) }
        let (b, o) = byten(t, &ut, u: u)
        let s = spikar(t, &ut, pxPerM: u / (Matt.bal * standardLangdM), u: u)
        return (ut, Rensning(byten: b, bytenOklara: o, spikar: s))
    }
}
