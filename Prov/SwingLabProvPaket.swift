// SIMULATORPROVET FÖR PAKETET OCH VÄGEN TILLBAKA (S2_SPEC §10.2 steg 8, §12 S2f).
//
// Vad som bevisas här, på provets PÅHITTADE film och PÅHITTADE leder (CLAUDE.md:
// Dataregeln; repot är publikt):
//   steg 8  appens Export (App/Export.swift) packar ett pass ur filmen: två slag med
//           leder ur SwingDemo:s påhittade sving (samma figur som tools/pc/generera.py),
//           riktiga passthrough-klipp, ett redigerat fönster och utsnitt. Zippen läses
//           tillbaka med katalogläsaren (namn, storlek, CRC), med och utan klipp.
//   PC:n    paketen och Swifts egna mått på samma leder (facit.json) läggs i
//           /tmp/swinglab_prov/paket/, där kompilera.yml låter PC:ns tools/pc/paket.py och
//           session.py läsa dem (tools/tests/test_appens_paket.py): kontraktet mellan
//           telefon och PC prövas med de byte appen skrev, inte med en kopia av formatet.
//   tillbaka `att_jobba_pa.json` kontrolleras och sparas (Store.importFocus), en felaktig
//           fil sparas inte, och den senaste läses när appen startar om (BESLUT B28).

import XCTest
import AVFoundation
import Swing
import Capture
import SwingDemo
@testable import SwingLab

/// Appens fotavtryck i minnet, byte (det iOS räknar mot gränsen), eller 0.
func fotavtryck() -> UInt64 {
    var info = task_vm_info_data_t()
    var n = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
    let kr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(n)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &n)
        }
    }
    return kr == KERN_SUCCESS ? info.phys_footprint : 0
}

/// Fotavtryckets topp, avläst var 2:a ms i en egen tråd medan paketet skrivs.
final class MinnesToppen: @unchecked Sendable {
    private let lock = NSLock()
    private var topp: UInt64 = 0
    private var igang = true

    func start() {
        Thread.detachNewThread { [self] in
            while lock.withLock({ igang }) {
                let f = fotavtryck()
                lock.withLock { topp = max(topp, f) }
                usleep(2000)
            }
        }
    }

    func stopp() -> UInt64 {
        lock.withLock {
            igang = false
            return topp
        }
    }
}

@MainActor
final class SwingLabProvPaket: XCTestCase {
    static let ut = "/tmp/swinglab_prov/paket"
    /// Spelarens längd i den påhittade svingen, m.
    static let langd = 1.80

