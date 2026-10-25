import Foundation
import XCTest
import Swing
@testable import Capture

/// Inspelningens skärm (PLAN S2j, METOD MS32): statusen, vilken varning som visas, lutningens
/// hysteres, vakten för den andra telefonen, svingräknaren och lagringen. Påhittade värden.
final class InspelningslageTests: XCTestCase {
    let fo = AndraTelefonen(vy: .fo, kopplad: true, inspelar: false)

    // MARK: Statusen

    func testStatusen() {
        XCTAssertEqual(InspelningsStatus.av(roll: .solo, inspelar: false, sekunder: 0, svingar: nil, andra: [], natAv: false), .ingen)
        XCTAssertEqual(InspelningsStatus.av(roll: .lead, inspelar: false, sekunder: 0, svingar: nil, andra: [], natAv: false), .soker)
        XCTAssertEqual(InspelningsStatus.av(roll: .lead, inspelar: false, sekunder: 0, svingar: nil, andra: [fo], natAv: false), .kopplad)
        XCTAssertEqual(InspelningsStatus.av(roll: .follow, inspelar: false, sekunder: 0, svingar: nil,
                                            andra: [AndraTelefonen(vy: .dtl, kopplad: true, inspelar: false)], natAv: false), .kopplad)
        var tappad = fo
        tappad.kopplad = false
        XCTAssertEqual(InspelningsStatus.av(roll: .lead, inspelar: false, sekunder: 0, svingar: nil, andra: [fo, tappad], natAv: false), .tappad)
        // Lokalt nätverk av: ingen pill, varningen säger det.
        XCTAssertEqual(InspelningsStatus.av(roll: .lead, inspelar: false, sekunder: 0, svingar: nil, andra: [], natAv: true), .ingen)
        // Under serien: REC med tiden nedåt avrundad, också ensam.
        let rec = InspelningsStatus.av(roll: .solo, inspelar: true, sekunder: 42.9, svingar: 3, andra: [], natAv: false)
        XCTAssertEqual(rec, .spelarIn(sekunder: 42, svingar: 3))
        XCTAssertEqual(rec.text, "REC 0:42\u{00A0}\u{00B7} 3 swings")
        XCTAssertEqual(InspelningsStatus.spelarIn(sekunder: 5, svingar: nil).text, "REC 0:05")
        XCTAssertEqual(InspelningsStatus.spelarIn(sekunder: 61, svingar: 1).text, "REC 1:01\u{00A0}\u{00B7} 1 swing")
        XCTAssertNil(InspelningsStatus.ingen.text)
        XCTAssertEqual(InspelningsStatus.tappad.text, "Other phone lost")
        XCTAssertEqual(InspelningsStatus.kopplad.text, "Connected")
        XCTAssertEqual(InspelningsStatus.soker.text, "Searching")
    }

    // MARK: Varningarna

    func testIngenVarningNarAlltArRatt() {
        var f = Inspelningsfakta(roll: .lead, vy: .dtl)
        f.andra = [fo]
        f.ledigaByte = 50_000_000_000
        f.bildfrekvens = 240
        f.tryck = .serious                                   // information: kugghjulet
        XCTAssertNil(InspelningsVarning.av(f))
        XCTAssertEqual(InspelningsVarning.alla(f), [])
    }

    func testVarningarnaOchOrdningen() {
        var f = Inspelningsfakta(roll: .lead, vy: .dtl, inspelar: true)
        f.andra = [AndraTelefonen(vy: .dtl, kopplad: true, inspelar: false)]
        f.andraStoppade = true
        f.natAv = true
        f.tryck = .critical
        f.ledigaByte = 3_000_000_000
        f.mikrofonAv = true
        f.externMikrofon = true
        f.bildfrekvens = 120
        f.narOnskad = false
        XCTAssertEqual(InspelningsVarning.alla(f), [
            .andraStoppade, .sammaVy(.dtl, kanByta: false), .lokaltNatAv, .varme(.critical), .lagring,
            .mikrofonAv, .bildfrekvens(120),
        ])
        f.problem = "Interrupted."
        XCTAssertEqual(InspelningsVarning.av(f), .problem("Interrupted."))
        XCTAssertEqual(InspelningsVarning.av(f)?.text, "Interrupted.")
    }

    func testVarningarnasText() {
        XCTAssertEqual(InspelningsVarning.andraStoppade.text, "Other phone stopped recording")
        XCTAssertEqual(InspelningsVarning.sammaVy(.dtl, kanByta: true).text, "Both phones are DTL")
        XCTAssertEqual(InspelningsVarning.sammaVy(.dtl, kanByta: true).bytTill, .fo)
        XCTAssertNil(InspelningsVarning.sammaVy(.dtl, kanByta: false).bytTill)
        XCTAssertEqual(InspelningsVarning.lokaltNatAv.text, "Local network off")
        XCTAssertEqual(InspelningsVarning.varme(.critical).text, "Heat: critical")
        XCTAssertEqual(InspelningsVarning.lagring.text, "Less than 4 GB free")
        XCTAssertEqual(InspelningsVarning.bildfrekvens(120).text, "120 fps, not 240")
        XCTAssertEqual(InspelningsVarning.mikrofonAv.text, "Microphone off")
        XCTAssertEqual(InspelningsVarning.externMikrofon.text, "External microphone")
    }

