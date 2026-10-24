import Foundation

/// Minnet på telefonen: varje fel som fått en övning, sedan när, hur första serien rört sig
/// pass för pass och övningens läge. Samma räkning som `ovningar_ur` i tools/pc/historik.py
/// (BESLUT B12, BESLUT B53), ur passens analyser och de hämtade `att_jobba_pa.json`.
/// METOD MT4, METOD MT5
public struct Ovningslage: Sendable {
    /// En rad i uppföljningen: första serien i ett senare pass, om "klart när" hålls och
    /// rörelsen sedan övningen valdes (nil när starten saknas).
    public struct Uppfoljning: Sendable {
        public let pass: String
        public let forstaSerien: Double?
        public let uppfyllt: Bool?
        public let rorelse: Double?
        public let tydlig: Bool?
    }

    public let fel: String
    public let vy: String
    public let matt: String
    /// Spåret: klubban och längden i passet då felet valdes, och vyn (för tempot vyn som tempot
    /// togs ur). Bara enheter och val i samma spår följer upp och avslutar saken (BESLUT B56).
    public let klubba: String?
    public let langd: Double?
    public let sparVy: String
    /// Passet då felet först valdes i det här blocket.
    public internal(set) var felStart: String
    public internal(set) var valtIPass: String
    public internal(set) var ovningId: String
    public internal(set) var forraOvningar: [String]
    /// "Klart när" från valet: villkoret och gränsen (ett tal, eller [min, max]).
    public internal(set) var villkor: String
    public internal(set) var grans: JSONVarde
    public internal(set) var pa: String
    public internal(set) var passIRad: Int
    public internal(set) var markning: String?
    public internal(set) var ovning: String = ""
    public internal(set) var tanke: String = ""
    public internal(set) var steg: String = ""
    public internal(set) var typ: String = ""
    public internal(set) var harFysik = false
    public internal(set) var senastIPass: String = ""
    public internal(set) var startForstaSerien: Double?
    public internal(set) var spridning: Double?
    public internal(set) var uppfoljning: [Uppfoljning] = []
    public internal(set) var uppfylltIRad = 0
    public internal(set) var passUtanRorelse = 0
    public internal(set) var dagarSedanFeletValdes = 0
    public internal(set) var rorelseSedanFeletValdes = false
    public internal(set) var aktuell = false
    /// "avslutad", "klart", "fysik", "ny", "byt_ovning" eller "fortsatt" (METOD MT5).
    public internal(set) var lage = ""
    /// "klart_nar", "inte_flaggat" eller nil (BESLUT B45).
    public internal(set) var klartSkal: String?

    /// Sakens "klart när" som `grans` (ett tal, eller [min, max] för mellan).
    static func grans(_ k: AttJobbaPa.KlartNar) -> JSONVarde {
        k.villkor == .mellan ? .lista([.tal(k.lo), .tal(k.hi)]) : .tal(k.lo)
    }

    static func uppfyllt(_ villkor: String, _ grans: JSONVarde, _ v: Double) -> Bool {
        if villkor == ">=" { return v >= (grans.somTal ?? .nan) }
        if villkor == "<=" { return v <= (grans.somTal ?? .nan) }
        guard let g = grans.somLista, g.count == 2, let lo = g[0].somTal, let hi = g[1].somTal else { return false }
        return lo <= v && v <= hi
    }

    /// Hur långt värdet rört sig åt rätt håll sedan starten. METOD MT4
    static func rorelse(_ villkor: String, _ grans: JSONVarde, start: Double, nu: Double) -> Double {
        if villkor == ">=" { return nu - start }
        if villkor == "<=" { return start - nu }
        let g = grans.somLista ?? []
        let c = ((g.first?.somTal ?? 0) + (g.last?.somTal ?? 0)) / 2
        return abs(start - c) - abs(nu - c)
    }

    static func varde(_ a: Passanalys, _ vy: String, _ matt: String, forsta: Bool) -> Double? {
        let g = vy == "bada" ? "alla" : vy
        return (forsta ? a.forstaSerien : a.session)[g]?[matt]?.median
    }

