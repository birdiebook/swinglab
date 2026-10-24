import Foundation

// Telefonens lutning i uppställningen (S6c-2, BESLUT B39, B62, METOD MS19): appen visar en
// tunn horisontlinje och lutningen åt sidan medan telefonen står på stativet, ur samma
// gravitation och samma vridning till kamerans ram som lodlinjen i manifestet (Plumb, MS17).

/// Lutningen ur ett prov av gravitationen, för uppställningen. METOD MS19
public struct Lutning: Equatable, Sendable {
    /// Lutningen åt sidan, grader: vinkeln mellan bildens lodräta och lodlinjen i bildens plan,
    /// + när uppåt pekar åt bildens högra sida. Det är den som gör kamerornas vågräta fel (MK3).
    public var sida: Double
    /// Vinkeln mellan uppåt och bildens överkant, grader (även framåt och bakåt), som
    /// manifestets fält prövas mot (`Plumb.maxTilt`).
    public var franLodlinjen: Double

    /// Telefonen lutar mer än lodlinjens fält tål: 3D tar då kamerornas vågräta (MS17, MK3).
    public var forStorFor3D: Bool { !(franLodlinjen <= Plumb.maxTilt) }

    /// Ur gravitationen i enhetens ram (CoreMotion, g) och filens orientering (EXIF, 6 = stående,
    /// appens läge). nil när provet inte är ett tal eller inte är gravitationen (0,5–1,5 g).
    public init?(gravity g: [Double], exif: UInt32 = 6) {
        guard g.count == 3, g.allSatisfy(\.isFinite) else { return nil }
        let langd = (g[0] * g[0] + g[1] * g[1] + g[2] * g[2]).squareRoot()
        guard langd >= 0.5, langd <= 1.5 else { return nil }
        let u = Plumb.up(gravity: g, exif: exif)
        sida = atan2(u[0], -u[1]) * 180 / .pi
        franLodlinjen = Plumb.angle(u, [0, -1, 0])
    }
}
