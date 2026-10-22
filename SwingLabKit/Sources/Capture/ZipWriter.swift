import Foundation

// Zip-skrivaren för paketet (S2_SPEC §8.4, BESLUT B27): bara metoden 0 (lagrad, ingen
// komprimering), eftersom videon redan är komprimerad och DEFLATE inte finns i
// Foundation på Linux. Samma bitar på Linux och telefonen. Huvudena som i Idunns
// `ZipArchive`: version 20, flaggan 0x0800 (namnen i UTF-8), DOS-tid i UTC, och
// CRC-32 med egen tabell (IEEE 0xEDB88320). Ingen zip64: från 4 GB eller 65 535
// filer kastar `ZipWriter.Error.tooLarge`, och appen föreslår paketet utan klipp.
// Stora filer strömmas till disk i bitar om 1 MB: CRC i ett första svep, sedan
// kopieringen, så att inget paket ligger i minnet (S2_SPEC §11.4 R13).

/// CRC-32 (IEEE 802.3, polynomet 0xEDB88320), som zip och PNG.
public struct CRC32: Sendable {
    static let table: [UInt32] = (0..<256).map { n -> UInt32 in
        var c = UInt32(n)
        for _ in 0..<8 {
            c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1
        }
        return c
    }

    private var state: UInt32 = 0xFFFF_FFFF

    public init() {}

    public mutating func update(_ data: Data) {
        var c = state
        data.withUnsafeBytes { (buf: UnsafeRawBufferPointer) in
            for b in buf {
                c = CRC32.table[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8)
            }
        }
        state = c
    }

    public var value: UInt32 { state ^ 0xFFFF_FFFF }

    public static func checksum(_ data: Data) -> UInt32 {
        var c = CRC32()
        c.update(data)
        return c.value
    }
}

/// Skriver en okomprimerad zip till disk, fil för fil.
public final class ZipWriter {
    public enum Error: Swift.Error, Equatable {
        /// Över 4 GB eller 65 535 filer (ingen zip64).
        case tooLarge
        /// Namnet är tomt, börjar med "/", innehåller ".." eller är för långt.
        case badName
        /// Filen ändrades mellan CRC-svepet och kopieringen.
        case fileChanged
        /// `finish()` är redan anropad.
        case finished
        case cannotCreate
    }

    /// En fil i zippen: namnet, storleken, CRC och var dess lokala huvud börjar.
    public struct Entry: Equatable, Sendable {
        public let name: String
        public let size: UInt32
        public let crc: UInt32
        public let offset: UInt32
    }

    /// Bitarnas storlek när en stor fil läses och kopieras, byte.
    public static let chunkSize = 1 << 20

    /// Gränserna utan zip64, ett under fälten största värde (0xFFFF och 0xFFFF_FFFF betyder
    /// "se zip64" för en läsare). Interna så att testerna kan pröva dem med små tal.
    var maxBytes: UInt64 = 0xFFFF_FFFE
    var maxEntries = 0xFFFE

    private let handle: FileHandle
    private var offset: UInt64 = 0
    public private(set) var entries: [Entry] = []
    private var done = false
    private let dosTime: UInt16
    private let dosDate: UInt16

    /// Skapar filen (en befintlig skrivs över). `date` blir filernas tid (DOS-tid i UTC).
    public init(url: URL, date: Date = Date()) throws {
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else { throw Error.cannotCreate }
        handle = try FileHandle(forWritingTo: url)
        let d = ZipWriter.dos(date)
        dosTime = d.time
        dosDate = d.date
    }

    deinit {
        if !done { try? handle.close() }
    }

    /// Antal byte skrivna hittills.
    public var bytesWritten: UInt64 { offset }

    /// En liten fil ur minnet.
    public func add(name: String, data: Data) throws {
        let namn = try checkedName(name)
        try reserve(nameBytes: namn.count, size: UInt64(data.count))
        let crc = CRC32.checksum(data)
        try writeEntry(namn: namn, name: name, size: UInt32(data.count), crc: crc) {
            try self.write(data)
        }
    }

