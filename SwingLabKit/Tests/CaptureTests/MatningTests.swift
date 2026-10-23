import Foundation
import XCTest
import Swing
import SwingDemo
@testable import Capture

/// S4b: från analysens leder till måtten, passets mått och granskningens linjer, på
/// PÅHITTADE svingar (SwingDemo, CLAUDE.md: Dataregeln). METOD MS14, MS15, BESLUT B35
final class MatningTests: XCTestCase {
    static let rot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    /// Klicket i seriens fil, s.
    static let klick = 12.5

    func katalog() throws -> Katalog {
        try Katalog.las(Data(contentsOf: Self.rot.appendingPathComponent("katalog.json")))
    }

    /// En påhittad sving som analysens leder: t relativt klicket, pts i filen, lederna i
    /// filens ordning (högerspelare: samma som svingens främre/bakre) med konfidensen c.
    static func serie(_ sv: Sving, c: Double = 0.9) -> JointSeries {
        let frames = sv.t.indices.map { k -> PoseFrame in
            let leder = (0..<13).map { i -> PoseJoint? in
                let p = sv.leder[i][k]
                return p.hel ? PoseJoint(x: p.x, y: p.y, c: c) : nil
            }
            return PoseFrame(t: sv.t[k] - sv.tKlick, pts: sv.t[k] - sv.tKlick + klick, joints: leder, confidence: 0.9)
        }
        return JointSeries(width: 1080, height: 1920, frames: frames)
    }

    static func slag(_ id: String = "s01", impact: Double = klick) -> ShotRecord {
        ShotRecord(id: id, series: 1, click: Click(time: klick, strength: 50), impact: impact, verdict: .swing,
                   joints: ShotRecord.jointsPath(id))
    }

    static let fo = PassSetup(view: .fo, club: "j7", distance: 3, hand: .hoger)

    // MARK: Lederna till måtten

    /// Lederna som en sving i S1:s form ger samma mått och positioner som S1 på samma
    /// sving: tiderna relativt klicket, träffen som t_klick. METOD MS14, MT1
    func testMattenArS1s() throws {
        let sv = DemoSving.fo(sway: (topp: -3, traff: 4, finish: 8))
        let facit = try Matt.mat(sv)
        let m = ShotMeasuring.measure(Self.serie(sv), shot: Self.slag(), setup: Self.fo, height: 1.80)
        XCTAssertNil(m.problem)
        XCTAssertTrue(m.ok)
        XCTAssertFalse(m.heightAssumed)
        XCTAssertEqual(m.heightM, 1.80)
        XCTAssertEqual(m.cmPerPx ?? .nan, facit.cmPerPx, accuracy: 1e-9)
        XCTAssertEqual(Set(m.values.keys), Set(facit.matt.keys))
        for (k, v) in facit.matt {
            XCTAssertEqual(m.values[k] ?? .nan, v, accuracy: 1e-6, k)
        }
        XCTAssertEqual(m.values["backen_sway_topp"] ?? .nan, -3, accuracy: 0.5)
        for p in Positioner.namn {
            if let t = facit.positioner.tid(p) {
                XCTAssertEqual(m.positions[p] ?? .nan, t - sv.tKlick, accuracy: 1e-6, p)
            } else {
                XCTAssertNil(m.positions[p], p)
            }
        }
        XCTAssertEqual(m.positions["P7"] ?? .nan, 0, accuracy: 1e-9)
        XCTAssertEqual(m.positions["P4"] ?? .nan, facit.faser.topp - sv.tKlick, accuracy: 1e-6)
    }

