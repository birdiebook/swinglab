import Capture
import Foundation
import Swing
import XCTest
@testable import TreD

/// S6c-2: telefonens väg till 3D (METOD MS19). 2D-faserna räknas på telefonen ur samma leder
/// som PC:n mäter, den andra telefonens slag kommer som en bunt (kompakta leder), och resultatet
/// ska vara Pythons inom METOD M50:s tolerans. PÅHITTADE pass (CLAUDE.md, Dataregeln).
extension TreDTests {
    static let telefonensPass = ["utan_brus", "bra_brus_vanster"]

    func testTelefonensFaserSomPCn() throws {
        for pass in Self.telefonensPass {
            let (d, f) = try Fixtur.paket(pass: pass, andra: [:])
            let langd = try XCTUnwrap(Fixtur.tal(try Fixtur.indata(pass)["langd_m"]))
            let sw = TreDTelefon.faser(d, langdM: langd).merging(TreDTelefon.faser(f, langdM: langd)) { x, _ in x }
            var storst = 0.0
            for (k, py) in try Fixtur.faser(pass) {
                guard py.start != nil || py.topp != nil else { continue }
                let s = try XCTUnwrap(sw[k], "\(pass) \(k)")
                XCTAssertEqual(s.start == nil, py.start == nil, "\(pass) \(k) start")
                if let a = s.start, let b = py.start { storst = max(storst, abs(a - b)) }
                if let a = s.topp, let b = py.topp { storst = max(storst, abs(a - b)) }
            }
            print("TRED-FASER \(pass) största skillnad mot Python \(storst) s")
            XCTAssertLessThanOrEqual(storst, 1e-9, pass)
        }
    }

    /// Den andra telefonens slag går genom bunten (kompakta leder, JSON, tillbaka), och
    /// paketen kommer i vilken ordning som helst.
    func testTelefonensVagSomPython() throws {
        for pass in Self.telefonensPass {
            let fx = try Fixtur.las(pass)
            let v = Fixtur.variant(fx, "grund")
            let bas = try Fixtur.indata(pass)["paket"] as! [String: Any]
            let l = try Fixtur.leder(pass)
            var indata: [String: TreDIndata] = [:]
            for vy in ["dtl", "fo"] {
                let p = bas[vy] as! [String: Any]
                indata[vy] = TreDIndata(manifest: Fixtur.data(p["manifest"])!, lederna: l[vy]!,
                                        par: Fixtur.data(p["par"]), enhet: Fixtur.data(p["enhet"]))
            }
            let fo = indata["fo"]!
            let bunt = try SlagBunt.make(manifest: fo.manifest, enhet: fo.enhet, par: fo.par, leder: fo.lederna)
            let d = try bunt.data()
            let tillbaka = try TreDIndata(try SlagBunt.las(d))
            print("TRED-BUNT \(pass) \(bunt.leder.count) slag \(d.count) byte")
            let start = Date()
            let ut = TreDTelefon.rakna(tillbaka, indata["dtl"]!)
            print("TRED-TELEFON \(pass) \(Date().timeIntervalSince(start)) s med 2D-faserna")
            guard case let .resultat(r) = ut else { return XCTFail("\(pass): \(ut)") }
            let a = Avvikelser()
            jamfor(r, v["python"] as! [String: Any], v["inre"] as! [Any], "\(pass)/telefonen", a)
            a.skriv("\(pass)/telefonen")
            inomTolerans(a, "\(pass)/telefonen")

            // Filen tur och retur, och medianerna till pass.json.
            let fil = TreDFil(pass: "20261103-180000", raknad: Date(timeIntervalSince1970: 0), raknadAv: .dtl,
                              kallor: ["dtl": "a", "fo": Overforing.summa(d)], sekunder: 1.5, ut: ut)
            let lest = try TreDFil.las(try fil.data())
            XCTAssertEqual(lest.treD?.slag, r.slag)
            XCTAssertEqual(lest.raknad, "1970-01-01T00:00:00Z")
            XCTAssertTrue(lest.galler(["dtl": "a", "fo": Overforing.summa(d)]))
            let med = try XCTUnwrap(lest.medianer)
            XCTAssertEqual(Set(med.keys), Set(TvaKameror.matt))
            for m in TvaKameror.matt {
                XCTAssertEqual(med[m]?.median, r.session[m]?.median)
                XCTAssertEqual(med[m]?.n, r.n[m])
            }
        }
    }

    func testTvaLikaVyerHoppas() throws {
        let bas = try Fixtur.indata("utan_brus")["paket"] as! [String: Any]
        let p = bas["dtl"] as! [String: Any]
        let i = TreDIndata(manifest: Fixtur.data(p["manifest"])!, lederna: try Fixtur.leder("utan_brus")["dtl"]!)
        XCTAssertEqual(TreDTelefon.rakna(i, i), .hoppat("parningen: paketen ska vara ett DTL- och ett FO-paket"))
        XCTAssertEqual(TreDKort(TreDFil(pass: "20261103-180000", raknad: Date(), raknadAv: .dtl, kallor: [:], sekunder: nil,
                                        ut: TreDTelefon.rakna(i, i))).skal, [Texter.treDVyerna])
    }

