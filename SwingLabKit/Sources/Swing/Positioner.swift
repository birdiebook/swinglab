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

    /// Handledens höjd över axeln per ruta, px: axel.y − handled.y (y nedåt), + när
    /// handleden står över axeln. 0 = armen vågrät (vinkeln mot vågrätt är 0, åt
    /// vilket håll armen än pekar). NaN där en av punkterna saknas. Nollstället
    /// interpoleras på höjden, inte på vinkeln: atan böjer kurvan när armen är kort
    /// i bild. METOD M28
    public static func armensHojd(axel: [Punkt], handled: [Punkt]) -> [Double] {
        zip(axel, handled).map { a, h in a.hel && h.hel ? a.y - h.y : .nan }
    }

    /// En passage genom vågrätt: tiden, rutparet och riktningen.
    public struct Passage: Equatable, Sendable {
        public let tid: Double
        public let t0: Double
        public let t1: Double
        public let uppat: Bool
    }

    /// Armens passager genom vågrätt mellan fran och till, i tidsordning. Uppåt:
    /// h0 < 0 ≤ h1, nedåt: h0 ≥ 0 > h1, mellan två rutor i följd där armen syns,
    /// båda inom fönstret och högst maxLuckaS isär (METOD M3), linjärt mellan dem.
    /// METOD M28
    public static func passager(_ t: [Double], _ h: [Double], fran: Double, till: Double) -> [Passage] {
        var ut: [Passage] = []
        var forra: Int? = nil
        for k in t.indices where h[k].isFinite && t[k] >= fran && t[k] <= till {
            defer { forra = k }
            guard let k0 = forra, t[k] - t[k0] <= Faser.maxLuckaS else { continue }
            let h0 = h[k0], h1 = h[k]
            let upp = h0 < 0 && 0 <= h1, ned = h0 >= 0 && 0 > h1
            if upp || ned {
                ut.append(Passage(tid: t[k0] + (0.0 - h0) / (h1 - h0) * (t[k] - t[k0]), t0: t[k0], t1: t[k], uppat: upp))
            }
        }
        return ut
    }

    /// Någon ruta i urvalet (på tiden) där armen syns och villkoret gäller höjden.
    static func nagon(_ t: [Double], _ h: [Double], _ urval: (Double) -> Bool, _ villkor: (Double) -> Bool) -> Bool {
        t.indices.contains { urval(t[$0]) && h[$0].isFinite && villkor(h[$0]) }
    }

    /// Positionerna ur faserna och armarnas höjd per ruta (armensHojd). METOD M28
    ///
    /// P3 = sista passagen uppåt för främre armen från adressens slut, med rutparet
    /// över toppen (t0 ≤ toppen); P5 = första nedåt till träffen, med rutparet över
    /// toppen (t1 ≥ toppen); P9 = första uppåt för bakre armen från träffen och 1,0 s
    /// fram. Ingen passage gissas över en lucka: P3 saknas om armen syns under vågrätt
    /// mellan P3 och toppen, P5 om den syns under vågrätt mellan toppen och P5, och P9
    /// om bakre armen syns vid eller över vågrätt mellan träffen och P9.
    public static func hitta(_ t: [Double], _ f: Fastider, framre: [Double], bakre: [Double]) -> Positioner {
        let fr = passager(t, framre, fran: f.adressTill, till: f.traff)
        var p3 = fr.last { $0.uppat && $0.t0 <= f.topp }?.tid
        var p5 = fr.first { !$0.uppat && $0.t1 >= f.topp }?.tid
        if let p = p3, nagon(t, framre, { $0 > p && $0 <= f.topp }, { $0 < 0 }) { p3 = nil }
        if let p = p5, nagon(t, framre, { $0 >= f.topp && $0 < p }, { $0 < 0 }) { p5 = nil }
        var p9 = passager(t, bakre, fran: f.traff, till: f.traff + p9EfterS).first { $0.uppat }?.tid
        if let p = p9, nagon(t, bakre, { $0 >= f.traff && $0 < p }, { $0 >= 0 }) { p9 = nil }
        return Positioner(p1: (f.adressFran + f.adressTill) / 2, p3: p3, p4: f.topp, p5: p5,
                          p7: f.traff, p9: p9, p10: (f.finishFran + f.finishTill) / 2)
    }
}
