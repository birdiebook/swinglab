// SKÄRMBILDERNA MOT REFERENSERNA (PLAN S4i, BESLUT B100, METOD MS40). Galleriet som resten
// av simulatorprovet ritar till /tmp/swinglab_prov/<namn>.png jämförs med referenserna i
// Prov/Referenser/<namn>.png, med swift-snapshot-testings bildjämförelse (MIT): varje punkt
// inom ΔE 2 (perceptualPrecision 0,98), i alla punkter (precision 1).
//
// Körs av kompilera.yml EFTER resten av provet, i en egen körning (-only-testing), så att
// alla bilder finns när den börjar; i huvudkörningen hoppas den över (-skip-testing).
// En ändrad skärm fäller provet, och referensen, den nya bilden och skillnaden ritas bredvid
// varandra till /tmp/swinglab_prov/skillnad/<namn>.png (på ci-resultat som
// resultat/<sha>.skillnad.<namn>.png). En bild utan referens fäller inte: den är ny och får
// sin referens nästa gång referenserna spelas in (kompilera med spela_in, i den låsta miljön).
//
// DATAN ÄR PÅHITTAD: bilderna är galleriets (SwingDemo, påhittade svingar), inga riktiga.

import XCTest
import UIKit
import SnapshotTesting

@MainActor
final class SwingLabProvReferenser: XCTestCase {

    static let galleri = "/tmp/swinglab_prov"
    static let skillnad = "/tmp/swinglab_prov/skillnad"
    /// Andelen punkter som måste stämma: alla, så att en ändrad siffra (≈0,04 % av en skärm) fäller.
    /// METOD MS40
    static let precision: Float = 1
    /// Hur nära en punkt måste vara: 1 − ΔE/100, alltså ΔE ≤ 2 (bibliotekets 98–99 %). METOD MS40
    static let perceptuell: Float = 0.98
    /// Bilder som inte jämförs, med skälet. Tom: galleriet är bytelikt mellan körningar (MS40).
    static let undantag: [String: String] = [:]

