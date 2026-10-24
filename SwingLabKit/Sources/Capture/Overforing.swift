import Foundation
import Swing

// Överföringen mellan telefonerna för 3D (S6c-2, BESLUT B61, METOD MS19): följaren skickar
// sina analyserade slag till den styrande, som räknar 3D (TreD) och skickar resultatet
// tillbaka. Det som skickas är ett paket utan video: manifestet, enhet.json, par.json och
// lederna per slag i kompakt form (`SlagBunt`). Samma bunt byggs ur den andra telefonens zip
// ("Import other phone") när kopplingen inte fanns. Stora meddelanden delas i bitar
// (`LinkPart`), varje bit kvitteras, och allt som inte kvitterats skickas igen när kopplingen
// kommer tillbaka (BESLUT B22). Bara Foundation, så att allt prövas på Linux.

/// Ett fel i överföringen eller bunten: platsen och fältet, aldrig värdet (CLAUDE.md, Dataregeln).
public struct OverforingFel: Error, Equatable, Sendable {
    public var skal: String

    public init(_ skal: String) {
        self.skal = skal
    }
}

// MARK: - Lederna i kompakt form

/// Ett slags leder för överföringen: tiderna som int32 i 1e-4 s, och per ruta och led x och y
/// i 0,1 px (int16, eller int32 när ett tal inte ryms) och konfidensen som uint16 i 0,001, allt
/// little endian i base64. Samma steg som ledfilen redan är avrundad till
/// (`JointSeries.rounded`), och talen läses tillbaka med samma räkning (n · steg), så att 3D och
/// 2D-faserna får exakt ledfilens tal. En led med konfidensen 0 (avrundad) eller ett tal som
/// inte är ändligt skickas som saknad: båda räknas som saknade i 3D och 2D (METOD M1, MK2).
/// Rutans `pts` och observationens konfidens följer inte med (3D läser dem inte). METOD MS19
public struct KompaktaLeder: Codable, Equatable, Sendable {
    public var width: Int
    public var height: Int
    public var source: String
    /// "i16" eller "i32": x och y.
    public var enc: String
    public var t: String
    public var j: String

    public static let tidSteg = 1e-4
    public static let pxSteg = 0.1
    public static let konfSteg = 1e-3

    public init(_ s: JointSeries) throws {
        width = s.width
        height = s.height
        source = s.source
        var tider: [Int32] = []
        tider.reserveCapacity(s.frames.count)
        var xy: [Int64] = []
        var konf: [UInt16] = []
        xy.reserveCapacity(s.frames.count * JointSeries.names.count * 2)
        konf.reserveCapacity(s.frames.count * JointSeries.names.count)
        for (i, f) in s.frames.enumerated() {
            let n = (f.t / Self.tidSteg).rounded()
            guard n.isFinite, abs(n) <= Double(Int32.max) else { throw OverforingFel("ruta \(i): tiden ryms inte") }
            tider.append(Int32(n))
            for m in 0..<JointSeries.names.count {
                var x = 0.0, y = 0.0, c = 0.0
                if m < f.joints.count, let led = f.joints[m], led.x.isFinite, led.y.isFinite, led.c.isFinite {
                    let nx = (led.x / Self.pxSteg).rounded(), ny = (led.y / Self.pxSteg).rounded()
                    let nc = (led.c / Self.konfSteg).rounded()
                    if abs(nx) <= Double(Int32.max), abs(ny) <= Double(Int32.max), nc >= 1, nc <= Double(UInt16.max) {
                        x = nx
                        y = ny
                        c = nc
                    }
                }
                xy.append(Int64(x))
                xy.append(Int64(y))
                konf.append(UInt16(c))
            }
        }
        let smal = xy.allSatisfy { $0 >= Int64(Int16.min) && $0 <= Int64(Int16.max) }
        enc = smal ? "i16" : "i32"
        var tb = [UInt8]()
        tb.reserveCapacity(tider.count * 4)
        for v in tider { Self.lagg(&tb, UInt64(UInt32(bitPattern: v)), 4) }
        var jb = [UInt8]()
        jb.reserveCapacity(konf.count * (smal ? 6 : 10))
        for k in 0..<konf.count {
            if smal {
                Self.lagg(&jb, UInt64(UInt16(bitPattern: Int16(xy[2 * k]))), 2)
                Self.lagg(&jb, UInt64(UInt16(bitPattern: Int16(xy[2 * k + 1]))), 2)
            } else {
                Self.lagg(&jb, UInt64(UInt32(bitPattern: Int32(xy[2 * k]))), 4)
                Self.lagg(&jb, UInt64(UInt32(bitPattern: Int32(xy[2 * k + 1]))), 4)
            }
            Self.lagg(&jb, UInt64(konf[k]), 2)
        }
        t = Data(tb).base64EncodedString()
        j = Data(jb).base64EncodedString()
    }

