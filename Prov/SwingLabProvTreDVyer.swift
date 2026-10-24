// 3D I VYERNA RITADE TILL PNG (S6c-2, BESLUT B62, METOD MS19): passets kort med tal, med skäl
// och hoppat, Progress med ett 3D-mått och uppställningens lutning. Talen kommer ur ett
// PÅHITTAT pass (tools/tests/fixturer/tre_d/) och Demo-passen (CLAUDE.md, Dataregeln). Samma
// prov av formspråket som de andra vyerna: gråskala, ingen accent (3D övas aldrig, B14, B37).

import XCTest
import SwiftUI
import Swing
import Capture
import TreD
import SwingDemo
@testable import SwingLab

extension SwingLabProvVyer {
    func treDFil() throws -> (TreDFil, TreDResultat) {
        let (dtl, fo) = try TreDFixtur.indata("utan_brus")
        guard case let .resultat(r) = TreDTelefon.rakna(fo, dtl) else { throw XCTSkip("3D hoppades över") }
        return (TreDFil(pass: "20261103-180000", raknad: Date(), raknadAv: .dtl, kallor: [:], sekunder: 1, ut: .resultat(r)), r)
    }

    func testTreDKortet() throws {
        let k = try katalog()
        let (fil, r) = try treDFil()
        var forra = try XCTUnwrap(fil.medianer)
        for (m, d) in [("xfaktor_stretch", -9.4), ("backen_vrid_topp", 2.6), ("hofter_oppna_traff", -1.2)] {
            let v = forra[m]?.median
            forra[m]?.median = v.map { $0 + d }
        }
        let kort = TreDKort(fil, forra: (Tal.dag(2026, 10, 27), forra), katalog: k)
        XCTAssertEqual(kort.rader.count, 5)
        try rendera(TreDKortVy(kort: kort), namn: "tred-kort", accent: false)
        try rendera(TreDKortVy(kort: kort), namn: "tred-kort-stor", textstorlek: .accessibility5, accent: false)

        // Färre än tio svingar, en vinkel utanför 60–120° och slag utanför: inga tal, skälen i grått.
        var r2 = r
        r2.session = [:]
        r2.n = r2.n.mapValues { _ in 7 }
        r2.osaker = ["serie 1 (DTL) mot 1 (FO): vinkeln mellan kamerorna utanför 60–120°"]
        r2.utelamnade = [TreDUtelamnat(dtl: "s08", fo: "s08", skal: "domen är inte sving")]
        let farre = TreDKort(TreDFil(pass: fil.pass, raknad: Date(), raknadAv: .dtl, kallor: [:], sekunder: nil,
                                     ut: .resultat(r2)), katalog: k)
        XCTAssertTrue(farre.rader.allSatisfy { $0.varde == nil })
        try rendera(TreDKortVy(kort: farre), namn: "tred-kort-farre", accent: false)

        let hoppat = TreDKort(TreDFil(pass: fil.pass, raknad: Date(), raknadAv: .dtl, kallor: [:], sekunder: nil,
                                      ut: .hoppat("kalibreringen: ingen serie gick att kalibrera under spärren")), katalog: k)
        XCTAssertEqual(hoppat.rader.count, 0)
        try rendera(TreDKortVy(kort: hoppat), namn: "tred-kort-hoppat", accent: false)
    }

    func testTreDIProgress() throws {
        // Demo-passen, de sex sista med 3D (påhittade medianer kring Pythons fixtur).
        let (fil, _) = try treDFil()
        let bas = try XCTUnwrap(fil.medianer)
        let n = Demo.pass.count
        let pass = Demo.pass.enumerated().map { i, p -> Swing.Pass in
            var t: [String: TreDMedian] = [:]
            if i >= n - 6 {
                for (m, v) in bas {
                    let skift = Double((i * 7 + m.count) % 9) - 4
                    t[m] = TreDMedian(n: 10 + i % 4, median: v.median.map { $0 + skift }, q1: nil, q3: nil)
                }
            }
            return Swing.Pass(datum: p.datum, klubba: p.klubba, svingar: p.svingar, serie1: p.serie1,
                              osakerStart: p.osakerStart, klubbMarkerade: p.klubbMarkerade, treD: t)
        }
        let v = Utvecklingsvisning(katalog: try katalog(), pass: pass, block: Demo.block, ovas: Demo.attJobbaPa.ovas)
        let ids = v.matt.map(\.id)
        XCTAssertEqual(Array(ids.suffix(5)), Katalog.treDMatt.map { "\($0)_3d" })
        let u = try XCTUnwrap(v.matt.first { $0.id == "xfaktor_stretch_3d" })
        XCTAssertEqual(u.rubrik, "3D · no markers")
        XCTAssertEqual(u.punkter.count, 6)
        try rendera(UtvecklingVy(visning: v, valt: "xfaktor_stretch_3d"), namn: "utveckling-3d", accent: false)
        // Utan 3D i passen syns inga 3D-mått.
        let utan = Utvecklingsvisning(katalog: try katalog(), pass: Demo.pass, block: Demo.block)
        XCTAssertFalse(utan.matt.contains { $0.id.hasSuffix("_3d") })
    }

    func testLutningen() throws {
        let v = 4.0 * .pi / 180
        let l = try XCTUnwrap(Lutning(gravity: [sin(v), -cos(v), 0]))
        try rendera(LutningVy(lutning: l).frame(height: 300).background(Theme.cam), namn: "lutning", accent: false)
        let w = 52.0 * .pi / 180
        let s = try XCTUnwrap(Lutning(gravity: [-sin(w), -cos(w), 0]))
        XCTAssertTrue(s.forStorFor3D)
        try rendera(LutningVy(lutning: s).frame(height: 300).background(Theme.cam), namn: "lutning-for-stor", accent: false)
    }
}
