import CoreImage
import CoreMedia
import CoreVideo
import Foundation
import ImageIO
import Observation
import UIKit
import Capture

// Den andra telefonens bild live (PLAN S2k, BESLUT B90, METOD MS35). Följaren: kamerans rutor i
// förhandsbildens storlek (en egen videoutgång, `Camera`), en av dem i takten blir en JPEG om 360 ×
// 640 och skickas över PhoneLink, högst en i flykt. Den styrande: bilden avkodas utanför
// huvudtråden och visas i rutan i hörnet. Inget sparas: bilden finns bara i minnet tills nästa
// kommer. När, hur ofta och mottrycket står i SwingLabKit (`Forhandsbild.swift`).

/// Följarens källa: tar emot kamerans rutor på kamerans kö och lämnar en bild i takten när den
/// förra är kvitterad (`ForhandsSandare`). Takten sätts av inspelningens skärm (`Forhandstakt`).
final class ForhandsKalla: @unchecked Sendable {
    private let las = NSLock()
    private var sandare = ForhandsSandare()
    private var hz = 0.0
    private let ci = CIContext(options: [.cacheIntermediates: false])
    /// En färdig bild (på kamerans kö): skickas av inspelningen, eller släpps (`slapp`).
    var onBild: (@Sendable (LinkPreview) -> Void)?

    /// Takten, bilder/s; noll släpper bilden i flykt.
    func stall(hz: Double) {
        las.lock()
        self.hz = hz
        if hz <= 0 { sandare.nollstall() }
        las.unlock()
    }

    func kvitterad(_ n: Int) {
        las.lock()
        sandare.kvitterad(n)
        las.unlock()
    }

    func slapp(_ n: Int) {
        las.lock()
        sandare.slapp(n)
        las.unlock()
    }

    /// En ruta ur kameran (kamerans kö). `tid`: när rutan togs, värdklockan.
    func ruta(_ pb: CVPixelBuffer, tid: Double) {
        las.lock()
        let n = sandare.ta(nu: LinkClock.now(), hz: hz)
        las.unlock()
        guard let n else { return }
        // Kamerans buffert ligger på sidan; telefonen står (som filens rotation 90°, `Camera`).
        guard let k = ForhandsKodare.jpeg(CIImage(cvPixelBuffer: pb).oriented(.right), ci: ci) else {
            slapp(n)
            return
        }
        onBild?(LinkPreview(n: n, t: tid, w: k.w, h: k.h, jpeg: k.jpeg))
    }
}

/// JPEG-kodningen: bilden skalas till kortsidan 360 px och kodas med kvaliteten 0,5 (MS35).
/// Samma kod i provet, på en påhittad bild.
enum ForhandsKodare {
    static func jpeg(_ bild: CIImage, ci: CIContext) -> (jpeg: Data, w: Int, h: Int)? {
        let e = bild.extent
        guard e.width.isFinite, e.height.isFinite, e.width >= 1, e.height >= 1 else { return nil }
        let (w, h) = LinkPreview.storlek(bredd: Int(e.width.rounded()), hojd: Int(e.height.rounded()))
        let sx = CGFloat(w) / e.width, sy = CGFloat(h) / e.height
        let skalad = bild.transformed(by: CGAffineTransform(translationX: -e.minX, y: -e.minY))
            .transformed(by: CGAffineTransform(scaleX: sx, y: sy))
            .cropped(to: CGRect(x: 0, y: 0, width: w, height: h))
        guard let rum = CGColorSpace(name: CGColorSpace.sRGB),
              let d = ci.jpegRepresentation(of: skalad, colorSpace: rum, options: [
                  CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String):
                      LinkPreview.kvalitet,
              ]),
              d.count <= LinkPreview.maxBytes else { return nil }
        return (d, w, h)
    }
}

/// Den styrandes bild av den andra telefonen: senaste bilden, avkodad. Egen klass, så att bara
/// rutan ritas om när en ny bild kommer, inte hela inspelningens skärm.
@MainActor
@Observable
final class AndraBild {
    private(set) var bild: UIImage?
    /// Avkodningarnas ordning: en som blir klar efter en senare visas inte.
    @ObservationIgnored private var lopnummer = 0
    @ObservationIgnored private var visad = 0
    /// Den styrande spelar in (serie eller ljusprov): rutan syns inte, så ingen bild avkodas och
    /// inspelningen får telefonens kraft (MS35).
    @ObservationIgnored var pausad = false

    init(bild: UIImage? = nil) {
        self.bild = bild
    }

    /// En ny bild: avkodas utanför huvudtråden; en äldre som blir klar efter en nyare visas inte.
    func ta(_ p: LinkPreview) {
        guard !pausad else { return }
        lopnummer += 1
        let data = p.jpeg, n = lopnummer
        Task.detached(priority: .userInitiated) {
            let img = UIImage(data: data)?.preparingForDisplay()
            await MainActor.run { [weak self] in
                guard let self, let img, n > self.visad else { return }
                self.visad = n
                self.bild = img
            }
        }
    }

    /// Kopplingen föll: ingen bild.
    func tom() {
        visad = lopnummer
        if bild != nil { bild = nil }
    }
}