    /// `antal` byte little endian.
    static func lagg(_ b: inout [UInt8], _ v: UInt64, _ antal: Int) {
        for i in 0..<antal { b.append(UInt8(truncatingIfNeeded: v >> (8 * UInt64(i)))) }
    }

    static func las(_ b: [UInt8], _ i: Int, _ antal: Int) -> UInt64 {
        var v: UInt64 = 0
        for k in 0..<antal { v |= UInt64(b[i + k]) << (8 * UInt64(k)) }
        return v
    }

    /// Lederna tillbaka, med ledfilens tal (n · steg). Ett fel nämner bara fältet.
    public func series() throws -> JointSeries {
        guard enc == "i16" || enc == "i32" else { throw OverforingFel("enc ska vara i16 eller i32") }
        guard let td = Data(base64Encoded: t), let jd = Data(base64Encoded: j) else {
            throw OverforingFel("t och j ska vara base64")
        }
        let tb = [UInt8](td), jb = [UInt8](jd)
        let leder = JointSeries.names.count
        let per = enc == "i16" ? 6 : 10
        let rutor = tb.count / 4
        guard tb.count % 4 == 0, jb.count == rutor * leder * per else {
            throw OverforingFel("t och j har inte samma antal rutor")
        }
        guard width > 0, height > 0 else { throw OverforingFel("width och height ska vara positiva") }
        var frames: [PoseFrame] = []
        frames.reserveCapacity(rutor)
        var p = 0
        for i in 0..<rutor {
            let ti = Int32(bitPattern: UInt32(Self.las(tb, 4 * i, 4)))
            var js: [PoseJoint?] = []
            js.reserveCapacity(leder)
            for _ in 0..<leder {
                let x: Int64, y: Int64
                if enc == "i16" {
                    x = Int64(Int16(bitPattern: UInt16(Self.las(jb, p, 2))))
                    y = Int64(Int16(bitPattern: UInt16(Self.las(jb, p + 2, 2))))
                    p += 4
                } else {
                    x = Int64(Int32(bitPattern: UInt32(Self.las(jb, p, 4))))
                    y = Int64(Int32(bitPattern: UInt32(Self.las(jb, p + 4, 4))))
                    p += 8
                }
                let c = Self.las(jb, p, 2)
                p += 2
                js.append(c == 0 ? nil : PoseJoint(x: Double(x) * Self.pxSteg, y: Double(y) * Self.pxSteg,
                                                   c: Double(c) * Self.konfSteg))
            }
            frames.append(PoseFrame(t: Double(ti) * Self.tidSteg, pts: 0, joints: js, confidence: 0))
        }
        return JointSeries(source: source, width: width, height: height, frames: frames)
    }
}

// MARK: - Bunten: en telefons slag för 3D

/// En telefons slag för 3D: paketets filer utan video (docs/FORMAT.md, `swinglab-slag/1`).
/// `manifest`, `enhet` och `par` är filernas text som de står i paketet, så att TreD läser dem
/// som PC:n läser zippen; lederna per slag-id i kompakt form. METOD MS19
public struct SlagBunt: Codable, Equatable, Sendable {
    public static let formatName = "swinglab-slag/1"
    /// Den andra telefonens bunt i passets mapp (`Pass/<id>/annan_telefon.json`).
    public static let filnamn = "annan_telefon.json"
    /// Största bunt som tas emot eller läses, byte (ett pass om 60 slag är cirka 7 MB).
    public static let maxBytes = 48 << 20

    public var format: String
    public var pass: String
    public var vy: Vy
    public var manifest: String
    public var enhet: String?
    public var par: String?
    public var leder: [String: KompaktaLeder]

