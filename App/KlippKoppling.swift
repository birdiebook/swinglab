import AVFoundation
import Foundation
import Observation
import UIKit
import Swing
import Capture

/// Videon från båda telefonerna på den styrande (S6g, BESLUT B80, B81, METOD MS30). I passets
/// skärm delar den kopplingen med 3D (`TreDKoppling.link`, syftet "pass" och bara passets
/// partner). Den styrande begär svingarnas klipp ur parningen (`KlippBegaran`, också för ett klick
/// som följaren missade), tar emot bitarna i ordning på en egen kö och skriver dem till filen
/// (`KlippMottagare`), mäter klicket i varje klipp och sparar `video.json`. Följaren skär klippen
/// passthrough ur sina original, strömmar dem en bit i taget ur filen och behåller hela
/// inspelningen tills den styrande kvitterat att allt kommit fram. Överföringen fortsätter där den
/// slutade när kopplingen kommer tillbaka (filens storlek hos den styrande), och en kort
/// överföring hinner klart när appen läggs undan (`beginBackgroundTask`).
@MainActor
@Observable
final class KlippKoppling {
    let passID: String
    /// Den andra vyns video som kommit (den styrande).
    private(set) var video: AnnanVideo?
    /// Raden med förloppet: "Getting video from other phone · 60 %" (den styrande) eller
    /// "Sending video to other phone · 60 %" (följaren); nil = inget pågår.
    private(set) var rad: String?
    /// Den andra telefonen har samma vy som den här (BESLUT B83).
    private(set) var sammaVy = false
    /// "Get full video" är begärd och inte framme än.
    private(set) var hamtarHela = false
    /// Importen av klippen ur den andra telefonens paket gick inte: kort, i vyn.
    var problem: String?
    /// Passet fick ny video: vyn läser om.
    @ObservationIgnored var onAndrat: (() -> Void)?

    // Provet läser dessa.
    @ObservationIgnored private(set) var mottagnaBitar = 0
    @ObservationIgnored private(set) var skickadeBitar = 0
    @ObservationIgnored private(set) var mottagnaByte = 0

    @ObservationIgnored private let store: Store
    @ObservationIgnored private weak var link: PhoneLink?
    /// Filen läses och skrivs här, en bit i taget och i ordning.
    @ObservationIgnored private let ko = DispatchQueue(label: "swinglab.klipp", qos: .userInitiated)
    @ObservationIgnored private var bakgrund: UIBackgroundTaskIdentifier = .invalid

    // Den styrande.
    @ObservationIgnored private var nr = 0
    @ObservationIgnored private var begaran: KlippBegaran?
    /// Den senast skickade begärans innehåll utan förloppet (namnen och vad som är framme).
    @ObservationIgnored private var skickad: [KlippPost]?
    @ObservationIgnored private var hela = false
    /// Förloppet per klipp: hela bitar och antalet.
    @ObservationIgnored private var har: [String: Int] = [:]
    @ObservationIgnored private var antal: [String: Int] = [:]
    @ObservationIgnored private var mater: Set<String> = []

    // Följaren.
    @ObservationIgnored private var sandare = KlippSandare()
    @ObservationIgnored private var fran: KlippBegaran?
    @ObservationIgnored private var levererade: Set<String> = []
    /// Klippet som skärs eller vars summa räknas (bara ett i taget).
    @ObservationIgnored private var forbereder: String?
    /// Filen som strömmas.
    @ObservationIgnored private var kalla: URL?

    init(passID: String, store: Store) {
        self.passID = passID
        self.store = store
        video = store.annanVideo(passID)
    }

    private var pass: PassState? { store.load(passID) }

    /// Kopplingen i passets skärm (3D:s, redan startad), eller provets. Utan koppling (ett pass
    /// med en telefon) finns bara importen och det som redan kommit.
    func start(link l: PhoneLink?) {
        guard let l, let p = pass, p.setup.role != .solo else { return }
        link = l
        l.onHello = { [weak self] h in self?.hej(h) }
        l.onDown = { [weak self] in self?.nere() }
        if p.setup.role == .lead {
            l.onStream = { [weak self] dev, bit in self?.bit(dev, bit) }
        } else {
            l.onStreamAck = { [weak self] a in self?.kvittens(a) }
            l.dataHandlers[Overforing.begaran] = { [weak self] pass, d in
                await self?.begaranKom(pass, d) ?? .osparad
            }
            // Den senaste begäran från förra gången: följaren vet vad som väntar.
            fran = store.begaran(passID)
        }
        uppdatera()
    }