    /// Kortet: talen med minst min_slag svingar, skillnaden mot förra passet, skälen, och inga
    /// tal när 3D hoppades över (BESLUT B14, B62).
    func testKortet() throws {
        let fx = try Fixtur.las("utan_brus")
        let (dtl, fo) = try Fixtur.paket(pass: "utan_brus", andra: [:])
        var r = try TvaKameror.analysera(dtl: dtl, fo: fo, faser: Fixtur.faser("utan_brus"))
        _ = fx
        let katalog = try Katalog.las(Data(contentsOf: Fixtur.rot.appendingPathComponent("katalog.json")))
        let fil = TreDFil(pass: "20261103-180000", raknad: Date(), raknadAv: .dtl, kallor: [:], sekunder: nil,
                          ut: .resultat(r))
        var forra = fil.medianer!
        let stretchNu = try XCTUnwrap(Avrundning.avrunda("xfaktor_stretch", forra["xfaktor_stretch"]?.median))
        forra["xfaktor_stretch"]?.median = stretchNu - 20
        let k = TreDKort(fil, forra: (Tal.dag(2026, 11, 1), forra), katalog: katalog)
        XCTAssertEqual(k.rubrik, "3D · no markers")
        XCTAssertEqual(k.rader.map(\.matt), Katalog.treDMatt)
        XCTAssertEqual(k.rader.map(\.namn), ["Pelvis turn at the top", "Shoulder turn at the top", "X-factor at the top",
                                             "X-factor stretch", "Hips open at impact"])
        XCTAssertTrue(k.rader.allSatisfy { $0.varde != nil && $0.info != nil && $0.enhet == "°" })
        XCTAssertEqual(k.svingar, "10 swings")
        XCTAssertEqual(k.skal, [])
        let stretch = try XCTUnwrap(k.rader.first { $0.matt == "xfaktor_stretch" })
        XCTAssertEqual(stretch.mot, "+20.0° vs Nov 1")
        XCTAssertTrue(stretch.tydlig)
        XCTAssertFalse(try XCTUnwrap(k.rader.first { $0.matt == "backen_vrid_topp" }).tydlig)

        // Färre än tio: inga tal, och skälet.
        r.session = [:]
        r.n = r.n.mapValues { _ in 7 }
        r.utelamnade = [TreDUtelamnat(dtl: "s09", fo: "s09", skal: "domen är inte sving")]
        r.osaker = ["serie 1 (DTL) mot 1 (FO): vinkeln mellan kamerorna utanför 60–120°"]
        let k2 = TreDKort(TreDFil(pass: "20261103-180000", raknad: Date(), raknadAv: .dtl, kallor: [:], sekunder: nil,
                                  ut: .resultat(r)), katalog: katalog)
        XCTAssertTrue(k2.rader.allSatisfy { $0.varde == nil && $0.mot == nil })
        XCTAssertEqual(k2.skal, ["Fewer than 10 swings", "Camera angle outside 60–120°", "1 swing left out"])

        // Hoppat: inga rader och inga tal.
        let k3 = TreDKort(TreDFil(pass: "20261103-180000", raknad: Date(), raknadAv: .dtl, kallor: [:], sekunder: nil,
                                  ut: .hoppat("kalibreringen: Sampson-felet är över spärren")))
        XCTAssertEqual(k3.rader, [])
        XCTAssertNil(k3.svingar)
        XCTAssertEqual(k3.skal, ["Cameras could not be placed"])
    }

    /// Längden ger skalan i cm men inte faserna (MS19): telefonens och PC:ns längd kan skilja.
    func testFasernaBerorInteAvLangden() throws {
        let (d, f) = try Fixtur.paket(pass: "bra_brus_vanster", andra: [:])
        for p in [d, f] {
            XCTAssertEqual(TreDTelefon.faser(p, langdM: 1.55), TreDTelefon.faser(p, langdM: 1.95))
        }
    }

    /// Filen bär de oavrundade talen (marginalerna vid grenarna) och tål NaN; kortet utan tal
    /// när slagen ändrats.
    func testInreIFilenOchUppdateras() throws {
        let (dtl, fo) = try Fixtur.paket(pass: "utan_brus", andra: [:])
        let r = try TvaKameror.analysera(dtl: dtl, fo: fo, faser: Fixtur.faser("utan_brus"))
        var fil = TreDFil(pass: "20261103-180000", raknad: Date(), raknadAv: .dtl, kallor: [:], sekunder: nil,
                          ut: .resultat(r))
        XCTAssertEqual(fil.inre?.count, r.kalibrering.count)
        XCTAssertNotNil(fil.inre?.first??.sampsonPx)
        let lest = try TreDFil.las(try fil.data())
        XCTAssertEqual(lest.inre?.first??.forsk, r.inre.first??.forsk)
        fil.inre = [TreDInre(r: [.nan], t: [], upp: [], forsk: [], aterprojektion: [.nan, 1], sampsonPx: .infinity)]
        let text = String(decoding: try fil.data(), as: UTF8.self)
        XCTAssertFalse(text.contains("nan"))
        let k = TreDKort(fil, katalog: nil, aktuell: false)
        XCTAssertEqual(k.rader.count, 5)
        XCTAssertTrue(k.rader.allSatisfy { $0.varde == nil && $0.mot == nil })
        XCTAssertNil(k.svingar)
        XCTAssertEqual(k.skal, ["Updating…"])
    }

    func testKatalogensTreDArTvaKamerornas() throws {
        XCTAssertEqual(TreDFil.filnamn, PassPackage.treDFile)
        XCTAssertEqual(Katalog.treDMatt, TvaKameror.matt)
        let k = try Katalog.las(Data(contentsOf: Fixtur.rot.appendingPathComponent("katalog.json")))
        XCTAssertEqual(k.treD.map(\.matt), TvaKameror.matt)
        XCTAssertTrue(k.treD.allSatisfy { $0.minSlag == TvaKameror.minSlag && $0.lage == TvaKameror.lage })
    }
}
