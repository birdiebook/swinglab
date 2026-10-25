import Foundation
import Swing

// Passets tillstånd (S2_SPEC §8.1, §12 S2c): uppställningen, serierna med sina
// rutor och klick, och ljusprovet. Appen läser och skriver det som
// `Pass/<id>/pass.json`; manifestet i paketet (S2f) byggs ur det. Nycklarna är
// manifestets där samma sak finns (§8.3). BESLUT B26

/// Uppställningen: vy, klubba, avstånd till bollen och spelhand (S2_SPEC §4.4, §5).
public struct PassSetup: Codable, Equatable, Sendable {
    public var view: Vy
    public var club: String
    /// Bollen till telefonen, m. Ger träffen ur klicket (METOD MS6).
    public var distance: Double
    public var hand: Hand
    /// Ensam, styr eller följ (S2g, S2_SPEC §7.1). BESLUT B21
    public var role: LinkRole

    public init(view: Vy = .dtl, club: String = "j7", distance: Double = PassSetup.standardDistance,
                hand: Hand = .hoger, role: LinkRole = .solo) {
        self.view = view
        self.club = club
        self.distance = distance
        self.hand = hand
        self.role = role
    }

    enum CodingKeys: String, CodingKey {
        case view = "vy", club = "klubba", distance = "avstand_m", hand = "spelhand", role = "roll"
    }

    /// Ett pass från före S2g saknar rollen: det var ensamt.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        view = try c.decode(Vy.self, forKey: .view)
        club = try c.decode(String.self, forKey: .club)
        distance = try c.decode(Double.self, forKey: .distance)
        hand = try c.decode(Hand.self, forKey: .hand)
        role = try c.decodeIfPresent(LinkRole.self, forKey: .role) ?? .solo
    }

    /// Standardavståndet, m (S2_SPEC §4.4). METOD MS6
    public static let standardDistance = 3.0
    /// Avståndet som går att välja, m, i steg om `distanceStep`. METOD MS6
    public static let distanceRange = 1.0...8.0
    public static let distanceStep = 0.5

    /// Klubborna i uppställningen, med manifestets namn (S2_SPEC §8.3, "j7").
    public static let clubs = ["dr", "t3", "t5", "h4", "j4", "j5", "j6", "j7", "j8", "j9", "pw", "gw", "sw", "lw"]

    /// Klubbans etikett i vyn, på engelskt sätt (BESLUT B30): "7i", "3W", "4H", "PW", "Dr".
    /// Id:t är manifestets ("j7", "t3", "h4") och ändras inte.
    public static func clubLabel(_ id: String) -> String {
        guard id.count == 2, let tal = Int(id.dropFirst()) else { return id == "dr" ? "Dr" : id.uppercased() }
        switch String(id.prefix(1)) {
        case "j": return "\(tal)i"
        case "t": return "\(tal)W"
        case "h": return "\(tal)H"
        default: return id.uppercased()
        }
    }

    /// Avståndet inom spannet och på stegen.
    public static func clampDistance(_ d: Double) -> Double {
        guard d.isFinite else { return standardDistance }
        let r = (d / distanceStep).rounded() * distanceStep
        return min(max(r, distanceRange.lowerBound), distanceRange.upperBound)
    }

    /// Ljudets väg från bollen, s (träffen = klicket − den). METOD MS6
    public var soundDelay: Double { ClickPairing.soundDelay(distance: distance) }
}

/// Var serien kommer ifrån (manifestets `kalla`).
public enum SeriesSource: String, Codable, Sendable {
    case recording = "inspelning"
    case photos = "bilder"
}

/// Telefonens värmetryck, `AVCaptureDevice.SystemPressureState.Level` (S2_SPEC §2.6). METOD MS11
public enum Pressure: String, Codable, Sendable, Comparable, CaseIterable {
    case nominal, fair, serious, critical, shutdown

    var rang: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    public static func < (a: Pressure, b: Pressure) -> Bool { a.rang < b.rang }

