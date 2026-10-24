import Foundation
import Swing

// Ett parat pass på den styrande telefonen (S6g, BESLUT B80–B83, METOD MS30, MS31): den andra
// telefonens klipp (`AnnanVideo`), synken mellan vyerna på träffens tid, raden "14 swings · 12 from
// both phones", förloppet, den andra vyns slag och mått ur bunten (S6c-2), paketet för den andra
// vyn (Send to PC) och varningen för samma vy. Bara Foundation, så att allt prövas på Linux.

/// Den andra telefonens video i den styrandes pass: `<vy>/video.json` med klippen och de hela
/// inspelningarna som kommit (BESLUT B81). Filerna ligger i `<vy>/Klipp/<slag>.mov` och
/// `<vy>/Video/<serie>.mov` i passets mapp. METOD MS30
public struct AnnanVideo: Codable, Equatable, Sendable {
    public static let formatName = "swinglab-annan-video/1"
    public static let filnamn = "video.json"

    public struct Klipp: Codable, Equatable, Sendable {
        /// Filen i passets mapp ("fo/Klipp/s03.mov").
        public var fil: String
        /// Serien i följarens pass.
        public var serie: Int
        /// Klippets början i följarens fil (den begärda, inom filen), s; nil för en hel inspelning.
        public var fran: Double?
        /// Klicket i följarens fil som den styrande räknade med, s.
        public var klick: Double?
        /// Klicket mätt i klippet, s i klippet; nil = inget klick hördes (synken tar då det begärda).
        public var klickIKlipp: Double?
        /// Klippets längd, s.
        public var langd: Double?
        public var bytes: Int
        public var id: String

        public init(fil: String, serie: Int, fran: Double? = nil, klick: Double? = nil, klickIKlipp: Double? = nil,
                    langd: Double? = nil, bytes: Int, id: String) {
            self.fil = fil
            self.serie = serie
            self.fran = fran
            self.klick = klick
            self.klickIKlipp = klickIKlipp
            self.langd = langd
            self.bytes = bytes
            self.id = id
        }

        enum CodingKeys: String, CodingKey {
            case fil, serie, fran = "fran_s", klick = "klick_s", klickIKlipp = "klick_i_klipp_s", langd = "langd_s", bytes, id
        }
    }

    public var format: String
    public var pass: String
    /// Den andra telefonens vy.
    public var vy: Vy
    /// Namnet (den styrandes slag, eller "video-01") → klippet.
    public var klipp: [String: Klipp]

    public init(pass: String, vy: Vy, klipp: [String: Klipp] = [:]) {
        format = Self.formatName
        self.pass = pass
        self.vy = vy
        self.klipp = klipp
    }

    /// Mappen för den andra vyn i passets mapp: "fo" eller "dtl".
    public static func mappnamn(_ vy: Vy) -> String { vy.rawValue }

    /// `video.json` i passets mapp.
    public static func jsonFil(_ vy: Vy) -> String { "\(mappnamn(vy))/\(filnamn)" }

    /// Klippets fil i passets mapp: "fo/Klipp/s03.mov", eller "fo/Video/01.mov" för en hel serie.
    public static func fil(vy: Vy, namn: String) -> String {
        if KlippPost.arVideo(namn) { return "\(mappnamn(vy))/Video/\(namn.dropFirst(6)).mov" }
        return "\(mappnamn(vy))/Klipp/\(namn).mov"
    }

    /// Namn → summa, för mottagningen.
    public var klara: [String: String] { klipp.mapValues(\.id) }

    public func data() throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try e.encode(self)
    }

    public static func las(_ d: Data) throws -> AnnanVideo {
        guard let v = try? JSONDecoder().decode(AnnanVideo.self, from: d), v.format == formatName,
              PassID.isValid(v.pass) else { throw OverforingFel("\(filnamn): går inte att läsa") }
        return v
    }

    /// Klippets klick i klippets tid: mätt, annars det begärda (klicket − klippets början). METOD MS31
    public func klickIKlippet(_ namn: String) -> Double? {
        guard let k = klipp[namn] else { return nil }
        if let m = k.klickIKlipp { return m }
        guard let c = k.klick, let f = k.fran else { return nil }
        return c - f
    }

    /// Den andra vyns video för den styrandes slag, och videons tid − den styrandes seriens tid,
    /// synkat på träffen (METOD MS31): klippet, med träffen i klippet = klicket i klippet − följarens
    /// ljudväg; annars den hela inspelningen, där förskjutningen är parningens träffförskjutning.
    /// nil = ingen video för slaget.
    public func kalla(slag s: ShotRecord, par e: PairEntry) -> (fil: String, offset: Double)? {
        if let k = klipp[s.id], let c = klickIKlippet(s.id) {
            let traff = c - ClickPairing.soundDelay(distance: e.follower.distance)
            return (k.fil, traff - s.impact)
        }
        if let v = klipp[KlippPost.videoNamn(e.follower.series)] {
            return (v.fil, e.hitOffset)
        }
        return nil
    }
}

