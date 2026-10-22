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

    public init(view: Vy = .dtl, club: String = "j7", distance: Double = PassSetup.standardDistance,
                hand: Hand = .hoger) {
        self.view = view
        self.club = club
        self.distance = distance
        self.hand = hand
    }

    enum CodingKeys: String, CodingKey {
        case view = "vy", club = "klubba", distance = "avstand_m", hand = "spelhand"
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

    public init(nr: Int, source: SeriesSource, club: String, file: String, start: Date, startHost: Double?,
                duration: Double, bytes: Int64, timing: FrameTiming, clicks: [Click], orientation: UInt32,
                uprightWidth: Int, uprightHeight: Int, audio: AudioInfo? = nil, format: CameraFormat? = nil,
                exposure: ExposureRecord? = nil, pressure: Pressure? = nil, markedSlowMotion: Bool? = nil) {
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

    public init(id: String, created: Date, setup: PassSetup, series: [SeriesRecord] = [],
                lightCheck: LightCheck? = nil, status: PassStatus = .recorded) {
        format = Self.formatName
        self.id = id
        self.created = created
        self.setup = setup
        self.series = series
        self.lightCheck = lightCheck
        self.status = status
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

/// Appens inställningar (`installningar.json`).
public struct AppSettings: Codable, Equatable, Sendable {
    /// BESLUT B26: behåll hela serierna (standard) eller bara klippen efter export.
    public var keepOriginals: Bool

    public init(keepOriginals: Bool = PassStorage.keepOriginalsByDefault) {
        self.keepOriginals = keepOriginals
    }
}
