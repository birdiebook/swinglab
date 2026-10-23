import Foundation
import Swing

// Från analysens leder till måtten på telefonen (PLAN S4, S4b): ett slags leder
// (`JointSeries`, S2e) görs om till en sving i S1:s form och mäts med Matt.mat,
// samma väg som PC:n går med paketet (METOD MT1), och resultatet sparas i passet.
// Passets mått (sessionen, katalogen, förra passet) räknas sedan av Swing/Visning
// ur de slag som räknas. METOD MS14

/// Ett slags mått, sparat i passet (`ShotRecord.measure`). Tiderna är lederna tidsskala:
/// s relativt klicket. METOD MS14
public struct ShotMeasure: Codable, Equatable, Sendable {
    /// Längden som gav skalan, m (METOD M2).
    public var heightM: Double
    /// Längden är standarden, inte Johannes (`AppSettings.heightM` saknas): skalan är antagen.
    public var heightAssumed: Bool
    public var cmPerPx: Double?
    /// P1–P10 som tider (s relativt klicket); en position som saknas står inte med (METOD M28).
    public var positions: [String: Double]
    /// Måtten per namn (`Matt.namn`); ett mått som inte gick att räkna står inte med.
    public var values: [String: Double]
    /// Varför slaget inte gick att mäta: "hands" (händerna syns inte före träffen),
    /// "scale" (skalans segment syns inte i adressen) eller "format"; nil när det gick.
    public var problem: String?
    /// Baksvingens start är osäker bakifrån, och tempot saknas (METOD M40); nil = säker.
    public var startUncertain: Bool?
    /// Mätningens version (`ShotMeasuring.version`); nil = 1, mätt före S1d.
    public var version: Int?
    /// Baksvingens start (s relativt klicket), för förslaget till P2 (METOD M45); nil = saknas
    /// eller mätt före S7a.
    public var start: Double?

    public init(heightM: Double, heightAssumed: Bool, cmPerPx: Double? = nil, positions: [String: Double] = [:],
                values: [String: Double] = [:], problem: String? = nil) {
        self.heightM = heightM
        self.heightAssumed = heightAssumed
        self.cmPerPx = cmPerPx
        self.positions = positions
        self.values = values
        self.problem = problem
    }

    /// Slaget gick att mäta.
    public var ok: Bool { problem == nil }
}

/// Mätningen av ett slag. METOD MS14
public enum ShotMeasuring {
    /// Längden när Johannes inte angett någon, m: skalan märks då antagen. METOD MS14
    public static let assumedHeightM = 1.80
    /// Mätningens version: ett slag mätt med en äldre mäts om. 2 = starten bakifrån ur
    /// posen (METOD M40), 3 = M41–M43 och spridningen (S1e). Samma som PC:ns
    /// `matt.MATVERSION`. METOD MS14
    public static let version = 3
    /// Längderna som går att välja i appen, cm (inom formatets 1,0–2,5 m). METOD MS14
    public static let heightChoicesCm = 140...210

    /// Ett slags leder som en sving i S1:s form (docs/FORMAT.md): rutornas tid relativt
    /// klicket, en saknad led som `[0, 0, 0]` (räknas som saknad, METOD M1), träffen
    /// `impact` (s relativt klicket) som `t_klick`, och kamerans riktning som standarden för
    /// spelhanden. Samma som PC:ns `paket.till_sving` (METOD MT1, BESLUT B12).
    public static func sving(_ s: JointSeries, view: Vy, hand: Hand, heightM: Double, impact: Double) throws -> Sving {
        let rutor = s.frames.map { f -> (t: Double, leder: [[Double]]) in
            let leder = (0..<Sving.antalLeder).map { i -> [Double] in
                guard i < f.joints.count, let j = f.joints[i], j.x.isFinite, j.y.isFinite, j.c.isFinite else {
                    return [0, 0, 0]
                }
                return [j.x, j.y, j.c]
            }
            return (t: f.t, leder: leder)
        }
        return try Sving.las(vy: view, hand: hand, langdM: heightM, tKlick: impact, rutor: rutor)
    }

