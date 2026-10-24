import Foundation
import Swing

// Vad två telefoner säger till varandra och när (S2_SPEC §7.3–7.4), utan nätverk:
// appens Link.swift lämnar in det som kom och skickar det som svaras. Därför går
// tappen att pröva på Linux. Regeln: varje telefon spelar in och sparar själv,
// kopplingen bär bara kommandon, klick och pingar, och allt som inte kvitterats
// skickas igen när kopplingen kommer tillbaka. BESLUT B22

/// Följarens sida: startar och stoppar på kommando, svarar på ping, och skickar varje
/// serie tills den styrande kvitterat den. METOD MS9, MS10
public struct LinkFollower: Sendable {
    public enum Action: Equatable, Sendable {
        case send(LinkMessage)
        case startRecording(passID: String, series: Int)
        case stopRecording(series: Int)
        /// Alla bitar av en överföring från den styrande kom (3D tillbaka, S6c-2): foga ihop
        /// dem utanför huvudtråden (`Overforing.foga`), spara, och svara med `svara`. METOD MS19
        case received(kind: String, pass: String, id: String, bytes: Int, delar: [String])
        /// En egen överföring är kvitterad hel av den styrande.
        case delivered(kind: String, pass: String, id: String)
        /// Den styrande sa nej till en egen överföring (skälet: "pass", "version", "format").
        case refused(kind: String, pass: String, fel: String)
        /// En kvittens för ett klipp som följaren strömmar (S6g, `KlippSandare`). METOD MS30
        case streamAck(LinkPartAck)
    }

    public let hello: LinkHello
    /// Den styrande telefonens serie som spelas in, nil = ingen.
    public private(set) var recording: Int?
    /// Passet som kommandona gäller.
    public private(set) var passID: String?
    /// Serierna som redan startats i passet: ett `start` som kommer igen efter ett tapp
    /// startar inte om en serie (följaren kan ha stoppats för hand under tappet).
    public private(set) var started: Set<Int> = []
    /// Serierna som inte kvitterats, efter den styrandes nummer.
    public private(set) var outbox: [Int: LinkSeries] = [:]
    /// Den styrandes pass för varje serie som startats.
    public private(set) var leadPasses: [Int: String] = [:]
    public private(set) var isConnected = false
    /// Den styrande telefonen, ur dess hello.
    public private(set) var lead: LinkHello?
    /// Följarens stora överföringar (slagen, S6c-2) och de som tas emot (3D). METOD MS19
    public private(set) var parts = PartSender()
    /// Följaren tar bara emot 3D (S6c-2, METOD MS19) och den styrandes begäran om klipp (S6g).
    var inbox = PartReceiver(tillatna: [Overforing.treD, Overforing.begaran])

    public init(hello: LinkHello) {
        self.hello = hello
    }

    /// Kopplingen är uppe: hello, sedan allt som inte kvitterats.
    public mutating func connected() -> [Action] {
        isConnected = true
        var ut: [Action] = [.send(.hello(hello))]
        for n in outbox.keys.sorted() {
            if let s = outbox[n] { ut.append(.send(.recorded(s))) }
        }
        return ut
    }

    public mutating func disconnected() {
        isConnected = false
    }

    /// En stor överföring till den styrande (slagen, S6c-2), i färdiga bitar (`Overforing.dela`):
    /// nu om kopplingen är uppe och den styrande tar bitar, och allt igen varje gång den styrande
    /// säger hello (den kan ha startats om). METOD MS19
    public mutating func send(_ delar: [LinkPart]) -> [Action] {
        let d = parts.enqueue(delar)
        return isConnected && lead?.kanDelar == true ? d.map { .send(.part($0)) } : []
    }

    /// Den styrande tar emot klippen (S6g): kopplingen är uppe och dess hello har "video1".
    public var kanVideo: Bool { isConnected && lead?.kanVideo == true }

    /// Bitar av ett klipp (S6g), lästa ur filen av appen: skickas bara när kopplingen är uppe och
    /// den styrande tar klipp. Inget sparas här: den styrandes kvittenser och begäran säger var
    /// strömmen står (`KlippSandare`). METOD MS30
    public func sendStream(_ delar: [LinkPart]) -> [Action] {
        kanVideo ? delar.map { .send(.part($0)) } : []
    }

