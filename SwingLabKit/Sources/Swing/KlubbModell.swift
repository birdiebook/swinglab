import Foundation

// Klubbmodellen på telefonen (PLAN S7-2, BESLUT B96, METOD MF7): beskrivningen
// `swinglab-klubba-coreml/1` (docs/FORMAT.md), indatan ur en bild och räkningen från modellens råa
// utdata till rutor. Samma räkning som `ur_utdata` i tools/pc/formarkare.py (BESLUT B12). Core ML
// körs i appen (App/KlubbModell.swift); här finns bara det som går att pröva utan Mac.

/// Beskrivningen som `formarkare.py coreml` skriver bredvid Core ML-paketet.
public struct KlubbModellBeskrivning: Decodable, Equatable, Sendable {
    public static let format = "swinglab-klubba-coreml/1"

    public struct Indata: Decodable, Equatable, Sendable {
        /// Core ML-namnet på indatan, 1 × 3 × sida × sida i RGB.
        public var namn: String
        public var form: [Int]
        /// Pixelvärdet gånger skalan, minus medel, delat med std, per färg.
        public var skala: Double
        public var medel: [Double]
        public var std: [Double]
    }

    /// Core ML-namnen på utdatan: rutorna (frågor × 4, cx, cy, b, h normerade 0–1) och logits.
    public struct Utdata: Decodable, Equatable, Sendable {
        public var rutor: String
        public var logits: String
    }

    /// Ett dataset modellen tränats på, för namnangivelsen (CC BY, B92).
    public struct Kalla: Decodable, Equatable, Sendable {
        public var namn: String
        public var licens: String
        public var kalla: String
    }

    public var format: String
    public var modell: String
    public var indata: Indata
    public var utdata: Utdata
    /// Klasserna i logitordning: logit i är `klasser[i]`, resten används inte.
    public var klasser: [String]
    public var data: [Kalla]

    public var sida: Int { indata.form[3] }

    public enum Fel: Error, Equatable {
        case format(String)
    }

    public static func las(_ json: Data) throws -> KlubbModellBeskrivning {
        let b: KlubbModellBeskrivning
        do {
            b = try JSONDecoder().decode(KlubbModellBeskrivning.self, from: json)
        } catch {
            throw Fel.format("beskrivningen går inte att läsa")
        }
        guard b.format == format else { throw Fel.format("format") }
        let f = b.indata.form
        guard f.count == 4, f[0] == 1, f[1] == 3, f[2] == f[3], f[2] > 0 else { throw Fel.format("indata.form") }
        guard b.indata.medel.count == 3, b.indata.std.count == 3, b.indata.std.allSatisfy({ $0 > 0 }) else {
            throw Fel.format("indata.medel, indata.std")
        }
        guard !b.klasser.isEmpty else { throw Fel.format("klasser") }
        return b
    }
}

/// En ruta ur modellen, i bildens px.
public struct KlubbDetektion: Equatable, Sendable {
    public var klass: String
    public var konfidens: Double
    /// Frågans nummer bland modellens frågor.
    public var fraga: Int
    /// `[x, y, b, h]` i px.
    public var bbox: [Double]

    public init(klass: String, konfidens: Double, fraga: Int, bbox: [Double]) {
        self.klass = klass
        self.konfidens = konfidens
        self.fraga = fraga
        self.bbox = bbox
    }

    public var mitt: (x: Double, y: Double) { (bbox[0] + bbox[2] / 2, bbox[1] + bbox[3] / 2) }
}

public enum KlubbModell {
    /// En RGBA-bild (sida × sida, rad för rad, 4 byte per pixel) som modellens indata:
    /// färg för färg (CHW), varje värde `(byte × skala − medel) / std`. METOD MF7
    public static func indata(rgba: [UInt8], sida: Int, beskrivning b: KlubbModellBeskrivning) -> [Float] {
        let n = sida * sida
        precondition(rgba.count == n * 4, "rgba ska vara sida × sida × 4")
        var ut = [Float](repeating: 0, count: 3 * n)
        for c in 0..<3 {
            let s = b.indata.skala / b.indata.std[c]
            let m = b.indata.medel[c] / b.indata.std[c]
            for i in 0..<n {
                ut[c * n + i] = Float(Double(rgba[i * 4 + c]) * s - m)
            }
        }
        return ut
    }

    /// Modellens råa utdata som rutor i bildens px: varje fråga och klass vars sigmoid når
    /// `troskel`, säkrast först (sedan fråga och klass). Samma som `ur_utdata` i
    /// tools/pc/formarkare.py, utan avrundningen. METOD MF7
    public static func detektioner(rutor: [Float], logits: [Float], klasser: [String], troskel: Double,
                                   bredd: Double, hojd: Double) -> [KlubbDetektion] {
        let fragor = rutor.count / 4
        guard fragor > 0, logits.count % fragor == 0 else { return [] }
        let perFraga = logits.count / fragor
        let k = min(klasser.count, perFraga)
        var ut: [KlubbDetektion] = []
        for q in 0..<fragor {
            for c in 0..<k {
                let p = 1 / (1 + exp(-Double(logits[q * perFraga + c])))
                guard p >= troskel else { continue }
                let cx = Double(rutor[q * 4]), cy = Double(rutor[q * 4 + 1])
                let b = Double(rutor[q * 4 + 2]), h = Double(rutor[q * 4 + 3])
                ut.append(KlubbDetektion(klass: klasser[c], konfidens: p, fraga: q,
                                         bbox: [(cx - b / 2) * bredd, (cy - h / 2) * hojd, b * bredd, h * hojd]))
            }
        }
        return ut.sorted {
            ($0.konfidens, $1.fraga, $1.klass) > ($1.konfidens, $0.fraga, $0.klass)
        }
    }
}