    /// En stor fil från disk: CRC och storlek i ett första svep, sedan kopieringen i bitar
    /// om 1 MB. Filen ligger aldrig hel i minnet.
    public func addFile(name: String, from source: URL) throws {
        let namn = try checkedName(name)
        var crc = CRC32()
        var size: UInt64 = 0
        do {
            let las = try FileHandle(forReadingFrom: source)
            defer { try? las.close() }
            var slut = false
            while !slut {
                try Self.pool {
                    guard let bit = try las.read(upToCount: Self.chunkSize), !bit.isEmpty else {
                        slut = true
                        return
                    }
                    crc.update(bit)
                    size += UInt64(bit.count)
                    if size > maxBytes { throw Error.tooLarge }
                }
            }
        }
        try reserve(nameBytes: namn.count, size: size)
        let summa = crc.value
        try writeEntry(namn: namn, name: name, size: UInt32(size), crc: summa) {
            let las = try FileHandle(forReadingFrom: source)
            defer { try? las.close() }
            var kopierat: UInt64 = 0
            var kontroll = CRC32()
            var slut = false
            while !slut {
                try Self.pool {
                    guard let bit = try las.read(upToCount: Self.chunkSize), !bit.isEmpty else {
                        slut = true
                        return
                    }
                    kopierat += UInt64(bit.count)
                    guard kopierat <= size else { throw Error.fileChanged }
                    kontroll.update(bit)
                    try self.write(bit)
                }
            }
            guard kopierat == size, kontroll.value == summa else { throw Error.fileChanged }
        }
    }

    /// Katalogen och slutposten. Filen stängs.
    public func finish() throws {
        guard !done else { throw Error.finished }
        let start = offset
        var katalog = Data()
        for e in entries {
            let namn = Data(e.name.utf8)
            katalog.append(le32(0x0201_4B50))
            katalog.append(le16(20))            // skriven med version 2.0
            katalog.append(le16(20))            // kräver version 2.0
            katalog.append(le16(0x0800))        // namnet i UTF-8
            katalog.append(le16(0))             // metoden 0: lagrad
            katalog.append(le16(dosTime))
            katalog.append(le16(dosDate))
            katalog.append(le32(e.crc))
            katalog.append(le32(e.size))
            katalog.append(le32(e.size))
            katalog.append(le16(UInt16(namn.count)))
            katalog.append(le16(0))             // extra
            katalog.append(le16(0))             // kommentar
            katalog.append(le16(0))             // disken
            katalog.append(le16(0))             // interna attribut
            katalog.append(le32(0))             // externa attribut
            katalog.append(le32(e.offset))
            katalog.append(namn)
        }
        guard start + UInt64(katalog.count) + 22 <= maxBytes else { throw Error.tooLarge }
        var slut = Data()
        slut.append(le32(0x0605_4B50))
        slut.append(le16(0))
        slut.append(le16(0))
        slut.append(le16(UInt16(entries.count)))
        slut.append(le16(UInt16(entries.count)))
        slut.append(le32(UInt32(katalog.count)))
        slut.append(le32(UInt32(start)))
        slut.append(le16(0))                    // kommentar
        try write(katalog + slut)
        try handle.close()
        done = true
    }

    // MARK: - Hjälp

    private func checkedName(_ name: String) throws -> Data {
        let namn = Data(name.utf8)
        guard !name.isEmpty, !name.hasPrefix("/"), !name.split(separator: "/").contains(".."),
              namn.count <= 0xFFFF else { throw Error.badName }
        return namn
    }

    /// Ryms filen utan zip64?
    private func reserve(nameBytes: Int, size: UInt64) throws {
        guard !done else { throw Error.finished }
        guard entries.count + 1 <= maxEntries,
              offset + 30 + UInt64(nameBytes) + size <= maxBytes else { throw Error.tooLarge }
    }