    /// Ett nej för ett klipp till den styrande (S6g): `saknas` när originalet fattas eller klippet
    /// inte gick att skära, så att den slutar begära det. BESLUT B84
    public func refuseStream(_ a: LinkPartAck) -> [Action] {
        kanVideo ? [.send(.partAck(a))] : []
    }

    /// Svaret på en hel överföring från den styrande: kvittensen, eller inget (osparad).
    public mutating func svara(kind: String, pass: String, id: String, _ svar: Mottagning) -> [Action] {
        inbox.svara(kind: kind, pass: pass, id: id, svar).map { [.send(.partAck($0))] } ?? []
    }

    /// Svaret på en ping: t1 när den kom, t2 när svaret skickas (följarens värdklocka).
    public static func pong(_ id: Int, t0: Double, t1: Double, t2: Double) -> LinkMessage {
        .pong(id: id, t0: t0, t1: t1, t2: t2)
    }

    /// Ett meddelande från den styrande, mottaget vid t1 på följarens värdklocka.
    public mutating func receive(_ m: LinkMessage, at t1: Double, now: () -> Double) -> [Action] {
        switch m {
        case let .hello(h):
            // Bara en styrande med samma syfte (inspelningen eller passets 3D, S6c-2); appen
            // stänger förbindelsen till en annan.
            guard h.syfte == hello.syfte else { return [] }
            lead = h
            // Allt som inte kvitterats hela igen: den styrande kan ha startats om. METOD MS19
            return h.kanDelar ? parts.alla().map { .send(.part($0)) } : []
        case let .ping(id, t0):
            return [.send(Self.pong(id, t0: t0, t1: t1, t2: now()))]
        case let .start(pass, series):
            var ut: [Action] = []
            if pass != passID {
                passID = pass
                started = []
            }
            if !started.contains(series) {
                if let r = recording { ut.append(.stopRecording(series: r)) }
                started.insert(series)
                leadPasses[series] = pass
                recording = series
                ut.append(.startRecording(passID: pass, series: series))
            }
            ut.append(.send(.ack(.start, series: series)))
            return ut
        case let .stop(series):
            var ut: [Action] = []
            // Ett missat stopp och start kan komma ihop efter ett tapp: stoppet gäller
            // serien och allt före den.
            if let r = recording, r <= series {
                recording = nil
                ut.append(.stopRecording(series: r))
            }
            started.insert(series)
            ut.append(.send(.ack(.stop, series: series)))
            return ut
        case let .ack(kind, series):
            if kind == .recorded { outbox.removeValue(forKey: series) }
            return []
        case let .part(p):
            switch inbox.receive(p) {
            case let .kvittera(a):
                return a.map { .send(.partAck($0)) }
            case let .hel(kind, pass, id, bytes, delar, a):
                return a.map { .send(.partAck($0)) } + [.received(kind: kind, pass: pass, id: id, bytes: bytes, delar: delar)]
            }
        case let .partAck(a):
            // Klippen strömmas av appen (S6g): kvittensen går dit.
            if a.kind == Overforing.klipp { return [.streamAck(a)] }
            switch parts.receive(a) {
            case .inget: return []
            case let .klar(kind, pass, id): return [.delivered(kind: kind, pass: pass, id: id)]
            case let .igen(d): return d.map { .send(.part($0)) }
            case let .nekad(kind, pass, fel): return [.refused(kind: kind, pass: pass, fel: fel)]
            }
        case .pong, .recorded, .status:
            return []
        }
    }

    /// Stopp för hand på följaren (under ett tapp): inget mer att stoppa när kommandot kommer.
    public mutating func stoppedLocally() {
        recording = nil
    }

    /// Serien är sparad på följaren: den skickas nu om kopplingen är uppe, annars när
    /// den kommer tillbaka.
    public mutating func finished(_ s: LinkSeries) -> [Action] {
        var s = s
        if s.leadPass == nil { s.leadPass = leadPasses[s.series] ?? passID }
        outbox[s.series] = s
        return isConnected ? [.send(.recorded(s))] : []
    }
}

/// Ett pingprov och när det togs: vid start och under serien, efter stopp, eller före
/// första serien.
public enum PingTag: Equatable, Sendable {
    case idle
    case during(Int)
    case after(Int)
}

