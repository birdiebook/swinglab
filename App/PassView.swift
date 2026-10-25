import SwiftUI
import Swing
import Capture
import TreD

/// Slagen i ett pass (S2_SPEC §9, §12 S2e): analysen med förloppet, och listan med
/// domen och en miniatyr vid träffen med de uppmätta linjerna. Formspråket är BESLUT
/// B13: ingen figur, bara linjer över bilden, tal och etiketter; signalfärgen bara för
/// varningar. Accenten (BESLUT B31) är för det som övas och används inte här: listan
/// visar slagen, inga mått.
struct PassShotsView: View {
    let passID: String
    var onClose: () -> Void

    @Environment(Store.self) private var store
    @State private var pass: PassState?
    @State private var analysis = Analysis()
    @State private var images: [String: CGImage] = [:]
    @State private var overlays: [String: ImpactOverlay] = [:]
    @State private var job: Task<Void, Never>?
    /// Slaget vars miniatyr visas stor (slag utan leder).
    @State private var enlarged: ShotID?
    /// Slaget som granskas (S4b): videon med lederna och måtten per position.
    @State private var reviewing: ShotID?
    /// Serien som öppnats i redigeraren (S2i).
    @State private var editing: SeriesID?
    /// Passets mått (S4:s Passet med riktig data), när något slag är mätt (METOD MS14).
    @State private var visning: Passvisning?
    /// Tidigare pass med samma klubba och vy som inte kom med i baslinjen (inga mått).
    @State private var unmeasured = 0
    /// 3D (S6c-2, BESLUT B61): kopplingen till den andra telefonen, räkningen och filen.
    @State private var tred: TreDKoppling?
    /// Förra passet med 3D (samma klubba, vy och längd), för kortets skillnad (METOD MK7).
    @State private var forraTreD: PassState?
    /// Figuren i 3D är öppen (S6d, BESLUT B73).
    @State private var visarFigur = false
    /// Den andra telefonens video (S6g, BESLUT B80): klippen till den styrande, och valet DTL, FO
    /// eller 3D i ett parat pass (B82). Den andra vyns mått ur dess slag (S6c-2:s bunt).
    @State private var klipp: KlippKoppling?
    @State private var parvy: Parvy?
    @State private var annanVisning: Passvisning?
    @State private var par: PairFile?
    /// Den andra telefonens slag finns i passet (B82: raden och växlingen bara för ett parat pass).
    @State private var harAnnan = false

    struct SeriesID: Identifiable {
        let id: Int
    }

    struct ShotID: Identifiable {
        let id: String
    }

