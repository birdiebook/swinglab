import Foundation

/// Ett JSON-värde som skiljer på tal och sant/falskt och på heltal och decimaltal, som
/// Pythons json gör (paket.py kontrollerar `isinstance(x, int)` och att ett tal inte är
/// en bool). JSONSerialization blandar ihop dem olika på Darwin och Linux, så paketets
/// filer läses med den här lilla läsaren (RFC 8259). METOD M51
public indirect enum JSONVarde: Equatable, Sendable {
    case null
    case bool(Bool)
    /// Talet och om det skrevs som heltal (utan `.`, `e` och `E`).
    case nummer(Double, heltal: Bool)
    case strang(String)
    case array([JSONVarde])
    case dict([String: JSONVarde])

    public struct Fel: Error, Equatable {}

    public static func las(_ data: Data) throws -> JSONVarde {
        var l = Lasare(b: [UInt8](data))
        l.blanka()
        let v = try l.varde(djup: 0)
        l.blanka()
        guard l.i == l.b.count else { throw Fel() }
        return v
    }

    public subscript(_ nyckel: String) -> JSONVarde? {
        if case .dict(let o) = self { return o[nyckel] }
        return nil
    }

    /// Ett ändligt tal (inte en bool), som paket._tal.
    public var tal: Double? {
        if case .nummer(let x, _) = self, x.isFinite { return x }
        return nil
    }

    /// Ett heltal skrivet som heltal (Pythons int, inte bool).
    public var heltal: Int? {
        if case .nummer(let x, true) = self, x.isFinite, abs(x) < 9e15 { return Int(x) }
        return nil
    }

    public var text: String? {
        if case .strang(let s) = self { return s }
        return nil
    }

    public var lista: [JSONVarde]? {
        if case .array(let l) = self { return l }
        return nil
    }

    public var objekt: [String: JSONVarde]? {
        if case .dict(let o) = self { return o }
        return nil
    }

    /// Pythons `==` mellan två värden ur json (None för ett saknat): tal och bool jämförs
    /// som tal (True == 1).
    static func pyLika(_ a: JSONVarde?, _ b: JSONVarde?) -> Bool {
        func somTal(_ v: JSONVarde?) -> Double? {
            switch v {
            case .nummer(let x, _)?: return x
            case .bool(let x)?: return x ? 1 : 0
            default: return nil
            }
        }
        if let x = somTal(a), let y = somTal(b) { return x == y }
        switch (a ?? .null, b ?? .null) {
        case (.null, .null): return true
        case (.strang(let x), .strang(let y)): return x == y
        case (.array(let x), .array(let y)): return x.count == y.count && zip(x, y).allSatisfy { pyLika($0, $1) }
        case (.dict(let x), .dict(let y)):
            return Set(x.keys) == Set(y.keys) && x.allSatisfy { pyLika($0.value, y[$0.key]) }
        default: return false
        }
    }

    struct Lasare {
        let b: [UInt8]
        var i = 0

        mutating func blanka() {
            while i < b.count, [0x20, 0x09, 0x0A, 0x0D].contains(b[i]) { i += 1 }
        }

        mutating func varde(djup: Int) throws -> JSONVarde {
            guard djup < 200, i < b.count else { throw Fel() }
            switch b[i] {
            case UInt8(ascii: "{"):
                i += 1
                var o: [String: JSONVarde] = [:]
                blanka()
                if i < b.count, b[i] == UInt8(ascii: "}") {
                    i += 1
                    return .dict(o)
                }
                while true {
                    blanka()
                    guard i < b.count, b[i] == UInt8(ascii: "\"") else { throw Fel() }
                    let k = try strang()
                    blanka()
                    guard i < b.count, b[i] == UInt8(ascii: ":") else { throw Fel() }
                    i += 1
                    blanka()
                    o[k] = try varde(djup: djup + 1)
                    blanka()
                    guard i < b.count else { throw Fel() }
                    if b[i] == UInt8(ascii: ",") { i += 1; continue }
                    if b[i] == UInt8(ascii: "}") { i += 1; return .dict(o) }
                    throw Fel()
                }
            case UInt8(ascii: "["):
                i += 1
                var l: [JSONVarde] = []
                blanka()
                if i < b.count, b[i] == UInt8(ascii: "]") {
                    i += 1
                    return .array(l)
                }
                while true {
                    blanka()
                    l.append(try varde(djup: djup + 1))
                    blanka()
                    guard i < b.count else { throw Fel() }
                    if b[i] == UInt8(ascii: ",") { i += 1; continue }
                    if b[i] == UInt8(ascii: "]") { i += 1; return .array(l) }
                    throw Fel()
                }
            case UInt8(ascii: "\""):
                return .strang(try strang())
            case UInt8(ascii: "t"): return try ord("true", .bool(true))
            case UInt8(ascii: "f"): return try ord("false", .bool(false))
            case UInt8(ascii: "n"): return try ord("null", .null)
            default: return try tal()
            }
        }

        mutating func ord(_ s: String, _ v: JSONVarde) throws -> JSONVarde {
            let u = Array(s.utf8)
            guard i + u.count <= b.count, Array(b[i..<(i + u.count)]) == u else { throw Fel() }
            i += u.count
            return v
        }

        mutating func tal() throws -> JSONVarde {
            let start = i
            if i < b.count, b[i] == UInt8(ascii: "-") { i += 1 }
            func siffror() -> Int {
                let s = i
                while i < b.count, b[i] >= 0x30, b[i] <= 0x39 { i += 1 }
                return i - s
            }
            guard i < b.count else { throw Fel() }
            if b[i] == UInt8(ascii: "0") { i += 1 } else if siffror() == 0 { throw Fel() }
            var heltal = true
            if i < b.count, b[i] == UInt8(ascii: ".") {
                i += 1
                heltal = false
                guard siffror() > 0 else { throw Fel() }
            }
            if i < b.count, b[i] == UInt8(ascii: "e") || b[i] == UInt8(ascii: "E") {
                i += 1
                heltal = false
                if i < b.count, b[i] == UInt8(ascii: "+") || b[i] == UInt8(ascii: "-") { i += 1 }
                guard siffror() > 0 else { throw Fel() }
            }
            guard let x = Double(String(decoding: b[start..<i], as: UTF8.self)) else { throw Fel() }
            return .nummer(x, heltal: heltal)
        }

        mutating func hex4() throws -> UInt32 {
            guard i + 4 <= b.count, let v = UInt32(String(decoding: b[i..<(i + 4)], as: UTF8.self), radix: 16) else {
                throw Fel()
            }
            i += 4
            return v
        }

        mutating func strang() throws -> String {
            i += 1                                        // "
            var ut = [UInt8]()
            while true {
                guard i < b.count else { throw Fel() }
                let c = b[i]
                i += 1
                if c == UInt8(ascii: "\"") { break }
                if c < 0x20 { throw Fel() }
                guard c == UInt8(ascii: "\\") else {
                    ut.append(c)
                    continue
                }
                guard i < b.count else { throw Fel() }
                let e = b[i]
                i += 1
                switch e {
                case UInt8(ascii: "\""), UInt8(ascii: "\\"), UInt8(ascii: "/"): ut.append(e)
                case UInt8(ascii: "b"): ut.append(0x08)
                case UInt8(ascii: "f"): ut.append(0x0C)
                case UInt8(ascii: "n"): ut.append(0x0A)
                case UInt8(ascii: "r"): ut.append(0x0D)
                case UInt8(ascii: "t"): ut.append(0x09)
                case UInt8(ascii: "u"):
                    var u = try hex4()
                    if (0xD800...0xDBFF).contains(u), i + 6 <= b.count, b[i] == UInt8(ascii: "\\"),
                       b[i + 1] == UInt8(ascii: "u") {
                        let spar = i
                        i += 2
                        let l = try hex4()
                        if (0xDC00...0xDFFF).contains(l) {
                            u = 0x10000 + ((u - 0xD800) << 10) + (l - 0xDC00)
                        } else {
                            i = spar
                        }
                    }
                    let s = Unicode.Scalar(u) ?? "\u{FFFD}"
                    ut.append(contentsOf: Array(String(Character(s)).utf8))
                default: throw Fel()
                }
            }
            return String(decoding: ut, as: UTF8.self)
        }
    }
}
