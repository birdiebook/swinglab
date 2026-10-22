import Foundation
import XCTest
@testable import Capture
import Swing

/// Lederna, personvalet och svingdomen på PÅHITTADE figurer (S2_SPEC §4.3, §6.3).
/// METOD MS5, MS7, MS8
final class LederTests: XCTestCase {
    static let bredd = 1080, hojd = 1920

    /// En stående figur (y nedåt) med händerna i `hander`, förskjuten dx i x och skalad
    /// kring fötterna. H = fotledernas mitt − näsan = 1150 px vid skala 1.
    static func figur(hander: (x: Double, y: Double), dx: Double = 0, skala: Double = 1, c: Double = 0.9,
                      utan: Set<Int> = []) -> [PoseJoint?] {
        let pkt: [(Double, Double)] = [
            (540, 500),                         // nasa
            (600, 650), (480, 650),             // axel_v, axel_h (figuren vänd mot kameran)
            (620, 850), (460, 850),             // armbågar
            (hander.x + 10, hander.y), (hander.x - 10, hander.y),   // handleder
            (580, 1050), (500, 1050),           // höfter
            (590, 1350), (490, 1350),           // knän
            (600, 1650), (480, 1650),           // fotleder
        ]
        return pkt.enumerated().map { i, p -> PoseJoint? in
            utan.contains(i) ? nil : PoseJoint(x: (p.0 - 540) * skala + 540 + dx, y: 1650 - (1650 - p.1) * skala, c: c)
        }
    }

    static let H = 1150.0

    /// Händerna i en påhittad sving: adress, upp till toppen över huvudet vid −0,5 s,
    /// ned, och 3 kroppslängder per sekund genom träffen.
    static func hander(_ t: Double, stilla: Bool, fart: Double = 3) -> (x: Double, y: Double) {
        if stilla { return (540, 1000) }
        func lerp(_ a: (Double, Double), _ b: (Double, Double), _ u: Double) -> (x: Double, y: Double) {
            (a.0 + (b.0 - a.0) * u, a.1 + (b.1 - a.1) * u)
        }
        switch t {
        case ..<(-1.2): return (540, 1000)
        case ..<(-0.5): return lerp((540, 1000), (700, 450), (t + 1.2) / 0.7)
        case ..<(-0.15): return lerp((700, 450), (540 - 0.45 * H, 1000), (t + 0.5) / 0.35)
        default: return (540 + fart * H * t, 1000)
        }
    }

    /// Den glesa serien: var 8:e ruta vid 240 bilder/s i [−1,6, +0,1] s.
    static func serie(stilla: Bool = false, fart: Double = 3, utan: (Int) -> Set<Int> = { _ in [] }) -> JointSeries {
        let frames = (0...51).map { k -> PoseFrame in
            let t = -1.6 + Double(k) / 30
            return PoseFrame(t: t, pts: 10 + t, joints: figur(hander: hander(t, stilla: stilla, fart: fart), utan: utan(k)),
                             confidence: 0.9)
        }
        return JointSeries(width: bredd, height: hojd, frames: frames)
    }

    func testNamnenArFormatets() {
        XCTAssertEqual(JointSeries.names, Sving.lederIFilen)
        XCTAssertEqual(Self.figur(hander: (540, 1000)).count, JointSeries.names.count)
    }

    func testEnSvingArEttSlag() {
        XCTAssertEqual(SwingCheck.verdict(Self.serie()), .swing)
    }

    func testFartgransenTvaKroppslangderPerSekund() {
        // Händerna genom träffen i 2,1 H/s räcker, 1,9 H/s inte (METOD MS5).
        XCTAssertEqual(SwingCheck.verdict(Self.serie(fart: 2.1)), .swing)
        XCTAssertEqual(SwingCheck.verdict(Self.serie(fart: 1.9)), .notSwing)
        XCTAssertEqual(SwingCheck.minSpeed, 2.0)
    }

    func testStillaHanderArInteEttSlag() {
        XCTAssertEqual(SwingCheck.verdict(Self.serie(stilla: true)), .notSwing)
    }