    var body: some View {
        ScrollView {
            if let pass {
                PassScreenContent(pass: pass, visning: visning, images: images, overlays: overlays,
                                  analysis: AnalysisState(analysis), unmeasured: unmeasured, onClose: onClose, onAnalyze: analyze,
                                  onVerdict: setVerdict, onThumb: open, onEdit: { editing = SeriesID(id: $0) },
                                  onHeight: setHeight, sendToPC: true,
                                  claude: AnyView(ClaudeKnappar(passID: passID, onFocus: reload).environment(store)),
                                  treD: treDKort, annanTelefon: annanTelefon(pass), onFigur: figurKnapp, parad: paradLage(pass),
                                  annanVisning: annanVisning,
                                  onParvy: { parvy = $0 }, onHela: { klipp?.hamtaHela() },
                                  foljarRad: pass.setup.role == .follow ? klipp?.rad : nil,
                                  foljarSammaVy: pass.setup.role == .follow && klipp?.sammaVy == true)
                    // Medan paketet skrivs (Send to PC) väntar Analyze, domen, längden, redigeraren
                    // och granskningen, så att pass.json inte ändras under.
                    .disabled(store.exporting.contains(passID))
            }
        }
        .background(Theme.ground, ignoresSafeAreaEdges: .all)
        .preferredColorScheme(.dark)
        .task {
            reload()
            startTreD()
        }
        .onDisappear {
            job?.cancel()
            klipp?.stop()
            klipp = nil
            tred?.stop()
            tred = nil
        }
        // Listan fylls under analysen: passet efter varje sparat steg.
        .onChange(of: analysis.pass) { _, p in
            guard let p else { return }
            pass = p
            Task { await loadImages(p) }
        }
        // Redigeraren för en serie: efter Done görs seriens slag om, och miniatyrerna
        // läses om med det nya utsnittet (METOD MS13).
        .fullScreenCover(item: $editing) { e in
            ClipEditorView(passID: passID, seriesNr: e.id) {
                editing = nil
                images = [:]
                overlays = [:]
                reload()
            }
            .environment(store)
        }
        // Granskningen: tillbaka läser passet om ("Detection wrong" ändrar måtten).
        .fullScreenCover(item: $reviewing) { s in
            ShotReviewView(passID: passID, shotID: s.id, startVy: parvy?.vy) {
                reviewing = nil
                reload()
            }
            .environment(store)
        }
        // Figuren i 3D (S6d): bara på telefonen som räknade den, för passets slag som de är nu.
        .fullScreenCover(isPresented: $visarFigur) {
            if let index = tred?.figur, let pass {
                TreDFigurSkarm(passID: passID, index: index,
                               nummer: Dictionary(ShotRow.rows(pass).map { ($0.id, $0.number) }, uniquingKeysWith: { a, _ in a }),
                               vy: pass.setup.view) { visarFigur = false }
                    .environment(store)
            }
        }
        .sheet(item: $enlarged) { s in
            if let pass, let shot = pass.shots.first(where: { $0.id == s.id }) {
                ImpactLarge(pass: pass, shot: shot, overlay: overlays[s.id])
                    .environment(store)
            }
        }
    }

    private func reload() {
        guard let p = store.load(passID) else { return }
        show(p)
    }

    /// 3D i passet (S6c-2): kopplingen för ett pass med två telefoner, och räkningen när den
    /// andra telefonens slag finns. BESLUT B61
    private func startTreD() {
        guard tred == nil else { return }
        let t = TreDKoppling(passID: passID, store: store)
        t.onAndrat = { reload() }
        tred = t
        t.start()
        // Videon från den andra telefonen på samma koppling (S6g, BESLUT B80).
        let k = KlippKoppling(passID: passID, store: store)
        k.onAndrat = { reload() }
        klipp = k
        k.start(link: t.link)
    }

    /// Huvudet i ett parat pass på den styrande (S6g, BESLUT B82): DTL, FO och 3D, vad som finns
    /// och förloppet. nil för ett pass med en telefon och för följaren.
    private func paradLage(_ p: PassState) -> ParadLage? {
        // Bara när en följare faktiskt var kopplad och parades (par.json eller dess slag).
        guard p.setup.role == .lead, par != nil || harAnnan else { return nil }
        let video = klipp?.video
        let helaFinns = video.map { v in
            Set(par?.entries.map(\.follower.series) ?? []).allSatisfy { v.klipp[KlippPost.videoNamn($0)] != nil }
        } ?? false
        var annanKlipp = Set<String>()
        for s in p.shots {
            if let v = video, let e = KlippBegaran.parning(par, serie: s.series, vy: p.setup.view),
               v.kalla(slag: s, par: e) != nil { annanKlipp.insert(s.id) }
        }
        return ParadLage(egen: p.setup.view, valt: parvy ?? Parvy.av(p.setup.view),
                         franBada: Parstatus.text(pass: p, par: par, video: video), forlopp: klipp?.rad,
                         sammaVy: klipp?.sammaVy ?? false,
                         kanHamtaHela: par != nil && !helaFinns && video?.originalenBorta != true,
                         hamtarHela: klipp?.hamtarHela ?? false, annanKlipp: annanKlipp,
                         utanKlick: video?.utanKlick ?? [])
    }

