import Foundation
import Swing

/// Läget "Mark club" i granskningen (PLAN S7a, BESLUT B47, B56, METOD M45), bakifrån och
/// framifrån: Johannes går igenom P1–P10 i ordning, trycker på greppet (eller på ringen ur
/// handlederna) och sedan på hoseln, och positionen sparas av sig själv med rutans tid från första trycket. Han kan flytta en
/// punkt, ångra eller hoppa över en position där klubban inte syns. Allt som avgör vad ett
/// tryck blir bor här och prövas på Linux; App/ ritar ytan och förstoringsglaset.
/// Koordinaterna på ytan är 0–1 i det visade utsnittet (`shownCrop`), punkterna sparas i
/// hela bildens pixlar.
public struct ClubMarking: Equatable, Sendable {
    /// Vilken punkt.
    public enum Point: String, Equatable, Sendable { case grip, hosel }

    /// Utsnittet vidgas så mycket per sida i märkningen: klubban når utanför spelaren vid
    /// toppen (som PC:ns märksida). METOD MF6, M45
    public static let marginal = 0.15
    /// Ett tryck närmare ytans kant än så (andel av bredden och höjden) blir ingen punkt:
    /// fingret täcker kanten och glaset visar inget utanför bilden. METOD M45
    public static let edge = 0.03
    /// Ett tryck så här nära en satt punkt eller ringen (andel av ytans bredd) tar den. METOD M45
    public static let grabRadius = 0.05
    /// Fingret måste röra sig så här långt (punkter på skärmen) för att ett tryck på en satt
    /// punkt ska bli en flytt; annars är det ett tryck. METOD M45
    public static let dragThresholdPt = 4.0
    /// Förstoringsglaset förstorar så mycket, mätt i punkter på skärmen. METOD M45, M46
    public static let loupeZoom = 3.0
    /// En punkt hör till rutan när tiderna skiljer mindre än så, s (lederna avrundas till 0,1 ms).
    public static let sameFrame = 1e-4

    /// Utsnittet som märkningen visar: seriens vidgat med `marginal` per sida, inom bilden.
    public static func shownCrop(_ crop: CropRect?) -> CropRect {
        guard let c = crop, !c.isFull else { return .full }
        let mx = c.width * marginal, my = c.height * marginal
        let x0 = max(0, c.x - mx), y0 = max(0, c.y - my)
        let x1 = min(1, c.maxX + mx), y1 = min(1, c.maxY + my)
        return CropRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }

    /// Fingrets plats i ytan (punkter) som ytans koordinater 0–1.
    public static func surface(x: Double, y: Double, width: Double, height: Double) -> (u: Double, v: Double) {
        (x / max(1, width), y / max(1, height))
    }

    /// Ett drag är en flytt när fingret rört sig mer än `dragThresholdPt` punkter.
    public static func isDrag(dx: Double, dy: Double) -> Bool {
        (dx * dx + dy * dy).squareRoot() > dragThresholdPt
    }

    /// Positionerna i ordning.
    public static let order = Klubba.positioner

    public let width: Int
    public let height: Int
    /// Vyn: P2, P6 och P8 föreslås olika (METOD M45), och riktpinnen hör bara till DTL (M48).
    public let view: Vy
    /// +1 eller −1: bildens x mot målet (FO) eller bollen (DTL), spelhanden (M1).
    public let xTecken: Double
    /// Det visade utsnittet (`shownCrop`, på hela pixlar).
    public let crop: CropRect
    /// Positionen som märks nu (index i `order`); `order.count` = klar.
    public private(set) var index: Int
    /// De sparade markeringarna per position.
    public private(set) var marks: [String: KlubbMarkering]
    /// Punkterna på positionen som märks nu, i hela bildens pixlar.
    public private(set) var grip: KlubbPunkt?
    public private(set) var hosel: KlubbPunkt?
    /// Greppets källa: ett fritt tryck eller ringen ur handlederna.
    public private(set) var gripSource = Klubba.kalla
    /// Rutans tid (s relativt klicket) där första punkten sattes; positionen sparas med den.
    public private(set) var frameT: Double?
    private var history: [Snapshot] = []

