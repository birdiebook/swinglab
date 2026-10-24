import Foundation

/// Underlaget till Claude-appen (S5b, BESLUT B52): texten som "Ask Claude" kopierar. Den är
/// skillens regler (`ClaudeKallor.instruktion`, avsnitten claude-appen i SKILL.md) och passets
/// data som kompakt JSON, räknad på telefonen. Samma text som `tools/pc/underlag.py` ger för
/// samma passhistorik, tecken för tecken (BESLUT B12, BESLUT B53). Svaret tillbaka läses med
/// `svar(_:)` (ClaudeSvar). METOD MT11
public struct ClaudeUnderlag: Sendable {
    /// Felens väg i texten: de senaste passen. METOD MT11
    public static let historikPass = 6
    /// Uppföljningens senaste rader per övning. METOD MT11
    public static let uppfoljningRader = 4
    /// z mot baslinjen med en decimal. METOD MT11
    public static let zDecimaler = 1
    /// Mallar för nya fel; övningar som fortsätter kommer till. METOD MT11
    public static let maxNyaMallar = 3
    public static let rubrik = "# SwingLab: Att jobba på efter passet "
    public static let dataRubrik = "## Datan"

    /// Passets enhet (huvudklubban), och enheterna med samma klubba och längd till och med det.
    public let analys: Passanalys
    public let analyser: [Passanalys]
    /// Minnet före passets val (`Ovningslage.minne(…, fore: passet)`).
    public let ovningar: [Ovningslage]
    /// Valen för passen i sammanhanget.
    public let filer: [AttJobbaPa]
    public let skapad: String
    public let katalog: Katalog
    public let kedjor: Kedjor

    /// Underlaget för passet `nu` ur passen (i valfri ordning) och alla hämtade
    /// `att_jobba_pa.json` (`FocusInbox.readAll`), som `underlag` i underlag.py: enheterna med
    /// samma klubba och längd som passets huvudklubba, valen för deras pass och minnet före
    /// passets val (BESLUT B56). `skapad` = tiden i ISO 8601. nil när passet saknas.
    public init?(passen: [Passrader], nu: String, filer: [AttJobbaPa], skapad: String, katalog: Katalog,
                 kedjor: Kedjor = .appens) {
        let enh = Passanalys.historik(passen, katalog: katalog, kedjor: kedjor)
        let ctx = Passanalys.sammanhang(enh, nu: nu)
        guard let n = ctx.first(where: { $0.huvud && $0.pass == nu }) else { return nil }
        let huvudpass = Set(ctx.filter(\.huvud).map(\.pass))
        let docs = filer.filter { huvudpass.contains($0.pass) }
        analys = n
        analyser = ctx
        ovningar = Ovningslage.minne(ctx, docs, till: nu, fore: nu, kedjor: kedjor)
        self.filer = docs
        self.skapad = skapad
        self.katalog = katalog
        self.kedjor = kedjor
    }

    // MARK: texten

    /// Rubriken, instruktionen och datan i ett kodblock.
    public var text: String {
        Self.rubrik + analys.pass + "\n\n" + ClaudeKallor.instruktion + "\n\n" + Self.dataRubrik + "\n\n```json\n"
            + data.skriv() + "\n```\n"
    }

    // MARK: datan (underlag.py data)

    static func dag(_ pass: String) -> String { Dag.fran(pass).map(Dag.iso) ?? "" }

    static func tal(_ v: Double?) -> JSONVarde { .d(v) }

    static func z(_ v: Double?) -> JSONVarde {
        guard let v else { return .null }
        return .tal(Avrundning.pyRound(v, zDecimaler))
    }

    static func klartNarFil(villkor: String, grans: JSONVarde, pa: String = "forsta_serien",
                            passIRad: Int = AttJobbaPaKontroll.passIRad) -> JSONVarde {
        .o([("villkor", .text(villkor)), ("grans", grans), ("pa", .text(pa)), ("pass_i_rad", .i(passIRad))])
    }

