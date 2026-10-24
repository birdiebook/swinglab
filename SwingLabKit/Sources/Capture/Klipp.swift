import Foundation
import Swing

// Klippen mellan telefonerna (S6g, BESLUT B80, METOD MS30). Den styrande har efter passet
// videon från båda telefonerna: den begär svingarnas klipp ur följarens filer över PhoneLink
// (`KlippBegaran`, i en vanlig överföring `begaran`), och följaren skär dem passthrough och
// strömmar dem ur filen i bitar (`klipp`). Bitarna är S6c-2:s (`LinkPart`, 192 kB, base64) med
// klippets namn, men de går inte genom `PartSender`/`PartReceiver`, som håller allt i minnet:
// följaren läser en bit i taget ur filen och har högst `KlippSandare.fonster` i luften, och den
// styrande skriver varje bit i ordning till en `.part`-fil (`KlippMottagare`). Filens storlek är
// hur långt klippet kommit, så att överföringen fortsätter där den slutade när kopplingen kommer
// tillbaka, också efter att appen startats om. Bara Foundation, så att allt prövas på Linux.
// Storleken och tiden (räknade och uppmätta i simulatorn) står i METOD MS30.

/// Ett klipp som den styrande begär: ett av dess slag i följarens fil, eller en hel inspelning
/// ("Get full video"). METOD MS30
public struct KlippPost: Codable, Equatable, Sendable {
    /// Den styrandes slag ("s03"), eller "video-01" för följarens hela serie 1.
    public var namn: String
    /// Serien i följarens pass (`Video/<nr>.mov`).
    public var serie: Int
    /// Fönstret i följarens fil, s; nil för en hel inspelning.
    public var fran: Double?
    public var till: Double?
    /// Klicket i följarens fil som den styrande räknar med (dess klick + parningens förskjutning), s.
    public var klick: Double?
    /// Klippet är framme hos den styrande.
    public var klar: Bool
    /// Ett påbörjat klipp: innehållets summa och antalet hela bitar som redan kommit.
    public var harId: String?
    public var har: Int?

    public init(namn: String, serie: Int, fran: Double? = nil, till: Double? = nil, klick: Double? = nil,
                klar: Bool = false, harId: String? = nil, har: Int? = nil) {
        self.namn = namn
        self.serie = serie
        self.fran = fran
        self.till = till
        self.klick = klick
        self.klar = klar
        self.harId = harId
        self.har = har
    }

    enum CodingKeys: String, CodingKey {
        case namn, serie, fran = "fran_s", till = "till_s", klick = "klick_s", klar, harId = "har_id", har
    }

    /// "video-01": följarens hela serie.
    public static func videoNamn(_ serie: Int) -> String { String(format: "video-%02d", serie) }

    /// Namnet är en hel inspelning.
    public static func arVideo(_ namn: String) -> Bool { namn.hasPrefix("video-") }

    /// Ett namn som går att lägga i en sökväg: ett slag ("s03") eller en serie ("video-01"),
    /// bara gemena bokstäver, siffror och bindestreck, högst 16 tecken.
    public static func giltigt(_ namn: String) -> Bool {
        guard !namn.isEmpty, namn.count <= 16, namn.first != "-" else { return false }
        return namn.allSatisfy { tecken.contains($0) }
    }

    static let tecken = Set("abcdefghijklmnopqrstuvwxyz0123456789-")

    /// Fönstret i följarens fil inom [0, längd]; nil när inget är kvar. En hel inspelning är hela filen.
    public func fonster(langd: Double) -> ClosedRange<Double>? {
        guard let fran, let till else { return langd > 0 ? 0...langd : nil }
        let a = max(0, fran), b = langd > 0 ? min(langd, till) : till
        return a < b ? a...b : nil
    }
}

