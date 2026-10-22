import Foundation
import Observation
import Swing
import Capture

/// Katalogen (`katalog.json`, BESLUT B6) ur appens bunt; nil om den saknas eller inte går
/// att läsa (då visas inga mått, och simulatorprovet fäller bygget).
enum AppKatalog {
    static let katalog: Katalog? = {
        guard let url = Bundle.main.url(forResource: "katalog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? Katalog.las(data)
    }()
}

/// Passen på telefonen (S2_SPEC §8.1). Allt ligger i appens Application Support och
/// lämnar telefonen bara i ett paket som Johannes själv delar (BESLUT B3). Videon och
/// klippen ligger utanför iCloud-backupen. BESLUT B26
///
/// ```
/// Application Support/SwingLab/
///   pass.json                 index (PassIndex)
///   installningar.json        AppSettings
///   Pass/<id>/pass.json       PassState
///   Pass/<id>/Video/01.mov    inspelningar och importerade original   (utanför backupen)
///   Pass/<id>/Klipp/          klippen kring slagen (S2e)                (utanför backupen)
///   Pass/<id>/Leder/s01.json  ett slags leder (JointSeries, S2e)
/// Documents/Export/           paketen (S2f), synliga i Filer             (utanför backupen)
/// ```
@Observable
final class Store {
    let root: URL
    let exportFolder: URL
    private(set) var index = PassIndex()
    /// Passen som lästs, per id: `allPasses` läser disken en gång, och varje sparat pass
    /// uppdaterar sin rad (S4b). Inte observerad: den ändrar inget som syns.
    @ObservationIgnored private var cache: [String: PassState]?
    private(set) var settings = AppSettings()
    /// Visas när en fil inte gick att läsa eller skriva.
    var problem: String?

