import Foundation

/// Ett pass som vyn ser det: dagen, klubban och svingarnas mått i passets ordning.
/// Varje slag ger en sving per telefon (FO och DTL).
public struct Pass: Sendable {
    public let datum: Date
    public let klubba: String
    public let svingar: [SvingMatt]
    /// De första så här många svingarna i varje vy är serie 1, före uppvärmningen
    /// (design/README.md, öppet val 4). 0 = ingen serie 1.
    public let serie1: Int
    /// Slagen vars start är osäker bakifrån: de saknar tempo (METOD M40).
    public let osakerStart: Int
    /// Slagen som räknas och har klubban markerad (PLAN S7a, METOD M45).
    public let klubbMarkerade: Int

    public init(datum: Date, klubba: String, svingar: [SvingMatt], serie1: Int = 0, osakerStart: Int = 0,
                klubbMarkerade: Int = 0) {
        self.datum = datum
        self.klubba = klubba
        self.svingar = svingar
        self.serie1 = serie1
        self.osakerStart = osakerStart
        self.klubbMarkerade = klubbMarkerade
    }

    /// Slagen: den telefon som såg flest.
    public var slag: Int {
        Swift.max(svingar.filter { $0.vy == .fo }.count, svingar.filter { $0.vy == .dtl }.count)
    }

    /// Svingarna i en grupp: "fo", "dtl" eller "alla" (som Session.grupper).
    public func grupp(_ grupp: String) -> [SvingMatt] {
        guard let vy = Vy(rawValue: grupp) else { return svingar }
        return svingar.filter { $0.vy == vy }
    }

    /// Serie 1 i en grupp: de första `serie1` svingarna i varje vy.
    public func serie1Grupp(_ grupp: String) -> [SvingMatt] {
        guard serie1 > 0 else { return [] }
        if let vy = Vy(rawValue: grupp) {
            return Array(svingar.filter { $0.vy == vy }.prefix(serie1))
        }
        return Array(svingar.filter { $0.vy == .fo }.prefix(serie1)) + Array(svingar.filter { $0.vy == .dtl }.prefix(serie1))
    }

    /// Passets median för ett mått i en grupp (METOD M25), nil när svingarna är för få.
    public func median(_ matt: String, _ grupp: String) -> Double? {
        Session.sammanfatta(self.grupp(grupp).map { $0.matt })[matt]?.median
    }

    public func sammanfattning(_ matt: String, _ grupp: String) -> Sammanfattning? {
        Session.sammanfatta(self.grupp(grupp).map { $0.matt })[matt]
    }

    /// Serie 1:s median för ett mått.
    public func serie1Median(_ matt: String, _ grupp: String) -> Double? {
        Session.sammanfatta(serie1Grupp(grupp).map { $0.matt })[matt]?.median
    }

    /// Passets spridning mellan slagen för ett mått i en grupp: den robusta sd:n
    /// (q3 − q1)/1,349, nil under `Spridning.minSlag` svingar. METOD M44
    public func spridning(_ matt: String, _ grupp: String) -> Double? {
        guard varden(matt, grupp).count >= Spridning.minSlag else { return nil }
        return sammanfattning(matt, grupp).map(Session.robustSD)
    }

    /// Värdena för ett mått i passet, i passets ordning.
    public func varden(_ matt: String, _ grupp: String) -> [Double] {
        self.grupp(grupp).compactMap { $0.matt[matt] }.filter { $0.isFinite }
    }
}

extension Katalog.Fel {
    /// Gruppen som felet bedöms i (Bedomare): vyn, eller alla svingar ihop.
    public var grupp: String { vy == "bada" ? "alla" : vy }
}

/// Den egna baslinjen som ett spann: medianen ± en robust sd ur tidigare pass,
/// alltså det som Bedomare räknar som grönt. METOD M27
public enum Baslinje {
    public static func spann(_ varden: [Double]) -> (lo: Double, hi: Double)? {
        guard varden.count >= Bedomare.minBaslinje else { return nil }
        let s = varden.sorted()
        let med = Session.percentil(s, 0.5)
        let spr = (Session.percentil(s, 0.75) - Session.percentil(s, 0.25)) / Session.iqrSkala
        guard spr > 0 else { return nil }
        return (med - Bedomare.gronZ * spr, med + Bedomare.gronZ * spr)
    }
}
