// SIMULATORPROVET FÖR KLUBBMODELLEN I APPEN (PLAN S7-2, BESLUT B96, METOD MF7).
//
// Vad som bevisas här, på releasens RITADE bilder (inga andras bilder, inga av Johannes):
//   bygget     kompilera.yml hämtade modellen ur releasen (tools/hamta_klubbmodell.py, summorna
//              prövade) och Xcode kompilerade in den i appen som Klubbmodell.mlmodelc;
//   samma tal  Core ML i appen ger samma rutor som PyTorch-modellen på PC:n (prov.json): varje
//              ruta med konfidens ≥ 0,3 finns med samma klass, mitten inom MAX_PX och konfidensen
//              inom MAX_KONFIDENS;
//   tiden      ms per bild på simulatorns processor (inte telefonens Neural Engine).
// TIDEN PÅ TELEFONEN OCH MODELLEN PÅ RIKTIGA KLIPP PROVAS BARA PÅ TELEFONEN.

import XCTest
import CoreGraphics
import CoreML
import ImageIO
import Swing
@testable import SwingLab

final class SwingLabProvKlubbModell: XCTestCase {
    static let prov = "/tmp/swinglab_modell/prov"
    /// Mittens avstånd Core ML → PyTorch, px i modellens sida (research 7, S7-2: 0,5 px).
    static let maxPx = 0.5
    /// Konfidensens skillnad (antagande: FP16 mot FP32).
    static let maxKonfidens = 0.02

    private struct Prov: Decodable {
        struct Bild: Decodable {
            struct Ruta: Decodable {
                let klass: String
                let konfidens: Double
                let bbox: [Double]
            }
            let fil: String
            let detektioner: [Ruta]
        }
        let modell: String
        let konfidens: Double
        let bilder: [Bild]
    }

    func testCoreMLSomPyTorch() throws {
        let mapp = URL(fileURLWithPath: Self.prov)
        let prov = try JSONDecoder().decode(Prov.self, from: Data(contentsOf: mapp.appending(path: "prov.json")))
        let k = try XCTUnwrap(try KlubbModellKorning.iAppen(berakning: .cpuOnly),
                              "Klubbmodell.mlmodelc saknas i appen (tools/hamta_klubbmodell.py i kompilera.yml)")
        XCTAssertEqual(k.beskrivning.modell, prov.modell)
        print("PROV: klubbmodell \(prov.modell), \(prov.bilder.count) ritade bilder, Core ML på simulatorns CPU")
        var varstaPx = 0.0, varstaK = 0.0, tider: [Double] = []
        for b in prov.bilder {
            let url = mapp.appending(path: b.fil) as CFURL
            let kalla = try XCTUnwrap(CGImageSourceCreateWithURL(url, nil))
            let bild = try XCTUnwrap(CGImageSourceCreateImageAtIndex(kalla, 0, nil))
            let t0 = Date()
            let det = try k.detektioner(bild, troskel: prov.konfidens / 2)
            tider.append(Date().timeIntervalSince(t0) * 1000)
            for r in b.detektioner {
                let mitt = (r.bbox[0] + r.bbox[2] / 2, r.bbox[1] + r.bbox[3] / 2)
                let bast = det.filter { $0.klass == r.klass }
                    .min { hypot($0.mitt.x - mitt.0, $0.mitt.y - mitt.1) < hypot($1.mitt.x - mitt.0, $1.mitt.y - mitt.1) }
                guard let d = bast else {
                    XCTFail("\(b.fil): Core ML saknar \(r.klass) (PyTorch \(r.konfidens))")
                    continue
                }
                let px = hypot(d.mitt.x - mitt.0, d.mitt.y - mitt.1)
                let dk = abs(d.konfidens - r.konfidens)
                varstaPx = max(varstaPx, px)
                varstaK = max(varstaK, dk)
                print(String(format: "PROV: klubbmodell %@ %@ PyTorch %.3f Core ML %.3f, mitten %.2f px", b.fil, r.klass,
                             r.konfidens, d.konfidens, px))
                XCTAssertLessThanOrEqual(px, Self.maxPx, "\(b.fil) \(r.klass)")
                XCTAssertLessThanOrEqual(dk, Self.maxKonfidens, "\(b.fil) \(r.klass)")
            }
        }
        let median = tider.sorted()[tider.count / 2]
        print(String(format: "PROV: klubbmodell störst %.2f px och %.3f i konfidens; %.0f ms per bild i median (simulatorn)",
                     varstaPx, varstaK, median))
    }
}
