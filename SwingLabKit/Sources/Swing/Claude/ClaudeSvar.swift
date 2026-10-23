import Foundation

/// Svaret från Claude-appen (S5b, "Paste from Claude"): urklippet tolkas, filen tas ur det
/// sista kodblocket som går att läsa som en `att_jobba_pa.json`, och den kontrolleras med samma
/// regler och felkoder som PC:n (`ur_text` och `las_svar` i tools/pc/att_jobba_pa.py, BESLUT
/// B54). En godkänd fil sparas som en från PC:n (`FocusInbox`, `Store.focus`). METOD MT12
public enum ClaudeSvar {
    public enum Resultat: Sendable {
        /// Filen som JSON att spara, och den tolkad.
        case godkand(data: Data, focus: AttJobbaPa)
        /// Felen: fältet och koden, aldrig värdet.
        case fel([Kontrollfel])

        public var felen: [Kontrollfel] {
            if case let .fel(f) = self { return f }
            return []
        }
    }

    /// Tecken som telefonen eller ett anteckningsprogram byter till: typografiska citattecken
    /// blir raka, hårda mellanslag vanliga, BOM och nollbredda tecken tas bort. Bara när blocket
    /// inte går att läsa som det står. METOD MT12
    static let utbyten: [Unicode.Scalar: String] = [
        "\u{201C}": "\"", "\u{201D}": "\"", "\u{201E}": "\"", "\u{201F}": "\"", "\u{2033}": "\"",
        "\u{00A0}": " ", "\u{202F}": " ", "\u{2007}": " ", "\u{FEFF}": "", "\u{200B}": "",
    ]

    static func normalisera(_ s: String) -> String {
        var ut = ""
        for c in s.unicodeScalars {
            if let b = utbyten[c] { ut += b } else { ut.unicodeScalars.append(c) }
        }
        return ut
    }

    /// Kodblocken i ordning: det mellan en rad som börjar med ``` (med valfri märkning) och nästa
    /// ```, som `kodblock` i Python.
    public static func kodblock(_ text: String) -> [String] {
        let s = Array(text.unicodeScalars)
        let n = s.count
        func tre(_ i: Int) -> Bool { i + 3 <= n && s[i] == "`" && s[i + 1] == "`" && s[i + 2] == "`" }
        func stycke(_ a: Int, _ b: Int) -> String {
            var t = ""
            t.unicodeScalars.append(contentsOf: s[a..<b])
            return t
        }
        var ut: [String] = []
        var i = 0
        while i + 3 <= n {
            if tre(i) {
                var j = i + 3
                while j < n, s[j] != "\n", s[j] != "`" { j += 1 }
                if j < n, s[j] == "\n" {
                    var k = j + 1
                    while k + 3 <= n, !tre(k) { k += 1 }
                    if tre(k) {
                        ut.append(stycke(j + 1, k))
                        i = k + 3
                        continue
                    }
                }
            }
            i += 1
        }
        return ut
    }

    /// Filen ur svaret, eller felet: inget kodblock, ett block som inte är JSON, eller inget
    /// block med en `att_jobba_pa.json` (ett objekt med `format` eller `saker`). METOD MT12
    public static func urText(_ text: String) -> (fil: JSONVarde?, fel: [Kontrollfel]) {
        let block = kodblock(text)
        var kandidater = block
        if block.isEmpty {
            kandidater = [text]
            let s = Array(text.unicodeScalars)
            if let a = s.firstIndex(of: "{"), let b = s.lastIndex(of: "}"), b > a {
                var t = ""
                t.unicodeScalars.append(contentsOf: s[a...b])
                kandidater.append(t)
            }
        }
        var lasbar = false
        for b in kandidater.reversed() {
            for variant in [b, normalisera(b)] {
                guard let v = try? JSONVarde.las(variant) else { continue }
                lasbar = true
                if let o = v.somObjekt, o["format"] != nil || o["saker"] != nil { return (v, []) }
                break
            }
        }
        if lasbar { return (nil, [Kontrollfel("svaret", "inte_att_jobba_pa")]) }
        if !block.isEmpty { return (nil, [Kontrollfel("svaret", "inte_json")]) }
        return (nil, [Kontrollfel("svaret", "inget_block")])
    }

    /// Svaret kontrollerat mot passets analys och minnet före passet. En godkänd fil läses också
    /// som telefonen läser en fil från PC:n (`AttJobbaPa.las`); går det inte är felet filens.
    public static func las(_ text: String, analys: Passanalys, ovningar: [Ovningslage], katalog: Katalog,
                           kedjor: Kedjor = .appens) -> Resultat {
        let (fil, fel) = urText(text)
        guard let fil else { return .fel(fel) }
        let k = AttJobbaPaKontroll.kontrollera(fil, analys: analys, ovningar: ovningar, katalog: katalog, kedjor: kedjor)
        if !k.isEmpty { return .fel(k) }
        let data = Data((fil.skriv() + "\n").utf8)
        guard let focus = try? AttJobbaPa.las(data) else { return .fel([Kontrollfel("filen", "objekt")]) }
        return .godkand(data: data, focus: focus)
    }
}
