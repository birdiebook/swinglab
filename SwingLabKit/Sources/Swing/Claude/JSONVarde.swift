import Foundation

/// Ett JSON-värde med fälten i den ordning de står, för underlaget till Claude-appen och
/// svaret tillbaka (S5b). Läsningen och skrivningen följer Pythons `json` tecken för tecken,
/// så att telefonen och PC:n ger samma text och samma fel (BESLUT B53, BESLUT B54):
/// `tools/pc/underlag.py` (`skriv`, `tal`) och `tools/pc/att_jobba_pa.py` (`json.loads`).
public indirect enum JSONVarde: Equatable, Sendable {
    case null
    case bool(Bool)
    case tal(Double)
    case text(String)
    case lista([JSONVarde])
    case objekt(Objekt)

    /// Ett objekt: nycklarna i ordning och värdena. En nyckel som står två gånger behåller sin
    /// första plats och får det sista värdet, som en dict i Python.
    public struct Objekt: Equatable, Sendable {
        public private(set) var nycklar: [String] = []
        public private(set) var varden: [String: JSONVarde] = [:]

        public init() {}

        public init(_ par: [(String, JSONVarde)]) {
            for (k, v) in par { self[k] = v }
        }

        public subscript(_ k: String) -> JSONVarde? {
            get { varden[k] }
            set {
                if let v = newValue {
                    if varden[k] == nil { nycklar.append(k) }
                    varden[k] = v
                } else if varden[k] != nil {
                    varden[k] = nil
                    nycklar.removeAll { $0 == k }
                }
            }
        }

        public var par: [(String, JSONVarde)] { nycklar.map { ($0, varden[$0]!) } }
    }

    // MARK: att bygga

    public static func o(_ par: [(String, JSONVarde)]) -> JSONVarde { .objekt(Objekt(par)) }
    public static func t(_ s: String?) -> JSONVarde { s.map { .text($0) } ?? .null }
    public static func d(_ v: Double?) -> JSONVarde { v.map { .tal($0) } ?? .null }
    public static func i(_ v: Int) -> JSONVarde { .tal(Double(v)) }
    public static func texter(_ s: [String]) -> JSONVarde { .lista(s.map { .text($0) }) }
    /// Ett spann ur katalogen: [min, max] med null för en öppen ände, eller null.
    public static func spann(_ s: [Double?]?) -> JSONVarde { s.map { .lista($0.map { d($0) }) } ?? .null }

    // MARK: att läsa

    public subscript(_ k: String) -> JSONVarde? {
        if case let .objekt(o) = self { return o[k] }
        return nil
    }

    public var somObjekt: Objekt? { if case let .objekt(o) = self { return o } else { return nil } }
    public var somLista: [JSONVarde]? { if case let .lista(l) = self { return l } else { return nil } }
    public var somText: String? { if case let .text(s) = self { return s } else { return nil } }
    public var arNull: Bool { self == .null }

    /// Ett tal men inte true/false (Pythons `_tal`).
    public var somTal: Double? { if case let .tal(v) = self { return v } else { return nil } }

    /// Talet som Python ser det: true och false är 1 och 0.
    var pyTal: Double? {
        switch self {
        case let .tal(v): return v
        case let .bool(b): return b ? 1 : 0
        default: return nil
        }
    }

    /// Pythons `==`: 1 == 1.0 == true, listor element för element, objekt utan ordning.
    public func lika(_ b: JSONVarde) -> Bool {
        if let x = pyTal, let y = b.pyTal { return x == y }
        switch (self, b) {
        case (.null, .null): return true
        case let (.text(x), .text(y)): return x == y
        case let (.lista(x), .lista(y)):
            return x.count == y.count && zip(x, y).allSatisfy { $0.lika($1) }
        case let (.objekt(x), .objekt(y)):
            return Set(x.nycklar) == Set(y.nycklar) && x.nycklar.allSatisfy { x[$0]!.lika(y[$0]!) }
        default: return false
        }
    }

    /// Nyckeln i en Python-mängd (`set(map(_nyckel, …))` i att_jobba_pa.py): listor och objekt
    /// blir None, och 1, 1.0 och true är samma.
    var pyNyckel: String {
        if let v = pyTal { return "t:\(v)" }
        if case let .text(s) = self { return "s:" + s }
        return "n"
    }

    // MARK: läsningen (json.loads)

    public struct LasFel: Error {}

    /// Texten som JSON, som Pythons `json.loads` utan NaN och Infinity: bara mellanslag, tab,
    /// radslut och vagnretur runt om, inga kontrolltecken i texter, inga avslutande kommatecken.
    public static func las(_ text: String) throws -> JSONVarde {
        var l = Lasare(Array(text.unicodeScalars))
        l.blanka()
        let v = try l.varde()
        l.blanka()
        guard l.i == l.s.count else { throw LasFel() }
        return v
    }

    struct Lasare {
        let s: [Unicode.Scalar]
        var i = 0

        init(_ s: [Unicode.Scalar]) { self.s = s }

        var tecken: Unicode.Scalar? { i < s.count ? s[i] : nil }

        mutating func blanka() {
            while let c = tecken, c == " " || c == "\t" || c == "\n" || c == "\r" { i += 1 }
        }

        mutating func ord(_ w: String) -> Bool {
            let u = Array(w.unicodeScalars)
            guard i + u.count <= s.count, Array(s[i..<(i + u.count)]) == u else { return false }
            i += u.count
            return true
        }

        mutating func varde() throws -> JSONVarde {
            guard let c = tecken else { throw LasFel() }
            switch c {
            case "{": return try objektet()
            case "[": return try listan()
            case "\"": return .text(try texten())
            case "t": if ord("true") { return .bool(true) }
            case "f": if ord("false") { return .bool(false) }
            case "n": if ord("null") { return .null }
            default:
                if c == "-" || ("0"..."9").contains(c) { return .tal(try talet()) }
            }
            throw LasFel()
        }

        mutating func objektet() throws -> JSONVarde {
            i += 1
            var o = Objekt()
            blanka()
            if tecken == "}" {
                i += 1
                return .objekt(o)
            }
            while true {
                blanka()
                guard tecken == "\"" else { throw LasFel() }
                let k = try texten()
                blanka()
                guard tecken == ":" else { throw LasFel() }
                i += 1
                blanka()
                o[k] = try varde()
                blanka()
                if tecken == "," {
                    i += 1
                    continue
                }
                guard tecken == "}" else { throw LasFel() }
                i += 1
                return .objekt(o)
            }
        }

        mutating func listan() throws -> JSONVarde {
            i += 1
            var l: [JSONVarde] = []
            blanka()
            if tecken == "]" {
                i += 1
                return .lista(l)
            }
            while true {
                blanka()
                l.append(try varde())
                blanka()
                if tecken == "," {
                    i += 1
                    continue
                }
                guard tecken == "]" else { throw LasFel() }
                i += 1
                return .lista(l)
            }
        }

        static func siffra(_ c: Unicode.Scalar?) -> Bool { c.map { ("0"..."9").contains($0) } ?? false }

        mutating func talet() throws -> Double {
            let start = i
            if tecken == "-" { i += 1 }
            guard Self.siffra(tecken) else { throw LasFel() }
            if tecken == "0" {
                i += 1
            } else {
                while Self.siffra(tecken) { i += 1 }
            }
            if tecken == ".", i + 1 < s.count, Self.siffra(s[i + 1]) {
                i += 1
                while Self.siffra(tecken) { i += 1 }
            }
            if tecken == "e" || tecken == "E" {
                var j = i + 1
                if j < s.count, s[j] == "+" || s[j] == "-" { j += 1 }
                if j < s.count, Self.siffra(s[j]) {
                    i = j
                    while Self.siffra(tecken) { i += 1 }
                }
            }
            var t = ""
            t.unicodeScalars.append(contentsOf: s[start..<i])
            guard let v = Double(t) else { throw LasFel() }
            return v
        }

        mutating func hex4() throws -> UInt32 {
            guard i + 4 <= s.count else { throw LasFel() }
            var v: UInt32 = 0
            for c in s[i..<(i + 4)] {
                guard let h = Int(String(Character(c)), radix: 16) else { throw LasFel() }
                v = v * 16 + UInt32(h)
            }
            i += 4
            return v
        }

        mutating func texten() throws -> String {
            i += 1
            var ut = String.UnicodeScalarView()
            while true {
                guard let c = tecken else { throw LasFel() }
                i += 1
                if c == "\"" { return String(ut) }
                if c.value < 0x20 { throw LasFel() }
                guard c == "\\" else {
                    ut.append(c)
                    continue
                }
                guard let e = tecken else { throw LasFel() }
                i += 1
                switch e {
                case "\"": ut.append("\"")
                case "\\": ut.append("\\")
                case "/": ut.append("/")
                case "b": ut.append("\u{08}")
                case "f": ut.append("\u{0C}")
                case "n": ut.append("\n")
                case "r": ut.append("\r")
                case "t": ut.append("\t")
                case "u":
                    var v = try hex4()
                    if (0xD800..<0xDC00).contains(v), i + 6 <= s.count, s[i] == "\\", s[i + 1] == "u" {
                        let spar = i
                        i += 2
                        let w = try hex4()
                        if (0xDC00..<0xE000).contains(w) {
                            v = 0x10000 + ((v - 0xD800) << 10) + (w - 0xDC00)
                        } else {
                            i = spar
                        }
                    }
                    // En ensam surrogat går inte att ha i en Swift-sträng: ersättningstecknet.
                    ut.append(Unicode.Scalar(v) ?? "\u{FFFD}")
                default: throw LasFel()
                }
            }
        }
    }

    // MARK: skrivningen (underlag.py skriv)

    /// Ett tal som Python skriver det i underlaget (`underlag.tal`): heltal utan decimaler,
    /// annars den kortaste formen som läses tillbaka till samma tal.
    public static func talText(_ v: Double) -> String {
        guard v.isFinite else { return "null" }
        if v == v.rounded(), abs(v) < 1e15 { return String(Int(v)) }
        return "\(v)"
    }

    /// En text som `json.dumps(s, ensure_ascii=False)`.
    public static func textText(_ s: String) -> String {
        var ut = "\""
        for c in s.unicodeScalars {
            switch c {
            case "\"": ut += "\\\""
            case "\\": ut += "\\\\"
            case "\n": ut += "\\n"
            case "\r": ut += "\\r"
            case "\t": ut += "\\t"
            case "\u{08}": ut += "\\b"
            case "\u{0C}": ut += "\\f"
            default:
                if c.value < 0x20 {
                    let h = String(c.value, radix: 16)
                    ut += "\\u" + String(repeating: "0", count: 4 - h.count) + h
                } else {
                    ut.unicodeScalars.append(c)
                }
            }
        }
        return ut + "\""
    }

    /// JSON med varje fält och listpost på egen rad i de två yttersta nivåerna och kompakt
    /// därunder, tecken för tecken som `underlag.skriv`.
    public func skriv(_ djup: Int = 0) -> String {
        let sep = djup < 2 ? ",\n" : ","
        switch self {
        case .null: return "null"
        case let .bool(b): return b ? "true" : "false"
        case let .tal(v): return Self.talText(v)
        case let .text(s): return Self.textText(s)
        case let .lista(l):
            if l.isEmpty { return "[]" }
            let inne = l.map { $0.skriv(djup + 1) }.joined(separator: sep)
            return djup < 2 ? "[\n" + inne + "\n]" : "[" + inne + "]"
        case let .objekt(o):
            if o.nycklar.isEmpty { return "{}" }
            let inne = o.par.map { Self.textText($0.0) + ":" + $0.1.skriv(djup + 1) }.joined(separator: sep)
            return djup < 2 ? "{\n" + inne + "\n}" : "{" + inne + "}"
        }
    }
}
