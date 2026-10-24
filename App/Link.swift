import CoreMedia
import Foundation
import Network
import Observation
import Swing
import Capture

// Två telefoner (S2_SPEC §7, S2g): Network.framework med Bonjour, en styrande som
// lyssnar och en eller flera följare som söker och ansluter av sig själva, igen och
// igen. Bara kommandon, klick och ping går över kopplingen (BESLUT B21, B22); vad som
// sägs och när står i SwingLabKit (LinkSession.swift) och är prövat på Linux. Här
// finns bara nätet och klockan.

/// Värdklockan, samma som filens startPTS räknas om till (Camera, S2_SPEC §7.2). METOD MS9
enum LinkClock {
    static func now() -> Double { CMClock.hostTimeClock.time.seconds }
}

/// En TCP-förbindelse med Wire-ramar. Allt sker på `queue`. Hörs inget på
/// `silence` sekunder stängs den (flygplansläge stänger inte TCP av sig själv).
final class LinkConnection: @unchecked Sendable {
    let id: Int
    private let connection: NWConnection
    private let queue: DispatchQueue
    private let answersPings: Bool
    private var reader = Wire.Reader()
    private var lastHeard = LinkClock.now()
    private var watchdog: DispatchSourceTimer?
    private var closed = false
    /// På `queue`: ett meddelande och när det kom (värdklockan).
    var onMessage: (@Sendable (LinkMessage, Double) -> Void)?
    /// På `queue`: uppe (true), eller stängd för gott (false, en gång).
    var onState: (@Sendable (Bool) -> Void)?

    /// Tystnad före stängning, s. Den styrande pingar varje sekund. METOD MS9
    static let silence = 4.0

    init(id: Int, connection: NWConnection, queue: DispatchQueue, answersPings: Bool) {
        self.id = id
        self.connection = connection
        self.queue = queue
        self.answersPings = answersPings
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.lastHeard = LinkClock.now()
                self.onState?(true)
                self.receive()
                self.startWatchdog()
            case .failed, .cancelled, .waiting:
                // .waiting: inget att nå just nu; vi försöker själva igen.
                self.close()
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    /// Bonjour-tjänsten eller adressen förbindelsen gick till.
    var endpoint: NWEndpoint { connection.endpoint }

    func send(_ m: LinkMessage) {
        var m = m
        // Pingens t0 stämplas här, när den lämnar telefonen, inte när huvudtråden skapade
        // den: väntan på kön hamnar då inte i vägen fram. Svaret bär t0 tillbaka. METOD MS9
        if case let .ping(id, _) = m { m = .ping(id: id, t0: LinkClock.now()) }
        guard let d = try? Wire.frame(m) else { return }
        connection.send(content: d, completion: .contentProcessed { [weak self] error in
            if error != nil { self?.close() }
        })
    }

    /// Stänger förbindelsen (från vilken tråd som helst).
    func cancel() {
        queue.async { self.close() }
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self, !self.closed else { return }
            if let data, !data.isEmpty {
                let t = LinkClock.now()
                self.lastHeard = t
                do {
                    for m in try self.reader.feed(data) {
                        // Följaren svarar på pingen direkt, här: t1 och t2 så nära
                        // nätet som möjligt (METOD MS9).
                        if self.answersPings, case let .ping(id, t0) = m {
                            self.send(LinkFollower.pong(id, t0: t0, t1: t, t2: LinkClock.now()))
                        }
                        self.onMessage?(m, t)
                    }
                } catch {
                    self.close()
                    return
                }
            }
            if isComplete || error != nil {
                self.close()
                return
            }
            self.receive()
        }
    }

    private func startWatchdog() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 1, repeating: 1)
        t.setEventHandler { [weak self] in
            guard let self else { return }
            if LinkClock.now() - self.lastHeard > Self.silence { self.close() }
        }
        t.resume()
        watchdog = t
    }

    private func close() {
        guard !closed else { return }
        closed = true
        watchdog?.cancel()
        watchdog = nil
        connection.cancel()
        onState?(false)
    }
}

/// Nätet: lyssnaren (styr) eller sökaren (följ), förbindelserna och återanslutningen.
/// Allt på en egen kö; händelserna lämnas till `onEvent` på den kön.
final class LinkTransport: @unchecked Sendable {
    enum Event: Sendable {
        case up(Int)
        case down(Int)
        case message(Int, LinkMessage, Double)
        case listening(UInt16)
        /// Lokalt nätverk nekat eller inte tillgängligt (true), eller åter (false).
        case blocked(Bool)
    }

