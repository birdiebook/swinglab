import SwiftUI
import UniformTypeIdentifiers
import Swing
import Capture

/// Flikarnas data som värden (S4c), ur passen på telefonen och de hämtade
/// `att_jobba_pa.json`: Idag (det senaste passet mot de tidigare med samma klubba, vy och
/// längd), Utveckling (passen med samma klubba och längd som det senaste) och Att jobba på.
/// Fokus och accenten kommer ur samma källa, `Store.focus` (S2f); alla filerna bara för
/// blocken (BESLUT B31, B36). METOD MS16
///
/// **Dold sedan S4e (BESLUT B64):** Today, Progress och Focus visas inte i navigeringen, men
/// koden och datan är kvar (`IdagVy`, `UtvecklingVy`, `AttJobbaPaVy`), så att de kan komma
/// tillbaka ett tryck bort (VISION.md).
struct Flikdata: Sendable {
    var idag: Idagvisning
    var utveckling: Utvecklingsvisning
    var jobba: AttJobbaPaVisning?
    /// Det senaste passets id: Idags tryck öppnar det.
    var senaste: String?

    /// `fokus` = den senaste filen (`Store.focus`), `filer` = alla, för blocken.
    static func bygg(passes: [PassState], fokus: AttJobbaPa?, filer: [AttJobbaPa], katalog: Katalog,
                     idag: Date = Date()) -> Flikdata {
        let ovas = fokus?.ovas ?? []
        var idagPass: [Swing.Pass] = []
        let nu = PassHistory.latest(passes)
        if let nu {
            idagPass = PassHistory.earlier(nu, among: passes).map(\.visningsPass) + [nu.visningsPass]
        }
        let utv = PassHistory.progress(passes)
        return Flikdata(
            idag: Idagvisning(idag: idag, katalog: katalog, pass: idagPass, attJobbaPa: fokus),
            utveckling: Utvecklingsvisning(katalog: katalog, pass: utv.passes.map(\.visningsPass),
                                           block: AttJobbaPa.block(filer), ovas: ovas, ejMatta: utv.unmeasured,
                                           annanLangd: utv.otherHeight),
            jobba: fokus.map { AttJobbaPaVisning($0, katalog: katalog) },
            senaste: nu?.id)
    }

    /// Passen läses, mäts med sin egen längd och flikarna räknas utanför huvudtråden (ett pass
    /// från före S4b får sina mått här); de som ändrades sparas på huvudtråden. Svarar också
    /// passen. METOD MS14, MS16
    @MainActor
    static func load(_ store: Store, katalog: Katalog, idag: Date = Date()) async -> (data: Flikdata, passes: [PassState]) {
        let ids = store.index.passes.map(\.id)
        let root = store.root
        let hojd = store.settings.heightM
        let fokus = store.focus
        let r = await Task.detached(priority: .userInitiated) { () -> (Flikdata, [PassState], [PassState]) in
            let fore = Store.reading(ids, root: root, height: hojd)
            let efter = Store.measuring(fore, root: root)
            let data = Flikdata.bygg(passes: efter, fokus: fokus, filer: Store.readingFocus(root: root), katalog: katalog, idag: idag)
            return (data, fore, efter)
        }.value
        for (a, b) in zip(r.1, r.2) where a != b && store.load(a.id) == a { store.save(b) }
        return (r.0, r.2)
    }
}

/// Appens två flikar (PLAN S4e, BESLUT B64, som ersätter B36:s tre): Sessions, förstasidan
/// med passen, och Me med längden, handen, klubborna och "Import focus". Ett pass är ett eget
/// flöde över flikarna (uppställningen, kameran, slagen). Listan läses om när passens index
/// ändras, när ett flöde stängs och när appen kommer tillbaka.
struct Flikar: View {
    @Environment(Store.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var flik = Flik.sessions
    @State private var rader: [Sessionsrad] = []
    @State private var flow: PassFlowView.Mode?
    @State private var opened: OpenPass?
    /// Passet vars radering frågas om (efter svepet).
    @State private var radera: Sessionsrad?
    /// Varför raderingen vägrades eller inte gick, i bladet.
    @State private var raderaFel: String?
    /// Räknas upp när listan ska läsas om (ett flöde stängdes, appen kom tillbaka).
    @State private var omlasning = 0
    /// Filer för `att_jobba_pa.json` (S2_SPEC §8.5).
    @State private var importingFocus = false
    /// Svaret efter hämtningen: sparad, eller felet (fältet, aldrig värdet).
    @State private var focusResult: String?
    @State private var focusFailed = false

    enum Flik: Hashable { case sessions, jag }

    struct OpenPass: Identifiable {
        let id: String
    }

    struct Nyckel: Equatable {
        let index: PassIndex
        let omlasning: Int
    }

    var body: some View {
        TabView(selection: $flik) {
            Tab("Sessions", systemImage: "list.bullet", value: Flik.sessions) {
                SessionsVy(rader: rader, tom: store.index.passes.isEmpty, problem: store.problem,
                           nytt: { flow = $0 }, oppna: { opened = OpenPass(id: $0) }, radera: { radera = $0 })
            }
            Tab("Me", systemImage: "person", value: Flik.jag) {
                ScrollView {
                    JagVy(heightM: store.settings.heightM, hand: store.settings.hand ?? .hoger, clubs: store.settings.bag,
                          onHeight: { store.setHeight($0) }, onHand: { store.setHand($0) },
                          onClub: { store.toggleClub($0) }, onImportFocus: { importingFocus = true },
                          importResult: focusResult, importFailed: focusFailed)
                }
                .background(Theme.ground, ignoresSafeAreaEdges: .all)
            }
        }
        .tint(Theme.text)
        .task(id: Nyckel(index: store.index, omlasning: omlasning)) {
            let nya = await Sessionslista.load(store)
            // En nyare läsning har startat (indexet ändrades): den här skriver inte över den.
            guard !Task.isCancelled else { return }
            rader = nya
        }
        // "Focus saved" eller felet gäller bara medan Me visas.
        .onChange(of: flik) { _, ny in
            if ny != .jag {
                focusResult = nil
                focusFailed = false
            }
        }
        .onChange(of: scenePhase) { _, fas in
            if fas == .active { omlasning += 1 }
        }
        .fullScreenCover(item: $flow, onDismiss: { omlasning += 1 }) { mode in
            PassFlowView(mode: mode) { flow = nil }
                .environment(store)
        }
        .fullScreenCover(item: $opened, onDismiss: { omlasning += 1 }) { p in
            PassShotsView(passID: p.id) { opened = nil }
                .environment(store)
        }
        // Frågan före raderingen (BESLUT B64): ett blad, så att provet kan rita den.
        // Vägras raderingen eller går den inte, står bladet kvar med felet (`Store.problem`).
        .sheet(item: $radera, onDismiss: { raderaFel = nil }) { rad in
            ScrollView {
                RaderaPassVy(rad: rad, problem: raderaFel, onDelete: {
                    store.problem = nil
                    if store.deletePass(rad.id) {
                        rader.removeAll { $0.id == rad.id }
                        radera = nil
                    } else {
                        raderaFel = store.problem ?? String(localized: "The session could not be deleted.")
                        store.problem = nil
                    }
                }, onCancel: { radera = nil })
            }
            .background(Theme.ground, ignoresSafeAreaEdges: .all)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
        .fileImporter(isPresented: $importingFocus, allowedContentTypes: [.json], allowsMultipleSelection: false) { r in
            importFocus(r)
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
