import Foundation
import Observation
import Swing
import Capture
import TreD

/// 3D i passet (S6c-2, BESLUT B61, METOD MS19). I passets skärm, för ett pass med två
/// telefoner, startas kopplingen igen med syftet "pass" och bara till passets partner: följaren
/// skickar sina analyserade slag (en bunt utan video) till den styrande, den styrande räknar 3D
/// med TreD utanför huvudtråden och skickar `tre_d.json` tillbaka, och båda sparar samma fil.
/// "Import other phone" ger samma bunt ur den andra telefonens paket när kopplingen inte fanns;
/// då räknar telefonen själv, tills den styrandes fil kommer (den är facit). Passet räknas om när
/// någon telefons slag ändrats (buntarnas summor i filen). Allt tungt (bunten, summorna,
/// bitarna, läsningen och skrivningen) görs utanför huvudtråden. Tiden i simulatorn står i
/// METOD M50.
@MainActor
@Observable
final class TreDKoppling {
    /// Följarens överföring, som en grå rad i passet (METOD MS19).
    enum Skickat: Equatable {
        case vantar, skickat, annatPass, annanVersion
    }

    let passID: String
    /// Passets 3D, när den finns.
    private(set) var fil: TreDFil?
    /// Figurens index (S6d, BESLUT B72), när den här telefonen räknade figuren.
    private(set) var figur: TreDFigurIndex?
    /// 3D räknas just nu.
    private(set) var raknar = false
    /// Den andra telefonens slag finns i passet.
    private(set) var harAnnan = false
    /// Importen gick inte: kort, i vyn.
    var problem: String?
    /// Importen gick, men zippen är från ett annat pass eller en annan dag.
    private(set) var varning: String?
    private(set) var skickat: Skickat?
    /// Den här telefonens och den andra telefonens buntsummor nu (nil = inte räknade än).
    private(set) var egenSumma: String?
    private(set) var annanSumma: String?

    @ObservationIgnored private let store: Store
    @ObservationIgnored private(set) var link: PhoneLink?
    @ObservationIgnored private var jobb: Task<Void, Never>?
    @ObservationIgnored private var rakning: Task<(TreDFil, Double)?, Never>?
    /// Ett nytt varv behövs när det pågående är klart (passet ändrades under tiden).
    @ObservationIgnored private var igen = false
    /// Passet fick ny 3D: vyn läser om (Progress och kortet).
    @ObservationIgnored var onAndrat: (() -> Void)?
    /// Räknetiden för den senaste räkningen, s (provet, METOD M50).
    @ObservationIgnored private(set) var senasteTid: Double?
    /// Den egna bunten för passet som det såg ut, en gång per ändring (inte vid varje omladdning).
    @ObservationIgnored private var egen: (pass: PassState, bunt: SlagBunt, data: Data, summa: String)?
    /// Den andra telefonens bunt som den lästes.
    @ObservationIgnored private var annan: (bunt: SlagBunt, summa: String)?
    /// Summan som följaren senast skickade, och den den styrande kvitterat.
    @ObservationIgnored private var skickadSumma: String?

    init(passID: String, store: Store) {
        self.passID = passID
        self.store = store
        fil = store.treD(passID)
        figur = store.treDFigur(passID)
        harAnnan = store.hasOtherPhone(passID)
    }

    /// Figuren hör till passets 3D som den är nu (samma buntar): då visas knappen "3D".
    var figurAktuell: Bool {
        guard let fil, let figur, aktuell else { return false }
        return figur.kallor == fil.kallor && figur.pass == passID
    }

    private var vy: Vy? { store.load(passID)?.setup.view }

    /// Filen gäller passets slag som de är nu: den egna summan, och den andra telefonens när den
    /// här telefonen räknade. Okänt (summorna inte räknade än) räknas som aktuellt.
    var aktuell: Bool {
        guard let fil, let vy, let e = egenSumma else { return true }
        guard fil.kallor[vy.rawValue] == e else { return false }
        if fil.raknadAv == vy, let a = annanSumma, let av = annan?.bunt.vy { return fil.kallor[av.rawValue] == a }
        return true
    }

    /// Den grå raden för följaren (eller när den styrande saknar bitarna).
    var status: Skickat? {
        if link?.role == .follow, link?.partnerUtanDelar == true, fil?.treD == nil || !aktuell { return .annanVersion }
        return skickat
    }

    /// Kopplingen för ett pass med två telefoner. `link` = provets (loopback), redan startad.
    func start(link given: PhoneLink? = nil) {
        guard link == nil, let p = store.load(passID), p.setup.role != .solo else {
            uppdatera()
            return
        }
        let l = given ?? PhoneLink(role: p.setup.role, view: p.setup.view, mode: .pass, partner: store.partner(passID))
        if p.setup.role == .lead { l.forPass(passID) }
        l.onData = { [weak self] kind, pass, data in await self?.mottaget(kind: kind, pass: pass, data: data) ?? .osparad }
        l.onDelivered = { [weak self] kind, _ in
            if kind == Overforing.slag { self?.skickat = .skickat }
        }
        l.onRefused = { [weak self] kind, _, fel in
            guard kind == Overforing.slag else { return }
            self?.skickat = fel == Overforing.felPass ? .annatPass : .annanVersion
        }
        if given == nil { l.start() }
        link = l
        // Den styrande: sin egen 3D till en följare som ansluter (bitarna utanför huvudtråden).
        if p.setup.role == .lead, let fil, fil.raknadAv == p.setup.view { skickaTreD(fil) }
        uppdatera()
    }

