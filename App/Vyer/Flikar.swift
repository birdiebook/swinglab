import SwiftUI
import Swing
import Capture

/// Flikarnas data som värden (S4c), ur passen på telefonen och de hämtade
/// `att_jobba_pa.json`: Idag (det senaste passet mot de tidigare med samma klubba, vy och
/// längd), Utveckling (passen med samma klubba och längd som det senaste) och Att jobba på
/// (den senaste filen). Det som övas bär accenten överallt (BESLUT B31). METOD MS16
struct Flikdata {
    var idag: Idagvisning
    var utveckling: Utvecklingsvisning
    var jobba: AttJobbaPaVisning?
    /// Det senaste passets id: Idags tryck öppnar det.
    var senaste: String?

    static func bygg(passes: [PassState], filer: [AttJobbaPa], katalog: Katalog, idag: Date = Date()) -> Flikdata {
        let fokus = filer.last
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
                                           block: AttJobbaPa.block(filer), ovas: ovas, ejMatta: utv.unmeasured),
            jobba: fokus.map { AttJobbaPaVisning($0, katalog: katalog) },
            senaste: nu?.id)
    }

    /// Passen på telefonen mätta med sin egen längd utanför huvudtråden (ett pass från före
    /// S4b får sina mått här); de som ändrades sparas. METOD MS14, MS16
    @MainActor
    static func passes(_ store: Store) async -> [PassState] {
        let alla = store.allPasses()
        let root = store.root
        let efter = await Task.detached(priority: .userInitiated) { Store.measuring(alla, root: root) }.value
        for (a, b) in zip(alla, efter) where a != b && store.load(a.id) == a { store.save(b) }
        return efter
    }

    @MainActor
    static func load(_ store: Store, katalog: Katalog) async -> Flikdata {
        let p = await passes(store)
        return bygg(passes: p, filer: FokusFiler.alla(root: store.root), katalog: katalog)
    }
}

/// Appens tre flikar (skissen, BESLUT B13): Today, Progress och Me. Ett pass är ett eget
/// flöde över flikarna (uppställningen, kameran, slagen), liksom Att jobba på. Passen och
/// "Import focus" (S2f) nås från Me → Sessions. Flikarna läses om när passens index
/// ändras, när ett flöde stängs och när appen kommer tillbaka. BESLUT B36
struct Flikar: View {
    @Environment(Store.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var data: Flikdata? = AppKatalog.katalog.map { Flikdata.bygg(passes: [], filer: [], katalog: $0) }
    @State private var flik = Flik.idag
    @State private var flow: PassFlowView.Mode?
    @State private var opened: StartView.OpenPass?
    @State private var focusOpen = false
    @State private var sessionsOpen = false
    /// Räknas upp när flikarna ska läsas om (ett flöde stängdes, appen kom tillbaka).
    @State private var omlasning = 0

    enum Flik: Hashable { case idag, utveckling, jag }

    struct Nyckel: Equatable {
        let index: PassIndex
        let omlasning: Int
    }

    var body: some View {
        TabView(selection: $flik) {
            Tab("Today", systemImage: "smallcircle.filled.circle", value: Flik.idag) {
                ScrollView { idag }
                    .background(Theme.ground, ignoresSafeAreaEdges: .all)
            }
            Tab("Progress", systemImage: "chart.xyaxis.line", value: Flik.utveckling) {
                ScrollView {
                    if let u = data?.utveckling {
                        UtvecklingVy(visning: u)
                            .id(u.matt.map(\.id).joined() + u.period)
                    }
                }
                .background(Theme.ground, ignoresSafeAreaEdges: .all)
            }
            Tab("Me", systemImage: "person", value: Flik.jag) {
                ScrollView {
                    JagVy(heightM: store.settings.heightM, hand: store.settings.hand ?? .hoger, clubs: store.settings.bag,
                          sessions: store.index.passes.count, onHeight: { store.setHeight($0) },
                          onHand: { store.setHand($0) }, onClub: { store.toggleClub($0) },
                          onSessions: { sessionsOpen = true })
                }
                .background(Theme.ground, ignoresSafeAreaEdges: .all)
            }
        }
        .tint(Theme.text)
        .task(id: Nyckel(index: store.index, omlasning: omlasning)) {
            guard let k = AppKatalog.katalog else { return }
            data = await Flikdata.load(store, katalog: k)
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
        .fullScreenCover(isPresented: $focusOpen) {
            ScrollView {
                if let j = data?.jobba {
                    AttJobbaPaVy(visning: j) { focusOpen = false }
                }
            }
            .background(Theme.ground, ignoresSafeAreaEdges: .all)
            .preferredColorScheme(.dark)
        }
        // Passen, "Import from Photos" och "Import focus" (S2f) i startvyns form.
        .sheet(isPresented: $sessionsOpen, onDismiss: { omlasning += 1 }) {
            StartView()
                .environment(store)
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder private var idag: some View {
        if let v = data?.idag {
            IdagVy(visning: v, startaPass: { flow = .record }, importera: { flow = .photos },
                   oppnaPasset: { if let id = data?.senaste { opened = StartView.OpenPass(id: id) } },
                   oppnaJobba: { if data?.jobba != nil { focusOpen = true } })
        } else {
            VStack(alignment: .leading) {
                Button("Start session") { flow = .record }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
        }
    }
}
