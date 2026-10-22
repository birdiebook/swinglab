import Foundation

// Trimma och utsnitt (PLAN.md S2i, Johannes 2026-10-22 efter första telefonprovet):
// "Man ska också kunna klippa ner videon om den man valt är längre än svingen, även
// ändra framing." Originalfilen ändras aldrig. Passet sparar per serie (en inspelning
// eller ett importerat klipp) ett tidsfönster i filen och ett utsnitt i den upprätta
// bilden. Klick utanför fönstret blir inga slag, Vision letar bara inom utsnittet
// (`regionOfInterest`), och lederna förs tillbaka till hela bildens pixlar så att
// måtten inte ändras. Allt här är värden och prövas på Linux; App/ClipEditor.swift
// ritar redigeraren och App/PoseRunner.swift ger Vision rutan. METOD MS13

/// Tidsfönstret i seriens fil, s (filens egen tidslinje, samma som klicken). Ett klick
/// räknas som ett slag bara inom fönstret, gränserna inräknade. METOD MS13
public struct TimeWindow: Codable, Equatable, Sendable {
    public var start: Double
    public var end: Double

    public init(start: Double, end: Double) {
        self.start = start
        self.end = end
    }

    /// Manifestets namn (docs/FORMAT.md "Paketet"), samma i pass.json.
    enum CodingKeys: String, CodingKey {
        case start = "fran_s", end = "till_s"
    }

    /// Fönstret får inte bli kortare, s: handtagen kan inte gå förbi varandra. METOD MS13
    public static let minLength = 1.0

    /// Hela filen.
    public static func full(_ duration: Double) -> TimeWindow {
        TimeWindow(start: 0, end: max(0, duration.isFinite ? duration : 0))
    }

    public var length: Double { end - start }

    /// Klicket ligger i fönstret (gränserna inräknade).
    public func contains(_ t: Double) -> Bool { t >= start && t <= end }

    /// Fönstret inom filen och minst `minLength` långt (hela filen om den är kortare).
    /// Ett ogiltigt tal ger hela filen.
    public func clamped(duration: Double) -> TimeWindow {
        let d = max(0, duration.isFinite ? duration : 0)
        guard start.isFinite, end.isFinite, d > Self.minLength else { return .full(d) }
        var a = min(max(0, start), d)
        var b = min(max(0, end), d)
        if b < a { swap(&a, &b) }
        if b - a < Self.minLength {
            // Utvidgas kring mitten och skjuts in i filen.
            let m = (a + b) / 2
            a = min(max(0, m - Self.minLength / 2), d - Self.minLength)
            b = a + Self.minLength
        }
        return TimeWindow(start: a, end: b)
    }

    /// Starthandtaget dras till t: inom [0, slut − minLength].
    public func withStart(_ t: Double, duration: Double) -> TimeWindow {
        let w = clamped(duration: duration)
        guard t.isFinite else { return w }
        return TimeWindow(start: min(max(0, t), max(0, w.end - Self.minLength)), end: w.end)
    }

    /// Sluthandtaget dras till t: inom [start + minLength, längd].
    public func withEnd(_ t: Double, duration: Double) -> TimeWindow {
        let w = clamped(duration: duration)
        let d = max(0, duration.isFinite ? duration : 0)
        guard t.isFinite else { return w }
        return TimeWindow(start: w.start, end: max(min(d, t), min(d, w.start + Self.minLength)))
    }
}