    let role: LinkRole
    private let queue = DispatchQueue(label: "swinglab.link")
    private let port: UInt16?
    private let fixed: NWEndpoint?
    private let bonjour: Bool
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connections: [Int: LinkConnection] = [:]
    private var connecting = false
    private var endpoints: [NWEndpoint] = []
    /// Nästa tjänst att pröva när förra inte svarade.
    private var cursor = 0
    /// Den styrande vars hello hörts: följaren håller sig till den, så att två par i
    /// samma rum inte korsas.
    private var bound: NWEndpoint?
    private var listenerBlocked = false
    /// Förbindelserna där den styrandes hello hörts.
    private var heardHello: Set<Int> = []
    private var browserBlocked = false
    private var nextID = 1
    private var stopped = false
    private var suspendedUntil = 0.0
    var onEvent: (@Sendable (Event) -> Void)?
    /// Följaren: vilken styrande den kopplar till (syftet och passets partner, S6c-2). En annan
    /// stängs, och nästa tjänst prövas. BESLUT B61
    private let accepts: @Sendable (LinkHello) -> Bool

    /// Väntan före nästa försök, s.
    static let retry = 1.0

    init(role: LinkRole, port: UInt16?, endpoint: NWEndpoint?, bonjour: Bool,
         accepts: @escaping @Sendable (LinkHello) -> Bool = { _ in true }) {
        self.role = role
        self.port = port
        fixed = endpoint
        self.bonjour = bonjour
        self.accepts = accepts
    }

    /// TCP utan Nagle (pingen väntar inte) och med peer-to-peer, så att telefonerna
    /// hittar varandra även utan gemensamt wifi (S2_SPEC §7.1). BESLUT B21
    /// Utan Bonjour (simulatorprovet) bara loopback.
    static func parameters(loopback: Bool = false) -> NWParameters {
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        tcp.connectionTimeout = 5
        let p = NWParameters(tls: nil, tcp: tcp)
        p.includePeerToPeer = true
        p.allowLocalEndpointReuse = true
        if loopback { p.requiredInterfaceType = .loopback }
        return p
    }

    func start() {
        queue.async {
            self.stopped = false
            if self.role == .lead {
                self.listen()
                // Sökaren bara för att se om lokalt nätverk är nekat (S2_SPEC §7.4):
                // lyssnaren säger det inte alltid.
                if self.bonjour { self.search() }
            } else {
                self.search()
            }
        }
    }

    func stop() {
        queue.async {
            self.stopped = true
            self.listener?.cancel()
            self.listener = nil
            self.browser?.cancel()
            self.browser = nil
            for c in self.connections.values { c.cancel() }
        }
    }

    func send(_ m: LinkMessage, to id: Int) {
        queue.async { self.connections[id]?.send(m) }
    }

    func close(_ id: Int) {
        queue.async { self.connections[id]?.cancel() }
    }

    /// Kopplingen bort i `seconds` (simulatorprovets flygplansläge): förbindelserna
    /// stängs och ingen ny tas förrän tiden gått.
    func suspend(_ seconds: Double) {
        queue.async {
            self.suspendedUntil = LinkClock.now() + seconds
            for c in self.connections.values { c.cancel() }
            self.queue.asyncAfter(deadline: .now() + seconds + 0.05) { self.connectNext() }
        }
    }

    // MARK: Styr

    private func listen() {
        guard !stopped, listener == nil else { return }
        do {
            let p = port.flatMap { NWEndpoint.Port(rawValue: $0) } ?? .any
            let l = try NWListener(using: Self.parameters(loopback: !bonjour), on: p)
            if bonjour { l.service = NWListener.Service(name: nil, type: Wire.bonjourService) }
            l.stateUpdateHandler = { [weak self, weak l] state in
                guard let self else { return }
                switch state {
                case .ready:
                    self.setBlocked(listener: false)
                    if let n = l?.port?.rawValue { self.onEvent?(.listening(n)) }
                case .waiting:
                    self.setBlocked(listener: true)
                case .failed:
                    self.listener?.cancel()
                    self.listener = nil
                    self.queue.asyncAfter(deadline: .now() + Self.retry) { self.listen() }
                default:
                    break
                }
            }
            l.newConnectionHandler = { [weak self] c in self?.accept(c) }
            listener = l
            l.start(queue: queue)
        } catch {
            queue.asyncAfter(deadline: .now() + Self.retry) { self.listen() }
        }
    }