    func testVarmenVarnarForstVidKritisk() {
        var f = Inspelningsfakta()
        for p in Pressure.allCases {
            f.tryck = p
            XCTAssertEqual(InspelningsVarning.av(f) != nil, p >= .critical, p.rawValue)
        }
    }

    func testSammaVyKanBytasBaraForeSerien() {
        var f = Inspelningsfakta(roll: .follow, vy: .fo)
        f.andra = [AndraTelefonen(vy: .fo, kopplad: true, inspelar: false)]
        f.kanByta = true
        XCTAssertEqual(InspelningsVarning.av(f)?.bytTill, .dtl)
        f.inspelar = true
        XCTAssertNil(InspelningsVarning.av(f)?.bytTill)
        // En tappad telefon med samma vy räknas inte: den hör inte bytet.
        f.inspelar = false
        f.andra[0].kopplad = false
        XCTAssertNil(InspelningsVarning.av(f))
    }

    func testTappadVarnarBaraUnderSerien() {
        var f = Inspelningsfakta(roll: .lead, vy: .dtl)
        f.andra = [AndraTelefonen(vy: .fo, kopplad: false, inspelar: false)]
        XCTAssertNil(InspelningsVarning.av(f))              // pillen säger "Other phone lost"
        f.inspelar = true
        XCTAssertEqual(InspelningsVarning.av(f), .andraTappad)
        XCTAssertEqual(InspelningsVarning.andraTappad.text, "Other phone lost")
    }

    func testEnsamFarIngaKopplingensVarningar() {
        var f = Inspelningsfakta(roll: .solo, vy: .dtl, inspelar: true)
        f.natAv = true
        f.andraStoppade = true
        XCTAssertNil(InspelningsVarning.av(f))
        f.ledigaByte = 1_000_000_000
        XCTAssertEqual(InspelningsVarning.av(f), .lagring)
        f.ledigaByte = nil                                    // okänt: ingen varning
        XCTAssertNil(InspelningsVarning.av(f))
    }

    // MARK: Lutningen

    func lutning(_ grader: Double) -> Lutning {
        let v = grader * .pi / 180
        return Lutning(gravity: [sin(v), -cos(v), 0])!
    }

    func testLutningensHysteres() {
        var v = LutningsVisare()
        XCTAssertFalse(v.uppdatera(lutning(1.9)))
        XCTAssertFalse(v.uppdatera(lutning(2.0)))             // på först över 2,0°
        XCTAssertTrue(v.uppdatera(lutning(2.05)))
        XCTAssertTrue(v.uppdatera(lutning(1.9)))              // kvar mellan 1,5 och 2,0
        XCTAssertTrue(v.uppdatera(lutning(-1.6)))             // åt andra hållet: beloppet
        XCTAssertTrue(v.uppdatera(lutning(1.5)))
        XCTAssertFalse(v.uppdatera(lutning(1.49)))            // av under 1,5°
        XCTAssertFalse(v.uppdatera(lutning(1.9)))
        XCTAssertTrue(v.uppdatera(lutning(-6)))
        XCTAssertFalse(v.uppdatera(nil))                      // inget prov: inget visas
        XCTAssertFalse(v.visas)
    }

    func testLutningenGarInteFramOchTillbakaVidGransen() {
        // Brus ±0,3° runt 2°: en växling, inget blinkande.
        var v = LutningsVisare()
        var byten = 0
        var forra = v.visas
        for i in 0..<200 {
            let g = 2.0 + (i % 2 == 0 ? 0.3 : -0.3) * Double((i * 7) % 5) / 4
            if v.uppdatera(lutning(g)) != forra { byten += 1 }
            forra = v.visas
        }
        XCTAssertEqual(byten, 1)
    }

    func testOver45GraderVisasAlltid() throws {
        var v = LutningsVisare()
        // Framåt (mot marken) 50°: ingen lutning åt sidan, men för mycket för 3D.
        let p = 50.0 * .pi / 180
        let l = try XCTUnwrap(Lutning(gravity: [0, -cos(p), -sin(p)]))
        XCTAssertTrue(l.forStorFor3D)
        XCTAssertTrue(v.uppdatera(l))
    }

    func testLutningensTal() {
        XCTAssertEqual(LutningsVisare.text(lutning(6.2)), "6°")
        XCTAssertEqual(LutningsVisare.text(lutning(-2.6)), "3°")
    }

    // MARK: Den andra telefonen slutade

