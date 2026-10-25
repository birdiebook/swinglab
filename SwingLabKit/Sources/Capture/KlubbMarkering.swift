import Foundation
import Swing

/// Läget "Mark club" i granskningen (PLAN S7a, BESLUT B47, B57, B58, METOD M45), bakifrån och
/// framifrån: Johannes går igenom kroppens positioner och sist skaftets (`order`), trycker på
/// greppet (eller på ringen ur handlederna) och sedan på hoseln, och positionen sparas av sig själv med rutans tid från första trycket. Han kan flytta en
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

    /// Märkningens ordning (BESLUT B58): kroppens positioner först och skaftets sist, i båda
    /// vyerna, så att ändarna är markerade när P2, P6 och P8 föreslås (METOD M45).
    public static let order = ["P1", "P3", "P4", "P5", "P7", "P9", "P10", "P2", "P6", "P8"]

    public let width: Int
    public let height: Int
    /// Vyn: P2, P6 och P8 föreslås olika (METOD M45), och riktpinnen hör bara till DTL (M48).
    public let view: Vy
    /// +1 eller −1: bildens x mot målet (FO) eller bollen (DTL), svingens `xTecken` (M1).
    public let xTecken: Double
    /// Märkningens yta (`shownCrop`, på hela pixlar): hela bilden ytan kan visa.
    public let crop: CropRect
    /// Den del av `crop` som syns nu (S7c, BESLUT B59): inzoomad kring händerna när en position
    /// öppnas, nyp och dra ändrar den, dubbeltryck växlar mot hela `crop`. Samma proportioner
    /// som `crop`, så att ytan inte byter form. Ytans koordinater 0–1 gäller den. METOD M45
    public private(set) var zoom: CropRect
    /// Positionen som märks nu (index i `order`); `order.count` = klar.
    public private(set) var index: Int
    /// De sparade markeringarna per position.
    public private(set) var marks: [String: KlubbMarkering]
    /// Punkterna på positionen som märks nu, i hela bildens pixlar.
    public private(set) var grip: KlubbPunkt?
    public private(set) var hosel: KlubbPunkt?
    /// Greppets källa: ett fritt tryck, ringen ur handlederna eller modellens förslag (B93).
    public private(set) var gripSource = Klubba.kalla
    /// Hoselns källa: ett fritt tryck eller modellens förslag, godkänt (S7d, BESLUT B93).
    public private(set) var hoselSource = Klubba.kalla
    /// Modellens förslag för slaget (S7d, BESLUT B93, METOD MF8): rutorna ur förslagsfilen, och
    /// modellens namn och version. Tom = inga förslag; märkningen är då som i S7c.
    public let suggestions: [KlubbForslagFil.Ruta]
    public let suggestionModel: String
    /// Förslaget som visades när positionens punkter sattes (BESLUT B93): sparas med markeringen,
    /// också när en punkt flyttas senare och förslagsfilen bytts. En sparad position har sitt.
    public private(set) var pointsSuggestion: KlubbMarkering.Forslag?
    /// Rutans tid (s relativt klicket) där första punkten sattes; positionen sparas med den.
    public private(set) var frameT: Double?
    private var history: [Snapshot] = []

    struct Snapshot: Equatable, Sendable {
        let index: Int
        let marks: [String: KlubbMarkering]
        let grip: KlubbPunkt?
        let hosel: KlubbPunkt?
        let gripSource: String
        let hoselSource: String
        let pointsSuggestion: KlubbMarkering.Forslag?
        let frameT: Double?
    }

    /// Märkningen av ett slag; `existing` = slagets markeringar. Börjar på den första
    /// positionen som saknar en markering (alla klara: P1).
    public init(existing: [KlubbMarkering]?, width: Int, height: Int, crop: CropRect?, view: Vy, xTecken: Double,
                suggestions: [KlubbForslagFil.Ruta] = [], suggestionModel: String = "") {
        self.suggestions = suggestions
        self.suggestionModel = suggestionModel
        self.width = width
        self.height = height
        self.view = view
        self.xTecken = xTecken
        self.crop = Self.shownCrop(crop).snapped(width: width, height: height)
        zoom = self.crop
        let m = Dictionary((existing ?? []).map { ($0.position, $0) }, uniquingKeysWith: { _, b in b })
        marks = m
        // Den första positionen utan markering; ett helt markerat slag är klart ("All positions done").
        index = Self.order.firstIndex { m[$0] == nil } ?? Self.order.count
        grip = nil
        hosel = nil
        frameT = nil
        load()
    }

    public var done: Bool { index >= Self.order.count }
    /// Positionen som visas har en markering med båda punkterna: knappen heter Next och går
    /// vidare utan att ändra den (B59).
    public var isMarked: Bool { !done && marks[position]?.markerad == true }

    /// Nästa position i ordningen som saknar markering efter den som visas, runt till början;
    /// `order.count` (klar) när alla har en. METOD M45
    func nextMissing() -> Int {
        let n = Self.order.count
        for k in 1...n {
            let i = (index + k) % n
            if i != index, marks[Self.order[i]] == nil { return i }
        }
        return n
    }
    public var position: String { done ? Self.order[Self.order.count - 1] : Self.order[index] }
    /// Positionen i klartext, "P4 · Top of backswing · 3 of 10" (BESLUT B59); nil när alla är klara.
    public var positionLine: String? {
        done ? nil : Texter.markeringsPosition(position, nummer: index + 1, av: Self.order.count)
    }
    /// Nästa tryck sätter den punkten; nil när båda är satta.
    public var next: Point? { grip == nil ? .grip : hosel == nil ? .hosel : nil }
    public var hasPoints: Bool { grip != nil || hosel != nil }
    public var canUndo: Bool { !history.isEmpty }
    /// Markeringarna i svingens ordning (P1–P10, som `pass.json` sparar dem).
    public var result: [KlubbMarkering] { Klubba.positioner.compactMap { marks[$0] } }

    private func snapshot() -> Snapshot {
        Snapshot(index: index, marks: marks, grip: grip, hosel: hosel, gripSource: gripSource, hoselSource: hoselSource,
                 pointsSuggestion: pointsSuggestion, frameT: frameT)
    }

    private mutating func load() {
        let m = done ? nil : marks[position]
        let satt = m?.hoppad != true
        grip = satt ? m?.grepp : nil
        hosel = satt ? m?.hosel : nil
        gripSource = m?.greppKalla ?? Klubba.kalla
        hoselSource = m?.hoselKalla ?? Klubba.kalla
        // Bara en markerad position har en ruta med punkter; en hoppad visar förslaget (M45).
        frameT = m?.markerad == true ? m?.t : nil
        pointsSuggestion = m?.markerad == true ? m?.forslag : nil
    }

    // MARK: ytan

    /// Ytans punkt (0–1 i den del som syns, `zoom`) i hela bildens pixlar; nil nära kanten
    /// eller utanför ytan. METOD M45
    public func imagePoint(u: Double, v: Double) -> KlubbPunkt? {
        guard u.isFinite, v.isFinite, u >= Self.edge, u <= 1 - Self.edge, v >= Self.edge, v <= 1 - Self.edge else {
            return nil
        }
        return KlubbPunkt(x: (zoom.x + u * zoom.width) * Double(width), y: (zoom.y + v * zoom.height) * Double(height))
    }

    /// Bildens punkt på ytan (0–1 i den del som syns).
    public func surfacePoint(_ p: KlubbPunkt) -> (u: Double, v: Double) {
        ((p.x / Double(width) - zoom.x) / zoom.width, (p.y / Double(height) - zoom.y) / zoom.height)
    }

    // MARK: zoomen (S7c)

    /// En position öppnas så här mycket inzoomad, högst. BESLUT B59, METOD M45
    public static let zoomStart = 2.5
    /// Nypet zoomar högst så här mycket. METOD M45
    public static let zoomMax = 8.0
    /// Skaftet grepp → hosel när inget är markerat än, m (järn 7, METOD M49).
    public static let shaftM = 0.80
    /// En cirkel med radien så här mycket av skaftets längd kring skaftets förväntade mitt ska
    /// få plats: skaftet (halva längden åt varje håll) och lite marginal. METOD M45
    public static let zoomRadius = 0.6

    /// Hur mycket som är inzoomat: 1 = hela ytan.
    public var zoomFactor: Double { crop.width / zoom.width }

    /// Startzoomen (METOD M45): `zoomStart` gånger, men aldrig så mycket att en cirkel med radien
    /// `zoomRadius` · skaftets längd `length` (px) kring `center` (skaftets förväntade mitt) inte
    /// får plats, och aldrig under 1; mitten flyttad in i ytan. nil mitt = ytans mitt. Räknas i
    /// pixlar, som `klubba.zoom_start`.
    public static func startZoomRect(crop: CropRect, width: Int, height: Int, center: KlubbPunkt?,
                                     length: Double?) -> CropRect {
        let W = Double(width), H = Double(height)
        let cx0 = crop.x * W, cy0 = crop.y * H, cw = crop.width * W, ch = crop.height * H
        var z = zoomStart
        if let L = length, L > 0 { z = min(z, min(cw, ch) / (2 * zoomRadius * L)) }
        z = max(1, z)
        let w = cw / z, h = ch / z
        let c = center ?? KlubbPunkt(x: cx0 + cw / 2, y: cy0 + ch / 2)
        let x = min(max(cx0, c.x - w / 2), cx0 + cw - w), y = min(max(cy0, c.y - h / 2), cy0 + ch - h)
        return CropRect(x: x / W, y: y / H, width: w / W, height: h / H)
    }

    /// Zoomen när en position öppnas (METOD M45): kring skaftets förväntade mitt. Med positionens
    /// egen markering är det dess mitt; annars greppet (händerna, `hands`, annars de markerade
    /// greppens mitt) plus halva skaftet åt det håll skaftet pekar i den närmaste markerade
    /// positionen i svingen (grannen), och utan granne händerna. Skaftets längd ur positionens
    /// markering, annars medianen av de markerade, annars `shaftM` genom skalan (`cmPerPx`).
    /// Utan egen markering men med modellens grepp och hosel i rutan `t` (S7d, BESLUT B93) är
    /// det förslagets skaft, så att ✓ aldrig godkänner en punkt utanför det som syns.
    public mutating func startZoom(hands: KlubbPunkt?, cmPerPx: Double?, t: Double? = nil) {
        var egen = marks[position].flatMap { $0.markerad ? $0 : nil }
        if egen == nil, !done, let t, let f = suggestion(at: t), let g = f.grepp, let h = f.hosel {
            egen = KlubbMarkering(position: position, t: t, grepp: g, hosel: h)
        }
        func langd(_ m: KlubbMarkering) -> Double {
            ((m.hosel!.x - m.grepp!.x) * (m.hosel!.x - m.grepp!.x) + (m.hosel!.y - m.grepp!.y) * (m.hosel!.y - m.grepp!.y))
                .squareRoot()
        }
        let markerade = result.filter(\.markerad)
        var mitt = hands
        if mitt == nil, !markerade.isEmpty {
            mitt = KlubbPunkt(x: markerade.map { $0.grepp!.x }.reduce(0, +) / Double(markerade.count),
                              y: markerade.map { $0.grepp!.y }.reduce(0, +) / Double(markerade.count))
        }
        var L: Double? = nil
        if let e = egen {
            L = langd(e)
        } else if !markerade.isEmpty {
            let l = markerade.map(langd).sorted()
            L = l.count % 2 == 1 ? l[l.count / 2] : (l[l.count / 2 - 1] + l[l.count / 2]) / 2
        } else if let c = cmPerPx, c > 0 {
            L = Self.shaftM * 100 / c
        }
        if let e = egen {
            mitt = KlubbPunkt(x: (e.grepp!.x + e.hosel!.x) / 2, y: (e.grepp!.y + e.hosel!.y) / 2)
        } else if let g = mitt, let L, let granne = Self.granne(position, markerade) {
            let dx = granne.hosel!.x - granne.grepp!.x, dy = granne.hosel!.y - granne.grepp!.y
            let n = (dx * dx + dy * dy).squareRoot()
            if n > 0 { mitt = KlubbPunkt(x: g.x + dx / n * L / 2, y: g.y + dy / n * L / 2) }
        }
        zoom = Self.startZoomRect(crop: crop, width: width, height: height, center: mitt, length: L)
    }

    /// Den markerade positionen närmast `position` i svingens ordning (P1–P10), den tidigare vid
    /// lika avstånd.
    static func granne(_ position: String, _ markerade: [KlubbMarkering]) -> KlubbMarkering? {
        guard let i = Klubba.positioner.firstIndex(of: position) else { return nil }
        return markerade.filter { $0.position != position }.min { a, b in
            let da = abs((Klubba.positioner.firstIndex(of: a.position) ?? 0) - i)
            let db = abs((Klubba.positioner.firstIndex(of: b.position) ?? 0) - i)
            return da != db ? da < db : (Klubba.positioner.firstIndex(of: a.position) ?? 0) < (Klubba.positioner.firstIndex(of: b.position) ?? 0)
        }
    }

    /// Hela ytan.
    public mutating func showWhole() { zoom = crop }

    /// Nypet: zoomar `scale` gånger med bildens punkt under (u, v) kvar under fingrarna, mellan
    /// hela ytan och `zoomMax`.
    public mutating func zoom(by scale: Double, u: Double, v: Double) {
        guard scale.isFinite, scale > 0, u.isFinite, v.isFinite else { return }
        let ax = zoom.x + u * zoom.width, ay = zoom.y + v * zoom.height
        let w = min(crop.width, max(crop.width / Self.zoomMax, zoom.width / scale))
        let h = w * crop.height / crop.width
        zoom = Self.inom(CropRect(x: ax - u * w, y: ay - v * h, width: w, height: h), crop)
    }

    /// Dra: flyttar det som syns med fingret (du, dv i ytans 0–1), inom ytan.
    public mutating func pan(du: Double, dv: Double) {
        guard du.isFinite, dv.isFinite else { return }
        zoom = Self.inom(CropRect(x: zoom.x - du * zoom.width, y: zoom.y - dv * zoom.height, width: zoom.width,
                                  height: zoom.height), crop)
    }

    static func inom(_ r: CropRect, _ c: CropRect) -> CropRect {
        CropRect(x: min(max(c.x, r.x), c.maxX - r.width), y: min(max(c.y, r.y), c.maxY - r.height),
                 width: r.width, height: r.height)
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
        let w = zoom.width * loupePt / (Self.loupeZoom * max(1, surfaceWidthPt))
        let h = w * Double(width) / Double(height)
        let cx = zoom.x + u * zoom.width, cy = zoom.y + v * zoom.height
        let x = min(max(0, cx - w / 2), 1 - w), y = min(max(0, cy - h / 2), 1 - h)
        return CropRect(x: x, y: y, width: w, height: h)
    }

    /// Förstoringen som glaset ger: glasets bredd i punkter genom den del av ytan det visar.
    public func loupeMagnification(_ lc: CropRect, surfaceWidthPt: Double, loupePt: Double) -> Double {
        loupePt / (lc.width / zoom.width * surfaceWidthPt)
    }

    // MARK: handlingarna

    /// Ett tryck i rutan med tiden `t`: sätter nästa punkt. Greppet tas ur ringen (`ring`,
    /// handledernas mitt) när trycket träffar den, annars där trycket är. När hoseln är satt
    /// sparas positionen med rutans tid från första trycket och nästa position tas. Svarar om
    /// något ändrades: inget nära kanten, inget när båda är satta, och inget på en annan ruta
    /// än den första punktens (den rutan töms först, `clearPoints`). METOD M45
    /// Med modellens förslag (S7d, BESLUT B93): ett tryck på den streckade "1?" eller "2?" godkänner
    /// den punkten (källan `godkand_forslag`), ett tryck någon annanstans sätter punkten där (ett
    /// rättat förslag, `klick`). Modellens grepp ersätter ringen ur handlederna när det finns.
    @discardableResult
    public mutating func tap(u: Double, v: Double, t: Double, ring: KlubbPunkt? = nil, now: Date = Date()) -> Bool {
        guard !done, let n = next else { return false }
        if let f = frameT, abs(f - t) > Self.sameFrame { return false }
        let forslag = suggestion(at: frameT ?? t)
        if n == .grip, let gissning = gripGuess(ring: ring, t: t), avstand(gissning.0, u, v) <= Self.grabRadius {
            history.append(snapshot())
            grip = gissning.0
            gripSource = gissning.1
            frameT = t
            pointsSuggestion = forslagForMark(t)
            return true
        }
        if n == .hosel, let h = forslag?.hosel, avstand(h, u, v) <= Self.grabRadius,
           grip.map({ avstand(h, u, v) < avstand($0, u, v) }) ?? true {
            history.append(snapshot())
            hosel = h
            hoselSource = Klubba.kallaForslag
            frameT = frameT ?? t
            spara(now: now)
            return true
        }
        guard let p = imagePoint(u: u, v: v) else { return false }
        history.append(snapshot())
        if n == .grip {
            grip = p
            gripSource = Klubba.kalla
            frameT = t
            pointsSuggestion = forslagForMark(t)
        } else {
            // Punkt 2 på punkt 1 är ett tryck på greppet, inte klubbhuvudet (B59).
            if let g = grip, avstand(g, u, v) <= Self.grabRadius {
                history.removeLast()
                return false
            }
            hosel = p
            hoselSource = Klubba.kalla
            frameT = frameT ?? t
            spara(now: now)
        }
        return true
    }

    // MARK: modellens förslag (S7d)

    /// Modellens förslag i rutan med tiden `t` (METOD MF8: rutan i filen inom 2 ms, punkterna med
    /// konfidens ≥ 0,5); nil utan förslag. BESLUT B93
    public func suggestion(at t: Double) -> KlubbForslag? {
        guard let i = KlubbForslagFil.ruta(suggestions, t: t) else { return nil }
        let f = suggestions[i].visat(modell: suggestionModel)
        return f.tom ? nil : f
    }

    /// Gissningen av greppet som ett tryck godkänner: modellens förslag när det finns (källan
    /// `godkand_forslag`), annars ringen ur handlederna (`handlederna_bekraftad`, B47).
    public func gripGuess(ring: KlubbPunkt?, t: Double) -> (KlubbPunkt, String)? {
        if let g = suggestion(at: frameT ?? t)?.grepp { return (g, Klubba.kallaForslag) }
        return ring.map { ($0, Klubba.kallaRing) }
    }

    /// Det som visas av förslaget i rutan med tiden `t` (BESLUT B93): punkterna som saknas än;
    /// huvudets mitt bara när hoseln saknas och modellen inte gav hoseln. nil = inget att visa.
    public func shownSuggestion(t: Double) -> KlubbForslag? {
        guard !done, next != nil, let f = suggestion(at: frameT ?? t) else { return nil }
        if let ft = frameT, abs(ft - t) > Self.sameFrame { return nil }
        let ut = KlubbForslag(grepp: grip == nil ? f.grepp : nil, hosel: hosel == nil ? f.hosel : nil,
                              huvud: hosel == nil && f.hosel == nil ? f.huvud : nil,
                              huvudBox: hosel == nil && f.hosel == nil ? f.huvudBox : nil, modell: f.modell)
        return ut.tom ? nil : ut
    }

    /// Ett tryck räcker (✓, BESLUT B93): förslaget har varje punkt som saknas på positionen, och
    /// de syns i det inzoomade (en punkt utanför godkänns inte utan att ha setts). METOD MF8
    public func canUseSuggestion(t: Double) -> Bool {
        guard let f = shownSuggestion(t: t) else { return false }
        func syns(_ p: KlubbPunkt) -> Bool {
            let s = surfacePoint(p)
            return (0...1).contains(s.u) && (0...1).contains(s.v)
        }
        return (grip != nil || f.grepp.map(syns) == true) && (hosel != nil || f.hosel.map(syns) == true)
    }

    /// ✓: punkterna som saknas tas ur förslaget (godkända), och positionen sparas med rutan. Svarar
    /// om något ändrades. BESLUT B93
    @discardableResult
    public mutating func useSuggestion(t: Double, now: Date = Date()) -> Bool {
        guard canUseSuggestion(t: t), let f = shownSuggestion(t: t) else { return false }
        history.append(snapshot())
        if grip == nil, let g = f.grepp {
            grip = g
            gripSource = Klubba.kallaForslag
        }
        if hosel == nil, let h = f.hosel {
            hosel = h
            hoselSource = Klubba.kallaForslag
        }
        if frameT == nil {
            frameT = t
            pointsSuggestion = forslagForMark(t)
        }
        spara(now: now)
        return true
    }

    /// Förslaget som visas i rutan när första punkten sätts, för markeringen (B93): grepp och
    /// hosel, och huvudets mitt när den visas i stället för hoseln, med modellen. Ett tryck med
    /// en ledtråd på skärmen är då inte ett rent klick (`klubba.ursprung`, `--utan-forslag`).
    private func forslagForMark(_ t: Double) -> KlubbMarkering.Forslag? {
        guard let f = suggestion(at: t) else { return nil }
        let huvud = f.hosel == nil ? f.huvud : nil
        guard f.grepp != nil || f.hosel != nil || huvud != nil else { return nil }
        return KlubbMarkering.Forslag(grepp: f.grepp, hosel: f.hosel, huvud: huvud, modell: f.modell)
    }

    /// Markeringen med förslaget som visades när punkterna sattes. En godkänd punkt bär alltid
    /// sitt förslag (PC:ns `klubba.kontrollera` kräver det); finns det inte längre blir den ett
    /// tryck på samma plats.
    private func markering(_ g: KlubbPunkt, _ h: KlubbPunkt, _ f: Double, now: Date) -> KlubbMarkering {
        let fs = pointsSuggestion
        let gk = gripSource == Klubba.kallaForslag && fs?.grepp == nil ? Klubba.kalla : gripSource
        let hk = hoselSource == Klubba.kallaForslag && fs?.hosel == nil ? Klubba.kalla : hoselSource
        return KlubbMarkering(position: position, t: f, grepp: g, hosel: h,
                              greppKalla: gk == Klubba.kalla ? nil : gk, andrad: Self.sekund(now),
                              hoselKalla: hk == Klubba.kalla ? nil : hk, forslag: fs)
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
            hoselSource = Klubba.kalla
        }
        if let g = grip, let h = hosel, let f = frameT { marks[position] = markering(g, h, f, now: now) }
        return true
    }

    /// Positionen sparad med punkterna och rutans tid, och nästa position.
    private mutating func spara(now: Date) {
        guard let g = grip, let h = hosel, let f = frameT else { return }
        marks[position] = markering(g, h, f, now: now)
        index = nextMissing()
        load()
    }

    /// Nästa position som saknar markering, utan ändring (Next på en markerad position).
    /// Svarar false när positionen har en ensam punkt.
    @discardableResult
    public mutating func advance() -> Bool {
        guard !done, grip == nil || hosel != nil else { return false }
        history.append(snapshot())
        index = nextMissing()
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
        hoselSource = Klubba.kalla
        pointsSuggestion = nil
        frameT = nil
    }

    /// Klubban syns inte i rutan med tiden `t`: positionen hoppas över (sparas som hoppad), och
    /// nästa position som saknar markering visas. En markerad position skrivs aldrig över: där
    /// är knappen Next (`advance`).
    public mutating func skip(t: Double, now: Date = Date()) {
        guard !done else { return }
        if isMarked {
            advance()
            return
        }
        history.append(snapshot())
        marks[position] = KlubbMarkering(position: position, t: t, grepp: nil, hosel: nil, hoppad: true,
                                         andrad: Self.sekund(now))
        index = nextMissing()
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
        hoselSource = s.hoselSource
        pointsSuggestion = s.pointsSuggestion
        frameT = s.frameT
    }

    /// Riktpinnen (två tryck på en pinne längs mållinjen) gäller bara bakifrån. METOD M48
    public var stickAvailable: Bool { view == .dtl }

    /// Rutans tid att visa för positionen: punkternas ruta (en markerad position har sin),
    /// annars förslaget (`suggestedTime`), också för en hoppad position, annars den hoppade
    /// rutan, annars träffen. METOD M45
    public func shownTime(measure: ShotMeasure?, impact: Double, paired: [String: Double] = [:]) -> Double {
        frameT ?? suggestedTime(measure: measure, paired: paired) ?? marks[position]?.t ?? impact
    }

    /// Förslaget till positionens ruta (METOD M45): för P2, P6 och P8 framifrån rutan där
    /// skaftets vinkel mellan de markerade positionerna före och efter går genom vågrätt
    /// (`Klubba.forslagTidSkaft`, P2 från baksvingens start), bakifrån FO-slagets tid med två
    /// parade telefoner (`paired`, `ClubPairTime`); annars kroppens positioner (samma som PC:n).
    public func suggestedTime(measure: ShotMeasure?, paired: [String: Double] = [:]) -> Double? {
        if Klubba.skaftets.contains(position) {
            if view == .fo, let t = Klubba.forslagTidSkaft(position, marks: result, xTecken: xTecken,
                                                            start: measure?.start) { return t }
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
/// telefonerna inte flyttar tiden. Den styrande telefonens vy står i `par.json` (`PairFile.view`).
public enum ClubPairTime {
    /// Klickparet för DTL-slagets klick `dtlIndex`: index i DTL-telefonens och FO-telefonens
    /// klick (serien). nil när parningen inte är DTL mot FO (`leadView` och följarens vy),
    /// är osäker, eller klicket inte parades. Den styrandes klick är `a` i parningen, följarens `b`.
    public static func pair(_ entry: PairEntry, leadView: Vy, dtlIndex: Int) -> (dtl: Int, fo: Int)? {
        guard Set([leadView, entry.follower.view]) == Set([Vy.dtl, Vy.fo]), !entry.uncertain else { return nil }
        let dtlStyr = leadView == .dtl
        guard let p = entry.pairing.pairs.first(where: { (dtlStyr ? $0.a : $0.b) == dtlIndex }) else { return nil }
        return dtlStyr ? (dtl: p.a, fo: p.b) : (dtl: p.b, fo: p.a)
    }

    /// FO-markeringarnas P2, P6 och P8 som tider för DTL-slaget med klicket `dtlIndex`, s
    /// relativt DTL-klicket. Klicken tas ur paret med index i `dtlClicks` och `foClicks`
    /// (filtider, s). Hoppade och osatta positioner tas inte med; tom utan par.
    public static func dtlTimes(fo: [KlubbMarkering], entry: PairEntry, leadView: Vy, dtlIndex: Int,
                                dtlClicks: [Double], foClicks: [Double]) -> [String: Double] {
        guard let p = pair(entry, leadView: leadView, dtlIndex: dtlIndex), dtlClicks.indices.contains(p.dtl),
              foClicks.indices.contains(p.fo) else { return [:] }
        // Följarens filtid = den styrandes + hitOffset.
        let foTillDtl = leadView == .dtl ? -entry.hitOffset : entry.hitOffset
        var ut: [String: Double] = [:]
        for m in fo where Klubba.skaftets.contains(m.position) && m.markerad {
            ut[m.position] = foClicks[p.fo] + m.t + foTillDtl - dtlClicks[p.dtl]
        }
        return ut
    }
}
