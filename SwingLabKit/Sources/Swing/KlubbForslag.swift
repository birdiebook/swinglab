import Foundation

// Modellens förslag i klubbmarkeringen (PLAN S7d, BESLUT B93, METOD MF8): filen
// `swinglab-klubba-forslag/1` (docs/FORMAT.md), dess kontroll och matchningen ruta → visad ruta.
// Samma regler, samma fel och samma val som tools/pc/klubba_forslag.py (BESLUT B12). Ett förslag
// är aldrig en markering av sig självt (B92): det blir en punkt först när Johannes godkänt det
// med ett tryck (`Klubba.kallaForslag`) i märkningen (`ClubMarking`, Capture).

/// Det som telefonen visar ur en ruta i förslagsfilen (konfidens ≥ `visaKonfidens`): greppet och
/// hoseln, som kan godkännas, och klubbhuvudets mitt (med sin ruta), som bara är en ledtråd.
public struct KlubbForslag: Equatable, Sendable {
    public var grepp: KlubbPunkt?
    public var hosel: KlubbPunkt?
    public var huvud: KlubbPunkt?
    /// Huvudets ruta `[x, y, b, h]` i px, när modellen gav en.
    public var huvudBox: [Double]?
    /// "namn version", för förslagets rad i `swinglab-klubba` (`forslag.*.modell`).
    public var modell: String

    public init(grepp: KlubbPunkt? = nil, hosel: KlubbPunkt? = nil, huvud: KlubbPunkt? = nil,
                huvudBox: [Double]? = nil, modell: String) {
        self.grepp = grepp
        self.hosel = hosel
        self.huvud = huvud
        self.huvudBox = huvudBox
        self.modell = modell
    }

    public var tom: Bool { grepp == nil && hosel == nil && huvud == nil }
}

public struct KlubbForslagFil: Equatable, Sendable {
    public static let format = "swinglab-klubba-forslag/1"
    /// Punkterna i filen (BESLUT B93): hosel = B44:s klubbhuvud, huvud = klubbhuvudets mitt.
    public static let punktnamn = ["grepp", "hosel", "huvud", "skaft_mitt"]
    /// En ruta i filen hör till den visade när tiderna skiljer högst så, s. METOD MF8
    public static let rutaTol = 0.002
    /// En punkt med lägre konfidens visas inte. METOD MF8
    public static let visaKonfidens = 0.5
    /// Större än så tas inte emot, byte. METOD MF8
    public static let maxBytes = 20_000_000
    static let maxFel = 30

    public struct Punkt: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var konfidens: Double
        public var box: [Double]?