    func testAndraStoppade() {
        var v = AndraStoppadeVakt()
        let spelar = AndraTelefonen(vy: .fo, kopplad: true, inspelar: true)
        let stilla = AndraTelefonen(vy: .fo, kopplad: true, inspelar: false)
        // Före serien: aldrig.
        XCTAssertFalse(v.uppdatera(roll: .lead, egenInspelar: false, tid: 0, andra: [stilla]))
        // Följaren startar en stund efter: ingen varning inom marginalen.
        XCTAssertFalse(v.uppdatera(roll: .lead, egenInspelar: true, tid: 10, andra: [stilla]))
        XCTAssertFalse(v.uppdatera(roll: .lead, egenInspelar: true, tid: 11.5, andra: [stilla]))
        XCTAssertFalse(v.uppdatera(roll: .lead, egenInspelar: true, tid: 12, andra: [spelar]))
        XCTAssertFalse(v.uppdatera(roll: .lead, egenInspelar: true, tid: 40, andra: [spelar]))
        // Slutade mitt i: varning direkt.
        XCTAssertTrue(v.uppdatera(roll: .lead, egenInspelar: true, tid: 41, andra: [stilla]))
        // Tappad: den egna varningen, inte den här.
        XCTAssertFalse(v.uppdatera(roll: .lead, egenInspelar: true, tid: 42,
                                   andra: [AndraTelefonen(vy: .fo, kopplad: false, inspelar: false)]))
        // Ny serie: börjar om.
        XCTAssertFalse(v.uppdatera(roll: .lead, egenInspelar: false, tid: 50, andra: [stilla]))
        XCTAssertFalse(v.uppdatera(roll: .lead, egenInspelar: true, tid: 60, andra: [stilla]))
        // Startade aldrig: varning efter marginalen.
        XCTAssertTrue(v.uppdatera(roll: .lead, egenInspelar: true, tid: 63, andra: [stilla]))
        // Följaren vet inte om den styrande spelar in.
        var f = AndraStoppadeVakt()
        XCTAssertFalse(f.uppdatera(roll: .follow, egenInspelar: true, tid: 0, andra: [stilla]))
        XCTAssertFalse(f.uppdatera(roll: .follow, egenInspelar: true, tid: 30, andra: [stilla]))
    }

    // MARK: Svingarna under serien

    func testSvingarnaRaknasEnGangPerKlick() {
        var s = LevandeSvingar()
        var t = 0.0
        func tyst(_ sekunder: Double) {
            let slut = t + sekunder
            while t < slut {
                s.prov(tid: t, topp: -50 + (Int(t * 20) % 3 == 0 ? 2 : -1))
                t += 0.05
            }
        }
        // Ett klick i första halvsekunden räknas inte: baslinjen saknas.
        s.prov(tid: 0, topp: -5)
        t = 0.05
        tyst(4)
        XCTAssertEqual(s.antal, 0)
        for _ in 0..<3 {
            // Toppen hålls några prov (peakHold): ett klick.
            for _ in 0..<6 {
                s.prov(tid: t, topp: -8)
                t += 0.05
            }
            tyst(8)
        }
        XCTAssertEqual(s.antal, 3)
        // Två toppar närmare än en sekund: ett klick.
        s.prov(tid: t, topp: -8); t += 0.05
        s.prov(tid: t, topp: -50); t += 0.05
        s.prov(tid: t, topp: -8); t += 0.05
        tyst(5)
        XCTAssertEqual(s.antal, 4)
        // Under gränsen (+15 dB): inget.
        s.prov(tid: t, topp: -35); t += 0.05
        tyst(5)
        XCTAssertEqual(s.antal, 4)
        s.prov(tid: t, topp: .nan)
        XCTAssertEqual(s.antal, 4)
    }

    // MARK: Lagringen

    func testLagringstiden() {
        XCTAssertNil(Lagringstid.minuter(ledigt: nil, mbPerMinut: nil))
        // 21,2 GB ledigt, golvet 2 GB, 480 MB/min: 40 minuter.
        XCTAssertEqual(Lagringstid.minuter(ledigt: 21_200_000_000, mbPerMinut: nil), 40)
        XCTAssertEqual(Lagringstid.minuter(ledigt: 21_200_000_000, mbPerMinut: 0), 40)
        XCTAssertEqual(Lagringstid.minuter(ledigt: 12_000_000_000, mbPerMinut: 250), 40)
        XCTAssertEqual(Lagringstid.minuter(ledigt: 1_000_000_000, mbPerMinut: nil), 0)
        XCTAssertEqual(Texter.inspMinuter(40), "about 40 min")
        XCTAssertEqual(Texter.inspHorda(6, av: 6, ms: "1.2"), "6 of 6\u{00A0}\u{00B7} 1.2 ms")
        XCTAssertEqual(Texter.inspTelefon(roll: "Lead", vy: .dtl), "Lead\u{00A0}\u{00B7} DTL")
        XCTAssertEqual(Texter.inspTelefon(roll: nil, vy: .fo), "FO")
    }

    func testHjalplinjernaArPaSomStandard() throws {
        var s = AppSettings()
        XCTAssertTrue(s.visaHjalplinjer)
        s.guideLines = false
        let data = try JSONEncoder().encode(s)
        XCTAssertFalse(try JSONDecoder().decode(AppSettings.self, from: data).visaHjalplinjer)
        // En installningar.json från före S2j.
        let gammal = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"keepOriginals":true}"#.utf8))
        XCTAssertTrue(gammal.visaHjalplinjer)
    }
}
