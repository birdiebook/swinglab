import Foundation

/// Ett fel i kontrollen av en `att_jobba_pa.json`: fältet och koden, aldrig värdet (CLAUDE.md,
/// Dataregeln). Samma koder som `Kontrollfel` i tools/pc/att_jobba_pa.py (BESLUT B54); appen
/// visar dem på engelska (`text`, BESLUT B30).
public struct Kontrollfel: Equatable, Sendable, CustomStringConvertible {
    public let falt: String
    public let kod: String

    public init(_ falt: String, _ kod: String) {
        self.falt = falt
        self.kod = kod
    }

    /// "saker[0].fel: not flagged in this session"
    public var text: String { "\(falt): \(Texter.kontrollfel(kod))" }
    public var description: String { text }
}

/// Kontrollen av en `att_jobba_pa.json` mot passets analys och minnet före passet, regel för
/// regel som `kontrollera` i tools/pc/att_jobba_pa.py, så att ett svar från Claude-appen tas
/// emot på telefonen bara när PC:n hade tagit emot det (BESLUT B54). METOD MT5, MT6, MT8, MT10
public enum AttJobbaPaKontroll {
    public static let format = "swinglab-att-jobba-pa/1"
    /// 1–3 saker. METOD MT6
    public static let maxSaker = 3
    /// "Klart när" hålls två pass i rad. METOD MT5
    public static let passIRad = 2
    /// Tecken i tanken och i rörlighetsövningen. METOD MT8
    public static let maxTanke = 60
    public static let maxFysik = 200
    static let villkoren = [">=", "<=", "mellan"]
    static let typer = ["teknik", "teknik_kroppen_gor_det_svart", "troligen_rorlighet"]
    static let stegen = AttJobbaPa.Ovning.stegen
    static let topp = ["format", "pass", "skapad", "saker"]
    static let sak = ["ordning", "fel", "namn", "vy", "matt", "enhet", "nu", "spann", "markning", "ovning", "klart_nar",
                      "foljdfel", "typ", "fysik", "block"]
    static let ovningen = ["id", "text", "tanke", "kalla", "steg"]
    static let klart = ["villkor", "grans", "pa", "pass_i_rad"]
    static let foljd = ["fel", "namn", "vag", "nu", "enhet"]
    static let fysiken = ["test", "treregeln", "ovning"]
    static let blocket = ["start", "vecka"]

    // Värdeorden på ordstam, som i att_jobba_pa.py (BESLUT B13, B30). METOD MT8
    static let vardeorden: Set<String> = ["ok", "okay", "wow", "yay", "bravo", "ideal", "ideally"]
    static let stammar = ["good", "better", "best", "worse", "worst", "bad", "poor", "great", "perfect", "nice", "excellen",
                          "super", "cool", "neat", "sweet", "kudos", "nail", "crush", "pure", "crisp", "boring", "fine",
                          "awesome", "amazing", "fantastic", "terrific", "terribl", "horribl", "awful", "brillian", "superb",
                          "wonderful", "outstanding", "impressiv", "beautiful", "lovely", "gorgeous", "flawless", "congrat",
                          "unfortunat", "sloppy", "ugly", "incredibl", "remarkabl", "magnificent", "splendid", "marvel",
                          "stunning", "spectacular", "fabulous", "solid", "mistake", "wrong"]
    static let undantag = ["badge", "badminton", "bestow", "supinat", "coolin"]

    static func ordtecken(_ c: Unicode.Scalar) -> Bool {
        ("a"..."z").contains(c) || ("A"..."Z").contains(c) || "åäöéüÅÄÖÉÜ".unicodeScalars.contains(c)
    }

    /// \w och \s med re.ASCII, som Python (BESLUT B54).
    static func ordkaraktar(_ c: Unicode.Scalar) -> Bool {
        c == "_" || ("a"..."z").contains(c) || ("A"..."Z").contains(c) || ("0"..."9").contains(c)
    }

    static func blanktecken(_ c: Unicode.Scalar) -> Bool {
        [" ", "\t", "\n", "\r", "\u{0B}", "\u{0C}"].contains(c)
    }

