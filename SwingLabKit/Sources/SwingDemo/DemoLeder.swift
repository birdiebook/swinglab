import Foundation
import Capture

/// PÅHITTADE Vision-leder för slagens kedja (S2e, CLAUDE.md: Dataregeln). Vision hittar
/// ingen person i provets genererade film (METOD MS12), så simulatorprovet matar
/// analysen med de här i stället för Vision och prövar resten: personvalet, domen,
/// lederna på disk, klippen och passet. Samma figur som CaptureTests/LederTests: en
/// stående person (y nedåt) med händerna som går upp till toppen och genom träffen i
/// 3 kroppslängder per sekund, eller står stilla. Bredvid står en mindre granne längre
/// bort, med stilla händer, som personvalet ska välja bort (METOD MS8).
public enum DemoLeder {
    /// Figuren ritas i 1080 × 1920 och skalas till bildens storlek.
    static let basBredd = 1080.0, basHojd = 1920.0
    /// Kroppens längd i grundbilden, fotledernas mitt − näsan, px.
    public static let H = 1150.0

    /// Händerna vid t s relativt klicket.
    static func hander(_ t: Double, sving: Bool) -> (x: Double, y: Double) {
        guard sving else { return (540, 1000) }
        func lerp(_ a: (Double, Double), _ b: (Double, Double), _ u: Double) -> (x: Double, y: Double) {
            (a.0 + (b.0 - a.0) * u, a.1 + (b.1 - a.1) * u)
        }
        switch t {
        case ..<(-1.2): return (540, 1000)
        case ..<(-0.5): return lerp((540, 1000), (700, 450), (t + 1.2) / 0.7)
        case ..<(-0.15): return lerp((700, 450), (540 - 0.45 * H, 1000), (t + 0.5) / 0.35)
        default: return (540 + 3 * H * min(t, 0.12), 1000)
        }
    }

    /// De 13 lederna i grundbilden, förskjutna dx och skalade kring fötterna.
    static func figur(_ hander: (x: Double, y: Double), dx: Double, skala: Double) -> [(Double, Double)] {
        let pkt: [(Double, Double)] = [
            (540, 500),                         // nasa
            (600, 650), (480, 650),             // axel_v, axel_h (figuren vänd mot kameran)
            (620, 850), (460, 850),             // armbågar
            (hander.x + 10, hander.y), (hander.x - 10, hander.y),   // handleder
            (580, 1050), (500, 1050),           // höfter
            (590, 1350), (490, 1350),           // knän
            (600, 1650), (480, 1650),           // fotleder
        ]
        var ut: [(Double, Double)] = []
        for (x, y) in pkt {
            let nx: Double = (x - 540) * skala + 540 + dx
            let ny: Double = 1650 - (1650 - y) * skala
            ut.append((nx, ny))
        }
        return ut
    }

    /// Vision-kandidaterna i en ruta: grannen först, sedan personen som svingar (eller
    /// står still). t = pts, lederna i pixlar i den upprätta bilden width × height.
    public static func kandidater(pts: Double, klick: Double, sving: Bool, width: Int, height: Int) -> [PoseFrame] {
        let sx = Double(width) / basBredd, sy = Double(height) / basHojd
        func person(_ p: [(Double, Double)]) -> PoseFrame {
            PoseFrame(t: pts, pts: pts, joints: p.map { PoseJoint(x: $0.0 * sx, y: $0.1 * sy, c: 0.9) }, confidence: 0.9)
        }
        let granne = person(figur((540, 1000), dx: 380, skala: 0.45))
        let spelare = person(figur(hander(pts - klick, sving: sving), dx: 0, skala: 1))
        return [granne, spelare]
    }
}