    private func accept(_ c: NWConnection) {
        guard !stopped, LinkClock.now() >= suspendedUntil else {
            c.cancel()
            return
        }
        adopt(c)
    }

    // MARK: Följ

    private func search() {
        if fixed != nil {
            connectNext()
            return
        }
        guard !stopped, browser == nil else { return }
        let b = NWBrowser(for: .bonjour(type: Wire.bonjourService, domain: nil), using: Self.parameters())
        b.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            self.endpoints = results.map(\.endpoint).sorted { "\($0)" < "\($1)" }
            self.connectNext()
        }
        b.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.setBlocked(browser: false)
            case .waiting:
                // Lokalt nätverk nekat (S2_SPEC §7.4).
                self.setBlocked(browser: true)
            case .failed:
                self.browser?.cancel()
                self.browser = nil
                self.queue.asyncAfter(deadline: .now() + Self.retry) { self.search() }
            default:
                break
            }
        }
        browser = b
        b.start(queue: queue)
    }

    /// Nästa försök att ansluta: till den fasta adressen (provet), till den styrande vars
    /// hello redan hörts, eller annars nästa styrande som Bonjour visar, i tur. Svarar
    /// den inte, försöker vi igen om en sekund.
    private func connectNext() {
        guard role == .follow, !stopped, !connecting, connections.isEmpty else { return }
        guard LinkClock.now() >= suspendedUntil else { return }
        let e: NWEndpoint
        if let fixed {
            e = fixed
        } else if let bound {
            // Samma tjänst (namnet) över vilket gränssnitt som helst; annars den gamla adressen.
            e = endpoints.first { Self.serviceName($0) != nil && Self.serviceName($0) == Self.serviceName(bound) } ?? bound
        } else if !endpoints.isEmpty {
            e = endpoints[cursor % endpoints.count]
        } else {
            return
        }
        connecting = true
        adopt(NWConnection(to: e, using: Self.parameters(loopback: !bonjour)))
    }

    static func serviceName(_ e: NWEndpoint) -> String? {
        if case let .service(name, _, _, _) = e { return name }
        return nil
    }

    private func setBlocked(listener: Bool? = nil, browser: Bool? = nil) {
        if let listener { listenerBlocked = listener }
        if let browser { browserBlocked = browser }
        onEvent?(.blocked(listenerBlocked || browserBlocked))
    }

    private func adopt(_ nw: NWConnection) {
        let id = nextID
        nextID += 1
        let c = LinkConnection(id: id, connection: nw, queue: queue, answersPings: role == .follow)
        connections[id] = c
        c.onMessage = { [weak self] m, t in
            guard let self else { return }
            // Följaren binder sig till den styrande som svarat med hello, när det är rätt
            // styrande (samma syfte, passets partner); en annan stängs (S6c-2).
            if self.role == .follow, case let .hello(h) = m, h.role == .lead {
                guard self.accepts(h) else {
                    self.connections[id]?.cancel()
                    return
                }
                self.heardHello.insert(id)
                if self.bound == nil { self.bound = self.connections[id]?.endpoint }
            }
            self.onEvent?(.message(id, m, t))
        }
        c.onState = { [weak self] up in
            guard let self else { return }
            if up {
                self.connecting = false
                self.onEvent?(.up(id))
                return
            }
            let varUppe = self.connections.removeValue(forKey: id) != nil
            self.connecting = false
            if varUppe { self.onEvent?(.down(id)) }
            if self.role == .follow {
                // En tjänst som inte svarade med hello: nästa i tur.
                if self.heardHello.remove(id) == nil, self.bound == nil { self.cursor += 1 }
                self.queue.asyncAfter(deadline: .now() + Self.retry) { self.connectNext() }
            }
        }
        c.start()
    }
}

/// Kopplingen som vyn ser: rollen, den andra telefonens läge, och start, stopp och
/// klick till och från SwingLabKits logik. Allt här sker på huvudtråden. Heter inte
/// `Link`, som skulle skugga SwiftUI:s.
@MainActor
@Observable
final class PhoneLink {
    /// Den andra telefonen som en etikett (BESLUT B13): vyn och läget, och hos den
    /// styrande senaste parningen (antal par och median |rest|, osäker i signalfärgen).
    struct Peer: Identifiable, Equatable {
        let id: String
        let view: Vy
        let connected: Bool
        let recording: Bool
        var pairs: Int? = nil
        var residual: Double? = nil
        var uncertain = false
    }