    func stop() {
        sandare.avbrott()
        slutaBakgrund()
        link = nil
    }

    /// Den andra telefonen sa hello: vyn prövas, och den styrande skickar sin begäran igen (den
    /// kan ha startats om och säger var varje klipp står).
    private func hej(_ h: LinkHello) {
        guard let p = pass else { return }
        sammaVy = Vyvakt.sammaVy(egen: p.setup.view, andra: [h.view])
        if p.setup.role == .lead, h.role == .follow, h.kanVideo { skickaBegaran(tvinga: true) }
    }

    private func nere() {
        guard let p = pass else { return }
        if p.setup.role == .follow {
            sandare.avbrott()
            forbereder = nil
        }
        visaRad()
        slutaBakgrund()
    }

    /// Passet ändrades (analysen, domen) eller kopplingen kom upp.
    func uppdatera() {
        guard let p = pass else { return }
        if p.setup.role == .lead {
            video = store.annanVideo(passID)
            skickaBegaran(tvinga: false)
        }
        visaRad()
    }

    // MARK: Den styrande

    private var annanVy: Vy? { pass.map { Vyvakt.annan($0.setup.view) } }

    private var mottagare: KlippMottagare? {
        annanVy.map { KlippMottagare(mapp: store.passFolder(passID), vy: $0, pass: passID) }
    }

    /// "Get full video": varje parad serie hel, som reserv (BESLUT B80).
    func hamtaHela() {
        hela = true
        hamtarHela = true
        skickaBegaran(tvinga: true)
    }

    /// Begäran ur passet och det som kommit; skickas när något ändrats, eller alltid (`tvinga`).
    private func skickaBegaran(tvinga: Bool) {
        guard let p = pass, p.setup.role == .lead, let m = mottagare, !sammaVy else { return }
        let framme = Set(video?.klipp.keys.map { $0 } ?? [])
        let utkast = KlippBegaran.make(pass: p, par: store.pairs(passID), nr: nr + 1, framme: framme, hela: hela).begaran
        guard !utkast.klipp.isEmpty else { return }
        let pagaende = m.pagaende(utkast.klipp.filter { !$0.klar }.map(\.namn))
        let b = KlippBegaran.make(pass: p, par: store.pairs(passID), nr: nr + 1, framme: framme, pagaende: pagaende,
                                  hela: hela).begaran
        let innehall = b.klipp.map { k -> KlippPost in
            var k = k
            k.harId = nil
            k.har = nil
            return k
        }
        begaran = b
        for (n, h) in pagaende { har[n] = h.har }
        if hela, b.klipp.filter({ KlippPost.arVideo($0.namn) }).allSatisfy(\.klar) { hamtarHela = false }
        visaRad()
        guard let link, link.kanVideo, tvinga || innehall != skickad else { return }
        nr += 1
        skickad = innehall
        guard let d = try? b.data() else { return }
        link.send(Overforing.dela(kind: Overforing.begaran, pass: passID, data: d))
    }

