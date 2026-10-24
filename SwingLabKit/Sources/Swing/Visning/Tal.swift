import Foundation

/// Talen och datumen som vyn visar (BESLUT B13, design/README.md regel 4 och 7):
/// decimalpunkt och engelska datum (BESLUT B30), typografiskt minus och tecken på
/// förändringar. Räknas för hand, inte med NumberFormatter, så att telefonens språk
/// inte spelar in och Linux ger samma text som telefonen. Orden står i Texter.
public enum Tal {
    /// U+2212, samma bredd som plus i tabellsiffror.
    public static let minus = "\u{2212}"

    /// |v| med `decimaler` decimaler och decimalpunkt, utan tecken.
    static func belopp(_ v: Double, _ decimaler: Int) -> String {
        String(format: "%.\(Swift.max(0, decimaler))f", abs(v))
    }

    /// Avrundat till noll? Då visas inget minus ("−0.0").
    static func noll(_ v: Double, _ decimaler: Int) -> Bool {
        abs(v) < 0.5 * pow(10, -Double(Swift.max(0, decimaler)))
    }

    /// Ett värde: "−2.4", "11.3". Saknas värdet: "—".
    public static func tal(_ v: Double?, decimaler: Int) -> String {
        guard let v, v.isFinite else { return "—" }
        return (v < 0 && !noll(v, decimaler) ? minus : "") + belopp(v, decimaler)
    }

    /// En förändring eller ett mått med riktning: "+1.2", "−2.4", "±0.0".
    public static func tecken(_ v: Double?, decimaler: Int) -> String {
        guard let v, v.isFinite else { return "—" }
        if noll(v, decimaler) { return "±" + belopp(0, decimaler) }
        return (v > 0 ? "+" : minus) + belopp(v, decimaler)
    }

    /// En gräns på en axel: högst `decimaler` decimaler, utan nollor på slutet ("0", "2.5").
    public static func axel(_ v: Double, decimaler: Int) -> String {
        var s = tal(v, decimaler: decimaler)
        guard s.contains(".") else { return s }
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s == minus + "0" ? "0" : s
    }

    /// Enheten efter ett tal i löptext: grader sitter ihop, kvoten ": 1" utelämnas.
    public static func medEnhet(_ tal: String, _ enhet: String) -> String {
        switch enhet {
        case "": return tal
        case "°": return tal + "°"
        case ": 1": return tal
        default: return tal + " " + enhet
        }
    }

    // MARK: datumen

    public static var manader: [String] { Texter.manader }
    public static var veckodagar: [String] { Texter.veckodagar }

    /// Svensk tid, oavsett telefonens zon, så att ett pass har samma datum överallt.
    public static let kalender: Calendar = {
        var k = Calendar(identifier: .gregorian)
        k.timeZone = TimeZone(identifier: "Europe/Stockholm") ?? TimeZone(secondsFromGMT: 3600)!
        k.firstWeekday = 2
        return k
    }()

    /// "Jan 6"
    public static func datum(_ d: Date) -> String {
        let c = kalender.dateComponents([.day, .month], from: d)
        return Texter.datum(dag: c.day ?? 0, manad: manader[((c.month ?? 1) - 1) % 12])
    }

    /// "Fri, Jan 9"
    public static func dag(_ d: Date) -> String {
        let v = kalender.component(.weekday, from: d)
        return Texter.dag(veckodag: veckodagar[(v - 1) % 7], datum: datum(d))
    }

    /// "18:05": klockslaget i svensk tid (sessionslistan, METOD MS20).
    public static func klocka(_ d: Date) -> String {
        let c = kalender.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    /// "Jan"
    public static func manad(_ d: Date) -> String {
        manader[(kalender.component(.month, from: d) - 1) % 12]
    }

    /// Ett datum i svensk tid, för demodatan och testerna.
    public static func dag(_ ar: Int, _ manad: Int, _ dag: Int, timme: Int = 12) -> Date {
        kalender.date(from: DateComponents(year: ar, month: manad, day: dag, hour: timme))!
    }
}
