import Foundation

public enum SwingVerdict: String, Codable, Sendable {
    case swing, notSwing, uncertain
}

/// Är klicket ett slag? Glesa leder kring klicket ska visa händerna över axlarna
/// före och snabba vid klicket (S2_SPEC §4.3). Grannens klick, röster och
/// klubban mot mattan ger inget av det. METOD MS5
public enum SwingCheck {
    /// Det glesa fönstret kring klicket, s, och var 8:e ruta. METOD MS5
    public static let sparseWindow = -1.6...0.1
    public static let sparseStride = 8
    /// Det täta fönstret för bekräftade och osäkra slag, s. METOD MS5
    public static let denseWindow = -2.5...1.5
    /// (a) Händernas högsta fart i fönstret kring klicket, kroppslängder per sekund. METOD MS5
    public static let speedWindow = -0.10...0.05
    public static let minSpeed = 2.0
    /// (b) Händerna över axlarnas mitt någon gång i fönstret före klicket. METOD MS5
    public static let topWindow = -1.6 ... -0.15
    /// (c) Andelen rutor där alla 13 leder är säkra (METOD MS8). METOD MS5
    public static let minComplete = 0.6

    /// Händernas fart mellan på varandra följande rutor, i kroppslängder per sekund,
    /// med tiden i stegets mitt.
    static func speeds(_ frames: [PoseFrame], bodyHeight h: Double) -> [(t: Double, v: Double)] {
        let med: [(t: Double, p: (x: Double, y: Double))] = frames.compactMap { f -> (t: Double, p: (x: Double, y: Double))? in
            guard let h = f.hands else { return nil }
            return (t: f.t, p: h)
        }.sorted { $0.t < $1.t }
        var ut: [(t: Double, v: Double)] = []
        guard med.count >= 2 else { return ut }
        for i in 1..<med.count {
            let dt = med[i].t - med[i - 1].t
            guard dt > 0 else { continue }
            let dx = med[i].p.x - med[i - 1].p.x, dy = med[i].p.y - med[i - 1].p.y
            ut.append((t: (med[i].t + med[i - 1].t) / 2, v: (dx * dx + dy * dy).squareRoot() / dt / h))
        }
        return ut
    }

    /// Domen. series: lederna glest kring klicket, t relativt klicket. METOD MS5
    /// - osäkert om färre än 60 % av rutorna har alla leder, eller kroppens längd saknas;
    /// - slag om (a) och (b) håller; annars inte slag.
    public static func verdict(_ series: JointSeries) -> SwingVerdict {
        let frames = series.frames
        guard !frames.isEmpty else { return .uncertain }
        let hela = frames.filter(\.complete).count
        guard Double(hela) >= minComplete * Double(frames.count) else { return .uncertain }
        let langder = frames.compactMap(\.bodyHeight).filter { $0 > 0 }
        guard !langder.isEmpty else { return .uncertain }
        let h = JointSeries.median(langder)
        let fart = speeds(frames, bodyHeight: h)
        let a = fart.contains { speedWindow.contains($0.t) && $0.v >= minSpeed }
        let b = frames.contains { f in
            guard topWindow.contains(f.t), let hand = f.hands,
                  let axlar = f.mitt(JointSeries.axelV, JointSeries.axelH) else { return false }
            return hand.y < axlar.y                  // y nedåt: över = mindre y
        }
        return a && b ? .swing : .notSwing
    }
}