    /// Startvärdet (första serien i startenheten), dess spridning och en rad per senare enhet i
    /// spåret. METOD MT4
    static func foljning(_ enh: [Passanalys], _ vy: String, _ matt: String, _ villkor: String, _ grans: JSONVarde,
                         start: Passanalys?, startPass: String) -> (start: Double?, spr: Double?, rader: [Uppfoljning]) {
        var startv: Double? = nil, spr: Double? = nil
        if let a = start {
            startv = varde(a, vy, matt, forsta: true) ?? varde(a, vy, matt, forsta: false)
            spr = a.session[vy == "bada" ? "alla" : vy]?[matt].map(Session.robustSD)
        }
        var rader: [Uppfoljning] = []
        for u in enh where u.pass > startPass {
            guard let v = varde(u, vy, matt, forsta: true) else {
                rader.append(Uppfoljning(pass: u.pass, forstaSerien: nil, uppfyllt: nil, rorelse: nil, tydlig: nil))
                continue
            }
            let visat = Avrundning.avrunda(matt, v)
            let upp = uppfyllt(villkor, grans, visat ?? v)
            if let s = startv, let sp = spr {
                let r = rorelse(villkor, grans, start: s, nu: v)
                rader.append(Uppfoljning(pass: u.pass, forstaSerien: visat, uppfyllt: upp,
                                         rorelse: Avrundning.avrunda(matt, r), tydlig: r > sp))
            } else {
                rader.append(Uppfoljning(pass: u.pass, forstaSerien: visat, uppfyllt: upp, rorelse: nil, tydlig: nil))
            }
        }
        return (startv, spr, rader)
    }

    /// Övningens stabila id; en fil från före id:t känns igen på texten.
    static func id(_ o: AttJobbaPa.Ovning) -> String {
        if let i = o.id, !i.isEmpty { return i }
        return o.text
    }

    /// Enheten följer upp spåret: samma klubba, längd och vy som när saken valdes (BESLUT B56).
    func relevant(_ u: Passanalys) -> Bool {
        guard u.samma(klubba: klubba, langd: langd) else { return false }
        return vy == "bada" ? u.tempoVy == sparVy : u.vyer.contains(vy)
    }

