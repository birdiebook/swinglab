// 3D PÅ TELEFONEN I SIMULATORN (S6c-1, BESLUT B48, METOD M50). SwingLabKit:s TreD prövas
// på Linux i Actions; här byggs och körs samma kod på Darwin (JSON-läsaren, String(format:)
// och libm), på ett PÅHITTAT pass ur tools/tests/fixturer/tre_d/ (CLAUDE.md, Dataregeln),
// och jämförs med Pythons tal. Raderna "PROV: TreD …" hamnar i kompilera.txt.

import XCTest
import Capture
import TreD

final class SwingLabProvTreD: XCTestCase {
    static let mapp = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("tools/tests/fixturer/tre_d")

    func las(_ namn: String) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(contentsOf: Self.mapp.appendingPathComponent("\(namn).json")))
            as! [String: Any]
    }

    /// Kompakta leder (int32-tider i 1e-4 s, int16-leder i 0,1 px och 0,001) → JointSeries.
    func leder(_ k: [String: Any]) -> JointSeries {
        let t = Data(base64Encoded: k["t"] as! String)!, j = Data(base64Encoded: k["j"] as! String)!
        let tider: [Int32] = t.withUnsafeBytes { r in
            (0..<(t.count / 4)).map { Int32(littleEndian: r.loadUnaligned(fromByteOffset: $0 * 4, as: Int32.self)) }
        }
        let tal: [Int16] = j.withUnsafeBytes { r in
            (0..<(j.count / 2)).map { Int16(littleEndian: r.loadUnaligned(fromByteOffset: $0 * 2, as: Int16.self)) }
        }
        let frames = tider.indices.map { i in
            PoseFrame(t: Double(tider[i]) / 1e4, pts: 0, joints: (0..<13).map { m -> PoseJoint? in
                let b = (i * 13 + m) * 3
                return tal[b + 2] == 0 ? nil : PoseJoint(x: Double(tal[b]) / 10, y: Double(tal[b + 1]) / 10,
                                                         c: Double(tal[b + 2]) / 1000)
            }, confidence: 0.9)
        }
        return JointSeries(source: "pahittad-3d-r1", width: (k["width"] as! NSNumber).intValue,
                           height: (k["height"] as! NSNumber).intValue, frames: frames)
    }

    func testTreDSomPython() throws {
        let fx = try las("lodlinje")
        let indata = try las("indata/\(fx["indata"] as! String)")
        let variant = (fx["varianter"] as! [String: Any])["grund"] as! [String: Any]
        let andra = variant["andra"] as! [String: Any]
        var paket: [TreDPaket] = []
        for vy in ["dtl", "fo"] {
            var p = (indata["paket"] as! [String: Any])[vy] as! [String: Any]
            for (k, v) in (andra[vy] as? [String: Any]) ?? [:] { p[k] = v }
            let lederna = (p["leder"] as! [String: Any]).mapValues { leder($0 as! [String: Any]) }
            paket.append(try TreDPaket.las(manifest: Data((p["manifest"] as! String).utf8), lederna: lederna,
                                           filer: Set(p["filer"] as! [String]),
                                           par: (p["par"] as? String).map { Data($0.utf8) }, enhet: nil))
        }
        var faser: [String: Faser2D] = [:]
        for r in indata["rader"] as! [[String: Any]] {
            faser["\(r["vy"] as! String)/\(r["id"] as! String)"] =
                Faser2D(start: (r["start"] as? NSNumber)?.doubleValue, topp: (r["topp"] as? NSNumber)?.doubleValue)
        }
        let start = Date()
        let r = try TvaKameror.analysera(dtl: paket[0], fo: paket[1], faser: faser)
        let tid = Date().timeIntervalSince(start)
        let py = variant["python"] as! [String: Any]
        let pk = (py["kalibrering"] as! [[String: Any]])[0]
        XCTAssertEqual(r.kalibrering[0].lodlinje, pk["lodlinje"] as? String)
        XCTAssertEqual(r.kalibrering[0].sampsonPx!, (pk["sampson_px"] as! NSNumber).doubleValue, accuracy: 0.01 + 1e-9)
        XCTAssertEqual(r.kalibrering[0].vinkelMellanKamerorna!, (pk["vinkel_mellan_kamerorna"] as! NSNumber).doubleValue,
                       accuracy: 0.1 + 1e-9)
        let pslag = py["slag"] as! [[String: Any]]
        XCTAssertEqual(r.slag.count, pslag.count)
        var storst = 0.0
        for (s, q) in zip(r.slag, pslag) {
            for (m, v) in (q["matt"] as? [String: Any]) ?? [:] {
                let d = abs((s.matt?[m] ?? .nan) - (v as! NSNumber).doubleValue)
                storst = max(storst, d.isNaN ? .infinity : d)
            }
        }
        print("PROV: TreD \(r.parning.par) slag på \(String(format: "%.2f", tid)) s i simulatorn, " +
              "största avvikelse mot Python \(storst)°")
        XCTAssertLessThanOrEqual(storst, 1e-6)                          // METOD M50
        XCTAssertNoThrow(try JSONEncoder().encode(r))
    }
}