/// Den styrande sidan: skickar start och stopp, pingar, tar emot följarnas serier,
/// kvitterar dem och parar klicken (`ClickPairing`). Flera följare går (S2_SPEC §7.1).
/// METOD MS9, MS10
public struct LinkLeader: Sendable {
    public enum Action: Equatable, Sendable {
        case send(peer: Int, LinkMessage)
        /// En äldre förbindelse till samma telefon: stäng den.
        case close(peer: Int)
        /// Följarens serie: spara den på disken. Kommer före kvittensen, som inte ska
        /// skickas om sparningen misslyckas.
        case store(FollowerRecord)
        /// En serie är parad (ny eller ändrad): skriv par.json.
        case paired(PairEntry)
        /// Alla bitar av en överföring från en följare kom (slagen, S6c-2): foga ihop dem utanför
        /// huvudtråden (`Overforing.foga`), spara, och svara med `svara`. METOD MS19
        case received(device: String, kind: String, pass: String, id: String, bytes: Int, delar: [String])
        /// En bit av ett klipp från en följare (S6g): appen skriver den till filen
        /// (`KlippMottagare`) och svarar med `streamAck`. METOD MS30
        case stream(device: String, LinkPart)
        /// Följarens nej för ett klipp (`saknas`, S6g): appen slutar begära det. BESLUT B84
        case streamRefused(device: String, LinkPartAck)
    }

    public enum Command: Equatable, Sendable {
        case idle
        case recording(passID: String, series: Int)
        case stopped(passID: String, series: Int)
    }

    /// En följare, känd på sin id även när den ansluter igen.
    public struct Follower: Equatable, Sendable {
        public var hello: LinkHello
        /// Förbindelsen, nil = tappad.
        public var peer: Int?
        /// Har sagt hello i den här kopplingen (inte bara läst från disken).
        public var live = false
        /// Ur följarens senaste status.
        public var recording: Bool = false
        public var freeGB: Double?
        public var pressure: String?
        /// Senaste kvitterade start och stopp.
        public var ackedStart: Int?
        public var ackedStop: Int?
        var samples: [(tag: PingTag, sample: PingSample)] = []
        /// Antalet prov när serie n startade.
        var startIndex: [Int: Int] = [:]
        var series: [Int: LinkSeries] = [:]
        /// Proven som sparades med serien (FollowerRecord), för en serie läst från disken.
        var saved: [Int: (before: [PingSample], after: [PingSample])] = [:]

        public init(hello: LinkHello, peer: Int?) {
            self.hello = hello
            self.peer = peer
        }

        public static func == (a: Follower, b: Follower) -> Bool {
            a.hello == b.hello && a.peer == b.peer && a.live == b.live && a.recording == b.recording
                && a.ackedStart == b.ackedStart
                && a.ackedStop == b.ackedStop && a.samples.count == b.samples.count && a.series == b.series
        }

        /// Antalet pingprov hittills.
        public var sampleCount: Int { samples.count }

        /// Klockan ur proven före serien (vid start och under), eller ur de sista före
        /// starten när inga togs under. METOD MS9
        public func before(_ n: Int) -> [PingSample] {
            let under = samples.filter { $0.tag == .during(n) }.map(\.sample)
            if !under.isEmpty { return under }
            let slut = startIndex[n] ?? samples.count
            return samples.prefix(slut).suffix(LinkLeader.burst).map(\.sample)
        }

        /// Proven vid start och under serien. METOD MS9
        public func during(_ n: Int) -> [PingSample] {
            samples.filter { $0.tag == .during(n) }.map(\.sample)
        }

        /// Klockans prov för serien: efter stoppet, annars de som sparades med serien,
        /// annars under serien, annars de sista före. METOD MS9
        public func clockSamples(_ n: Int) -> (before: [PingSample], after: [PingSample]) {
            let s = saved[n]
            let efter = after(n).isEmpty ? (s?.after ?? []) : after(n)
            var fore = during(n)
            if fore.isEmpty, let sb = s?.before, !sb.isEmpty { fore = sb }
            if fore.isEmpty { fore = before(n) }
            return (fore, efter)
        }

        /// Proven efter stoppet. METOD MS9
        public func after(_ n: Int) -> [PingSample] {
            samples.filter { $0.tag == .after(n) }.map(\.sample)
        }