/// Vad passet har från båda telefonerna, och förloppet (METOD MS31).
public enum Parstatus {
    /// "14 swings · 12 from both phones": svingarna som räknas i passet och hur många av dem som
    /// har den andra vyns video (ett klipp, eller den hela serien).
    public static func franBada(pass: PassState, par: PairFile?, video: AnnanVideo?) -> (svingar: Int, bada: Int) {
        let svingar = pass.shots.filter(\.counts)
        guard let video else { return (svingar.count, 0) }
        let bada = svingar.filter { s in
            guard let e = KlippBegaran.parning(par, serie: s.series, vy: pass.setup.view) else {
                return video.klipp[s.id] != nil
            }
            return video.kalla(slag: s, par: e) != nil
        }
        return (svingar.count, bada.count)
    }

    public static func text(pass: PassState, par: PairFile?, video: AnnanVideo?) -> String {
        let r = franBada(pass: pass, par: par, video: video)
        return Texter.franBada(svingar: r.svingar, bada: r.bada)
    }

    /// Andelen 0–1 av det som begärts: hela klipp plus den påbörjade delen av dem som kommit en bit.
    public static func andel(_ b: KlippBegaran, pagaende: [String: Int] = [:], antal: [String: Int] = [:]) -> Double {
        guard !b.klipp.isEmpty else { return 1 }
        var n = 0.0
        for k in b.klipp {
            if k.klar {
                n += 1
            } else if let h = pagaende[k.namn], let c = antal[k.namn], c > 0 {
                n += min(1, Double(h) / Double(c))
            }
        }
        return n / Double(b.klipp.count)
    }

    /// Procenten avrundad nedåt, så att 100 % betyder framme.
    public static func procent(_ andel: Double) -> Int {
        Int((max(0, min(1, andel)) * 100).rounded(.down))
    }
}

/// Den andra telefonens slag som ett pass, ur bunten (S6c-2, `SlagBunt`): vyn, klubban, slagen
/// med domen och "Detection wrong", mätta med den styrandes längd, så att den styrande kan visa
/// den andra vyns kort och granskningens rader (BESLUT B82, METOD MS31).
public enum AnnanSession {
    public static func pass(_ bunt: SlagBunt, lead: PassState) throws -> PassState {
        let m = try JSONDecoder().decode(PackageManifest.self, from: bunt.manifestData)
        let leder = try bunt.lederna()
        let setup = PassSetup(view: bunt.vy, club: m.series.first?.club ?? lead.setup.club, distance: m.distance,
                              hand: m.hand, role: .follow)
        var p = PassState(id: lead.id, created: lead.created, setup: setup, status: .analyzed, heightM: lead.heightM)
        p.shots = m.shots.map { s in
            ShotRecord(id: s.id, series: s.series, click: Click(time: s.click, strength: s.strength ?? 0), impact: s.impact,
                       verdict: AnnanSession.verdict(s.verdict), joints: leder[s.id] != nil ? s.id : nil,
                       detectionWrong: s.detectionWrong)
        }
        p.measureShots(height: lead.heightM) { s in leder[s.id] }
        return p
    }

    static func verdict(_ namn: String) -> SwingVerdict? {
        switch namn {
        case "sving": return .swing
        case "osaker": return .uncertain
        case "inte_sving": return .notSwing
        default: return nil
        }
    }

    /// Den andra telefonens slag för den styrandes slag: samma serie i parningen och klicket inom
    /// 30 ms från det väntade (den styrandes klick + förskjutningen, METOD MS10). nil = följaren
    /// hörde inte klicket.
    public static func slag(_ s: ShotRecord, i annan: PassState, par e: PairEntry) -> ShotRecord? {
        let vantat = s.click.time + e.offset
        return annan.shots.filter { $0.series == e.follower.series && abs($0.click.time - vantat) <= ClickPairing.defaultTolerance }
            .min { abs($0.click.time - vantat) < abs($1.click.time - vantat) }
    }
}