/// Utsnittet: en rektangel i den upprätta bilden, normaliserad 0–1 med origo uppe till
/// vänster och y nedåt (som lederna i pixlar, METOD MS7, och linjerna vid träffen).
/// Proportionerna är fria. METOD MS13
public struct CropRect: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// Manifestets namn (docs/FORMAT.md "Paketet"): bredd och höjd som `b` och `h`.
    enum CodingKeys: String, CodingKey {
        case x, y, width = "b", height = "h"
    }

    /// Hela bilden.
    public static let full = CropRect(x: 0, y: 0, width: 1, height: 1)

    /// Den minsta sidan, andel av bildens sida: 216 × 384 px i 1080 × 1920. METOD MS13
    public static let minSide = 0.2

    /// Toleransen när ett utsnitt jämförs med hela bilden eller en punkt med rutan.
    static let eps = 1e-9

    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
    public var midX: Double { x + width / 2 }
    public var midY: Double { y + height / 2 }

    /// Utsnittet är hela bilden (inget att skära bort).
    public var isFull: Bool {
        abs(x) < 1e-6 && abs(y) < 1e-6 && abs(width - 1) < 1e-6 && abs(height - 1) < 1e-6
    }

    /// Inom bilden och minst `minSide` åt båda hållen. Ett ogiltigt tal ger hela bilden.
    public func clamped() -> CropRect {
        guard x.isFinite, y.isFinite, width.isFinite, height.isFinite else { return .full }
        let w = min(1, max(Self.minSide, width))
        let h = min(1, max(Self.minSide, height))
        return CropRect(x: min(max(0, x), 1 - w), y: min(max(0, y), 1 - h), width: w, height: h)
    }

    /// Rutan flyttad (dragen), samma storlek, inom bilden.
    public func moved(dx: Double, dy: Double) -> CropRect {
        guard dx.isFinite, dy.isFinite else { return clamped() }
        return CropRect(x: x + dx, y: y + dy, width: width, height: height).clamped()
    }

    /// Rutan nypt: skalad kring sin mitt med samma faktor åt båda hållen, inom bilden.
    public func scaled(by k: Double) -> CropRect {
        guard k.isFinite, k > 0 else { return clamped() }
        let w = min(1, max(Self.minSide, width * k))
        let h = min(1, max(Self.minSide, height * k))
        return CropRect(x: midX - w / 2, y: midY - h / 2, width: w, height: h).clamped()
    }

    public enum Corner: CaseIterable, Sendable {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    /// Hörnet dras till (px, py), normaliserat; det motsatta hörnet står still. Hörnet
    /// stannar inom bilden och minst `minSide` från det motsatta (proportionerna fria).
    public func dragging(_ corner: Corner, to px: Double, _ py: Double) -> CropRect {
        let r = clamped()
        guard px.isFinite, py.isFinite else { return r }
        let px = min(max(0, px), 1), py = min(max(0, py), 1)
        var x0 = r.x, y0 = r.y, x1 = r.maxX, y1 = r.maxY
        switch corner {
        case .topLeft:
            x0 = min(px, x1 - Self.minSide)
            y0 = min(py, y1 - Self.minSide)
        case .topRight:
            x1 = max(px, x0 + Self.minSide)
            y0 = min(py, y1 - Self.minSide)
        case .bottomLeft:
            x0 = min(px, x1 - Self.minSide)
            y1 = max(py, y0 + Self.minSide)
        case .bottomRight:
            x1 = max(px, x0 + Self.minSide)
            y1 = max(py, y0 + Self.minSide)
        }
        return CropRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0).clamped()
    }

    /// Hörnets punkt, normaliserad.
    public func point(_ corner: Corner) -> (x: Double, y: Double) {
        switch corner {
        case .topLeft: return (x, y)
        case .topRight: return (maxX, y)
        case .bottomLeft: return (x, maxY)
        case .bottomRight: return (maxX, maxY)
        }
    }

    /// Punkten (normaliserad, hela bilden) ligger i rutan, kanten inräknad.
    public func contains(x px: Double, y py: Double) -> Bool {
        px >= x - Self.eps && px <= maxX + Self.eps && py >= y - Self.eps && py <= maxY + Self.eps
    }

    /// En punkt i hela bilden (normaliserad) som andel av rutan: (0, 0) uppe till vänster i
    /// rutan, (1, 1) nere till höger. Miniatyrerna ritar linjerna så.
    public func local(x px: Double, y py: Double) -> (x: Double, y: Double) {
        ((px - x) / width, (py - y) / height)
    }

    /// Rutan i pixlar i en bild av storleken w × h (origo uppe till vänster), avrundad
    /// utåt till hela pixlar och inom bilden. För att skära ur en upprätt ruta.
    public func pixels(width w: Int, height h: Int) -> (x: Int, y: Int, width: Int, height: Int) {
        // Ett tal som är en hel pixel på flyttalets fel när räknas som den pixeln.
        let e = 1e-6
        let x0 = max(0, min(w, Int((x * Double(w) + e).rounded(.down))))
        let y0 = max(0, min(h, Int((y * Double(h) + e).rounded(.down))))
        let x1 = max(x0, min(w, Int((maxX * Double(w) - e).rounded(.up))))
        let y1 = max(y0, min(h, Int((maxY * Double(h) - e).rounded(.up))))
        return (x0, y0, x1 - x0, y1 - y0)
    }

    // MARK: Vision

    /// Visions `regionOfInterest`: normaliserad i den bearbetade (orienterade) bilden med
    /// origo nere till vänster (Apple, VNImageBasedRequest.regionOfInterest). Samma rektangel
    /// med y vänt. METOD MS13
    public var visionRegion: (x: Double, y: Double, width: Double, height: Double) {
        (x, 1 - maxY, width, height)
    }

    /// Visions punkt i rutan → normaliserad punkt i hela den upprätta bilden, origo uppe
    /// till vänster. Visions punkter är normaliserade i `regionOfInterest` med origo nere
    /// till vänster (som Apples `VNImagePointForNormalizedPointUsingRegionOfInterest`).
    /// METOD MS13
    public func fromVision(x u: Double, y v: Double) -> (x: Double, y: Double) {
        (x + u * width, y + (1 - v) * height)
    }

    /// Omvänt: en normaliserad punkt i hela den upprätta bilden (origo uppe till vänster)
    /// → Visions punkt i rutan (origo nere till vänster). För provets påhittade leder.
    public func toVision(x px: Double, y py: Double) -> (x: Double, y: Double) {
        ((px - x) / width, 1 - (py - y) / height)
    }
}

