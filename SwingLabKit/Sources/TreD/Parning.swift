import Capture
import Foundation
import Swing

/// Hur slagen parades (analys.json `tre_d.parning`). METOD MK1
public struct TreDParning: Equatable, Sendable, Codable {
    public struct Serie: Equatable, Sendable, Codable {
        public var dtl: Int
        public var fo: Int
        /// "par.json" eller "klicken".
        public var kalla: String
        public var par: Int
    }

    public var kalla: String
    public var serier: [Serie]
    public var par: Int
    /// Slag per vy ("dtl", "fo") som inte parades.
    public var oparade: [String: Int]
    public var parJsonFel: String?

    enum CodingKeys: String, CodingKey {
        case kalla, serier, par, oparade
        case parJsonFel = "par_json_fel"
    }
}

/// Parningen av två telefoners slag, som tools/pc/tva_kameror.py `para_slag`. METOD MK1
public enum Parning {
    /// Klicken paras utan förhandsvärde: varje skillnad b − a prövas, den som parar flest
    /// inom toleransen förfinas med ClickPairing kring sig. Osäker med färre än 3 par
    /// eller när en annan förskjutning minst 2 · toleransen bort parar lika många. METOD MK1
    public static func utanPrior(_ a: [Double], _ b: [Double]) -> ClickPairing {
        let tol = ClickPairing.defaultTolerance
        guard !a.isEmpty, !b.isEmpty else {
            return ClickPairing(offset: 0, pairs: [], count: 0, secondBestOffset: nil, secondBestCount: 0,
                                uncertain: true)
        }
        var kand: [Double] = []
        for x in a {
            for y in b { kand.append(((y - x) * 1e4).rounded(.toNearestOrEven) / 1e4) }
        }
        kand = Array(Set(kand)).sorted()
        let antal = kand.map { d -> Int in
            b.filter { y in a.map { abs($0 + d - y) }.min()! < tol }.count
        }
        var i = 0
        for k in 1..<max(antal.count, 1) where antal[k] > antal[i] { i = k }
        let bast = kand[i], flest = antal[i]
        var nast = 0
        for (k, d) in kand.enumerated() where abs(d - bast) >= 2 * tol { nast = max(nast, antal[k]) }
        var r = ClickPairing.pair(a, b, prior: bast, priorWindow: tol)
        r.count = flest
        r.uncertain = flest < ClickPairing.minPairsWithoutPrior || nast >= flest
        return r
    }

    /// Slagen som båda telefonerna filmat: [(DTL-slaget, FO-slaget)] och hur de paras. Ur
    /// den styrande telefonens par.json när den gäller paret, annars ur klicken, serie mot
    /// serie, flest par först. Paketen i fel ordning (eller två av samma vy) är ett fel.
    /// METOD MK1, BESLUT B48
    public static func paraSlag(_ dtl: TreDPaket, _ fo: TreDPaket) throws -> (par: [(TreDSlag, TreDSlag)], info: TreDParning) {
        guard dtl.vy == .dtl, fo.vy == .fo else {
            throw TreDFel(skal: "parningen: paketen ska vara ett DTL- och ett FO-paket")
        }
        let styr = [dtl, fo].first { $0.par != nil && $0.par?.vy == $0.vy }
        let styrArDtl = styr?.vy == .dtl
        var par: [(TreDSlag, TreDSlag)] = []
        var serier: [TreDParning.Serie] = []
        var anvanda = Set<String>()

        func klick(_ p: TreDPaket, _ serie: Int) -> [TreDSlag] { p.slag.filter { $0.serie == serie } }
        func nyckel(_ vy: Vy, _ serie: Int) -> String { "\(vy.rawValue)-\(serie)" }

        if let styr, let pf = styr.par {
            let folj = styrArDtl ? fo : dtl
            for rad in pf.serier {
                guard rad.foljareVy == folj.vy, rad.foljarePass == folj.passID, styr.serier[rad.serie] != nil,
                      folj.serier[rad.foljareSerie] != nil else { continue }
                let sa = klick(styr, rad.serie), sb = klick(folj, rad.foljareSerie)
                let a = sa.map(\.klickS), b = sb.map(\.klickS)
                let r: ClickPairing
                let kalla: String
                if rad.osaker {
                    r = utanPrior(a, b)
                    kalla = "klicken"
                } else {
                    r = ClickPairing.pair(a, b, prior: rad.forskjutningS, priorWindow: ClickPairing.defaultTolerance)
                    kalla = "par.json"
                }
                if r.uncertain { continue }
                for p in r.pairs {
                    par.append(styrArDtl ? (sa[p.a], sb[p.b]) : (sb[p.b], sa[p.a]))
                }
                anvanda.insert(nyckel(styr.vy, rad.serie))
                anvanda.insert(nyckel(folj.vy, rad.foljareSerie))
                serier.append(TreDParning.Serie(dtl: styrArDtl ? rad.serie : rad.foljareSerie,
                                                fo: styrArDtl ? rad.foljareSerie : rad.serie, kalla: kalla,
                                                par: r.pairs.count))
            }
        }
        // Serier som par.json inte parat: klicken, serie mot serie, flest par först.
        var forslag: [(n: Int, sd: Int, sf: Int, sa: [TreDSlag], sb: [TreDSlag], r: ClickPairing)] = []
        for sd in dtl.serier.keys.sorted() {
            for sf in fo.serier.keys.sorted() {
                if anvanda.contains(nyckel(.dtl, sd)) || anvanda.contains(nyckel(.fo, sf)) { continue }
                let sa = klick(dtl, sd), sb = klick(fo, sf)
                let r = utanPrior(sa.map(\.klickS), sb.map(\.klickS))
                if !r.uncertain { forslag.append((-r.pairs.count, sd, sf, sa, sb, r)) }
            }
        }
        forslag.sort { ($0.n, $0.sd, $0.sf) < ($1.n, $1.sd, $1.sf) }
        for f in forslag {
            if anvanda.contains(nyckel(.dtl, f.sd)) || anvanda.contains(nyckel(.fo, f.sf)) { continue }
            for p in f.r.pairs { par.append((f.sa[p.a], f.sb[p.b])) }
            anvanda.insert(nyckel(.dtl, f.sd))
            anvanda.insert(nyckel(.fo, f.sf))
            serier.append(TreDParning.Serie(dtl: f.sd, fo: f.sf, kalla: "klicken", par: f.r.pairs.count))
        }
        let info = TreDParning(kalla: styr != nil ? "par.json" : "klicken", serier: serier, par: par.count,
                               oparade: ["dtl": dtl.slag.count - par.count, "fo": fo.slag.count - par.count],
                               parJsonFel: dtl.parFel ?? fo.parFel)
        return (par, info)
    }
}
