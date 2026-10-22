import Foundation
import Swing

/// Granskningen av ett slag (PLAN S4, BESLUT B32, B35): videon ruta för ruta med de
/// uppmätta lederna ovanpå, i utsnittets koordinater (METOD MS13). Rutorna är slagets egna
/// (lederna har en ruta per videobild i det täta fönstret, med bildens egen tid), så att
/// stegningen och linjerna följer samma rutnät. B13: tunna linjer och punkter, ingen figur;
/// en led som Vision är osäker på ritas ihålig och dess linjer streckade. METOD MS15
public struct ShotReview: Sendable {
    /// Hur säker en led är i rutan.
    public enum JointState: Equatable, Sendable {
        /// Konfidens ≥ 0,3: leden mäts (METOD M1).
        case measured
        /// 0,1 ≤ konfidens < 0,3: Vision såg den, men måtten räknar den som saknad.
        case weak
    }

    /// En led i ytans koordinater: 0–1 i utsnittet (hela bilden utan utsnitt), origo uppe
    /// till vänster.
    public struct Point: Equatable, Sendable {
        public let x: Double
        public let y: Double
        public let state: JointState
    }

    /// En linje mellan två leder (index i `JointSeries.names`); streckad när någon av dem är osäker.
    public struct Line: Equatable, Sendable {
        public let from: Int
        public let to: Int
        public let measured: Bool
    }

    /// Det som ritas över en ruta: 13 leder (nil = saknas eller under 0,1) och linjerna.
    public struct Overlay: Equatable, Sendable {
        public let points: [Point?]
        public let lines: [Line]
    }

    /// Linjerna: axellinjen, höftlinjen, armarna (axel–armbåge–handled) och benen
    /// (höft–knä–fotled). Näsan är huvudpunkten, utan linje. Ingen bål: ingen figur (B13).
    public static let bones: [[Int]] = [[1, 2], [7, 8], [1, 3], [3, 5], [2, 4], [4, 6], [7, 9], [9, 11], [8, 10], [10, 12]]
    /// Fylld från den konfidens där leden mäts. METOD M1, MS15
    public static let measuredConfidence = Sving.minKonfidens
    /// Ritad (ihålig) från den konfidens där Vision räknar leden som säker. METOD MS8, MS15
    public static let shownConfidence = PoseRules.jointConfidence
    /// Uppspelningens fart: 240 bilder/s visas som 30 per sekund. METOD MS15
    public static let playbackRate = 0.125

    /// Rutorna i tidsordning (t relativt klicket, pts i seriens fil).
    public let frames: [PoseFrame]
    public let width: Int
    public let height: Int
    /// Utsnittet på hela pixlar (samma som bilden skärs till), eller hela bilden.
    public let crop: CropRect

    public init(series: JointSeries, crop: CropRect?) {
        frames = series.frames.sorted { $0.t < $1.t }
        width = series.width
        height = series.height
        self.crop = crop.map { $0.snapped(width: series.width, height: series.height) } ?? .full
    }

    /// Ytans proportioner, bredd / höjd i bildpunkter: utsnittets.
    public var aspect: Double {
        guard width > 0, height > 0, crop.height > 0 else { return 9.0 / 16 }
        return crop.width * Double(width) / (crop.height * Double(height))
    }

    /// Rutan närmast tiden t (s relativt klicket), nil utan rutor.
    public func index(nearestT t: Double) -> Int? {
        nearest(t) { $0.t }
    }

    /// Rutan närmast tiden p i seriens fil.
    public func index(nearestPts p: Double) -> Int? {
        nearest(p) { $0.pts }
    }

    private func nearest(_ v: Double, _ tid: (PoseFrame) -> Double) -> Int? {
        guard !frames.isEmpty, v.isFinite else { return frames.isEmpty ? nil : 0 }
        var lo = 0, hi = frames.count - 1
        while lo < hi {
            let m = (lo + hi) / 2
            if tid(frames[m]) < v { lo = m + 1 } else { hi = m }
        }
        if lo > 0 && abs(tid(frames[lo - 1]) - v) <= abs(tid(frames[lo]) - v) { return lo - 1 }
        return lo
    }

    /// Lederna och linjerna i ruta k, i ytans koordinater.
    public func overlay(_ k: Int) -> Overlay {
        guard frames.indices.contains(k), width > 0, height > 0 else { return Overlay(points: [], lines: []) }
        let f = frames[k]
        let w = Double(width), h = Double(height)
        let points = (0..<JointSeries.names.count).map { i -> Point? in
            guard i < f.joints.count, let j = f.joints[i], j.x.isFinite, j.y.isFinite, j.c >= Self.shownConfidence
            else { return nil }
            let l = crop.local(x: j.x / w, y: j.y / h)
            return Point(x: l.x, y: l.y, state: j.c >= Self.measuredConfidence ? .measured : .weak)
        }
        let lines = Self.bones.compactMap { b -> Line? in
            guard let a = points[b[0]], let c = points[b[1]] else { return nil }
            return Line(from: b[0], to: b[1], measured: a.state == .measured && c.state == .measured)
        }
        return Overlay(points: points, lines: lines)
    }

    /// Positionerna P1–P10 i svingens ordning med rutan närmast var och en; nil när
    /// positionen saknas (METOD M28) eller slaget inte är mätt.
    public func positions(_ m: ShotMeasure?) -> [(name: String, index: Int?)] {
        Positioner.namn.map { p in (name: p, index: m?.positions[p].flatMap { index(nearestT: $0) }) }
    }
}