    /// Vyn varnar från `serious` (Apple: systemet kan sänka kvaliteten). METOD MS11
    public var warns: Bool { self >= .serious }

    /// Raden i kvittot.
    public var light: ExposurePlan.Light {
        switch self {
        case .nominal, .fair: return .good
        case .serious: return .marginal
        case .critical, .shutdown: return .tooDark
        }
    }
}

/// Ljudet i filen: det telefonen skrev (läst ur filen, S2_SPEC §2.5).
public struct AudioInfo: Codable, Equatable, Sendable {
    public var sampleRate: Double
    public var channels: Int
    /// Kodeken som fyra tecken ("aac ", "lpcm"), utan blanksteg.
    public var codec: String
    /// Mikrofonens porttyp vid starten (`AVAudioSession.Port`), om den var känd.
    public var microphone: String?

    public init(sampleRate: Double, channels: Int, codec: String, microphone: String? = nil) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.codec = codec
        self.microphone = microphone
    }

    enum CodingKeys: String, CodingKey {
        case sampleRate = "hz", channels = "kanaler", codec = "kodek", microphone = "mikrofon"
    }
}

/// Exponeringen som låstes, med linsläget och distorsionsrättningen (manifestets `exponering`).
public struct ExposureRecord: Codable, Equatable, Sendable {
    public var plan: ExposurePlan
    /// Linsläget 0–1 efter fokuslåset.
    public var lensPosition: Double?
    public var distortionCorrection: Bool?

    public init(plan: ExposurePlan, lensPosition: Double? = nil, distortionCorrection: Bool? = nil) {
        self.plan = plan
        self.lensPosition = lensPosition
        self.distortionCorrection = distortionCorrection
    }
}

/// Det som lästs ur en fil: rutornas tider, ljudet, geometrin och storleken.
/// App/MediaReader fyller i det; `SeriesRecord.make` bygger serien.
public struct FileFacts: Equatable, Sendable {
    public var frameTimes: [Double]
    public var clicks: [Click]
    public var audio: AudioInfo?
    /// preferredTransform (a, b, c, d) och lagrad storlek.
    public var transform: [Double]
    public var storedWidth: Int
    public var storedHeight: Int
    public var bytes: Int64
    /// Filens längd, s (asset.duration).
    public var duration: Double

    public init(frameTimes: [Double], clicks: [Click], audio: AudioInfo?, transform: [Double],
                storedWidth: Int, storedHeight: Int, bytes: Int64, duration: Double) {
        self.frameTimes = frameTimes
        self.clicks = clicks
        self.audio = audio
        self.transform = transform
        self.storedWidth = storedWidth
        self.storedHeight = storedHeight
        self.bytes = bytes
        self.duration = duration
    }
}

/// En serie: en inspelning (start → stopp) eller ett importerat original.
public struct SeriesRecord: Codable, Equatable, Sendable {
    public var nr: Int
    public var source: SeriesSource
    public var club: String
    /// Filen relativt passets mapp, "Video/01.mov".
    public var file: String
    /// När serien började (inspelning) eller spelades in (Bilder: asset.creationDate).
    public var start: Date
    /// Filens tid noll på telefonens värdklocka (startPTS), s. Bara egen inspelning.
    public var startHost: Double?
    public var duration: Double
    public var bytes: Int64
    public var timing: FrameTiming
    public var clicks: [Click]
    /// EXIF-orienteringen ur transformen och den upprätta storleken (METOD MS7).
    public var orientation: UInt32
    public var uprightWidth: Int
    public var uprightHeight: Int
    public var audio: AudioInfo?
    public var format: CameraFormat?
    public var exposure: ExposureRecord?
    /// Det högsta trycket under serien.
    public var pressure: Pressure?
    /// Bilder: `mediaSubtypes` innehöll `.videoHighFrameRate`.
    public var markedSlowMotion: Bool?
    /// Fönstret och utsnittet ur redigeraren (S2i, `Edit.swift`); nil = aldrig redigerad:
    /// hela filen och hela bilden. Ett pass.json från före S2i saknar fältet. METOD MS13
    public var edit: SeriesEdit?
    /// Telefonens lodlinje under inspelningen (S6b, `Lodlinje.swift`); nil = inga rörelseprov
    /// (simulatorn, en import ur Bilder) eller ett pass.json från före S6b. METOD MS17
    public var plumb: PlumbRecord?
    /// Riktpinnen bakifrån (S7a): två tryck i hela bildens pixlar på en pinne på marken,
    /// parallell med mållinjen, för flyktpunkten; nil = ingen (bildens mitt, antagen). METOD M48
    public var riktpinne: [KlubbPunkt]?
    /// Riktpinnens steg hoppades över för serien (S7c, BESLUT B59): märkningen frågar inte igen.
    /// nil = inte hoppat.
    public var riktpinneHoppad: Bool?

