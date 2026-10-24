import SwiftUI
import UIKit
import Swing
import Capture

// Claude-appen på telefonen (S5b-2, BESLUT B52, B60): "Ask Claude" kopierar underlaget för ett
// pass till urklippet, och "Paste from Claude" läser svaret, kontrollerar det som PC:n (B54) och
// visar sakerna i ett blad innan de blir Focus. Raden sitter i passet och på Today (det senaste
// passet). Formspråket är B13: text i gråskala, ingen ikon, inget värdeord. METOD MS18

/// Logiken bakom knapparna, utan vy, så att provet går samma väg som appen.
@MainActor
enum ClaudeApp {
    /// Claude-appens URL-schema; står i `LSApplicationQueriesSchemes` (project.yml), annars svarar
    /// `canOpenURL` alltid nej. BESLUT B60
    static let url = URL(string: "claude://")!

    /// "Open Claude" visas bara när appen finns.
    static var kanOppnas: Bool { UIApplication.shared.canOpenURL(url) }

    /// Passet och de tidigare passen som kan jämföras (samma klubba, vy och längd), mätta som i
    /// passets skärm (`PassMeasures`, METOD MS14). nil när passet inte finns.
    private static func passen(_ passID: String, store: Store) async -> (nu: PassState, alla: [PassState])? {
        guard let p = store.load(passID) else { return nil }
        let r = await PassMeasures.load(p, store: store)
        return (r.pass, r.earlier + [r.pass])
    }

    /// Underlaget och texten för passet, räknade utanför huvudtråden: `ClaudeKontext.underlag` med
    /// passet `nu` uttryckligen och de hämtade filerna, som den bara läser för passen i
    /// sammanhanget (BESLUT B56). nil när passet saknas eller inte har några slag som räknas.
    static func underlag(passID: String, store: Store, katalog: Katalog,
                         skapad: Date = Date()) async -> (underlag: ClaudeUnderlag, text: String)? {
        guard let p = await passen(passID, store: store) else { return nil }
        let nu = p.nu, alla = p.alla
        let root = store.root
        return await Task.detached(priority: .userInitiated) { () -> (underlag: ClaudeUnderlag, text: String)? in
            guard let u = ClaudeKontext.underlag(nu: nu, alla: alla, filer: Store.readingFocus(root: root),
                                                 katalog: katalog, skapad: skapad) else { return nil }
            return (u, u.text)
        }.value
    }

    /// "Ask Claude": texten i urklippet. Svarar texten, eller nil när det inte finns något att fråga om.
    @discardableResult
    static func fraga(passID: String, store: Store, katalog: Katalog, skapad: Date = Date()) async -> String? {
        guard let u = await underlag(passID: passID, store: store, katalog: katalog, skapad: skapad) else { return nil }
        UIPasteboard.general.string = u.text
        return u.text
    }

    /// Felet när passet inte finns eller inte har några slag som räknas (raden visas bara för ett
    /// mätt pass, så det är sällsynt): koden "not in this session".
    nonisolated static let utanPass = Kontrollfel("pass", "ej_i_analysen")

    /// Ett godkänt svar som väntar på "Use".
    struct Mottaget: Identifiable, Sendable {
        let focus: AttJobbaPa
        let fileName: String
        let data: Data
        /// Passet har redan en fil: "Use" frågar innan den skrivs över (PLAN S5b-2).
        let finns: Bool
        var id: String { fileName }
    }

    enum Klistrat: Sendable {
        case mottaget(Mottaget)
        /// Fältet och koden, aldrig värdet (BESLUT B54).
        case fel([Kontrollfel])
    }

    /// "Paste from Claude": urklippet läses här och bara här, efter Johannes tryck, så att iOS
    /// frågar om tillåtelse att klistra in. Svaret kontrolleras mot underlaget för samma pass
    /// (`FocusInbox.acceptClaude`); inget sparas förrän "Use".
    static func klistra(passID: String, store: Store, katalog: Katalog) async -> Klistrat {
        let text = UIPasteboard.general.string ?? ""
        guard let p = await passen(passID, store: store) else {
            return .fel([ClaudeApp.utanPass])
        }
        let nu = p.nu, alla = p.alla
        let root = store.root
        let mapp = store.focusFolder
        return await Task.detached(priority: .userInitiated) { () -> Klistrat in
            guard let u = ClaudeKontext.underlag(nu: nu, alla: alla, filer: Store.readingFocus(root: root),
                                                 katalog: katalog) else {
                return .fel([ClaudeApp.utanPass])
            }
            switch FocusInbox.acceptClaude(text, underlag: u) {
            case let .rejected(f):
                return .fel(f)
            case let .accepted(focus, fileName, data):
                let finns = FileManager.default.fileExists(atPath: mapp.appending(path: fileName).path)
                return .mottaget(Mottaget(focus: focus, fileName: fileName, data: data, finns: finns))
            }
        }.value
    }

    /// "Use": filen sparas som en från PC:n ("Import focus"), och `Store.focus` följer med, så att
    /// Today och accenten (BESLUT B31) ändras direkt.
    static func anvand(_ m: Mottaget, store: Store) throws {
        try store.importFocus(m.data)
    }
}

/// Raden med knapparna, som värden (provet ritar den): två diskreta textknappar med en tunn
/// linje ovanför, och under dem "Copied" med "Open Claude", eller felraden.
struct ClaudeRad: View {
    enum Lage: Equatable {
        case vila
        case arbetar
        case kopierat
        /// `Texter.kontrollfelRad`: fältet och koden.
        case fel(String)
    }