    func stop() {
        jobb?.cancel()
        jobb = nil
        rakning?.cancel()
        rakning = nil
        raknar = false
        link?.stop()
        link = nil
    }

    /// Passets slag är analyserade (eller ändrade): följaren skickar sina, och den telefon som har
    /// den andra telefonens slag räknar när något ändrats.
    func uppdatera() {
        guard jobb == nil else {
            igen = true
            return
        }
        guard let p = store.load(passID), Self.analyserat(p) else { return }
        let folder = store.passFolder(passID)
        let behovEgen = egen?.pass != p
        let app = Export.appInfo(), phone = Export.phoneInfo()
        let device = behovEgen ? Export.deviceInfo(p) : nil
        let behovAnnan = annan == nil && harAnnan
        jobb = Task { [weak self] in
            if behovEgen, let device {
                let e = await Task.detached(priority: .userInitiated) { () -> (SlagBunt, Data, String)? in
                    guard let r = try? Self.egenBunt(p, folder: folder, app: app, phone: phone, device: device)
                    else { return nil }
                    return (r.0, r.1, Overforing.summa(r.1))
                }.value
                if let e { self?.egen = (p, e.0, e.1, e.2) }
            }
            if behovAnnan {
                let a = await Task.detached(priority: .userInitiated) { () -> (SlagBunt, String)? in
                    guard let d = Store.otherPhoneData(folder), let b = try? SlagBunt.las(d) else { return nil }
                    return (b, Overforing.summa(d))
                }.value
                if let a { self?.annan = a }
            }
            guard let self else { return }
            if !Task.isCancelled { await self.vidare(p) }
            self.jobb = nil
            if self.igen {
                self.igen = false
                self.uppdatera()
            }
        }
    }

    /// Passets alla slag är analyserade och något har leder.
    static func analyserat(_ p: PassState) -> Bool {
        ShotPlan.next(p) == nil && p.shots.contains { $0.joints != nil }
    }