    public init(nr: Int, source: SeriesSource, club: String, file: String, start: Date, startHost: Double?,
                duration: Double, bytes: Int64, timing: FrameTiming, clicks: [Click], orientation: UInt32,
                uprightWidth: Int, uprightHeight: Int, audio: AudioInfo? = nil, format: CameraFormat? = nil,
                exposure: ExposureRecord? = nil, pressure: Pressure? = nil, markedSlowMotion: Bool? = nil,
                edit: SeriesEdit? = nil, plumb: PlumbRecord? = nil) {
        self.nr = nr
        self.source = source
        self.club = club
        self.file = file
        self.start = start
        self.startHost = startHost
        self.duration = duration
        self.bytes = bytes
        self.timing = timing
        self.clicks = clicks
        self.orientation = orientation
        self.uprightWidth = uprightWidth
        self.uprightHeight = uprightHeight
        self.audio = audio
        self.format = format
        self.exposure = exposure
        self.pressure = pressure
        self.markedSlowMotion = markedSlowMotion
        self.edit = edit
        self.plumb = plumb
    }

    /// Serien ur det som lästs ur filen. METOD MS3, MS7
    public static func make(nr: Int, source: SeriesSource, club: String, file: String, start: Date,
                            startHost: Double?, facts: FileFacts) -> SeriesRecord {
        let t = facts.transform.count == 4 ? facts.transform : [1, 0, 0, 1]
        let exif = Orientation.exif(a: t[0], b: t[1], c: t[2], d: t[3])
        let upp = Orientation.uprightSize(width: facts.storedWidth, height: facts.storedHeight, exif: exif)
        let timing = FrameTiming.analyze(facts.frameTimes)
        var langd = facts.duration
        if !(langd.isFinite && langd > 0), let a = facts.frameTimes.min(), let b = facts.frameTimes.max() {
            langd = b - a
        }
        return SeriesRecord(nr: nr, source: source, club: club, file: file, start: start, startHost: startHost,
                            duration: langd.isFinite ? max(0, langd) : 0, bytes: facts.bytes, timing: timing,
                            clicks: facts.clicks, orientation: exif, uprightWidth: upp.width,
                            uprightHeight: upp.height, audio: facts.audio)
    }

    /// Filens storlek per minut, MB (10^6 byte). 0 för en serie utan längd. METOD MS11
    public var megabytesPerMinute: Double {
        duration > 0 ? Double(bytes) / 1_000_000 / duration * 60 : 0
    }
}

/// Status i passets lista.
public enum PassStatus: String, Codable, Sendable {
    case recorded = "inspelat"
    case analyzed = "analyserat"
    case exported = "exporterat"
}

/// Ett pass: uppställningen, serierna och ljusprovet.
public struct PassState: Codable, Equatable, Sendable {
    public static let formatName = "swinglab-pass/1"

