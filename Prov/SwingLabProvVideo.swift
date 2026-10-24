// VIDEON FRÅN BÅDA TELEFONERNA PÅ DEN STYRANDE (S6g, BESLUT B80–B83, METOD MS30, MS31).
//
// Två telefoner i samma process över loopback (som SwingLabProvTreDLink), var och en med sin egen
// Store och en PÅHITTAD film (SyntheticMovie: grå rutor, en vit ruta och ett klick vid varje slag;
// inga riktiga svingar, CLAUDE.md: Dataregeln). Den styrande (DTL) har fyra slag; följaren (FO)
// hörde bara tre av dem (det andra klicket saknas). Vad som bevisas:
//   klippen    den styrande begär ett klipp per sving ur par.json, också för klicket som följaren
//              missade; följaren skär dem passthrough och strömmar dem; kopplingen faller mitt i
//              och strömmen fortsätter där den slutade (bitarna räknas); klicket mäts i varje klipp;
//   hela       "Get full video": följarens hela serie kommer byte för byte;
//   originalen följaren behåller sin inspelning tills den styrande sagt att allt kommit fram;
//   synken     rutan vid den styrandes klick och den andra vyns ruta på samma träff är båda vita;
//   paketen    Send to PC på den styrande ger två paket (DTL och FO) i paketets format, som PC:n
//              läser i kompilera.yml (tools/tests/test_appens_paket.py, mappen paket-parat);
//   vyerna     raden "Paired", passet i DTL, FO och 3D, granskningen i båda vyerna och varningen för
//              samma vy.
// Raderna "PROV: VIDEO …" hamnar i kompilera.txt.

import XCTest
import Network
import SwiftUI
import UIKit
import AVFoundation
import Swing
import Capture
import SwingDemo
import TreD
@testable import SwingLab

extension SwingLabProvVyer {
    /// Paketen från den styrande för PC:ns prov (bredvid SwingLabProvPaket:s, som tömmer sin mapp).
    static let parat = "/tmp/swinglab_prov/paket-parat"

