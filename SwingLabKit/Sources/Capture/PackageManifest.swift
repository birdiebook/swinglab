import Foundation
import Swing

// Paketet till PC:n (S2_SPEC §8.3, docs/FORMAT.md "Paketet", BESLUT B27): manifestet,
// `enhet.json`, `ljusprov.json`, ett JSON per slag med lederna och, valbart, klippen.
// Allt som avgör vad som hamnar i zippen och med vilka nycklar bor här och prövas på
// Linux; App/Export.swift fyller i telefonens modell, appens version, kameraformaten och
// klippens längd och delar filen. PC:n (`tools/pc/paket.py`) läser och kräver formen.

/// `manifest.json` i paketet (format `swinglab-paket/1`). Nycklarna är FORMAT.md:s.
public struct PackageManifest: Codable, Equatable, Sendable {
    public static let formatName = "swinglab-paket/1"

    public struct AppInfo: Codable, Equatable, Sendable {
        public var version: String
        public var build: String

        public init(version: String, build: String) {
            self.version = version
            self.build = build
        }

        enum CodingKeys: String, CodingKey { case version, build = "bygge" }
    }

    public struct PhoneInfo: Codable, Equatable, Sendable {
        /// "iPhone18,1".
        public var model: String
        public var ios: String
        /// "ensam", "styr" eller "folj": `make` sätter den ur passets roll (`LinkRole`, S2g).
        public var role: String

        public init(model: String, ios: String, role: String = "ensam") {
            self.model = model
            self.ios = ios
            self.role = role
        }

        enum CodingKeys: String, CodingKey { case model = "modell", ios, role = "roll" }
    }

    /// Rutornas tider i serien (FrameTiming).
    public struct Frames: Codable, Equatable, Sendable {
        public var count: Int
        public var gridRate: Double?
        public var meanRate: Double?
        public var missing: Double?
        public var largestGap: Double?

        enum CodingKeys: String, CodingKey {
            case count = "antal", gridRate = "natets_hz", meanRate = "snitt_hz", missing = "saknas"
            case largestGap = "storsta_hal_s"
        }
    }

    public struct Format: Codable, Equatable, Sendable {
        public var index: Int
        public var width: Int
        public var height: Int
        public var fieldOfView: Double?
        public var binned: Bool

        enum CodingKeys: String, CodingKey {
            case index, width = "bredd", height = "hojd", fieldOfView = "synfalt", binned = "binnat"
        }
    }

    public struct Exposure: Codable, Equatable, Sendable {
        public var duration: Double?
        public var iso: Double?
        public var neededISO: Double?
        public var deficitEV: Double?
        public var lens: Double?
        public var distortionCorrection: Bool?

        enum CodingKeys: String, CodingKey {
            case duration = "tid_s", iso, neededISO = "behov_iso", deficitEV = "brist_ev", lens = "lins"
            case distortionCorrection = "distorsionsratt"
        }
    }

    public struct Series: Codable, Equatable, Sendable {
        public var nr: Int
        public var source: SeriesSource
        public var club: String
        /// Seriens start i lokal tid, ISO 8601 med zonen.
        public var startLocal: String
        public var startHost: Double?
        public var duration: Double?
        public var frames: Frames
        public var format: Format?
        public var exposure: Exposure?
        public var audio: AudioInfo?
        public var pressure: Pressure?
        public var orientation: UInt32
        public var orientationSuspect: Bool
        /// Fönstret och utsnittet ur redigeraren, klampade som de läses; saknas utan
        /// redigering (hela filen, hela bilden). METOD MS13
        public var window: TimeWindow?
        public var crop: CropRect?
        /// Uppåt (−gravitationen) i kamerans ram i den upprätta bilden, g (`Plumb.field`);
        /// står bara med när telefonen stod still (S6b, BESLUT B39). METOD MS17
        public var plumb: [Double]? = nil
        /// Riktpinnen bakifrån: två punkter [x, y] i hela bildens pixlar (S7a, METOD M48);
        /// står bara med när Johannes satt den.
        public var riktpinne: [[Double]]? = nil

