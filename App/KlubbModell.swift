import CoreGraphics
import CoreML
import Foundation
import Swing

/// Klubbmodellen i appen (PLAN S7-2, BESLUT B96, METOD MF7): Core ML-paketet som bygget hämtar ur
/// modellens release (tools/hamta_klubbmodell.py) och kompilerar in som `Klubbmodell.mlmodelc`,
/// med beskrivningen `Klubbmodell.json` bredvid. Ett bygge utan modell (utan hämtningen) ger nil.
/// Bilden görs om till indata och utdatan till rutor i SwingLabKit (`KlubbModell`); här finns bara
/// Core ML. Ett fel från Core ML kastas vidare.
final class KlubbModellKorning {
    /// Modellen saknar en utdata som beskrivningen namnger (fel modell till beskrivningen).
    enum KorFel: Error {
        case utdata
    }

    let beskrivning: KlubbModellBeskrivning
    private let modell: MLModel

    init(modell: MLModel, beskrivning: KlubbModellBeskrivning) {
        self.modell = modell
        self.beskrivning = beskrivning
    }

    /// Modellen i appens bundle, eller nil när bygget saknar den. `berakning` är var Core ML får
    /// räkna; standard är allt (Neural Engine på telefonen).
    static func iAppen(berakning: MLComputeUnits = .all, bundle: Bundle = .main) throws -> KlubbModellKorning? {
        guard let url = bundle.url(forResource: "Klubbmodell", withExtension: "mlmodelc"),
              let json = bundle.url(forResource: "Klubbmodell", withExtension: "json") else { return nil }
        let b = try KlubbModellBeskrivning.las(Data(contentsOf: json))
        let konfig = MLModelConfiguration()
        konfig.computeUnits = berakning
        return KlubbModellKorning(modell: try MLModel(contentsOf: url, configuration: konfig), beskrivning: b)
    }

    /// Rutorna i en bild, i bildens px. Bilden skalas till modellens sida (sRGB), som PC:ns utsnitt
    /// skalas i formarkare.py. METOD MF7
    func detektioner(_ bild: CGImage, troskel: Double) throws -> [KlubbDetektion] {
        let sida = beskrivning.sida
        let rgba = Self.rgba(bild, sida: sida)
        let x = KlubbModell.indata(rgba: rgba, sida: sida, beskrivning: beskrivning)
        let arr = try MLMultiArray(shape: [1, 3, NSNumber(value: sida), NSNumber(value: sida)], dataType: .float32)
        x.withUnsafeBufferPointer { kalla in
            arr.withUnsafeMutableBytes { mal, _ in
                mal.copyMemory(from: UnsafeRawBufferPointer(kalla))
            }
        }
        let ut = try modell.prediction(from: MLDictionaryFeatureProvider(
            dictionary: [beskrivning.indata.namn: MLFeatureValue(multiArray: arr)]))
        guard let rutor = ut.featureValue(for: beskrivning.utdata.rutor)?.multiArrayValue,
              let logits = ut.featureValue(for: beskrivning.utdata.logits)?.multiArrayValue else { throw KorFel.utdata }
        return KlubbModell.detektioner(rutor: Self.floats(rutor), logits: Self.floats(logits),
                                       klasser: beskrivning.klasser, troskel: troskel,
                                       bredd: Double(bild.width), hojd: Double(bild.height))
    }

    /// Bildens pixlar som RGBA i sida × sida. En bild som redan har sidan och 8 bitars RGB(A)
    /// läses som den är (simulatorprovets PNG, så att provet mäter modellen och inte skalningen);
    /// annars ritas den om i sRGB.
    static func rgba(_ bild: CGImage, sida: Int) -> [UInt8] {
        let n = sida * sida
        if bild.width == sida, bild.height == sida, bild.bitsPerComponent == 8,
           bild.bitsPerPixel == 24 || bild.bitsPerPixel == 32,
           [.none, .noneSkipLast, .last, .premultipliedLast].contains(bild.alphaInfo),
           bild.byteOrderInfo == .orderDefault || bild.byteOrderInfo == .order32Big,
           let data = bild.dataProvider?.data, let p = CFDataGetBytePtr(data) {
            let steg = bild.bitsPerPixel / 8
            var ut = [UInt8](repeating: 255, count: n * 4)
            for y in 0..<sida {
                for x in 0..<sida {
                    let k = y * bild.bytesPerRow + x * steg
                    let i = (y * sida + x) * 4
                    ut[i] = p[k]; ut[i + 1] = p[k + 1]; ut[i + 2] = p[k + 2]
                }
            }
            return ut
        }
        var ut = [UInt8](repeating: 0, count: n * 4)
        let rum = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        ut.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: sida, height: sida, bitsPerComponent: 8,
                                      bytesPerRow: sida * 4, space: rum,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return }
            ctx.interpolationQuality = .high
            ctx.draw(bild, in: CGRect(x: 0, y: 0, width: sida, height: sida))
        }
        return ut
    }

    static func floats(_ a: MLMultiArray) -> [Float] {
        let n = a.count
        switch a.dataType {
        case .float32:
            return a.withUnsafeBufferPointer(ofType: Float.self) { Array($0.prefix(n)) }
        default:
            return (0..<n).map { a[$0].floatValue }
        }
    }
}