        /// Klockan nu: de senaste proven. nil utan prov.
        public var latestClock: ClockOffset? {
            ClockSync.estimate(samples.suffix(LinkLeader.burst).map(\.sample))
        }
    }

    /// Pingar per skur och mellanrummet, s (S2_SPEC §7.2). METOD MS9
    public static let burst = 30
    public static let burstInterval = 0.02

    public let hello: LinkHello
    public private(set) var command: Command = .idle
    /// Passet som den styrande spelar in i. En serie från ett annat pass tas inte emot.
    public private(set) var passID: String?
    /// Följarna efter id.
    public private(set) var followers: [String: Follower] = [:]
    var peerDevice: [Int: String] = [:]
    var pending: [Int: (peer: Int, tag: PingTag)] = [:]
    var nextPing = 1
    /// Överföringarna som varje följare kvitterat hela (följare → slag → id).
    var sent: [String: [String: String]] = [:]
    /// Den styrande telefonens egna serier.
    public private(set) var own: [Int: LinkSeries] = [:]
    /// Senaste parningen per följare och serie.
    public private(set) var pairs: [String: [Int: PairEntry]] = [:]
    /// Överföringarna till följarna (3D, S6c-2), per följare, och det som ska till varje
    /// följare som säger hello senare. METOD MS19
    public private(set) var senders: [String: PartSender] = [:]
    var inboxes: [String: PartReceiver] = [:]
    var broadcast: [String: [LinkPart]] = [:]
    /// Följaren som passet parades med vid inspelningen (S6c-2, BESLUT B61): bara den tas emot.
    /// nil = vilken som helst (ett pass från före S6c-2).
    public var partner: String?
    /// Följare vars överföring tas emot samtidigt (minnet, METOD MS19).
    public static let maxMottagare = 4

    public init(hello: LinkHello, passID: String? = nil) {
        self.hello = hello
        self.passID = passID
    }

    /// En följares serie som sparats på disken (efter att vyn stängts eller appen startats
    /// om): den paras när den styrandes egen serie finns.
    public mutating func restore(_ r: FollowerRecord) {
        var f = followers[r.hello.device] ?? Follower(hello: r.hello, peer: nil)
        f.series[r.series.series] = r.series
        f.saved[r.series.series] = (before: r.before, after: r.after)
        followers[r.hello.device] = f
    }

    /// Den senaste parningen med följaren (högsta serien), eller nil.
    public func latestPair(device: String) -> PairEntry? {
        pairs[device]?.max { $0.key < $1.key }?.value
    }

    /// Följarna med en förbindelse.
    public var connectedPeers: [Int] { peerDevice.keys.sorted() }

    public func follower(peer: Int) -> Follower? {
        peerDevice[peer].flatMap { followers[$0] }
    }

    /// En ny förbindelse: hello. Följaren känns igen först på sitt hello.
    public mutating func connected(peer: Int) -> [Action] {
        [.send(peer: peer, .hello(hello))]
    }

    public mutating func disconnected(peer: Int) {
        guard let id = peerDevice.removeValue(forKey: peer) else { return }
        if followers[id]?.peer == peer { followers[id]?.peer = nil }
        pending = pending.filter { $0.value.peer != peer }
    }