/// Seriens redigering: fönstret och utsnittet. Saknas den (nil i serien) har serien
/// aldrig öppnats i redigeraren och gäller hela filen och hela bilden. METOD MS13
public struct SeriesEdit: Codable, Equatable, Sendable {
    public var window: TimeWindow
    public var crop: CropRect

    public init(window: TimeWindow, crop: CropRect = .full) {
        self.window = window
        self.crop = crop
    }

    /// Manifestets namn (docs/FORMAT.md "Paketet").
    enum CodingKeys: String, CodingKey {
        case window = "fonster", crop = "utsnitt"
    }

    /// Fönstret inom filen och utsnittet inom bilden.
    public func clamped(duration: Double) -> SeriesEdit {
        SeriesEdit(window: window.clamped(duration: duration), crop: crop.clamped())
    }
}

extension SeriesRecord {
    /// Fönstret som gäller: redigeringens, annars hela filen. METOD MS13
    public var activeWindow: TimeWindow { edit?.window ?? .full(duration) }

    /// Utsnittet som gäller, eller nil för hela bilden. METOD MS13
    public var activeCrop: CropRect? {
        guard let c = edit?.crop, !c.isFull else { return nil }
        return c
    }

    /// Klicken som blir slag: de inom fönstret. METOD MS13
    public var countedClicks: [Click] {
        guard let w = edit?.window else { return clicks }
        return clicks.filter { w.contains($0.time) }
    }
}

extension PassState {
    /// Sätter seriens redigering. Ändras fönstret eller utsnittet görs seriens slag om:
    /// lederna, klippet och domen (utom Johannes egen) tas bort, slag vars klick hamnat
    /// utanför fönstret försvinner (`syncShots`; deras id ges aldrig igen) och ett analyserat
    /// pass blir inspelat igen, så att Analyze gör om det som saknas. Svarar filerna i passet
    /// (leder och klipp) som inget längre pekar på; appen tar bort dem. METOD MS12, MS13
    @discardableResult
    public mutating func setEdit(_ edit: SeriesEdit, series nr: Int) -> [String] {
        guard let i = series.firstIndex(where: { $0.nr == nr }) else { return [] }
        let ny = edit.clamped(duration: series[i].duration)
        let fore = series[i]
        series[i].edit = ny
        let andrat = fore.activeWindow != series[i].activeWindow || fore.activeCrop != series[i].activeCrop
        guard andrat else { return [] }
        let filerFore = Set(shots.flatMap { [$0.joints, $0.clip].compactMap { $0 } })
        for k in shots.indices where shots[k].series == nr {
            if !shots[k].verdictByJohannes { shots[k].verdict = nil }
            shots[k].joints = nil
            shots[k].jointFrames = nil
            shots[k].orientationSuspect = nil
            shots[k].clip = nil
            shots[k].clipStart = nil
            shots[k].clickInClip = nil
            shots[k].clipFlagged = nil
        }
        syncShots()
        if status == .analyzed { status = .recorded }
        let filerEfter = Set(shots.flatMap { [$0.joints, $0.clip].compactMap { $0 } })
        return filerFore.subtracting(filerEfter).sorted()
    }
}

// MARK: - Orienteringen: upprätt bild och buffertens koordinater

extension Orientation {
    /// En normaliserad punkt i den lagrade bufferten (origo uppe till vänster, som filens
    /// rutor ligger) → samma punkt i den upprätta bilden (origo uppe till vänster).
    /// EXIF 6 (.right) vrider 90° medurs: (s, t) → (1 − t, s); 8 (.left) moturs:
    /// (s, t) → (t, 1 − s); 3 (.down) ett halvt varv; 1 som den är. Samma avbildning som
    /// preferredTransform (0, 1, −1, 0, h, 0) gör med pixlarna. METOD MS7, MS13
    public static func upright(x s: Double, y t: Double, exif: UInt32) -> (x: Double, y: Double) {
        switch exif {
        case 6: return (1 - t, s)
        case 8: return (t, 1 - s)
        case 3: return (1 - s, 1 - t)
        default: return (s, t)
        }
    }