    /// Den andra vyns mått i den styrandes pass: dess slag ur bunten, mätta med passets längd,
    /// utanför huvudtråden (METOD MS31).
    private func laddaAnnan(_ p: PassState) {
        guard p.setup.role == .lead else { return }
        let folder = store.passFolder(passID), ovas = store.focus?.ovas ?? []
        Task {
            let annan = await Task.detached(priority: .userInitiated) { () -> PassState? in
                guard let d = Store.otherPhoneData(folder), let b = try? SlagBunt.las(d) else { return nil }
                return try? AnnanSession.pass(b, lead: p)
            }.value
            guard let annan, annan.id == pass?.id else { return }
            annanVisning = Self.visning(annan, earlier: [], ovas: ovas)
        }
    }

    /// Passets kort "3D" när passet har 3D (BESLUT B62).
    private var treDKort: TreDKort? {
        guard let f = tred?.fil else { return nil }
        let forra = forraTreD.flatMap { p in p.treD.map { (datum: p.created, median: $0) } }
        return TreDKort(f, forra: forra, katalog: AppKatalog.katalog, aktuell: tred?.aktuell ?? true)
    }

    /// Raden "3D" i kortet när figuren finns på telefonen och gäller passets slag (S6d, B73).
    private var figurKnapp: (() -> Void)? {
        guard tred?.figurAktuell == true else { return nil }
        return { visarFigur = true }
    }

    /// "Import other phone" och följarens grå rad, för ett mätt pass med två telefoner utan 3D
    /// med tal (ingen fil, en som hoppades över eller en som inte gäller slagen nu). BESLUT B61
    private func annanTelefon(_ p: PassState) -> AnyView? {
        // Den styrande utan den andra vyns video: importen är reserven också för klippen (S6g).
        let utanVideo = p.setup.role == .lead && klipp?.video == nil
        guard let tred, p.setup.role != .solo, tred.fil?.treD == nil || !tred.aktuell || tred.status != nil || utanVideo
        else { return nil }
        let k = klipp
        return AnyView(AnnanTelefonRad(koppling: tred, efterImport: { url in await k?.importera(url) }))
    }

    /// Passet nu, och sedan dess mått: passet och de tidigare passen (samma klubba och vy)
    /// mäts med längden som gäller utanför huvudtråden, och baslinjen och "vs" tas ur dem
    /// (METOD MS14).
    private func show(_ p: PassState) {
        pass = p
        Task { await loadImages(p) }
        Task {
            let r = await PassMeasures.load(p, store: store)
            guard r.pass.id == pass?.id else { return }
            pass = r.pass
            visning = Self.visning(r.pass, earlier: r.earlier, ovas: store.focus?.ovas ?? [])
            unmeasured = r.unmeasured
            forraTreD = r.earlier.last { $0.treD != nil }
            // Slagen kan ha ändrats (analysen, domen, Detection wrong): 3D skickas eller räknas om,
            // och den styrande begär klippen (S6g).
            tred?.uppdatera()
            par = store.pairs(passID)
            harAnnan = store.hasOtherPhone(passID)
            klipp?.uppdatera()
            laddaAnnan(r.pass)
        }
    }

    /// `ovas` = felen i Att jobba på: deras kort bär accenten (BESLUT B31).
    static func visning(_ p: PassState, earlier: [PassState], ovas: Set<String> = []) -> Passvisning? {
        guard let k = AppKatalog.katalog, p.shots.contains(where: { $0.measure != nil }) else { return nil }
        return Passvisning(katalog: k, pass: earlier.map(\.visningsPass) + [p.visningsPass], ovas: ovas)
    }

    private func analyze() {
        guard !analysis.running, !store.exporting.contains(passID) else { return }
        job = Task {
            if let p = await analysis.run(passID: passID, store: store) {
                show(p)
            }
        }
    }

    /// Ett tryck på ett slag: granskningen när lederna finns, annars rutan vid träffen stor.
    private func open(_ id: String) {
        guard !analysis.running else { return }
        if pass?.shots.first(where: { $0.id == id })?.joints != nil {
            reviewing = ShotID(id: id)
        } else {
            enlarged = ShotID(id: id)
        }
    }

    private func setVerdict(_ v: SwingVerdict, _ id: String) {
        guard var p = pass, !analysis.running else { return }
        p.setVerdict(v, shot: id)
        store.save(p)
        show(p)
    }