    func bedomning() -> JSONVarde {
        .lista(analys.bedomning.compactMap { b -> JSONVarde? in
            guard b.status != .av, b.status != .gron, let visat = b.visat else { return nil }
            var p: [(String, JSONVarde)] = [("id", .text(b.id)), ("vy", .text(b.vy)), ("enhet", .text(b.enhet)),
                                            ("status", .text(b.status.rawValue))]
            if let g = b.grund { p.append(("grund", .text(g))) }
            if b.z != nil { p.append(("z", Self.z(b.z))) }
            p += [("n", .i(b.n)), ("visat", .tal(visat)), ("forsta_serien", .d(b.forstaSerien)),
                  ("spann", .spann(b.spann))]
            if b.gult != nil { p.append(("gult", .spann(b.gult))) }
            if let bas = b.baslinje {
                p.append(("baslinje", .o([("median", .d(bas.median)), ("sd", .d(bas.sd)), ("n", .i(bas.n))])))
            }
            if let m = b.motForra { p.append(("mot_forra", .o([("skillnad", .d(m.skillnad)), ("tydlig", .bool(m.tydlig))]))) }
            return .o(p)
        })
    }

    func kandidater() -> JSONVarde {
        .lista(analys.kandidater.map { k -> JSONVarde in
            .o([("fel", .text(k.fel)), ("status", .text(k.status.rawValue)), ("fas", .text(k.fas)),
                ("orsaker", .o(k.orsaker.map { ($0.fel, JSONVarde.texter($0.vag)) })), ("foljdfel", .bool(k.foljdfel)),
                ("fysik", .texter(k.fysik))])
        })
    }

    func historik() -> JSONVarde {
        let passen = Array(analyser.filter { $0.pass <= analys.pass }.sorted(by: Passanalys.fore)
            .suffix(Self.historikPass))
        var fel: [(String, JSONVarde)] = []
        for f in katalog.fel where f.aktiv {
            let rader = passen.map { u -> JSONVarde in
                guard let b = u.rad(f.id), let v = b.visat else { return .null }
                return .lista([.tal(v), .text(b.status.rawValue)])
            }
            let flaggat = passen.contains { u in
                guard let b = u.rad(f.id), b.visat != nil else { return false }
                return b.status != .gron
            }
            if flaggat { fel.append((f.id, JSONVarde.lista(rader))) }
        }
        return .o([("pass", .texter(passen.map(\.pass))), ("fel", .o(fel))])
    }

    static func uppfoljning(_ u: Ovningslage.Uppfoljning) -> JSONVarde {
        var p: [(String, JSONVarde)] = [("pass", .text(u.pass)), ("forsta_serien", .d(u.forstaSerien))]
        if let up = u.uppfyllt { p.append(("uppfyllt", .bool(up))) }
        if let r = u.rorelse, let t = u.tydlig { p += [("rorelse", .tal(r)), ("tydlig", .bool(t))] }
        return .o(p)
    }

    static func ovningMinne(_ o: Ovningslage) -> JSONVarde {
        if o.lage == "avslutad" {
            return .o([("fel", .text(o.fel)), ("aktuell", .bool(o.aktuell)), ("lage", .text(o.lage)),
                       ("ovning_id", .text(o.ovningId))])
        }
        return .o([
            ("fel", .text(o.fel)), ("aktuell", .bool(o.aktuell)), ("lage", .text(o.lage)), ("klart_skal", .t(o.klartSkal)),
            ("ovning_id", .text(o.ovningId)), ("forra_ovningar", .texter(o.forraOvningar)), ("steg", .text(o.steg)),
            ("typ", .text(o.typ)), ("fel_start", .text(o.felStart)), ("valt_i_pass", .text(o.valtIPass)),
            ("klart_nar", klartNarFil(villkor: o.villkor, grans: o.grans, pa: o.pa, passIRad: o.passIRad)),
            ("markning", .t(o.markning)), ("start_forsta_serien", .d(o.startForstaSerien)), ("spridning", .d(o.spridning)),
            ("uppfoljning", .lista(o.uppfoljning.suffix(uppfoljningRader).map(uppfoljning))),
            ("uppfyllt_i_rad", .i(o.uppfylltIRad)), ("pass_utan_rorelse", .i(o.passUtanRorelse)),
            ("dagar_sedan_felet_valdes", .i(o.dagarSedanFeletValdes)),
            ("rorelse_sedan_felet_valdes", .bool(o.rorelseSedanFeletValdes)),
        ])
    }