    /// Slagets mått ur dess leder. `height` = Johannes längd i m, nil = standarden (antagen).
    /// Ett slag som inte går att mäta får `problem` i stället för måtten. METOD MS14
    public static func measure(_ s: JointSeries, shot: ShotRecord, setup: PassSetup, height: Double?) -> ShotMeasure {
        let h = height ?? assumedHeightM
        var ut = ShotMeasure(heightM: h, heightAssumed: height == nil)
        ut.version = version
        do {
            let sv = try sving(s, view: setup.view, hand: setup.hand, heightM: h, impact: shot.impact - shot.click.time)
            let r = try Matt.mat(sv)
            ut.cmPerPx = r.cmPerPx
            for p in Positioner.namn {
                if let t = r.positioner.tid(p), t.isFinite { ut.positions[p] = t }
            }
            ut.values = r.matt.filter { $0.value.isFinite }
            ut.startUncertain = r.faser.startOsaker ? true : nil
            ut.start = r.faser.start.flatMap { $0.isFinite ? $0 : nil }
            // Klubbans mått ur markeringarna (S7a, METOD M46–M49) bland slagets mått, och rutan
            // han valde för P2, P6 och P8 som slagets position (M45). Samma som PC:ns analys.
            if let marks = shot.klubba, !marks.isEmpty {
                for (k, v) in Klubba.mat(marks, vy: setup.view, xTecken: sv.xTecken, bredd: s.width, hojd: s.height,
                                         sving: sv) where v.isFinite {
                    ut.values[k] = v
                }
                for m in marks where Klubba.skaftets.contains(m.position) && m.markerad {
                    ut.positions[m.position] = m.t
                }
            }
        } catch SvingFel.handernaSaknas {
            ut.problem = "hands"
        } catch SvingFel.skalanSaknas {
            ut.problem = "scale"
        } catch {
            ut.problem = "format"
        }
        return ut
    }
}

extension ShotRecord {
    /// Slaget räknas i passets mått: en sving eller osäkert (METOD MT1), mätt, och inte
    /// märkt "Detection wrong" (BESLUT B35). METOD MS14
    public var counts: Bool {
        wantsDetail && detectionWrong != true && measure?.ok == true
    }
}

extension PassState {
    /// Slaget har leder men inga mått, mått med en annan längd än den som gäller nu, eller
    /// mått från en äldre version av mätningen (METOD MS14, M40).
    public func needsMeasure(_ shot: ShotRecord, height: Double?) -> Bool {
        guard shot.joints != nil else { return false }
        guard let m = shot.measure else { return true }
        return m.heightAssumed != (height == nil) || m.heightM != (height ?? ShotMeasuring.assumedHeightM)
            || (m.version ?? 1) < ShotMeasuring.version
    }

    /// Mäter (om) slagen som behöver det med passets egen längd (`heightM`, METOD MS16).
    @discardableResult
    public mutating func measureShots(joints: (ShotRecord) -> JointSeries?) -> Bool {
        measureShots(height: heightM, joints: joints)
    }

    /// Mäter (om) slagen som behöver det; `joints` läser ett slags leder. Svarar om något
    /// ändrades (då ska passet sparas). Ett pass från före S4b får sina mått här. METOD MS14
    @discardableResult
    public mutating func measureShots(height: Double?, joints: (ShotRecord) -> JointSeries?) -> Bool {
        var andrat = false
        for i in shots.indices where needsMeasure(shots[i], height: height) {
            guard let s = joints(shots[i]) else { continue }
            shots[i].measure = ShotMeasuring.measure(s, shot: shots[i], setup: setup, height: height)
            andrat = true
        }
        return andrat
    }

    /// Klubbans markeringar för ett slag (S7a): sparas i slaget och slaget mäts om med passets
    /// längd, så att klubbmåtten och P2, P6 och P8 följer markeringarna. `joints` = slagets
    /// leder. METOD M45, BESLUT B47
    public mutating func setClubMarks(_ marks: [KlubbMarkering], shot id: String, joints: JointSeries) {
        guard let i = shots.firstIndex(where: { $0.id == id }) else { return }
        shots[i].klubba = marks.isEmpty ? nil : marks.sorted {
            (Klubba.positioner.firstIndex(of: $0.position) ?? 99) < (Klubba.positioner.firstIndex(of: $1.position) ?? 99)
        }
        shots[i].measure = ShotMeasuring.measure(joints, shot: shots[i], setup: setup, height: heightM)
    }

    /// Slagen som räknas och har klubban markerad (S7a): passet visar antalet.
    public var clubMarkedCount: Int { shots.filter { $0.counts && $0.klubbaMarkerad }.count }

    /// Johannes märker slaget "Detection wrong", eller ångrar det. BESLUT B35
    public mutating func setDetectionWrong(_ wrong: Bool, shot id: String) {
        guard let i = shots.firstIndex(where: { $0.id == id }) else { return }
        shots[i].detectionWrong = wrong ? true : nil
    }

    /// Måtten för slagen som räknas, i passets ordning, med passets vy.
    public var countedSwings: [SvingMatt] {
        shots.filter(\.counts).compactMap { s in s.measure.map { SvingMatt(vy: setup.view, matt: $0.values) } }
    }