    public var format: String
    /// `yyyyMMdd-HHmmss` i lokal tid vid passets start.
    public var id: String
    public var created: Date
    public var setup: PassSetup
    public var series: [SeriesRecord]
    public var lightCheck: LightCheck?
    public var status: PassStatus
    /// Slagen ur klicken, med domen, lederna och klippen (S2e, `Shots.swift`).
    public var shots: [ShotRecord]
    /// Vad Vision kostade i passet (S2_SPEC §6.4). METOD MS12
    public var vision: VisionStats?
    /// Det högsta slagnumret som getts ("s07" → 7). Går aldrig bakåt, så att ett id
    /// aldrig ges två gånger (`syncShots`). METOD MS12
    public var lastShotNumber: Int
    /// Längden som passets slag mäts med, m (skalan, METOD M2); nil = standarden, märkt
    /// antagen. Tas från Jag när passet skapas och ändras bara i passet: en ny längd i Jag
    /// rör inga gamla pass (S4c). METOD MS16
    public var heightM: Double?
    /// Passet kom från före S4c, utan längd och utan mätta slag: det har aldrig mätts, så
    /// det tar Me:s längd när det läses (`fillMissingHeight`), som förut. Skrivs inte i
    /// pass.json. METOD MS16
    public var heightPending = false
    /// 3D ur två telefoner (S6c-2): passets median per 3D-mått ur `tre_d.json`, så att Progress
    /// och jämförelsen mot förra passet inte läser filen. nil = passet har ingen 3D. METOD MS19
    public var treD: [String: TreDMedian]?

    enum CodingKeys: String, CodingKey {
        case format, id, created, setup, series, lightCheck, status, shots, vision, lastShotNumber, heightM
        case treD = "tre_d"
    }

    public init(id: String, created: Date, setup: PassSetup, series: [SeriesRecord] = [],
                lightCheck: LightCheck? = nil, status: PassStatus = .recorded, shots: [ShotRecord] = [],
                vision: VisionStats? = nil, lastShotNumber: Int = 0, heightM: Double? = nil) {
        format = Self.formatName
        self.id = id
        self.created = created
        self.setup = setup
        self.series = series
        self.lightCheck = lightCheck
        self.status = status
        self.shots = shots
        self.vision = vision
        self.lastShotNumber = lastShotNumber
        self.heightM = heightM
    }

    /// Ett pass från S2c/S2d saknar `shots` och `vision`: det läses ändå, med inga slag.
    /// Saknas räknaren är den det högsta numret bland slagen.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = try c.decode(String.self, forKey: .format)
        id = try c.decode(String.self, forKey: .id)
        created = try c.decode(Date.self, forKey: .created)
        setup = try c.decode(PassSetup.self, forKey: .setup)
        series = try c.decode([SeriesRecord].self, forKey: .series)
        lightCheck = try c.decodeIfPresent(LightCheck.self, forKey: .lightCheck)
        status = try c.decode(PassStatus.self, forKey: .status)
        shots = try c.decodeIfPresent([ShotRecord].self, forKey: .shots) ?? []
        vision = try c.decodeIfPresent(VisionStats.self, forKey: .vision)
        lastShotNumber = try c.decodeIfPresent(Int.self, forKey: .lastShotNumber)
            ?? (shots.compactMap { ShotRecord.number($0.id) }.max() ?? 0)
        treD = try c.decodeIfPresent([String: TreDMedian].self, forKey: .treD)
        // Ett pass från före S4c saknar längden. Med mätta slag: den som slagen mättes med (då
        // Me:s), så att passet behåller sina tal. Utan: Me:s längd när passet läses. METOD MS16
        if c.contains(.heightM) {
            heightM = try c.decodeIfPresent(Double.self, forKey: .heightM)
        } else if let m = shots.compactMap(\.measure).first {
            heightM = m.heightAssumed ? nil : m.heightM
        } else {
            heightM = nil
            heightPending = true
        }
    }

    /// Som den härledda, men längden står alltid med (`null` när den är antagen), så att ett
    /// nytt pass aldrig läses som ett från före S4c. METOD MS16
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(format, forKey: .format)
        try c.encode(id, forKey: .id)
        try c.encode(created, forKey: .created)
        try c.encode(setup, forKey: .setup)
        try c.encode(series, forKey: .series)
        try c.encodeIfPresent(lightCheck, forKey: .lightCheck)
        try c.encode(status, forKey: .status)
        try c.encode(shots, forKey: .shots)
        try c.encodeIfPresent(vision, forKey: .vision)
        try c.encode(lastShotNumber, forKey: .lastShotNumber)
        try c.encode(heightM, forKey: .heightM)
        try c.encodeIfPresent(treD, forKey: .treD)
    }

    /// Ett pass från före S4c utan mätta slag tar Me:s längd (`settings`); andra rörs inte.
    /// METOD MS16
    public mutating func fillMissingHeight(_ settings: Double?) {
        guard heightPending else { return }
        heightM = settings
        heightPending = false
    }

    /// Nästa seriens nummer (1, 2, …).
    public var nextSeriesNumber: Int { (series.map(\.nr).max() ?? 0) + 1 }

    /// Filen för serie nr, relativt passets mapp.
    public static func videoPath(nr: Int, extension ext: String = "mov") -> String {
        String(format: "Video/%02d.%@", nr, ext.isEmpty ? "mov" : ext)
    }

    /// Klicken i alla serier.
    public var clickCount: Int { series.reduce(0) { $0 + $1.clicks.count } }

    /// Raden i passens index.
    public var entry: PassIndex.Entry {
        PassIndex.Entry(id: id, created: created, series: series.count, clicks: clickCount, status: status)
    }
}