    let role: LinkRole
    let hello: LinkHello
    private(set) var peers: [Peer] = []
    /// Lokalt nätverk nekat (S2_SPEC §7.4).
    private(set) var blocked = false
    /// Porten som lyssnaren fick (provet ansluter dit utan Bonjour).
    private(set) var port: UInt16?

    /// Följaren: den styrande startade eller stoppade serien.
    @ObservationIgnored var onStart: ((String, Int) -> Void)?
    @ObservationIgnored var onStop: ((Int) -> Void)?
    /// Den styrande: en serie är parad.
    @ObservationIgnored var onPaired: ((PairEntry) -> Void)?
    /// En hel överföring kom (S6c-2): slagen hos den styrande, 3D hos följaren, ihopfogad utanför
    /// huvudtråden. Svaret blir kvittensen (sparad, nej med skäl, eller osparad: kommer igen).
    /// BESLUT B61, METOD MS19
    @ObservationIgnored var onData: ((String, String, Data) async -> Mottagning)?
    /// Följaren: en egen överföring är kvitterad hel.
    @ObservationIgnored var onDelivered: ((String, String) -> Void)?
    /// Följaren: den styrande sa nej till en överföring ("pass", "version", "format").
    @ObservationIgnored var onRefused: ((String, String, String) -> Void)?
    /// Den andra telefonen sa hello: dess id (passets partner, BESLUT B61).
    @ObservationIgnored var onPartner: ((String) -> Void)?
    /// Följaren: den styrande saknar bitarna (en äldre app), så slagen kan inte skickas.
    private(set) var partnerUtanDelar = false

    private let transport: LinkTransport
    @ObservationIgnored private var leader: LinkLeader?
    @ObservationIgnored private var follower: LinkFollower?
    /// Följarens enda förbindelse.
    @ObservationIgnored private var followConnection: Int?
    @ObservationIgnored private var heartbeat: Timer?
    @ObservationIgnored private var lastStatus: LinkMessage?
    /// Den styrande: passet där följarnas serier och par.json sparas.
    @ObservationIgnored private var store: Store?
    @ObservationIgnored private var passID: String?
    @ObservationIgnored private let partner: String?

    /// Hjärtslaget: en ping i sekunden till varje följare. METOD MS9
    static let heartbeatInterval = 1.0