/// Paketet för den andra vyn från den styrande (Send to PC, BESLUT B81): samma format och
/// kontrakt som följarens eget (`swinglab-<pass>-<vy>.zip`, docs/FORMAT.md "Paketet"), byggt ur
/// bunten (manifestet, enhet.json och lederna) och klippen som kommit. Ett klipp kommer med för
/// det följarslag vars klick ligger inom 30 ms från klippets väntade klick, med klicket i klippet
/// flyttat lika mycket som följarens klick skiljer från det väntade. METOD MS31
public enum AnnanPaket {
    /// "swinglab-<pass>-<vy>.zip" för bunten.
    public static func filnamn(_ bunt: SlagBunt) -> String { "swinglab-\(bunt.pass)-\(bunt.vy.rawValue).zip" }

    /// Manifestet med klippen ("klipp/<följarens slag>.mov") och filerna i paketet.
    public static func delar(bunt: SlagBunt, video: AnnanVideo?, medKlipp: Bool) throws
        -> (manifest: PackageManifest, filer: [(String, PassPackage.Source)]) {
        var m = try JSONDecoder().decode(PackageManifest.self, from: bunt.manifestData)
        let leder = try bunt.lederna()
        m.shots = m.shots.filter { leder[$0.id] != nil }
        guard !m.shots.isEmpty else { throw PassPackage.Error.noShots }
        var klippFiler: [(String, PassPackage.Source)] = []
        for i in m.shots.indices {
            m.shots[i].clip = nil
            m.shots[i].clickInClip = nil
            m.shots[i].clipDuration = nil
            guard medKlipp, let video else { continue }
            let s = m.shots[i]
            let traff = video.klipp.filter { _, k in
                guard let c = k.klick, k.fran != nil else { return false }
                return k.serie == s.series && abs(c - s.click) <= ClickPairing.defaultTolerance
            }.min { abs(($0.value.klick ?? 0) - s.click) < abs(($1.value.klick ?? 0) - s.click) }
            guard let t = traff, let c = video.klickIKlippet(t.key), let vantat = t.value.klick else { continue }
            let k = t.value
            let iKlippet = c + (s.click - vantat)
            guard iKlippet >= 0, k.langd.map({ iKlippet < $0 }) ?? true else { continue }
            let zipNamn = PackageManifest.clipName(s.id)
            m.shots[i].clip = zipNamn
            m.shots[i].clickInClip = iKlippet
            m.shots[i].clipDuration = k.langd
            klippFiler.append((zipNamn, .file(k.fil)))
        }
        let e = PassPackage.encoder()
        var filer: [(String, PassPackage.Source)] = [("manifest.json", .data(try e.encode(m)))]
        if let enhet = bunt.enhetData { filer.append(("enhet.json", .data(enhet))) }
        let je = JSONEncoder()
        je.outputFormatting = [.sortedKeys]
        for s in m.shots {
            if let l = leder[s.id] { filer.append((s.joints, .data(try je.encode(l.rounded())))) }
        }
        return (m, filer + klippFiler)
    }

    /// Skriver paketet till `url` ur passets mapp `folder` (klippen), via en `.part` i `scratch`.
    @discardableResult
    public static func write(bunt: SlagBunt, video: AnnanVideo?, folder: URL, to url: URL, scratch: URL,
                             created: Date, medKlipp: Bool) throws -> PassPackage.Summary {
        let (m, filer) = try delar(bunt: bunt, video: video, medKlipp: medKlipp)
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.createDirectory(at: scratch, withIntermediateDirectories: true)
        let del = scratch.appendingPathComponent(url.lastPathComponent).appendingPathExtension(PassPackage.partExtension)
        do {
            let zip = try ZipWriter(url: del, date: created)
            for (namn, kalla) in filer {
                switch kalla {
                case .data(let d): try zip.add(name: namn, data: d)
                case .file(let rel): try zip.addFile(name: namn, from: folder.appendingPathComponent(rel))
                }
            }
            try zip.finish()
            try PassPackage.swap(del, into: url)
            return PassPackage.Summary(url: url, names: filer.map(\.0), shots: m.shots.count,
                                       clips: m.shots.filter { $0.clip != nil }.count, bytes: zip.bytesWritten)
        } catch ZipWriter.Error.tooLarge {
            try? fm.removeItem(at: del)
            throw PassPackage.Error.tooLarge
        } catch {
            try? fm.removeItem(at: del)
            throw error
        }
    }
}