/// Den styrandes begäran (`Pass/<id>/begaran.json` hos följaren): klippen den vill ha, i passets
/// ordning, med det som redan är framme. Skickas när kopplingen kommer upp och när ett klipp är
/// framme; `nr` gör varje begäran till en ny överföring. METOD MS30
public struct KlippBegaran: Codable, Equatable, Sendable {
    public static let formatName = "swinglab-klippbegaran/1"
    /// Följarens kopia av den senaste begäran.
    public static let filnamn = "begaran.json"
    /// Följaren: den styrande har en app utan klippen (`video1` saknas i dess hello), så ingen
    /// begäran kommer och originalen behövs inte för den (BESLUT B84).
    public static let utanVideoFil = "utan_video.json"
    public static let utanVideoInnehall = Data("{}".utf8)
    /// Följarens skurna klipp tills de kommit fram (passets mapp).
    public static let utskickMapp = "Utskick"
    public static func utskick(_ namn: String) -> String { "\(utskickMapp)/\(namn).mov" }
    /// Klippet kring träffen: från 4 s före till 2,5 s efter (Johannes 2026-10-24). METOD MS30
    public static let fore = 4.0
    public static let efter = 2.5
    /// Klicket i ett klipp räknas som slagets när det ligger inom parningens tolerans (30 ms, MS10)
    /// från det väntade, räknat från klippets verkliga början (`KlippStart`). Längre bort = följaren
    /// hörde inte klicket (eller ett annat ljud), och synken tar det väntade. METOD MS30
    public static let klickTolerans = ClickPairing.defaultTolerance

    public var format: String
    public var pass: String
    /// Den styrandes vy; följarens ska vara den andra.
    public var vy: Vy
    public var nr: Int
    public var klipp: [KlippPost]

    public init(pass: String, vy: Vy, nr: Int, klipp: [KlippPost]) {
        format = Self.formatName
        self.pass = pass
        self.vy = vy
        self.nr = nr
        self.klipp = klipp
    }

    /// Allt som begärts är framme: följaren får släppa sina original (BESLUT B80).
    public var alltFramme: Bool { !klipp.isEmpty && klipp.allSatisfy(\.klar) }

    /// En äldre begäran än `annan` för samma pass (lägre `nr`): följaren gör inget med den, så att
    /// en begäran som kommer sent aldrig vinner över en nyare (BESLUT B84).
    public func aldre(an annan: KlippBegaran?) -> Bool {
        guard let annan, annan.pass == pass else { return false }
        return nr < annan.nr
    }

    /// Nästa klipp att skicka: det första som inte är framme och inte redan levererat.
    public func nasta(utom levererade: Set<String>) -> KlippPost? {
        klipp.first { !$0.klar && !levererade.contains($0.namn) }
    }

    public func data() throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return try e.encode(self)
    }

    /// Begäran ur JSON, med formatet, passet och namnen prövade.
    public static func las(_ d: Data) throws -> KlippBegaran {
        guard d.count <= Overforing.maxBytes[Overforing.begaran] ?? 0,
              let b = try? JSONDecoder().decode(KlippBegaran.self, from: d) else {
            throw OverforingFel("\(filnamn): går inte att läsa")
        }
        guard b.format == formatName else { throw OverforingFel("\(filnamn): format ska vara \(formatName)") }
        guard PassID.isValid(b.pass) else { throw OverforingFel("\(filnamn): pass") }
        guard b.klipp.allSatisfy({ KlippPost.giltigt($0.namn) }) else { throw OverforingFel("\(filnamn): namn") }
        return b
    }

    /// Parningens rad för den styrandes serie: följaren med den andra vyn (den första, om flera).
    public static func parning(_ par: PairFile?, serie: Int, vy: Vy) -> PairEntry? {
        par?.entries.first { $0.series == serie && $0.follower.view != vy }
    }

    /// Den styrandes begäran ur passet och par.json (S6g, BESLUT B80): ett klipp per sving (dom
    /// sving eller osäker) i följarens serie, från `fore` före till `efter` efter träffen i
    /// följarens fil (den styrandes träff + parningens träffförskjutning, METOD MS6), också när
    /// följaren inte hörde klicket. Med `hela` också varje parad serie hel. `framme` = det som
    /// redan kommit, `pagaende` = påbörjade klipp (summan och hela bitar). Svarar också antalet
    /// svingar som inte går att begära (serien saknar parning). METOD MS30
    /// `saknas` = klippen som följaren sagt att den inte kan skicka (originalet borta): de begärs
    /// inte igen (BESLUT B84).
    public static func make(pass: PassState, par: PairFile?, nr: Int, framme: Set<String>,
                            pagaende: [String: (id: String, har: Int)] = [:], hela: Bool = false,
                            saknas: Set<String> = []) -> (begaran: KlippBegaran, utanParning: Int) {
        var ut: [KlippPost] = []
        var utan = 0
        func post(_ p: KlippPost) -> KlippPost {
            var p = p
            p.klar = framme.contains(p.namn)
            if !p.klar, let g = pagaende[p.namn] {
                p.harId = g.id
                p.har = g.har
            }
            return p
        }
        for s in pass.shots where s.wantsDetail {
            guard let e = parning(par, serie: s.series, vy: pass.setup.view) else {
                utan += 1
                continue
            }
            let traff = s.impact + e.hitOffset
            ut.append(post(KlippPost(namn: s.id, serie: e.follower.series, fran: max(0, traff - fore), till: traff + efter,
                                     klick: s.click.time + e.offset)))
        }
        if hela {
            var serier: [Int] = []
            for s in pass.series.map(\.nr).sorted() {
                guard let e = parning(par, serie: s, vy: pass.setup.view), !serier.contains(e.follower.series) else { continue }
                serier.append(e.follower.series)
                ut.append(post(KlippPost(namn: KlippPost.videoNamn(e.follower.series), serie: e.follower.series)))
            }
        }
        return (KlippBegaran(pass: pass.id, vy: pass.setup.view, nr: nr, klipp: ut.filter { !saknas.contains($0.namn) }), utan)
    }
}