    /// Ett meddelande från förbindelsen `peer`, mottaget vid t3 på den styrandes värdklocka.
    public mutating func receive(_ m: LinkMessage, from peer: Int, at t3: Double) -> [Action] {
        switch m {
        case let .hello(h):
            guard h.role == .follow else { return [] }
            // En följare med ett annat syfte (inspelningen mot passets 3D) eller en annan telefon
            // än passets partner kopplas bort (S6c-2, BESLUT B61).
            guard h.syfte == hello.syfte, partner == nil || partner == h.device else { return [.close(peer: peer)] }
            var ut: [Action] = []
            if let gammal = followers[h.device]?.peer, gammal != peer {
                peerDevice.removeValue(forKey: gammal)
                ut.append(.close(peer: gammal))
            }
            var f = followers[h.device] ?? Follower(hello: h, peer: peer)
            f.hello = h
            f.peer = peer
            f.live = true
            followers[h.device] = f
            peerDevice[peer] = h.device
            // Kommandot som gäller nu: ett start eller stopp som tappades når fram nu.
            switch command {
            case .idle: break
            case let .recording(p, n): ut.append(.send(peer: peer, .start(passID: p, series: n)))
            case let .stopped(_, n): ut.append(.send(peer: peer, .stop(series: n)))
            }
            // Överföringarna som inte kvitterats hela, igen från början (följaren kan ha startats
            // om), och de som gjordes innan följaren kom. METOD MS19
            guard h.kanDelar else { return ut }
            var sender = senders[h.device] ?? PartSender()
            // Begäran om klipp skickas inte igen härifrån: appen skickar en ny med högre `nr` när
            // följaren säger hello, så att en gammal aldrig kommer efter en ny (S6g, BESLUT B84).
            sender.pagaende[Overforing.begaran] = nil
            for k in broadcast.keys.sorted() where k != Overforing.begaran {
                guard let d = broadcast[k], let id = d.first?.id, sender.pagaende[k] == nil, sent[h.device]?[k] != id
                else { continue }
                _ = sender.enqueue(d)
            }
            ut += sender.alla().map { .send(peer: peer, .part($0)) }
            senders[h.device] = sender
            return ut
        case let .pong(id, t0, t1, t2):
            // t0 stämplas när pingen lämnar telefonen (App, nätets kö) och kommer tillbaka i svaret.
            guard let p = pending.removeValue(forKey: id), p.peer == peer, t0.isFinite,
                  let dev = peerDevice[peer] else { return [] }
            followers[dev]?.samples.append((tag: p.tag, sample: PingSample(t0: t0, t1: t1, t2: t2, t3: t3)))
            return []
        case let .status(recording, freeGB, pressure):
            guard let dev = peerDevice[peer] else { return [] }
            followers[dev]?.recording = recording
            followers[dev]?.freeGB = freeGB
            followers[dev]?.pressure = pressure
            return []
        case let .ack(kind, series):
            guard let dev = peerDevice[peer] else { return [] }
            switch kind {
            case .start: followers[dev]?.ackedStart = series
            case .stop: followers[dev]?.ackedStop = series
            case .recorded: break
            }
            return []
        case let .part(p):
            guard let dev = peerDevice[peer] else { return [] }
            // En överföring för ett annat pass får ett nej, så att följaren slutar och visar det.
            if let mitt = passID, mitt != p.pass {
                return [.send(peer: peer, .partAck(LinkPartAck(kind: p.kind, pass: p.pass, id: p.id, index: nil, ok: false,
                                                               fel: Overforing.felPass)))]
            }
            // Klippen strömmas till filen av appen (S6g), bara från en följare som har "video1".
            if p.kind == Overforing.klipp {
                return followers[dev]?.hello.kanVideo == true ? [.stream(device: dev, p)] : []
            }
            guard inboxes[dev] != nil || inboxes.count < Self.maxMottagare else { return [] }
            // Den styrande tar bara emot följarens slag (S6c-2).
            var inbox = inboxes[dev] ?? PartReceiver(tillatna: [Overforing.slag])
            let r = inbox.receive(p)
            inboxes[dev] = inbox
            switch r {
            case let .kvittera(a):
                return a.map { .send(peer: peer, .partAck($0)) }
            case let .hel(kind, pass, id, bytes, delar, a):
                return a.map { .send(peer: peer, .partAck($0)) }
                    + [.received(device: dev, kind: kind, pass: pass, id: id, bytes: bytes, delar: delar)]
            }
        case let .partAck(a):
            // Följarens nej för ett klipp (S6g) går till appen.
            if a.kind == Overforing.klipp {
                guard let dev = peerDevice[peer], followers[dev]?.hello.kanVideo == true, !a.ok else { return [] }
                return [.streamRefused(device: dev, a)]
            }
            guard let dev = peerDevice[peer], var sender = senders[dev] else { return [] }
            let r = sender.receive(a)
            senders[dev] = sender
            switch r {
            case .inget, .nekad: return []
            case let .klar(kind, _, id):
                sent[dev, default: [:]][kind] = id
                return []
            case let .igen(d): return d.map { .send(peer: peer, .part($0)) }
            }
        case let .recorded(s):
            guard let dev = peerDevice[peer], var f = followers[dev] else { return [] }
            // En serie från ett annat pass: inte här, och ingen kvittens (följaren skickar
            // den igen till rätt pass).
            if let mitt = passID, let dess = s.leadPass, mitt != dess { return [] }
            let prov = f.clockSamples(s.series)
            f.series[s.series] = s
            f.saved[s.series] = prov
            followers[dev] = f
            var ut: [Action] = [.store(FollowerRecord(hello: f.hello, series: s, before: prov.before, after: prov.after)),
                                .send(peer: peer, .ack(.recorded, series: s.series))]
            if let a = pair(dev, s.series) { ut.append(a) }
            return ut
        case .ping, .start, .stop:
            return []
        }
    }