    func testHanderUtanToppArInteEttSlag() {
        // Snabba vid klicket men aldrig över axlarna (klubban mot mattan, en vift).
        var s = Self.serie()
        s.frames = s.frames.map { f in
            var g = f
            if f.t < -0.15 { g.joints = Self.figur(hander: (540, 1000)) }
            return g
        }
        XCTAssertEqual(SwingCheck.verdict(s), .notSwing)
    }

    func testSaknadeLederArOsakert() {
        XCTAssertEqual(SwingCheck.verdict(Self.serie(utan: { $0 % 2 == 0 ? [9, 10] : [] })), .uncertain)
        XCTAssertEqual(SwingCheck.verdict(JointSeries(width: 1080, height: 1920, frames: [])), .uncertain)
        // Låg konfidens räknas som saknad (METOD MS8): 0,09 i varannan ruta.
        var s = Self.serie()
        for k in stride(from: 0, to: s.frames.count, by: 2) {
            s.frames[k].joints = Self.figur(hander: Self.hander(s.frames[k].t, stilla: false), c: 0.09)
        }
        XCTAssertEqual(SwingCheck.verdict(s), .uncertain)
        // Ett saknat knä i var femte ruta håller (79 % hela), i 42 % av rutorna inte (58 %).
        XCTAssertEqual(SwingCheck.verdict(Self.serie(utan: { $0 % 5 == 0 ? [9] : [] })), .swing)
        XCTAssertEqual(SwingCheck.verdict(Self.serie(utan: { $0 % 5 < 2 ? [9] : [] })), .uncertain)
    }

    func testOrienteringenMisstankt() {
        let upp = Self.serie()
        XCTAssertFalse(upp.orientationSuspect)
        // En liggande kropp: fotlederna till höger om näsan på samma höjd.
        var ligg = upp
        ligg.frames = ligg.frames.map { f in
            var g = f
            g.joints = f.joints.map { j in j.map { PoseJoint(x: 1650 - $0.y + 200, y: $0.x + 400, c: $0.c) } }
            return g
        }
        XCTAssertTrue(ligg.orientationSuspect)
        XCTAssertTrue(JointSeries.passSuspect([ligg, ligg, upp]))
        XCTAssertFalse(JointSeries.passSuspect([ligg, upp]))
        XCTAssertFalse(JointSeries(width: 1080, height: 1920, frames: []).orientationSuspect)
    }

    func testPersonvalet() {
        func kand(_ dx: Double, _ skala: Double, utan: Set<Int> = []) -> PoseFrame {
            PoseFrame(t: 0, pts: 0, joints: Self.figur(hander: (540, 1000), dx: dx, skala: skala, utan: utan), confidence: 0.8)
        }
        let grannen = kand(-420, 0.35)      // liten och långt till vänster
        let johannes = kand(10, 1.0)
        let annan = kand(380, 0.95)
        let utanHoft = kand(0, 1.0, utan: [7, 8])
        XCTAssertEqual(PosePicker.pick([grannen, annan, johannes, utanHoft], previousHipMid: nil, width: 1080), 2)
        // En liten figur mitt i bild väljs inte före en stor bredvid.
        XCTAssertEqual(PosePicker.pick([kand(0, 0.3), annan], previousHipMid: nil, width: 1080), 1)
        // Sedan: närmast föregående höfter.
        XCTAssertEqual(PosePicker.pick([johannes, annan], previousHipMid: (920, 1050), width: 1080), 1)
        XCTAssertEqual(PosePicker.pick([johannes, annan], previousHipMid: (560, 1050), width: 1080), 0)
        XCTAssertNil(PosePicker.pick([utanHoft], previousHipMid: nil, width: 1080))
        // En osäker observation (confidence < 0,6, METOD MS8) väljs inte, ens mitt i bild.
        var osaker = johannes
        osaker.confidence = 0.59
        XCTAssertEqual(PosePicker.pick([osaker, annan], previousHipMid: nil, width: 1080), 1)
        XCTAssertNil(PosePicker.pick([osaker], previousHipMid: (560, 1050), width: 1080))
        XCTAssertNil(PosePicker.pick([], previousHipMid: nil, width: 1080))
    }

    func testSerienKodasTillJSON() throws {
        var s = Self.serie()
        s.frames[0].joints[3] = nil
        let d = try JSONEncoder().encode(s)
        XCTAssertEqual(try JSONDecoder().decode(JointSeries.self, from: d), s)
    }
}