    func testVideoMellanTvaTelefoner() async throws {
        let dag = Date(timeIntervalSince1970: 1_792_848_612)
        // Den styrandes klick, och följarens: 0,25 s senare i dess fil, utan det andra.
        let styrKlick = [2.0, 4.5, 7.0, 9.5], foljKlick = [2.25, 7.25, 9.75]

        /// En telefon: Store, passet med filmen, slagen med leder och mått, och klippen (bara den
        /// styrande; följarens klipp skärs när den styrande begär dem).
        func telefon(_ vy: Vy, _ roll: LinkRole, _ klick: [Double]) async throws -> (Store, PassState) {
            let rot = FileManager.default.temporaryDirectory
                .appending(path: "swinglab-video-\(vy.rawValue)-\(UUID().uuidString)", directoryHint: .isDirectory)
            let store = Store(root: rot, exportFolder: rot.appending(path: "Export"),
                              scratchFolder: rot.appending(path: "Scratch"))
            store.setHeight(1.80)
            var p = store.newPass(setup: PassSetup(view: vy, club: "j7", distance: 3, hand: .hoger, role: roll), at: dag)
            let fil = PassState.videoPath(nr: 1)
            try await SyntheticMovie.write(to: store.url(fil, in: p.id), sound: .lpcm, dropEveryThird: false,
                                           seconds: 12, flashes: klick)
            let serie = try await SeriesMaker.make(url: store.url(fil, in: p.id), nr: 1, file: fil, source: .recording,
                                                   club: "j7", start: p.created, startHost: nil, microphone: nil)
            p.series = [serie]
            p.syncShots()
            for i in p.shots.indices {
                let s = p.shots[i]
                p.shots[i].verdict = .swing
                let sv = vy == .fo ? DemoSving.fo(sway: (-3 - Double(i), 2, 4)) : DemoSving.dtl(thrust: (-2 - Double(i), 3, 8))
                let j = DemoPass.serie(sv, klick: s.click.time)
                p.shots[i].joints = try store.writeJoints(j, shot: s.id, in: p.id)
                p.shots[i].jointFrames = j.frames.count
                if roll == .lead {
                    let w = try XCTUnwrap(ShotPlan.window(ShotPlan.clipWindow, click: s.click.time, series: serie))
                    let rel = ShotRecord.clipPath(s.id)
                    try await Clips.export(store.url(fil, in: p.id), range: w, to: store.url(rel, in: p.id))
                    let m = ClipCheck.measure(try await MediaReader.clicks(store.url(rel, in: p.id)),
                                              expected: s.click.time - w.lowerBound)
                    p.shots[i].clip = rel
                    p.shots[i].clipStart = w.lowerBound
                    p.shots[i].clickInClip = m.time
                    p.shots[i].clipFlagged = m.flagged
                }
            }
            p.status = .analyzed
            try store.write(p)
            return (store, store.measured(p))
        }
        let (styrStore, styrPass) = try await telefon(.dtl, .lead, styrKlick)
        let (foljStore, foljPass) = try await telefon(.fo, .follow, foljKlick)
        XCTAssertEqual(styrPass.id, foljPass.id, "samma pass-id (S2g)")
        XCTAssertEqual(styrPass.shots.count, 4)
        XCTAssertEqual(foljPass.shots.count, 3, "följaren hörde tre klick")
        let id = styrPass.id

        // Parningen som S2g skriver den (följarens serie 1, förskjutningen ur klicken).
        let par = PairEntry.make(lead: LinkSeries(record: styrPass.series[0], series: 1, passID: id, setup: styrPass.setup),
                                 follower: LinkSeries(record: foljPass.series[0], series: 1, passID: id,
                                                      setup: foljPass.setup),
                                 followerModel: "prov-fo", before: [], after: [])
        XCTAssertEqual(par.offset, 0.25, accuracy: 0.003)
        XCTAssertEqual(par.pairCount, 3)
        styrStore.savePair(par, passID: id, model: "prov-dtl", view: .dtl)
        // Följarens slag (S6c-2:s bunt) hos den styrande: den andra vyns mått och paket.
        let (_, bunt) = try TreDKoppling.egenBunt(foljPass, folder: foljStore.passFolder(id), app: Export.appInfo(),
                                                  phone: Export.phoneInfo(), device: Export.deviceInfo(foljPass))
        XCTAssertTrue(styrStore.saveOtherPhone(bunt, passID: id))

        // Kopplingen över loopback, och klippen på den.
        let styr = PhoneLink(role: .lead, view: .dtl, mode: .pass, bonjour: false, device: "prov-styr")
        styr.forPass(id)
        styr.start()
        defer { styr.stop() }
        let portNu = await vantaPa(10) { styr.port }
        let port = try XCTUnwrap(portNu, "lyssnaren fick ingen port")
        let folj = PhoneLink(role: .follow, view: .fo, mode: .pass, partner: "prov-styr",
                             endpoint: .hostPort(host: "127.0.0.1", port: try XCTUnwrap(NWEndpoint.Port(rawValue: port))),
                             bonjour: false, device: "prov-folj")
        let styrKlipp = KlippKoppling(passID: id, store: styrStore)
        let foljKlipp = KlippKoppling(passID: id, store: foljStore)
        styrKlipp.start(link: styr)
        foljKlipp.start(link: folj)
        XCTAssertTrue(foljStore.originalenBehovs(foljPass), "följaren behåller inspelningen")
        let start = Date()
        folj.start()
        defer { folj.stop() }

        // 1. Klippen, med ett avbrott mitt i (flygplansläge 1,5 s på följaren).
        let ok1 = await vanta(20) { styrKlipp.mottagnaBitar >= 3 }
        XCTAssertTrue(ok1, "inga bitar kom")
        let fore = styrKlipp.mottagnaBitar
        folj.suspend(1.5)
        let ok2 = await vanta(90) { (styrKlipp.video?.klipp.count ?? 0) == 4 }
        XCTAssertTrue(ok2, "klippen kom inte fram efter avbrottet")
        let tid = Date().timeIntervalSince(start)
        let v = try XCTUnwrap(styrStore.annanVideo(id))
        XCTAssertEqual(v.klipp.keys.sorted(), ["s01", "s02", "s03", "s04"], "också klippet för klicket följaren missade")
        let byte = v.klipp.values.map(\.bytes).reduce(0, +)
        let bitar = v.klipp.values.map { Overforing.antal($0.bytes) }.reduce(0, +)
        print(String(format: "PROV: VIDEO 4 klipp %ld byte (%ld per klipp, %.1f s långa) i %ld bitar, %.2f s med ett avbrott om 1,5 s efter %ld bitar; mottagna bitar %ld (%ld igen)",
                     byte, byte / 4, v.klipp["s01"]?.langd ?? .nan, bitar, tid, fore, styrKlipp.mottagnaBitar,
                     styrKlipp.mottagnaBitar - bitar))
        XCTAssertLessThanOrEqual(styrKlipp.mottagnaBitar, bitar + 4 * KlippSandare.fonster,
                                 "strömmen fortsatte där den slutade, inte från början")
        for (n, k) in v.klipp.sorted(by: { $0.key < $1.key }) {
            let url = styrStore.url(k.fil, in: id)
            XCTAssertEqual(try Klippfil.summa(url), k.id, n)
            // 4 s före och 2,5 s efter träffen, inom filen (12 s): det första och sista är kortare.
            let langd = try XCTUnwrap(k.langd)
            XCTAssertTrue(langd > 4 && langd < 6.7, "\(n): klippets längd")
            print("PROV: VIDEO \(n) serie \(k.serie) från \(String(format: "%.3f", k.fran ?? .nan)) s, väntat klick \(String(format: "%.4f", k.klick ?? .nan)) s, i klippet \(k.klickIKlipp.map { String(format: "%.4f", $0) } ?? "inget")")
        }
        XCTAssertNil(v.klipp["s02"]?.klickIKlipp, "följaren hörde inte det andra klicket")
        XCTAssertEqual(v.utanKlick, ["s02"], "slaget märks")
        for n in ["s01", "s03", "s04"] {
            let k = try XCTUnwrap(v.klipp[n])
            let c = try XCTUnwrap(k.klickIKlipp, "\(n): klicket i klippet")
            // Nära det väntade (klippets början kan ligga före den begärda, MS12); synken tar det mätta.
            XCTAssertEqual(c, try XCTUnwrap(k.klick) - (k.start ?? k.fran ?? 0), accuracy: KlippBegaran.klickTolerans, n)
            print("PROV: VIDEO \(n) början begärd \(String(format: "%.4f", k.fran ?? .nan)) s, läst ur klippet \(String(format: "%.4f", k.start ?? .nan)) s")
        }
        let ok3 = await vanta(10) { foljStore.begaran(id)?.alltFramme == true }
        XCTAssertTrue(ok3, "den styrande kvitterade inte allt")
        let ok4 = await vanta(5) { styrKlipp.rad == nil && foljKlipp.rad == nil }
        XCTAssertTrue(ok4)

        // 2. "Get full video": följarens hela serie, byte för byte.
        let t2 = Date()
        styrKlipp.hamtaHela()
        let ok5 = await vanta(60) { styrKlipp.video?.klipp["video-01"] != nil }
        XCTAssertTrue(ok5, "hela videon kom inte")
        let hel = try Data(contentsOf: styrStore.url(AnnanVideo.fil(vy: .fo, namn: "video-01"), in: id))
        XCTAssertEqual(hel, try Data(contentsOf: foljStore.url(foljPass.series[0].file, in: id)))
        print(String(format: "PROV: VIDEO hela serien %ld byte i %ld bitar, %.2f s på loopback", hel.count,
                     Overforing.antal(hel.count), Date().timeIntervalSince(t2)))
        let ok6 = await vanta(10) { foljStore.begaran(id)?.alltFramme == true }
        XCTAssertTrue(ok6)
        XCTAssertFalse(foljStore.originalenBehovs(try XCTUnwrap(foljStore.load(id))), "allt framme: originalen får gå")
        XCTAssertFalse(FileManager.default.fileExists(atPath: foljStore.url(KlippBegaran.utskickMapp, in: id).path),
                       "de skurna klippen är borta")

        // 3. Synken: rutan vid den styrandes klick och den andra vyns ruta på samma träff är vita
        // (filmernas vita ruta ligger på klicket, och telefonerna står lika långt bort).
        let styrP = try XCTUnwrap(styrStore.load(id))
        let fv = try XCTUnwrap(styrStore.annanVideo(id))
        let halv = 1.0 / 480
        for s in [styrP.shots[0], styrP.shots[3]] {
            let k = try XCTUnwrap(fv.kalla(slag: s, par: par))
            let egen = try await bild(styrStore.url(styrP.series[0].file, in: id), s.click.time + halv)
            let annan = try await bild(styrStore.url(k.fil, in: id), s.click.time + k.offset + halv)
            let foreAnnan = try await bild(styrStore.url(k.fil, in: id), s.click.time + k.offset - 3 * halv)
            print(String(format: "PROV: VIDEO synken %@: DTL-rutan vid klicket ljus %.2f, FO-rutan på samma träff %.2f (ruta före %.2f), förskjutning %.4f s",
                         s.id, ljus(egen), ljus(annan), ljus(foreAnnan), k.offset))
            XCTAssertGreaterThan(ljus(egen), 0.85, "\(s.id): den styrandes vita ruta")
            XCTAssertGreaterThan(ljus(annan), 0.85, "\(s.id): följarens vita ruta på samma träff")
            XCTAssertLessThan(ljus(foreAnnan), 0.6, "\(s.id): rutan före är grå")
        }

        // 4. Send to PC på den styrande: två paket i paketets format (BESLUT B81).
        let urls = try await Export.packages(passID: id, store: styrStore, includeClips: true)
        XCTAssertEqual(urls.map(\.lastPathComponent), ["swinglab-\(id)-dtl.zip", "swinglab-\(id)-fo.zip"])
        try? FileManager.default.removeItem(atPath: Self.parat)
        try FileManager.default.createDirectory(atPath: Self.parat, withIntermediateDirectories: true)
        for u in urls { try FileManager.default.copyItem(at: u, to: URL(fileURLWithPath: Self.parat).appending(path: u.lastPathComponent)) }
        let fo = try ZipCatalog(url: urls[1])
        let m = try JSONDecoder().decode(PackageManifest.self, from: fo.data(named: "manifest.json"))
        XCTAssertEqual(m.view, .fo)
        let medKlipp = m.shots.filter { $0.clip != nil }.map(\.id)
        print("PROV: VIDEO paketen \(urls.map(\.lastPathComponent)); FO \(fo.names), klipp för \(medKlipp)")
        XCTAssertEqual(medKlipp, ["s01", "s02", "s03"], "följarens tre slag har var sitt klipp")
        let facit: [String: Any] = ["pass": id, "fo_klipp": medKlipp, "dtl_slag": styrP.shots.map(\.id)]
        try JSONSerialization.data(withJSONObject: facit, options: [.sortedKeys])
            .write(to: URL(fileURLWithPath: Self.parat + "/facit.json"))

        // 5. Vyerna: raden "Paired", passet i DTL, FO och 3D, raden om vad som finns.
        let k = try katalog()
        let rader = [Sessionsrad(styrP, parad: true), Sessionsrad(try XCTUnwrap(foljStore.load(id)), parad: true)]
        XCTAssertTrue(Sessionsrad.parad(mapp: styrStore.passFolder(id)), "par.json och följarens slag finns")
        XCTAssertEqual(rader.map(\.vyNamn), ["Paired", "Face on"])
        // Två telefoners rader (samma pass-id, i var sin lista): ritade efter varandra.
        try rendera(VStack(spacing: 0) { SessionRadVy(rad: rader[0]); SessionRadVy(rad: rader[1]) }.padding(.horizontal, 20),
                    namn: "parad-rad", accent: false)
        let status = Parstatus.text(pass: styrP, par: styrStore.pairs(id), video: fv)
        XCTAssertEqual(status, "4 swings\u{00A0}· 4 from both phones")
        let dtlVisning = try XCTUnwrap(PassShotsView.visning(styrP, earlier: []))
        let annan = try AnnanSession.pass(try XCTUnwrap(styrStore.otherPhone(id)), lead: styrP)
        let foVisning = try XCTUnwrap(PassShotsView.visning(annan, earlier: []))
        XCTAssertTrue(foVisning.kort(i: .fo).contains { $0.id == "sway_topp" })
        let kort3D = (try? treDFil()).map { TreDKort($0.0, katalog: k) }
        for (val, namn) in [(Parvy.dtl, "parad-dtl"), (.fo, "parad-fo"), (.treD, "parad-3d")] {
            let lage = ParadLage(egen: .dtl, valt: val, franBada: status,
                                 forlopp: val == .dtl ? Texter.hamtar(60) : nil, kanHamtaHela: true,
                                 annanKlipp: Set(fv.klipp.keys), utanKlick: fv.utanKlick)
            try rendera(PassScreenContent(pass: styrP, visning: dtlVisning, images: [:], overlays: [:],
                                          analysis: AnalysisState(), editable: false, treD: kort3D,
                                          onFigur: val == .treD ? {} : nil, parad: lage,
                                          annanVisning: foVisning), namn: namn, accent: false, skala: 2)
        }

        // 3D-fliken i Leads parade pass har S6d:s rad "3D" (figuren): fliken med figuren är en rad
        // högre än utan, och raden öppnar figuren, här ritad ur fixturens pass vid P7 (S6d, B73).
        let lage3D = ParadLage(egen: .dtl, valt: .treD, franBada: status)
        func hojd(_ onFigur: (() -> Void)?) throws -> CGFloat {
            let r = ImageRenderer(content: PassScreenContent(pass: styrP, visning: dtlVisning, images: [:], overlays: [:],
                                                             analysis: AnalysisState(), editable: false, treD: kort3D,
                                                             onFigur: onFigur, parad: lage3D, annanVisning: foVisning)
                .frame(width: Self.bredd).environment(\.colorScheme, .dark))
            r.proposedSize = ProposedViewSize(width: Self.bredd, height: nil)
            return try XCTUnwrap(r.uiImage).size.height
        }
        let medFigur = try hojd({}), utanFigur = try hojd(nil)
        print(String(format: "PROV: VIDEO 3D-fliken i det parade passet: %.0f pt med raden 3D, %.0f pt utan", medFigur, utanFigur))
        XCTAssertGreaterThanOrEqual(medFigur - utanFigur, 40, "raden 3D (figuren) i 3D-fliken")
        let (_, f) = try treDFigur("utan_brus")
        let fig = try XCTUnwrap(f.figurer.first)
        let u = f.index.uppstallningar[fig.uppstallning]
        let r = try XCTUnwrap(TreDRiktning.ur(fig, uppstallning: u, hand: f.index.hand))
        let k7 = try XCTUnwrap(fig.positionsRutor().first { $0.name == "P7" }?.index ?? nil)
        try rendera(TreDFigurInnehall(index: f.index, figur: fig, uppstallning: u, riktning: r,
                                      betraktare: TreDBetraktare.vinkel(.faceOn, r), rubrik: "Shot 1", nu: fig.t(k7),
                                      vinkel: .faceOn, spar: TreDSpar.spar(fig, val: [.hands]), sparVal: [.hands],
                                      forra: false, nasta: true),
                    namn: "parad-3d-figur", accent: false)

        // Granskningen i båda vyerna, samma ruta och position (P7, träffen), videon synkad.
        let s1 = styrP.shots[0]
        let leder = try XCTUnwrap(styrStore.joints(try XCTUnwrap(s1.joints), in: id))
        let review = ShotReview(series: leder, crop: nil)
        let pos = review.positions(s1.measure)
        let k7 = try XCTUnwrap(review.index(nearestT: s1.impact - s1.click.time))
        let kalla = try XCTUnwrap(fv.kalla(slag: s1, par: par))
        let tDTL = review.frames[k7].pts
        let annanSlag = try XCTUnwrap(AnnanSession.slag(s1, i: annan, par: par))
        XCTAssertEqual(annanSlag.id, "s01")
        let stillDTL = try await bild(styrStore.url(styrP.series[0].file, in: id), tDTL)
        let stillFO = try await bild(styrStore.url(kalla.fil, in: id), tDTL + kalla.offset)
        let vyerna: [(Vy, CGImage, [Positionsrad])] = [
            (.dtl, stillDTL, ReviewRows.rows(pass: styrP, shot: s1, position: "P7", baseline: [:])),
            (.fo, stillFO, ReviewRows.rows(pass: annan, shot: annanSlag, position: "P7", baseline: [:])),
        ]
        for (vy, still, rows) in vyerna {
            let vyval = Segment(alternativ: ["DTL", "FO"], valt: .constant(vy == .dtl ? 0 : 1))
            try rendera(ReviewContent(surface: Image(decorative: still, scale: 1).resizable(), review: review, number: 1,
                                      frame: k7, overlayOn: vy == .dtl, position: "P7", positions: pos, rows: rows,
                                      impact: s1.impact - s1.click.time, editable: false, vyval: AnyView(vyval),
                                      aspekt: vy == .fo ? Double(still.width) / Double(still.height) : nil),
                        namn: "parad-granskning-\(vy.rawValue)", accent: false)
            if vy == .fo {
                XCTAssertTrue(rows.contains { $0.matt == "sway_gap_traff" }, "FO:s rader i FO")
            } else {
                XCTAssertTrue(rows.contains { $0.matt == "backen_thrust_traff" }, "DTL:s rader i DTL")
            }
        }

        // 6. Varningen för samma vy i uppställningen (signalfärgen, som uppställningens varningar).
        try spara(SammaVyVarning(vy: .dtl, onByt: {}).padding(.vertical, 16).frame(width: Self.bredd)
                    .background(Theme.ground), "samma-vy")
        XCTAssertTrue(Vyvakt.sammaVy(egen: .dtl, andra: [.dtl]))
    }