    var lage: Lage = .vila
    /// Claude-appen går att öppna (`ClaudeApp.kanOppnas`) och texten är kopierad.
    var oppna = false
    var fraga: () -> Void = {}
    var klistra: () -> Void = {}
    var oppnaClaude: () -> Void = {}

    private struct Stil: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .typsnitt(15, .medium)
                .foregroundStyle(Theme.secondary)
                .frame(minHeight: 44)
                .contentShape(.rect)
                .opacity(configuration.isPressed ? 0.6 : 1)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 24) {
                Button("Ask Claude", action: fraga)
                Button("Paste from Claude", action: klistra)
                Spacer(minLength: 0)
                if lage == .arbetar { ProgressView().controlSize(.small) }
            }
            .buttonStyle(Stil())
            .disabled(lage == .arbetar)
            if lage == .kopierat || oppna {
                HStack(spacing: 24) {
                    if lage == .kopierat {
                        Text("Copied")
                            .typsnitt(13)
                            .foregroundStyle(Theme.tertiary)
                    }
                    if oppna {
                        Button("Open Claude", action: oppnaClaude)
                            .buttonStyle(Stil())
                    }
                }
                .frame(minHeight: 32)
            }
            if case let .fel(rad) = lage {
                Text(verbatim: rad)
                    .typsnitt(13)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.hair).frame(height: 1)
        }
    }
}

/// Bladet med Claudes svar: sakerna som i Focus (`SakVy`), och "Use" och "Cancel". Har passet
/// redan en fil frågar "Use" först, uttryckligen, innan den skrivs över (PLAN S5b-2).
struct ClaudeSvarsblad: View {
    let visning: AttJobbaPaVisning
    let finns: Bool
    var anvand: () -> Void = {}
    var avbryt: () -> Void = {}
    @State private var fragar: Bool

    init(visning: AttJobbaPaVisning, finns: Bool, fragar: Bool = false,
         anvand: @escaping () -> Void = {}, avbryt: @escaping () -> Void = {}) {
        self.visning = visning
        self.finns = finns
        self.anvand = anvand
        self.avbryt = avbryt
        _fragar = State(initialValue: fragar)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Focus")
                    .typsnitt(16, .semibold)
                    .foregroundStyle(Theme.text)
                Spacer()
                Under(text: visning.fran)
            }
            .frame(minHeight: 44)
            .padding(.bottom, 8)
            ForEach(Array(visning.saker.enumerated()), id: \.offset) { i, s in
                SakVy(sak: s, antal: visning.saker.count)
                    .padding(.top, i == 0 ? 0 : 28)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(s.upplasningHel)
            }
            VStack(alignment: .leading, spacing: 8) {
                if fragar {
                    Text("Replace the focus from \(visning.fran)?")
                        .typsnitt(15, .medium)
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 4)
                    Button("Replace", action: anvand)
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("Use") {
                        if finns { fragar = true } else { anvand() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                Button("Cancel", action: avbryt)
                    .buttonStyle(RowButtonStyle())
            }
            .padding(.top, 28)
        }
        .padding(.horizontal, 20)
        .background(Theme.ground)
    }
}

/// Knapparna med sitt läge och bladet, för ett pass. `onFocus` körs när ett svar blivit Focus.
struct ClaudeKnappar: View {
    let passID: String
    var onFocus: () -> Void = {}

    @Environment(Store.self) private var store
    @State private var lage = ClaudeRad.Lage.vila
    @State private var oppna = false
    @State private var mottaget: ClaudeApp.Mottaget?
    @State private var bekraftelse: Task<Void, Never>?

    /// Så länge "Copied" står kvar. METOD MS18
    static let bekraftelseSekunder = 3.0

    var body: some View {
        ClaudeRad(lage: lage, oppna: oppna, fraga: fraga, klistra: klistra,
                  oppnaClaude: { UIApplication.shared.open(ClaudeApp.url) })
            .onChange(of: passID) { _, _ in
                lage = .vila
                oppna = false
            }
            .sheet(item: $mottaget) { m in
                ScrollView {
                    if let k = AppKatalog.katalog {
                        ClaudeSvarsblad(visning: AttJobbaPaVisning(m.focus, katalog: k), finns: m.finns,
                                        anvand: { anvand(m) }, avbryt: { mottaget = nil })
                            .padding(.vertical, 16)
                    }
                }
                .background(Theme.ground, ignoresSafeAreaEdges: .all)
                .preferredColorScheme(.dark)
                .presentationDragIndicator(.visible)
            }
    }

    private func fraga() {
        guard lage != .arbetar, let k = AppKatalog.katalog else { return }
        lage = .arbetar
        bekraftelse?.cancel()
        Task {
            let text = await ClaudeApp.fraga(passID: passID, store: store, katalog: k)
            lage = text == nil ? .vila : .kopierat
            oppna = text != nil && ClaudeApp.kanOppnas
            guard text != nil else { return }
            bekraftelse = Task {
                try? await Task.sleep(for: .seconds(Self.bekraftelseSekunder))
                if !Task.isCancelled, lage == .kopierat { lage = .vila }
            }
        }
    }

    private func klistra() {
        guard lage != .arbetar, let k = AppKatalog.katalog else { return }
        lage = .arbetar
        bekraftelse?.cancel()
        Task {
            switch await ClaudeApp.klistra(passID: passID, store: store, katalog: k) {
            case let .mottaget(m):
                lage = .vila
                mottaget = m
            case let .fel(f):
                lage = .fel(Texter.kontrollfelRad(f))
            }
        }
    }

    private func anvand(_ m: ClaudeApp.Mottaget) {
        mottaget = nil
        do {
            try ClaudeApp.anvand(m, store: store)
            oppna = false
            onFocus()
        } catch {
            lage = .fel(error.localizedDescription)
        }
    }
}