/// Samma vy på båda telefonerna (S6g, BESLUT B83): första riktiga passet 2026-10-24 hade fel
/// vy-etiketter, och då gick 3D inte att räkna. Uppställningen säger till direkt när de kopplas.
public enum Vyvakt {
    /// En uppkopplad telefon har samma vy som den här.
    public static func sammaVy(egen: Vy, andra: [Vy]) -> Bool { andra.contains(egen) }

    /// Den andra vyn (den som den här telefonen kan byta till).
    public static func annan(_ vy: Vy) -> Vy { vy == .dtl ? .fo : .dtl }
}

/// Reserven (S6c-2:s "Import other phone", AirDrop): klippen ur den andra telefonens paket till den
/// styrandes pass. Varje klipp i paketet hör till ett följarslag; det läggs under den styrandes
/// slag vars klick plus parningens förskjutning ligger inom 30 ms (utan par.json paras seriernas
/// klick med samma nummer, METOD MS10). Klippet kopieras ur zippen 1 MB i taget. METOD MS31
public enum ImportKlipp {
    /// Förskjutningen (följarens filtid − den styrandes) och följarens serie för den styrandes serie.
    static func forskjutning(lead: PassState, serie: Int, par: PairFile?, foljare m: PackageManifest) -> (Double, Int)? {
        if let e = KlippBegaran.parning(par, serie: serie, vy: lead.setup.view) { return (e.offset, e.follower.series) }
        guard let a = lead.series.first(where: { $0.nr == serie })?.clicks.map(\.time) else { return nil }
        let b = m.shots.filter { $0.series == serie }.map(\.click)
        let p = ClickPairing.pair(a, b, prior: nil)
        return p.pairs.isEmpty ? nil : (p.offset, serie)
    }

    /// Den styrandes slag för varje klipp i paketet: (klippets namn i zippen, slaget, följarslaget).
    public static func plan(lead: PassState, par: PairFile?, foljare m: PackageManifest)
        -> [(zip: String, slag: String, foljarslag: PackageManifest.Shot)] {
        var ut: [(zip: String, slag: String, foljarslag: PackageManifest.Shot)] = []
        let medKlipp = m.shots.filter { $0.clip != nil && $0.clickInClip != nil }
        var tagna: Set<String> = []
        for s in lead.shots {
            guard let fk = forskjutning(lead: lead, serie: s.series, par: par, foljare: m) else { continue }
            let fs = fk.1
            let vantat = s.click.time + fk.0
            guard let f = medKlipp.filter({ $0.series == fs && abs($0.click - vantat) <= ClickPairing.defaultTolerance })
                .min(by: { abs($0.click - vantat) < abs($1.click - vantat) }),
                  let zip = f.clip, !tagna.contains(f.id) else { continue }
            tagna.insert(f.id)
            ut.append((zip, s.id, f))
        }
        return ut
    }

    /// Klippen ur zippen till `<vy>/Klipp/<slag>.mov` i passets mapp, och `video.json` som den blir
    /// (med det som redan fanns). nil = paketet bär inga klipp för passets slag.
    public static func importera(zip url: URL, lead: PassState, par: PairFile?, vy: Vy, mapp: URL,
                                 tidigare: AnnanVideo?) throws -> AnnanVideo? {
        let z = try ZipLasare(url: url)
        guard let md = try z.data("manifest.json", max: 4 << 20) else { throw OverforingFel("manifest.json saknas") }
        let m = try JSONDecoder().decode(PackageManifest.self, from: md)
        guard m.view == vy else { return nil }
        var v = tidigare ?? AnnanVideo(pass: lead.id, vy: vy)
        var nagot = false
        for (zipNamn, slag, f) in plan(lead: lead, par: par, foljare: m) {
            let rel = AnnanVideo.fil(vy: vy, namn: slag)
            let mal = mapp.appendingPathComponent(rel)
            guard try z.kopiera(zipNamn, till: mal, max: KlippMottagare.maxKlipp), let k = f.clickInClip else { continue }
            v.klipp[slag] = AnnanVideo.Klipp(fil: rel, serie: f.series, fran: f.click - k, klick: f.click, klickIKlipp: k,
                                             langd: f.clipDuration, bytes: Klippfil.storlek(mal) ?? 0,
                                             id: (try? Klippfil.summa(mal)) ?? "")
            nagot = true
        }
        return nagot ? v : nil
    }
}