    /// En stor överföring till varje följare (3D tillbaka, S6c-2), i färdiga bitar: nu till dem
    /// som är uppkopplade och tar bitar, och till en följare som säger hello senare. METOD MS19
    public mutating func sendToFollowers(_ delar: [LinkPart]) -> [Action] {
        guard let kind = delar.first?.kind else { return [] }
        broadcast[kind] = delar
        var ut: [Action] = []
        for dev in followers.keys.sorted() {
            guard followers[dev]?.hello.kanDelar == true, sent[dev]?[kind] != delar.first?.id else { continue }
            var sender = senders[dev] ?? PartSender()
            let d = sender.enqueue(delar)
            senders[dev] = sender
            if let peer = followers[dev]?.peer { ut += d.map { .send(peer: peer, .part($0)) } }
        }
        return ut
    }

    /// Svaret på en hel överföring från en följare: kvittensen till den, eller inget (osparad).
    public mutating func svara(device: String, kind: String, pass: String, id: String, _ svar: Mottagning) -> [Action] {
        guard let a = inboxes[device]?.svara(kind: kind, pass: pass, id: id, svar),
              let peer = followers[device]?.peer else { return [] }
        return [.send(peer: peer, .partAck(a))]
    }

    /// En kvittens för ett klipp till följaren (S6g), eller inget när den inte är uppkopplad.
    public func streamAck(device: String, _ a: LinkPartAck) -> [Action] {
        guard let peer = followers[device]?.peer else { return [] }
        return [.send(peer: peer, .partAck(a))]
    }

    /// Överföringar till följarna som inte kvitterats hela.
    public var unsentParts: Int { senders.values.map(\.count).reduce(0, +) }

    /// Start på den styrande: till alla följare.
    public mutating func start(passID: String, series: Int) -> [Action] {
        command = .recording(passID: passID, series: series)
        self.passID = passID
        for k in Array(followers.keys) {
            guard var f = followers[k] else { continue }
            f.startIndex[series] = f.samples.count
            followers[k] = f
        }
        return connectedPeers.map { .send(peer: $0, .start(passID: passID, series: series)) }
    }

    /// Stopp på den styrande: till alla följare. Tom när inget spelas in.
    public mutating func stop() -> [Action] {
        guard case let .recording(p, n) = command else { return [] }
        command = .stopped(passID: p, series: n)
        return connectedPeers.map { .send(peer: $0, .stop(series: n)) }
    }

    /// En ping till förbindelsen, stämplad med t0 = nu. nil för en okänd förbindelse.
    public mutating func ping(peer: Int, now t0: Double) -> LinkMessage? {
        guard peerDevice[peer] != nil else { return nil }
        let id = nextPing
        nextPing += 1
        let tag: PingTag
        switch command {
        case .idle: tag = .idle
        case let .recording(_, n): tag = .during(n)
        case let .stopped(_, n): tag = .after(n)
        }
        pending[id] = (peer: peer, tag: tag)
        if pending.count > 4 * Self.burst {                 // svar som aldrig kom
            pending = pending.filter { $0.key > id - 2 * Self.burst }
        }
        return .ping(id: id, t0: t0)
    }

    /// Den styrande telefonens egen serie är sparad: para med följarna som skickat sin.
    public mutating func ownFinished(_ s: LinkSeries) -> [Action] {
        own[s.series] = s
        return followers.keys.sorted().compactMap { pair($0, s.series) }
    }