    struct Snapshot: Equatable, Sendable {
        let index: Int
        let marks: [String: KlubbMarkering]
        let grip: KlubbPunkt?
        let hosel: KlubbPunkt?
        let gripSource: String
        let frameT: Double?
    }

    /// Märkningen av ett slag; `existing` = slagets markeringar. Börjar på den första
    /// positionen som saknar en markering (alla klara: P1).
    public init(existing: [KlubbMarkering]?, width: Int, height: Int, crop: CropRect?, view: Vy = .dtl,
                xTecken: Double = 1) {
        self.width = width
        self.height = height
        self.view = view
        self.xTecken = xTecken
        self.crop = Self.shownCrop(crop).snapped(width: width, height: height)
        let m = Dictionary((existing ?? []).map { ($0.position, $0) }, uniquingKeysWith: { _, b in b })
        marks = m
        index = Self.order.firstIndex { m[$0] == nil } ?? 0
        grip = nil
        hosel = nil
        frameT = nil
        load()
    }

    public var done: Bool { index >= Self.order.count }
    public var position: String { done ? Self.order[Self.order.count - 1] : Self.order[index] }
    /// Nästa tryck sätter den punkten; nil när båda är satta.
    public var next: Point? { grip == nil ? .grip : hosel == nil ? .hosel : nil }
    public var hasPoints: Bool { grip != nil || hosel != nil }
    public var canUndo: Bool { !history.isEmpty }
    /// Markeringarna i positionernas ordning.
    public var result: [KlubbMarkering] { Self.order.compactMap { marks[$0] } }

    private func snapshot() -> Snapshot {
        Snapshot(index: index, marks: marks, grip: grip, hosel: hosel, gripSource: gripSource, frameT: frameT)
    }

