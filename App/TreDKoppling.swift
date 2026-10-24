import Foundation
import Observation
import Swing
import Capture
import TreD

/// 3D i passet (S6c-2, BESLUT B61, METOD MS19). I passets skärm, för ett pass med två
/// telefoner, startas kopplingen igen: följaren skickar sina analyserade slag (en bunt utan
/// video) till den styrande, den styrande räknar 3D med TreD utanför huvudtråden och skickar
/// `tre_d.json` tillbaka, och båda sparar samma fil. "Import other phone" ger samma bunt ur den
/// andra telefonens paket när kopplingen inte fanns; då räknar telefonen själv. Passet räknas om
/// när någon telefons slag ändrats (buntarnas summor i filen).
@MainActor
@Observable
final class TreDKoppling {
    let passID: String
    /// Passets 3D, när den finns.
    private(set) var fil: TreDFil?
    /// 3D räknas just nu.
    private(set) var raknar = false
    /// Den andra telefonens slag finns i passet.
    private(set) var harAnnan = false
    /// Importen gick inte: kort, i vyn.
    var problem: String?

    @ObservationIgnored private let store: Store
    @ObservationIgnored private(set) var link: PhoneLink?
    @ObservationIgnored private var jobb: Task<Void, Never>?
    /// Ett nytt varv behövs när det pågående är klart (passet ändrades under tiden).
    @ObservationIgnored private var igen = false
    /// Passet fick ny 3D: vyn läser om (Progress och kortet).
    @ObservationIgnored var onAndrat: (() -> Void)?
    /// Räknetiden för den senaste räkningen, s (provet, METOD M50).
    @ObservationIgnored private(set) var senasteTid: Double?

    init(passID: String, store: Store) {
        self.passID = passID
        self.store = store
        fil = store.treD(passID)
        harAnnan = store.hasOtherPhone(passID)
    }

    /// Kopplingen för ett pass med två telefoner. `link` = provets (loopback), redan startad.
    func start(link given: PhoneLink? = nil) {
        guard link == nil, let p = store.load(passID), p.setup.role != .solo else {
            uppdatera()
            return
        }
        let l = given ?? PhoneLink(role: p.setup.role, view: p.setup.view)
        if p.setup.role == .lead { l.forPass(passID) }
        l.onData = { [weak self] kind, pass, data in self?.mottaget(kind: kind, pass: pass, data: data) ?? false }
        if given == nil { l.start() }
        link = l
        // Den styrande: 3D som redan finns går till en följare som ansluter.
        if p.setup.role == .lead, let fil, let d = try? fil.data() { l.send(kind: Overforing.treD, pass: passID, data: d) }
        uppdatera()
    }

    func stop() {
        jobb?.cancel()
        jobb = nil
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
        let app = Export.appInfo(), phone = Export.phoneInfo(), device = Export.deviceInfo(p)
        let folder = store.passFolder(passID)
        jobb = Task { [weak self] in
            let egen = await Task.detached(priority: .userInitiated) {
                try? Self.egenBunt(p, folder: folder, app: app, phone: phone, device: device)
            }.value
            let annan = await Task.detached(priority: .userInitiated) { Store.otherPhoneData(folder) }.value
            guard let self else { return }
            if let egen, !Task.isCancelled { await self.vidare(p, egen: egen, annan: annan) }
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

    private func vidare(_ p: PassState, egen: (SlagBunt, Data), annan: Data?) async {
        let egenSumma = Overforing.summa(egen.1)
        // Följaren skickar sina slag när den styrandes 3D inte gäller dem.
        if p.setup.role == .follow, let link, fil?.kallor[p.setup.view.rawValue] != egenSumma {
            link.send(kind: Overforing.slag, pass: passID, data: egen.1)
        }
        guard let annan, let ab = try? SlagBunt.las(annan), ab.vy != p.setup.view else { return }
        let kallor = [p.setup.view.rawValue: egenSumma, ab.vy.rawValue: Overforing.summa(annan)]
        if fil?.galler(kallor) == true { return }
        raknar = true
        defer { raknar = false }
        let pass = passID, vy = p.setup.view, langd = p.heightM
        let ny = await Task.detached(priority: .userInitiated) { () -> (TreDFil, Double)? in
            guard let a = try? TreDIndata(egen.0), let b = try? TreDIndata(ab) else { return nil }
            let start = Date()
            let ut = TreDTelefon.rakna(a, b, langdM: langd)
            let tid = Date().timeIntervalSince(start)
            return (TreDFil(pass: pass, raknad: Date(), raknadAv: vy, kallor: kallor, sekunder: tid, ut: ut), tid)
        }.value
        guard let ny, !Task.isCancelled else { return }
        senasteTid = ny.1
        spara(ny.0)
        if p.setup.role == .lead, let link, let d = try? ny.0.data() {
            link.send(kind: Overforing.treD, pass: passID, data: d)
        }
    }

    private func spara(_ f: TreDFil) {
        guard store.saveTreD(f, passID: passID) else { return }
        fil = f
        onAndrat?()
    }

    /// En hel överföring från den andra telefonen: slagen (den styrande) eller 3D (följaren).
    /// En överföring för ett annat pass, eller som inte går att läsa, tas emot och släpps, så att
    /// den inte skickas om och om igen. false bara när sparningen misslyckades.
    private func mottaget(kind: String, pass: String, data: Data) -> Bool {
        guard pass == passID else { return true }
        switch kind {
        case Overforing.slag:
            guard let b = try? SlagBunt.las(data), b.vy != store.load(passID)?.setup.view else { return true }
            guard store.saveOtherPhone(data, passID: passID) else { return false }
            harAnnan = true
            uppdatera()
            return true
        case Overforing.treD:
            guard let f = try? TreDFil.las(data), f.pass == passID else { return true }
            guard store.saveTreD(f, passID: passID) else { return false }
            fil = f
            onAndrat?()
            return true
        default:
            return true
        }
    }

    /// "Import other phone": den andra telefonens paket ur Filer eller AirDrop, läst fil för fil
    /// utan klippen, till samma bunt; sedan räknar den här telefonen. METOD MS19
    func importera(_ url: URL) async {
        problem = nil
        let skyddad = url.startAccessingSecurityScopedResource()
        defer { if skyddad { url.stopAccessingSecurityScopedResource() } }
        let r = await Task.detached(priority: .userInitiated) { () -> Result<Data, OverforingFel> in
            do {
                return .success(try SlagBunt.ur(zip: url).data())
            } catch let e as OverforingFel {
                return .failure(e)
            } catch {
                return .failure(OverforingFel(""))
            }
        }.value
        switch r {
        case let .success(d):
            guard let b = try? SlagBunt.las(d), b.vy != store.load(passID)?.setup.view else {
                problem = String(localized: "Same view as this phone")
                return
            }
            guard store.saveOtherPhone(d, passID: passID) else { return }
            harAnnan = true
            uppdatera()
        case .failure:
            problem = String(localized: "Not a SwingLab package")
        }
    }
}
