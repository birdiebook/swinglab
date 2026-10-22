import Foundation
import Swing

// Två telefoner (S2_SPEC §7.1, BESLUT B21): meddelandena mellan dem och hur de
// ramas in på TCP-strömmen. Appens Link.swift (Network.framework) skickar bara
// det här; logiken i LinkSession.swift avgör vad som skickas. Bara kommandon,
// klicktider och klockans prov, aldrig video (dataregeln, BESLUT B22).

/// Rollen i uppställningen: ensam, styr (lyssnar och visar Start) eller följ (söker
/// och ansluter). Manifestets `telefon.roll` (S2_SPEC §8.3).
public enum LinkRole: String, Codable, Sendable, CaseIterable {
    case solo = "ensam"
    case lead = "styr"
    case follow = "folj"
}

/// Vem som talar: rollen, en slumpad id per start av appen (känner igen en telefon som
/// ansluter igen), modellen, appens version och vyn.
public struct LinkHello: Codable, Equatable, Sendable {
    public var role: LinkRole
    public var device: String
    public var model: String
    public var app: String
    public var view: Vy

    public init(role: LinkRole, device: String, model: String, app: String, view: Vy) {
        self.role = role
        self.device = device
        self.model = model
        self.app = app
        self.view = view
    }
}

/// En inspelad serie som klick på telefonens egen tidslinje: följaren skickar den efter
/// stopp (`recorded`), och den styrande har sin egen likadan. Tiderna är s i filen.
public struct LinkSeries: Codable, Equatable, Sendable {
    /// Den styrande telefonens serie (kommandot `start`).
    public var series: Int
    /// Serien i den här telefonens pass (`Video/<nr>.mov`).
    public var localSeries: Int
    /// Den här telefonens pass.
    public var passID: String
    /// Filens tid noll på telefonens värdklocka (startPTS), s. nil = okänd.
    public var startHost: Double?
    public var frameRate: Double
    public var clicks: [Click]
    public var view: Vy
    /// Bollen till telefonen, m (ljudets väg, METOD MS6).
    public var distance: Double

    public init(series: Int, localSeries: Int, passID: String, startHost: Double?, frameRate: Double,
                clicks: [Click], view: Vy, distance: Double) {
        self.series = series
        self.localSeries = localSeries
        self.passID = passID
        self.startHost = startHost
        self.frameRate = frameRate
        self.clicks = clicks
        self.view = view
        self.distance = distance
    }
}

/// Vad en kvittens kvitterar.
public enum LinkAck: String, Codable, Sendable {
    case start, stop, recorded
}

/// Ett meddelande mellan telefonerna (S2_SPEC §7.1). JSON med `type` och fälten
/// platt bredvid; formatet står i docs/FORMAT.md "Två telefoner".
public enum LinkMessage: Equatable, Sendable {
    case hello(LinkHello)
    /// Styrande telefonens värdklocka när pingen skickades.
    case ping(id: Int, t0: Double)
    /// Följarens klocka vid mottagning (t1) och svar (t2). METOD MS9
    case pong(id: Int, t0: Double, t1: Double, t2: Double)
    case start(passID: String, series: Int)
    case stop(series: Int)
    /// Följarens serie med klicken, efter stopp. Skickas tills den kvitteras.
    case recorded(LinkSeries)
    case status(recording: Bool, freeGB: Double, pressure: String)
    case ack(LinkAck, series: Int)
}

extension LinkMessage: Codable {
    enum Typ: String, Codable {
        case hello, ping, pong, start, stop, recorded, status, ack
    }

