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
        if villkor == ">=" { return v >= (grans.pyTal ?? .nan) }
        if villkor == "<=" { return v <= (grans.pyTal ?? .nan) }
        guard let g = grans.somLista, g.count == 2, let lo = g[0].pyTal, let hi = g[1].pyTal else { return false }
        return lo <= v && v <= hi
    }

    /// Hur långt värdet rört sig åt rätt håll sedan starten. METOD MT4
    static func rorelse(_ villkor: String, _ grans: JSONVarde, start: Double, nu: Double) -> Double {
        if villkor == ">=" { return nu - start }
        if villkor == "<=" { return start - nu }
        let g = grans.somLista ?? []
        let c = ((g.first?.pyTal ?? 0) + (g.last?.pyTal ?? 0)) / 2
        return abs(start - c) - abs(nu - c)
    }

    static func varde(_ a: Passanalys, _ vy: String, _ matt: String, forsta: Bool) -> Double? {
        let g = vy == "bada" ? "alla" : vy
        return (forsta ? a.forstaSerien : a.session)[g]?[matt]?.median
    }

    /// Startvärdet, startpassets spridning och en rad per senare pass. METOD MT4
    static func foljning(_ analyser: [String: Passanalys], _ passIds: [String], _ vy: String, _ matt: String,
                         _ villkor: String, _ grans: JSONVarde, start startPass: String)
        -> (start: Double?, spr: Double?, rader: [Uppfoljning]) {
        var start: Double? = nil, spr: Double? = nil
        if let a = analyser[startPass] {
            start = varde(a, vy, matt, forsta: true) ?? varde(a, vy, matt, forsta: false)
            spr = a.session[vy == "bada" ? "alla" : vy]?[matt].map(Session.robustSD)
        }
        var rader: [Uppfoljning] = []
        for p in passIds where p > startPass {
            guard let v = varde(analyser[p]!, vy, matt, forsta: true) else {
                rader.append(Uppfoljning(pass: p, forstaSerien: nil, uppfyllt: nil, rorelse: nil, tydlig: nil))
                continue
            }
            let visat = Avrundning.avrunda(matt, v)
            let upp = uppfyllt(villkor, grans, visat ?? v)
            if let s = start, let sp = spr {
                let r = rorelse(villkor, grans, start: s, nu: v)
                rader.append(Uppfoljning(pass: p, forstaSerien: visat, uppfyllt: upp, rorelse: Avrundning.avrunda(matt, r),
                                         tydlig: r > sp))
            } else {
                rader.append(Uppfoljning(pass: p, forstaSerien: visat, uppfyllt: upp, rorelse: nil, tydlig: nil))
            }
        }
        return (start, spr, rader)
    }

    /// Övningens stabila id; en fil från före id:t känns igen på texten.
    static func id(_ o: AttJobbaPa.Ovning) -> String {
        if let i = o.id, !i.isEmpty { return i }
        return o.text
    }

    /// Minnet ur passens analyser och valen: `till` tar med passen och valen till och med det
    /// passet, `fore` bara valen före det (kontrollen av ett nytt val). Som `ovningar_ur`.
    public static func minne(_ analyserna: [Passanalys], _ alla: [AttJobbaPa], till: String? = nil,
                             fore: String? = nil) -> [Ovningslage] {
        var analyser: [String: Passanalys] = [:]
        for a in analyserna where till == nil || a.pass <= till! { analyser[a.pass] = a }
        let passIds = analyser.keys.sorted()
        let docs = alla.filter { (till == nil || $0.pass <= till!) && (fore == nil || $0.pass < fore!) }
            .enumerated().sorted { ($0.element.pass, $0.offset) < ($1.element.pass, $1.offset) }.map(\.element)
        var ordning: [String] = []
        var senast: [String: Ovningslage] = [:]
        var forraFel = Set<String>()
        for d in docs {
            for s in d.saker {
                let fid = s.fel, ovId = id(s.ovning)
                if senast[fid] == nil || !forraFel.contains(fid) {
                    let g = senast[fid]
                    let tidigare = g.map { [$0.ovningId] + $0.forraOvningar } ?? []
                    if g == nil { ordning.append(fid) }
                    senast[fid] = Ovningslage(fel: fid, vy: s.vy, matt: s.matt, felStart: d.pass, valtIPass: d.pass,
                                              ovningId: ovId, forraOvningar: tidigare, villkor: s.klartNar.villkor.rawValue,
                                              grans: grans(s.klartNar), pa: s.klartNar.pa, passIRad: s.klartNar.passIRad,
                                              markning: s.markning)
                } else if senast[fid]!.ovningId != ovId {
                    var g = senast[fid]!
                    g.valtIPass = d.pass
                    g.forraOvningar = [g.ovningId] + g.forraOvningar
                    g.ovningId = ovId
                    g.villkor = s.klartNar.villkor.rawValue
                    g.grans = grans(s.klartNar)
                    g.pa = s.klartNar.pa
                    g.passIRad = s.klartNar.passIRad
                    g.markning = s.markning
                    senast[fid] = g
                }
                var g = senast[fid]!
                g.ovning = s.ovning.text
                g.tanke = s.ovning.tanke
                g.steg = s.ovning.steg
                g.typ = s.typ
                g.harFysik = s.fysik != nil
                g.senastIPass = d.pass
                senast[fid] = g
            }
            forraFel = Set(d.saker.map(\.fel))
        }
        var ut: [Ovningslage] = []
        for fid in ordning {
            var o = senast[fid]!
            let (start, spr, upp) = foljning(analyser, passIds, o.vy, o.matt, o.villkor, o.grans, start: o.valtIPass)
            let uppFel = foljning(analyser, passIds, o.vy, o.matt, o.villkor, o.grans, start: o.felStart).rader
            var uppfyllda = 0
            for u in upp.reversed() {
                if u.uppfyllt != true { break }
                uppfyllda += 1
            }
            var utan = 0
            for u in upp.reversed() {
                if u.tydlig == true { break }
                utan += 1
            }
            var dagar = 0
            if let sista = passIds.last, let a = Dag.fran(sista), let b = Dag.fran(o.felStart) { dagar = a - b }
            let rorelseIBlocket = uppFel.contains { $0.tydlig == true }
            var ejFlaggat = false
            if let sista = passIds.last, sista > o.senastIPass, let a = analyser[sista] {
                ejFlaggat = a.bedomning.contains { $0.id == fid && $0.status == .gron }
            }
            var skal: String? = nil
            let lage: String
            if !forraFel.contains(fid) {
                lage = "avslutad"
            } else if uppfyllda >= o.passIRad {
                lage = "klart"
                skal = "klart_nar"
            } else if ejFlaggat {
                lage = "klart"
                skal = "inte_flaggat"
            } else if !uppFel.isEmpty && !rorelseIBlocket && dagar >= fysikDagar && !o.harFysik {
                lage = "fysik"
            } else if upp.isEmpty {
                lage = "ny"
            } else if utan >= bytOvningPass {
                lage = "byt_ovning"
            } else {
                lage = "fortsatt"
            }
            let matt = o.matt
            o.startForstaSerien = start.flatMap { Avrundning.avrunda(matt, $0) }
            o.spridning = spr.flatMap { Avrundning.avrunda(matt, $0) }
            o.uppfoljning = upp
            o.dagarSedanFeletValdes = dagar
            o.rorelseSedanFeletValdes = rorelseIBlocket
            o.uppfylltIRad = uppfyllda
            o.passUtanRorelse = utan
            o.aktuell = forraFel.contains(fid)
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