// MARK: - Filerna

/// Läsningen och summan av en fil, en bit i taget (aldrig hela filen i minnet). METOD MS30
public enum Klippfil {
    /// Filens storlek, byte; nil när den saknas.
    public static func storlek(_ url: URL) -> Int? {
        guard let a = try? FileManager.default.attributesOfItem(atPath: url.path),
              let n = a[.size] as? NSNumber else { return nil }
        return n.intValue
    }

    /// Bit `index` (`Overforing.delBytes` byte; den sista kortare).
    public static func del(_ url: URL, index: Int) throws -> Data {
        let h = try FileHandle(forReadingFrom: url)
        defer { try? h.close() }
        try h.seek(toOffset: UInt64(index) * UInt64(Overforing.delBytes))
        return try h.read(upToCount: Overforing.delBytes) ?? Data()
    }

    /// Bit `index` som en bit på kopplingen.
    public static func bit(_ url: URL, index: Int, pass: String, namn: String, id: String, bytes: Int) throws -> LinkPart {
        let d = try del(url, index: index)
        return LinkPart(kind: Overforing.klipp, pass: pass, id: id, index: index, count: Overforing.antal(bytes),
                        bytes: bytes, data: d.base64EncodedString(), namn: namn)
    }

    /// Filens summa (`Overforing.summa`: CRC-32 och längden), läst 1 MB i taget.
    public static func summa(_ url: URL) throws -> String {
        let h = try FileHandle(forReadingFrom: url)
        defer { try? h.close() }
        var crc = CRC32()
        var n = 0
        while true {
            let d = try autoreleasepoolOmDetFinns { try h.read(upToCount: 1 << 20) ?? Data() }
            if d.isEmpty { break }
            crc.update(d)
            n += d.count
        }
        return String(format: "%08x", crc.value) + "-\(n)"
    }

    static func autoreleasepoolOmDetFinns<T>(_ f: () throws -> T) rethrows -> T {
        #if canImport(ObjectiveC)
        return try autoreleasepool { try f() }
        #else
        return try f()
        #endif
    }
}

// MARK: - Följaren: strömmen

/// Följarens ström av ett klipp: vilka bitar som ska läsas ur filen och skickas, högst
/// `fonster` i luften, och vad en kvittens betyder. Bara ett klipp åt gången; den styrandes
/// begäran säger vilket som är nästa och var det står. METOD MS30
public struct KlippSandare: Equatable, Sendable {
    /// Bitar i luften: 8 · 192 kB ≈ 1,5 MB (2 MB i base64) åt gången.
    public static let fonster = 8

    public struct Strom: Equatable, Sendable {
        public let namn: String
        public let id: String
        public let bytes: Int
        public let count: Int
        /// Nästa bit att skicka.
        public internal(set) var nasta: Int
        var iLuften: Set<Int>
        /// Bitar som kvitterats, för förloppet.
        public internal(set) var kvitterade: Int
    }

    public private(set) var strom: Strom?