    /// `port` och `endpoint` utan Bonjour är simulatorprovets loopback (S2_SPEC §10.2 steg 9).
    /// `mode`: inspelningen eller passets 3D (S6c-2); `partner`: passets andra telefon, när den
    /// är känd (bara den kopplas). `device`: provets andra telefon i samma process.
    init(role: LinkRole, view: Vy, mode: LinkHello.Mode = .record, partner: String? = nil, port: UInt16? = nil,
         endpoint: NWEndpoint? = nil, bonjour: Bool = true, device: String? = nil) {
        self.role = role
        let h = LinkHello(role: role, device: device ?? Self.deviceID(), model: Self.model(), app: Self.version(),
                          view: view, mode: mode)
        hello = h
        transport = LinkTransport(role: role, port: port, endpoint: endpoint, bonjour: bonjour, accepts: { l in
            l.syfte == h.syfte && (partner == nil || l.device == partner)
        })
        self.partner = partner
        if role == .lead {
            var l = LinkLeader(hello: h)
            l.partner = partner
            leader = l
        } else {
            follower = LinkFollower(hello: h)
        }
        transport.onEvent = { [weak self] e in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.handle(e) }
            }
        }
    }

    func start() {
        transport.start()
        guard role == .lead, heartbeat == nil else { return }
        heartbeat = Timer.scheduledTimer(withTimeInterval: Self.heartbeatInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.beat() }
        }
    }

    func stop() {
        heartbeat?.invalidate()
        heartbeat = nil
        transport.stop()
    }

    // MARK: Den styrande

    func startSeries(passID: String, series: Int) {
        guard leader != nil else { return }
        apply(leader?.start(passID: passID, series: series) ?? [])
        for p in leader?.connectedPeers ?? [] { burst(p) }
    }

    func stopSeries() {
        guard leader != nil else { return }
        apply(leader?.stop() ?? [])
        for p in leader?.connectedPeers ?? [] { burst(p) }
    }

    /// Den styrande: passet som parningen gäller. Följarnas serier som redan sparats
    /// (`foljare.json`) och passets egna inspelade serier läses in, så att en parning som
    /// inte hann bli klar innan vyn stängdes görs nu; par.json skrivs i passet.
    func attachLead(store: Store, pass: PassState) {
        guard leader != nil else { return }
        self.store = store
        passID = pass.id
        leader = LinkLeader(hello: hello, passID: pass.id)
        for r in store.followerRecords(pass.id) { leader?.restore(r) }
        for s in pass.series where s.source == .recording {
            apply(leader?.ownFinished(LinkSeries(record: s, series: s.nr, passID: pass.id, setup: pass.setup)) ?? [])
        }
    }

    /// Den styrandes egen serie är sparad: para med följarna.
    func ownFinished(_ s: LinkSeries) {
        apply(leader?.ownFinished(s) ?? [])
    }

    /// Den styrande i passets skärm (S6c-2): tar bara emot följarnas slag för passet.
    func forPass(_ id: String) {
        guard leader != nil else { return }
        passID = id
        leader = LinkLeader(hello: hello, passID: id)
        leader?.partner = partner
    }

    /// En stor överföring i färdiga bitar (`Overforing.dela` utanför huvudtråden, S6c-2, BESLUT
    /// B61): följaren till den styrande, den styrande till varje följare, nu och igen när
    /// kopplingen kommer tillbaka. METOD MS19
    func send(_ delar: [LinkPart]) {
        if leader != nil {
            apply(leader?.sendToFollowers(delar) ?? [])
        } else {
            apply(follower?.send(delar) ?? [])
        }
    }

    /// Telefonens id: stabilt per installation (S6c-2), så att passets partner känns igen.
    /// Ett slumptal, inget namn (BESLUT B61).
    nonisolated static func deviceID() -> String {
        let nyckel = "swinglab.telefon"
        if let id = UserDefaults.standard.string(forKey: nyckel) { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: nyckel)
        return id
    }

    /// En hel överföring: fogas ihop och prövas utanför huvudtråden, sparas av appen, och svaret
    /// går tillbaka som kvittens (METOD MS19).
    private func taEmot(kind: String, pass: String, id: String, bytes: Int, delar: [String],
                        svara: @escaping (Mottagning) -> Void) {
        let handler = onData
        Task { @MainActor in
            let d = await Task.detached(priority: .userInitiated) {
                Overforing.foga(id: id, bytes: bytes, delar: delar)
            }.value
            guard let d else { return svara(.felSumma) }
            svara(await handler?(kind, pass, d) ?? .osparad)
        }
    }

    /// Överföringar som inte kvitterats hela (provet).
    var pendingTransfers: Int { leader?.unsentParts ?? follower?.parts.count ?? 0 }

    /// Klockan mot den första följaren just nu (provet).
    var clock: ClockOffset? {
        leader?.followers.values.sorted { $0.hello.device < $1.hello.device }.first?.latestClock
    }

    /// Antalet pingprov från den första följaren (provet).
    var sampleCount: Int {
        leader?.followers.values.map(\.sampleCount).max() ?? 0
    }

    // MARK: Följaren

    /// Följarens serie är sparad: den skickas nu eller när kopplingen kommer tillbaka.
    func finished(_ s: LinkSeries) {
        apply(follower?.finished(s) ?? [])
    }

    /// Stopp för hand på följaren.
    func stoppedLocally() {
        follower?.stoppedLocally()
    }

    /// Serier som inte kvitterats av den styrande (provet).
    var unacknowledged: Int { follower?.outbox.count ?? 0 }

    /// Följarens läge till den styrande: spelar in, ledigt och trycket.
    func report(recording: Bool, freeBytes: Int64?, pressure: Pressure) {
        let m = LinkMessage.status(recording: recording, freeGB: Double(freeBytes ?? 0) / 1e9, pressure: pressure.rawValue)
        lastStatus = m
        if let c = followConnection { transport.send(m, to: c) }
    }

    /// Simulatorprovets flygplansläge.
    func suspend(_ seconds: Double) {
        transport.suspend(seconds)
    }

    // MARK: Händelserna

    private func handle(_ e: LinkTransport.Event) {
        switch e {
        case let .up(id):
            if role == .lead {
                apply(leader?.connected(peer: id) ?? [])
            } else {
                followConnection = id
                apply(follower?.connected() ?? [])
                if let s = lastStatus { transport.send(s, to: id) }
            }
        case let .down(id):
            if role == .lead {
                leader?.disconnected(peer: id)
            } else if followConnection == id {
                followConnection = nil
                follower?.disconnected()
            }
        case let .message(id, m, t):
            if role == .lead {
                apply(leader?.receive(m, from: id, at: t) ?? [])
                if case let .hello(h) = m, leader?.followers[h.device]?.peer == id {
                    burst(id)
                    onPartner?(h.device)
                }
            } else if id == followConnection {
                // Pingen har redan besvarats på nätets kö.
                if case .ping = m { break }
                apply(follower?.receive(m, at: t, now: LinkClock.now) ?? [])
                if case let .hello(h) = m, follower?.lead == h { onPartner?(h.device) }
            }
        case let .listening(p):
            port = p
        case let .blocked(b):
            blocked = b
        }
        refresh()
    }

    private func apply(_ a: [LinkLeader.Action]) {
        // En serie som inte gick att spara kvitteras inte: följaren skickar den igen.
        var osparade: Set<Int> = []
        for x in a {
            switch x {
            case let .send(peer, m):
                if case let .ack(.recorded, n) = m, osparade.contains(n) { continue }
                transport.send(m, to: peer)
            case let .received(device, kind, pass, id, bytes, delar):
                taEmot(kind: kind, pass: pass, id: id, bytes: bytes, delar: delar) { [weak self] svar in
                    guard let self else { return }
                    self.apply(self.leader?.svara(device: device, kind: kind, pass: pass, id: id, svar) ?? [])
                }
            case let .close(peer):
                transport.close(peer)
            case let .store(r):
                if let store, let passID, !store.saveFollower(r, passID: passID) { osparade.insert(r.series.series) }
            case let .paired(e):
                if let store, let passID { store.savePair(e, passID: passID, model: hello.model, view: hello.view) }
                onPaired?(e)
            }
        }
        refresh()
    }

    private func apply(_ a: [LinkFollower.Action]) {
        for x in a {
            switch x {
            case let .send(m):
                if let c = followConnection { transport.send(m, to: c) }
            case let .startRecording(p, n): onStart?(p, n)
            case let .stopRecording(n): onStop?(n)
            case let .received(kind, pass, id, bytes, delar):
                taEmot(kind: kind, pass: pass, id: id, bytes: bytes, delar: delar) { [weak self] svar in
                    guard let self else { return }
                    self.apply(self.follower?.svara(kind: kind, pass: pass, id: id, svar) ?? [])
                }
            case let .delivered(kind, pass, _):
                onDelivered?(kind, pass)
            case let .refused(kind, pass, fel):
                onRefused?(kind, pass, fel)
            }
        }
        refresh()
    }

    private func refresh() {
        let ny: [Peer]
        if let leader {
            ny = leader.followers.values.filter(\.live)
                .map { f in
                    let e = leader.latestPair(device: f.hello.device)
                    return Peer(id: f.hello.device, view: f.hello.view, connected: f.peer != nil, recording: f.recording,
                                pairs: e?.pairCount, residual: e?.medianAbsResidual, uncertain: e?.uncertain ?? false)
                }
                .sorted { ($0.view.rawValue, $0.id) < ($1.view.rawValue, $1.id) }
        } else if let follower, let l = follower.lead {
            ny = [Peer(id: l.device, view: l.view, connected: follower.isConnected, recording: false)]
            if partnerUtanDelar != !l.kanDelar { partnerUtanDelar = !l.kanDelar }
        } else {
            ny = []
        }
        if ny != peers { peers = ny }
    }

    /// 30 ping med 20 ms mellanrum, sedan parning om med de nya proven (S2_SPEC §7.2). METOD MS9
    private func burst(_ peer: Int) {
        Task { @MainActor [weak self] in
            for _ in 0..<LinkLeader.burst {
                self?.ping(peer)
                try? await Task.sleep(for: .milliseconds(Int(LinkLeader.burstInterval * 1000)))
            }
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, let a = self.leader?.pairAgain() else { return }
            self.apply(a)
        }
    }

    private func ping(_ peer: Int) {
        if let m = leader?.ping(peer: peer, now: LinkClock.now()) { transport.send(m, to: peer) }
    }

    private func beat() {
        for p in leader?.connectedPeers ?? [] { ping(p) }
    }

    // MARK: Telefonen

    /// Modellens id ("iPhone18,3"), inget namn.
    nonisolated static func model() -> String {
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return sim }
        var u = utsname()
        uname(&u)
        return withUnsafeBytes(of: &u.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    nonisolated static func version() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}