    /// Passets koppling säger till när den andra telefonen har samma vy, och den styrande begär då
    /// inga klipp (BESLUT B83).
    func testSammaVyIPasset() async throws {
        let id = "20261024-160000"
        let rot = FileManager.default.temporaryDirectory
            .appending(path: "swinglab-sammavy-\(UUID().uuidString)", directoryHint: .isDirectory)
        let store = Store(root: rot, exportFolder: rot.appending(path: "Export"))
        _ = store.adopt(store.newPass(setup: PassSetup(view: .dtl, role: .lead)), id: id)
        let styr = PhoneLink(role: .lead, view: .dtl, mode: .pass, bonjour: false, device: "prov-styr")
        styr.forPass(id)
        styr.start()
        defer { styr.stop() }
        let portNu = await vantaPa(10) { styr.port }
        let port = try XCTUnwrap(portNu)
        let k = KlippKoppling(passID: id, store: store)
        k.start(link: styr)
        let folj = PhoneLink(role: .follow, view: .dtl, mode: .pass, partner: "prov-styr",
                             endpoint: .hostPort(host: "127.0.0.1", port: try XCTUnwrap(NWEndpoint.Port(rawValue: port))),
                             bonjour: false, device: "prov-folj")
        folj.start()
        defer { folj.stop() }
        let ok7 = await vanta(15) { k.sammaVy }
        XCTAssertTrue(ok7, "samma vy syns inte")
        print("PROV: VIDEO samma vy på båda telefonerna: \(Texter.sammaVy(.dtl)), i passet \(Texter.sammaVyIPasset)")
    }