    public init() {}

    public enum Svar: Equatable, Sendable {
        case inget
        /// Bitarna att läsa och skicka nu.
        case skicka([Int])
        /// Klippet är framme och sparat hos den styrande.
        case klar(String)
        /// Den styrande sa nej (skälet); klippet skickas inte mer.
        case nej(String, String)
    }

    /// Börjar skicka klippet från bit `fran` (det den styrande redan har; ett tal utanför börjar
    /// om, och en mottagare som har alla bitar får den sista igen så att den kan pröva summan).
    /// Svarar bitarna att skicka nu.
    public mutating func borja(namn: String, id: String, bytes: Int, fran: Int = 0) -> [Int] {
        let n = Overforing.antal(bytes)
        let start = fran < 0 || fran > n ? 0 : min(fran, n - 1)
        strom = Strom(namn: namn, id: id, bytes: bytes, count: n, nasta: start, iLuften: [], kvitterade: start)
        return fyll()
    }

    private mutating func fyll() -> [Int] {
        guard var s = strom else { return [] }
        var ut: [Int] = []
        while s.iLuften.count < Self.fonster, s.nasta < s.count {
            ut.append(s.nasta)
            s.iLuften.insert(s.nasta)
            s.nasta += 1
        }
        strom = s
        return ut
    }

    /// En kvittens från den styrande.
    public mutating func kvittens(_ a: LinkPartAck) -> Svar {
        guard let s = strom, a.kind == Overforing.klipp, a.namn == s.namn, a.id == s.id else { return .inget }
        if a.ok {
            guard let i = a.index else {
                strom = nil
                return .klar(s.namn)
            }
            if strom?.iLuften.remove(i) != nil { strom?.kvitterade += 1 }
            return .skicka(fyll())
        }
        if let fel = a.fel {
            strom = nil
            return .nej(s.namn, fel)
        }
        // Mottagaren vill börja om: vid `har` (den har bitarna före), annars från början.
        let fran = min(max(0, a.har ?? 0), s.count - 1)
        strom?.nasta = fran
        strom?.iLuften = []
        strom?.kvitterade = fran
        return .skicka(fyll())
    }

    /// Kopplingen föll: inget är längre i luften. Den styrandes nästa begäran säger var den står.
    public mutating func avbrott() {
        strom = nil
    }

    /// Andelen av klippet som kvitterats, 0–1.
    public var andel: Double {
        guard let s = strom, s.count > 0 else { return 0 }
        return Double(s.kvitterade) / Double(s.count)
    }
}

// MARK: - Den styrande: mottagningen

/// Den styrandes sida av ett klipp: varje bit skrivs i ordning till `<vy>/Delar/<namn>~<id>.part`
/// i passets mapp, och när den sista kommit prövas summan och filen flyttas till sin plats
/// (`AnnanVideo.fil`). Filens storlek är förloppet: en bit som redan finns kvitteras igen, en bit
/// längre fram ger "börja vid `har`", så att strömmen fortsätter där den slutade. Ingen bit
/// hålls i minnet. Används på en egen kö (appen) eller direkt (proven). METOD MS30
public struct KlippMottagare: Sendable {
    /// Största klipp, byte: 6,5 s i 240 bilder/s är cirka 33 MB, och taket ger fyra gånger det
    /// (METOD MS30).
    public static let maxKlipp = 128 << 20
    /// Marginalen på disken utöver klippet innan den första biten tas emot, byte (METOD MS30).
    public static let marginal: Int64 = 200 << 20
    /// Största hela inspelning, byte (zippens gräns, BESLUT B27).
    public static let maxVideo = Int(UInt32.max)

    /// Passets mapp.
    public let mapp: URL
    /// Den andra telefonens vy: mappen klippen sparas i.
    public let vy: Vy
    public let pass: String

    public init(mapp: URL, vy: Vy, pass: String) {
        self.mapp = mapp
        self.vy = vy
        self.pass = pass
    }

    public enum Svar: Equatable, Sendable {
        /// Kvittenser att skicka.
        case kvittera([LinkPartAck])
        /// Klippet är helt, summan stämmer och filen ligger på sin plats (`fil`, i passets mapp).
        /// Den sista bitens kvittens skickas nu; helheten kvitteras när appen sparat `video.json`
        /// (`helKvittens`).
        case klar(namn: String, fil: String, bytes: Int, id: String, kvittens: LinkPartAck)
    }