    static var referenser: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Referenser")
    }

    func testSkarmarnaMotReferenserna() throws {
        let fm = FileManager.default
        func pngNamn(_ mapp: String) -> Set<String> {
            Set(((try? fm.contentsOfDirectory(atPath: mapp)) ?? []).filter { $0.hasSuffix(".png") }.map { String($0.dropLast(4)) })
        }
        let bilder = pngNamn(Self.galleri)
        let refs = pngNamn(Self.referenser.path)
        guard !bilder.isEmpty else {
            print("REFERENS: RÖTT: galleriet saknas i \(Self.galleri) (resten av provet körs först)")
            return XCTFail("galleriet saknas")
        }
        try? fm.removeItem(atPath: Self.skillnad)
        try fm.createDirectory(atPath: Self.skillnad, withIntermediateDirectories: true)

        let diffing = Diffing<UIImage>.image(precision: Self.precision, perceptualPrecision: Self.perceptuell, scale: 1)
        var lika: [String] = [], andrade: [String] = [], nya: [String] = [], detaljer: [String] = []
        for namn in bilder.sorted() {
            if let varfor = Self.undantag[namn] {
                detaljer.append("undantag \(namn): \(varfor)")
                continue
            }
            guard refs.contains(namn) else {
                nya.append(namn)
                continue
            }
            let ny = try XCTUnwrap(UIImage(contentsOfFile: "\(Self.galleri)/\(namn).png"), "\(namn).png gick inte att läsa")
            let ref = try XCTUnwrap(UIImage(contentsOfFile: Self.referenser.appendingPathComponent("\(namn).png").path),
                                    "referensen \(namn).png gick inte att läsa")
            guard let fel = diffing.diffV2(ref, ny) else {
                lika.append(namn)
                continue
            }
            andrade.append(namn)
            var skillnadsbild: UIImage?
            for bilaga in fel.1 {
                if case .data(let data, name: let filnamn) = bilaga, filnamn == "difference.png" {
                    skillnadsbild = UIImage(data: data)
                }
            }
            // Var och hur mycket: punkterna där en kanal skiljer mer än 8 av 255, och rutan runt dem.
            var omfang = "storleken \(Int(ref.size.width))×\(Int(ref.size.height)) blev \(Int(ny.size.width))×\(Int(ny.size.height)) px"
            var ruta: CGRect?
            if let a = Bildpunkter(ref), let b = Bildpunkter(ny), let s = a.skillnad(mot: b) {
                ruta = s.ruta
                let andel = Double(s.antal) / Double(a.bredd * a.hojd) * 100
                omfang = String(format: "%.3f %% av punkterna", andel)
                if let r = s.ruta {
                    omfang += " i (\(Int(r.minX)), \(Int(r.minY)))–(\(Int(r.maxX)), \(Int(r.maxY))) px av \(a.bredd)×\(a.hojd)"
                }
            }
            let sida = Self.sidaVidSida(referens: ref, ny: ny, skillnad: skillnadsbild, ruta: ruta)
            try XCTUnwrap(sida.pngData()).write(to: URL(fileURLWithPath: "\(Self.skillnad)/\(namn).png"))
            detaljer.append("ändrad \(namn): \(omfang); \(fel.0.replacingOccurrences(of: "\n", with: " · "))")
        }
        let borta = refs.subtracting(bilder).sorted()
        let jamforda = lika.count + andrade.count

        // Domen först (kompilera.yml lägger raderna i sammanfattningen på ci-resultat).
        if !andrade.isEmpty {
            print("REFERENS: RÖTT: \(andrade.count) av \(jamforda) skärmar ändrade mot referensen: \(Self.lista(andrade))")
            print("REFERENS:   bilderna: resultat/<sha>.skillnad.<namn>.png (referensen, den nya och skillnaden)")
            print("REFERENS:   avsiktligt? spela in: kompilera med spela_in (BESLUT B100)")
        } else if jamforda > 0 {
            print("REFERENS: GRÖNT: \(lika.count) av \(jamforda) skärmar lika referensen (ΔE ≤ 2 i varje punkt)")
        } else {
            print("REFERENS: GULT: ingen skärm jämförd, referenserna saknas (spelas in med spela_in)")
        }
        if !nya.isEmpty {
            print("REFERENS: GULT: \(nya.count) nya utan referens (spelas in med spela_in): \(Self.lista(nya))")
        }
        if !borta.isEmpty {
            print("REFERENS: GULT: \(borta.count) referenser utan bild (skärmen ritades inte): \(Self.lista(borta))")
        }
        for d in detaljer { print("REFERENS:   \(d)") }
        XCTAssertTrue(andrade.isEmpty, "skärmar ändrade mot referensen: \(andrade.joined(separator: ", "))")
    }

    /// Namnen i en rad, högst 15.
    static func lista(_ namn: [String]) -> String {
        namn.count <= 15 ? namn.joined(separator: ", ")
                         : namn.prefix(15).joined(separator: ", ") + " och \(namn.count - 15) till"
    }

    /// Referensen, den nya bilden och skillnaden (bibliotekets, ljusast där det skiljer mest)
    /// bredvid varandra i full upplösning, med en röd ram runt det som ändrats.
    static func sidaVidSida(referens: UIImage, ny: UIImage, skillnad: UIImage?, ruta: CGRect?) -> UIImage {
        let lucka: CGFloat = 24, rubrik: CGFloat = 44
        let paneler: [(String, UIImage?)] = [("referens", referens), ("ny", ny), ("skillnad", skillnad)]
        let w = max(referens.size.width, ny.size.width), h = max(referens.size.height, ny.size.height)
        let storlek = CGSize(width: 3 * w + 4 * lucka, height: rubrik + h + lucka)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: storlek, format: format).image { ctx in
            UIColor(white: 0.22, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: storlek))
            let text: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 24, weight: .semibold),
                                                       .foregroundColor: UIColor.white]
            for (i, panel) in paneler.enumerated() {
                let x = lucka + CGFloat(i) * (w + lucka)
                (panel.0 as NSString).draw(at: CGPoint(x: x, y: 8), withAttributes: text)
                guard let bild = panel.1 else { continue }
                bild.draw(in: CGRect(x: x, y: rubrik, width: bild.size.width, height: bild.size.height))
                if let ruta, i < 2 {
                    let ram = UIBezierPath(rect: ruta.offsetBy(dx: x, dy: rubrik).insetBy(dx: -6, dy: -6))
                    ram.lineWidth = 4
                    UIColor.red.setStroke()
                    ram.stroke()
                }
            }
        }
    }
}

/// Punkterna i en bild som RGBA i sRGB, 8 bitar per kanal, rad 0 överst (som `provaFormspraket`).
/// Delas av referensernas jämförelse (rutan runt det ändrade) och matrisen (ljust mot mörkt).
struct Bildpunkter {
    let bredd: Int
    let hojd: Int
    let data: [UInt8]

    init?(_ bild: UIImage) {
        guard let cg = bild.cgImage, let rum = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let w = cg.width, h = cg.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let ritat = px.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: rum, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ritat else { return nil }
        bredd = w
        hojd = h
        data = px
    }

    /// Punkterna där någon kanal skiljer mer än `grans` av 255, och rutan runt dem (px, rad 0
    /// överst); nil när storlekarna skiljer. METOD MS40
    func skillnad(mot andra: Bildpunkter, grans: Int = 8) -> (antal: Int, ruta: CGRect?)? {
        guard bredd == andra.bredd, hojd == andra.hojd else { return nil }
        var antal = 0, x0 = Int.max, y0 = Int.max, x1 = -1, y1 = -1
        let n = bredd * hojd, w = bredd
        data.withUnsafeBufferPointer { a in
            andra.data.withUnsafeBufferPointer { b in
                var i = 0
                while i < n {
                    let j = i * 4
                    var d = 0
                    for k in 0..<4 {
                        let ak = Int(a[j + k]), bk = Int(b[j + k])
                        let dk = ak > bk ? ak - bk : bk - ak
                        if dk > d { d = dk }
                    }
                    if d > grans {
                        antal += 1
                        let x = i % w, y = i / w
                        if x < x0 { x0 = x }
                        if x > x1 { x1 = x }
                        if y < y0 { y0 = y }
                        if y > y1 { y1 = y }
                    }
                    i += 1
                }
            }
        }
        let ruta: CGRect? = antal > 0 ? CGRect(x: x0, y: y0, width: x1 - x0 + 1, height: y1 - y0 + 1) : nil
        return (antal, ruta)
    }
}