    /// Omvänt: en normaliserad punkt i den upprätta bilden → i den lagrade bufferten.
    public static func stored(x u: Double, y v: Double, exif: UInt32) -> (x: Double, y: Double) {
        switch exif {
        case 6: return (v, 1 - u)
        case 8: return (1 - v, u)
        case 3: return (1 - u, 1 - v)
        default: return (u, v)
        }
    }

    /// Utsnittet i den upprätta bilden → samma rektangel i buffertens koordinater
    /// (normaliserad, origo uppe till vänster). METOD MS13
    public static func storedRect(_ r: CropRect, exif: UInt32) -> CropRect {
        rect(r) { stored(x: $0, y: $1, exif: exif) }
    }

    /// En rektangel i buffertens koordinater → i den upprätta bilden. METOD MS13
    public static func uprightRect(_ r: CropRect, exif: UInt32) -> CropRect {
        rect(r) { upright(x: $0, y: $1, exif: exif) }
    }

    static func rect(_ r: CropRect, _ f: (Double, Double) -> (x: Double, y: Double)) -> CropRect {
        let a = f(r.x, r.y), b = f(r.maxX, r.maxY)
        let x0 = min(a.x, b.x), y0 = min(a.y, b.y)
        return CropRect(x: x0, y: y0, width: max(a.x, b.x) - x0, height: max(a.y, b.y) - y0)
    }
}

// MARK: - Lederna ur utsnittet

extension PoseFrame {
    /// En persons leder ur Vision när Vision bara letade i utsnittet: punkterna är
    /// normaliserade i rutan (origo nere till vänster) och förs till pixlar i hela den
    /// upprätta bilden, så att cm per px och måtten är desamma som utan utsnitt. En punkt
    /// som hamnar utanför rutan (Vision kan gissa en led utanför det den såg) sparas som
    /// saknad: analysen ger bara leder inom rutan. Konfidens 0 är ogiltig (Apple). METOD MS7,
    /// MS8, MS13
    public static func fromVision(pts: Double, points: [PoseJoint?], confidence: Double,
                                  uprightWidth: Int, uprightHeight: Int, crop: CropRect?) -> PoseFrame {
        guard let crop else {
            return fromVision(pts: pts, points: points, confidence: confidence, uprightWidth: uprightWidth,
                              uprightHeight: uprightHeight)
        }
        let w = Double(uprightWidth), h = Double(uprightHeight)
        let joints = (0..<JointSeries.names.count).map { i -> PoseJoint? in
            guard i < points.count, let p = points[i], p.c > 0, p.x.isFinite, p.y.isFinite else { return nil }
            let q = crop.fromVision(x: p.x, y: p.y)
            guard crop.contains(x: q.x, y: q.y) else { return nil }
            return PoseJoint(x: q.x * w, y: q.y * h, c: p.c)
        }
        return PoseFrame(t: pts, pts: pts, joints: joints, confidence: confidence)
    }
}

extension ImpactOverlay {
    /// Linjerna i utsnittets koordinater (0–1 i rutan), för en miniatyr som visar bara
    /// rutan. METOD MS13
    public func cropped(_ c: CropRect?) -> ImpactOverlay {
        guard let c else { return self }
        func p(_ q: Point) -> Point {
            let l = c.local(x: q.x, y: q.y)
            return Point(x: l.x, y: l.y)
        }
        return ImpactOverlay(t: t, shoulders: shoulders.map(p), hips: hips.map(p), leftWrist: leftWrist.map(p),
                             rightWrist: rightWrist.map(p))
    }
}

// MARK: - Redigerarens tidslinje

/// Tidslinjen i redigeraren som värden: var handtagen, spelhuvudet och klicken står,
/// som andelar 0–1 av linjens längd, och vilka klick som räknas. METOD MS13
public struct TrimTimeline: Equatable, Sendable {
    public struct Tick: Equatable, Sendable {
        public var position: Double
        public var counted: Bool
    }

    public var start: Double
    public var end: Double
    public var playhead: Double
    public var ticks: [Tick]

    public init(window: TimeWindow, duration: Double, current: Double, clicks: [Click]) {
        let d = duration > 0 && duration.isFinite ? duration : 1
        func f(_ t: Double) -> Double { min(1, max(0, t / d)) }
        start = f(window.start)
        end = f(window.end)
        playhead = f(current)
        ticks = clicks.map { Tick(position: f($0.time), counted: window.contains($0.time)) }
    }

    /// Tiden vid en andel av linjen, inom filen.
    public static func time(at fraction: Double, duration: Double) -> Double {
        guard fraction.isFinite, duration.isFinite, duration > 0 else { return 0 }
        return min(max(0, fraction), 1) * duration
    }
}