        enum CodingKeys: String, CodingKey {
            case nr, source = "kalla", club = "klubba", startLocal = "start_lokal", startHost = "start_vard_s"
            case duration = "langd_s", frames = "rutor", format, exposure = "exponering", audio = "ljud"
            case pressure = "tryck", orientation = "orientering", orientationSuspect = "orientering_misstankt"
            case window = "fonster", crop = "utsnitt", plumb = "lodlinje", riktpinne
        }
    }

    public struct Shot: Codable, Equatable, Sendable {
        public var id: String
        public var series: Int
        /// Klicket i seriens fil, s, och styrkan.
        public var click: Double
        public var strength: Double?
        /// Träffen i seriens fil, s (klicket − avstånd/343, METOD MS6).
        public var impact: Double
        /// "sving", "inte_sving" eller "osaker".
        public var verdict: String
        public var verdictByJohannes: Bool
        /// Klippet i zippen ("klipp/s01.mov"), klicket mätt i klippet (s i klippet) och
        /// klippets längd: PC:n räknar bara klippets rutor i [0; längd). METOD MS12
        public var clip: String?
        public var clickInClip: Double?
        public var clipDuration: Double?
        /// Lederna i zippen ("slag/s01.json").
        public var joints: String
        /// Johannes märkte lederna fel ("Detection wrong", S4b): PC:n mäter inte slaget,
        /// som telefonen (METOD MT1). Står bara med när det är satt.
        public var detectionWrong: Bool? = nil

        enum CodingKeys: String, CodingKey {
            case id, series = "serie", click = "klick_s", strength = "styrka", impact = "traff_s", verdict = "dom"
            case verdictByJohannes = "andrad_av_johannes", clip = "klipp", clickInClip = "klick_i_klipp_s"
            case clipDuration = "klipp_langd_s", joints = "leder", detectionWrong = "detection_wrong"
        }
    }

    public struct Vision: Codable, Equatable, Sendable {
        public var revision: Int
        public var msPerFrame: Double?
        public var sparseStride: Int
        public var denseStride: Int

        enum CodingKeys: String, CodingKey {
            case revision, msPerFrame = "ms_per_ruta", sparseStride = "glest_steg", denseStride = "tatt_steg"
        }
    }

    public var format: String
    public var created: String
    public var app: AppInfo
    public var pass: String
    public var phone: PhoneInfo
    public var view: Vy
    public var distance: Double
    public var hand: Hand
    public var series: [Series]
    public var shots: [Shot]
    public var vision: Vision?
    /// S1:s mått per slag; `null` tills telefonen räknar dem (PC:n räknar).
    public var measures: [String: [String: Double]]?
    /// Passets längd (`PassState.heightM`), m, så att PC:n mäter med samma skala som telefonen
    /// (METOD M2, MS16, BESLUT B12); står inte med när längden är antagen.
    public var playerHeight: Double? = nil

    enum CodingKeys: String, CodingKey {
        case format, created = "skapad", app, pass, phone = "telefon", view = "vy", distance = "avstand_m"
        case hand = "spelhand", series = "serier", shots = "slag", vision, measures = "matt"
        case playerHeight = "spelarens_langd_m"
    }