    func pagaende() -> JSONVarde {
        guard let d = filer.filter({ $0.pass < analys.pass }).enumerated()
            .max(by: { ($0.element.pass, $0.offset) < ($1.element.pass, $1.offset) })?.element else { return .null }
        return .o([("pass", .text(d.pass)), ("saker", .lista(d.saker.map { s -> JSONVarde in
            .o([("fel", .text(s.fel)), ("ovning_id", .text(Ovningslage.id(s.ovning))), ("steg", .text(s.ovning.steg)),
                ("tanke", .text(s.ovning.tanke)), ("typ", .text(s.typ)),
                ("block", .o([("start", .text(s.block.start)), ("vecka", .i(s.block.vecka))]))])
        }))])
    }

    /// En övning att välja: id, text, källa och (för katalogens, eller den som fortsätter) tanken.
    func alternativ(_ fid: String, _ ovId: String, tanke: String? = nil) -> JSONVarde? {
        guard let k = katalog.fel.first(where: { $0.id == fid }) else { return nil }
        let t = (tanke?.isEmpty == false) ? tanke : nil
        if ovId == k.ovningId {
            return .o([("id", .text(ovId)), ("text", .text(k.ovning)), ("kalla", .text("katalog")),
                       ("tanke", .text(t ?? k.tanke))])
        }
        guard let x = kedjor.ovningar.first(where: { $0.fel == fid && $0.id == ovId }) else { return nil }
        var p: [(String, JSONVarde)] = [("id", .text(ovId)), ("text", .text(x.text)), ("kalla", .text("research3"))]
        if let t { p.append(("tanke", .text(t))) }
        return .o(p)
    }

