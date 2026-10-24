import AVFoundation
import SwiftUI
import UIKit
import Swing
import Capture
import TreD

/// Paketet till PC:n (S2_SPEC §8.3–8.4, BESLUT B27): appen fyller i det bara telefonen
/// vet (modellen, iOS, appens version, kameraformaten och klippens längd) och låter
/// SwingLabKit (`PassPackage`) bygga och skriva zippen, strömmad till disk. Paketet
/// hamnar i `Documents/Export/` och delas med `ActivitySheet`; vart det går väljer
/// Johannes (BESLUT B3).
enum Export {
    enum ExportError: LocalizedError {
        case noPass
        case noShots
        case tooLarge
        case failed

        var errorDescription: String? {
            switch self {
            case .noShots: return String(localized: "Analyze the session first.")
            case .tooLarge: return String(localized: "Too large. Send without clips.")
            case .noPass, .failed: return String(localized: "The package could not be written.")
            }
        }
    }

    static func appInfo() -> PackageManifest.AppInfo {
        let info = Bundle.main.infoDictionary ?? [:]
        return PackageManifest.AppInfo(version: info["CFBundleShortVersionString"] as? String ?? "?",
                                       build: info["CFBundleVersion"] as? String ?? "?")
    }

    /// "iPhone18,1" (simulatorn: modellen den efterliknar).
    static func modelIdentifier() -> String {
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return sim }
        var u = utsname()
        uname(&u)
        return withUnsafeBytes(of: &u.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    @MainActor
    static func phoneInfo() -> PackageManifest.PhoneInfo {
        PackageManifest.PhoneInfo(model: modelIdentifier(), ios: UIDevice.current.systemVersion)
    }

    /// `enhet.json`: alla format bakkameran rapporterar (tom i simulatorn) och det som
    /// valdes för passets första inspelade serie (METOD MS1).
    @MainActor
    static func deviceInfo(_ pass: PassState) -> DeviceInfo {
        let kamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        return DeviceInfo(model: modelIdentifier(), ios: UIDevice.current.systemVersion,
                          formats: kamera.map { Camera.describe($0.formats) } ?? [],
                          chosenIndex: pass.series.compactMap(\.format).first?.index)
    }

    /// Klippens längd (passet → s), så att PC:n räknar bara klippets rutor i [0; längd):
    /// passthrough-klippet bär rutor efter redigeringens slut (METOD MS12).
    static func clipDurations(_ pass: PassState, store: Store) async -> [String: Double] {
        var ut: [String: Double] = [:]
        for s in pass.shots {
            guard let rel = s.clip else { continue }
            let url = store.url(rel, in: pass.id)
            guard FileManager.default.fileExists(atPath: url.path),
                  let d = try? await AVURLAsset(url: url).load(.duration), d.isValid, d.seconds.isFinite else { continue }
            ut[rel] = d.seconds
        }
        return ut
    }

    /// Skriver passets paket och svarar filen. Passet blir "exporterat"; med "Spara bara
    /// klippen" och ett färdigt pass tas originalen bort efter en export med klipp (BESLUT B26).
    @MainActor
    static func package(passID: String, store: Store, includeClips: Bool, now: Date = Date()) async throws -> URL {
        guard let pass = store.load(passID) else { throw ExportError.noPass }
        // Analyze och redigeraren väntar medan paketet skrivs, så att passet inte ändras under.
        store.setExporting(passID, true)
        defer { store.setExporting(passID, false) }
        let folder = store.passFolder(pass.id)
        let url = store.exportURL(pass)
        let scratch = store.scratchFolder
        let app = appInfo(), phone = phoneInfo(), device = deviceInfo(pass)
        let langd = includeClips ? await clipDurations(pass, store: store) : [:]
        let p = pass
        let fil = store.treD(pass.id)
        do {
            _ = try await Task.detached(priority: .userInitiated) {
                // 3D följer med bara när filen gäller passets slag som de är nu (S6c-2, BESLUT B63).
                var medTreD = false
                if let fil, let b = try? TreDKoppling.egenBunt(p, folder: folder, app: app, phone: phone, device: device) {
                    medTreD = fil.kallor[p.setup.view.rawValue] == Overforing.summa(b.1)
                }
                return try PassPackage.write(pass: p, folder: folder, to: url, scratch: scratch, app: app, phone: phone,
                                             device: device, created: now, includeClips: includeClips,
                                             clipDurations: langd, includeTreD: medTreD)
            }.value
        } catch PassPackage.Error.noShots {
            throw ExportError.noShots
        } catch PassPackage.Error.tooLarge {
            throw ExportError.tooLarge
        } catch {
            throw ExportError.failed
        }
        Store.createOutsideBackup(store.exportFolder)
        // Passet läses om precis före sparningen: bara statusen ändras, inget annat skrivs över.
        if var nu = store.load(passID) {
            nu.status = .exported
            store.save(nu)
            if includeClips, ShotPlan.next(nu) == nil { store.releaseOriginals(nu) }
        }
        return url
    }

    /// Paketen som "Send to PC" delar: passets eget, och på den styrande med den andra telefonens
    /// slag också den andra vyns (S6g, BESLUT B81), byggt ur bunten och klippen som kommit, i samma
    /// format och kontrakt som den andra telefonens eget paket. Går den andra vyns paket inte att
    /// skriva delas passets eget ensamt.
    @MainActor
    static func packages(passID: String, store: Store, includeClips: Bool, now: Date = Date()) async throws -> [URL] {
        let egen = try await package(passID: passID, store: store, includeClips: includeClips, now: now)
        guard let annan = await otherPackage(passID: passID, store: store, includeClips: includeClips, now: now) else {
            return [egen]
        }
        return [egen, annan]
    }

    /// Den andra vyns paket på den styrande (S6g, BESLUT B81), eller nil (ingen bunt, inga slag med
    /// leder, eller ett fel). METOD MS31
    @MainActor
    static func otherPackage(passID: String, store: Store, includeClips: Bool, now: Date = Date()) async -> URL? {
        guard let p = store.load(passID), p.setup.role == .lead, let bunt = store.otherPhone(passID),
              bunt.vy != p.setup.view else { return nil }
        let folder = store.passFolder(passID), scratch = store.scratchFolder
        let url = store.exportFolder.appending(path: AnnanPaket.filnamn(bunt))
        let video = store.annanVideo(passID)
        store.setExporting(passID, true)
        defer { store.setExporting(passID, false) }
        let ok = await Task.detached(priority: .userInitiated) { () -> Bool in
            (try? AnnanPaket.write(bunt: bunt, video: video, folder: folder, to: url, scratch: scratch, created: now,
                                   medKlipp: includeClips)) != nil
        }.value
        guard ok else { return nil }
        Store.createOutsideBackup(store.exportFolder)
        return url
    }
}

/// Delningsbladet (Idunn): AirDrop, Filer, iCloud Drive.
struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// "Send to PC" i passet: med klipp (standard, för PC:ns MediaPipe) eller utan (några MB).
/// Paketet skrivs och delningsbladet öppnas; ett fel visas och inget delas.
struct SendToPCButton: View {
    let passID: String
    var disabled = false

    @Environment(Store.self) private var store
    @State private var working = false
    @State private var shared: SharedFile?
    @State private var problem: String?

    struct SharedFile: Identifiable {
        let urls: [URL]
        var id: String { urls.map(\.path).joined() }
    }

    var body: some View {
        Group {
            if working {
                ProgressView()
            } else {
                Menu("Send to PC") {
                    Button("With clips") { send(clips: true) }
                    Button("Without clips") { send(clips: false) }
                }
                .disabled(disabled)
            }
        }
        .sheet(item: $shared) { f in
            ActivitySheet(items: f.urls)
        }
        .alert(Text(verbatim: problem ?? ""), isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
            Button("Close", role: .cancel) { problem = nil }
        }
    }

    private func send(clips: Bool) {
        working = true
        Task {
            defer { working = false }
            do {
                // På den styrande också den andra vyns paket (S6g, BESLUT B81).
                let urls = try await Export.packages(passID: passID, store: store, includeClips: clips)
                shared = SharedFile(urls: urls)
            } catch {
                problem = error.localizedDescription
            }
        }
    }
}