    /// Frasen "well done" (`\bwell\s+done\b`, utan hänsyn till skiftläge).
    static func wellDone(_ s: [Unicode.Scalar]) -> Bool {
        let well = Array("well".unicodeScalars), done = Array("done".unicodeScalars)
        func lag(_ c: Unicode.Scalar) -> Unicode.Scalar {
            ("A"..."Z").contains(c) ? Unicode.Scalar(c.value + 32)! : c
        }
        func lika(_ i: Int, _ w: [Unicode.Scalar]) -> Bool {
            guard i + w.count <= s.count else { return false }
            return (0..<w.count).allSatisfy { lag(s[i + $0]) == w[$0] }
        }
        var i = 0
        while i < s.count {
            if lika(i, well), i == 0 || !ordkaraktar(s[i - 1]) {
                var j = i + 4
                var mellan = 0
                while j < s.count, blanktecken(s[j]) {
                    j += 1
                    mellan += 1
                }
                if mellan > 0, lika(j, done), j + 4 == s.count || !ordkaraktar(s[j + 4]) { return true }
            }
            i += 1
        }
        return false
    }

    /// Om texten bär ett värdeord (`vardeord` i Python). METOD MT8
    public static func harVardeord(_ text: String) -> Bool {
        let s = Array(text.unicodeScalars)
        if wellDone(s) { return true }
        var ord: [String] = []
        var nu = ""
        for c in s {
            if ordtecken(c) {
                nu.unicodeScalars.append(c)
            } else if !nu.isEmpty {
                ord.append(nu.lowercased())
                nu = ""
            }
        }
        if !nu.isEmpty { ord.append(nu.lowercased()) }
        for o in ord {
            if undantag.contains(where: { o.hasPrefix($0) }) { continue }
            if vardeorden.contains(o) || stammar.contains(where: { o.hasPrefix($0) }) { return true }
        }
        return false
    }

