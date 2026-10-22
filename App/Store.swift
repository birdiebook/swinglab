import Foundation
import Observation
import Capture

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
        guard PassID.isValid(pass.id) else { return }
        do {
            try FileManager.default.createDirectory(at: passFolder(pass.id), withIntermediateDirectories: true)
            try PassCoding.encoder().encode(pass).write(to: passFile(pass.id), options: .atomic)
            index.upsert(pass.entry)
            try PassCoding.encoder().encode(index).write(to: indexFile, options: .atomic)
        } catch {
            problem = String(localized: "pass.json could not be saved.")
        }
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
