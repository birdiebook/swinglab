import Foundation

/// P-positionerna i en sving (BESLUT B32): P1 Adress, P3, P4 Topp, P5, P7 Träff,
/// P9 och P10 Finish, som tider i s. P3, P5 och P9 saknas (nil) när armen aldrig
/// blir vågrät; de gissas aldrig. P2, P6 och P8 kräver klubban (PLAN S7).
/// Samma definitioner som tools/pc/positioner.py. METOD M28
public struct Positioner: Equatable, Sendable {
    /// Positionerna i svingens ordning, som katalogens `positioner` (docs/FORMAT.md).
    public static let namn = ["P1", "P3", "P4", "P5", "P7", "P9", "P10"]
    /// P9 söks från träffen till finishens fönster (1,0 s). METOD M28
    public static let p9EfterS = Faser.finish.fran

    /// Adressens fönster, tiden i fönstrets mitt (måtten är fönstrets medel).
    public let p1: Double
    /// Främre armen vågrät på väg upp.
    public let p3: Double?
    /// Toppen.
    public let p4: Double
    /// Främre armen vågrät på väg ner.
    public let p5: Double?
    /// Träffen (klicket).
    public let p7: Double
    /// Bakre armen vågrät efter träffen.
    public let p9: Double?
    /// Finishens fönster, tiden i fönstrets mitt.
    public let p10: Double

    /// Tiden för en position ur `namn`, nil när den saknas eller namnet är okänt.
    public func tid(_ position: String) -> Double? {
        switch position {
        case "P1": return p1
        case "P3": return p3
        case "P4": return p4
        case "P5": return p5
        case "P7": return p7
        case "P9": return p9
        case "P10": return p10
        default: return nil
        }
    }

    /// α per ruta i grader: armen axel → handled mot vågrätt i bild, + när
    /// handleden står över axeln (y nedåt). NaN där en av punkterna saknas.
    /// Riktningen i x räknas inte: vågrät åt vilket håll som helst. METOD M28
    public static func armensVinkel(axel: [Punkt], handled: [Punkt]) -> [Double] {
        zip(axel, handled).map { a, h in
            Matt.grader(atan2(a.y - h.y, abs(h.x - a.x)))
        }
    }

    /// Tiderna då α passerar 0 mellan fran och till, i tidsordning. Uppåt:
    /// α0 < 0 ≤ α1, nedåt: α0 ≥ 0 > α1, mellan två rutor i följd där armen syns,
    /// båda inom fönstret och högst maxLuckaS isär (METOD M3), linjärt mellan
    /// dem. METOD M28
    public static func passager(_ t: [Double], _ a: [Double], fran: Double, till: Double, uppat: Bool) -> [Double] {
        var ut: [Double] = []
        var forra: Int? = nil
        for k in t.indices where a[k].isFinite && t[k] >= fran && t[k] <= till {
            defer { forra = k }
            guard let k0 = forra, t[k] - t[k0] <= Faser.maxLuckaS else { continue }
            let a0 = a[k0], a1 = a[k]
            if uppat ? (a0 < 0 && 0 <= a1) : (a0 >= 0 && 0 > a1) {
                ut.append(t[k0] + (0.0 - a0) / (a1 - a0) * (t[k] - t[k0]))
            }
        }
        return ut
    }

    /// Positionerna ur faserna och armarnas vinkel per ruta (armensVinkel). METOD M28
    ///
    /// P3 = sista passagen uppåt för främre armen från adressens slut till toppen,
    /// P5 = första nedåt från toppen till träffen, P9 = första uppåt för bakre
    /// armen från träffen och 1,0 s fram.
    public static func hitta(_ t: [Double], _ f: Fastider, framre: [Double], bakre: [Double]) -> Positioner {
        let p3 = passager(t, framre, fran: f.adressTill, till: f.topp, uppat: true)
        let p5 = passager(t, framre, fran: f.topp, till: f.traff, uppat: false)
        let p9 = passager(t, bakre, fran: f.traff, till: f.traff + p9EfterS, uppat: true)
        return Positioner(p1: (f.adressFran + f.adressTill) / 2, p3: p3.last, p4: f.topp, p5: p5.first,
                          p7: f.traff, p9: p9.first, p10: (f.finishFran + f.finishTill) / 2)
    }
}