    /// `matt` skrivs alltid, `null` när måtten saknas (S2_SPEC §8.3); övriga valfria fält
    /// står bara med när de finns.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(format, forKey: .format)
        try c.encode(created, forKey: .created)
        try c.encode(app, forKey: .app)
        try c.encode(pass, forKey: .pass)
        try c.encode(phone, forKey: .phone)
        try c.encode(view, forKey: .view)
        try c.encode(distance, forKey: .distance)
        try c.encode(hand, forKey: .hand)
        try c.encodeIfPresent(playerHeight, forKey: .playerHeight)
        try c.encode(series, forKey: .series)
        try c.encode(shots, forKey: .shots)
        try c.encodeIfPresent(vision, forKey: .vision)
        try c.encode(measures, forKey: .measures)
    }

    /// Domen med manifestets namn.
    public static func verdictName(_ v: SwingVerdict) -> String {
        switch v {
        case .swing: return "sving"
        case .notSwing: return "inte_sving"
        case .uncertain: return "osaker"
        }
    }

    /// Ledernas och klippets namn i zippen.
    public static func jointsName(_ id: String) -> String { "slag/\(id).json" }
    public static func clipName(_ id: String) -> String { "klipp/\(id).mov" }

    /// Tiden i ISO 8601 med zonen ("2026-10-24T15:42:10+02:00").
    public static func timestamp(_ date: Date, timeZone: TimeZone) -> String {
        let f = ISO8601DateFormatter()
        f.timeZone = timeZone
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }

    /// Ett tal som JSON tål, annars nil.
    static func finite(_ v: Double?) -> Double? {
        guard let v, v.isFinite else { return nil }
        return v
    }

    /// Manifestet ur passet. Telefonens roll är passets (S2g), och ett slag märkt
    /// "Detection wrong" bär `detection_wrong` (PC:n mäter det inte, METOD MT1). Bara slagen vars leder finns (`hasJoints`) kommer med, eftersom
    /// PC:n kräver lederna för varje slag; klippen bara med `includeClips`, när klippet
    /// finns (`hasClip`) och klicket hittades i det. Fönstret och utsnittet plattas ut per
    /// serie, klampade som de läses (`activeWindow`, `activeCrop`); en serie utan redigering
    /// får inga fält. Lodlinjen vrids till kamerans ram och står bara med när telefonen stod
    /// still (`Plumb.field`). METOD MS12, MS13, MS17
    public static func make(pass: PassState, app: AppInfo, phone: PhoneInfo, created: Date, timeZone: TimeZone,
                            includeClips: Bool, clipDurations: [String: Double] = [:],
                            hasJoints: (ShotRecord) -> Bool = { $0.joints != nil },
                            hasClip: (ShotRecord) -> Bool = { $0.clip != nil }) -> PackageManifest {
        let serier = pass.series.sorted { $0.nr < $1.nr }.map { s -> Series in
            let medLeder = pass.shots.filter { $0.series == s.nr }.compactMap(\.orientationSuspect)
            let misstankta: Int = medLeder.filter { $0 }.count
            let misstankt: Bool = !medLeder.isEmpty && 2 * misstankta > medLeder.count
            let fonster: TimeWindow? = s.edit != nil ? s.activeWindow : nil
            let rutor = Frames(count: s.timing.count, gridRate: finite(s.timing.gridRate),
                               meanRate: finite(s.timing.meanRate), missing: finite(s.timing.missingFraction),
                               largestGap: finite(s.timing.largestGap))
            let fmt = s.format.map {
                Format(index: $0.index, width: $0.width, height: $0.height, fieldOfView: finite($0.fieldOfView),
                       binned: $0.binned)
            }
            let exp = s.exposure.map {
                Exposure(duration: finite($0.plan.duration), iso: finite($0.plan.iso), neededISO: finite($0.plan.neededISO),
                         deficitEV: finite($0.plan.deficitEV), lens: finite($0.lensPosition),
                         distortionCorrection: $0.distortionCorrection)
            }
            return Series(nr: s.nr, source: s.source, club: s.club, startLocal: timestamp(s.start, timeZone: timeZone),
                          startHost: finite(s.startHost), duration: finite(s.duration),
                          frames: rutor, format: fmt, exposure: exp, audio: s.audio, pressure: s.pressure,
                          orientation: s.orientation, orientationSuspect: misstankt, window: fonster, crop: s.activeCrop,
                          plumb: Plumb.field(s.plumb, exif: s.orientation),
                          riktpinne: s.riktpinne.flatMap { $0.count == 2 ? $0.map { [$0.x, $0.y] } : nil })
        }
        let nr = Set(pass.series.map(\.nr))
        let slag = pass.shots.filter { (s: ShotRecord) -> Bool in
            guard s.verdict != nil, s.joints != nil, nr.contains(s.series) else { return false }
            return (s.jointFrames ?? 1) > 0 && hasJoints(s)
        }.map { s -> Shot in
            var shot = Shot(id: s.id, series: s.series, click: s.click.time, strength: finite(s.click.strength),
                            impact: s.impact, verdict: verdictName(s.verdict ?? .uncertain),
                            verdictByJohannes: s.verdictByJohannes, clip: nil, clickInClip: nil, clipDuration: nil,
                            joints: jointsName(s.id))
            if s.detectionWrong == true { shot.detectionWrong = true }
            if includeClips, s.clip != nil, let k = finite(s.clickInClip), hasClip(s) {
                shot.clip = clipName(s.id)
                shot.clickInClip = k
                shot.clipDuration = finite(s.clip.flatMap { clipDurations[$0] })
            }
            return shot
        }
        let vision = pass.vision.map {
            Vision(revision: $0.revision, msPerFrame: finite($0.msPerFrame), sparseStride: $0.sparseStride,
                   denseStride: $0.denseStride)
        }
        var telefon = phone
        telefon.role = pass.setup.role.rawValue
        return PackageManifest(format: formatName, created: timestamp(created, timeZone: timeZone), app: app,
                               pass: pass.id, phone: telefon, view: pass.setup.view, distance: pass.setup.distance,
                               hand: pass.setup.hand, series: serier, shots: slag, vision: vision, measures: nil,
                               playerHeight: finite(pass.heightM))
    }
}

