import Foundation
import Swing

/// Läget "Mark club" i granskningen (PLAN S7a, BESLUT B47, METOD M45): Johannes går igenom
/// P1–P10 i ordning, trycker på greppet och sedan på hoseln, kan flytta en punkt, ångra eller
/// hoppa över en position där klubban inte syns. Allt som avgör vad ett tryck blir bor här
/// och prövas på Linux; App/ ritar ytan och förstoringsglaset. Koordinaterna på ytan är
/// 0–1 i det visade utsnittet (`shownCrop`), punkterna sparas i hela bildens pixlar.
public struct ClubMarking: Equatable, Sendable {
    /// Vilken punkt.
    public enum Point: String, Equatable, Sendable { case grip, hosel }

    /// Utsnittet vidgas så mycket per sida i märkningen: klubban når utanför spelaren vid
    /// toppen (som PC:ns märksida). METOD MF6, M45
    public static let marginal = 0.15
    /// Ett tryck närmare ytans kant än så (andel av bredden och höjden) blir ingen punkt:
    /// fingret täcker kanten och glaset visar inget utanför bilden. METOD M45
    public static let edge = 0.03
    /// Ett tryck så här nära en satt punkt (andel av ytans bredd) flyttar den. METOD M45
    public static let grabRadius = 0.05
    /// Förstoringsglaset förstorar så mycket. METOD M45
    public static let loupeZoom = 3.0

    /// Utsnittet som märkningen visar: seriens vidgat med `marginal` per sida, inom bilden.
    public static func shownCrop(_ crop: CropRect?) -> CropRect {
        guard let c = crop, !c.isFull else { return .full }
        let mx = c.width * marginal, my = c.height * marginal
        let x0 = max(0, c.x - mx), y0 = max(0, c.y - my)
        let x1 = min(1, c.maxX + mx), y1 = min(1, c.maxY + my)
        return CropRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }

    /// Positionerna i ordning.
    public static let order = Klubba.positioner

    public let width: Int
    public let height: Int
    /// Det visade utsnittet (`shownCrop`).
    public let crop: CropRect
    /// Positionen som märks nu (index i `order`); `order.count` = klar.
    public private(set) var index: Int
    /// De sparade markeringarna per position.
    public private(set) var marks: [String: KlubbMarkering]
    /// Punkterna på positionen som märks nu, i hela bildens pixlar.
    public private(set) var grip: KlubbPunkt?
    public private(set) var hosel: KlubbPunkt?
    private var history: [Snapshot] = []

    struct Snapshot: Equatable, Sendable {
        let index: Int
        let marks: [String: KlubbMarkering]
        let grip: KlubbPunkt?
        let hosel: KlubbPunkt?
    }

    /// Märkningen av ett slag; `existing` = slagets markeringar. Börjar på den första
    /// positionen som saknar en markering (alla klara: P1).
    public init(existing: [KlubbMarkering]?, width: Int, height: Int, crop: CropRect?) {
        self.width = width
        self.height = height
        self.crop = Self.shownCrop(crop).snapped(width: width, height: height)
        let m = Dictionary((existing ?? []).map { ($0.position, $0) }, uniquingKeysWith: { _, b in b })
        marks = m
        index = Self.order.firstIndex { m[$0] == nil } ?? 0
        grip = nil
        hosel = nil
        load()
    }

    public var done: Bool { index >= Self.order.count }
    public var position: String { done ? Self.order[Self.order.count - 1] : Self.order[index] }
    /// Nästa tryck sätter den punkten; nil när båda är satta.
    public var next: Point? { grip == nil ? .grip : hosel == nil ? .hosel : nil }
    public var canUndo: Bool { !history.isEmpty }
    /// Markeringarna i positionernas ordning.
    public var result: [KlubbMarkering] { Self.order.compactMap { marks[$0] } }

    private func snapshot() -> Snapshot { Snapshot(index: index, marks: marks, grip: grip, hosel: hosel) }

    private mutating func load() {
        let m = done ? nil : marks[position]
        grip = m?.hoppad == true ? nil : m?.grepp
        hosel = m?.hoppad == true ? nil : m?.hosel
    }

    // MARK: ytan

    /// Ytans punkt (0–1 i det visade utsnittet) i hela bildens pixlar; nil nära kanten eller
    /// utanför ytan (bilden). METOD M45
    public func imagePoint(u: Double, v: Double) -> KlubbPunkt? {
        guard u.isFinite, v.isFinite, u >= Self.edge, u <= 1 - Self.edge, v >= Self.edge, v <= 1 - Self.edge else {
            return nil
        }
        return KlubbPunkt(x: (crop.x + u * crop.width) * Double(width), y: (crop.y + v * crop.height) * Double(height))
    }

