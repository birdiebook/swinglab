import Foundation

/// Varför ett mått saknas, i appen (PLAN S3b lager 1, BESLUT B109). Mätningen skriver orsaken per
/// slag och mått (`Kvalitet.saknas`, `ShotMeasure.missing`, sedan version 6: METOD M52, M4, M40),
/// och här blir den enkel engelska ur Texter. Där talet skulle stå säger appen att måttet saknas,
/// "Not measured" på granskningens rad och "Measured in 5 of 8 swings" på passets kort; orsaken
/// står först i måttets infoblad, ett tryck bort (BESLUT B41, B94). Koden visas aldrig. Ett slag
/// mätt före version 6 har ingen kod: då står bara att måttet saknas. Appen räknar ingen orsak
/// själv: den läser mätningens. METOD MS21, MS22
public enum Saknas {
    /// Mätningens koder, i den ordning orsakerna står i infobladet när antalen är lika.
    public enum Orsak: String, CaseIterable, Sendable {
        /// Ett segment är kraftigt kortare i bild än i adressen: det pekar mot eller från
        /// kameran (METOD M52).
        case segmentKort = "segment_kort"
        /// Ett segment är längre i bild än i adressen: en punkt är fel (METOD M52).
        case segmentLangt = "segment_langt"
        /// En punkt saknas i fasen eller i adressen (METOD M52).
        case ledSaknas = "led_saknas"
        /// Baksvingens start är osäker: framifrån ingen stilla adress i klippet (METOD M4),
        /// bakifrån en skakig adress, en lucka eller för få leder (METOD M40).
        case startOsaker = "start_osaker"
        /// Baksvingens start hittades inte (METOD M4, M40).
        case startSaknas = "start_saknas"
    }

    /// Kroppsdelen som en ledvinkel bygger på (METOD M52), i måttnamnens ord: "lead arm". nil för
    /// ett mått som inte är en ledvinkel.
    static func kroppsdel(_ matt: String) -> String? {
        if matt.hasPrefix("framre_armbage") { return Texter.framreArm }
        if matt.hasPrefix("bakre_armbage") { return Texter.bakreArm }
        if matt.hasPrefix("framre_kna_") { return Texter.framreBen }
        if matt.hasPrefix("bakre_kna_") { return Texter.bakreBen }
        return nil
    }

    /// Orsaken i ord, med liten bokstav och utan punkt: "the lead arm pointed toward or away from
    /// the camera". `vy` = slagets vy (starten skiljer framifrån och bakifrån). nil utan kod; en
    /// okänd kod får en allmän text, aldrig koden. METOD MS21
    public static func orsak(_ kod: String?, matt: String, vy: Vy) -> String? {
        guard let kod else { return nil }
        let del = kroppsdel(matt)
        switch Orsak(rawValue: kod) {
        case .segmentKort?: return del.map(Texter.orsakMotKameran) ?? Texter.orsakMotKameranAllman
        case .segmentLangt?: return del.map(Texter.orsakPunktFel) ?? Texter.orsakPunktFelAllman
        case .ledSaknas?: return del.map(Texter.orsakPunktSaknas) ?? Texter.orsakPunktSaknasAllman
        case .startOsaker?: return vy == .fo ? Texter.orsakKlippetSent : Texter.orsakStartOklar
        case .startSaknas?: return Texter.orsakStartSaknas
        case nil: return Texter.orsakOkand
        }
    }

    /// Infobladets rad för ett slag i granskningen: "Not measured in this swing: the lead arm
    /// pointed toward or away from the camera." eller utan kod "Not measured in this swing."
    /// METOD MS21
    public static func slag(_ kod: String?, matt: String, vy: Vy) -> String {
        orsak(kod, matt: matt, vy: vy).map(Texter.ejMattISlaget) ?? Texter.ejMattISlagetUtanOrsak
    }

    /// Ett mått i passet: hur många av svingarna i gruppen som har talet, och varför resten
    /// saknar det. METOD MS22
    public struct Rakning: Equatable, Sendable {
        /// En orsak i ord och antalet svingar med den.
        public struct Post: Equatable, Sendable {
            public let text: String
            public let n: Int
        }

        /// Svingarna med talet.
        public let matt: Int
        /// Svingarna i gruppen.
        public let av: Int
        /// Orsakerna i ord, flest först (lika: kodernas ordning i `Orsak`); samma text en gång.
        public let orsaker: [Post]
        /// Svingarna som saknar talet utan kod (mätta före version 6, eller ett mått utan kontroll).
        public let utanOrsak: Int

        /// Kortets rad: "Measured in 5 of 8 swings", "Not measured in any of the 8 swings".
        public var rad: String { matt == 0 ? Texter.ejMattIAlla(av) : Texter.mattI(matt, av: av) }

        /// Infobladets rader: raden som mening, sedan en rad per orsak och sist svingarna utan
        /// kod, när någon annan har en. Utan någon kod bara raden.
        public var blad: [String] {
            var ut = ["\(rad)."]
            guard !orsaker.isEmpty else { return ut }
            ut += orsaker.map { Texter.orsakRad($0.n, $0.text) }
            if utanOrsak > 0 { ut.append(Texter.orsakRad(utanOrsak, Texter.ingenOrsak)) }
            return ut
        }
    }

    /// Räkningen för `matt` bland passets svingar i `grupp` ("fo", "dtl" eller "alla", som
    /// `Pass.grupp`). nil när passet inte bär orsakerna (`Pass.saknas`), när gruppen saknar svingar
    /// och när alla svingar har talet: då säger kortet inget. METOD MS22
    public static func pass(_ p: Pass, matt: String, grupp: String) -> Rakning? {
        guard let koder = p.saknas, koder.count == p.svingar.count else { return nil }
        let vy = Vy(rawValue: grupp)
        var av = 0, med = 0, utan = 0
        var antal: [String: Int] = [:]
        var rang: [String: Int] = [:]
        for (s, k) in zip(p.svingar, koder) where vy == nil || s.vy == vy {
            av += 1
            if let v = s.matt[matt], v.isFinite {
                med += 1
            } else if let t = orsak(k[matt], matt: matt, vy: s.vy) {
                antal[t, default: 0] += 1
                let r = Orsak(rawValue: k[matt] ?? "").flatMap { Orsak.allCases.firstIndex(of: $0) } ?? Orsak.allCases.count
                rang[t] = min(rang[t] ?? r, r)
            } else {
                utan += 1
            }
        }
        guard av > 0, med < av else { return nil }
        let orsaker = antal.keys.sorted { a, b in
            antal[a]! != antal[b]! ? antal[a]! > antal[b]! : (rang[a]! != rang[b]! ? rang[a]! < rang[b]! : a < b)
        }.map { Rakning.Post(text: $0, n: antal[$0]!) }
        return Rakning(matt: med, av: av, orsaker: orsaker, utanOrsak: utan)
    }
}