    public init(pass: String, vy: Vy, manifest: String, enhet: String?, par: String?, leder: [String: KompaktaLeder]) {
        format = Self.formatName
        self.pass = pass
        self.vy = vy
        self.manifest = manifest
        self.enhet = enhet
        self.par = par
        self.leder = leder
    }

    /// Bunten ur paketets filer. Manifestet ska bära `pass` och `vy`; lederna för slagen i det.
    public static func make(manifest: Data, enhet: Data?, par: Data?, leder: [String: JointSeries]) throws -> SlagBunt {
        let (pass, vy, _) = try lasManifest(manifest)
        var k: [String: KompaktaLeder] = [:]
        for (id, s) in leder { k[id] = try KompaktaLeder(s) }
        return SlagBunt(pass: pass, vy: vy, manifest: String(decoding: manifest, as: UTF8.self),
                        enhet: enhet.map { String(decoding: $0, as: UTF8.self) },
                        par: par.map { String(decoding: $0, as: UTF8.self) }, leder: k)
    }

    /// Manifestets pass, vy och slagens ledfiler (id → sökväg i paketet).
    static func lasManifest(_ d: Data) throws -> (pass: String, vy: Vy, leder: [(String, String)]) {
        guard let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else {
            throw OverforingFel("manifest.json är inte ett JSON-objekt")
        }
        guard let pass = o["pass"] as? String, PassID.isValid(pass) else { throw OverforingFel("manifest.json: pass") }
        guard let v = o["vy"] as? String, let vy = Vy(rawValue: v) else { throw OverforingFel("manifest.json: vy") }
        var leder: [(String, String)] = []
        for s in (o["slag"] as? [[String: Any]]) ?? [] {
            if let id = s["id"] as? String, let fil = s["leder"] as? String { leder.append((id, fil)) }
        }
        return (pass, vy, leder)
    }

    public var manifestData: Data { Data(manifest.utf8) }
    public var enhetData: Data? { enhet.map { Data($0.utf8) } }
    public var parData: Data? { par.map { Data($0.utf8) } }

    /// Lederna per slag-id.
    public func lederna() throws -> [String: JointSeries] {
        var ut: [String: JointSeries] = [:]
        for (id, k) in leder {
            do {
                ut[id] = try k.series()
            } catch let e as OverforingFel {
                throw OverforingFel("leder \(id): \(e.skal)")
            }
        }
        return ut
    }

    /// Bunten som JSON (sorterade nycklar, så att samma bunt ger samma byte och samma summa).
    public func data() throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return try e.encode(self)
    }

    /// Bunten ur JSON, med formatet, passet och storleken prövade.
    public static func las(_ d: Data) throws -> SlagBunt {
        guard d.count <= maxBytes else { throw OverforingFel("\(filnamn): för stor") }
        guard let b = try? JSONDecoder().decode(SlagBunt.self, from: d) else {
            throw OverforingFel("\(filnamn): går inte att läsa")
        }
        guard b.format == formatName else { throw OverforingFel("\(filnamn): format ska vara \(formatName)") }
        guard PassID.isValid(b.pass) else { throw OverforingFel("\(filnamn): pass") }
        return b
    }

    /// Bunten ur den andra telefonens paket (`swinglab-<pass>-<vy>.zip`, "Import other phone"):
    /// manifest.json, enhet.json och par.json, och varje slags ledfil. Zippen läses fil för
    /// fil, så att klippen aldrig läses in. METOD MS19
    public static func ur(zip url: URL) throws -> SlagBunt {
        let z = try ZipLasare(url: url)
        guard let m = try z.data("manifest.json", max: 4 << 20) else { throw OverforingFel("manifest.json saknas") }
        let (_, _, filer) = try lasManifest(m)
        var leder: [String: JointSeries] = [:]
        for (id, fil) in filer {
            guard let d = try z.data(fil, max: 32 << 20) else { throw OverforingFel("\(fil) saknas") }
            guard let s = try? JSONDecoder().decode(JointSeries.self, from: d) else {
                throw OverforingFel("\(fil) går inte att läsa")
            }
            leder[id] = s
        }
        return try make(manifest: m, enhet: try z.data("enhet.json", max: 4 << 20),
                        par: try z.data("par.json", max: 4 << 20), leder: leder)
    }
}

// MARK: - Zippen: läsaren