    private mutating func load() {
        let m = done ? nil : marks[position]
        let satt = m?.hoppad != true
        grip = satt ? m?.grepp : nil
        hosel = satt ? m?.hosel : nil
        gripSource = m?.greppKalla ?? Klubba.kalla
        frameT = m?.t
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

    private func avstand(_ p: KlubbPunkt, _ u: Double, _ v: Double) -> Double {
        let s = surfacePoint(p)
        return ((s.u - u) * (s.u - u) + (s.v - v) * (s.v - v) / (aspect * aspect)).squareRoot()
    }

    /// Den satta punkten närmast ytans punkt inom `grabRadius`, eller nil.
    public func grab(u: Double, v: Double) -> Point? {
        var bast: (Point, Double)? = nil
        for (namn, p) in [(Point.grip, grip), (.hosel, hosel)] {
            guard let p else { continue }
            let d = avstand(p, u, v)
            if d <= Self.grabRadius, d < (bast?.1 ?? .infinity) { bast = (namn, d) }
        }
        return bast?.0
    }

    /// Förstoringsglasets utsnitt kring ytans punkt, kvadratiskt i bildpunkter och inom bilden:
    /// ett glas `loupePt` punkter brett över en yta `surfaceWidthPt` punkter bred förstorar
    /// då exakt `loupeZoom` gånger. METOD M45, M46
    public func loupeCrop(u: Double, v: Double, surfaceWidthPt: Double, loupePt: Double) -> CropRect {
        let w = crop.width * loupePt / (Self.loupeZoom * max(1, surfaceWidthPt))
        let h = w * Double(width) / Double(height)
        let cx = crop.x + u * crop.width, cy = crop.y + v * crop.height
        let x = min(max(0, cx - w / 2), 1 - w), y = min(max(0, cy - h / 2), 1 - h)
        return CropRect(x: x, y: y, width: w, height: h)
    }

    /// Förstoringen som glaset ger: glasets bredd i punkter genom den del av ytan det visar.
    public func loupeMagnification(_ lc: CropRect, surfaceWidthPt: Double, loupePt: Double) -> Double {
        loupePt / (lc.width / crop.width * surfaceWidthPt)
    }

    // MARK: handlingarna

    /// Ett tryck i rutan med tiden `t`: sätter nästa punkt. Greppet tas ur ringen (`ring`,
    /// handledernas mitt) när trycket träffar den, annars där trycket är. När hoseln är satt
    /// sparas positionen med rutans tid från första trycket och nästa position tas. Svarar om
    /// något ändrades: inget nära kanten, inget när båda är satta, och inget på en annan ruta
    /// än den första punktens (den rutan töms först, `clearPoints`). METOD M45
    @discardableResult
    public mutating func tap(u: Double, v: Double, t: Double, ring: KlubbPunkt? = nil, now: Date = Date()) -> Bool {
        guard !done, let n = next else { return false }
        if let f = frameT, abs(f - t) > Self.sameFrame { return false }
        if n == .grip, let r = ring, avstand(r, u, v) <= Self.grabRadius {
            history.append(snapshot())
            grip = r
            gripSource = Klubba.kallaRing
            frameT = t
            return true
        }
        guard let p = imagePoint(u: u, v: v) else { return false }
        history.append(snapshot())
        if n == .grip {
            grip = p
            gripSource = Klubba.kalla
            frameT = t
        } else {
            hosel = p
            frameT = frameT ?? t
            spara(now: now)
        }
        return true
    }

    /// Flyttar en satt punkt dit (inget nära kanten). En sparad position sparas om på samma
    /// ruta. Ett flyttat grepp är ett fritt tryck.
    @discardableResult
    public mutating func move(_ point: Point, u: Double, v: Double, now: Date = Date()) -> Bool {
        guard !done, let p = imagePoint(u: u, v: v) else { return false }
        switch point {
        case .grip:
            guard grip != nil else { return false }
            history.append(snapshot())
            grip = p
            gripSource = Klubba.kalla
        case .hosel:
            guard hosel != nil else { return false }
            history.append(snapshot())
            hosel = p
        }
        if grip != nil, hosel != nil, let f = frameT {
            marks[position] = KlubbMarkering(position: position, t: f, grepp: grip, hosel: hosel,
                                             greppKalla: gripSource == Klubba.kalla ? nil : gripSource, andrad: Self.sekund(now))
        }
        return true
    }

    /// Positionen sparad med punkterna och rutans tid, och nästa position.
    private mutating func spara(now: Date) {
        guard let g = grip, let h = hosel, let f = frameT else { return }
        marks[position] = KlubbMarkering(position: position, t: f, grepp: g, hosel: h,
                                         greppKalla: gripSource == Klubba.kalla ? nil : gripSource, andrad: Self.sekund(now))
        index += 1
        load()
    }

    /// Nästa position utan ändring (en sparad position som visades). Svarar false när
    /// positionen har en ensam punkt.
    @discardableResult
    public mutating func advance() -> Bool {
        guard !done, grip == nil || hosel != nil else { return false }
        history.append(snapshot())
        index += 1
        load()
        return true
    }

    /// Tömmer punkterna på positionen (inför ett steg till en annan ruta, efter en fråga).
    public mutating func clearPoints() {
        guard hasPoints || frameT != nil else { return }
        history.append(snapshot())
        grip = nil
        hosel = nil
        gripSource = Klubba.kalla
        frameT = nil
    }

    /// Klubban syns inte i rutan med tiden `t`: positionen hoppas över (sparas som hoppad).
    public mutating func skip(t: Double, now: Date = Date()) {
        guard !done else { return }
        history.append(snapshot())
        marks[position] = KlubbMarkering(position: position, t: t, grepp: nil, hosel: nil, hoppad: true,
                                         andrad: Self.sekund(now))
        index += 1
        load()
    }

    /// Till en position (raden P1–P10): dess markering laddas, med sin ruta.
    public mutating func go(to position: String) {
        guard let i = Self.order.firstIndex(of: position), i != index else { return }
        history.append(snapshot())
        index = i
        load()
    }

    /// Ångrar det senaste: en punkt, en flytt, en sparad eller hoppad position. Rutan att visa
    /// är då `frameT` (den sparade) när den finns.
    public mutating func undo() {
        guard let s = history.popLast() else { return }
        index = s.index
        marks = s.marks
        grip = s.grip
        hosel = s.hosel
        gripSource = s.gripSource
        frameT = s.frameT
    }

    /// Riktpinnen (två tryck på en pinne längs mållinjen) gäller bara bakifrån. METOD M48
    public var stickAvailable: Bool { view == .dtl }

    /// Rutans tid att visa för positionen: punkternas ruta, annars markeringens, annars
    /// förslaget (`suggestedTime`), annars träffen.
    public func shownTime(measure: ShotMeasure?, impact: Double, paired: [String: Double] = [:]) -> Double {
        frameT ?? marks[position]?.t ?? suggestedTime(measure: measure, paired: paired) ?? impact
    }

    /// Förslaget till positionens ruta (METOD M45): för P2, P6 och P8 framifrån rutan där
    /// skaftets vinkel mellan de markerade positionerna före och efter går genom vågrätt
    /// (`Klubba.forslagTidSkaft`), bakifrån FO-slagets tid med två parade telefoner (`paired`,
    /// `ClubPairTime`); annars kroppens positioner (samma som PC:n).
    public func suggestedTime(measure: ShotMeasure?, paired: [String: Double] = [:]) -> Double? {
        if Klubba.skaftets.contains(position) {
            if view == .fo, let t = Klubba.forslagTidSkaft(position, marks: result, xTecken: xTecken) { return t }
            if view == .dtl, let t = paired[position] { return t }
        }
        return measure.flatMap { Klubba.forslagTid(position, positioner: $0.positions) }
    }

    /// Tiden på hela sekunder, som pass.json sparar den (ISO 8601), så att en markering är
    /// densamma när den lästs tillbaka.
    static func sekund(_ d: Date) -> Date { Date(timeIntervalSince1970: d.timeIntervalSince1970.rounded(.down)) }

    /// Senaste ändringen bland markeringarna, för paketets `andrad`.
    public static func lastChange(_ marks: [KlubbMarkering]?) -> Date? {
        marks?.compactMap(\.andrad).max()
    }
}

/// P2, P6 och P8 bakifrån ur FO-slaget med två parade telefoner (S2g, METOD M45): framifrån
/// syns "parallellt med marken" direkt, så DTL-markeringens förslag är FO-markeringens tid,
/// förd över med parningens förskjutning. Tiderna i markeringarna är s relativt varje telefons
/// eget klick; filtiderna hänger ihop genom träffens förskjutning (`PairEntry.hitOffset`,
/// följarens filtid = den styrandes + den, METOD MS6), så att ljudets olika väg till
/// telefonerna inte flyttar tiden.
public enum ClubPairTime {
    /// Klicket i den andra telefonens serie som parades med klicket `index` i den här
    /// telefonens serie, eller nil (inte parat, eller parningen osäker). `view` = den här
    /// telefonens vy; den styrandes klick är `a` i parningen, följarens `b`.
    public static func partner(_ entry: PairEntry, view: Vy, index: Int) -> Int? {
        guard !entry.uncertain else { return nil }
        let foljare = entry.follower.view == view
        return entry.pairing.pairs.first { (foljare ? $0.b : $0.a) == index }.map { foljare ? $0.a : $0.b }
    }

    /// FO-markeringarnas P2, P6 och P8 som tider för DTL-slaget, s relativt DTL-klicket.
    /// `foClick` och `dtlClick` = de parade klickens tid i var sin fil; `entry` = parningen
    /// (vilken telefon som styr står i `entry.follower.view`). Hoppade och osatta positioner
    /// tas inte med.
    public static func dtlTimes(fo: [KlubbMarkering], foClick: Double, dtlClick: Double,
                                entry: PairEntry) -> [String: Double] {
        // Följarens filtid = den styrandes + hitOffset.
        let foTillDtl = entry.follower.view == .fo ? -entry.hitOffset : entry.hitOffset
        var ut: [String: Double] = [:]
        for m in fo where Klubba.skaftets.contains(m.position) && m.markerad {
            ut[m.position] = foClick + m.t + foTillDtl - dtlClick
        }
        return ut
    }
}
