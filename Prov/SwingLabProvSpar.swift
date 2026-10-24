// SIMULATORPROVET FÖR SPÅREN OCH KLUBBHUVUDETS BANA (PLAN S4f, S7b; BESLUT B70, B71).
//
// Vad som bevisas här, på PÅHITTADE filmer (inga riktiga svingar, CLAUDE.md: Dataregeln):
//   rutorna   appens läsare av Y-planet (KlubbSparLasare) ger rutan upprätt som lederna: en
//             vit markör i den lagrade bufferten hamnar där Orientation säger, och en ruta
//             som inte finns i filen blir ingen bild (METOD MS7, M61);
//   banan     SwingLabKit:s spårning på den påhittade klubbfilmen (KlubbFilm) ritas med
//             spårlagret i granskningen: fast det spelade, svagt resten, interpolerat
//             streckat, och händernas spår bredvid (bilderna klubba-bana-p6, klubba-bana-p10).
// KLUBBHUVUDETS BANA PÅ RIKTIGA KLIPP PROVAS BARA PÅ TELEFONEN.

import XCTest
import AVFoundation
import CoreGraphics
import SwiftUI
import UIKit
import Swing
import Capture
import SwingDemo
@testable import SwingLab

@MainActor
final class SwingLabProvSpar: XCTestCase {
    static let ut = "/tmp/swinglab_prov"

    /// Läsaren ger den upprätta rutan: markören i bufferten 480 × 270 (EXIF 6) hamnar i den
    /// upprätta bilden 270 × 480 där Orientation.uprightRect säger.
    func testRutornaUrFilenUpprattSomLederna() async throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "swinglab-prov", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let film = dir.appending(path: "spar-markor.mov")
        let m = (x: 40, y: 20, width: 80, height: 60)
        try await SyntheticMovie.write(to: film, sound: .none, seconds: 1.0, marker: m)
        let geo = try await MediaReader.geometry(film)
        XCTAssertEqual(geo.exif, 6)
        let skala = KlubbRutor.skala(uprightWidth: 270, uprightHeight: 480)
        XCTAssertEqual(skala, 1)
        // Ruta 120 finns (var tredje saknas: 122 saknas).
        let bilder = try await KlubbSparLasare.lasRutor(url: film, pts: [120.0 / 240, 122.0 / 240, 123.0 / 240],
                                                        exif: geo.exif, skala: skala)
        XCTAssertNotNil(bilder[0])
        XCTAssertNil(bilder[1], "rutan finns inte i filen")
        XCTAssertNotNil(bilder[2])
        let b = try XCTUnwrap(bilder[0])
        XCTAssertEqual(b.count, 270 * 480)
        let r = Orientation.uprightRect(CropRect(x: Double(m.x) / 480, y: Double(m.y) / 270, width: Double(m.width) / 480,
                                                 height: Double(m.height) / 270), exif: 6)
        func medel(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> Double {
            var s = 0.0, n = 0.0
            for y in Int(y0 * 480 + 3)..<Int(y1 * 480 - 3) {
                for x in Int(x0 * 270 + 3)..<Int(x1 * 270 - 3) {
                    s += Double(b[y * 270 + x])
                    n += 1
                }
            }
            return s / max(n, 1)
        }
        let inne = medel(r.x, r.y, r.maxX, r.maxY)
        let ute = medel(0.6, 0.6, 0.9, 0.9)
        print("PROV: spårets rutor: markören \(Int(inne)) i \(r), bakgrunden \(Int(ute))")
        XCTAssertGreaterThan(inne, 220, "markören där Orientation säger")
        XCTAssertLessThan(ute, 160)
    }

    /// Klubbhuvudets bana på den påhittade filmen, ritad i granskningen med händernas spår.
    func testKlubbhuvudetsBanaIGranskningen() throws {
        let f = KlubbFilm.film()
        let bana = KlubbBana(KlubbSpar.spara(f.rutor, bredd: KlubbFilm.rutBredd, hojd: KlubbFilm.rutHojd,
                                             skala: KlubbFilm.skala, ankare: f.ankare), ankare: f.ankare)
        print("PROV: klubbhuvudets bana: \(bana.punkter.count) rutor, \(Int(bana.andelInterpolerade * 100)) % interpolerade")
        XCTAssertGreaterThan(bana.punkter.count, 250)
        XCTAssertLessThanOrEqual(bana.andelInterpolerade, 0.5)
        let frames = f.rutor.map { r in
            PoseFrame(t: r.t, pts: r.t + 1, joints: r.leder.map { $0.map { PoseJoint(x: $0.x, y: $0.y, c: 0.9) } },
                      confidence: 0.9)
        }
        let review = ShotReview(series: JointSeries(width: KlubbFilm.bredd, height: KlubbFilm.hojd, frames: frames), crop: nil)
        let pos: [(name: String, index: Int?)] = Klubba.positioner.map { p in
            (p, f.ankare.first { $0.position == p }.flatMap { review.index(nearestT: $0.t) })
        }
        let val: [SparPunkt] = [.hands, .club]
        let spar = review.spar([.hands]) + [SparSerie(bana: bana)]
        for (namn, p) in [("klubba-bana-p6", "P6"), ("klubba-bana-p10", "P10")] {
            let k = try XCTUnwrap(pos.first { $0.name == p }?.index ?? nil)
            let i = KlubbFilm.tider()[k].i
            let still = try XCTUnwrap(gra(KlubbFilm.ruta(i, f.rutor[k].t), KlubbFilm.rutBredd, KlubbFilm.rutHojd))
            try rita(ReviewContent(surface: Image(decorative: still, scale: 1).resizable(), review: review, number: 1,
                                   frame: k, overlayOn: false, position: p, positions: pos, rows: [], impact: 0,
                                   spar: spar, sparVal: Set(val), onSpar: { _ in }, klubbaMojlig: true, editable: false),
                     namn)
        }
    }

    // MARK: Hjälp

    private func gra(_ b: [UInt8], _ w: Int, _ h: Int) -> CGImage? {
        guard let p = CGDataProvider(data: Data(b) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: w,
                       space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: p, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    /// En vy i telefonens bredd, mörk, i full längd, till /tmp/swinglab_prov/<namn>.png.
    private func rita<V: View>(_ innehall: V, _ namn: String) throws {
        let vy = innehall
            .frame(width: 390)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 16)
            .background(Theme.ground)
            .environment(\.colorScheme, .dark)
        let r = ImageRenderer(content: vy)
        r.scale = 2
        r.proposedSize = ProposedViewSize(width: 390, height: nil)
        let png = try XCTUnwrap(r.uiImage?.pngData(), "\(namn).png ritades inte")
        try FileManager.default.createDirectory(atPath: Self.ut, withIntermediateDirectories: true)
        try png.write(to: URL(fileURLWithPath: "\(Self.ut)/\(namn).png"))
        print("PROV: skrev \(namn).png")
    }
}