    static func fritext(_ v: JSONVarde?, _ falt: String, _ maxlen: Int, _ fel: inout [Kontrollfel]) {
        guard let s = v?.somText, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            fel.append(Kontrollfel(falt, "text"))
            return
        }
        if s.unicodeScalars.count > maxlen { fel.append(Kontrollfel(falt, "for_lang")) }
        if s.unicodeScalars.contains(where: { ("0"..."9").contains($0) }) {
            fel.append(Kontrollfel(falt, "siffror"))
        }
        if harVardeord(s) { fel.append(Kontrollfel(falt, "vardeord")) }
        if s.unicodeScalars.contains("!") { fel.append(Kontrollfel(falt, "utropstecken")) }
        if s.unicodeScalars.contains(where: { "åäöÅÄÖ".unicodeScalars.contains($0) }) {
            fel.append(Kontrollfel(falt, "svenska"))
        }
    }

    static func sok(_ falt: String, _ k: String) -> String { falt == "filen" ? k : "\(falt).\(k)" }

    /// Formen är stängd: okända och saknade nycklar. Svarar om värdet var ett objekt.
    static func nycklar(_ d: JSONVarde?, _ tillatna: [String], _ falt: String, _ fel: inout [Kontrollfel]) -> Bool {
        guard let o = d?.somObjekt else {
            fel.append(Kontrollfel(falt, "objekt"))
            return false
        }
        for k in o.nycklar where !tillatna.contains(k) { fel.append(Kontrollfel(sok(falt, k), "okand_nyckel")) }
        for k in tillatna where o[k] == nil { fel.append(Kontrollfel(sok(falt, k), "saknas")) }
        return true
    }

    /// `skapad` som tid i ISO 8601: yyyy-MM-dd och valfritt THH:mm[:ss[.f]] med Z eller ±HH:mm
    /// (`skapad_ok` i Python).
    public static func skapadOK(_ v: JSONVarde?) -> Bool {
        guard let s = v?.somText.map({ Array($0.unicodeScalars) }) else { return false }
        var i = 0
        func tal(_ n: Int) -> Int? {
            guard i + n <= s.count else { return nil }
            var v = 0
            for c in s[i..<(i + n)] {
                guard ("0"..."9").contains(c) else { return nil }
                v = v * 10 + Int(c.value) - 48
            }
            i += n
            return v
        }
        func tecken(_ c: Unicode.Scalar) -> Bool {
            guard i < s.count, s[i] == c else { return false }
            i += 1
            return true
        }
        guard let ar = tal(4), tecken("-"), let man = tal(2), tecken("-"), let dag = tal(2) else { return false }
        guard (1...12).contains(man), dag >= 1, dag <= Dag.dagar(i: man, ar: ar), ar >= 1 else { return false }
        if i == s.count { return true }
        guard tecken("T") || tecken(" "), let h = tal(2), tecken(":"), let mi = tal(2) else { return false }
        var sek: Int? = nil
        if tecken(":") {
            guard let x = tal(2) else { return false }
            sek = x
            if tecken(".") {
                var n = 0
                while i < s.count, ("0"..."9").contains(s[i]), n < 6 {
                    i += 1
                    n += 1
                }
                guard n >= 1 else { return false }
            }
        }
        var zh: Int? = nil, zm: Int? = nil
        if tecken("Z") {
        } else if tecken("+") || tecken("-") {
            guard let a = tal(2), tecken(":"), let b = tal(2) else { return false }
            zh = a
            zm = b
        }
        guard i == s.count else { return false }
        return h <= 23 && mi <= 59 && (sek ?? 0) <= 59 && (zh ?? 0) <= 23 && (zm ?? 0) <= 59
    }

    /// yyyyMMdd-HHmmss med en dag som finns (`pass_form` i Python).
    static func passForm(_ s: String) -> Bool {
        let c = Array(s.unicodeScalars)
        guard c.count == 15, c[8] == "-",
              c.enumerated().allSatisfy({ $0.offset == 8 || ("0"..."9").contains($0.element) }) else { return false }
        return Dag.fran(s) != nil && !s.hasPrefix("0000")
    }

    /// Alla fel i filen mot passets analys och minnet före passet (`Ovningslage.minne(…, fore:
    /// passet)`). Samma fel i samma ordning som Python.
    public static func kontrollera(_ d: JSONVarde, analys: Passanalys, ovningar: [Ovningslage], katalog: Katalog,
                                   kedjor: Kedjor = .appens) -> [Kontrollfel] {
        var K: [String: Katalog.Fel] = [:]
        for f in katalog.fel { K[f.id] = f }
        var fas: [String: Int] = [:]
        for (i, f) in kedjor.faser.enumerated() { fas[f] = i }
        var fel: [Kontrollfel] = []
        guard nycklar(d, topp, "filen", &fel) else { return fel }
        if d["format"] != .text(format) { fel.append(Kontrollfel("format", "format")) }
        let passText = d["pass"]?.somText
        let passOK = passText.map(passForm) ?? false
        if !passOK {
            fel.append(Kontrollfel("pass", "pass_form"))
        } else if passText != analys.pass {
            fel.append(Kontrollfel("pass", "inte_analysens"))
        }
        if !skapadOK(d["skapad"]) { fel.append(Kontrollfel("skapad", "iso")) }
        guard let saker = d["saker"]?.somLista, (1...maxSaker).contains(saker.count) else {
            return fel + [Kontrollfel("saker", "antal")]
        }
        var bed: [String: Passanalys.Rad] = [:]
        for b in analys.bedomning where bed[b.id] == nil { bed[b.id] = b }
        var kand: [String: Passanalys.Kandidat] = [:]
        for k in analys.kandidater { kand[k.fel] = k }
        var minne: [String: Ovningslage] = [:]
        for o in ovningar where o.lage != "avslutad" { minne[o.fel] = o }
        let valda: [JSONVarde] = saker.compactMap { $0.somObjekt != nil ? ($0["fel"] ?? .null) : nil }
        if Set(valda.map(\.pyNyckel)).count != valda.count { fel.append(Kontrollfel("saker", "dubblett")) }
        let valdaText = Set(valda.compactMap(\.somText))
        var forraFas = -1
        for (i, s) in saker.enumerated() {
            let p = "saker[\(i)]"
            guard nycklar(s, sak, p, &fel) else { continue }
            if !(s["ordning"] ?? .null).lika(.i(i + 1)) { fel.append(Kontrollfel("\(p).ordning", "ordning")) }
            guard let fid = s["fel"]?.somText, let k = K[fid] else {
                fel.append(Kontrollfel("\(p).fel", "ej_i_katalogen"))
                continue
            }
            if !k.aktiv { fel.append(Kontrollfel("\(p).fel", "avstangt")) }
            // Måttet och bandet som analysen bedömde felet på: katalogens, utom klubbans källa när
            // klubban är markerad och ett band som klubban flyttar på andra klubbor (BESLUT B86, B88).
            let kb = bed[fid]
            let matt = kb?.matt ?? k.matt, spann = kb != nil ? kb!.spann : k.gront
            for (f, v) in [("namn", k.namn), ("vy", k.vy), ("matt", matt)] where s[f] != .text(v) {
                fel.append(Kontrollfel("\(p).\(f)", "katalogens"))
            }
            if s["enhet"] != .text(Avrundning.enhet(matt)) { fel.append(Kontrollfel("\(p).enhet", "mattets")) }
            if !(s["spann"] ?? .null).lika(.spann(spann)) { fel.append(Kontrollfel("\(p).spann", "katalogens")) }
            let fI = fas[k.fas] ?? fas.count
            if fI < forraFas { fel.append(Kontrollfel(p, "svingens_ordning")) }
            forraFas = max(forraFas, fI)
            if kedjor.orsaker(fid).contains(where: { valdaText.contains($0.fel) }) {
                fel.append(Kontrollfel("\(p).fel", "foljdfel_av_vald"))
            }

            guard let b = bed[fid] else {
                fel.append(Kontrollfel("\(p).fel", "ej_i_analysen"))
                continue
            }
            if b.status == .gul || b.status == .rod {
                if kand[fid]?.foljdfel == true { fel.append(Kontrollfel("\(p).fel", "foljdfel")) }
            } else if b.status == .okand {
                if !kand.isEmpty { fel.append(Kontrollfel("\(p).fel", "okant_med_flaggade")) }
            } else {
                fel.append(Kontrollfel("\(p).fel", "inte_flaggat"))
            }
            if !(s["nu"] ?? .null).lika(.d(b.visat)) { fel.append(Kontrollfel("\(p).nu", "analysens_tal")) }

            let o = minne[fid]
            let ov = s["ovning"]
            let ovObj = ov?.somObjekt
            let text: JSONVarde = ovObj.map { $0["text"] ?? .null } ?? .null
            let ovId: JSONVarde = ovObj.map { $0["id"] ?? .null } ?? .null
            let fortsatter = o != nil && ovId == .text(o!.ovningId)
            if fortsatter && o!.lage == "klart" { fel.append(Kontrollfel(p, "klar")) }
            if fortsatter && o!.lage == "byt_ovning" { fel.append(Kontrollfel("\(p).ovning", "byt_ovning")) }
            if let o, let id = ovId.somText, o.forraOvningar.contains(id) {
                fel.append(Kontrollfel("\(p).ovning.id", "redan_provad"))
            }

            if nycklar(ov, ovningen, "\(p).ovning", &fel), let ov {
                let kalla = ov["kalla"]
                if kalla == .text("katalog") {
                    if ovId != .text(k.ovningId) { fel.append(Kontrollfel("\(p).ovning.id", "katalogens")) }
                    if text != .text(k.ovning) { fel.append(Kontrollfel("\(p).ovning.text", "katalogens")) }
                } else if kalla == .text("research3") {
                    if let x = kedjor.ovningar.first(where: { $0.fel == fid && ovId == .text($0.id) }) {
                        if text != .text(x.text) { fel.append(Kontrollfel("\(p).ovning.text", "kedjornas")) }
                    } else {
                        fel.append(Kontrollfel("\(p).ovning.id", "ej_i_kedjorna"))
                    }
                } else {
                    fel.append(Kontrollfel("\(p).ovning.kalla", "kalla"))
                }
                fritext(ov["tanke"], "\(p).ovning.tanke", maxTanke, &fel)
                let steg = ov["steg"]?.somText
                if steg == nil || !stegen.contains(steg!) {
                    fel.append(Kontrollfel("\(p).ovning.steg", "steg"))
                } else if fortsatter, let ost = stegen.firstIndex(of: o!.steg) {
                    let hopp = stegen.firstIndex(of: steg!)! - ost
                    if !(0...1).contains(hopp) { fel.append(Kontrollfel("\(p).ovning.steg", "steg_hopp")) }
                } else if steg != stegen[0] {
                    fel.append(Kontrollfel("\(p).ovning.steg", "steg_forsta"))
                }
            }

            let kn = s["klart_nar"]
            if nycklar(kn, klart, "\(p).klart_nar", &fel), let kn {
                let villkor = kn["villkor"]?.somText
                if villkor == nil || !villkoren.contains(villkor!) {
                    fel.append(Kontrollfel("\(p).klart_nar.villkor", "villkor"))
                } else if villkor == "mellan" {
                    let g = kn["grans"]?.somLista
                    if !(g?.count == 2 && g!.allSatisfy { $0.somTal != nil } && g![0].somTal! <= g![1].somTal!) {
                        fel.append(Kontrollfel("\(p).klart_nar.grans", "grans_spann"))
                    }
                } else if kn["grans"]?.somTal == nil {
                    fel.append(Kontrollfel("\(p).klart_nar.grans", "grans_tal"))
                }
                if kn["pa"] != .text("forsta_serien") { fel.append(Kontrollfel("\(p).klart_nar.pa", "pa")) }
                if kn["pass_i_rad"]?.somTal != Double(passIRad) {
                    fel.append(Kontrollfel("\(p).klart_nar.pass_i_rad", "pass_i_rad"))
                }
                let knV = kn["villkor"] ?? .null, knG = kn["grans"] ?? .null
                let markning = s["markning"] ?? .null
                if fortsatter, let o {
                    if !(knV.lika(.text(o.villkor)) && knG.lika(o.grans)) {
                        fel.append(Kontrollfel("\(p).klart_nar", "last"))
                    }
                    if !markning.lika(.t(o.markning)) { fel.append(Kontrollfel("\(p).markning", "last")) }
                } else if let bkn = b.klartNar {
                    if !(knV.lika(.text(bkn.villkor)) && knG.lika(bkn.grans)) {
                        fel.append(Kontrollfel("\(p).klart_nar", "analysens"))
                    }
                    if !markning.lika(.t(bkn.markning)) { fel.append(Kontrollfel("\(p).markning", "analysens")) }
                } else {
                    fel.append(Kontrollfel("\(p).klart_nar", "inget_forslag"))
                }
            }

            let blk = s["block"]
            if nycklar(blk, blocket, "\(p).block", &fel), passOK, let blk, let dag = Dag.fran(passText!) {
                let start = o.flatMap { Dag.fran($0.felStart) } ?? dag
                if blk["start"] != .text(Dag.iso(start)) { fel.append(Kontrollfel("\(p).block.start", "block_start")) }
                if !(blk["vecka"] ?? .null).lika(.i(Dag.vecka(fran: start, till: dag))) {
                    fel.append(Kontrollfel("\(p).block.vecka", "block_vecka"))
                }
            }

            if let ff = s["foljdfel"]?.somLista {
                for (j, f) in ff.enumerated() {
                    let q = "\(p).foljdfel[\(j)]"
                    guard nycklar(f, foljd, q, &fel) else { continue }
                    guard let ffid = f["fel"]?.somText, let kf = K[ffid] else {
                        fel.append(Kontrollfel("\(q).fel", "ej_i_katalogen"))
                        continue
                    }
                    if let vag = kedjor.orsaker(ffid).first(where: { $0.fel == fid })?.vag {
                        if !(f["vag"] ?? .null).lika(.texter(vag)) { fel.append(Kontrollfel("\(q).vag", "vag")) }
                    } else {
                        fel.append(Kontrollfel("\(q).fel", "ingen_kedja"))
                    }
                    if valdaText.contains(ffid) { fel.append(Kontrollfel("\(q).fel", "vald")) }
                    if f["namn"] != .text(kf.namn) { fel.append(Kontrollfel("\(q).namn", "katalogens")) }
                    if f["enhet"] != .text(Avrundning.enhet(bed[ffid]?.matt ?? kf.matt)) {
                        fel.append(Kontrollfel("\(q).enhet", "mattets"))
                    }
                    if !(f["nu"] ?? .null).lika(.d(bed[ffid]?.visat)) {
                        fel.append(Kontrollfel("\(q).nu", "analysens_tal"))
                    }
                }
            } else {
                fel.append(Kontrollfel("\(p).foljdfel", "lista"))
            }

            let typ = s["typ"]?.somText
            let fy = s["fysik"] ?? .null
            if let o, o.lage == "fysik", fy == .null { fel.append(Kontrollfel("\(p).fysik", "fysik_forst")) }
            if typ == nil || !typer.contains(typ!) {
                fel.append(Kontrollfel("\(p).typ", "typ"))
            } else if fy == .null {
                if typ != "teknik" { fel.append(Kontrollfel("\(p).fysik", "kravs")) }
            } else if nycklar(fy, fysiken, "\(p).fysik", &fel) {
                let tre = fy["treregeln"]?.somLista
                let bools: [Bool]? = tre.flatMap { l -> [Bool]? in
                    let b = l.compactMap { v -> Bool? in if case let .bool(x) = v { return x } else { return nil } }
                    return b.count == l.count ? b : nil
                }
                if let b = bools, b.count == 3 {
                    let t = b == [true, true, true] ? "troligen_rorlighet"
                        : b == [true, true, false] ? "teknik_kroppen_gor_det_svart" : "teknik"
                    if t != typ { fel.append(Kontrollfel("\(p).typ", "treregeln")) }
                } else {
                    fel.append(Kontrollfel("\(p).fysik.treregeln", "treregeln"))
                }
                if !kedjor.test(fid).contains(where: { fy["test"] == .text($0) }) {
                    fel.append(Kontrollfel("\(p).fysik.test", "test"))
                }
                if typ == "teknik" {
                    if (fy["ovning"] ?? .null) != .null { fel.append(Kontrollfel("\(p).fysik.ovning", "null")) }
                } else {
                    fritext(fy["ovning"], "\(p).fysik.ovning", maxFysik, &fel)
                }
            }
        }
        return fel
    }
}
