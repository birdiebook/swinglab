import Foundation
import XCTest
@testable import Swing

// S7-2: klubbmodellens beskrivning, indata och utdata (BESLUT B96, METOD MF7). Samma fall som
// test_utdatan_som_rutor i tools/tests/test_formarkare.py (BESLUT B12).

final class KlubbModellTests: XCTestCase {
    static let beskrivning = """
    {"format": "swinglab-klubba-coreml/1", "modell": "klubba-prov-fp16", "precision": "float16",
     "data": [{"namn": "golf-club-tracking", "licens": "CC BY 4.0", "kalla": "https://x"}],
     "indata": {"namn": "tensors", "form": [1, 3, 2, 2], "fargordning": "RGB", "skala": 0.00392156862745098,
                "medel": [0.485, 0.456, 0.406], "std": [0.229, 0.224, 0.225]},
     "utdata": {"rutor": "concat_2", "logits": "linear_112"}, "rutor": "cx, cy, b, h normerade 0-1",
     "klasser": ["klubba", "klubbhuvud", "hander"]}
    """

    func testUtdatanSomRutor() {
        // Två frågor, tre klasser och en oanvänd logit.
        let rutor: [Float] = [0.5, 0.25, 0.1, 0.2, 0.2, 0.8, 0.4, 0.1]
        let logits: [Float] = [2.0, -1.0, 0.0, 9.0, -3.0, 1.0, -0.5, 9.0]
        let d = KlubbModell.detektioner(rutor: rutor, logits: logits, klasser: ["klubba", "klubbhuvud", "hander"],
                                        troskel: 0.3, bredd: 512, hojd: 256)
        XCTAssertEqual(d.map { "\($0.klass) \($0.fraga)" }, ["klubba 0", "klubbhuvud 1", "hander 0", "hander 1"])
        XCTAssertEqual(d[0].konfidens, 0.8808, accuracy: 1e-4)
        XCTAssertEqual(d[3].konfidens, 0.3775, accuracy: 1e-4)
        for (a, b) in zip(d[0].bbox, [230.4, 38.4, 51.2, 51.2]) {
            XCTAssertEqual(a, b, accuracy: 1e-3)
        }
        XCTAssertEqual(d[0].mitt.x, 256, accuracy: 1e-3)
    }

    func testBeskrivningenOchIndatan() throws {
        let b = try KlubbModellBeskrivning.las(Data(Self.beskrivning.utf8))
        XCTAssertEqual(b.sida, 2)
        XCTAssertEqual(b.utdata.logits, "linear_112")
        XCTAssertEqual(b.data.first?.licens, "CC BY 4.0")
        // 2 × 2 pixlar, RGBA: röd, grön, blå, vit.
        let rgba: [UInt8] = [255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255]
        let x = KlubbModell.indata(rgba: rgba, sida: 2, beskrivning: b)
        XCTAssertEqual(x.count, 12)
        XCTAssertEqual(Double(x[0]), (1 - 0.485) / 0.229, accuracy: 1e-5)     // R för den röda
        XCTAssertEqual(Double(x[1]), -0.485 / 0.229, accuracy: 1e-5)           // R för den gröna
        XCTAssertEqual(Double(x[4 + 1]), (1 - 0.456) / 0.224, accuracy: 1e-5) // G för den gröna
        XCTAssertEqual(Double(x[8 + 3]), (1 - 0.406) / 0.225, accuracy: 1e-5) // B för den vita
    }

    func testTrasigBeskrivningVagras() {
        let fel = Self.beskrivning.replacingOccurrences(of: "[1, 3, 2, 2]", with: "[1, 3, 2]")
        XCTAssertThrowsError(try KlubbModellBeskrivning.las(Data(fel.utf8))) {
            XCTAssertEqual($0 as? KlubbModellBeskrivning.Fel, .format("indata.form"))
        }
        let annat = Self.beskrivning.replacingOccurrences(of: "coreml/1", with: "coreml/2")
        XCTAssertThrowsError(try KlubbModellBeskrivning.las(Data(annat.utf8)))
    }
}