/// `enhet.json`: telefonens modell, iOS, alla kameraformat den rapporterar och det valda
/// (S2_SPEC §8.3). PC:n läser den inte än.
public struct DeviceInfo: Codable, Equatable, Sendable {
    public var model: String
    public var ios: String
    public var formats: [CameraFormat]
    public var chosenIndex: Int?

    public init(model: String, ios: String, formats: [CameraFormat], chosenIndex: Int?) {
        self.model = model
        self.ios = ios
        self.formats = formats
        self.chosenIndex = chosenIndex
    }

    enum CodingKeys: String, CodingKey { case model = "modell", ios, formats = "format", chosenIndex = "valt_index" }
}

/// Paketet som fil: vad som läggs i zippen och skrivningen. BESLUT B27
public enum PassPackage {
    public enum Error: Swift.Error, Equatable {
        /// Inget slag har leder: analysera passet först (PC:n kräver minst ett slag).
        case noShots
        /// Från 4 GB eller 65 535 filer: skicka utan klipp.
        case tooLarge
    }

    /// Vad som skrevs.
    public struct Summary: Equatable, Sendable {
        public var url: URL
        public var names: [String]
        public var shots: Int
        public var clips: Int
        public var bytes: UInt64
    }

    /// En fil i zippen: ur minnet eller ur passets mapp (relativ sökväg).
    public enum Source: Equatable, Sendable {
        case data(Data)
        case file(String)
    }

    /// "swinglab-<pass>-<dtl|fo>.zip".
    public static func fileName(_ pass: PassState) -> String {
        "swinglab-\(pass.id)-\(pass.setup.view.rawValue).zip"
    }

