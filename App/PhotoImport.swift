import AVFoundation
import CoreTransferable
import Observation
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import Capture

/// Import ur Bilder för gamla klipp (S2_SPEC §5, §12 S2d). Slowmotion ur Kamera-appen
/// ligger som originalet (240 bilder/s i realtid) plus en justering; den "aktuella"
/// versionen är omräknad och varje tid ungefär 8 gånger för lång. Därför hämtas
/// resursen av typen `.video` (originalet) med PHAssetResourceManager, och
/// `FrameTiming` vägrar en fil utan rutnät på minst 100 bilder/s. BESLUT B24
@Observable
final class PhotoImport {
    struct Outcome: Identifiable {
        let id = UUID()
        var series: SeriesRecord?
        /// Vägrad: inte slowmotion-originalet.
        var refused = false
        var failed = false
    }

    private(set) var outcomes: [Outcome] = []
    private(set) var running = false
    private(set) var current = 0
    private(set) var total = 0
    /// Nedladdningen ur iCloud för den aktuella filen, 0–1.
    private(set) var fraction = 0.0
    /// Begränsad eller nekad åtkomst: vyn ber om full åtkomst.
    private(set) var askFullAccess = false

    /// Hämtar de valda klippen i ordning till passets Video-mapp och svarar passet
    /// med de nya serierna. Varje serie sparas när den är klar.
    @MainActor
    func run(_ items: [PhotosPickerItem], pass: PassState, store: Store) async -> PassState {
        guard !items.isEmpty, !running else { return pass }
        running = true
        UIApplication.shared.isIdleTimerDisabled = true
        defer {
            running = false
            UIApplication.shared.isIdleTimerDisabled = false
        }
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        askFullAccess = status != .authorized
        var pass = pass
        total = items.count
        for (i, item) in items.enumerated() {
            current = i + 1
            fraction = 0
            let nr = pass.nextSeriesNumber
            var outcome = Outcome()
            do {
                if let s = try await importOne(item, nr: nr, pass: pass, store: store, library: status) {
                    pass.series.append(s)
                    store.save(pass)
                    outcome.series = s
                } else {
                    outcome.refused = true
                }
            } catch {
                outcome.failed = true
            }
            outcomes.append(outcome)
        }
        return pass
    }

    /// Ett klipp: originalresursen (eller reserven), rutnätets kontroll och serien.
    /// nil = vägrad (filen är borttagen).
    @MainActor
    private func importOne(_ item: PhotosPickerItem, nr: Int, pass: PassState, store: Store,
                           library: PHAuthorizationStatus) async throws -> SeriesRecord? {
        var asset: PHAsset?
        if library == .authorized || library == .limited, let id = item.itemIdentifier {
            asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
        }
        var file: String
        var url: URL
        if let asset, let resource = Self.original(asset) {
            file = PassState.videoPath(nr: nr, extension: Self.fileExtension(resource.originalFilename))
            url = store.url(file, in: pass.id)
            try? FileManager.default.removeItem(at: url)        // writeData kräver att filen inte finns
            try await write(resource, to: url)
        } else {
            // Reserven (Airtime): filen ur väljaren. Samma kontroll fäller en omräknad fil.
            if asset == nil { askFullAccess = true }
            guard let movie = try await item.loadTransferable(type: PickedMovie.self) else { return nil }
            file = PassState.videoPath(nr: nr, extension: Self.fileExtension(movie.url.lastPathComponent))
            url = store.url(file, in: pass.id)
            try? FileManager.default.removeItem(at: url)
            try FileManager.default.moveItem(at: movie.url, to: url)
        }
        guard try await Self.accept(url) else { return nil }
        var start = asset?.creationDate
        if start == nil { start = await Self.creationDate(url) }
        var s = try await SeriesMaker.make(url: url, nr: nr, file: file, source: .photos, club: pass.setup.club,
                                           start: start ?? Date(), startHost: nil, microphone: nil)
        s.markedSlowMotion = asset.map { $0.mediaSubtypes.contains(.videoHighFrameRate) }
        return s
    }