    var delar: URL { mapp.appendingPathComponent(AnnanVideo.mappnamn(vy)).appendingPathComponent("Delar") }

    func delfil(_ namn: String, _ id: String) -> URL {
        delar.appendingPathComponent("\(namn)~\(id).part")
    }

    /// Innehållets summa som den ska se ut (`Overforing.summa`): åtta hexsiffror, ett bindestreck och
    /// längden, som ska vara bitens `bytes`. Annat läses inte (och blir aldrig ett filnamn).
    public static func giltigtId(_ id: String, bytes: Int) -> Bool {
        let delar = id.split(separator: "-", omittingEmptySubsequences: false)
        guard delar.count == 2, delar[0].count == 8, delar[0].allSatisfy({ $0.isHexDigit && !$0.isUppercase }),
              !delar[1].isEmpty, delar[1].count <= 12, delar[1].allSatisfy({ $0.isASCII && $0.isNumber }),
              let n = Int(delar[1]) else { return false }
        return n == bytes
    }

    /// Tar bort påbörjade klipp vars namn inte står i begäran (ett avbrutet "Get full video", ett
    /// slag som inte längre är en sving), så att `Delar/` inte växer.
    public func rensa(behall: Set<String>) {
        let fm = FileManager.default
        for f in (try? fm.contentsOfDirectory(atPath: delar.path)) ?? [] {
            guard let namn = f.split(separator: "~").first.map(String.init), !behall.contains(namn) else { continue }
            try? fm.removeItem(at: delar.appendingPathComponent(f))
        }
    }

    /// Ett påbörjat klipp: summan och antalet hela bitar som finns. nil = inget.
    public func har(_ namn: String) -> (id: String, har: Int)? {
        let filer = (try? FileManager.default.contentsOfDirectory(atPath: delar.path)) ?? []
        guard let f = filer.first(where: { $0.hasPrefix(namn + "~") && $0.hasSuffix(".part") }) else { return nil }
        let id = String(f.dropFirst(namn.count + 1).dropLast(5))
        let n = Klippfil.storlek(delar.appendingPathComponent(f)) ?? 0
        return (id, n / Overforing.delBytes)
    }

    /// Alla påbörjade klipp (för begäran).
    public func pagaende(_ namn: [String]) -> [String: (id: String, har: Int)] {
        var ut: [String: (id: String, har: Int)] = [:]
        for n in namn { if let h = har(n) { ut[n] = h } }
        return ut
    }

    /// Kvittensen för hela klippet, när `video.json` är sparad.
    public func helKvittens(namn: String, id: String) -> LinkPartAck {
        LinkPartAck(kind: Overforing.klipp, pass: pass, id: id, index: nil, ok: true, namn: namn)
    }