    /// Passet som vyerna ser det (Swing/Visning): dagen, klubban, svingarna som räknas och
    /// serie 1 (de första fem i serie 1, METOD MT2).
    public var visningsPass: Swing.Pass {
        let forsta = series.map(\.nr).min()
        let iSerie1 = shots.filter { $0.counts && $0.series == forsta }.count
        return Swing.Pass(datum: created, klubba: PassSetup.clubLabel(setup.club), svingar: countedSwings,
                          serie1: Swift.min(PassHistory.firstSet, iSerie1),
                          osakerStart: shots.filter { $0.counts && $0.measure?.startUncertain == true }.count,
                          klubbMarkerade: clubMarkedCount)
    }

    /// Längden som slagens mått bär, och om den är antagen: den första mätta. nil = inget mätt.
    public var measuredHeight: (heightM: Double, assumed: Bool)? {
        shots.compactMap(\.measure).first.map { ($0.heightM, $0.heightAssumed) }
    }
}

/// Passen före: baslinjen och "vs" (METOD M26, M27). METOD MS14
public enum PassHistory {
    /// Första serien är de fem första slagen i serie 1. METOD MT2
    public static let firstSet = 5

    /// Passen före `nu` som kan jämföras: skapade före, med samma klubba och samma vy
    /// (kameran på samma plats, research 1 del 4). Äldst först.
    public static func candidates(_ nu: PassState, among alla: [PassState]) -> [PassState] {
        alla.filter { p in
            p.id != nu.id && p.created < nu.created && p.setup.club == nu.setup.club && p.setup.view == nu.setup.view
        }
        .sorted { $0.created < $1.created || ($0.created == $1.created && $0.id < $1.id) }
    }

    /// De tidigare passen att jämföra med (baslinjen och "vs"): kandidaterna med minst ett
    /// slag som räknas och mätta med **samma längd** som `nu`, så att ett mått i cm aldrig
    /// jämförs mellan två skalor. Appen mäter först om passen med längden som gäller
    /// (`measureShots`), så att bara pass utan leder faller bort; dem räknar `unmeasured`.
    public static func earlier(_ nu: PassState, among alla: [PassState]) -> [PassState] {
        let h = nu.measuredHeight?.heightM
        return candidates(nu, among: alla).filter { p in
            !p.countedSwings.isEmpty && (h == nil || p.measuredHeight?.heightM == h)
        }
    }

    /// Kandidaterna som inte kom med i `earlier`: utan mätta slag, eller med en annan längd.
    public static func unmeasured(_ nu: PassState, among alla: [PassState]) -> Int {
        candidates(nu, among: alla).count - earlier(nu, among: alla).count
    }

    /// Det senaste passet med slag som räknas (Idag, Utveckling): det sist skapade. METOD MS16
    public static func latest(_ alla: [PassState]) -> PassState? {
        alla.filter { !$0.countedSwings.isEmpty }.max { ($0.created, $0.id) < ($1.created, $1.id) }
    }

    /// Passen i Utveckling (METOD MS16): samma regel som baslinjen (MS14) räknad från det
    /// senaste passet. Samma klubba, slag som räknas och samma längd, äldst först; vyn väljer
    /// varje mått själv (ett FO-mått har bara FO-passens svingar). Pass med samma klubba som
    /// inte kom med räknas var för sig: `unmeasured` utan slag som räknas, `otherHeight` mätta
    /// med en annan längd. Ett pass med en annan klubba hör inte hit och räknas inte.
    public static func progress(_ alla: [PassState]) -> (passes: [PassState], unmeasured: Int, otherHeight: Int) {
        guard let nu = latest(alla) else { return ([], 0, 0) }
        let h = nu.measuredHeight?.heightM
        let klubba = alla.filter { $0.setup.club == nu.setup.club }
        let matta = klubba.filter { !$0.countedSwings.isEmpty }
        let med = matta.filter { $0.measuredHeight?.heightM == h }
            .sorted { ($0.created, $0.id) < ($1.created, $1.id) }
        return (med, klubba.count - matta.count, matta.count - med.count)
    }

    /// Måttens värden i de tidigare passen (alla slag som räknas), för den egna baslinjen.
    public static func baseline(_ tidigare: [PassState]) -> [String: [Double]] {
        var ut: [String: [Double]] = [:]
        for p in tidigare {
            for s in p.countedSwings {
                for (k, v) in s.matt where v.isFinite { ut[k, default: []].append(v) }
            }
        }
        return ut
    }
}