    /// Den här telefonens bunt: samma manifest som paketet (Send to PC), enhet.json, par.json och
    /// lederna. Tiden är passets, så att samma pass ger samma bunt och summa. METOD MS19
    nonisolated static func egenBunt(_ p: PassState, folder: URL, app: PackageManifest.AppInfo,
                                     phone: PackageManifest.PhoneInfo, device: DeviceInfo) throws -> (SlagBunt, Data) {
        let fm = FileManager.default
        let manifest = PackageManifest.make(pass: p, app: app, phone: phone, created: p.created, timeZone: .current,
                                            includeClips: false,
                                            hasJoints: { s in
                                                s.joints.map { fm.fileExists(atPath: folder.appending(path: $0).path) } ?? false
                                            })
        guard !manifest.shots.isEmpty else { throw PassPackage.Error.noShots }
        let e = PassPackage.encoder()
        let slag = Dictionary(p.shots.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var leder: [String: JointSeries] = [:]
        for s in manifest.shots {
            guard let rel = slag[s.id]?.joints, let d = try? Data(contentsOf: folder.appending(path: rel)),
                  let js = try? JSONDecoder().decode(JointSeries.self, from: d) else { continue }
            leder[s.id] = js
        }
        let b = try SlagBunt.make(manifest: try e.encode(manifest), enhet: try e.encode(device),
                                  par: try? Data(contentsOf: folder.appending(path: PassPackage.pairingFile)), leder: leder)
        return (b, try b.data())
    }

    private func vidare(_ p: PassState) async {
        guard let egen, egen.pass == p else { return }
        let vy = p.setup.view
        egenSumma = egen.summa
        annanSumma = annan?.summa
        // Följaren skickar sina slag tills den styrande kvitterat just den summan; en fil som den
        // styrande räknat på dem visar att den redan har dem.
        if p.setup.role == .follow, let link, skickadSumma != egen.summa,
           !(fil?.raknadAv != vy && fil?.kallor[vy.rawValue] == egen.summa) {
            skickadSumma = egen.summa
            skickat = .vantar
            let data = egen.data, pass = passID
            let delar = await Task.detached(priority: .userInitiated) {
                Overforing.dela(kind: Overforing.slag, pass: pass, data: data)
            }.value
            link.send(delar)
        }
        guard let annan, annan.bunt.vy != vy else { return }
        let kallor = [vy.rawValue: egen.summa, annan.bunt.vy.rawValue: annan.summa]
        // En fil som den andra telefonen räknat på de här slagen är facit (den styrande); en egen
        // räknas om bara när någon bunt ändrats. Inga resultat som pendlar.
        // En egen fil utan figur (räknad före S6d) räknas om en gång, så att figuren finns (B72).
        if let fil, fil.kallor[vy.rawValue] == egen.summa,
           fil.raknadAv != vy || (fil.galler(kallor) && figur?.kallor == fil.kallor) { return }
        raknar = true
        defer { raknar = false }
        let pass = passID, langd = p.heightM, a = egen.bunt, b = annan.bunt
        let folder = store.passFolder(passID)
        // 3D och figuren (S6d) i samma räkning; figuren skrivs före tre_d.json, så att knappen
        // "3D" aldrig pekar på en figur som inte finns.
        let t = Task.detached(priority: .userInitiated) { () -> (TreDFil, Double, TreDFigurIndex?)? in
            guard let ia = try? TreDIndata(a), let ib = try? TreDIndata(b) else { return nil }
            let start = Date()
            let r = TreDTelefon.rakna(ia, ib, langdM: langd, figur: true)
            if Task.isCancelled { return nil }
            let tid = Date().timeIntervalSince(start)
            var index: TreDFigurIndex?
            if var f = r.figur {
                f.index.pass = pass
                f.index.kallor = kallor
                if Store.skrivFigur(f, folder: folder) { index = f.index }
            }
            return (TreDFil(pass: pass, raknad: Date(), raknadAv: vy, kallor: kallor, sekunder: tid, ut: r.ut), tid, index)
        }
        rakning = t
        let ny = await withTaskCancellationHandler { await t.value } onCancel: { t.cancel() }
        rakning = nil
        guard let ny, !Task.isCancelled else { return }
        senasteTid = ny.1
        guard store.saveTreD(ny.0, passID: passID) else { return }
        figur = ny.2 ?? store.treDFigur(passID)
        fil = ny.0
        onAndrat?()
        if p.setup.role == .lead { skickaTreD(ny.0) }
    }

    /// Den styrandes 3D till följarna, i bitar gjorda utanför huvudtråden.
    private func skickaTreD(_ f: TreDFil) {
        guard let link else { return }
        let pass = passID
        Task {
            let delar = await Task.detached(priority: .userInitiated) { () -> [LinkPart] in
                guard let d = try? f.data() else { return [] }
                return Overforing.dela(kind: Overforing.treD, pass: pass, data: d)
            }.value
            if !delar.isEmpty { link.send(delar) }
        }
    }

    /// En hel överföring från den andra telefonen: slagen (den styrande) eller 3D (följaren).
    /// Svaret blir kvittensen: sparad, nej med skäl (följaren slutar och visar det), eller osparad
    /// (kommer igen). Läsningen och skrivningen görs utanför huvudtråden.
    private func mottaget(kind: String, pass: String, data: Data) async -> Mottagning {
        guard pass == passID else { return .nej(Overforing.felPass) }
        guard let vy else { return .osparad }
        let folder = store.passFolder(passID)
        switch kind {
        case Overforing.slag:
            let r = await Task.detached(priority: .userInitiated) { () -> (SlagBunt, String, Bool)? in
                guard let b = try? SlagBunt.las(data), b.vy != vy else { return nil }
                return (b, Overforing.summa(data), Store.skrivAnnan(data, folder: folder))
            }.value
            guard let r else { return .nej(Overforing.felFormat) }
            guard r.2 else { return .osparad }
            annan = (r.0, r.1)
            harAnnan = true
            uppdatera()
            return .sparad
        case Overforing.treD:
            let f = await Task.detached(priority: .userInitiated) { try? TreDFil.las(data) }.value
            guard let f, f.pass == passID else { return .nej(Overforing.felFormat) }
            guard store.saveTreD(f, passID: passID) else { return .osparad }
            fil = f
            onAndrat?()
            return .sparad
        default:
            return .nej(Overforing.felFormat)
        }
    }

    /// "Import other phone": den andra telefonens paket ur Filer eller AirDrop, läst fil för fil
    /// utan klippen, till samma bunt; sedan räknar den här telefonen. En zip från ett annat pass
    /// eller en annan dag tas emot men ger en grå varning. METOD MS19
    func importera(_ url: URL) async {
        problem = nil
        varning = nil
        guard let vy else { return }
        let skyddad = url.startAccessingSecurityScopedResource()
        defer { if skyddad { url.stopAccessingSecurityScopedResource() } }
        let folder = store.passFolder(passID)
        let r = await Task.detached(priority: .userInitiated) { () -> (SlagBunt, String, Bool)? in
            guard let b = try? SlagBunt.ur(zip: url), let d = try? b.data() else { return nil }
            guard b.vy != vy else { return (b, "", false) }
            return (b, Overforing.summa(d), Store.skrivAnnan(d, folder: folder))
        }.value
        guard let r else {
            problem = String(localized: "Not a SwingLab package")
            return
        }
        guard r.0.vy != vy else {
            problem = String(localized: "Same view as this phone")
            return
        }
        guard r.2 else {
            problem = String(localized: "annan_telefon.json could not be saved.")
            return
        }
        if r.0.pass != passID {
            varning = r.0.pass.prefix(8) == passID.prefix(8) ? String(localized: "Other phone's package is from another session")
                : String(localized: "Other phone's package is from another day")
        }
        annan = (r.0, r.1)
        harAnnan = true
        uppdatera()
    }
}