    /// En mall per fel som går att välja, som `mallar` i underlag.py. METOD MT11
    func mallar() -> JSONVarde {
        var K: [String: Katalog.Fel] = [:]
        for f in katalog.fel { K[f.id] = f }
        let kand = analys.kandidater
        var minne: [String: Ovningslage] = [:]
        for o in ovningar where o.lage != "avslutad" { minne[o.fel] = o }
        let fel: [String] = kand.isEmpty
            ? analys.bedomning.filter { $0.status == .okand && $0.klartNar != nil && $0.visat != nil }.map(\.id)
            : kand.filter { !$0.foljdfel }.map(\.fel)
        var nya = 0
        guard let dag = Dag.fran(analys.pass) else { return .lista([]) }
        let stegen = AttJobbaPa.Ovning.stegen
        var ut: [JSONVarde] = []
        for fid in fel {
            guard let k = K[fid], let b = analys.rad(fid) else { continue }
            let o = minne[fid]
            if o?.lage == "klart" { continue }
            var nuvarande: JSONVarde? = nil
            if let o, ["ny", "fortsatt", "fysik"].contains(o.lage) {
                nuvarande = alternativ(fid, o.ovningId, tanke: o.tanke)
            }
            let kn: JSONVarde, markning: String?, val: [JSONVarde], steg: [String]
            if let nuvarande, let o {
                kn = Self.klartNarFil(villkor: o.villkor, grans: o.grans, pa: o.pa, passIRad: o.passIRad)
                markning = o.markning
                let i = stegen.firstIndex(of: o.steg) ?? 0
                val = [nuvarande]
                steg = Array(stegen[i..<min(i + 2, stegen.count)])
            } else {
                guard let bkn = b.klartNar, nya < Self.maxNyaMallar else { continue }
                nya += 1
                kn = Self.klartNarFil(villkor: bkn.villkor, grans: bkn.grans)
                markning = bkn.markning
                let provade = o.map { [$0.ovningId] + $0.forraOvningar } ?? []
                var sedda = Set<String>()
                var v: [JSONVarde] = []
                for id in [k.ovningId] + kedjor.ovningar.filter({ $0.fel == fid }).map(\.id) {
                    if provade.contains(id) || sedda.contains(id) { continue }
                    sedda.insert(id)
                    if let a = alternativ(fid, id) { v.append(a) }
                }
                val = v
                steg = [stegen[0]]
            }
            let start = o.flatMap { Dag.fran($0.felStart) } ?? dag
            let foljd: [JSONVarde] = kand.filter { $0.foljdfel }.compactMap { x -> JSONVarde? in
                guard let vag = x.orsaker.first(where: { $0.fel == fid })?.vag, let kx = K[x.fel] else { return nil }
                return .o([("fel", .text(x.fel)), ("namn", .text(kx.namn)), ("vag", .texter(vag)),
                           ("nu", .d(analys.rad(x.fel)?.visat)), ("enhet", .text(Avrundning.enhet(kx.matt)))])
            }
            ut.append(.o([
                ("fel", .text(fid)), ("namn", .text(k.namn)), ("vy", .text(k.vy)), ("matt", .text(k.matt)),
                ("enhet", .text(Avrundning.enhet(k.matt))), ("nu", .d(b.visat)), ("grund", .t(b.grund)),
                ("spann", .spann(k.gront)),
                ("markning", .t(markning)), ("klart_nar", kn), ("foljdfel", .lista(foljd)),
                ("block", .o([("start", .text(Dag.iso(start))), ("vecka", .i(Dag.vecka(fran: start, till: dag)))])),
                ("ovning_val", .lista(val)), ("steg_val", .texter(steg)), ("fysik_test", .texter(kedjor.test(fid))),
            ]))
        }
        return .lista(ut)
    }

    /// Passets data till Claude, fält för fält som `data` i underlag.py. METOD MT11
    public var data: JSONVarde {
        let a = analys
        let dtl = a.slag.filter { $0.vy == .dtl }.count, fo = a.slag.filter { $0.vy == .fo }.count
        return .o([
            ("pass", .text(a.pass)),
            ("datum", .text(Self.dag(a.pass))),
            ("klubba", .t(a.klubba)),
            ("slag", .o([("dtl", .i(dtl)), ("fo", .i(fo))])),
            ("tempo_vy", .text(a.tempoVy)),
            ("forra", .t(a.forra)),
            ("baslinje", .o([("pass", .i(a.baslinjePass.count)),
                             ("svingar", .o([("dtl", .i(a.baslinjeSvingar["dtl"] ?? 0)),
                                             ("fo", .i(a.baslinjeSvingar["fo"] ?? 0))]))])),
            ("kandidater", kandidater()),
            ("bedomning", bedomning()),
            ("spridning", .lista(a.spridning.filter { $0.n > 0 }.map { s -> JSONVarde in
                .o([("matt", .text(s.matt)), ("vy", .text(s.vy)), ("n", .i(s.n)), ("visat", .d(s.visat))])
            })),
            ("historik", historik()),
            ("ovningar", .lista(ovningar.map(Self.ovningMinne))),
            ("pagaende", pagaende()),
            ("fil", .o([("format", .text(AttJobbaPaKontroll.format)), ("pass", .text(a.pass)),
                        ("skapad", .text(skapad))])),
            ("mallar", mallar()),
        ])
    }

    // MARK: svaret

    /// Svaret som Johannes kopierat i Claude-appen, kontrollerat mot det här passet som PC:n
    /// gör det (ClaudeSvar, BESLUT B54).
    public func svar(_ text: String) -> ClaudeSvar.Resultat {
        ClaudeSvar.las(text, analys: analys, ovningar: ovningar, katalog: katalog, kedjor: kedjor)
    }
}