    /// Samma sving som filformatet ger (docs/FORMAT.md): en saknad led blir [0, 0, 0] och en
    /// led under 0,3 saknas, som PC:ns paket.till_sving. METOD MT1, MS14
    func testSammaSomFilformatet() throws {
        var s = Self.serie(DemoSving.dtl(thrust: (topp: 1, traff: 3, finish: 5)))
        s.frames[10].joints[0] = nil
        s.frames[11].joints[5] = PoseJoint(x: 1, y: 2, c: 0.2)
        let a = try ShotMeasuring.sving(s, view: .dtl, hand: .hoger, heightM: 1.8, impact: -0.01)
        var rutor: [[String: Any]] = []
        for f in s.frames {
            let leder: [[Double]] = f.joints.map { j in j.map { [$0.x, $0.y, $0.c] } ?? [0, 0, 0] }
            rutor.append(["t": f.t, "leder": leder])
        }
        let json: [String: Any] = ["format": 1, "vy": "dtl", "hand": "hoger", "spelarens_langd_m": 1.8,
                                   "t_klick": -0.01, "rutor": rutor]
        let b = try Sving.las(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(a.vy, .dtl)
        XCTAssertEqual(a.xTecken, b.xTecken)
        XCTAssertEqual(a.tKlick, b.tKlick, accuracy: 1e-12)
        XCTAssertEqual(a.t.count, b.t.count)
        for k in a.t.indices { XCTAssertEqual(a.t[k], b.t[k], accuracy: 1e-9) }
        for l in 0..<13 {
            for k in a.t.indices {
                let p = a.leder[l][k], q = b.leder[l][k]
                XCTAssertEqual(p.hel, q.hel, "led \(l) ruta \(k)")
                if p.hel && q.hel {
                    XCTAssertEqual(p.x, q.x, accuracy: 1e-9)
                    XCTAssertEqual(p.y, q.y, accuracy: 1e-9)
                }
            }
        }
        XCTAssertFalse(a.leder[0][10].hel, "saknad led")
        XCTAssertFalse(a.leder[5][11].hel, "konfidens 0,2 räknas som saknad (M1)")
        // En vänsterspelare speglas som i filen.
        let v = try ShotMeasuring.sving(s, view: .dtl, hand: .vanster, heightM: 1.8, impact: 0)
        XCTAssertEqual(v.xTecken, -1)
    }

    /// Längden: utan Johannes längd mäts med 1,80 m och skalan märks antagen; en annan
    /// längd skalar måtten i cm och lämnar vinklarna. METOD M2, MS14
    func testLangdenOchDenAntagnaSkalan() throws {
        let s = Self.serie(DemoSving.fo(sway: (topp: -3, traff: 4, finish: 8)))
        let antagen = ShotMeasuring.measure(s, shot: Self.slag(), setup: Self.fo, height: nil)
        XCTAssertTrue(antagen.heightAssumed)
        XCTAssertEqual(antagen.heightM, ShotMeasuring.assumedHeightM)
        let lang = ShotMeasuring.measure(s, shot: Self.slag(), setup: Self.fo, height: 1.98)
        XCTAssertFalse(lang.heightAssumed)
        let a = try XCTUnwrap(antagen.values["backen_sway_topp"]), b = try XCTUnwrap(lang.values["backen_sway_topp"])
        XCTAssertEqual(b / a, 1.98 / 1.80, accuracy: 1e-9)
        XCTAssertEqual(antagen.values["sidbojning_topp"] ?? .nan, lang.values["sidbojning_topp"] ?? 0, accuracy: 1e-9)
    }

    /// Simulatorprovets påhittade Vision-leder är FO-svingens, skalade till bilden.
    func testDemoledernaArSvingens() {
        let sv = DemoSving.fo(sway: (topp: -3, traff: 4, finish: 8))
        for k in [0, 300, 528, 600, 700] {
            let j = DemoSving.lederFO(sv.t[k] - sv.tKlick, sway: (topp: -3, traff: 4, finish: 8), width: 270, height: 480)
            XCTAssertEqual(j.count, 13)
            for i in 0..<13 {
                XCTAssertEqual(j[i].x, sv.leder[i][k].x / 4, accuracy: 1e-9)
                XCTAssertEqual(j[i].y, sv.leder[i][k].y / 4, accuracy: 1e-9)
            }
        }
    }

    /// Ett slag som inte går att mäta får skälet i stället för måtten.
    func testSlagSomInteGarAttMata() {
        var s = Self.serie(DemoSving.fo(sway: (topp: -3, traff: 4, finish: 8)))
        for k in s.frames.indices {
            s.frames[k].joints[5] = nil
            s.frames[k].joints[6] = nil
        }
        let utanHander = ShotMeasuring.measure(s, shot: Self.slag(), setup: Self.fo, height: 1.8)
        XCTAssertEqual(utanHander.problem, "hands")
        XCTAssertFalse(utanHander.ok)
        XCTAssertTrue(utanHander.values.isEmpty)
        let tom = ShotMeasuring.measure(JointSeries(width: 1080, height: 1920, frames: []), shot: Self.slag(),
                                        setup: Self.fo, height: 1.8)
        XCTAssertEqual(tom.problem, "format")
    }

    // MARK: Passet

    /// Tre slag med kända sway: passets median, "Detection wrong" tar bort ett slag och
    /// går att ångra, en ny längd mäter om, en icke-sving räknas inte, och allt överlever
    /// pass.json. METOD MS14, BESLUT B35
    func testPassetsMattOchDetectionWrong() throws {
        var p = SlagTests.pass(klick: [[5.0, 12.0, 20.0]])
        p.syncShots()
        let sway = [-2.0, -4.0, -9.0]
        var serier: [String: JointSeries] = [:]
        for i in 0..<3 {
            p.shots[i].verdict = .swing
            p.shots[i].joints = ShotRecord.jointsPath(p.shots[i].id)
            serier[p.shots[i].id] = Self.serie(DemoSving.fo(sway: (topp: sway[i], traff: 2, finish: 4)))
        }
        XCTAssertTrue(p.countedSwings.isEmpty, "inget mätt än")
        XCTAssertTrue(p.measureShots(height: nil) { serier[$0.id] })
        XCTAssertFalse(p.measureShots(height: nil) { serier[$0.id] }, "allt är mätt")
        XCTAssertEqual(p.countedSwings.count, 3)
        XCTAssertEqual(p.measuredHeight?.assumed, true)
        let varden = p.shots.map { $0.measure?.values["backen_sway_topp"] ?? .nan }
        for i in 0..<3 { XCTAssertEqual(varden[i], sway[i], accuracy: 0.5) }

        let v = p.visningsPass
        XCTAssertEqual(v.klubba, "7i")
        XCTAssertEqual(v.slag, 3)
        XCTAssertEqual(v.serie1, 3)
        XCTAssertEqual(v.median("backen_sway_topp", "fo") ?? .nan, varden[1], accuracy: 1e-9)

        p.setDetectionWrong(true, shot: "s03")
        XCTAssertEqual(p.shots[2].detectionWrong, true)
        XCTAssertEqual(p.countedSwings.count, 2)
        XCTAssertEqual(p.visningsPass.varden("backen_sway_topp", "fo"), [varden[0], varden[1]])
        XCTAssertEqual(ShotRow.rows(p).map(\.detectionWrong), [false, false, true])
        let sparat = try PassCoding.decoder().decode(PassState.self, from: PassCoding.encoder().encode(p))
        XCTAssertEqual(sparat, p, "måtten och märkningen står i pass.json")
        p.setDetectionWrong(false, shot: "s03")
        XCTAssertNil(p.shots[2].detectionWrong)
        XCTAssertEqual(p.countedSwings.count, 3)

        // En ny längd mäter om; en annan dom räknas inte.
        XCTAssertTrue(p.needsMeasure(p.shots[0], height: 1.9))
        XCTAssertFalse(p.needsMeasure(p.shots[0], height: nil))
        XCTAssertTrue(p.measureShots(height: 1.9) { serier[$0.id] })
        XCTAssertEqual(p.measuredHeight?.heightM, 1.9)
        p.setVerdict(.notSwing, shot: "s01")
        XCTAssertEqual(p.countedSwings.count, 2)

        // Redigeringen gör om lederna: måtten och märkningen följer med bort. METOD MS13
        p.setDetectionWrong(true, shot: "s02")
        p.setEdit(SeriesEdit(window: TimeWindow(start: 1, end: 25), crop: CropRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5)),
                  series: 1)
        XCTAssertTrue(p.shots.allSatisfy { $0.measure == nil && $0.detectionWrong == nil })
    }