/// Läser en okomprimerad zip (paketets form, BESLUT B27, `ZipWriter`): den centrala katalogen,
/// och en fil i taget ur disken med CRC-kontroll. Bara metoden 0 och ingen zip64.
public final class ZipLasare {
    struct Post {
        let size: UInt32
        let crc: UInt32
        let method: UInt16
        let offset: UInt32
    }

    private let handle: FileHandle
    private var poster: [String: Post] = [:]

    public init(url: URL) throws {
        guard let h = try? FileHandle(forReadingFrom: url) else { throw OverforingFel("zippen går inte att öppna") }
        handle = h
        let langd = try h.seekToEnd()
        guard langd >= 22 else { throw OverforingFel("inte en zip") }
        // Slutet på den centrala katalogen ligger inom de sista 22 + 65 535 byten.
        let sok = min(langd, 22 + 65_535)
        try h.seek(toOffset: langd - sok)
        let slut = [UInt8](try h.read(upToCount: Int(sok)) ?? Data())
        var e: Int?
        var i = slut.count - 22
        while i >= 0 {
            if slut[i] == 0x50, slut[i + 1] == 0x4B, slut[i + 2] == 0x05, slut[i + 3] == 0x06 {
                e = i
                break
            }
            i -= 1
        }
        guard let e else { throw OverforingFel("inte en zip") }
        let antal = Int(KompaktaLeder.las(slut, e + 10, 2))
        let storlek = Int(KompaktaLeder.las(slut, e + 12, 4))
        let start = UInt64(KompaktaLeder.las(slut, e + 16, 4))
        guard start + UInt64(storlek) <= langd else { throw OverforingFel("zippens katalog ligger utanför filen") }
        try h.seek(toOffset: start)
        let kat = [UInt8](try h.read(upToCount: storlek) ?? Data())
        guard kat.count == storlek else { throw OverforingFel("zippens katalog är kort") }
        var p = 0
        for _ in 0..<antal {
            guard p + 46 <= kat.count, KompaktaLeder.las(kat, p, 4) == 0x0201_4B50 else {
                throw OverforingFel("zippens katalog går inte att läsa")
            }
            let metod = UInt16(KompaktaLeder.las(kat, p + 10, 2))
            let crc = UInt32(KompaktaLeder.las(kat, p + 16, 4))
            let size = UInt32(KompaktaLeder.las(kat, p + 24, 4))
            let n = Int(KompaktaLeder.las(kat, p + 28, 2))
            let x = Int(KompaktaLeder.las(kat, p + 30, 2))
            let k = Int(KompaktaLeder.las(kat, p + 32, 2))
            let offset = UInt32(KompaktaLeder.las(kat, p + 42, 4))
            guard p + 46 + n <= kat.count else { throw OverforingFel("zippens katalog går inte att läsa") }
            let namn = String(decoding: kat[(p + 46)..<(p + 46 + n)], as: UTF8.self)
            poster[namn] = Post(size: size, crc: crc, method: metod, offset: offset)
            p += 46 + n + x + k
        }
    }

    deinit {
        try? handle.close()
    }

    /// Filernas namn i zippen.
    public var namn: [String] { poster.keys.sorted() }

    /// En fil ur zippen, eller nil när den inte finns. Större än `max` byte, komprimerad eller
    /// med fel CRC är ett fel.
    public func data(_ namn: String, max: Int) throws -> Data? {
        guard let post = poster[namn] else { return nil }
        guard post.method == 0 else { throw OverforingFel("\(namn): komprimerad (bara okomprimerade zippar)") }
        guard Int(post.size) <= max else { throw OverforingFel("\(namn): för stor") }
        try handle.seek(toOffset: UInt64(post.offset))
        let huvud = [UInt8](try handle.read(upToCount: 30) ?? Data())
        guard huvud.count == 30, KompaktaLeder.las(huvud, 0, 4) == 0x0403_4B50 else {
            throw OverforingFel("\(namn): huvudet går inte att läsa")
        }
        let n = UInt64(KompaktaLeder.las(huvud, 26, 2)), x = UInt64(KompaktaLeder.las(huvud, 28, 2))
        try handle.seek(toOffset: UInt64(post.offset) + 30 + n + x)
        let d = try handle.read(upToCount: Int(post.size)) ?? Data()
        guard d.count == Int(post.size) else { throw OverforingFel("\(namn): kort") }
        guard CRC32.checksum(d) == post.crc else { throw OverforingFel("\(namn): fel CRC") }
        return d
    }
}

