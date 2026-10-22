import SwiftUI
import UniformTypeIdentifiers
import Swing

@main
struct SwingLabApp: App {
    @State private var store = Store()

    var body: some Scene {
        WindowGroup {
            StartView()
                .environment(store)
                .preferredColorScheme(.dark)
        }
    }
}

/// Startvyn (S2_SPEC §12). Nytt pass (S2c) och Hämta ur Bilder (S2d) öppnar
/// uppställningen; Hämta Att jobba på (S2f) öppnar Filer för `att_jobba_pa.json`, som
/// kontrolleras och sparas (BESLUT B28; vyerna visar den från S4c). Under dem passen, och ett tryck
/// öppnar slagen med analysen (S2e). Formspråket är BESLUT B13:
/// bara etiketter, ingen beskrivande text. Texterna är engelska och står i
/// Localizable.xcstrings (BESLUT B30, B33).
struct StartView: View {
    @Environment(Store.self) private var store
    @State private var flow: PassFlowView.Mode?
    @State private var opened: OpenPass?
    /// Filer för `att_jobba_pa.json` (S2_SPEC §8.5).
    @State private var importingFocus = false
    /// Svaret efter hämtningen: sparad, eller felet (fältet, aldrig värdet).
    @State private var focusResult: String?
    @State private var focusFailed = false

    struct OpenPass: Identifiable {
        let id: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SwingLab")
                .font(.system(size: 30, weight: .semibold))
                .tracking(-0.6)
                .foregroundStyle(Theme.text)
                .padding(.top, 8)
                .padding(.bottom, 18)

            Button("New session") { flow = .record }
                .buttonStyle(PrimaryButtonStyle())

            VStack(spacing: 0) {
                Button("Import from Photos") { flow = .photos }
                Button("Import focus") { importingFocus = true }
            }
            .buttonStyle(RowButtonStyle())
            .padding(.top, 22)

            if let focusResult {
                Text(verbatim: focusResult)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(focusFailed ? Theme.flag : Theme.secondary)
                    .padding(.top, 12)
            }

            if let problem = store.problem {
                Text(problem)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.flag)
                    .padding(.top, 12)
            }

            // Passen och deras slag (S2e).
            if !store.index.passes.isEmpty {
                ScrollView {
                    PassListSection(entries: store.index.passes) { opened = OpenPass(id: $0) }
                }
                .padding(.top, 22)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.ground, ignoresSafeAreaEdges: .all)
        .fileImporter(isPresented: $importingFocus, allowedContentTypes: [.json], allowsMultipleSelection: false) { r in
            importFocus(r)
        }
        .fullScreenCover(item: $flow) { mode in
            PassFlowView(mode: mode) { flow = nil }
                .environment(store)
        }
        .fullScreenCover(item: $opened) { p in
            PassShotsView(passID: p.id) { opened = nil }
                .environment(store)
        }
    }

    /// Den valda filen kontrolleras och sparas (`Store.importFocus`). BESLUT B28
    private func importFocus(_ r: Result<[URL], Error>) {
        guard case .success(let urls) = r, let url = urls.first else { return }
        do {
            try store.importFocus(from: url)
            focusResult = String(localized: "Focus saved")
            focusFailed = false
        } catch {
            focusResult = (error as? FormatFel)?.description ?? String(localized: "The file could not be read.")
            focusFailed = true
        }
    }
}