    /// Minnet ur enheterna (`Passanalys.historik`, i ett sammanhang) och valen: `till` tar med
    /// enheterna och valen till och med det passet, `fore` bara valen före det. Ett val gäller
    /// passets huvudklubba, och ett val för ett pass utan enhet läses inte. Som `ovningar_ur`.
    public static func minne(_ enheterna: [Passanalys], _ alla: [AttJobbaPa], till: String? = nil,
                             fore: String? = nil, kedjor: Kedjor = .appens) -> [Ovningslage] {
        let medTest = Set(kedjor.fysik.map(\.fel))
        let U = enheterna.filter { till == nil || $0.pass <= till! }.enumerated()
            .sorted { Passanalys.fore($0.element, $1.element) || (!Passanalys.fore($1.element, $0.element)
                                                                   && $0.offset < $1.offset) }
            .map(\.element)
        var huvud: [String: Passanalys] = [:]
        for u in U where u.huvud && huvud[u.pass] == nil { huvud[u.pass] = u }
        let docs = alla.filter { huvud[$0.pass] != nil && (fore == nil || $0.pass < fore!) }
            .enumerated().sorted { ($0.element.pass, $0.offset) < ($1.element.pass, $1.offset) }.map(\.element)
        var ordning: [String] = []
        var spar: [String: Ovningslage] = [:]
        var aktiv: [String: Bool] = [:]
        func nyckel(_ fel: String, _ k: String?) -> String { fel + "|" + (k.map { "k:" + $0 } ?? "-") }
        for d in docs {
            let u = huvud[d.pass]!
            let aktivaFore = aktiv
            for s in d.saker {
                let fid = s.fel, ovId = id(s.ovning)
                let k = nyckel(fid, u.klubba)
                if spar[k] == nil || aktivaFore[k] != true {
                    let g = spar[k]
                    let tidigare = g.map { [$0.ovningId] + $0.forraOvningar } ?? []
                    if g == nil { ordning.append(k) }
                    spar[k] = Ovningslage(fel: fid, vy: s.vy, matt: s.matt, klubba: u.klubba, langd: u.langd,
                                          sparVy: s.vy == "bada" ? u.tempoVy : s.vy, felStart: d.pass,
                                          valtIPass: d.pass, ovningId: ovId, forraOvningar: tidigare,
                                          villkor: s.klartNar.villkor.rawValue, grans: grans(s.klartNar),
                                          pa: s.klartNar.pa, passIRad: s.klartNar.passIRad, markning: s.markning)
                } else if spar[k]!.ovningId != ovId {
                    var g = spar[k]!
                    g.valtIPass = d.pass
                    g.forraOvningar = [g.ovningId] + g.forraOvningar
                    g.ovningId = ovId
                    g.villkor = s.klartNar.villkor.rawValue
                    g.grans = grans(s.klartNar)
                    g.pa = s.klartNar.pa
                    g.passIRad = s.klartNar.passIRad
                    g.markning = s.markning
                    spar[k] = g
                }
                var g = spar[k]!
                g.ovning = s.ovning.text
                g.tanke = s.ovning.tanke
                g.steg = s.ovning.steg
                g.typ = s.typ
                g.harFysik = s.fysik != nil
                g.senastIPass = d.pass
                spar[k] = g
                aktiv[k] = true
            }
            let valda = Set(d.saker.map(\.fel))
            for k in ordning where spar[k]!.relevant(u) { aktiv[k] = valda.contains(spar[k]!.fel) }
        }
        var ut: [Ovningslage] = []
        for k in ordning {
            var o = spar[k]!
            let rel = U.filter { o.relevant($0) }
            let start = U.first { $0.pass == o.valtIPass && $0.klubba == o.klubba }
            let fstart = U.first { $0.pass == o.felStart && $0.klubba == o.klubba }
            let (startv, spr, upp) = foljning(rel, o.vy, o.matt, o.villkor, o.grans, start: start, startPass: o.valtIPass)
            let uppFel = foljning(rel, o.vy, o.matt, o.villkor, o.grans, start: fstart, startPass: o.felStart).rader
            var uppfyllda = 0
            for x in upp.reversed() {
                if x.uppfyllt != true { break }
                uppfyllda += 1
            }
            var utan = 0
            for x in upp.reversed() {
                if x.tydlig == true { break }
                utan += 1
            }
            var dagar = 0
            if let sista = rel.last, let a = Dag.fran(sista.pass), let b = Dag.fran(o.felStart) { dagar = a - b }
            let rorelseIBlocket = uppFel.contains { $0.tydlig == true }
            var ejFlaggat = false
            if let sista = rel.last, sista.pass > o.senastIPass {
                ejFlaggat = sista.bedomning.contains { $0.id == o.fel && $0.status == .gron }
            }
            let arAktiv = aktiv[k] == true
            var skal: String? = nil
            let lage: String
            if !arAktiv {
                lage = "avslutad"
            } else if uppfyllda >= o.passIRad {
                lage = "klart"
                skal = "klart_nar"
            } else if ejFlaggat {
                lage = "klart"
                skal = "inte_flaggat"
            } else if !uppFel.isEmpty && !rorelseIBlocket && dagar >= fysikDagar && !o.harFysik
                        && medTest.contains(o.fel) {
                lage = "fysik"
            } else if upp.isEmpty {
                lage = "ny"
            } else if utan >= bytOvningPass {
                lage = "byt_ovning"
            } else {
                lage = "fortsatt"
            }
            let matt = o.matt
            o.startForstaSerien = startv.flatMap { Avrundning.avrunda(matt, $0) }
            o.spridning = spr.flatMap { Avrundning.avrunda(matt, $0) }
            o.uppfoljning = upp
            o.dagarSedanFeletValdes = dagar
            o.rorelseSedanFeletValdes = rorelseIBlocket
            o.uppfylltIRad = uppfyllda
            o.passUtanRorelse = utan
            o.aktuell = arAktiv
            o.lage = lage
            o.klartSkal = skal
            ut.append(o)
        }
        return ut
    }

    /// Så många pass utan tydlig rörelse → byt övning. METOD MT5
    public static let bytOvningPass = 4
    /// Sex veckor utan rörelse → fysiken (treregeln). METOD MT5
    public static let fysikDagar = 42
}