    /// Bildens punkt på ytan (0–1 i det visade utsnittet).
    public func surfacePoint(_ p: KlubbPunkt) -> (u: Double, v: Double) {
        ((p.x / Double(width) - crop.x) / crop.width, (p.y / Double(height) - crop.y) / crop.height)
    }

    /// Ytans proportioner, bredd / höjd i bildpunkter.
    public var aspect: Double { crop.width * Double(width) / (crop.height * Double(height)) }

    /// Den satta punkten närmast ytans punkt inom `grabRadius`, eller nil.
    public func grab(u: Double, v: Double) -> Point? {
        var bast: (Point, Double)? = nil
        for (namn, p) in [(Point.grip, grip), (.hosel, hosel)] {
            guard let p else { continue }
            let s = surfacePoint(p)
            let d = ((s.u - u) * (s.u - u) + (s.v - v) * (s.v - v) * (1 / aspect) * (1 / aspect)).squareRoot()
            if d <= Self.grabRadius, d < (bast?.1 ?? .infinity) { bast = (namn, d) }
        }
        return bast?.0
    }

    /// Förstoringsglasets utsnitt kring ytans punkt: kvadratiskt i bildpunkter, 1/`loupeZoom`
    /// av ytans bredd, inom bilden.
    public func loupeCrop(u: Double, v: Double) -> CropRect {
        let w = crop.width / Self.loupeZoom
        let h = w * Double(width) / Double(height)
        let cx = crop.x + u * crop.width, cy = crop.y + v * crop.height
        let x = min(max(0, cx - w / 2), 1 - w), y = min(max(0, cy - h / 2), 1 - h)
        return CropRect(x: x, y: y, width: w, height: h)
    }

    // MARK: handlingarna

    /// Ett tryck: sätter nästa punkt. Svarar om något ändrades (inte nära kanten, inte när
    /// båda punkterna redan är satta). METOD M45
    @discardableResult
    public mutating func tap(u: Double, v: Double) -> Bool {
        guard !done, let p = imagePoint(u: u, v: v), let n = next else { return false }
        history.append(snapshot())
        if n == .grip { grip = p } else { hosel = p }
        return true
    }

    /// Flyttar en satt punkt dit fingret släpptes; inget nära kanten.
    @discardableResult
    public mutating func move(_ point: Point, u: Double, v: Double) -> Bool {
        guard !done, let p = imagePoint(u: u, v: v) else { return false }
        switch point {
        case .grip:
            guard grip != nil else { return false }
            history.append(snapshot())
            grip = p
        case .hosel:
            guard hosel != nil else { return false }
            history.append(snapshot())
            hosel = p
        }
        return true
    }

    /// Positionen klar med båda punkterna på rutan med tiden `t` (s relativt klicket), och
    /// nästa position. Svarar false när en punkt saknas.
    @discardableResult
    public mutating func confirm(t: Double) -> Bool {
        guard !done, let g = grip, let h = hosel else { return false }
        history.append(snapshot())
        marks[position] = KlubbMarkering(position: position, t: t, grepp: g, hosel: h)
        index += 1
        load()
        return true
    }

    /// Klubban syns inte: positionen hoppas över (sparas som hoppad) och nästa.
    public mutating func skip(t: Double) {
        guard !done else { return }
        history.append(snapshot())
        marks[position] = KlubbMarkering(position: position, t: t, grepp: nil, hosel: nil, hoppad: true)
        index += 1
        load()
    }

    /// Till en position (raden P1–P10): dess markering laddas för att ändras.
    public mutating func go(to position: String) {
        guard let i = Self.order.firstIndex(of: position), i != index else { return }
        history.append(snapshot())
        index = i
        load()
    }

    /// Ångrar det senaste: en punkt, en flytt, en klar eller hoppad position.
    public mutating func undo() {
        guard let s = history.popLast() else { return }
        index = s.index
        marks = s.marks
        grip = s.grip
        hosel = s.hosel
    }

    /// Rutans tid att visa för positionen: markeringens, annars förslaget ur kroppens tider
    /// (METOD M45) ur slagets mått, annars träffen.
    public static func suggestedTime(_ position: String, measure: ShotMeasure?, existing: [KlubbMarkering]?,
                                     impact: Double) -> Double {
        if let m = existing?.first(where: { $0.position == position }) { return m.t }
        return measure.flatMap { Klubba.forslagTid(position, positioner: $0.positions, start: $0.start) } ?? impact
    }
}