/// Indexet över passen (`pass.json` i appens mapp).
public struct PassIndex: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public var id: String
        public var created: Date
        public var series: Int
        public var clicks: Int
        public var status: PassStatus

        public init(id: String, created: Date, series: Int, clicks: Int, status: PassStatus) {
            self.id = id
            self.created = created
            self.series = series
            self.clicks = clicks
            self.status = status
        }
    }

    public var passes: [Entry]

    public init(passes: [Entry] = []) { self.passes = passes }

    /// Lägger till eller ersätter passets rad; senaste först.
    public mutating func upsert(_ e: Entry) {
        passes.removeAll { $0.id == e.id }
        passes.append(e)
        passes.sort { $0.created > $1.created || ($0.created == $1.created && $0.id > $1.id) }
    }
}

/// Pass-id ur tiden: `yyyyMMdd-HHmmss` i den givna zonen (S2_SPEC §8.1). Inga namn.
public enum PassID {
    public static func make(_ date: Date, timeZone: TimeZone = .current) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(format: "%04d%02d%02d-%02d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0,
                      c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
    }

    /// Ett id som inte redan finns: lägger till "-2", "-3" … vid krock.
    public static func unique(_ base: String, taken: Set<String>) -> String {
        guard taken.contains(base) else { return base }
        var n = 2
        while taken.contains("\(base)-\(n)") { n += 1 }
        return "\(base)-\(n)"
    }

    /// Bara siffror, bindestreck: ett id från en fil går inte att använda som sökväg ut ur mappen.
    public static func isValid(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 40 && id.allSatisfy { $0.isASCII && ($0.isNumber || $0 == "-") }
    }
}

/// JSON för passets filer: sorterade nycklar och ISO 8601-tider, samma på Linux och telefonen.
public enum PassCoding {
    public static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    public static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

/// Lagringen: disken före start och originalen efter export. METOD MS11, BESLUT B26
public enum PassStorage {
    /// Under så mycket ledigt före start ber appen om plats, byte. METOD MS11
    public static let startMinimum: Int64 = 4_000_000_000
    /// `minFreeDiskSpaceLimit`: inspelningen stoppas här, byte. METOD MS11
    public static let recordingFloor: Int64 = 2_000_000_000

    public static func canStart(available: Int64?) -> Bool {
        guard let available else { return true }     // okänt: försök, golvet stoppar ändå
        return available >= startMinimum
    }

    /// Standard för originalen (BESLUT B26 väntar på Johannes): behåll hela serierna.
    public static let keepOriginalsByDefault = true