// MARK: - Bitarna på kopplingen

/// En bit av en stor överföring på kopplingen (meddelandet `part`, docs/FORMAT.md). `id` är
/// hela innehållets summa (`Overforing.summa`), så att samma innehåll är samma överföring och
/// ett nytt ersätter ett gammalt av samma slag. METOD MS19
public struct LinkPart: Codable, Equatable, Sendable {
    /// Meddelandets version. En bit med en annan version läses inte (och kvitteras inte).
    public static let version = 1

    public var v: Int
    /// "slag" (följarens bunt) eller "tre_d" (resultatet tillbaka).
    public var kind: String
    public var pass: String
    public var id: String
    public var index: Int
    public var count: Int
    public var bytes: Int
    /// Bitens byte i base64.
    public var data: String

    public init(v: Int = LinkPart.version, kind: String, pass: String, id: String, index: Int, count: Int, bytes: Int,
                data: String) {
        self.v = v
        self.kind = kind
        self.pass = pass
        self.id = id
        self.index = index
        self.count = count
        self.bytes = bytes
        self.data = data
    }
}

/// Kvittensen för en bit (`index`), eller för hela överföringen (`index` nil): `ok` = sparad,
/// annars stämde inte summan och allt skickas igen.
public struct LinkPartAck: Codable, Equatable, Sendable {
    public var v: Int
    public var kind: String
    public var pass: String
    public var id: String
    public var index: Int?
    public var ok: Bool

    public init(v: Int = LinkPart.version, kind: String, pass: String, id: String, index: Int?, ok: Bool) {
        self.v = v
        self.kind = kind
        self.pass = pass
        self.id = id
        self.index = index
        self.ok = ok
    }
}

/// Överföringens konstanter och delningen. METOD MS19
public enum Overforing {
    /// Följarens slag till den styrande.
    public static let slag = "slag"
    /// 3D-resultatet tillbaka till följaren.
    public static let treD = "tre_d"
    /// Byte per bit: base64 och JSON runt om ger cirka 350 kB, under ramens 1 MB (`Wire.maxLength`).
    public static let delBytes = 192 * 1024
    /// Största överföring, byte.
    public static let maxBytes = SlagBunt.maxBytes

    /// Innehållets summa: CRC-32 och längden, "1a2b3c4d-123456". Kännetecknet för innehållet,
    /// och kontrollen att alla bitar kom fram hela.
    public static func summa(_ d: Data) -> String {
        String(format: "%08x", CRC32.checksum(d)) + "-\(d.count)"
    }

    /// Antalet bitar för `bytes` byte (minst en, även för tomt innehåll).
    public static func antal(_ bytes: Int) -> Int {
        max(1, (bytes + delBytes - 1) / delBytes)
    }

    /// Innehållet delat i bitar.
    public static func dela(kind: String, pass: String, data: Data) -> [LinkPart] {
        let id = summa(data)
        let n = antal(data.count)
        let b = [UInt8](data)
        return (0..<n).map { i in
            let a = i * delBytes, e = min(b.count, a + delBytes)
            return LinkPart(kind: kind, pass: pass, id: id, index: i, count: n, bytes: b.count,
                            data: Data(b[a..<e]).base64EncodedString())
        }
    }
}

/// Avsändarens sida: en överföring per slag (`kind`), bitarna som inte kvitterats och om
/// hela kvitterats. En ny överföring av samma slag ersätter den förra. METOD MS19
public struct PartSender: Equatable, Sendable {
    struct Pagaende: Equatable, Sendable {
        var delar: [LinkPart]
        var kvitterade: Set<Int>
    }

    var pagaende: [String: Pagaende] = [:]

    public init() {}

    /// Överföringar som inte kvitterats hela.
    public var count: Int { pagaende.count }

    /// En ny överföring: alla bitar, att skicka nu.
    public mutating func enqueue(kind: String, pass: String, data: Data) -> [LinkPart] {
        let delar = Overforing.dela(kind: kind, pass: pass, data: data)
        pagaende[kind] = Pagaende(delar: delar, kvitterade: [])
        return delar
    }