    private func writeEntry(namn: Data, name: String, size: UInt32, crc: UInt32, body: () throws -> Void) throws {
        let start = offset
        var huvud = Data()
        huvud.append(le32(0x0403_4B50))
        huvud.append(le16(20))                  // kräver version 2.0
        huvud.append(le16(0x0800))              // namnet i UTF-8
        huvud.append(le16(0))                   // metoden 0: lagrad
        huvud.append(le16(dosTime))
        huvud.append(le16(dosDate))
        huvud.append(le32(crc))
        huvud.append(le32(size))
        huvud.append(le32(size))
        huvud.append(le16(UInt16(namn.count)))
        huvud.append(le16(0))                   // extra
        huvud.append(namn)
        try write(huvud)
        try body()
        entries.append(Entry(name: name, size: size, crc: crc, offset: UInt32(start)))
    }

    private func write(_ data: Data) throws {
        try handle.write(contentsOf: data)
        offset += UInt64(data.count)
    }

    /// En bit i en egen autoreleasepool på Apple, så att `FileHandle.read` inte samlar
    /// hundratals MB tills kopieringen är klar (S2_SPEC §11.4 R13). Linux har ingen.
    static func pool<T>(_ body: () throws -> T) rethrows -> T {
        #if canImport(ObjectiveC)
        return try autoreleasepool(invoking: body)
        #else
        return try body()
        #endif
    }

    /// DOS-tid och -datum i UTC; före 1980 blir 1980-01-01.
    static func dos(_ date: Date) -> (time: UInt16, date: UInt16) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let ar = c.year ?? 1980
        guard ar >= 1980 else { return (0, 33) }       // 1980-01-01
        let h: Int = c.hour ?? 0, m: Int = c.minute ?? 0, s: Int = c.second ?? 0
        let mon: Int = c.month ?? 1, d: Int = c.day ?? 1
        let ar7: Int = min(127, ar - 1980)
        let tid: Int = (h << 11) | (m << 5) | (s / 2)
        let dag: Int = (ar7 << 9) | (mon << 5) | d
        return (UInt16(tid), UInt16(dag))
    }
}

func le16(_ v: UInt16) -> Data {
    let b: [UInt8] = [UInt8(truncatingIfNeeded: v), UInt8(truncatingIfNeeded: v >> 8)]
    return Data(b)
}
func le32(_ v: UInt32) -> Data {
    let b: [UInt8] = [UInt8(truncatingIfNeeded: v), UInt8(truncatingIfNeeded: v >> 8),
                      UInt8(truncatingIfNeeded: v >> 16), UInt8(truncatingIfNeeded: v >> 24)]
    return Data(b)
}

/// En liten katalogläsare: läser slutposten och katalogen och, per fil, det lokala huvudet
/// och datan med CRC-kontroll. För testerna på Linux och simulatorprovet (S2_SPEC §10.2
/// steg 8); bara metoden 0, som skrivaren.
public struct ZipCatalog: Sendable {
    public enum Error: Swift.Error, Equatable {
        case notZip
        case corrupt(String)
    }

    public struct Entry: Equatable, Sendable {
        public let name: String
        public let method: UInt16
        public let flags: UInt16
        public let crc: UInt32
        public let compressedSize: UInt32
        public let size: UInt32
        public let offset: UInt32
    }

    public let url: URL
    public let entries: [Entry]