    func tmp(_ namn: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: "swinglab-prov", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: namn)
    }

    /// SwingDemo:s FO-sving som Visions leder i seriens upprätta bild: skalad från
    /// 1080 × 1920, t relativt klicket (träffen är klicket − avstånd/343, METOD MS6).
    static func leder(_ s: Sving, klick: Double, ljudet: Double, width: Int, height: Int) -> JointSeries {
        let sx = Double(width) / 1080, sy = Double(height) / 1920
        let frames = s.t.indices.map { i -> PoseFrame in
            let t = s.t[i] - s.tKlick - ljudet
            let joints = (0..<13).map { j -> PoseJoint? in
                PoseJoint(x: s.leder[j][i].x * sx, y: s.leder[j][i].y * sy, c: 0.9)
            }
            return PoseFrame(t: t, pts: klick + t, joints: joints, confidence: 0.9)
        }
        return JointSeries(width: width, height: height, frames: frames)
    }

    /// Slaget som en sving i filformatet, som PC:ns `paket.till_sving` gör det: t_klick =
    /// träffen − klicket, en saknad led med konfidensen 0. Swifts mått på den är facit för
    /// PC:ns mått på samma byte (BESLUT B12).
    static func sving(_ j: JointSeries, shot: PackageManifest.Shot, vy: Vy, hand: Hand) throws -> Sving {
        let rutor: [[String: Any]] = j.frames.map { f -> [String: Any] in
            ["t": f.t, "leder": f.joints.map { l -> [Double] in l.map { [$0.x, $0.y, $0.c] } ?? [0, 0, 0] }]
        }
        let d: [String: Any] = ["format": 1, "vy": vy.rawValue, "hand": hand.rawValue, "spelarens_langd_m": langd,
                                "t_klick": shot.impact - shot.click, "rutor": rutor]
        return try Sving.las(JSONSerialization.data(withJSONObject: d))
    }

    /// Steg 8: ett påhittat pass packas av appens Export, med och utan klipp, och läses
    /// tillbaka med katalogläsaren. Paketen och facit läggs där kompilera.yml låter PC:n
    /// läsa dem. BESLUT B27, METOD MS12, MS13
    func testSteg8PaketetTillPC() async throws {
        let rot = try tmp("paket-\(UUID().uuidString)")
        let store = Store(root: rot, exportFolder: rot.appending(path: "Export"))
        var pass = store.newPass(setup: PassSetup(view: .fo, club: "j7", distance: 3, hand: .hoger),
                                 at: Date(timeIntervalSince1970: 1_792_848_612))
        let fil = PassState.videoPath(nr: 1)
        try await SyntheticMovie.write(to: store.url(fil, in: pass.id), sound: .lpcm)
        var serie = try await SeriesMaker.make(url: store.url(fil, in: pass.id), nr: 1, file: fil, source: .recording,
                                               club: "j7", start: pass.created, startHost: nil, microphone: nil)
        serie.edit = SeriesEdit(window: TimeWindow(start: 0.3, end: 3.0),
                                crop: CropRect(x: 0.1, y: 0.05, width: 0.8, height: 0.9))
        pass.series.append(serie)
        pass.syncShots()
        XCTAssertEqual(pass.shots.map(\.id), ["s01", "s02"])

        // Lederna (påhittade, sway i toppen −6 och −4 cm) och klippen (riktig passthrough).
        let sway: [String: Double] = ["s01": -6, "s02": -4]
        for i in pass.shots.indices {
            let s = pass.shots[i]
            pass.shots[i].verdict = i == 0 ? .swing : .uncertain
            let sv = DemoSving.fo(sway: (sway[s.id]!, sway[s.id]! + 12, 14), langdM: Self.langd)
            let j = Self.leder(sv, klick: s.click.time, ljudet: pass.setup.soundDelay, width: serie.uprightWidth,
                               height: serie.uprightHeight)
            pass.shots[i].joints = try store.writeJoints(j, shot: s.id, in: pass.id)
            pass.shots[i].jointFrames = j.frames.count
            pass.shots[i].orientationSuspect = j.orientationSuspect
            let w = try XCTUnwrap(ShotPlan.window(ShotPlan.clipWindow, click: s.click.time, series: serie))
            let rel = ShotRecord.clipPath(s.id)
            try await Clips.export(store.url(fil, in: pass.id), range: w, to: store.url(rel, in: pass.id))
            let iKlippet = try await MediaReader.clicks(store.url(rel, in: pass.id))
            let m = ClipCheck.measure(iKlippet, expected: s.click.time - w.lowerBound)
            pass.shots[i].clip = rel
            pass.shots[i].clipStart = w.lowerBound
            pass.shots[i].clickInClip = m.time
            pass.shots[i].clipFlagged = m.flagged
        }
        pass.vision = VisionStats()
        // Den styrande telefonen med en följare (S2g): rollen i manifestet och par.json, som
        // S2g:s egen kod skriver den (Store.savePair), följer med i paketet.
        pass.setup.role = .lead
        try store.write(pass)
        let klicken = serie.clicks
        let ledare = LinkSeries(series: 1, localSeries: 1, passID: pass.id, startHost: 100, frameRate: 240,
                                clicks: klicken, view: .fo, distance: 3)
        let foljare = LinkSeries(series: 1, localSeries: 1, passID: "20261024-133015", startHost: 99.95, frameRate: 240,
                                 clicks: klicken.map { Click(time: $0.time + 0.05, strength: $0.strength) },
                                 view: .dtl, distance: 3)
        let par = PairEntry.make(lead: ledare, follower: foljare, followerModel: "iPhone14,5", before: [], after: [])
        store.savePair(par, passID: pass.id, model: "prov", view: .fo)
        let parPaDisken = try Data(contentsOf: store.url("par.json", in: pass.id))

        // Paketen läggs där PC:n i kompilera.yml läser dem; varje export skriver samma namn
        // i Export/, så de kopieras undan direkt.
        try? FileManager.default.removeItem(atPath: Self.ut)
        func tillPC(_ url: URL, _ mapp: String) throws -> URL {
            let dir = URL(fileURLWithPath: Self.ut).appending(path: mapp, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let kopia = dir.appending(path: url.lastPathComponent)
            try FileManager.default.copyItem(at: url, to: kopia)
            return kopia
        }

        // Med klipp: appens Export, som telefonen.
        let medExport = try await Export.package(passID: pass.id, store: store, includeClips: true)
        let medUrl = try tillPC(medExport, "med-klipp")
        XCTAssertEqual(medUrl.lastPathComponent, "swinglab-\(pass.id)-fo.zip")
        XCTAssertEqual(store.load(pass.id)?.status, .exported)
        let med = try ZipCatalog(url: medUrl)
        let medByte = try Data(contentsOf: medUrl).count
        print("PROV: paket med klipp \(med.names), \(medByte) byte")
        XCTAssertEqual(med.names, ["manifest.json", "enhet.json", "par.json", "slag/s01.json", "slag/s02.json",
                                   "klipp/s01.mov", "klipp/s02.mov"])
        XCTAssertEqual(try med.data(named: "par.json"), parPaDisken, "par.json som S2g skrev den")
        XCTAssertEqual(try PassCoding.decoder().decode(PairFile.self, from: med.data(named: "par.json")).entries, [par])
        for e in med.entries { _ = try med.data(e) }        // varje fil: huvudet, storleken och CRC
        let manifest = try JSONDecoder().decode(PackageManifest.self, from: med.data(named: "manifest.json"))
        XCTAssertEqual(manifest.format, "swinglab-paket/1")
        XCTAssertEqual(manifest.pass, pass.id)
        XCTAssertEqual(manifest.series.first?.window, TimeWindow(start: 0.3, end: 3.0))
        XCTAssertEqual(manifest.series.first?.crop, CropRect(x: 0.1, y: 0.05, width: 0.8, height: 0.9))
        XCTAssertEqual(manifest.shots.map(\.verdict), ["sving", "osaker"])
        XCTAssertFalse(manifest.phone.model.isEmpty)
        XCTAssertEqual(manifest.phone.role, "styr", "rollen ur passet (S2g)")
        for s in manifest.shots {
            XCTAssertEqual(try med.data(named: s.joints), try Data(contentsOf: store.url(ShotRecord.jointsPath(s.id), in: pass.id)),
                           "lederna byte för byte")
            let klipp = try XCTUnwrap(s.clip)
            XCTAssertEqual(try med.data(named: klipp), try Data(contentsOf: store.url(ShotRecord.clipPath(s.id), in: pass.id)))
            let langd = try XCTUnwrap(s.clipDuration, "klippets längd, så att PC:n räknar rutorna i [0; längd)")
            let k = try XCTUnwrap(s.clickInClip)
            XCTAssertTrue(k >= 0 && k < langd, "klicket i klippet ligger i [0; längd)")
            print("PROV: \(s.id) klick \(String(format: "%.4f", s.click)) s, i klippet \(String(format: "%.4f", k)) s, "
                  + "klippet \(String(format: "%.4f", langd)) s")
        }

        // Utan klipp: samma namn, inga klipp.
        let utanExport = try await Export.package(passID: pass.id, store: store, includeClips: false)
        let utanUrl = try tillPC(utanExport, "utan-klipp")
        let utan = try ZipCatalog(url: utanUrl)
        XCTAssertEqual(utan.names, ["manifest.json", "enhet.json", "par.json", "slag/s01.json", "slag/s02.json"])
        let utanM = try JSONDecoder().decode(PackageManifest.self, from: utan.data(named: "manifest.json"))
        XCTAssertTrue(utanM.shots.allSatisfy { $0.clip == nil })

        // Swifts mått på samma leder som facit för PC:ns (BESLUT B12).
        var facit: [String: Any] = [:]
        for s in manifest.shots {
            let j = try JSONDecoder().decode(JointSeries.self, from: med.data(named: s.joints))
            let r = try Matt.mat(try Self.sving(j, shot: s, vy: manifest.view, hand: manifest.hand))
            facit[s.id] = ["matt": r.matt, "sway_satt": sway[s.id]!] as [String: Any]
            print("PROV: \(s.id) Swift backen_sway_topp \(String(format: "%.3f", r.matt["backen_sway_topp"] ?? .nan)) cm "
                  + "(satt \(sway[s.id]!)), \(r.matt.count) mått")
            XCTAssertEqual(r.matt["backen_sway_topp"] ?? .nan, sway[s.id]!, accuracy: 0.5)
        }
        let f: [String: Any] = ["pass": pass.id, "spelarens_langd_m": Self.langd, "slag": facit]
        try JSONSerialization.data(withJSONObject: f, options: [.sortedKeys, .prettyPrinted])
            .write(to: URL(fileURLWithPath: Self.ut + "/facit.json"))
    }

    /// Minnet (S2_SPEC §11.4 R13): ett påhittat klipp på 400 MB packas av SwingLabKit som
    /// appen gör det, och fotavtryckets topp under skrivningen skrivs ut. Bitarna om 1 MB
    /// läses i var sin autoreleasepool, så toppen ska ligga några MB över starten, inte
    /// hundratals. BESLUT B27
    func testMinnetMedEttStortKlipp() async throws {
        let rot = try tmp("minnet-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: rot) }
        let mapp = rot.appending(path: "Pass/20261024-153012", directoryHint: .isDirectory)
        for d in ["Leder", "Klipp"] {
            try FileManager.default.createDirectory(at: mapp.appending(path: d), withIntermediateDirectories: true)
        }
        var p = PassState(id: "20261024-153012", created: Date(timeIntervalSince1970: 1_792_848_612),
                          setup: PassSetup(view: .fo, club: "j7", distance: 3, hand: .hoger))
        p.series = [SeriesRecord(nr: 1, source: .recording, club: "j7", file: PassState.videoPath(nr: 1),
                                 start: p.created, startHost: nil, duration: 60, bytes: 1,
                                 timing: FrameTiming.analyze([0, 1.0 / 240]), clicks: [Click(time: 10, strength: 50)],
                                 orientation: 6, uprightWidth: 1080, uprightHeight: 1920)]
        p.syncShots()
        p.shots[0].verdict = .swing
        p.shots[0].joints = ShotRecord.jointsPath("s01")
        p.shots[0].jointFrames = 1
        p.shots[0].clip = ShotRecord.clipPath("s01")
        p.shots[0].clickInClip = 2.5
        let led = JointSeries(width: 1080, height: 1920, frames: [
            PoseFrame(t: 0, pts: 10, joints: Array(repeating: PoseJoint(x: 540, y: 960, c: 0.9), count: 13), confidence: 0.9),
        ])
        try JSONEncoder().encode(led).write(to: mapp.appending(path: "Leder/s01.json"))

        // 400 MB påhittade byte, skrivna i bitar om 1 MB.
        let mb = 400
        let klipp = mapp.appending(path: "Klipp/s01.mov")
        FileManager.default.createFile(atPath: klipp.path, contents: nil)
        let h = try FileHandle(forWritingTo: klipp)
        for i in 0..<mb {
            try autoreleasepool {
                try h.write(contentsOf: Data(repeating: UInt8(truncatingIfNeeded: i), count: 1 << 20))
            }
        }
        try h.close()

        let ut = rot.appending(path: "Export/swinglab-20261024-153012-fo.zip")
        let scratch = rot.appending(path: "Caches", directoryHint: .isDirectory)
        let fore = fotavtryck()
        let toppen = MinnesToppen()
        toppen.start()
        let pp = p
        let s = try await Task.detached(priority: .userInitiated) {
            try PassPackage.write(pass: pp, folder: mapp, to: ut, scratch: scratch,
                                  app: PackageManifest.AppInfo(version: "0", build: "0"),
                                  phone: PackageManifest.PhoneInfo(model: "prov", ios: "0"), device: nil,
                                  created: pp.created, includeClips: true)
        }.value
        let topp = toppen.stopp()
        let mega = { (b: UInt64) in String(format: "%.1f", Double(b) / 1_048_576) }
        print("PROV: minnet: klippet \(mb) MB, paketet \(mega(s.bytes)) MB, fotavtrycket före \(mega(fore)) MB, "
              + "topp \(mega(topp)) MB (+\(mega(topp > fore ? topp - fore : 0)) MB)")
        XCTAssertEqual(s.clips, 1)
        XCTAssertEqual(try ZipCatalog(url: ut).entry("klipp/s01.mov")?.size, UInt32(mb << 20))
        XCTAssertGreaterThan(fore, 0, "fotavtrycket gick att läsa")
        XCTAssertLessThan(topp > fore ? topp - fore : 0, 64 << 20, "paketet ska inte ligga i minnet")
    }

    /// Vägen tillbaka (S2_SPEC §8.5): en giltig fil sparas och blir den senaste, en felaktig
    /// sparas inte och felet nämner fältet, och en ny Store läser den senaste. BESLUT B28
    func testAttJobbaPaTillbaka() throws {
        let rot = try tmp("tillbaka-\(UUID().uuidString)")
        let store = Store(root: rot, exportFolder: rot.appending(path: "Export"))
        XCTAssertNil(store.focus)
        let fil = try tmp("att_jobba_pa-\(UUID().uuidString).json")
        try Data(Demo.attJobbaPaJSON.utf8).write(to: fil)
        let a = try store.importFocus(from: fil)
        XCTAssertEqual(a.pass, "20270109-180000")
        XCTAssertEqual(store.focus?.saker.count, 2)
        let sparad = store.focusFolder.appending(path: "att_jobba_pa-20270109-180000.json")
        XCTAssertEqual(try Data(contentsOf: sparad), Data(Demo.attJobbaPaJSON.utf8), "sparad som den kom")

        let fel = Demo.attJobbaPaJSON.replacingOccurrences(of: "\"20270109-180000\"", with: "\"20270110-180000\"")
            .replacingOccurrences(of: "swinglab-att-jobba-pa/1", with: "annat/1")
        XCTAssertThrowsError(try store.importFocus(Data(fel.utf8))) { e in
            print("PROV: fel fil: \(e)")
            XCTAssertTrue("\(e)".hasPrefix("att_jobba_pa: format"))
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: store.focusFolder.path),
                       ["att_jobba_pa-20270109-180000.json"], "den felaktiga sparades inte")

        let senare = Demo.attJobbaPaJSON.replacingOccurrences(of: "\"20270109-180000\"", with: "\"20270116-180000\"")
        try store.importFocus(Data(senare.utf8))
        XCTAssertEqual(Store(root: rot, exportFolder: rot.appending(path: "Export")).focus?.pass, "20270116-180000",
                       "den senaste läses vid start")
    }
}