    enum Keys: String, CodingKey {
        case type, hello, id, t0, t1, t2, passID = "pass", series, recorded, recording, freeGB, pressure, ack
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        switch try c.decode(Typ.self, forKey: .type) {
        case .hello: self = .hello(try c.decode(LinkHello.self, forKey: .hello))
        case .ping: self = .ping(id: try c.decode(Int.self, forKey: .id), t0: try c.decode(Double.self, forKey: .t0))
        case .pong:
            self = .pong(id: try c.decode(Int.self, forKey: .id), t0: try c.decode(Double.self, forKey: .t0),
                         t1: try c.decode(Double.self, forKey: .t1), t2: try c.decode(Double.self, forKey: .t2))
        case .start:
            self = .start(passID: try c.decode(String.self, forKey: .passID), series: try c.decode(Int.self, forKey: .series))
        case .stop: self = .stop(series: try c.decode(Int.self, forKey: .series))
        case .recorded: self = .recorded(try c.decode(LinkSeries.self, forKey: .recorded))
        case .status:
            self = .status(recording: try c.decode(Bool.self, forKey: .recording),
                           freeGB: try c.decode(Double.self, forKey: .freeGB),
                           pressure: try c.decode(String.self, forKey: .pressure))
        case .ack: self = .ack(try c.decode(LinkAck.self, forKey: .ack), series: try c.decode(Int.self, forKey: .series))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case let .hello(h):
            try c.encode(Typ.hello, forKey: .type)
            try c.encode(h, forKey: .hello)
        case let .ping(id, t0):
            try c.encode(Typ.ping, forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(t0, forKey: .t0)
        case let .pong(id, t0, t1, t2):
            try c.encode(Typ.pong, forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(t0, forKey: .t0)
            try c.encode(t1, forKey: .t1)
            try c.encode(t2, forKey: .t2)
        case let .start(passID, series):
            try c.encode(Typ.start, forKey: .type)
            try c.encode(passID, forKey: .passID)
            try c.encode(series, forKey: .series)
        case let .stop(series):
            try c.encode(Typ.stop, forKey: .type)
            try c.encode(series, forKey: .series)
        case let .recorded(s):
            try c.encode(Typ.recorded, forKey: .type)
            try c.encode(s, forKey: .recorded)
        case let .status(recording, freeGB, pressure):
            try c.encode(Typ.status, forKey: .type)
            try c.encode(recording, forKey: .recording)
            try c.encode(freeGB, forKey: .freeGB)
            try c.encode(pressure, forKey: .pressure)
        case let .ack(kind, series):
            try c.encode(Typ.ack, forKey: .type)
            try c.encode(kind, forKey: .ack)
            try c.encode(series, forKey: .series)
        }
    }
}

/// Inramningen på TCP-strömmen: fyra bytes längd (big-endian) före varje JSON
/// (S2_SPEC §7.1). TCP är en ström, så ett meddelande kan komma i bitar eller flera i
/// samma bit. BESLUT B21
public enum Wire {
    /// Bonjour-tjänsten, samma som `NSBonjourServices` i project.yml. BESLUT B21
    public static let bonjourService = "_swinglab._tcp"

    /// Längsta meddelande, byte. En serie med tusen klick är cirka 60 kB.
    public static let maxLength = 1 << 20

    /// Felen säger var, aldrig vad (dataregeln): meddelandets nummer på strömmen.
    public enum WireError: Error, Equatable {
        /// Längden i huvudet är större än `maxLength` (eller noll).
        case badLength(message: Int)
        /// JSON som inte är ett meddelande.
        case badMessage(message: Int)
        /// Ett meddelande som inte går att koda (t.ex. NaN).
        case unencodable
    }

    public static func frame(_ m: LinkMessage) throws -> Data {
        let json: Data
        do {
            json = try JSONEncoder().encode(m)
        } catch {
            throw WireError.unencodable
        }
        guard json.count <= maxLength else { throw WireError.unencodable }
        let n = UInt32(json.count)
        var d = Data([UInt8(n >> 24 & 0xFF), UInt8(n >> 16 & 0xFF), UInt8(n >> 8 & 0xFF), UInt8(n & 0xFF)])
        d.append(json)
        return d
    }

    /// Läser ramar ur strömmen i den ordning bitarna kommer. Ett fel lämnar läsaren
    /// obrukbar: förbindelsen stängs och en ny börjar med en ny läsare.
    public struct Reader: Sendable {
        private var buffer: [UInt8] = []
        /// Lästa meddelanden hittills (för felets plats).
        public private(set) var count = 0

        public init() {}

        public mutating func feed(_ d: Data) throws -> [LinkMessage] {
            buffer.append(contentsOf: d)
            var ut: [LinkMessage] = []
            var i = 0
            while buffer.count - i >= 4 {
                let n = Int(buffer[i]) << 24 | Int(buffer[i + 1]) << 16 | Int(buffer[i + 2]) << 8 | Int(buffer[i + 3])
                guard n > 0, n <= Wire.maxLength else { throw WireError.badLength(message: count + 1) }
                guard buffer.count - i - 4 >= n else { break }
                let json = Data(buffer[(i + 4)..<(i + 4 + n)])
                count += 1
                do {
                    ut.append(try JSONDecoder().decode(LinkMessage.self, from: json))
                } catch {
                    throw WireError.badMessage(message: count)
                }
                i += 4 + n
            }
            if i > 0 { buffer.removeFirst(i) }
            return ut
        }
    }
}