    static let defaultRoot: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "SwingLab", directoryHint: .isDirectory)
    }()

    static let defaultExport: URL = {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appending(path: "Export", directoryHint: .isDirectory)
    }()

    init(root: URL = Store.defaultRoot, exportFolder: URL = Store.defaultExport) {
        self.root = root
        self.exportFolder = exportFolder
        try? FileManager.default.createDirectory(at: root.appending(path: "Pass", directoryHint: .isDirectory),
                                                 withIntermediateDirectories: true)
        Self.createOutsideBackup(exportFolder)
        index = read(PassIndex.self, at: indexFile, aside: "pass") ?? PassIndex()
        settings = read(AppSettings.self, at: settingsFile, aside: "installningar") ?? AppSettings()
    }

    private var indexFile: URL { root.appending(path: "pass.json") }
    private var settingsFile: URL { root.appending(path: "installningar.json") }

    func passFolder(_ id: String) -> URL {
        root.appending(path: "Pass", directoryHint: .isDirectory).appending(path: id, directoryHint: .isDirectory)
    }

    private func passFile(_ id: String) -> URL { passFolder(id).appending(path: "pass.json") }

    /// En fil i passet, t.ex. seriens "Video/01.mov".
    func url(_ relative: String, in id: String) -> URL { passFolder(id).appending(path: relative) }

    // MARK: Passen

    /// Ett nytt pass med id ur tiden (yyyyMMdd-HHmmss, lokal tid) och sina mappar.
    func newPass(setup: PassSetup, at date: Date = Date()) -> PassState {
        let id = PassID.unique(PassID.make(date), taken: Set(index.passes.map(\.id)))
        let pass = PassState(id: id, created: date, setup: setup)
        let folder = passFolder(id)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        Self.createOutsideBackup(folder.appending(path: "Video", directoryHint: .isDirectory))
        Self.createOutsideBackup(folder.appending(path: "Klipp", directoryHint: .isDirectory))
        save(pass)
        return pass
    }

    /// Passet, eller nil. En fil som inte går att läsa skrivs aldrig över: den flyttas
    /// undan och vyn säger det (Airtime).
    func load(_ id: String) -> PassState? {
        guard PassID.isValid(id) else { return nil }
        return read(PassState.self, at: passFile(id), aside: "pass")
    }

    func save(_ pass: PassState) {
        do {
            try write(pass)
        } catch {
            problem = String(localized: "pass.json could not be saved.")
        }
    }

    enum StoreError: LocalizedError {
        case invalidID
        var errorDescription: String? { String(localized: "pass.json could not be saved.") }
    }

    /// Som `save`, men felet kastas: analysen stannar hellre än fortsätter på ett pass
    /// som inte står på disken (BESLUT B25).
    func write(_ pass: PassState) throws {
        guard PassID.isValid(pass.id) else { throw StoreError.invalidID }
        try FileManager.default.createDirectory(at: passFolder(pass.id), withIntermediateDirectories: true)
        try PassCoding.encoder().encode(pass).write(to: passFile(pass.id), options: .atomic)
        index.upsert(pass.entry)
        cache?[pass.id] = pass
        try PassCoding.encoder().encode(index).write(to: indexFile, options: .atomic)
    }

    // MARK: Lederna (S2e)

    /// Ett slags leder till `Leder/<id>.json`, avrundade som i paketet (METOD MS12).
    /// Svarar sökvägen i passet.
    func writeJoints(_ series: JointSeries, shot id: String, in passID: String) throws -> String {
        let rel = ShotRecord.jointsPath(id)
        let fil = url(rel, in: passID)
        try FileManager.default.createDirectory(at: fil.deletingLastPathComponent(), withIntermediateDirectories: true)
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        try e.encode(series.rounded()).write(to: fil, options: .atomic)
        return rel
    }

    /// Ett slags leder, eller nil när filen saknas eller inte går att läsa.
    func joints(_ rel: String, in passID: String) -> JointSeries? {
        guard let data = try? Data(contentsOf: url(rel, in: passID)) else { return nil }
        return try? JSONDecoder().decode(JointSeries.self, from: data)
    }

    // MARK: Redigeringen (S2i)

    /// Seriens fönster och utsnitt till passet (`PassState.setEdit`), sparat; lederna och
    /// klippen som inget längre pekar på tas bort. Originalfilen rörs aldrig. Svarar
    /// passet som det står på disken. METOD MS13
    func saveEdit(_ edit: SeriesEdit, series nr: Int, in passID: String) throws -> PassState? {
        guard var pass = load(passID) else { return nil }
        let bort = pass.setEdit(edit, series: nr)
        try write(pass)
        removeShotFiles(bort, in: passID)
        return pass
    }

    /// Tar bort slagens filer (Leder/ och Klipp/) i passet; aldrig något annat.
    func removeShotFiles(_ files: [String], in passID: String) {
        let mapp = passFolder(passID).standardizedFileURL
        let tillatna = ["Leder", "Klipp"].map { mapp.appending(path: $0, directoryHint: .isDirectory).standardizedFileURL }
        for rel in files {
            let f = url(rel, in: passID).standardizedFileURL
            guard tillatna.contains(f.deletingLastPathComponent()) else { continue }
            try? FileManager.default.removeItem(at: f)
        }
    }

    // MARK: Två telefoner (S2g)

    /// Följaren tar den styrandes pass-id, så att båda paketen bär samma (S2_SPEC §7.4).
    /// Ett pass med serier byter aldrig id; ett tomt flyttas till det nya id:t, eller
    /// till passet som redan finns med det id:t. nil = id:t går inte att använda.
    func adopt(_ pass: PassState, id: String) -> PassState? {
        guard pass.id != id else { return pass }
        guard PassID.isValid(id), pass.series.isEmpty else { return nil }
        var ny = load(id) ?? PassState(id: id, created: pass.created, setup: pass.setup)
        ny.setup.role = pass.setup.role
        // Ljusprovet gjordes på följaren före första starten: det följer med.
        ny.lightCheck = ny.lightCheck ?? pass.lightCheck
        let folder = passFolder(id)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        Self.createOutsideBackup(folder.appending(path: "Video", directoryHint: .isDirectory))
        Self.createOutsideBackup(folder.appending(path: "Klipp", directoryHint: .isDirectory))
        do {
            try write(ny)
        } catch {
            problem = String(localized: "pass.json could not be saved.")
            return nil
        }
        removeEmpty(pass.id)
        return ny
    }

    /// Ett pass utan serier tas bort ur listan och från disken; ett med serier rörs aldrig.
    private func removeEmpty(_ id: String) {
        guard PassID.isValid(id), let p = load(id), p.series.isEmpty, p.shots.isEmpty else { return }
        try? FileManager.default.removeItem(at: passFolder(id))
        index.passes.removeAll { $0.id == id }
        cache?[id] = nil
        try? PassCoding.encoder().encode(index).write(to: indexFile, options: .atomic)
    }

    /// `par.json` i den styrande telefonens pass (S2_SPEC §7.3, §8.3), eller nil.
    func pairs(_ passID: String) -> PairFile? {
        guard PassID.isValid(passID) else { return nil }
        return read(PairFile.self, at: url("par.json", in: passID), aside: "par")
    }

    /// Följarnas serier i den styrandes pass (`foljare.json`), tom om filen saknas.
    func followerRecords(_ passID: String) -> [FollowerRecord] {
        guard PassID.isValid(passID) else { return [] }
        return read(FollowerInbox.self, at: url("foljare.json", in: passID), aside: "foljare")?.entries ?? []
    }

    /// En följares serie till `foljare.json`, innan den kvitteras (BESLUT B22). false =
    /// gick inte att spara, och då kvitteras den inte.
    func saveFollower(_ r: FollowerRecord, passID: String) -> Bool {
        guard PassID.isValid(passID) else { return false }
        var inbox = read(FollowerInbox.self, at: url("foljare.json", in: passID), aside: "foljare") ?? FollowerInbox()
        inbox.upsert(r)
        do {
            try FileManager.default.createDirectory(at: passFolder(passID), withIntermediateDirectories: true)
            try PassCoding.encoder().encode(inbox).write(to: url("foljare.json", in: passID), options: .atomic)
            return true
        } catch {
            problem = String(localized: "foljare.json could not be saved.")
            return false
        }
    }

    /// En parad serie till `par.json`: raden för samma serie och följare ersätts.
    func savePair(_ e: PairEntry, passID: String, model: String, view: Vy) {
        guard PassID.isValid(passID) else { return }
        var fil = pairs(passID) ?? PairFile(pass: passID, model: model, view: view)
        fil.upsert(e)
        do {
            try PassCoding.encoder().encode(fil).write(to: url("par.json", in: passID), options: .atomic)
        } catch {
            problem = String(localized: "par.json could not be saved.")
        }
    }

    // MARK: Måtten (S4b)

    /// Johannes längd (skalan, METOD M2, MS14); nil = standarden, märkt antagen.
    func setHeight(_ h: Double?) {
        settings.heightM = h
        do {
            try PassCoding.encoder().encode(settings).write(to: settingsFile, options: .atomic)
        } catch {
            problem = String(localized: "installningar.json could not be saved.")
        }
    }

    /// Passet med slagens mått: slagen med leder men utan mått (ett pass från före S4b),
    /// eller mätta med en annan längd, mäts nu och passet sparas. METOD MS14
    func measured(_ pass: PassState) -> PassState {
        var p = pass
        let id = pass.id
        if p.measureShots(height: settings.heightM, joints: { s in s.joints.flatMap { self.joints($0, in: id) } }) {
            save(p)
        }
        return p
    }

    /// Alla pass på telefonen, för de tidigare passen (baslinjen och "vs", METOD MS14). Läses
    /// från disken första gången; sedan håller `write` dem aktuella.
    func allPasses() -> [PassState] {
        var c = cache ?? [:]
        let ut = index.passes.compactMap { e -> PassState? in
            if let p = c[e.id] { return p }
            let p = load(e.id)
            c[e.id] = p
            return p
        }
        cache = c
        return ut
    }

    /// Slagens mått med längden `height`, utan Store och utan huvudtråden: lederna läses
    /// direkt ur passets mapp under `root`. Svarar passen; de som ändrades har nya mått och
    /// ska sparas av den som anropar (på huvudtråden). METOD MS14
    static func measuring(_ passes: [PassState], height: Double?, root: URL) -> [PassState] {
        passes.map { pass in
            var p = pass
            let mapp = root.appending(path: "Pass", directoryHint: .isDirectory)
                .appending(path: pass.id, directoryHint: .isDirectory)
            p.measureShots(height: height) { s in
                guard let rel = s.joints, let data = try? Data(contentsOf: mapp.appending(path: rel)) else { return nil }
                return try? JSONDecoder().decode(JointSeries.self, from: data)
            }
            return p
        }
    }

    // MARK: Originalen (BESLUT B26)

    func setKeepOriginals(_ keep: Bool) {
        settings.keepOriginals = keep
        do {
            try PassCoding.encoder().encode(settings).write(to: settingsFile, options: .atomic)
        } catch {
            problem = String(localized: "installningar.json could not be saved.")
        }
    }

    /// Tar bort passets original (Video/) när "Spara bara klippen" är valt och passet
    /// är exporterat. Rör aldrig något utanför passets Video-mapp. Svarar antalet filer.
    @discardableResult
    func releaseOriginals(_ pass: PassState) -> Int {
        guard PassStorage.mayDeleteOriginals(keepOriginals: settings.keepOriginals, status: pass.status) else { return 0 }
        let video = passFolder(pass.id).appending(path: "Video", directoryHint: .isDirectory).standardizedFileURL
        var n = 0
        for s in pass.series {
            let f = url(s.file, in: pass.id).standardizedFileURL
            guard f.deletingLastPathComponent() == video else { continue }
            if (try? FileManager.default.removeItem(at: f)) != nil { n += 1 }
        }
        return n
    }

    // MARK: Disken

    /// Ledigt för viktigt bruk, byte (nil = okänt).
    func availableBytes() -> Int64? {
        let v = try? root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return v?.volumeAvailableCapacityForImportantUsage
    }

    // MARK: Hjälp

    private func read<T: Decodable>(_ type: T.Type, at url: URL, aside: String) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try PassCoding.decoder().decode(type, from: data)
        } catch {
            let undan = url.deletingLastPathComponent()
                .appending(path: "\(aside)-unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: undan)
            problem = String(localized: "\(url.lastPathComponent) could not be read. Saved as \(undan.lastPathComponent).")
            return nil
        }
    }

    /// Skapar mappen och håller den utanför iCloud-backupen: videon är stor och går
    /// att spela in igen (Airtime Store.swift).
    static func createOutsideBackup(_ dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var d = dir
        try? d.setResourceValues(values)
    }
}