    /// Får seriernas original tas bort? Bara när Johannes valt "Spara bara klippen"
    /// och passet är exporterat (S2_SPEC §8.1). BESLUT B26
    public static func mayDeleteOriginals(keepOriginals: Bool, status: PassStatus) -> Bool {
        !keepOriginals && status == .exported
    }
}

/// Appens inställningar (`installningar.json`): Jag (S4c) är standarden för nya pass.
public struct AppSettings: Codable, Equatable, Sendable {
    /// BESLUT B26: behåll hela serierna (standard) eller bara klippen efter export.
    public var keepOriginals: Bool
    /// Spelarens längd i Jag, m: skalan för måtten i cm (METOD M2) i **nya** pass; ett pass
    /// behåller sin (`PassState.heightM`, METOD MS16). nil = inte angiven; då mäts med
    /// `ShotMeasuring.assumedHeightM` och skalan märks antagen (METOD MS14). Saknas i en
    /// installningar.json från före S4b.
    public var heightM: Double?
    /// Spelhanden i Jag, standarden i uppställningen; nil = höger. Saknas före S4c.
    public var hand: Hand?
    /// Klubborna i Jag (manifestets id, `PassSetup.clubs`), de som uppställningen visar;
    /// nil = alla. Saknas före S4c.
    public var clubs: [String]?
    /// Guiden till klubbans märkning har visats (S7c, BESLUT B59); nil = inte än.
    public var clubGuideSeen: Bool?
    /// Spåren som granskningen visar (S4f, BESLUT B70): `SparPunkt` råvärden; nil = inga.
    public var trails: [String]?
    /// Hjälplinjerna i inspelningen (S2j, BESLUT B85); nil = på. Saknas före S2j.
    public var guideLines: Bool?

    /// Hjälplinjerna visas (standard på).
    public var visaHjalplinjer: Bool { guideLines ?? true }

    public init(keepOriginals: Bool = PassStorage.keepOriginalsByDefault, heightM: Double? = nil, hand: Hand? = nil,
                clubs: [String]? = nil) {
        self.keepOriginals = keepOriginals
        self.heightM = heightM
        self.hand = hand
        self.clubs = clubs
    }

    /// Spåren som är påslagna (S4f, BESLUT B70); okända namn hoppas över.
    public var sparVal: Set<SparPunkt> { Set((trails ?? []).compactMap(SparPunkt.init(rawValue:))) }

    /// Ett spår slås på eller av; valet sparas i punkternas ordning (S4f, BESLUT B70).
    public mutating func toggleSpar(_ p: SparPunkt) {
        var v = sparVal
        if v.contains(p) { v.remove(p) } else { v.insert(p) }
        trails = SparPunkt.allCases.filter { v.contains($0) }.map(\.rawValue)
    }

    /// Klubborna i uppställningen, i `PassSetup.clubs` ordning; aldrig tom (alla när inga är valda).
    public var bag: [String] {
        let valda = Set(clubs ?? PassSetup.clubs)
        let ut = PassSetup.clubs.filter { valda.contains($0) }
        return ut.isEmpty ? PassSetup.clubs : ut
    }

    /// Klubban läggs till i eller tas bort ur Jag; den sista tas aldrig bort.
    public mutating func toggleClub(_ id: String) {
        guard PassSetup.clubs.contains(id) else { return }
        var b = bag
        if let i = b.firstIndex(of: id) {
            guard b.count > 1 else { return }
            b.remove(at: i)
        } else {
            b.append(id)
        }
        clubs = PassSetup.clubs.filter { b.contains($0) }
    }

    /// Uppställningen för ett nytt pass: spelhanden ur Jag och klubban från förra passet
    /// (`lastClub`) om den finns bland klubborna, annars 7i, annars den första (S4c).
    public func newSetup(lastClub: String? = nil) -> PassSetup {
        let b = bag
        let club = lastClub.flatMap { b.contains($0) ? $0 : nil } ?? (b.contains("j7") ? "j7" : b[0])
        return PassSetup(club: club, hand: hand ?? .hoger)
    }
}