    /// Det som ska skickas igen när kopplingen kommer tillbaka: bitarna som inte kvitterats,
    /// eller den sista när alla bitar kvitterats men inte helheten (kvittensen kan ha tappats;
    /// mottagaren svarar då med helhetens kvittens igen).
    public func unacked() -> [LinkPart] {
        var ut: [LinkPart] = []
        for k in pagaende.keys.sorted() {
            guard let p = pagaende[k] else { continue }
            let kvar = p.delar.filter { !p.kvitterade.contains($0.index) }
            ut += kvar.isEmpty ? Array(p.delar.suffix(1)) : kvar
        }
        return ut
    }

    /// En kvittens. Svarar bitarna som ska skickas igen (alla, när summan inte stämde) och
    /// om överföringen är klar.
    public mutating func receive(_ a: LinkPartAck) -> (done: Bool, resend: [LinkPart]) {
        guard a.v == LinkPart.version, var p = pagaende[a.kind], p.delar.first?.id == a.id,
              p.delar.first?.pass == a.pass else { return (false, []) }
        if let i = a.index {
            p.kvitterade.insert(i)
            pagaende[a.kind] = p
            return (false, [])
        }
        if a.ok {
            pagaende[a.kind] = nil
            return (true, [])
        }
        p.kvitterade = []
        pagaende[a.kind] = p
        return (false, p.delar)
    }
}

/// Mottagarens sida: bitarna per slag tills alla kommit, sedan summan. En bit med en annan
/// version, ett orimligt antal eller fel storlek läses inte. METOD MS19
public struct PartReceiver: Equatable, Sendable {
    struct Mottagen: Equatable, Sendable {
        let id: String
        let pass: String
        let count: Int
        let bytes: Int
        var delar: [Int: Data]
    }

    var pagaende: [String: Mottagen] = [:]
    /// Den senaste sparade överföringen per slag ("kind" → id), så att en bit som kommer igen
    /// efter en tappad helhetskvittens får kvittensen igen i stället för att tas emot igen.
    var klara: [String: String] = [:]

    public init() {}

    public enum Utfall: Equatable, Sendable {
        /// Kvittenser att skicka.
        case kvittera([LinkPartAck])
        /// Allt kom fram och summan stämmer: spara, och kvittera sedan helheten (`klar`).
        case hel(kind: String, pass: String, id: String, data: Data, kvittenser: [LinkPartAck])
    }

    public mutating func receive(_ p: LinkPart) -> Utfall {
        guard p.v == LinkPart.version, p.count == Overforing.antal(p.bytes), p.bytes >= 0,
              p.bytes <= Overforing.maxBytes, p.index >= 0, p.index < p.count,
              let d = Data(base64Encoded: p.data) else { return .kvittera([]) }
        let vantat = p.index == p.count - 1 ? p.bytes - p.index * Overforing.delBytes : Overforing.delBytes
        guard d.count == vantat else { return .kvittera([]) }
        let bit = LinkPartAck(kind: p.kind, pass: p.pass, id: p.id, index: p.index, ok: true)
        if klara[p.kind] == p.id {
            return .kvittera([bit, LinkPartAck(kind: p.kind, pass: p.pass, id: p.id, index: nil, ok: true)])
        }
        var m = pagaende[p.kind]
        if m == nil || m?.id != p.id || m?.pass != p.pass {
            m = Mottagen(id: p.id, pass: p.pass, count: p.count, bytes: p.bytes, delar: [:])
        }
        m!.delar[p.index] = d
        guard m!.delar.count == m!.count else {
            pagaende[p.kind] = m
            return .kvittera([bit])
        }
        pagaende[p.kind] = nil
        var hel = Data()
        hel.reserveCapacity(p.bytes)
        for i in 0..<m!.count { hel.append(m!.delar[i]!) }
        guard Overforing.summa(hel) == p.id else {
            return .kvittera([bit, LinkPartAck(kind: p.kind, pass: p.pass, id: p.id, index: nil, ok: false)])
        }
        return .hel(kind: p.kind, pass: p.pass, id: p.id, data: hel, kvittenser: [bit])
    }

    /// Helheten är sparad: kvittensen att skicka.
    public mutating func klar(kind: String, pass: String, id: String) -> LinkPartAck {
        klara[kind] = id
        return LinkPartAck(kind: kind, pass: pass, id: id, index: nil, ok: true)
    }
}