    /// Para om allt som går, efter en pingskur: svarar bara det som ändrats.
    public mutating func pairAgain() -> [Action] {
        var ut: [Action] = []
        for dev in followers.keys.sorted() {
            for n in (followers[dev]?.series.keys.sorted() ?? []) {
                if let a = pair(dev, n) { ut.append(a) }
            }
        }
        return ut
    }

    private mutating func pair(_ dev: String, _ n: Int) -> Action? {
        guard let a = own[n], let f = followers[dev], let b = f.series[n] else { return nil }
        let prov = f.clockSamples(n)
        let e = PairEntry.make(lead: a, follower: b, followerModel: f.hello.model, before: prov.before,
                               after: prov.after)
        guard pairs[dev]?[n] != e else { return nil }
        pairs[dev, default: [:]][n] = e
        return .paired(e)
    }
}

/// En serie parad mellan den styrande och en följare: raden i par.json (S2_SPEC §7.3,
/// §8.3). Förskjutningen är följarens filtid − den styrandes för samma klick.
/// METOD MS9, MS10, MS6
public struct PairEntry: Codable, Equatable, Sendable {
    /// Följaren i den här serien.
    public struct FollowerPart: Codable, Equatable, Sendable {
        public var model: String
        public var view: Vy
        public var distance: Double
        public var passID: String
        public var series: Int
        public var startHost: Double?
        public var frameRate: Double
        public var clicks: Int

        public init(model: String, view: Vy, distance: Double, passID: String, series: Int, startHost: Double?,
                    frameRate: Double, clicks: Int) {
            self.model = model
            self.view = view
            self.distance = distance
            self.passID = passID
            self.series = series
            self.startHost = startHost
            self.frameRate = frameRate
            self.clicks = clicks
        }

        enum CodingKeys: String, CodingKey {
            case model = "modell", view = "vy", distance = "avstand_m", passID = "pass", series = "serie",
                 startHost = "start_vard_s", frameRate = "hz", clicks = "klick"
        }
    }

    /// Klockans prov ("efter" stopp, "fore" = vid start och under, "ingen").
    public enum ClockSource: String, Codable, Sendable {
        case after = "efter", before = "fore", none = "ingen"
    }

    /// Den styrande telefonens serie.
    public var series: Int
    public var leadStartHost: Double?
    public var leadDistance: Double
    public var leadClicks: Int
    public var follower: FollowerPart
    public var clock: ClockOffset?
    public var clockSource: ClockSource
    /// Sökningens mitt och halva bredd, s (nil = utan ping, ± 10 s).
    public var prior: Double?
    public var window: Double
    public var pairing: ClickPairing
    /// Klickens förskjutning, s: följarens filtid = den styrandes + offset.
    public var offset: Double
    /// Träffens förskjutning, s: offset − (följarens avstånd − den styrandes) / 343. METOD MS6
    public var hitOffset: Double
    public var pairCount: Int
    /// Klick som inte parades, hos den styrande och hos följaren (resten).
    public var unpairedLead: Int
    public var unpairedFollower: Int
    /// Median |rest|, s: kvaliteten (Klart när: under 5 ms).
    public var medianAbsResidual: Double?
    public var uncertain: Bool

    enum CodingKeys: String, CodingKey {
        case series = "serie", leadStartHost = "styr_start_vard_s", leadDistance = "styr_avstand_m",
             leadClicks = "styr_klick", follower = "foljare", clock = "klocka", clockSource = "klocka_ur",
             prior = "prior_s", window = "fonster_s", pairing = "parning", offset = "forskjutning_s",
             hitOffset = "traff_forskjutning_s", pairCount = "antal_par", unpairedLead = "oparade_styr",
             unpairedFollower = "oparade_folj", medianAbsResidual = "median_rest_s", uncertain = "osaker"
    }

    /// Sökfönstret med ping efter stopp, och med bara pingen före (S2_SPEC §7.4). METOD MS10
    public static let windowAfter = ClickPairing.defaultPriorWindow
    public static let windowBeforeOnly = 0.5