    /// En bit från följaren: skrivs på kön, i ordning, och kvitteras.
    private func bit(_ dev: String, _ p: LinkPart) {
        guard let m = mottagare, let b = begaran else { return }
        let onskade = Set(b.klipp.map(\.namn)), klara = video?.klara ?? [:]
        borjaBakgrund()
        ko.async {
            let utfall = m.taEmot(p, onskade: onskade, klara: klara)
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self.svar(dev, p, utfall) }
            }
        }
    }

    private func svar(_ dev: String, _ p: LinkPart, _ s: KlippMottagare.Svar) {
        guard let link else { return }
        switch s {
        case let .kvittera(a):
            for x in a { link.streamAck(device: dev, x) }
            if let n = p.namn, a.contains(where: { $0.ok && $0.index == p.index }) {
                mottagnaBitar += 1
                mottagnaByte += p.data.utf8.count
                har[n] = max(har[n] ?? 0, p.index + 1)
                antal[n] = p.count
            }
            visaRad()
        case let .klar(namn, fil, bytes, id, kvittens):
            link.streamAck(device: dev, kvittens)
            mottagnaBitar += 1
            mottagnaByte += p.data.utf8.count
            har[namn] = p.count
            antal[namn] = p.count
            Task { await sparaKlipp(dev: dev, namn: namn, fil: fil, bytes: bytes, id: id) }
        }
    }

    /// Ett klipp är framme: klicket mäts i det och längden läses, `video.json` sparas, och först då
    /// kvitteras helheten (BESLUT B22: kvittensen betyder sparad). METOD MS30
    private func sparaKlipp(dev: String, namn: String, fil: String, bytes: Int, id: String) async {
        guard let vy = annanVy, !mater.contains(namn) else { return }
        mater.insert(namn)
        defer { mater.remove(namn) }
        let url = store.url(fil, in: passID)
        let post = begaran?.klipp.first { $0.namn == namn }
        let langd = try? await AVURLAsset(url: url).load(.duration).seconds
        var klick: Double?
        if let post, let k = post.klick, let f = post.fran, !KlippPost.arVideo(namn) {
            let start = max(0, f)
            let iKlippet = (try? await MediaReader.clicks(url)) ?? []
            let m = ClipCheck.measure(iKlippet, expected: k - start)
            klick = m.flagged ? nil : m.time
        }
        var v = store.annanVideo(passID) ?? AnnanVideo(pass: passID, vy: vy)
        v.klipp[namn] = AnnanVideo.Klipp(fil: fil, serie: post?.serie ?? 0, fran: post?.fran.map { max(0, $0) },
                                         klick: post?.klick, klickIKlipp: klick,
                                         langd: langd.flatMap { $0.isFinite ? $0 : nil }, bytes: bytes, id: id)
        guard store.saveAnnanVideo(v, passID: passID) else { return }
        video = v
        if let m = mottagare { link?.streamAck(device: dev, m.helKvittens(namn: namn, id: id)) }
        onAndrat?()
        skickaBegaran(tvinga: false)
        if begaran?.alltFramme == true { slutaBakgrund() }
    }

    // MARK: Följaren

    /// Den styrandes begäran: sparas, sedan skärs och skickas nästa klipp.
    private func begaranKom(_ pass: String, _ d: Data) async -> Mottagning {
        guard pass == passID else { return .nej(Overforing.felPass) }
        guard let p = self.pass, let b = try? KlippBegaran.las(d), b.pass == passID else {
            return .nej(Overforing.felFormat)
        }
        guard b.vy != p.setup.view else {
            sammaVy = true
            return .nej(Overforing.felFormat)
        }
        guard store.saveBegaran(d, passID: passID) else { return .osparad }
        fran = b
        if b.alltFramme { store.rensaUtskick(passID) }
        // Varje begäran säger var den styrande står: strömmen börjar om där (dubbletter kvitteras).
        sandare.avbrott()
        forbereder = nil
        fortsatt()
        return .sparad
    }

    /// Nästa klipp: skärs passthrough ur originalet (eller hela filen för "video-NN"), summan
    /// räknas, och strömmen börjar där den styrande står.
    private func fortsatt() {
        visaRad()
        guard let link, link.kanVideo, sandare.strom == nil, forbereder == nil, let b = fran,
              let post = b.nasta(utom: levererade), let p = pass,
              let serie = p.series.first(where: { $0.nr == post.serie }) else {
            if fran?.nasta(utom: levererade) == nil { slutaBakgrund() }
            return
        }
        let original = store.url(serie.file, in: passID)
        guard FileManager.default.fileExists(atPath: original.path) else {
            // Originalet finns inte (borttaget): klippet går inte att skära. Nästa.
            levererade.insert(post.namn)
            fortsatt()
            return
        }
        forbereder = post.namn
        borjaBakgrund()
        let namn = post.namn, pid = passID
        let mal = KlippPost.arVideo(namn) ? original : store.utskick(namn, passID: passID)
        Task {
            if !KlippPost.arVideo(namn), !FileManager.default.fileExists(atPath: mal.path),
               let w = post.fonster(langd: serie.duration) {
                do {
                    try await Clips.export(original, range: w, to: mal)
                } catch {
                    try? FileManager.default.removeItem(at: mal)
                }
            }
            let r = await Task.detached(priority: .userInitiated) { () -> (String, Int)? in
                guard let n = Klippfil.storlek(mal), n > 0, let id = try? Klippfil.summa(mal) else { return nil }
                return (id, n)
            }.value
            guard self.forbereder == namn else { return }
            self.forbereder = nil
            guard let r else {
                self.levererade.insert(namn)
                self.fortsatt()
                return
            }
            self.kalla = mal
            let start = post.harId == r.0 ? (post.har ?? 0) : 0
            self.las(self.sandare.borja(namn: namn, id: r.0, bytes: r.1, fran: start), pass: pid)
        }
    }

    /// Bitarna läses ur filen på kön och skickas i ordning.
    private func las(_ index: [Int], pass: String) {
        guard !index.isEmpty, let s = sandare.strom, let url = kalla else { return }
        let namn = s.namn, id = s.id, bytes = s.bytes
        ko.async {
            let bitar = index.compactMap { try? Klippfil.bit(url, index: $0, pass: pass, namn: namn, id: id, bytes: bytes) }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard self.sandare.strom?.namn == namn, self.sandare.strom?.id == id else { return }
                    self.skickadeBitar += bitar.count
                    self.link?.sendStream(bitar)
                }
            }
        }
        visaRad()
    }

    private func kvittens(_ a: LinkPartAck) {
        switch sandare.kvittens(a) {
        case .inget:
            return
        case let .skicka(index):
            las(index, pass: passID)
        case let .klar(namn):
            levererade.insert(namn)
            if !KlippPost.arVideo(namn) { try? FileManager.default.removeItem(at: store.utskick(namn, passID: passID)) }
            kalla = nil
            fortsatt()
        case .nej:
            kalla = nil
            fran = nil
            visaRad()
            slutaBakgrund()
        }
    }

    // MARK: Raden och bakgrunden

    private func visaRad() {
        guard let p = pass else { return }
        if p.setup.role == .lead {
            guard let b = begaran, !b.alltFramme, link?.kanVideo == true || !har.isEmpty else {
                rad = nil
                return
            }
            let procent = Parstatus.procent(Parstatus.andel(b, pagaende: har, antal: antal))
            rad = link?.kanVideo == true ? Texter.hamtar(procent) : Texter.videoVantar
        } else {
            guard let b = fran, b.nasta(utom: levererade) != nil, link?.kanVideo == true else {
                rad = nil
                return
            }
            var n = 0.0
            for k in b.klipp where k.klar || levererade.contains(k.namn) { n += 1 }
            if let s = sandare.strom, !levererade.contains(s.namn) { n += sandare.andel }
            rad = Texter.skickar(Parstatus.procent(n / Double(max(1, b.klipp.count))))
        }
    }

    /// En kort överföring hinner klart när appen läggs undan (iOS ger några tiotal sekunder).
    private func borjaBakgrund() {
        guard bakgrund == .invalid else { return }
        bakgrund = UIApplication.shared.beginBackgroundTask { [weak self] in
            MainActor.assumeIsolated { self?.slutaBakgrund() }
        }
    }

    private func slutaBakgrund() {
        guard bakgrund != .invalid else { return }
        UIApplication.shared.endBackgroundTask(bakgrund)
        bakgrund = .invalid
    }

    // MARK: Reserven: den andra telefonens paket

    /// "Import other phone" (S6c-2) tar också klippen ur paketet när det skickades med klipp:
    /// varje klipp läggs under den styrandes slag med samma klick (parningen), med klicket i
    /// klippet ur paketet. Ett paket utan klipp ger inga. METOD MS31
    func importera(_ url: URL) async {
        problem = nil
        guard let p = pass, p.setup.role != .follow else { return }
        let vy = Vyvakt.annan(p.setup.view)
        let skyddad = url.startAccessingSecurityScopedResource()
        defer { if skyddad { url.stopAccessingSecurityScopedResource() } }
        let mapp = store.passFolder(passID), par = store.pairs(passID), tidigare = video ?? store.annanVideo(passID)
        let ny = await Task.detached(priority: .userInitiated) { () -> AnnanVideo? in
            try? ImportKlipp.importera(zip: url, lead: p, par: par, vy: vy, mapp: mapp, tidigare: tidigare)
        }.value
        guard let ny else { return }
        guard store.saveAnnanVideo(ny, passID: passID) else { return }
        video = ny
        onAndrat?()
        skickaBegaran(tvinga: false)
    }
}