    /// Passets egen längd: bara det här passet mäts om; Jag och andra pass rörs inte (METOD MS16).
    private func setHeight(_ h: Double) {
        guard !analysis.running else { return }
        store.setPassHeight(h, passID: passID)
        reload()
    }

    /// Miniatyrerna och linjerna för slagen som har dom; ett slag som inte går att läsa
    /// får den tomma ytan (vyn visar då bara linjerna, eller inget).
    private func loadImages(_ p: PassState) async {
        for s in p.shots where s.verdict != nil {
            if overlays[s.id] == nil, let o = ShotImages.overlay(shot: s, pass: p, store: store) { overlays[s.id] = o }
            if images[s.id] == nil, let img = try? await ShotImages.impactFrame(pass: p, shot: s, store: store) {
                images[s.id] = img
            }
        }
    }
}

/// Passets mått med de tidigare passen (METOD MS14): passet och dess kandidater (samma
/// klubba och vy, före) mäts med sin egen längd utanför huvudtråden (METOD MS16), de som
/// ändrades sparas, och de tidigare passen med samma längd som passet blir baslinjen och
/// "vs"; de med en annan längd eller utan mått räknas.
@MainActor
enum PassMeasures {
    static func load(_ p: PassState, store: Store) async -> (pass: PassState, earlier: [PassState], unmeasured: Int) {
        let kandidater = PassHistory.candidates(p, among: store.allPasses())
        let root = store.root
        let fore = [p] + kandidater
        let efter = await Task.detached(priority: .userInitiated) {
            Store.measuring(fore, root: root)
        }.value
        // Bara ett pass som inte ändrats under tiden skrivs över med sina nya mått.
        for (a, b) in zip(fore, efter) where a != b && store.load(a.id) == a { store.save(b) }
        let nu = efter[0]
        let tidigare = Array(efter.dropFirst())
        return (nu, PassHistory.earlier(nu, among: tidigare), PassHistory.unmeasured(nu, among: tidigare))
    }
}

