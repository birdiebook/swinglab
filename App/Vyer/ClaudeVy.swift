import SwiftUI
import UIKit
import Accessibility
import UniformTypeIdentifiers
import Swing
import Capture

// Claude-appen på telefonen (S5b-2, BESLUT B52, B60): "Ask Claude" kopierar underlaget för ett
// pass till urklippet, och "Paste from Claude" läser svaret, kontrollerar det som PC:n (B54) och
// visar sakerna i ett blad innan de sparas. Raden sitter i passet och på Today (det senaste
// passet). Formspråket är B13: text i gråskala, ingen ikon, inget värdeord. METOD MS18

/// Logiken bakom knapparna, utan vy, så att provet går samma väg som appen.
@MainActor
enum ClaudeApp {
    /// Claude-appens URL-schema; står i `LSApplicationQueriesSchemes` (project.yml), annars svarar
    /// `canOpenURL` alltid nej. BESLUT B60
    static let url = URL(string: "claude://")!

    /// "Open Claude" visas bara när appen finns.
    static var kanOppnas: Bool { UIApplication.shared.canOpenURL(url) }

    /// Så länge texten ligger i urklippet: den bär passets mätningar (Dataregeln). METOD MS18
    static let urklippSekunder: TimeInterval = 600

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

    /// Texten i urklippet bara på den här telefonen (inte Universal Clipboard till Macen) och bara
    /// i `urklippSekunder` (Dataregeln, BESLUT B60). Svarar urklippets `changeCount`.
    @discardableResult
    static func kopiera(_ text: String, nu: Date = Date()) -> Int {
        UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: text]],
                                      options: [.localOnly: true, .expirationDate: nu.addingTimeInterval(urklippSekunder)])
        return UIPasteboard.general.changeCount
    }

    /// "Ask Claude" i ett steg (provet): underlaget i urklippet. Svarar texten, eller nil när det
    /// inte finns något att fråga om. Knapparna gör samma två steg, med en kontroll emellan.
    @discardableResult
    static func fraga(passID: String, store: Store, katalog: Katalog, skapad: Date = Date()) async -> String? {
        guard let u = await underlag(passID: passID, store: store, katalog: katalog, skapad: skapad) else { return nil }
        kopiera(u.text)
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
        /// Filen blir Focus (den senaste, `Store.focus`); annars sparas den för ett äldre pass.
        let blirFocus: Bool
        /// Dagen för filen som förblir Focus ("Nov 13") när den här inte blir det.
        let focusFran: String?
        /// Urklippets `changeCount` när svaret lästes: det töms efter "Use" bara om det är kvar.
        let urklipp: Int
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
        let urklipp = UIPasteboard.general.changeCount
        guard let p = await passen(passID, store: store) else { return .fel([ClaudeApp.utanPass]) }
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
                // Focus är filen med det högsta pass-id:t (`Store.latestFocus`, BESLUT B36).
                let namn = (try? FileManager.default.contentsOfDirectory(atPath: mapp.path)) ?? []
                let blir = FocusInbox.latest(namn + [fileName]) == fileName
                var fran: String?
                if !blir, let senaste = FocusInbox.latest(namn),
                   let d = try? Data(contentsOf: mapp.appending(path: senaste)),
                   let f = try? FocusInbox.accept(d).focus {
                    fran = f.passDatum.map(Tal.datum)
                }
                return .mottaget(Mottaget(focus: focus, fileName: fileName, data: data, finns: namn.contains(fileName),
                                          blirFocus: blir, focusFran: fran, urklipp: urklipp))
            }
        }.value
    }

    /// "Use": filen sparas som en från PC:n ("Import focus"), och `Store.focus` följer med, så att
    /// Today och accenten (BESLUT B31) ändras direkt. Svaret bär mätningarna, så urklippet töms
    /// när det fortfarande är Claudes svar (Dataregeln, BESLUT B60).
    static func anvand(_ m: Mottaget, store: Store) throws {
        try store.importFocus(m.data)
        if UIPasteboard.general.changeCount == m.urklipp { UIPasteboard.general.items = [] }
    }
}

/// Raden med knapparna, som värden (provet ritar den): två diskreta textknappar med en tunn
/// linje ovanför, och under dem "Copied" med "Open Claude", eller felraden. Ett tryck på felraden
/// visar alla felen; texten går att markera.
struct ClaudeRad: View {
    enum Lage: Equatable {
        case vila
        case arbetar
        case kopierat
        /// `Texter.kontrollfelRad` och `kontrollfelAlla`: fältet och koden.
        case fel(rad: String, alla: [String])
    }