    /// En bit från följaren. `onskade` = namnen i den senaste begäran; `klara` = namn → summa för
    /// klippen som redan är framme (en bit av ett sådant kvitteras hel igen); `ledigt` = ledigt på
    /// disken, byte (nil = okänt). Ett nytt klipp tas bara emot med klippet och marginalen ledigt,
    /// och en skrivning som felar ger nej med skälet `disk`, så att strömmen aldrig står still tyst.
    /// Finns passets mapp inte (passet raderat) skrivs inget. METOD MS30
    public func taEmot(_ p: LinkPart, onskade: Set<String>, klara: [String: String], ledigt: Int64? = nil) -> Svar {
        func ack(_ index: Int?, ok: Bool, fel: String? = nil, har: Int? = nil) -> LinkPartAck {
            LinkPartAck(kind: Overforing.klipp, pass: p.pass, id: p.id, index: index, ok: ok, fel: fel, namn: p.namn, har: har)
        }
        guard p.v == LinkPart.version else { return .kvittera([ack(nil, ok: false, fel: Overforing.felVersion)]) }
        guard p.pass == pass else { return .kvittera([ack(nil, ok: false, fel: Overforing.felPass)]) }
        guard p.kind == Overforing.klipp, let namn = p.namn, KlippPost.giltigt(namn), onskade.contains(namn) else {
            return .kvittera([ack(nil, ok: false, fel: Overforing.felFormat)])
        }
        let tak = KlippPost.arVideo(namn) ? Self.maxVideo : Self.maxKlipp
        guard p.bytes > 0, p.count == Overforing.antal(p.bytes), p.index >= 0, p.index < p.count,
              p.data.utf8.count <= (Overforing.delBytes / 3 + 1) * 4 else { return .kvittera([]) }
        guard p.bytes <= tak, Self.giltigtId(p.id, bytes: p.bytes) else {
            return .kvittera([ack(nil, ok: false, fel: Overforing.felFormat)])
        }
        if klara[namn] == p.id { return .kvittera([ack(p.index, ok: true), ack(nil, ok: true)]) }
        let fm = FileManager.default
        guard fm.fileExists(atPath: mapp.path) else { return .kvittera([]) }
        let nytt = !fm.fileExists(atPath: delfil(namn, p.id).path)
        if nytt, let ledigt, ledigt < Int64(p.bytes) + Self.marginal {
            return .kvittera([ack(nil, ok: false, fel: Overforing.felDisk)])
        }
        do {
            try fm.createDirectory(at: delar, withIntermediateDirectories: true)
            // Ett annat innehåll med samma namn (klippet skars om): det gamla tas bort.
            for f in (try? fm.contentsOfDirectory(atPath: delar.path)) ?? []
            where f.hasPrefix(namn + "~") && f != "\(namn)~\(p.id).part" {
                try? fm.removeItem(at: delar.appendingPathComponent(f))
            }
            let fil = delfil(namn, p.id)
            if !fm.fileExists(atPath: fil.path) { fm.createFile(atPath: fil.path, contents: nil) }
            var storlek = Klippfil.storlek(fil) ?? 0
            // En bit som avbröts mitt i skrivningen: det som inte är en hel bit tas bort.
            if storlek > p.bytes || (storlek != p.bytes && storlek % Overforing.delBytes != 0) {
                storlek = min(p.bytes, storlek) / Overforing.delBytes * Overforing.delBytes
                let h = try FileHandle(forWritingTo: fil)
                try h.truncate(atOffset: UInt64(storlek))
                try h.close()
            }
            let har = storlek == p.bytes ? p.count : storlek / Overforing.delBytes
            if har == p.count { return try avsluta(p, namn: namn, fil: fil) }
            if p.index < har { return .kvittera([ack(p.index, ok: true)]) }
            if p.index > har { return .kvittera([ack(nil, ok: false, har: har)]) }
            guard let d = Data(base64Encoded: p.data),
                  d.count == (p.index == p.count - 1 ? p.bytes - p.index * Overforing.delBytes : Overforing.delBytes) else {
                return .kvittera([ack(nil, ok: false, har: har)])
            }
            let h = try FileHandle(forWritingTo: fil)
            try h.seek(toOffset: UInt64(storlek))
            try h.write(contentsOf: d)
            try h.close()
            if har + 1 == p.count { return try avsluta(p, namn: namn, fil: fil) }
            return .kvittera([ack(p.index, ok: true)])
        } catch {
            // Disken full eller skrivningen felade: nej med skälet, och den styrande säger det.
            return .kvittera([ack(nil, ok: false, fel: Overforing.felDisk)])
        }
    }

    /// Alla bitar finns: summan prövas och filen flyttas på plats, annars börjar klippet om.
    private func avsluta(_ p: LinkPart, namn: String, fil: URL) throws -> Svar {
        let fm = FileManager.default
        guard (try? Klippfil.summa(fil)) == p.id else {
            try? fm.removeItem(at: fil)
            return .kvittera([LinkPartAck(kind: Overforing.klipp, pass: p.pass, id: p.id, index: nil, ok: false,
                                          namn: namn, har: 0)])
        }
        let rel = AnnanVideo.fil(vy: vy, namn: namn)
        let mal = mapp.appendingPathComponent(rel)
        try fm.createDirectory(at: mal.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: mal.path) { try fm.removeItem(at: mal) }
        try fm.moveItem(at: fil, to: mal)
        return .klar(namn: namn, fil: rel, bytes: p.bytes, id: p.id,
                     kvittens: LinkPartAck(kind: Overforing.klipp, pass: p.pass, id: p.id, index: p.index, ok: true,
                                           namn: namn))
    }
}
