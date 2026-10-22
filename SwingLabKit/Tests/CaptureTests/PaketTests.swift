import Foundation
import XCTest
import Swing
import SwingDemo
@testable import Capture

/// S2f: zip-skrivaren, manifestet, paketet ur ett pass och vägen tillbaka
/// (`att_jobba_pa.json`), på PÅHITTADE pass (CLAUDE.md, Dataregeln). Att PC:n läser det
/// appen skriver prövas i simulatorprovet (`Prov/SwingLabProvPaket.swift`) och
/// `tools/tests/test_appens_paket.py` i kompilera.yml. S2_SPEC §8.3–8.5, §11.2. BESLUT B27, B28
final class PaketTests: XCTestCase {

    func tmp() throws -> URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("paket-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    // MARK: CRC och zip

    func testCRCMotKantVarde() {
        XCTAssertEqual(CRC32.checksum(Data("123456789".utf8)), 0xCBF4_3926)
        XCTAssertEqual(CRC32.checksum(Data()), 0)
        // I bitar ger samma summa som i ett svep.
        var c = CRC32()
        c.update(Data("1234".utf8))
        c.update(Data("56789".utf8))
        XCTAssertEqual(c.value, 0xCBF4_3926)
    }

    func testEnLitenOchEnStorFilTurOchRetur() throws {
        let d = try tmp()
        // 5 MB påhittade byte (LCG), större än en bit om 1 MB och inte jämnt delbar.
        var x: UInt32 = 1
        var stor = Data(count: 5 * 1_000_000 + 17)
        stor.withUnsafeMutableBytes { (b: UnsafeMutableRawBufferPointer) in
            for i in 0..<b.count {
                x = x &* 1_103_515_245 &+ 12345
                b[i] = UInt8(truncatingIfNeeded: x >> 16)
            }
        }
        let storFil = d.appendingPathComponent("stor.bin")
        try stor.write(to: storFil)
        let zipUrl = d.appendingPathComponent("p.zip")
        let datum = Date(timeIntervalSince1970: 1_792_848_612)    // 2026-10-24 13:30:12 UTC
        let z = try ZipWriter(url: zipUrl, date: datum)
        try z.add(name: "manifest.json", data: Data("{\"a\":1}".utf8))
        try z.addFile(name: "klipp/s01.mov", from: storFil)
        try z.add(name: "tom.txt", data: Data())
        try z.add(name: "slag/svängen.json", data: Data("[]".utf8))
        try z.finish()

        let k = try ZipCatalog(url: zipUrl)
        XCTAssertEqual(k.names, ["manifest.json", "klipp/s01.mov", "tom.txt", "slag/svängen.json"])
        XCTAssertEqual(try k.data(named: "manifest.json"), Data("{\"a\":1}".utf8))
        XCTAssertEqual(try k.data(named: "klipp/s01.mov"), stor)
        XCTAssertEqual(try k.data(named: "tom.txt"), Data())
        XCTAssertEqual(k.entry("klipp/s01.mov")?.size, UInt32(stor.count))
        XCTAssertEqual(k.entry("klipp/s01.mov")?.crc, CRC32.checksum(stor))
        for e in k.entries {
            XCTAssertEqual(e.method, 0, "lagrad")
            XCTAssertEqual(e.flags, 0x0800, "UTF-8")
        }
        // Filen är exakt huvudena, datan, katalogen och slutposten.
        let namnByte: Int = k.entries.reduce(0) { $0 + Data($1.name.utf8).count }
        let huvuden: Int = 4 * (30 + 46) + 2 * namnByte
        let datan: Int = 7 + stor.count + 0 + 2
        XCTAssertEqual(try Data(contentsOf: zipUrl).count, huvuden + datan + 22)
        // DOS-tiden i UTC: 13:30:12 och 2026-10-24.
        let rå = [UInt8](try Data(contentsOf: zipUrl).prefix(14))
        let tid: Int = Int(rå[10]) + 256 * Int(rå[11])
        let dag: Int = Int(rå[12]) + 256 * Int(rå[13])
        XCTAssertEqual(tid, 13 * 2048 + 30 * 32 + 6)
        XCTAssertEqual(dag, (2026 - 1980) * 512 + 10 * 32 + 24)
    }

    func testForStortOchFelNamnKastar() throws {
        let d = try tmp()
        let z = try ZipWriter(url: d.appendingPathComponent("a.zip"))
        XCTAssertEqual(z.maxEntries, 0xFFFE, "under fältets största värde (zip64-märket)")
        XCTAssertEqual(z.maxBytes, 0xFFFF_FFFE)
        z.maxEntries = 2
        try z.add(name: "a", data: Data([1]))
        try z.add(name: "b", data: Data([2]))
        XCTAssertThrowsError(try z.add(name: "c", data: Data([3]))) { XCTAssertEqual($0 as? ZipWriter.Error, .tooLarge) }
        for namn in ["", "/etc/x", "a/../b", ".."] {
            XCTAssertThrowsError(try z.add(name: namn, data: Data())) { XCTAssertEqual($0 as? ZipWriter.Error, .badName) }
        }
        let z2 = try ZipWriter(url: d.appendingPathComponent("b.zip"))
        z2.maxBytes = 100
        XCTAssertThrowsError(try z2.add(name: "x", data: Data(count: 80))) { XCTAssertEqual($0 as? ZipWriter.Error, .tooLarge) }
        try z2.finish()
        XCTAssertThrowsError(try z2.add(name: "y", data: Data())) { XCTAssertEqual($0 as? ZipWriter.Error, .finished) }
        XCTAssertEqual(try ZipCatalog(url: d.appendingPathComponent("b.zip")).entries, [])
        XCTAssertThrowsError(try ZipCatalog(url: d.appendingPathComponent("a.zip")), "utan slutpost är det ingen zip")
    }

    // MARK: Manifestet

    /// Ett påhittat pass: två serier, den andra redigerad (fönster och utsnitt); s01 en
    /// sving med leder och klipp, s02 inte en sving utan leder, s03 osäker i serie 2 med
    /// leder men klicket inte hittat i klippet.
    static func pass() -> PassState {
        var p = SlagTests.pass(klick: [[4.0, 12.0], [3.0, 9.0]], langd: 20)
        p.series[1].edit = SeriesEdit(window: TimeWindow(start: 2.0, end: 25.0),
                                      crop: CropRect(x: 0.25, y: 0.1, width: 0.5, height: 1.2))
        p.series[0].exposure = ExposureRecord(plan: ExposurePlan(duration: 0.0005, iso: 1250, neededISO: 1250,
                                                                 deficitEV: 0, light: .good), lensPosition: 0.62,
                                              distortionCorrection: true)
        p.series[0].pressure = .fair
        p.syncShots()
        XCTAssertEqual(p.shots.map(\.id), ["s01", "s02", "s03", "s04"])
        p.shots[0].verdict = .swing
        p.shots[0].joints = "Leder/s01.json"
        p.shots[0].jointFrames = 3
        p.shots[0].clip = "Klipp/s01.mov"
        p.shots[0].clipStart = 1.5
        p.shots[0].clickInClip = 2.5021
        p.shots[0].orientationSuspect = false
        p.shots[1].verdict = .notSwing
        p.shots[2].verdict = .uncertain
        p.shots[2].verdictByJohannes = true
        p.shots[2].joints = "Leder/s03.json"
        p.shots[2].clip = "Klipp/s03.mov"
        p.shots[2].detectionWrong = true
        p.shots[3].verdict = .swing          // leder saknas: kommer inte med
        p.vision = VisionStats()
        return p
    }

    static let app = PackageManifest.AppInfo(version: "0.1.0", build: "12")
    static let phone = PackageManifest.PhoneInfo(model: "iPhone18,1", ios: "26.1")
    static let skapad = Date(timeIntervalSince1970: 1_792_848_612)
    static let zon = TimeZone(secondsFromGMT: 7200)!

    func json(_ m: PackageManifest) throws -> J {
        try JSONDecoder().decode(J.self, from: PassPackage.encoder().encode(m))
    }

    func testManifestetsNycklarSomIFormatet() throws {
        let p = Self.pass()
        let m = PackageManifest.make(pass: p, app: Self.app, phone: Self.phone, created: Self.skapad, timeZone: Self.zon,
                                     includeClips: true, clipDurations: ["Klipp/s01.mov": 4.0])
        let j = try json(m)
        XCTAssertEqual(j["format"]?.str, "swinglab-paket/1")
        XCTAssertEqual(j["pass"]?.str, "20261024-153012")
        XCTAssertEqual(j["skapad"]?.str, "2026-10-24T15:30:12+02:00")
        XCTAssertEqual(j["vy"]?.str, "fo")
        XCTAssertEqual(j["spelhand"]?.str, "hoger")
        XCTAssertEqual(j["avstand_m"]?.num, 3.43)
        XCTAssertEqual(j["matt"], .null, "matt står med som null")
        XCTAssertEqual(j["telefon"]?["roll"]?.str, "ensam")
        var styr = p
        styr.setup.role = .lead
        let ms = PackageManifest.make(pass: styr, app: Self.app, phone: Self.phone, created: Self.skapad,
                                      timeZone: Self.zon, includeClips: false)
        XCTAssertEqual(ms.phone.role, "styr", "rollen ur passet (S2g)")
        XCTAssertEqual(j["app"]?["bygge"]?.str, "12")
        XCTAssertEqual(j["vision"]?["glest_steg"]?.num, Double(SwingCheck.sparseStride))

        let serier = try XCTUnwrap(j["serier"]?.arr)
        XCTAssertEqual(serier.map { $0["nr"]?.num }, [1, 2])
        XCTAssertEqual(serier[0]["kalla"]?.str, "inspelning")
        XCTAssertEqual(serier[0]["klubba"]?.str, "j7")
        XCTAssertEqual(serier[0]["tryck"]?.str, "fair")
        XCTAssertEqual(serier[0]["orientering"]?.num, 6)
        XCTAssertEqual(serier[0]["orientering_misstankt"]?.bool, false)
        XCTAssertEqual(serier[0]["rutor"]?["antal"]?.num, 10)
        XCTAssertEqual(serier[0]["exponering"]?["behov_iso"]?.num, 1250)
        XCTAssertNil(serier[0]["fonster"], "en serie utan redigering får inga fält")
        XCTAssertNil(serier[0]["utsnitt"])
        // Utplattade och klampade som de läses (activeWindow, activeCrop). METOD MS13
        XCTAssertEqual(serier[1]["fonster"], .o(["fran_s": .n(2.0), "till_s": .n(20.0)]))
        let u = try XCTUnwrap(serier[1]["utsnitt"]?.obj)
        XCTAssertEqual(Set(u.keys), ["x", "y", "b", "h"])
        XCTAssertEqual((u["y"]?.num ?? .nan) + (u["h"]?.num ?? .nan), 1, accuracy: 1e-9, "klampat inom bilden")

        let slag = try XCTUnwrap(j["slag"]?.arr)
        XCTAssertEqual(slag.map { $0["id"]?.str }, ["s01", "s03"], "bara slag med leder och dom")
        XCTAssertEqual(slag[0]["dom"]?.str, "sving")
        XCTAssertEqual(slag[0]["serie"]?.num, 1)
        XCTAssertEqual(slag[0]["klick_s"]?.num, 4.0)
        XCTAssertEqual(slag[0]["traff_s"]?.num ?? .nan, 3.99, accuracy: 1e-9)
        XCTAssertEqual(slag[0]["leder"]?.str, "slag/s01.json")
        XCTAssertEqual(slag[0]["klipp"]?.str, "klipp/s01.mov")
        XCTAssertEqual(slag[0]["klick_i_klipp_s"]?.num, 2.5021)
        XCTAssertEqual(slag[0]["klipp_langd_s"]?.num, 4.0)
        XCTAssertEqual(slag[1]["dom"]?.str, "osaker")
        XCTAssertEqual(slag[1]["andrad_av_johannes"]?.bool, true)
        XCTAssertEqual(slag[1]["detection_wrong"]?.bool, true, "Detection wrong följer med")
        XCTAssertNil(slag[0]["detection_wrong"], "står bara med när det är satt")
        XCTAssertNil(slag[1]["klipp"], "klicket hittades inte i klippet: inget klipp (PC:n kräver klick_i_klipp_s)")

        // Avkodas till samma manifest.
        let igen = try JSONDecoder().decode(PackageManifest.self, from: PassPackage.encoder().encode(m))
        XCTAssertEqual(igen, m)
    }

    func testUtanKlipp() throws {
        let m = PackageManifest.make(pass: Self.pass(), app: Self.app, phone: Self.phone, created: Self.skapad,
                                     timeZone: Self.zon, includeClips: false)
        XCTAssertEqual(m.shots.map(\.id), ["s01", "s03"])
        XCTAssertTrue(m.shots.allSatisfy { $0.clip == nil && $0.clickInClip == nil && $0.clipDuration == nil })
    }

    // MARK: Paketet

    func testPaketetUrPassetsMapp() throws {
        let d = try tmp()
        let mapp = d.appendingPathComponent("Pass/20261024-153012")
        try FileManager.default.createDirectory(at: mapp.appendingPathComponent("Leder"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: mapp.appendingPathComponent("Klipp"), withIntermediateDirectories: true)
        var p = Self.pass()
        p.lightCheck = LightCheck(exposure: ExposurePlan(duration: 0.0005, iso: 1000, neededISO: 1000, deficitEV: 0, light: .good),
                                  timing: FrameTiming.analyze((0..<10).map { Double($0) / 240 }), flicker100: 0.02,
                                  flicker120: 0.01, meanLuma: 0.4, verdict: .good)
        let leder = JointSeries(width: 1080, height: 1920, frames: [
            PoseFrame(t: -0.01, pts: 3.99, joints: Array(repeating: PoseJoint(x: 540, y: 960, c: 0.9), count: 13), confidence: 0.9),
        ])
        let lederData = try JSONEncoder().encode(leder)
        try lederData.write(to: mapp.appendingPathComponent("Leder/s01.json"))
        try Data("klippet".utf8).write(to: mapp.appendingPathComponent("Klipp/s01.mov"))
        // s03:s ledfil saknas på disken: slaget kommer inte med.
        let enhet = DeviceInfo(model: "iPhone18,1", ios: "26.1", formats: [], chosenIndex: nil)
        let ut = d.appendingPathComponent("Export/swinglab-20261024-153012-fo.zip")
        let tmp = d.appendingPathComponent("Caches/Export")
        XCTAssertEqual(PassPackage.fileName(p), "swinglab-20261024-153012-fo.zip")
        let s = try PassPackage.write(pass: p, folder: mapp, to: ut, scratch: tmp, app: Self.app, phone: Self.phone, device: enhet,
                                      created: Self.skapad, timeZone: Self.zon, includeClips: true)
        XCTAssertEqual(s.shots, 1)
        XCTAssertEqual(s.clips, 1)
        let k = try ZipCatalog(url: ut)
        XCTAssertEqual(k.names, ["manifest.json", "enhet.json", "ljusprov.json", "slag/s01.json", "klipp/s01.mov"])
        XCTAssertEqual(try k.data(named: "slag/s01.json"), lederData, "lederna byte för byte som i passet")
        XCTAssertEqual(try k.data(named: "klipp/s01.mov"), Data("klippet".utf8))
        let m = try JSONDecoder().decode(PackageManifest.self, from: k.data(named: "manifest.json"))
        XCTAssertEqual(m.shots.map(\.id), ["s01"])
        let e = try JSONDecoder().decode(J.self, from: k.data(named: "enhet.json"))
        XCTAssertEqual(e["modell"]?.str, "iPhone18,1")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: tmp.path), [], "ingen halv fil kvar")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: ut.deletingLastPathComponent().path),
                       [ut.lastPathComponent], "bara paketet i Export, ingen .part där")

        // Utan klipp och med parningen (S2g): samma namn, bytt mot det förra, par.json med.
        let par = Data("{\"serier\":[]}".utf8)
        try par.write(to: mapp.appendingPathComponent("par.json"))
        try PassPackage.write(pass: p, folder: mapp, to: ut, scratch: tmp, app: Self.app, phone: Self.phone, device: enhet,
                              created: Self.skapad, timeZone: Self.zon, includeClips: false)
        let utan = try ZipCatalog(url: ut)
        XCTAssertEqual(utan.names, ["manifest.json", "enhet.json", "ljusprov.json", "par.json", "slag/s01.json"])
        XCTAssertEqual(try utan.data(named: "par.json"), par)

        // En .part som en avbruten export lämnat tas bort vid start; inget annat rörs.
        try Data([1]).write(to: tmp.appendingPathComponent("gammal.zip.part"))
        try Data([2]).write(to: tmp.appendingPathComponent("annat.txt"))
        XCTAssertEqual(PassPackage.removeStaleParts(in: tmp), 1)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: tmp.path), ["annat.txt"])

        // Utan slag med leder: inget paket, och ingen fil kvar.
        var tom = p
        for i in tom.shots.indices { tom.shots[i].joints = nil }
        let ut2 = d.appendingPathComponent("Export/tom.zip")
        XCTAssertThrowsError(try PassPackage.write(pass: tom, folder: mapp, to: ut2, scratch: tmp, app: Self.app, phone: Self.phone,
                                                   device: nil, created: Self.skapad, includeClips: true)) {
            XCTAssertEqual($0 as? PassPackage.Error, .noShots)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: ut2.path))
    }

    // MARK: Vägen tillbaka

    func testAttJobbaPaTasEmotOchFarPassetsNamn() throws {
        let r = try FocusInbox.accept(Data(Demo.attJobbaPaJSON.utf8))
        XCTAssertEqual(r.fileName, "att_jobba_pa-20270109-180000.json")
        XCTAssertEqual(r.focus.saker.count, 2)
    }

    func testFelFilTasInteEmot() {
        let fel = Demo.attJobbaPaJSON.replacingOccurrences(of: "swinglab-att-jobba-pa/1", with: "annat/1")
        XCTAssertThrowsError(try FocusInbox.accept(Data(fel.utf8))) { e in
            XCTAssertTrue("\(e)".hasPrefix("att_jobba_pa: format"), "\(e)")
        }
        let utUrMappen = Demo.attJobbaPaJSON.replacingOccurrences(of: "\"20270109-180000\"", with: "\"../../x\"")
        XCTAssertThrowsError(try FocusInbox.accept(Data(utUrMappen.utf8))) { e in
            XCTAssertEqual("\(e)", "att_jobba_pa: pass: invalid")
        }
        XCTAssertThrowsError(try FocusInbox.accept(Data("inte json".utf8)))
        XCTAssertThrowsError(try FocusInbox.accept(Data(count: FocusInbox.maxBytes + 1)))
    }

    func testDenSenasteVinner() {
        XCTAssertEqual(FocusInbox.latest(["att_jobba_pa-20261103-180000.json", "att_jobba_pa-20270109-180000.json",
                                          "annat.json", "att_jobba_pa-x.json"]),
                       "att_jobba_pa-20270109-180000.json")
        XCTAssertNil(FocusInbox.latest([]))
        XCTAssertNil(FocusInbox.fileName(pass: "2026110-1800000"))
        XCTAssertNil(FocusInbox.fileName(pass: "20261103/180000"))
    }
}

/// JSON som värden, för att pröva nycklarna utan JSONSerialization (som bryggar tal
/// olika på Linux och Apple).
enum J: Decodable, Equatable {
    case null, b(Bool), n(Double), s(String), a([J]), o([String: J])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let v = try? c.decode(Bool.self) {
            self = .b(v)
        } else if let v = try? c.decode(Double.self) {
            self = .n(v)
        } else if let v = try? c.decode(String.self) {
            self = .s(v)
        } else if let v = try? c.decode([J].self) {
            self = .a(v)
        } else {
            self = .o(try c.decode([String: J].self))
        }
    }

    subscript(_ k: String) -> J? {
        if case .o(let d) = self { return d[k] }
        return nil
    }

    var str: String? { if case .s(let v) = self { return v }; return nil }
    var num: Double? { if case .n(let v) = self { return v }; return nil }
    var bool: Bool? { if case .b(let v) = self { return v }; return nil }
    var arr: [J]? { if case .a(let v) = self { return v }; return nil }
    var obj: [String: J]? { if case .o(let v) = self { return v }; return nil }
}