/// Passets skärm som värden (ingen ScrollView, ingen UIKit-del), så att provet kan rita
/// den: raden överst, passets mått när något slag är mätt (S4:s Passet, BESLUT B35) med
/// längden, och slagen med analysen under. Efter Analyze står måtten överst.
struct PassScreenContent: View {
    let pass: PassState
    let visning: Passvisning?
    let images: [String: CGImage]
    let overlays: [String: ImpactOverlay]
    let analysis: AnalysisState
    /// Tidigare pass (samma klubba och vy) som inte är med i baslinjen och "vs": utan mått.
    var unmeasured = 0
    var editable = true
    var onClose: () -> Void = {}
    var onAnalyze: () -> Void = {}
    var onVerdict: (SwingVerdict, String) -> Void = { _, _ in }
    var onThumb: (String) -> Void = { _ in }
    var onEdit: (Int) -> Void = { _ in }
    var onHeight: (Double) -> Void = { _ in }
    /// "Send to PC" i raden (S2f, Export.swift); false i provets bilder, som saknar Store.
    var sendToPC = false
    /// "Ask Claude" och "Paste from Claude" (S5b-2, `ClaudeKnappar`) under passets mått, när något
    /// slag är mätt; nil i provets bilder utan Store. BESLUT B60
    var claude: AnyView? = nil
    /// Passets kort "3D" (S6c-2, BESLUT B62), när passet har 3D.
    var treD: TreDKort? = nil
    /// "Import other phone" (BESLUT B61), för ett pass med två telefoner utan 3D.
    var annanTelefon: AnyView? = nil
    /// Figuren i 3D (S6d, BESLUT B73): raden "3D" i kortet; nil = ingen figur på telefonen.
    var onFigur: (() -> Void)? = nil
    /// Ett parat pass på den styrande (S6g, BESLUT B82): växlingen DTL, FO och 3D.
    var parad: ParadLage? = nil
    /// Den andra vyns mått (ur dess slag), när valet är den vyn.
    var annanVisning: Passvisning? = nil
    var onParvy: (Parvy) -> Void = { _ in }
    var onHela: () -> Void = {}
    /// Följaren: "Sending video to other phone · 60 %" medan klippen går (S6g, BESLUT B80).
    var foljarRad: String? = nil
    /// Följaren: den andra telefonen har samma vy (BESLUT B83).
    var foljarSammaVy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Navrad(titel: Tal.dag(pass.created), hoger: {
                if sendToPC { SendToPCButton(passID: pass.id) }
            }, tillbaka: onClose)
                .disabled(analysis.running)
                .padding(.horizontal, 20)
            if let parad {
                ParadHuvud(lage: parad, onVal: onParvy, onHela: onHela)
                    .disabled(analysis.running)
            }
            if let foljarRad {
                Text(verbatim: foljarRad)
                    .typsnitt(13, siffror: true)
                    .foregroundStyle(Theme.tertiary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            if foljarSammaVy {
                Text(verbatim: Texter.sammaVyIPasset)
                    .typsnitt(13, .semibold)
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            if let parad, parad.valt == .treD {
                treDInnehall
            } else if let parad, parad.annan {
                annanInnehall(parad)
            } else {
                egetInnehall
            }
        }
    }

    /// 3D i ett parat pass: kortet (med S6d:s figur när den finns), och importen.
    @ViewBuilder private var treDInnehall: some View {
        if let treD {
            TreDKortVy(kort: treD, onFigur: onFigur)
        } else {
            Under(text: Texter.treDInte)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        if let annanTelefon {
            annanTelefon
                .disabled(analysis.running)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
    }

    /// Den andra vyn i ett parat pass: dess kort (bara dess vy, BESLUT B64), och samma svingar,
    /// som öppnas i granskningen med den vyn vald.
    @ViewBuilder private func annanInnehall(_ parad: ParadLage) -> some View {
        if let annanVisning, let vy = parad.valt.vy {
            PassetVy(visning: annanVisning, vy: vy, navrad: false)
        } else {
            Under(text: Texter.annanVantar)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        if let annanTelefon {
            annanTelefon
                .disabled(analysis.running)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        // Inga miniatyrer ur den här vyns video och inget utsnitt att redigera här (B84).
        AnnanSlagLista(pass: pass, lage: parad, onTryck: onThumb)
    }

    /// Den här telefonens vy (och passet med en telefon, och följarens).
    @ViewBuilder private var egetInnehall: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let visning {
                // Bara sessionens vy (PLAN S4e, BESLUT B64).
                PassetVy(visning: visning, vy: pass.setup.view, navrad: false)
                if let h = pass.measuredHeight {
                    HeightRow(heightM: h.heightM, assumed: h.assumed, editable: editable && !analysis.running,
                              onSet: onHeight)
                        .padding(.horizontal, 20)
                        .padding(.bottom, unmeasured > 0 ? 0 : 8)
                }
                if unmeasured > 0 {
                    Under(text: String(localized: "\(unmeasured) earlier not measured"))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
                // I ett parat pass på den styrande står 3D under sitt eget val (S6g).
                if let treD, parad == nil {
                    TreDKortVy(kort: treD, onFigur: onFigur)
                }
                if let annanTelefon, parad == nil {
                    annanTelefon
                        .disabled(analysis.running)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
                if let claude {
                    claude
                        .disabled(analysis.running)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
            }
            ShotsContent(pass: pass, images: images, overlays: overlays, analysis: analysis, editable: editable,
                         onAnalyze: onAnalyze, onVerdict: onVerdict, onThumb: onThumb, onEdit: onEdit)
                .padding(20)
        }
    }
}

/// Längden som ger skalan (METOD M2, MS14): talet i cm som på Me, "assumed" när det är
/// standarden, och ett tryck väljer Johannes längd.
struct HeightRow: View {
    let heightM: Double
    let assumed: Bool
    var editable = true
    var onSet: (Double) -> Void = { _ in }

    private var label: some View {
        HStack(spacing: 8) {
            Etikett(text: String(localized: "Height"))
            // I cm som på Me (PLAN S4h).
            Text(verbatim: "\(Int((heightM * 100).rounded())) cm")
                .typsnitt(13, siffror: true)
                .foregroundStyle(Theme.secondary)
            if assumed {
                Text("assumed")
                    .typsnitt(11, .semibold)
                    .foregroundStyle(Theme.tertiary)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 32)
    }

    var body: some View {
        if editable {
            Menu {
                Picker("Height", selection: Binding(get: { Int((heightM * 100).rounded()) },
                                                    set: { onSet(Double($0) / 100) })) {
                    ForEach(Array(ShotMeasuring.heightChoicesCm), id: \.self) { cm in
                        Text(verbatim: "\(cm) cm").tag(cm)
                    }
                }
            } label: { label }
        } else {
            label
        }
    }
}

/// Analysens läge som värden, så att provet kan rita vyn utan att köra den.
struct AnalysisState: Equatable {
    var running = false
    var shot = 0
    var shots = 0
    var fraction = 0.0
    var problem: String?

    init(running: Bool = false, shot: Int = 0, shots: Int = 0, fraction: Double = 0, problem: String? = nil) {
        self.running = running
        self.shot = shot
        self.shots = shots
        self.fraction = fraction
        self.problem = problem
    }

    @MainActor
    init(_ a: Analysis) {
        self.init(running: a.running, shot: a.shotNumber, shots: a.shotTotal, fraction: a.fraction, problem: a.problem)
    }
}

/// Innehållet: rubriken, slagen per dom, analysen och listan. Ingen ScrollView och
/// ingen UIKit-del, så att provet kan rita den med ImageRenderer.
struct ShotsContent: View {
    let pass: PassState
    let images: [String: CGImage]
    let overlays: [String: ImpactOverlay]
    let analysis: AnalysisState
    var editable = true
    var onAnalyze: () -> Void = {}
    var onVerdict: (SwingVerdict, String) -> Void = { _, _ in }
    var onThumb: (String) -> Void = { _ in }
    /// Seriens redigerare (S2i): fönstret och utsnittet.
    var onEdit: (Int) -> Void = { _ in }
    /// Analysens räkning (ms per ruta, Visions konfidens) utfälld under "Details" (PLAN S4h,
    /// BESLUT B94): felsökning, ett tryck bort.
    @State var visaDetaljer = false

    var body: some View {
        let rows = ShotRow.rows(pass)
        let n = ShotRow.counts(pass)
        let vision = ShotRow.visionDetail(pass)
        VStack(alignment: .leading, spacing: 14) {
            Skarmrubrik("Shots")
            HStack(alignment: .top, spacing: 22) {
                count(n.swing, "Swing")
                count(n.notSwing, "Not a swing")
                if n.uncertain > 0 { count(n.uncertain, "Uncertain", flag: true) }
                Spacer(minLength: 0)
            }
            if n.msPerFrame != nil || vision != nil {
                DetaljKnapp(oppen: visaDetaljer) { visaDetaljer.toggle() }
                if visaDetaljer {
                    if let ms = n.msPerFrame {
                        Under(text: String(localized: "\(ms) ms/frame"))
                    }
                    // Vad Vision såg: kandidater per ruta, observationernas konfidens och andelen
                    // rutor med en vald person (gränsen 0,6, METOD MS8).
                    if let v = vision {
                        Under(text: String(localized: "\(v.candidates) per frame · confidence \(v.median) median, \(v.max) max · person \(v.person)"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if pass.orientationSuspect {
                Text("Orientation suspect")
                    .typsnitt(15, .semibold)
                    .foregroundStyle(Theme.flag)
            }
            if analysis.running {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Shot \(analysis.shot) of \(analysis.shots)")
                        .typsnitt(15, siffror: true)
                        .foregroundStyle(Theme.secondary)
                    ProgressView(value: analysis.fraction).tint(Theme.text)
                }
            } else if ShotPlan.next(pass) != nil || (pass.shots.isEmpty && pass.clickCount > 0) {
                Button("Analyze", action: onAnalyze).buttonStyle(PrimaryButtonStyle())
            }
            if let problem = analysis.problem {
                Text(verbatim: problem)
                    .typsnitt(13, .semibold)
                    .foregroundStyle(Theme.flag)
            }
            if !pass.series.isEmpty {
                SeriesSection(series: pass.series, editable: editable && !analysis.running, onEdit: onEdit)
            }
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    ShotRowView(row: row, image: images[row.id], overlay: overlays[row.id], editable: editable,
                                onVerdict: { onVerdict($0, row.id) }, onThumb: { onThumb(row.id) })
                }
            }
        }
    }

    private func count(_ n: Int, _ label: LocalizedStringKey, flag: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            StortTal(varde: "\(n)", enhet: "", storlek: 30)
            Text(label)
                .typsnitt(13)
                .foregroundStyle(flag ? Theme.flag : Theme.secondary)
        }
    }
}

/// Serierna i passet: numret, fönstret i s och utsnittets symbol; ett tryck öppnar
/// redigeraren (S2i). B13: bara etiketten, tiden och symbolen. METOD MS13
struct SeriesSection: View {
    let series: [SeriesRecord]
    var editable = true
    var onEdit: (Int) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Etikett(text: String(localized: "Sets"))
                .padding(.bottom, 6)
            ForEach(series, id: \.nr) { s in
                Button { onEdit(s.nr) } label: {
                    HStack(spacing: 10) {
                        Text(String(localized: "Set \(s.nr)"))
                        Spacer(minLength: 8)
                        Text(verbatim: Self.window(s))
                            .monospacedDigit()
                            .foregroundStyle(Theme.secondary)
                        Image(systemName: "crop")
                            .foregroundStyle(s.activeCrop == nil ? Theme.tertiary : Theme.text)
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(RowButtonStyle())
                .disabled(!editable)
            }
        }
    }

    /// "1.2–4.6 s": fönstret som gäller.
    static func window(_ s: SeriesRecord) -> String {
        let w = s.activeWindow
        return "\(Taltext.decimal(w.start, digits: 1))–\(Taltext.decimal(w.end, digits: 1)) s"
    }
}

/// En rad: miniatyren vid träffen, numret, serien, klubban och tiden, och domen.
struct ShotRowView: View {
    let row: ShotRow
    let image: CGImage?
    let overlay: ImpactOverlay?
    var editable = true
    var onVerdict: (SwingVerdict) -> Void = { _ in }
    var onThumb: () -> Void = {}

    /// Miniatyren: stor nog att se vilken axel som är fylld; ett tryck visar den stor.
    static let thumbSize = CGSize(width: 81, height: 144)

    var body: some View {
        HStack(spacing: 14) {
            // Ett tryck på slaget öppnar granskningen (S4b), eller rutan vid träffen stor.
            if editable {
                Button(action: onThumb) { left }
                    .buttonStyle(.plain)
                    .disabled(!row.hasJoints && image == nil && overlay == nil)
            } else {
                left
            }
            Spacer(minLength: 8)
            if editable {
                Menu {
                    Button("Swing") { onVerdict(.swing) }
                    Button("Not a swing") { onVerdict(.notSwing) }
                    Button("Uncertain") { onVerdict(.uncertain) }
                } label: { verdictLabel }
            } else {
                verdictLabel
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) { Rectangle().fill(Theme.hair).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }

    private var left: some View {
        HStack(spacing: 14) {
            thumb
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "\(row.number)")
                    .typsnitt(22, .medium, siffror: true)
                    .foregroundStyle(row.detectionWrong ? Theme.tertiary : Theme.text)
                Under(text: detail)
                if row.detectionWrong {
                    Text("Detection wrong")
                        .typsnitt(13, .semibold)
                        .foregroundStyle(Theme.tertiary)
                }
            }
        }
        .contentShape(.rect)
    }

    private var thumb: some View {
        ImpactThumb(image: image, overlay: overlay)
            .frame(width: Self.thumbSize.width, height: Self.thumbSize.height)
    }

    private var detail: String {
        var delar = [String(localized: "Set \(row.series)")]
        if let c = row.club { delar.append(c) }
        delar.append(String(localized: "\(row.time) s"))
        return delar.joined(separator: Texter.skilje)
    }

    private var verdictLabel: some View {
        HStack(spacing: 6) {
            if row.changedByJohannes {
                Image(systemName: "pencil")
                    .typsnitt(13)
                    .foregroundStyle(Theme.tertiary)
                    .accessibilityHidden(true)
            }
            Text(verdictText)
                .typsnitt(15, .medium)
                .foregroundStyle(row.warning ? Theme.flag : row.verdict == .swing ? Theme.text : Theme.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private var verdictText: LocalizedStringKey {
        switch row.verdict {
        case .swing: return "Swing"
        case .notSwing: return "Not a swing"
        case .uncertain: return "Uncertain"
        case nil: return "Not analyzed"
        }
    }
}

/// Rutan vid träffen med de uppmätta linjerna (BESLUT B13: ingen figur): axellinjen,
/// höftlinjen och handlederna. Personens vänstra axel och handled är fyllda, de högra
/// ihåliga, så att vänster och höger syns med ögat (klapprovet T2: den fyllda axeln
/// sitter på armen som lyfts).
struct ImpactThumb: View {
    let image: CGImage?
    let overlay: ImpactOverlay?

    var body: some View {
        Canvas { c, s in
            c.fill(Path(CGRect(origin: .zero, size: s)), with: .color(Theme.cam))
            // Bilden ryms hel (upprätt); utan bild gäller 9 : 16.
            let aspect = image.map { CGFloat($0.width) / CGFloat(max(1, $0.height)) } ?? 9.0 / 16
            var r = CGRect(origin: .zero, size: s)
            if s.width / s.height > aspect {
                r.size.width = s.height * aspect
                r.origin.x = (s.width - r.width) / 2
            } else {
                r.size.height = s.width / aspect
                r.origin.y = (s.height - r.height) / 2
            }
            if let image { c.draw(Image(decorative: image, scale: 1), in: r) }
            guard let o = overlay else { return }
            func p(_ q: ImpactOverlay.Point) -> CGPoint {
                CGPoint(x: r.minX + CGFloat(q.x) * r.width, y: r.minY + CGFloat(q.y) * r.height)
            }
            // Linjerna och prickarna växer med bilden (miniatyren och den stora).
            let linje = max(1.5, r.width * 0.006)
            let radie = max(3.5, r.width * 0.022)
            for l in [o.shoulders, o.hips] where l.count == 2 {
                var path = Path()
                path.move(to: p(l[0]))
                path.addLine(to: p(l[1]))
                c.stroke(path, with: .color(Theme.text), lineWidth: linje)
            }
            func prick(_ q: ImpactOverlay.Point, fylld: Bool) {
                let m = p(q)
                let ring = Path(ellipseIn: CGRect(x: m.x - radie, y: m.y - radie, width: 2 * radie, height: 2 * radie))
                if fylld {
                    c.fill(ring, with: .color(Theme.text))
                } else {
                    c.fill(ring, with: .color(Theme.cam))
                    c.stroke(ring, with: .color(Theme.text), lineWidth: linje)
                }
            }
            if o.shoulders.count == 2 {
                prick(o.shoulders[0], fylld: true)      // personens vänstra
                prick(o.shoulders[1], fylld: false)
            }
            if let v = o.leftWrist { prick(v, fylld: true) }
            if let h = o.rightWrist { prick(h, fylld: false) }
        }
        .clipShape(.rect(cornerRadius: 2))
        .accessibilityHidden(true)
    }
}

/// Rutan vid träffen i full storlek, med samma linjer. Läses ur filen i högre upplösning.
struct ImpactLarge: View {
    let pass: PassState
    let shot: ShotRecord
    let overlay: ImpactOverlay?

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var image: CGImage?

    var body: some View {
        ImpactThumb(image: image, overlay: overlay)
            .ignoresSafeArea(edges: .bottom)
            .background(Theme.cam, ignoresSafeAreaEdges: .all)
            .contentShape(.rect)
            .onTapGesture { dismiss() }
            .preferredColorScheme(.dark)
            .task {
                image = try? await ShotImages.impactFrame(pass: pass, shot: shot, store: store,
                                                          maxSize: CGSize(width: 1080, height: 1920))
            }
    }
}
