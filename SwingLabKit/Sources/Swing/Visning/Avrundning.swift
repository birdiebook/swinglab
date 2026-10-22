import Foundation

/// Decimalregeln, samma som PC:ns (`tools/pc/analys.py`, `enhet` och `avrunda`,
/// METOD MT3): cm och grader med en decimal, tempot och sekunder med två. Telefonen
/// visar `att_jobba_pa.json`:s tal med samma regel, så att den aldrig avrundar om
/// PC:ns tal (5,9° blir inte 6°), och Passet, Idag och Utveckling använder den också.
public enum Avrundning {
    /// Måttets enhet som PC:n skriver den: "cm", "°", "s" eller "".
    public static func enhet(_ matt: String) -> String {
        if matt == "tempo" || matt == "stans_bredd" { return "" }
        if matt.hasSuffix("_s") { return "s" }
        if ["bojning", "lutning", "kna", "armbage"].contains(where: { matt.contains($0) }) { return "°" }
        return "cm"
    }

    /// Decimalerna för en enhet: två för kvoter och sekunder, annars en.
    public static func decimaler(enhet: String) -> Int {
        enhet == "" || enhet == "s" ? 2 : 1
    }

    public static func decimaler(_ matt: String) -> Int {
        decimaler(enhet: enhet(matt))
    }

    /// Talet som visas, avrundat som PC:n gör (halvor bort från noll på decimaltalet;
    /// PC:ns tal i filen är redan avrundade, så de visas oförändrade).
    public static func avrunda(_ matt: String, _ v: Double?) -> Double? {
        guard let v, v.isFinite else { return nil }
        let k = pow(10, Double(decimaler(matt)))
        return (v * k).rounded() / k
    }
}