    /// Rutnätets kontroll (S2_SPEC §5 steg 6): en fil som inte är slowmotion-originalet
    /// tas bort och vägras. METOD MS3, BESLUT B24
    static func accept(_ url: URL) async throws -> Bool {
        let timing = FrameTiming.analyze(try await MediaReader.frameTimes(url))
        guard ImportCheck.verdict(timing) == .accept else {
            try? FileManager.default.removeItem(at: url)
            return false
        }
        return true
    }

    /// Resursen av typen `.video` ("the original video data"), aldrig `.fullSizeVideo`. BESLUT B24
    static func original(_ asset: PHAsset) -> PHAssetResource? {
        let resources = PHAssetResource.assetResources(for: asset)
        let kinds = resources.map { r -> ImportCheck.ResourceKind in
            switch r.type {
            case .video: return .video
            case .fullSizeVideo: return .fullSizeVideo
            default: return .other
            }
        }
        return ImportCheck.original(kinds).map { resources[$0] }
    }

    static func fileExtension(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        return ext.isEmpty ? "mov" : ext
    }

    /// Originalet till fil, ur iCloud vid behov, med förloppet till vyn.
    @MainActor
    private func write(_ resource: PHAssetResource, to url: URL) async throws {
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        options.progressHandler = { [weak self] p in
            DispatchQueue.main.async { self?.fraction = p }
        }
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            PHAssetResourceManager.default().writeData(for: resource, toFile: url, options: options) { error in
                if let error { c.resume(throwing: error) } else { c.resume() }
            }
        }
    }

    /// Filens egen tid för inspelningen, om den står i filen (Airtime).
    static func creationDate(_ url: URL) async -> Date? {
        let created = try? await AVURLAsset(url: url).load(.creationDate)
        return (try? await created?.load(.dateValue)) ?? nil
    }
}

/// Reserven vid begränsad åtkomst: filen ur väljaren, kopierad till tmp (Airtime PickedMovie).
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let dest = FileManager.default.temporaryDirectory.appending(path: "import-\(UUID().uuidString).\(ext)")
            try FileManager.default.copyItem(at: received.file, to: dest)
            return PickedMovie(url: dest)
        }
    }
}

/// Hämta ur Bilder: väljaren (flera klipp i ett svep), förloppet och kvittot per klipp.
struct ImportView: View {
    @Binding var pass: PassState
    var onClose: () -> Void

    @Environment(Store.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var items: [PhotosPickerItem] = []
    @State private var importer = PhotoImport()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PhotosPicker(selection: $items, matching: .videos, preferredItemEncoding: .current,
                                 photoLibrary: .shared()) {
                        Text("Välj klipp")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(importer.running)

                    if importer.running {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(importer.current) av \(importer.total)")
                                .font(Theme.number(15))
                                .foregroundStyle(Theme.secondary)
                            ProgressView(value: importer.fraction).tint(Theme.text)
                        }
                    }

                    if importer.askFullAccess {
                        Button("Full åtkomst till Bilder") {
                            if let u = URL(string: UIApplication.openSettingsURLString) { openURL(u) }
                        }
                        .buttonStyle(RowButtonStyle())
                    }

                    ForEach(importer.outcomes) { o in
                        if let s = o.series {
                            ReceiptCard(title: "Serie \(s.nr)", rows: Receipt.rows(s))
                        } else {
                            Text(o.refused ? ImportCheck.refusal : "Klippet gick inte att hämta.")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.flag)
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.ground, ignoresSafeAreaEdges: .all)
            .navigationTitle("Hämta ur Bilder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Stäng", action: onClose).disabled(importer.running)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: items) { _, valda in
            guard !valda.isEmpty else { return }
            Task {
                pass = await importer.run(valda, pass: pass, store: store)
                items = []
            }
        }
    }
}