    var lage: Lage
    /// Claude-appen går att öppna (`ClaudeApp.kanOppnas`) och texten är kopierad.
    var oppna: Bool
    var fraga: () -> Void
    var klistra: () -> Void
    var oppnaClaude: () -> Void
    @State private var visaAlla: Bool

    init(lage: Lage = .vila, oppna: Bool = false, visaAlla: Bool = false, fraga: @escaping () -> Void = {},
         klistra: @escaping () -> Void = {}, oppnaClaude: @escaping () -> Void = {}) {
        self.lage = lage
        self.oppna = oppna
        self.fraga = fraga
        self.klistra = klistra
        self.oppnaClaude = oppnaClaude
        _visaAlla = State(initialValue: visaAlla)
    }

    private struct Stil: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .typsnitt(15, .medium)
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.leading)
                .frame(minHeight: 44)
                .contentShape(.rect)
                .opacity(configuration.isPressed ? 0.6 : 1)
        }
    }

    @ViewBuilder private var knappar: some View {
        Button("Ask Claude", action: fraga)
        Button("Paste from Claude", action: klistra)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Bredvid varandra när de får plats, annars under varandra (stor text).
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 24) {
                    knappar
                    Spacer(minLength: 0)
                    if lage == .arbetar { ProgressView().controlSize(.small) }
                }
                VStack(alignment: .leading, spacing: 0) {
                    knappar
                    if lage == .arbetar { ProgressView().controlSize(.small) }
                }
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
            if case let .fel(rad, alla) = lage {
                VStack(alignment: .leading, spacing: 4) {
                    if visaAlla {
                        ForEach(Array(alla.enumerated()), id: \.offset) { _, t in Text(verbatim: t) }
                    } else {
                        Text(verbatim: rad)
                    }
                }
                .typsnitt(13)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
                .onTapGesture { if alla.count > 1 { visaAlla.toggle() } }
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.hair).frame(height: 1)
        }
        .onChange(of: lage) { _, _ in visaAlla = false }
    }
}

/// Bladets steg som värden, så att provet går samma väg som knapparna: "Use" frågar först när
/// passet redan har en fil, "Replace" sparar och "Cancel" stänger utan att något sparas.
struct Bladsteg: Equatable {
    let finns: Bool
    private(set) var fragar = false

    enum Tryck { case anvand, ersatt, avbryt }
    enum Utfall: Equatable { case fraga, spara, stang }

    init(finns: Bool, fragar: Bool = false) {
        self.finns = finns
        self.fragar = fragar
    }

    mutating func tryck(_ t: Tryck) -> Utfall {
        switch t {
        case .anvand:
            if finns && !fragar {
                fragar = true
                return .fraga
            }
            return .spara
        case .ersatt:
            return .spara
        case .avbryt:
            return .stang
        }
    }
}

/// Bladet med Claudes svar: sakerna som i Focus (`SakVy`), och "Use" och "Cancel". Har passet
/// redan en fil frågar "Use" först, uttryckligen, innan den skrivs över (PLAN S5b-2). Blir filen
/// inte Focus (ett äldre pass) säger en grå rad det, och knappen heter "Save".
struct ClaudeSvarsblad: View {
    let visning: AttJobbaPaVisning
    let blirFocus: Bool
    let focusFran: String?
    /// `.spara` eller `.stang`; `.fraga` stannar i bladet.
    var klar: (Bladsteg.Utfall) -> Void
    @State private var steg: Bladsteg

    init(visning: AttJobbaPaVisning, steg: Bladsteg, blirFocus: Bool = true, focusFran: String? = nil,
         klar: @escaping (Bladsteg.Utfall) -> Void = { _ in }) {
        self.visning = visning
        self.blirFocus = blirFocus
        self.focusFran = focusFran
        self.klar = klar
        _steg = State(initialValue: steg)
    }

    private func tryck(_ t: Bladsteg.Tryck) {
        let u = steg.tryck(t)
        if u != .fraga { klar(u) }
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
                if !blirFocus, let focusFran {
                    Under(text: String(localized: "Saved for \(visning.fran) · Focus stays \(focusFran)"))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 4)
                }
                if steg.fragar {
                    Group {
                        if blirFocus {
                            Text("Replace the focus from \(visning.fran)?")
                        } else {
                            Text("Replace the file from \(visning.fran)?")
                        }
                    }
                    .typsnitt(15, .medium)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)
                    Button("Replace") { tryck(.ersatt) }
                        .buttonStyle(PrimaryButtonStyle())
                } else if blirFocus {
                    Button("Use") { tryck(.anvand) }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("Save") { tryck(.anvand) }
                        .buttonStyle(PrimaryButtonStyle())
                }
                Button("Cancel") { tryck(.avbryt) }
                    .buttonStyle(RowButtonStyle())
            }
            .padding(.top, 28)
        }
        .padding(.horizontal, 20)
        .background(Theme.ground)
    }
}

