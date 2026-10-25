import Foundation

// Den andra telefonens bild live (PLAN S2k, BESLUT B90, METOD MS35): följaren skickar en liten
// förhandsbild till den styrande över samma PhoneLink-koppling, så att Johannes kan rikta in den
// andra telefonen utan att gå dit. En JPEG per bild, högst en i flykt (mottrycket), cirka 12 bilder/s
// i uppställningen, färre när telefonen är varm, och ingen alls under inspelningen eller från
// värmen "serious". Bilden går bara mellan de två parade telefonerna och sparas aldrig (B61).
// Logiken här, så att den prövas på Linux (`ForhandsbildTests`); appen tar rutan ur kameran,
// kodar den och visar den.

/// En förhandsbild på tråden (`preview`): JPEG-bytena (base64 i JSON), numret och när bilden togs
/// på följarens värdklocka. METOD MS35
public struct LinkPreview: Codable, Equatable, Sendable {
    /// Förmågan i hello (BESLUT B90).
    public static let cap = "preview1"
    public static let version = 1
    /// Bildens kortsida, px: 360 × 640 stående. METOD MS35
    public static let kortsida = 360
    /// JPEG-kvaliteten (0–1, ImageIO). METOD MS35
    public static let kvalitet = 0.5
    /// En bild som blev större än så skickas inte (en trasig kodning; `Wire.maxLength` räcker ändå).
    public static let maxBytes = 200_000

    public var v: Int
    /// Löpnummer från följaren; kvittensen bär det tillbaka.
    public var n: Int
    /// När rutan togs, följarens värdklocka (s): den styrande räknar fördröjningen med klockan
    /// ur pingen (MS9).
    public var t: Double
    public var w: Int
    public var h: Int
    public var jpeg: Data

    public init(n: Int, t: Double, w: Int, h: Int, jpeg: Data, v: Int = LinkPreview.version) {
        self.v = v
        self.n = n
        self.t = t
        self.w = w
        self.h = h
        self.jpeg = jpeg
    }

    /// Bildens storlek för en ruta i `bredd` × `hojd` px: kortsidan `kortsida`, aldrig uppskalad.
    public static func storlek(bredd: Int, hojd: Int) -> (w: Int, h: Int) {
        guard bredd > 0, hojd > 0 else { return (0, 0) }
        let s = min(1, Double(kortsida) / Double(min(bredd, hojd)))
        return (max(1, Int((Double(bredd) * s).rounded())), max(1, Int((Double(hojd) * s).rounded())))
    }
}

/// Takten för förhandsbilden, bilder/s. Under inspelningen ingen alls: den säkra vägen, tills det är
/// mätt på telefonerna att en egen videoutgång inte stör 240 bilder/s (MS35). Varm telefon: färre;
/// från "serious" ingen. METOD MS35
public enum Forhandstakt {
    public static let aktiv = 12.0
    /// Värmen "fair".
    public static let varm = 6.0
    public static let underInspelning = 0.0
    /// Från den här värmen skickas ingen bild.
    public static let avFran = Pressure.serious

    /// `kanSkicka`: kopplad till en styrande med "preview1". `inspelar`: en serie eller ljusprovet
    /// spelas in på den här telefonen.
    public static func hz(kanSkicka: Bool, inspelar: Bool, tryck: Pressure) -> Double {
        guard kanSkicka, tryck < avFran else { return 0 }
        if inspelar { return underInspelning }
        return tryck >= .fair ? varm : aktiv
    }
}

/// Följarens sida: när en ruta ur kameran ska bli en bild. Högst en bild i flykt: nästa tas först
/// när den förra är kvitterad, så att fördröjningen inte växer när nätet är långsamt (bilder
/// hoppas över i stället). En kvittens som aldrig kommer släpper flykten efter `kvittensTid`.
/// METOD MS35
public struct ForhandsSandare: Equatable, Sendable {
    public static let kvittensTid = 1.0
    /// Marginal mot kamerans rutnät (240 bilder/s = 4,2 ms), s.
    public static let marginal = 0.002