    public init(url: URL) throws {
        self.url = url
        let h = try FileHandle(forReadingFrom: url)
        defer { try? h.close() }
        let storlek = try h.seekToEnd()
        guard storlek >= 22 else { throw Error.notZip }
        let svans = min(storlek, 22 + 0xFFFF)
        try h.seek(toOffset: storlek - svans)
        let s = try [UInt8](h.read(upToCount: Int(svans)) ?? Data())
        guard let eocd = stride(from: s.count - 22, through: 0, by: -1).first(where: { ZipCatalog.u32(s, $0) == 0x0605_4B50 })
        else { throw Error.notZip }
        let antal = Int(ZipCatalog.u16(s, eocd + 10))
        let kStorlek = Int(ZipCatalog.u32(s, eocd + 12))
        let kStart = UInt64(ZipCatalog.u32(s, eocd + 16))
        guard kStart + UInt64(kStorlek) <= storlek else { throw Error.corrupt("katalogen") }
        try h.seek(toOffset: kStart)
        let k = try [UInt8](h.read(upToCount: kStorlek) ?? Data())
        guard k.count == kStorlek else { throw Error.corrupt("katalogen") }
        var ut: [Entry] = []
        var i = 0
        for n in 0..<antal {
            guard i + 46 <= k.count, ZipCatalog.u32(k, i) == 0x0201_4B50 else { throw Error.corrupt("katalogen, post \(n)") }
            let nl = Int(ZipCatalog.u16(k, i + 28)), xl = Int(ZipCatalog.u16(k, i + 30)), cl = Int(ZipCatalog.u16(k, i + 32))
            guard i + 46 + nl <= k.count else { throw Error.corrupt("katalogen, post \(n)") }
            let namn = String(decoding: k[(i + 46)..<(i + 46 + nl)], as: UTF8.self)
            ut.append(Entry(name: namn, method: ZipCatalog.u16(k, i + 10), flags: ZipCatalog.u16(k, i + 8),
                            crc: ZipCatalog.u32(k, i + 16), compressedSize: ZipCatalog.u32(k, i + 20),
                            size: ZipCatalog.u32(k, i + 24), offset: ZipCatalog.u32(k, i + 42)))
            i += 46 + nl + xl + cl
        }
        entries = ut
    }

    public var names: [String] { entries.map(\.name) }

    public func entry(_ name: String) -> Entry? { entries.first { $0.name == name } }

    /// Filens data, läst ur det lokala huvudet och kontrollerad mot katalogens storlek och CRC.
    public func data(_ e: Entry) throws -> Data {
        guard e.method == 0, e.compressedSize == e.size else { throw Error.corrupt("\(e.name): inte lagrad") }
        let h = try FileHandle(forReadingFrom: url)
        defer { try? h.close() }
        try h.seek(toOffset: UInt64(e.offset))
        let huvud = try [UInt8](h.read(upToCount: 30) ?? Data())
        guard huvud.count == 30, ZipCatalog.u32(huvud, 0) == 0x0403_4B50 else { throw Error.corrupt("\(e.name): huvudet") }
        let nl = Int(ZipCatalog.u16(huvud, 26)), xl = Int(ZipCatalog.u16(huvud, 28))
        let namn = try h.read(upToCount: nl) ?? Data()
        guard String(decoding: namn, as: UTF8.self) == e.name, ZipCatalog.u32(huvud, 14) == e.crc,
              ZipCatalog.u32(huvud, 22) == e.size else { throw Error.corrupt("\(e.name): huvudet mot katalogen") }
        if xl > 0 { _ = try h.read(upToCount: xl) }
        let d = try e.size > 0 ? (h.read(upToCount: Int(e.size)) ?? Data()) : Data()
        guard d.count == Int(e.size), CRC32.checksum(d) == e.crc else { throw Error.corrupt("\(e.name): CRC") }
        return d
    }

    public func data(named name: String) throws -> Data {
        guard let e = entry(name) else { throw Error.corrupt("\(name) saknas") }
        return try data(e)
    }

    static func u16(_ b: [UInt8], _ i: Int) -> UInt16 {
        let a: UInt16 = UInt16(b[i]), c: UInt16 = UInt16(b[i + 1]) << 8
        return a | c
    }
    static func u32(_ b: [UInt8], _ i: Int) -> UInt32 {
        let a: UInt32 = UInt32(b[i]), c: UInt32 = UInt32(b[i + 1]) << 8
        let d: UInt32 = UInt32(b[i + 2]) << 16, e: UInt32 = UInt32(b[i + 3]) << 24
        return a | c | d | e
    }
}