    /// Ett pass.json från före S4b (inga mått, ingen märkning, ingen längd) går att läsa.
    func testGamlaFilerGarAttLasa() throws {
        var p = SlagTests.pass(klick: [[5.0]])
        p.syncShots()
        let json = String(decoding: try PassCoding.encoder().encode(p), as: UTF8.self)
        XCTAssertFalse(json.contains("\"measure\""))
        XCTAssertFalse(json.contains("\"detectionWrong\""))
        let s = try PassCoding.decoder().decode(AppSettings.self, from: Data(#"{"keepOriginals": true}"#.utf8))
        XCTAssertNil(s.heightM)
    }

    /// Passen före: samma klubba och vy, äldst först, och bara pass med mätta slag.
    func testDeTidigarePassen() throws {
        func pass(_ id: String, _ dag: Double, club: String = "j7", view: Vy = .fo, matt: Bool = true,
                  h: Double = 1.8) -> PassState {
            var p = PassState(id: id, created: Date(timeIntervalSince1970: 1_792_000_000 + dag * 86_400),
                              setup: PassSetup(view: view, club: club, distance: 3, hand: .hoger))
            var s = Self.slag()
            if matt { s.measure = ShotMeasure(heightM: h, heightAssumed: false, values: ["backen_sway_topp": dag]) }
            p.shots = [s]
            p.series = SlagTests.pass(klick: [[Self.klick]]).series
            return p
        }
        let nu = pass("20261110-120000", 10)
        let alla = [pass("20261105-120000", 5), pass("20261101-120000", 1), pass("20261108-120000", 8, club: "dr"),
                    pass("20261107-120000", 7, view: .dtl), pass("20261106-120000", 6, matt: false),
                    pass("20261112-120000", 12), pass("20261103-120000", 3, h: 1.9), nu]
        let fore = PassHistory.earlier(nu, among: alla)
        XCTAssertEqual(fore.map(\.id), ["20261101-120000", "20261105-120000"], "samma klubba, vy och längd")
        XCTAssertEqual(PassHistory.candidates(nu, among: alla).count, 4)
        XCTAssertEqual(PassHistory.unmeasured(nu, among: alla), 2, "utan mått och med en annan längd räknas")
        XCTAssertEqual(PassHistory.baseline(fore)["backen_sway_topp"], [1, 5])
    }

    // MARK: Granskningens linjer

    /// Lederna i utsnittets koordinater, fyllda från 0,3, ihåliga från 0,1, linjerna
    /// streckade när en led är osäker, och rutan och positionerna på slagets eget rutnät.
    /// METOD MS15
    func testGranskningensLinjer() {
        let leder: [PoseJoint?] = (0..<13).map { i in PoseJoint(x: 100 + Double(i) * 20, y: 200 + Double(i) * 40, c: 0.9) }
        var f1 = PoseFrame(t: -0.01, pts: 9.99, joints: leder, confidence: 0.9)
        f1.joints[3] = PoseJoint(x: 160, y: 320, c: 0.2)          // vänster armbåge osäker
        f1.joints[12] = PoseJoint(x: 1, y: 1, c: 0.05)            // under 0,1: ritas inte
        f1.joints[9] = nil
        let f0 = PoseFrame(t: -0.02, pts: 9.98, joints: leder, confidence: 0.9)
        let f2 = PoseFrame(t: 0.0, pts: 10.0, joints: leder, confidence: 0.9)
        let s = JointSeries(width: 1080, height: 1920, frames: [f2, f0, f1])
        let crop = CropRect(x: 0.05, y: 0.1, width: 0.5, height: 0.5)
        let r = ShotReview(series: s, crop: crop)
        XCTAssertEqual(r.frames.map(\.t), [-0.02, -0.01, 0.0], "i tidsordning")
        XCTAssertEqual(r.crop, crop.snapped(width: 1080, height: 1920))
        XCTAssertEqual(r.aspect, (0.5 * 1080) / (0.5 * 1920), accuracy: 1e-9)

        let o = r.overlay(1)
        XCTAssertEqual(o.points.count, 13)
        let nasa = try? XCTUnwrap(o.points[0])
        XCTAssertEqual(nasa?.x ?? .nan, (100.0 / 1080 - r.crop.x) / r.crop.width, accuracy: 1e-12)
        XCTAssertEqual(nasa?.y ?? .nan, (200.0 / 1920 - r.crop.y) / r.crop.height, accuracy: 1e-12)
        XCTAssertEqual(nasa?.state, .measured)
        XCTAssertEqual(o.points[3]?.state, .weak)
        XCTAssertNil(o.points[12])
        XCTAssertNil(o.points[9])
        let par = o.lines.map { [$0.from, $0.to] }
        XCTAssertTrue(par.contains([1, 2]) && par.contains([7, 8]), "axellinjen och höftlinjen")
        XCTAssertFalse(par.contains([7, 9]) || par.contains([9, 11]) || par.contains([10, 12]), "saknade leder ger ingen linje")
        XCTAssertEqual(o.lines.first { $0.from == 1 && $0.to == 3 }?.measured, false, "streckad mot den osäkra")
        XCTAssertEqual(o.lines.first { $0.from == 1 && $0.to == 2 }?.measured, true)
        XCTAssertFalse(par.contains([1, 7]), "ingen bål: ingen figur (B13)")

        // Hela bilden utan utsnitt.
        let hel = ShotReview(series: s, crop: nil).overlay(0)
        XCTAssertEqual(hel.points[0]?.x ?? .nan, 100.0 / 1080, accuracy: 1e-12)

        // Rutorna och positionerna.
        XCTAssertEqual(r.index(nearestT: -0.014), 1)
        XCTAssertEqual(r.index(nearestT: 5), 2)
        XCTAssertEqual(r.index(nearestT: -5), 0)
        XCTAssertEqual(r.index(nearestPts: 9.981), 0)
        // Spelarens ruta: den senaste med tid ≤ spelarens tid (golv), inte den närmaste.
        XCTAssertEqual(r.index(atPts: 9.9899), 1, "inom avrundningen: rutan vid 9,99")
        XCTAssertEqual(r.index(atPts: 9.9989), 1, "nästan nästa ruta: fortfarande 9,99")
        XCTAssertEqual(r.index(atPts: 10.5), 2)
        XCTAssertEqual(r.index(atPts: 9.0), 0)
        XCTAssertEqual(r.seekTime(1) ?? .nan, 9.99 + 0.25 / 240, accuracy: 1e-12)
        XCTAssertEqual(r.index(atPts: r.seekTime(1)!), 1, "sökt rutas tid ger samma ruta")
        XCTAssertNil(r.seekTime(9))
        let m = ShotMeasure(heightM: 1.8, heightAssumed: false, positions: ["P4": -0.019, "P7": 0.001])
        let pos = r.positions(m)
        XCTAssertEqual(pos.map(\.name), Positioner.namn)
        XCTAssertEqual(pos.first { $0.name == "P4" }?.index, 0)
        XCTAssertEqual(pos.first { $0.name == "P7" }?.index, 2)
        XCTAssertNil(pos.first { $0.name == "P3" }?.index ?? nil, "saknad position")
        XCTAssertTrue(r.positions(nil).allSatisfy { $0.index == nil })
    }

    /// Måtten vid en position för ett mätt slag: katalogens fel och mått i vyn, med
    /// märkningen, accenten för det som övas och "after impact" för chicken wing. METOD M29
    func testMattenVidPositionerna() throws {
        let k = try katalog()
        let sv = DemoSving.fo(sway: (topp: -3, traff: 4, finish: 8))
        let m = ShotMeasuring.measure(Self.serie(sv), shot: Self.slag(), setup: Self.fo, height: 1.8)
        let p4 = Positionsmatt.rader(k, vy: .fo, position: "P4", varden: m.values, ovas: ["sway_topp"])
        // Felen först, sedan katalogens mått (S1b: knänas sway, bröstets och handens lyft, METOD M31–M34).
        XCTAssertEqual(p4.map(\.matt), ["backen_sway_topp", "sidbojning_topp", "framre_armbage_topp",
                                        "framre_kna_sway_topp", "bakre_kna_sway_topp", "brost_lyft_topp",
                                        "hand_lyft_topp", "huvud_lyft_topp"])
        XCTAssertTrue(p4.first { $0.matt == "bakre_kna_sway_topp" }!.ovas, "bakre knäets sway följer sway-felet")
        let sway = try XCTUnwrap(p4.first)
        XCTAssertEqual(sway.namn, "Hip sway")                  // granskningen: utan position (BESLUT B40)
        XCTAssertTrue(sway.ovas)
        XCTAssertEqual(sway.markning, .b10)
        XCTAssertEqual(sway.enhet, "cm")
        XCTAssertEqual(sway.varde, Tal.tecken(Avrundning.avrunda("backen_sway_topp", m.values["backen_sway_topp"]), decimaler: 1))
        XCTAssertNotNil(sway.spann, "katalogens gräns")
        XCTAssertNil(p4[1].spann, "egen baslinje utan tidigare pass: inget spann")
        XCTAssertEqual(p4[1].markning, .egen)

        let p3 = Positionsmatt.rader(k, vy: .fo, position: "P3", varden: m.values, ovas: ["sway_topp"])
        XCTAssertEqual(p3.map(\.matt), ["backen_sway_p3", "framre_armbage_p3"])
        XCTAssertTrue(p3[0].ovas, "sway hittills följer felets accent")
        XCTAssertFalse(p3[1].ovas)

        let p7 = Positionsmatt.rader(k, vy: .fo, position: "P7", varden: m.values)
        let av = try XCTUnwrap(p7.first { $0.matt == "axellinje_lutning_traff" })
        XCTAssertEqual(av.varde, "—")
        XCTAssertEqual(av.markning, .av)
        XCTAssertTrue(p7.contains { $0.matt == "hander_fore_adress_traff" })
        // Farterna märks oprövade (METOD M35–M37, BESLUT B11), i m/s.
        let fart = try XCTUnwrap(p7.first { $0.matt == "handfart_max" })
        XCTAssertEqual(fart.markning, .oprovad)
        XCTAssertEqual(fart.enhet, "m/s")
        XCTAssertTrue(fart.upplasning.contains("untested"))
        XCTAssertFalse(p7.contains { $0.matt == "backen_thrust_traff" }, "DTL:s mått syns inte i FO")

        let p9 = Positionsmatt.rader(k, vy: .fo, position: "P9", varden: m.values)
        XCTAssertEqual(p9.first?.under, "after impact")

        // Med tidigare pass blir den egna baslinjen ett spann.
        let bas = ["sidbojning_topp": (0..<10).map { Double($0) }]
        let medBas = Positionsmatt.rader(k, vy: .fo, position: "P4", varden: m.values, baslinje: bas)
        guard case .baslinje? = medBas[1].spann?.zon else { return XCTFail("egen baslinje utan spann") }

        // DTL vid P1: katalogens mått i den vyn.
        let dtl = ShotMeasuring.measure(Self.serie(DemoSving.dtl(thrust: (topp: 1, traff: 3, finish: 5))),
                                        shot: Self.slag(), setup: PassSetup(view: .dtl, club: "j7", distance: 3, hand: .hoger),
                                        height: 1.8)
        let p1 = Positionsmatt.rader(k, vy: .dtl, position: "P1", varden: dtl.values)
        XCTAssertEqual(p1.map(\.matt), ["brost_bojning_adress", "bakre_kna_adress", "backen_bojning_adress",
                                        "framre_kna_adress"])
        XCTAssertTrue(p1.allSatisfy { $0.varde != "—" && $0.enhet == "°" })
        XCTAssertEqual(dtl.values["framre_kna_adress"]!, 20, accuracy: 0.5)     // DemoSving: främre knät 20°
        let svenska = CharacterSet(charactersIn: "åäöÅÄÖ")
        for r in p1 + p3 + p4 + p7 + p9 { XCTAssertNil((r.namn + r.upplasning).rangeOfCharacter(from: svenska), r.namn) }
    }

    /// Passets kort under tre svingar: medianen av de som finns, utan spridning och utan
    /// "vs" (METOD MS14); från tre svingar som förut (M25).
    func testPassetsKortMedFaSvingar() throws {
        let k = try katalog()
        func pass(_ v: [Double]) -> Swing.Pass {
            Swing.Pass(datum: Tal.dag(2026, 10, 22), klubba: "7i",
                       svingar: v.map { SvingMatt(vy: .fo, matt: ["backen_sway_topp": $0]) })
        }
        let forra = pass([-6, -5, -7])
        let ett = Passvisning(katalog: k, pass: [forra, pass([-2.04])]).kort.first { $0.id == "sway_topp" }
        XCTAssertEqual(ett?.varde, "−2.0")
        XCTAssertNil(ett?.skillnad)
        XCTAssertNil(ett?.spann?.spridning)
        XCTAssertNil(ett?.spann?.forra, "utan jämförelse mot förra passet under tre svingar")
        let tva = Passvisning(katalog: k, pass: [pass([-2, -3])]).kort.first { $0.id == "sway_topp" }
        XCTAssertEqual(tva?.varde, "−2.5")
        let tre = Passvisning(katalog: k, pass: [forra, pass([-2, -3, -4])]).kort.first { $0.id == "sway_topp" }
        XCTAssertEqual(tre?.varde, "−3.0")
        XCTAssertEqual(tre?.skillnad, "+3.0 cm vs Oct 22")
        let tom = Passvisning(katalog: k, pass: [pass([])]).kort.first { $0.id == "sway_topp" }
        XCTAssertEqual(tom?.varde, "—")
        // Samma värde i alla slag: spannet får en minsta bredd, axelns ändar skiljer sig.
        let lika = Spann(nu: 20.004, spridning: (lo: 20.003, hi: 20.005), forra: nil, gront: nil, baslinje: nil,
                         decimaler: 1)
        XCTAssertNotEqual(lika.etiketter.first?.text, lika.etiketter.last?.text)
        let heltal = Spann(nu: 20, spridning: (lo: 20, hi: 20), forra: nil, gront: nil, baslinje: nil, decimaler: 0)
        XCTAssertNotEqual(heltal.etiketter.first?.text, heltal.etiketter.last?.text)
    }
}