    /// JSON för paketets filer: sorterade nycklar, och tal som JSON inte tål som text i
    /// stället för ett fel (ett okänt kameravärde ska inte stoppa paketet).
    public static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        e.dateEncodingStrategy = .iso8601
        e.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "inf", negativeInfinity: "-inf",
                                                                 nan: "nan")
        return e
    }

    /// Parningens fil i passets mapp (S2g, styrande telefon med följare): följer med
    /// oförändrad när den finns (S2_SPEC §8.3).
    public static let pairingFile = "par.json"

    /// 3D som telefonen räknade (S6c-2, `TreDFil`): följer med oförändrad när den finns, och
    /// PC:n jämför med sin egen (BESLUT B63).
    public static let treDFile = "tre_d.json"

    /// Filerna i paketet i ordning: manifestet, enheten, ljusprovet, parningen, lederna per
    /// slag och klippen.
    public static func parts(pass: PassState, manifest: PackageManifest, device: DeviceInfo?,
                             hasPairing: Bool = false, hasTreD: Bool = false) throws -> [(String, Source)] {
        let e = encoder()
        let m = try e.encode(manifest)
        var ut: [(String, Source)] = [("manifest.json", .data(m))]
        if let device {
            let d = try e.encode(device)
            ut.append(("enhet.json", .data(d)))
        }
        if let ljus = pass.lightCheck {
            let d = try e.encode(ljus)
            ut.append(("ljusprov.json", .data(d)))
        }
        if hasPairing { ut.append((pairingFile, .file(pairingFile))) }
        if hasTreD { ut.append((treDFile, .file(treDFile))) }
        if let klubba = clubFile(pass: pass, manifest: manifest) {
            ut.append((KlubbFil.filnamn, .data(try e.encode(klubba))))
        }
        let slag = Dictionary(pass.shots.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for s in manifest.shots {
            if let rel = slag[s.id]?.joints { ut.append((s.joints, .file(rel))) }
        }
        for s in manifest.shots {
            if let namn = s.clip, let rel = slag[s.id]?.clip { ut.append((namn, .file(rel))) }
        }
        return ut
    }

    /// Klubbans markeringar som `klubba.json` (S7a, BESLUT B47), version 2, för slagen i
    /// manifestet som har markeringar; nil utan. `t_klipp` = Visions tid + klicket i klippet
    /// när klippet följer med och rutan ligger i det, [0; klippets längd) (samma ruta i
    /// klippet, MS12), annars null; `visad` = det
    /// granskningen visade (seriens utsnitt vidgat för märkningen, i px). METOD M45
    public static func clubFile(pass: PassState, manifest: PackageManifest,
                                timeZone: TimeZone = .current) -> KlubbFil? {
        let slag = Dictionary(pass.shots.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let serier = Dictionary(pass.series.map { ($0.nr, $0) }, uniquingKeysWith: { a, _ in a })
        var rutor: [KlubbFil.Ruta] = []
        for m in manifest.shots {
            guard let s = slag[m.id], let marks = s.klubba, !marks.isEmpty, let serie = serier[s.series] else { continue }
            let w = serie.uprightWidth, h = serie.uprightHeight
            let visad = ClubMarking.shownCrop(serie.activeCrop).pixels(width: w, height: h)
            for k in marks {
                rutor.append(KlubbFil.ruta(k, vy: pass.setup.view, slag: m.id, fil: fileName(pass), bredd: w, hojd: h,
                                           visad: [visad.x, visad.y, visad.width, visad.height],
                                           tKlipp: m.clickInClip.flatMap { iKlippet(k.t + $0, m.clipDuration) }))
            }
        }
        guard !rutor.isEmpty else { return nil }
        // När markeringarna senast ändrades; utan tid (före granskningen) paketets tid.
        let andrad = ClubMarking.lastChange(manifest.shots.flatMap { m in slag[m.id]?.klubba ?? [] })
        return KlubbFil(pass: pass.id, kalla: [fileName(pass)],
                        andrad: andrad.map { PackageManifest.timestamp($0, timeZone: timeZone) } ?? manifest.created,
                        rutor: rutor)
    }

    /// Tiden i klippet när den ligger bland klippets rutor, [0; längd); annars nil. METOD MS12
    static func iKlippet(_ t: Double, _ langd: Double?) -> Double? {
        t >= 0 && (langd.map { t < $0 } ?? true) ? t : nil
    }

    /// Ändelsen på en zip under skrivning.
    public static let partExtension = "part"

    /// Skriver paketet till `url` ur passets mapp `folder`: först till en `.part`-fil i
    /// `scratch` (appens Caches, aldrig i Filer), som byter plats med `url` när zippen är hel,
    /// så att en avbruten export aldrig lämnar en halv fil i Export. Slag vars ledfil saknas
    /// på disken kommer inte med, och klipp som saknas utelämnas; `par.json` följer med när
    /// den finns, liksom `tre_d.json` (S6c-2). Kastar `noShots` utan slag och `tooLarge` från 4 GB.
    @discardableResult
    public static func write(pass: PassState, folder: URL, to url: URL, scratch: URL, app: PackageManifest.AppInfo,
                             phone: PackageManifest.PhoneInfo, device: DeviceInfo?, created: Date,
                             timeZone: TimeZone = .current, includeClips: Bool,
                             clipDurations: [String: Double] = [:]) throws -> Summary {
        let fm = FileManager.default
        func finns(_ rel: String?) -> Bool {
            guard let rel else { return false }
            return fm.fileExists(atPath: folder.appendingPathComponent(rel).path)
        }
        let manifest = PackageManifest.make(pass: pass, app: app, phone: phone, created: created, timeZone: timeZone,
                                            includeClips: includeClips, clipDurations: clipDurations,
                                            hasJoints: { finns($0.joints) }, hasClip: { finns($0.clip) })
        guard !manifest.shots.isEmpty else { throw Error.noShots }
        let delar = try parts(pass: pass, manifest: manifest, device: device, hasPairing: finns(pairingFile),
                              hasTreD: finns(treDFile))
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.createDirectory(at: scratch, withIntermediateDirectories: true)
        let del = scratch.appendingPathComponent(url.lastPathComponent).appendingPathExtension(partExtension)
        do {
            let zip = try ZipWriter(url: del, date: created)
            for (namn, kalla) in delar {
                switch kalla {
                case .data(let d): try zip.add(name: namn, data: d)
                case .file(let rel): try zip.addFile(name: namn, from: folder.appendingPathComponent(rel))
                }
            }
            try zip.finish()
            try swap(del, into: url)
            return Summary(url: url, names: delar.map(\.0), shots: manifest.shots.count,
                           clips: manifest.shots.filter { $0.clip != nil }.count, bytes: zip.bytesWritten)
        } catch ZipWriter.Error.tooLarge {
            try? fm.removeItem(at: del)
            throw Error.tooLarge
        } catch {
            try? fm.removeItem(at: del)
            throw error
        }
    }
}

extension PassPackage {
    /// Den hela zippen byter plats med paketet i Export: `replaceItemAt` på telefonen (ett
    /// byte, inget ögonblick utan fil). swift-corelibs `replaceItemAt` tappade filen i Linux-
    /// provet (2026-10-22), så där tas den gamla bort och den nya flyttas dit.
    static func swap(_ ny: URL, into url: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            try fm.moveItem(at: ny, to: url)
            return
        }
        #if canImport(ObjectiveC)
        _ = try fm.replaceItemAt(url, withItemAt: ny)
        #else
        try fm.removeItem(at: url)
        try fm.moveItem(at: ny, to: url)
        #endif
    }

    /// Tar bort `.part`-filer som en avbruten export lämnat i `scratch` (när appen startar).
    /// Rör inget annat. Svarar antalet.
    @discardableResult
    public static func removeStaleParts(in scratch: URL) -> Int {
        let fm = FileManager.default
        let namn = (try? fm.contentsOfDirectory(atPath: scratch.path)) ?? []
        var n = 0
        for f in namn where f.hasSuffix("." + partExtension) {
            if (try? fm.removeItem(at: scratch.appendingPathComponent(f))) != nil { n += 1 }
        }
        return n
    }
}