/// Knapparna med sitt läge och bladet, för ett pass. `onFocus` körs när ett svar sparats. Ett jobb
/// gäller passet det startades för: byts passet, eller försvinner raden, avbryts det, och inget
/// skrivs till urklippet eller raden efteråt.
struct ClaudeKnappar: View {
    let passID: String
    var onFocus: () -> Void = {}

    @Environment(Store.self) private var store
    @State private var lage = ClaudeRad.Lage.vila
    @State private var oppna = false
    @State private var mottaget: ClaudeApp.Mottaget?
    @State private var jobb: Task<Void, Never>?
    @State private var bekraftelse: Task<Void, Never>?
    /// Passet som det pågående jobbet gäller; nil = inget jobb.
    @State private var jobbID: String?

    /// Så länge "Copied" står kvar. METOD MS18
    static let bekraftelseSekunder = 3.0

    var body: some View {
        ClaudeRad(lage: lage, oppna: oppna, fraga: fraga, klistra: klistra,
                  oppnaClaude: { UIApplication.shared.open(ClaudeApp.url) })
            // Medan ett paket skrivs (Send to PC) ändras inga pass (PassMeasures sparar mått).
            .disabled(!store.exporting.isEmpty)
            .onChange(of: passID) { _, _ in
                avbryt()
                lage = .vila
                oppna = false
                mottaget = nil
            }
            .onDisappear {
                avbryt()
                if lage == .arbetar { lage = .vila }
            }
            .sheet(item: $mottaget) { m in
                ScrollView {
                    if let k = AppKatalog.katalog {
                        ClaudeSvarsblad(visning: AttJobbaPaVisning(m.focus, katalog: k), steg: Bladsteg(finns: m.finns),
                                        blirFocus: m.blirFocus, focusFran: m.focusFran) { utfall in
                            if utfall == .spara { anvand(m) } else { mottaget = nil }
                        }
                        .padding(.vertical, 16)
                    }
                }
                .background(Theme.ground, ignoresSafeAreaEdges: .all)
                .preferredColorScheme(.dark)
                .presentationDragIndicator(.visible)
            }
    }

    private func avbryt() {
        jobb?.cancel()
        jobb = nil
        bekraftelse?.cancel()
        bekraftelse = nil
        jobbID = nil
    }

    private func meddela(_ text: String) {
        AccessibilityNotification.Announcement(text).post()
    }

    private func fraga() {
        guard lage != .arbetar, let k = AppKatalog.katalog else { return }
        avbryt()
        let id = passID
        jobbID = id
        lage = .arbetar
        oppna = false
        jobb = Task {
            let u = await ClaudeApp.underlag(passID: id, store: store, katalog: k)
            guard !Task.isCancelled, jobbID == id else { return }
            jobbID = nil
            guard let u else {
                lage = .vila
                return
            }
            ClaudeApp.kopiera(u.text)
            lage = .kopierat
            oppna = ClaudeApp.kanOppnas
            meddela(String(localized: "Copied"))
            bekraftelse = Task {
                try? await Task.sleep(for: .seconds(Self.bekraftelseSekunder))
                if !Task.isCancelled, lage == .kopierat { lage = .vila }
            }
        }
    }

    private func klistra() {
        guard lage != .arbetar, let k = AppKatalog.katalog else { return }
        avbryt()
        let id = passID
        jobbID = id
        lage = .arbetar
        oppna = false
        jobb = Task {
            let r = await ClaudeApp.klistra(passID: id, store: store, katalog: k)
            guard !Task.isCancelled, jobbID == id else { return }
            jobbID = nil
            switch r {
            case let .mottaget(m):
                lage = .vila
                mottaget = m
            case let .fel(f):
                let rad = Texter.kontrollfelRad(f)
                lage = .fel(rad: rad, alla: Texter.kontrollfelAlla(f))
                meddela(rad)
            }
        }
    }

    private func anvand(_ m: ClaudeApp.Mottaget) {
        mottaget = nil
        do {
            try ClaudeApp.anvand(m, store: store)
            onFocus()
        } catch {
            lage = .fel(rad: Texter.focusSparadesInte, alla: [Texter.focusSparadesInte])
            meddela(Texter.focusSparadesInte)
        }
    }
}