    // MARK: - Hjälp

    /// Rutan vid tiden t i filen (toleransen 0: rutan som visas då).
    private func bild(_ url: URL, _ t: Double) async throws -> CGImage {
        let g = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        g.appliesPreferredTrackTransform = true
        g.requestedTimeToleranceBefore = .zero
        g.requestedTimeToleranceAfter = .zero
        return try await g.image(at: CMTime(seconds: max(0, t), preferredTimescale: 48_000)).image
    }

    /// Ljusheten 0…1 mitt i bilden.
    private func ljus(_ cg: CGImage) -> Double {
        var rgba = [UInt8](repeating: 0, count: 4)
        _ = rgba.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: -cg.width / 2, y: -cg.height / 2, width: cg.width, height: cg.height))
            return true
        }
        return (Double(rgba[0]) + Double(rgba[1]) + Double(rgba[2])) / (3 * 255)
    }

    /// En bild med uppställningens signalfärg (B13: varningar i uppställningen), utan formspråksprovet.
    private func spara(_ vy: some View, _ namn: String) throws {
        let r = ImageRenderer(content: vy.environment(\.colorScheme, .dark))
        r.scale = 3
        let png = try XCTUnwrap(r.uiImage?.pngData(), "kunde inte rita \(namn)")
        try FileManager.default.createDirectory(atPath: Self.ut, withIntermediateDirectories: true)
        try png.write(to: URL(fileURLWithPath: "\(Self.ut)/\(namn).png"))
        print("PROV: skrev \(namn).png")
    }

    private func vanta(_ sekunder: Double, _ villkor: () -> Bool) async -> Bool {
        let slut = Date().addingTimeInterval(sekunder)
        while Date() < slut {
            if villkor() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return villkor()
    }

    private func vantaPa<T>(_ sekunder: Double, _ varde: () -> T?) async -> T? {
        var ut: T?
        _ = await vanta(sekunder) {
            ut = varde()
            return ut != nil
        }
        return ut
    }
}
