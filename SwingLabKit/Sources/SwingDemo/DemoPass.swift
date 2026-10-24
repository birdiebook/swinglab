import Foundation
import Swing
import Capture

/// Påhittade pass som de ligger på telefonen (S4c): serier med klick, slag med domen sving
/// och påhittade leder ur DemoSving (FO), men inga mått. Appens egen väg (Store, mätningen
/// med passets längd, flikarna) räknar talen, så att provet visar riktiga tal ur appen.
/// Inga riktiga svingar (CLAUDE.md, Dataregeln). METOD MS16
public enum DemoPass {
    /// Klicken i passets två serier, s i filen: fem slag i serie 1 och tre i serie 2.
    public static let klick: [[Double]] = [[4, 10, 16, 22, 28], [4, 10, 16]]

    /// Ett FO-pass med `sway.count` slag (högst åtta), swayen vid toppen per slag i cm, i
    /// seriernas ordning. Svarar passet (slagen med sökvägen till lederna, inga mått) och
    /// lederna per slag, att skriva till `Leder/<slag>.json`.
    public static func fo(id: String, created: Date, club: String = "j7", heightM: Double? = nil,
                          sway: [Double]) -> (pass: PassState, leder: [String: JointSeries]) {
        bygg(.fo, id: id, created: created, club: club, heightM: heightM, antal: sway.count) { i in
            DemoSving.fo(sway: (topp: sway[i], traff: 2, finish: 4))
        }
    }

    /// Ett DTL-pass som `fo`: bäckenets thrust vid toppen per slag i cm (PLAN S4e, sessionerna
    /// med båda vyerna).
    public static func dtl(id: String, created: Date, club: String = "j7", heightM: Double? = nil,
                           thrust: [Double]) -> (pass: PassState, leder: [String: JointSeries]) {
        bygg(.dtl, id: id, created: created, club: club, heightM: heightM, antal: thrust.count) { i in
            DemoSving.dtl(thrust: (topp: thrust[i], traff: 3, finish: 8))
        }
    }

    static func bygg(_ vy: Vy, id: String, created: Date, club: String, heightM: Double?, antal: Int,
                     sving: (Int) -> Sving) -> (pass: PassState, leder: [String: JointSeries]) {
        var p = PassState(id: id, created: created, setup: PassSetup(view: vy, club: club, distance: 3, hand: .hoger),
                          heightM: heightM)
        var kvar = antal
        for (k, tider) in klick.enumerated() where kvar > 0 {
            let t = Array(tider.prefix(kvar))
            kvar -= t.count
            let timing = FrameTiming.analyze((0..<10).map { Double($0) / 240 })
            p.series.append(SeriesRecord(nr: k + 1, source: .recording, club: club, file: PassState.videoPath(nr: k + 1),
                                         start: created, startHost: nil, duration: 32, bytes: 1, timing: timing,
                                         clicks: t.map { Click(time: $0, strength: 50) }, orientation: 6,
                                         uprightWidth: 1080, uprightHeight: 1920))
        }
        p.syncShots()
        var leder: [String: JointSeries] = [:]
        for i in p.shots.indices {
            let s = p.shots[i]
            p.shots[i].verdict = .swing
            p.shots[i].joints = ShotRecord.jointsPath(s.id)
            p.shots[i].clip = ShotRecord.clipPath(s.id)          // analysen klar (ShotPlan.next == nil)
            leder[s.id] = serie(sving(i), klick: s.click.time)
        }
        p.status = .analyzed
        return (p, leder)
    }

    /// En sving som analysens leder: t relativt klicket, pts i filen (klicket vid `klick`),
    /// lederna i filens ordning med konfidensen 0,9; en saknad led saknas.
    public static func serie(_ sv: Sving, klick: Double) -> JointSeries {
        let frames = sv.t.indices.map { k -> PoseFrame in
            let leder = (0..<Sving.antalLeder).map { i -> PoseJoint? in
                let q = sv.leder[i][k]
                return q.hel ? PoseJoint(x: q.x, y: q.y, c: 0.9) : nil
            }
            return PoseFrame(t: sv.t[k] - sv.tKlick, pts: sv.t[k] - sv.tKlick + klick, joints: leder, confidence: 0.9)
        }
        return JointSeries(width: 1080, height: 1920, frames: frames)
    }
}