    /// Parar serien. Klockan tas ur proven efter stopp, annars ur proven före; prior är
    /// den förskjutning klockan och filernas start ger: b = a + SL − SF + θ, där θ =
    /// följarens klocka − den styrandes. Utan klocka eller starttid söks ± 10 s. METOD MS10
    public static func make(lead a: LinkSeries, follower b: LinkSeries, followerModel: String,
                            before: [PingSample], after: [PingSample]) -> PairEntry {
        let efter = ClockSync.estimate(after)
        let fore = ClockSync.estimate(before)
        let klocka = efter ?? fore
        let kalla: ClockSource = efter != nil ? .after : (fore != nil ? .before : .none)
        var prior: Double?
        if let k = klocka, let sl = a.startHost, let sf = b.startHost {
            let p = sl - sf + k.offset
            prior = p.isFinite ? p : nil
        }
        let fonster = prior == nil ? ClickPairing.defaultSearch : (efter != nil ? windowAfter : windowBeforeOnly)
        let ta = a.clicks.map(\.time), tb = b.clicks.map(\.time)
        let p = ClickPairing.pair(ta, tb, prior: prior, priorWindow: fonster)
        let traff = p.offset - (ClickPairing.soundDelay(distance: b.distance) - ClickPairing.soundDelay(distance: a.distance))
        let follower = FollowerPart(model: followerModel, view: b.view, distance: b.distance, passID: b.passID,
                                    series: b.localSeries, startHost: b.startHost, frameRate: b.frameRate,
                                    clicks: tb.count)
        return PairEntry(series: a.series, leadStartHost: a.startHost, leadDistance: a.distance, leadClicks: ta.count,
                         follower: follower, clock: klocka, clockSource: kalla, prior: prior, window: fonster,
                         pairing: p, offset: p.offset, hitOffset: traff, pairCount: p.pairs.count,
                         unpairedLead: ta.count - Set(p.pairs.map(\.a)).count,
                         unpairedFollower: tb.count - Set(p.pairs.map(\.b)).count,
                         medianAbsResidual: p.medianAbsResidual, uncertain: p.uncertain)
    }
}

/// `par.json` i den styrande telefonens pass: en rad per serie och följare
/// (docs/FORMAT.md "Två telefoner"). Skrivs om varje gång en parning blir klar.
public struct PairFile: Codable, Equatable, Sendable {
    public static let formatName = "swinglab-par/1"

    public var format: String
    public var pass: String
    public var model: String
    public var view: Vy
    public var entries: [PairEntry]

    public init(pass: String, model: String, view: Vy, entries: [PairEntry] = []) {
        format = Self.formatName
        self.pass = pass
        self.model = model
        self.view = view
        self.entries = entries
    }

    enum CodingKeys: String, CodingKey {
        case format, pass, model = "modell", view = "vy", entries = "serier"
    }

    /// Lägger till eller ersätter raden för samma serie och följare (modell och vy).
    public mutating func upsert(_ e: PairEntry) {
        entries.removeAll {
            $0.series == e.series && $0.follower.model == e.follower.model && $0.follower.view == e.follower.view
        }
        entries.append(e)
        entries.sort { ($0.series, $0.follower.view.rawValue) < ($1.series, $1.follower.view.rawValue) }
    }
}

/// En följares serie som den styrande tagit emot, med klockans prov: sparas i
/// `Pass/<id>/foljare.json` innan den kvitteras, så att parningen överlever att vyn
/// stängs eller appen startas om (docs/FORMAT.md "Två telefoner"). BESLUT B22
public struct FollowerRecord: Codable, Equatable, Sendable {
    public var hello: LinkHello
    public var series: LinkSeries
    public var before: [PingSample]
    public var after: [PingSample]

    public init(hello: LinkHello, series: LinkSeries, before: [PingSample], after: [PingSample]) {
        self.hello = hello
        self.series = series
        self.before = before
        self.after = after
    }
}

/// `foljare.json`: följarnas serier i den styrandes pass.
public struct FollowerInbox: Codable, Equatable, Sendable {
    public static let formatName = "swinglab-foljare/1"

    public var format: String
    public var entries: [FollowerRecord]

    public init(entries: [FollowerRecord] = []) {
        format = Self.formatName
        self.entries = entries
    }

    /// Lägger till eller ersätter samma följares serie (id och den styrandes serie).
    public mutating func upsert(_ r: FollowerRecord) {
        entries.removeAll { $0.hello.device == r.hello.device && $0.series.series == r.series.series }
        entries.append(r)
        entries.sort { ($0.series.series, $0.hello.device) < ($1.series.series, $1.hello.device) }
    }
}