        public init(x: Double, y: Double, konfidens: Double, box: [Double]?) {
            self.x = x
            self.y = y
            self.konfidens = konfidens
            self.box = box
        }
    }

    public struct Ruta: Equatable, Sendable {
        public var t: Double
        public var grepp: Punkt?
        public var hosel: Punkt?
        public var huvud: Punkt?
        public var skaftMitt: Punkt?

        public init(t: Double, grepp: Punkt?, hosel: Punkt?, huvud: Punkt?, skaftMitt: Punkt?) {
            self.t = t
            self.grepp = grepp
            self.hosel = hosel
            self.huvud = huvud
            self.skaftMitt = skaftMitt
        }

        /// Det som visas (METOD MF8): grepp, hosel och huvud med konfidens ≥ `visaKonfidens`.
        public func visat(modell: String) -> KlubbForslag {
            func v(_ p: Punkt?) -> Punkt? { p.flatMap { $0.konfidens >= KlubbForslagFil.visaKonfidens ? $0 : nil } }
            func k(_ p: Punkt?) -> KlubbPunkt? { p.map { KlubbPunkt(x: $0.x, y: $0.y) } }
            return KlubbForslag(grepp: k(v(grepp)), hosel: k(v(hosel)), huvud: k(v(huvud)), huvudBox: v(huvud)?.box,
                                modell: modell)
        }
    }

    public struct Slag: Equatable, Sendable {
        public var id: String
        public var rutor: [Ruta]
    }

    public var pass: String
    public var vy: Vy
    public var paket: String?
    public var skapad: String
    public var modellNamn: String
    public var modellVersion: String
    /// Datasetens namn och licens, för namnangivelsen (B92).
    public var data: [(namn: String, licens: String)] { dataset.map { ($0.first ?? "", $0.count > 1 ? $0[1] : "") } }
    var dataset: [[String]]
    public var bredd: Int
    public var hojd: Int
    public var slag: [Slag]

    public var modell: String { "\(modellNamn) \(modellVersion)" }

    // MARK: kontrollen

    /// Formen (docs/FORMAT.md): samma fel i samma ordning som `klubba_forslag.kontrollera`, på
    /// engelska (Texter), fältet utan värdet. Okända fält tillåts. METOD MF8
    public static func kontrollera(_ d: JSONVarde) -> [String] {
        guard let o = d.somObjekt else { return [Texter.ogiltigt(Texter.filen)] }
        var fel: [String] = []

        @discardableResult
        func krav(_ o: JSONVarde.Objekt, _ k: String, _ plats: String, _ ok: (JSONVarde) -> Bool) -> Bool {
            guard let v = o[k] else {
                fel.append(Texter.saknas(plats))
                return false
            }
            guard ok(v) else {
                fel.append(Texter.ogiltigt(plats))
                return false
            }
            return true
        }

        func ruta(_ r: JSONVarde, _ p: String, _ bredd: Double?, _ hojd: Double?, _ tider: inout [Double]) {
            guard let ro = r.somObjekt else {
                fel.append(Texter.ogiltigt(p))
                return
            }
            if krav(ro, "t", "\(p).t", tal), let t = ro["t"]?.somTal {
                if tider.contains(where: { abs(t - $0) < 2 * rutaTol }) { fel.append(Texter.dubblett("\(p).t")) }   // METOD MF8
                tider.append(t)
            }
            if let n = ro["ruta"], !n.arNull, !(heltal(n).map { $0 >= 0 } ?? false) { fel.append(Texter.ogiltigt("\(p).ruta")) }
            if let k = ro["t_klipp"], !k.arNull, !(k.somTal.map { $0.isFinite && $0 >= 0 } ?? false) {
                fel.append(Texter.ogiltigt("\(p).t_klipp"))
            }
            guard krav(ro, "punkter", "\(p).punkter", { $0.somObjekt != nil }), let pk = ro["punkter"]?.somObjekt else { return }
            if punktnamn.allSatisfy({ pk[$0] == nil || pk[$0] == .null }) { fel.append(Texter.ingenPunkt("\(p).punkter")) }
            for n in punktnamn {
                guard let q = pk[n], !q.arNull else { continue }
                let pq = "\(p).punkter.\(n)"
                guard let qo = q.somObjekt else {
                    fel.append(Texter.ogiltigt(pq))
                    continue
                }
                var xy = krav(qo, "x", "\(pq).x", tal)
                xy = krav(qo, "y", "\(pq).y", tal) && xy
                if xy, let b = bredd, let h = hojd, let x = qo["x"]?.somTal, let y = qo["y"]?.somTal,
                   !(0 <= x && x <= b && 0 <= y && y <= h) {
                    fel.append(Texter.utanforBilden(pq))
                }
                _ = krav(qo, "konfidens", "\(pq).konfidens") { $0.somTal.map { $0.isFinite && $0 >= 0 && $0 <= 1 } ?? false }
                if let b = qo["box"], !b.arNull {
                    let l = b.somLista?.compactMap(\.somTal).filter(\.isFinite) ?? []
                    if !(b.somLista?.count == 4 && l.count == 4 && l[2] > 0 && l[3] > 0) { fel.append(Texter.ogiltigt("\(pq).box")) }
                }
            }
        }

        if let f = o["format"] {
            if f.somText != format { fel.append(Texter.formatSkaVara(format)) }
        } else {
            fel.append(Texter.saknas("format"))
        }
        krav(o, "pass", "pass") { $0.somText.map(passID) ?? false }
        krav(o, "vy", "vy") { $0.somText.flatMap(Vy.init(rawValue:)) != nil }
        if let p = o["paket"], !p.arNull, p.somText == nil { fel.append(Texter.ogiltigt("paket")) }
        krav(o, "skapad", "skapad", text)
        if krav(o, "modell", "modell", { $0.somObjekt != nil }), let m = o["modell"]?.somObjekt {
            krav(m, "namn", "modell.namn", text)
            krav(m, "version", "modell.version", text)
            if krav(m, "data", "modell.data", { ($0.somLista?.count ?? 0) > 0 }), let data = m["data"]?.somLista {
                for (i, k) in data.enumerated() {
                    let p = "modell.data[\(i)]"
                    guard let ko = k.somObjekt else {
                        fel.append(Texter.ogiltigt(p))
                        continue
                    }
                    krav(ko, "namn", "\(p).namn", text)
                    krav(ko, "licens", "\(p).licens", text)
                    if let kk = ko["kalla"], !kk.arNull, kk.somText == nil { fel.append(Texter.ogiltigt("\(p).kalla")) }
                }
            }
        }
        var bh = krav(o, "bredd", "bredd") { heltal($0).map { $0 > 0 } ?? false }
        bh = krav(o, "hojd", "hojd") { heltal($0).map { $0 > 0 } ?? false } && bh
        let bredd = bh ? o["bredd"]?.somTal : nil, hojd = bh ? o["hojd"]?.somTal : nil
        if krav(o, "slag", "slag", { ($0.somLista?.count ?? 0) > 0 }), let slag = o["slag"]?.somLista {
            var ids = Set<String>()
            for (i, s) in slag.enumerated() {
                let p = "slag[\(i)]"
                guard let so = s.somObjekt else {
                    fel.append(Texter.ogiltigt(p))
                    continue
                }
                if krav(so, "id", "\(p).id", text), let id = so["id"]?.somText {
                    if ids.contains(id) { fel.append(Texter.dubblett("\(p).id")) }
                    ids.insert(id)
                }
                guard krav(so, "rutor", "\(p).rutor", { ($0.somLista?.count ?? 0) > 0 }),
                      let rutor = so["rutor"]?.somLista else { continue }
                var tider: [Double] = []
                for (j, r) in rutor.enumerated() {
                    ruta(r, "\(p).rutor[\(j)]", bredd, hojd, &tider)
                }
            }
        }
        return fel.count > maxFel ? Array(fel.prefix(maxFel)) + [Texter.flerFel] : fel
    }

    static func tal(_ v: JSONVarde) -> Bool { v.somTal?.isFinite ?? false }
    static func text(_ v: JSONVarde) -> Bool { !(v.somText ?? "").isEmpty }
    /// Ett tal utan decimaler (1 och 1.0 lika, som Pythons `_heltal`).
    static func heltal(_ v: JSONVarde) -> Double? {
        guard let d = v.somTal, d.isFinite, d == d.rounded() else { return nil }
        return d
    }

    /// `yyyyMMdd-HHmmss` med ASCII-siffror.
    static func passID(_ s: String) -> Bool {
        let c = Array(s.unicodeScalars)
        return c.count == 15 && c.enumerated().allSatisfy { i, u in i == 8 ? u == "-" : (48...57).contains(u.value) }
    }

    // MARK: läsningen

    /// Läser och kontrollerar en fil; `FormatFel` med det första felet ("suggestions: …"), fältet
    /// utan värdet. BESLUT B93
    public static func las(_ data: Data) throws -> KlubbForslagFil {
        guard data.count <= maxBytes else { throw FormatFel(Texter.forslagFel(Texter.forStor)) }
        guard let text = String(data: data, encoding: .utf8), let v = try? JSONVarde.las(text) else {
            throw FormatFel(Texter.forslagFel(Texter.inteJSON))
        }
        let fel = kontrollera(v)
        if let f = fel.first {
            throw FormatFel(Texter.forslagFel(fel.count > 1 ? "\(f) (+\(fel.count - 1))" : f))
        }
        return tolka(v)
    }

    /// En kontrollerad fil som värden.
    static func tolka(_ v: JSONVarde) -> KlubbForslagFil {
        func punkt(_ q: JSONVarde?) -> Punkt? {
            guard let q, let o = q.somObjekt, let x = o["x"]?.somTal, let y = o["y"]?.somTal,
                  let k = o["konfidens"]?.somTal else { return nil }
            let box = o["box"]?.somLista?.compactMap(\.somTal)
            return Punkt(x: x, y: y, konfidens: k, box: box?.count == 4 ? box : nil)
        }
        let m = v["modell"]
        let slag = (v["slag"]?.somLista ?? []).map { s in
            Slag(id: s["id"]?.somText ?? "", rutor: (s["rutor"]?.somLista ?? []).map { r in
                let pk = r["punkter"]
                return Ruta(t: r["t"]?.somTal ?? 0, grepp: punkt(pk?["grepp"]), hosel: punkt(pk?["hosel"]),
                            huvud: punkt(pk?["huvud"]), skaftMitt: punkt(pk?["skaft_mitt"]))
            })
        }
        return KlubbForslagFil(
            pass: v["pass"]?.somText ?? "", vy: Vy(rawValue: v["vy"]?.somText ?? "") ?? .dtl,
            paket: v["paket"]?.somText, skapad: v["skapad"]?.somText ?? "",
            modellNamn: m?["namn"]?.somText ?? "", modellVersion: m?["version"]?.somText ?? "",
            dataset: (m?["data"]?.somLista ?? []).map { [$0["namn"]?.somText ?? "", $0["licens"]?.somText ?? ""] },
            bredd: Int(v["bredd"]?.somTal ?? 0), hojd: Int(v["hojd"]?.somTal ?? 0), slag: slag)
    }

    // MARK: matchningen (METOD MF8)

    /// Slagets rutor; tom när slaget saknas eller bildens storlek inte är slagets (punkterna hör
    /// då till en annan bild). Som `klubba_forslag.rutor`.
    public func rutor(slag id: String, bredd: Int, hojd: Int) -> [Ruta] {
        guard bredd == self.bredd, hojd == self.hojd else { return [] }
        return slag.first { $0.id == id }?.rutor ?? []
    }

    /// Index för rutan närmast `t` och högst `rutaTol` därifrån, den tidigare vid lika avstånd.
    /// Som `klubba_forslag.ruta_for`.
    public static func ruta(_ rutor: [Ruta], t: Double) -> Int? {
        var bast: Int? = nil, bastD = Double.infinity
        for (i, r) in rutor.enumerated() {
            let d = abs(r.t - t)
            if d <= rutaTol, d < bastD {
                bast = i
                bastD = d
            }
        }
        return bast
    }

    /// Varje positions ruta i filen ur positionernas visade tider. Som `klubba_forslag.matcha`.
    public static func matcha(_ rutor: [Ruta], tider: [String: Double?]) -> [String: Int?] {
        tider.mapValues { t in t.flatMap { ruta(rutor, t: $0) } }
    }

    /// Mot passet på telefonen (Store): samma pass och vy, och slag som finns. Felen som PC:ns
    /// `klubba_forslag.mot_paket`.
    public func motPass(id: String, vy: Vy, slag ids: Set<String>) -> [String] {
        var fel: [String] = []
        if pass != id { fel.append(Texter.ingetPass) }
        if self.vy != vy { fel.append(Texter.annanVy) }
        for (i, s) in slag.enumerated() where !ids.contains(s.id) { fel.append(Texter.ingetSlag("slag[\(i)].id")) }
        return fel
    }

    /// Filens namn i appens mapp `KlubbForslag/`: "<pass>-<vy>.json". METOD MF8
    public var filnamn: String { "\(pass)-\(vy.rawValue).json" }
    public static let mapp = "KlubbForslag"
    public static func filnamn(pass: String, vy: Vy) -> String? { passID(pass) ? "\(pass)-\(vy.rawValue).json" : nil }
}