    /// Bilden som väntar på kvittens.
    public private(set) var iFlykt: Int?
    var flyktSedan = -Double.infinity
    var nasta = 1
    var senast = -Double.infinity

    public init() {}

    /// En ruta från kameran vid `nu` (värdklockan): bildens nummer när den ska tas, annars nil.
    public mutating func ta(nu: Double, hz: Double) -> Int? {
        guard hz > 0, hz.isFinite, nu.isFinite else { return nil }
        if iFlykt != nil, nu - flyktSedan < Self.kvittensTid { return nil }
        guard nu - senast >= 1 / hz - Self.marginal else { return nil }
        let n = nasta
        nasta += 1
        iFlykt = n
        flyktSedan = nu
        senast = nu
        return n
    }

    /// Den styrande kvitterade bild `n`. En sen kvittens för en äldre bild ändrar inget.
    public mutating func kvitterad(_ n: Int) {
        if iFlykt == n { iFlykt = nil }
    }

    /// Bilden blev aldrig skickad (kodningen misslyckades, kopplingen nere).
    public mutating func slapp(_ n: Int) {
        kvitterad(n)
    }

    /// Kopplingen föll eller takten blev noll: inget väntar längre. Numren fortsätter.
    public mutating func nollstall() {
        iFlykt = nil
    }
}

/// Den styrandes sida: senaste bilden, om rutan i hörnet ska visas, och fördröjningen och takten
/// till kugghjulet. METOD MS35
public struct ForhandsMottagare: Equatable, Sendable {
    /// Rutan försvinner så länge efter senaste bilden, s (följaren spelar in, är varm eller borta).
    public static let gammal = 1.5
    /// Takten räknas över så många sekunder.
    public static let fonster = 2.0
    /// Fördröjningen är medianen av så många bilder.
    public static let antal = 15

    public private(set) var enhet: String?
    public private(set) var senaste: Int?
    var ankomster: [Double] = []
    var fordrojningar: [Double] = []

    public init() {}

    /// En bild från följaren `enhet`, mottagen vid `nu` på den styrandes värdklocka. `klocka` är
    /// pingens skattning (följarens klocka − den styrandes, MS9); utan den ingen fördröjning.
    public mutating func ta(_ p: LinkPreview, fran enhet: String, nu: Double, klocka: ClockOffset?) {
        if enhet != self.enhet { self = ForhandsMottagare() }
        self.enhet = enhet
        senaste = p.n
        ankomster.removeAll { $0 < nu - Self.fonster }
        ankomster.append(nu)
        if let k = klocka, k.offset.isFinite, p.t.isFinite {
            // Bilden togs vid t − θ på den styrandes klocka.
            let d = nu - (p.t - k.offset)
            if d.isFinite, d > -0.5, d < 10 {
                fordrojningar.append(max(0, d))
                if fordrojningar.count > Self.antal { fordrojningar.removeFirst(fordrojningar.count - Self.antal) }
            }
        }
    }

    /// Rutan i hörnet: kopplad, ingen egen serie, och en bild de senaste `gammal` sekunderna.
    public func visas(nu: Double, kopplad: Bool, inspelar: Bool) -> Bool {
        guard kopplad, !inspelar, let sist = ankomster.last else { return false }
        return nu - sist <= Self.gammal
    }

    /// Fördröjningen från rutan till mottagningen, median, s. nil utan klocka.
    public var fordrojning: Double? {
        guard !fordrojningar.isEmpty else { return nil }
        let s = fordrojningar.sorted()
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }

    /// Bilder per sekund de senaste `fonster` sekunderna.
    public func takt(nu: Double) -> Double {
        Double(ankomster.filter { $0 >= nu - Self.fonster && $0 <= nu }.count) / Self.fonster
    }

    /// Kopplingen föll: ingen bild att visa.
    public mutating func nollstall() {
        self = ForhandsMottagare()
    }
}
