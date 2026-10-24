// FIGUREN I 3D RITAD TILL PNG (PLAN S6d, BESLUT B72, B73, METOD MK10, MK11): figuren vid P4 och P7
// från Face on, Down the line och Top, telefonerna där kalibreringen placerade dem, en
// uppställning över spärren (telefonerna, ingen figur) och ett pass utan 3D med skälet. Passen
// är PÅHITTADE (tools/tests/fixturer/tre_d/, CLAUDE.md, Dataregeln). Samma prov av formspråket
// som de andra vyerna: gråskala, ingen accent (3D övas aldrig, B14, B37). Raderna "PROV: TreD
// figur …" hamnar i kompilera.txt.

import XCTest
import SwiftUI
import Swing
import Capture
import TreD
@testable import SwingLab

extension SwingLabProvVyer {
    /// Ett fixturpass med figuren, räknad som på telefonen (TreDTelefon med figuren).
    func treDFigur(_ pass: String) throws -> (ut: TreDUt, figur: TreDFigurer) {
        let (dtl, fo) = try TreDFixtur.indata(pass)
        let start = Date()
        let r = TreDTelefon.rakna(fo, dtl, langdM: 1.80, figur: true)
        let figur = try XCTUnwrap(r.figur, pass)
        print(String(format: "PROV: TreD figur %@: %ld slag på %.2f s i simulatorn med figuren", pass,
                     figur.figurer.count, Date().timeIntervalSince(start)))
        return (r.ut, figur)
    }

    func testTreDFigurenVidP4OchP7FranTreVinklar() throws {
        let (_, f) = try treDFigur("utan_brus")
        let fig = try XCTUnwrap(f.figurer.first)
        let u = f.index.uppstallningar[fig.uppstallning]
        let r = try XCTUnwrap(TreDRiktning.ur(fig, uppstallning: u, hand: f.index.hand))
        let pos = Dictionary(uniqueKeysWithValues: fig.positionsRutor().map { ($0.name, $0.index) })
        for (p, val) in [("P4", [SparPunkt.hands]), ("P7", [.hands, .shoulders, .hips])] {
            let k = try XCTUnwrap(pos[p] ?? nil, p)
            for v in TreDVinkel.allCases {
                let vy = TreDFigurInnehall(index: f.index, figur: fig, uppstallning: u, riktning: r,
                                           betraktare: TreDBetraktare.vinkel(v, r), rubrik: "Shot 1", nu: fig.t(k),
                                           vinkel: v, spar: TreDSpar.spar(fig, val: val), sparVal: Set(val),
                                           forra: false, nasta: true)
                try rendera(vy, namn: "tred-figur-\(p.lowercased())-\(v.rawValue)", accent: false)
            }
        }
        print(String(format: "PROV: TreD figur %ld rutor, P4 %.3f s och P7 %.3f s på figurens tid, golvet %.2f m",
                     fig.n, fig.positioner["P4"] ?? .nan, fig.positioner["P7"] ?? .nan, u.golv ?? .nan))
    }

    func testTreDKamerornaOchOverSparren() throws {
        let (_, f) = try treDFigur("utan_brus")
        let fig = try XCTUnwrap(f.figurer.first)
        let u = f.index.uppstallningar[fig.uppstallning]
        let r = try XCTUnwrap(TreDRiktning.ur(fig, uppstallning: u, hand: f.index.hand))
        let kameror = try XCTUnwrap(u.kameror).values.map(\.c)
        let k = try XCTUnwrap(fig.positionsRutor().first { $0.name == "P1" }?.index)
        try rendera(TreDFigurInnehall(index: f.index, figur: fig, uppstallning: u, riktning: r,
                                      betraktare: TreDBetraktare.vinkel(.top, r, kameror: kameror), rubrik: "Shot 1",
                                      nu: fig.t(k), vinkel: .top, kameror: true),
                    namn: "tred-figur-kameror", accent: false)
        print(String(format: "PROV: TreD figur kamerorna: Sampson %.2f px, %.1f° mellan dem", u.sampsonPx ?? .nan,
                     u.vinkel ?? .nan))

        // Över spärren: telefonerna där kalibreringen satte dem och skälet, ingen figur (B72).
        let (ut, s) = try treDFigur("sparren")
        XCTAssertEqual(ut, .hoppat("kalibreringen: Sampson-felet är över spärren"))
        XCTAssertTrue(s.figurer.isEmpty)
        let us = try XCTUnwrap(s.index.uppstallningar.first)
        let rs = try XCTUnwrap(TreDRiktning.ur(nil, uppstallning: us, hand: s.index.hand))
        try rendera(TreDFigurInnehall(index: s.index, figur: nil, uppstallning: us, riktning: rs,
                                      betraktare: TreDBetraktare.vinkel(.top, rs, kameror: us.kameror!.values.map(\.c)),
                                      rubrik: Texter.treD, nu: 0, vinkel: .top, kameror: true),
                    namn: "tred-figur-over-sparren", accent: false)
    }

    func testTreDUtanFigurMedSkalet() throws {
        // Ett pass där ingen sving filmades av båda telefonerna: inga uppställningar, bara skälet.
        let index = TreDFigurIndex(pass: "20261103-180000", kallor: [:], langdM: 1.8, hand: .hoger,
                                   hoppat: "parningen: inga slag som båda telefonerna filmat och som går att mäta",
                                   uppstallningar: [], slag: [])
        let vy = TreDFigurInnehall(index: index, figur: nil, uppstallning: nil, riktning: nil, betraktare: nil,
                                   rubrik: Texter.treD, nu: 0)
        try rendera(vy, namn: "tred-figur-utan", accent: false)
    }

    func testTreDFigurenSparasOchLasesSomPaTelefonen() throws {
        let (_, f) = try treDFigur("utan_brus")
        let rot = FileManager.default.temporaryDirectory.appending(path: "swinglab-prov/figur-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: rot, withIntermediateDirectories: true)
        var g = f
        g.index.pass = "20261103-180000"
        g.index.kallor = ["dtl": "a", "fo": "b"]
        XCTAssertTrue(Store.skrivFigur(g, folder: rot))
        XCTAssertTrue(Store.skrivFigur(g, folder: rot))             // en ny figur ersätter den gamla
        XCTAssertEqual(Store.figurIndex(rot), g.index)
        let start = Date()
        let l = try XCTUnwrap(Store.lasFigur(rot, fil: g.index.slag[0].fil))
        let tid = Date().timeIntervalSince(start)
        XCTAssertEqual(l.n, g.figurer[0].n)
        XCTAssertNil(Store.lasFigur(rot, fil: "../tre_d.json"))
        let storlek = try FileManager.default.contentsOfDirectory(at: rot.appending(path: TreDFigurIndex.mapp),
                                                                  includingPropertiesForKeys: [.fileSizeKey])
            .reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        print(String(format: "PROV: TreD figur sparad: %ld slag, %ld byte på disken, ett slag läst på %.3f s",
                     g.figurer.count, storlek, tid))
        // Utan passets mapp (raderat pass) skrivs inget.
        XCTAssertFalse(Store.skrivFigur(g, folder: rot.appending(path: "finns-inte")))
    }
}
