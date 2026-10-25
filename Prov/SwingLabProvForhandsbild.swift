// SIMULATORPROVET FÖR DEN ANDRA TELEFONENS BILD (PLAN S2k, BESLUT B90, METOD MS35). Två PhoneLink i
// samma process över loopback, som SwingLabProvLink: följarens källa (`ForhandsKalla`) får en
// påhittad kamerabuffert 240 gånger i sekunden, kodar en JPEG i takten med appens kod och skickar
// den; den styrande kvitterar, avkodar och visar den. Provet mäter bildens storlek, kodningens tid,
// takten och fördröjningen, och att högst en bild är i flykt. Sedan rutan i hörnet och den stora
// bilden ritade till PNG.
//
// Kameran (den egna videoutgången bredvid filen i 240 bilder/s) och Bonjour över AWDL finns inte i
// simulatorn: de prövas på telefonerna (PLAN S2k, Klart när).
//
// BILDEN ÄR PÅHITTAD: en grå scen med en matta, en boll och en pinne, ingen person.
// PROV-raderna i loggen samlas i resultat/<sha>.kompilera.txt.

import XCTest
import CoreImage
import Network
import SwiftUI
import UIKit
import Swing
import Capture
@testable import SwingLab

/// Den påhittade scenen och kamerans buffert.
enum ProvBild {
    static let bredd = 1080
    static let hojd = 1920

    /// Scenen stående, i gråskala: himmel, mark, en matta, en boll, en pinne och en vit ruta uppe till
    /// vänster som visar att bilden står rätt.
    static func scen() -> CGImage {
        let cs = CGColorSpaceCreateDeviceGray()
        let ctx = CGContext(data: nil, width: bredd, height: hojd, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                            bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        let mark = CGFloat(hojd) * 0.25
        let himmel = CGGradient(colorsSpace: cs, colors: [CGColor(gray: 0.74, alpha: 1), CGColor(gray: 0.5, alpha: 1)] as CFArray,
                                locations: [0, 1])!
        ctx.drawLinearGradient(himmel, start: CGPoint(x: 0, y: CGFloat(hojd)), end: CGPoint(x: 0, y: mark), options: [])
        ctx.setFillColor(gray: 0.3, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(bredd), height: mark))
        ctx.setFillColor(gray: 0.42, alpha: 1)
        ctx.fill(CGRect(x: 240, y: 170, width: 600, height: 230))
        ctx.setFillColor(gray: 0.1, alpha: 1)
        ctx.fill(CGRect(x: 760, y: 300, width: 14, height: 900))
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fillEllipse(in: CGRect(x: 500, y: 270, width: 44, height: 44))
        ctx.fill(CGRect(x: 60, y: CGFloat(hojd) - 220, width: 160, height: 160))
        return ctx.makeImage()!
    }

    /// Kamerans buffert som den kommer ur utgången: på sidan (1920 × 1080), som appen vrider rätt.
    static func buffert(_ ci: CIContext) throws -> CVPixelBuffer {
        var pb: CVPixelBuffer?
        let attr = [kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary] as CFDictionary
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, hojd, bredd, kCVPixelFormatType_32BGRA, attr, &pb),
                       kCVReturnSuccess)
        let b = try XCTUnwrap(pb)
        var bild = CIImage(cgImage: scen()).oriented(.left)
        bild = bild.transformed(by: CGAffineTransform(translationX: -bild.extent.minX, y: -bild.extent.minY))
        ci.render(bild, to: b)
        return b
    }

    /// Bilden som den styrande får: scenen kodad med appens kod och avkodad.
    static func mottagen() throws -> UIImage {
        let k = try XCTUnwrap(ForhandsKodare.jpeg(CIImage(cgImage: scen()), ci: CIContext()))
        return try XCTUnwrap(UIImage(data: k.jpeg))
    }
}

@MainActor
final class SwingLabProvForhandsbild: XCTestCase {
    static let ut = "/tmp/swinglab_prov"

    /// Räknarna från följarens sida (en referens: källans block är `@Sendable`).
    final class Logg: @unchecked Sendable {
        var skickade = 0
        var kvitterade = 0
        var iFlyktMax = 0
        var bytes: [Int] = []
        var storlek: (w: Int, h: Int)?
    }

    /// Bilden från Follow till Lead över loopback: takten, mottrycket, fördröjningen, pausen under
    /// inspelningen och tappet. METOD MS35
    func testBildenFranFoljarenTillDenStyrande() throws {
        let styr = PhoneLink(role: .lead, view: .dtl, bonjour: false)
        styr.start()
        defer { styr.stop() }
        let port = try XCTUnwrap(väntaPå(10) { styr.port }, "lyssnaren fick ingen port")
        let nwPort = try XCTUnwrap(NWEndpoint.Port(rawValue: port))
        let folj = PhoneLink(role: .follow, view: .fo, endpoint: .hostPort(host: "127.0.0.1", port: nwPort),
                             bonjour: false)
        let kalla = ForhandsKalla()
        let logg = Logg()
        kalla.onBild = { p in
            // Källan anropas här på huvudtråden (provet driver den), i appen på kamerans kö.
            MainActor.assumeIsolated {
                guard folj.sendPreview(p) else { return kalla.slapp(p.n) }
                logg.skickade += 1
                logg.bytes.append(p.jpeg.count)
                logg.storlek = (p.w, p.h)
                logg.iFlyktMax = max(logg.iFlyktMax, logg.skickade - logg.kvitterade)
            }
        }
        folj.onPreviewAck = { n in
            logg.kvitterade += 1
            kalla.kvitterad(n)
        }
        folj.start()
        defer { folj.stop() }

        XCTAssertTrue(vänta(15) { styr.peers.first?.connected == true && folj.kanForhandsbild }, "ingen anslutning")
        // Klockan ur pingen: fördröjningen räknas med den.
        XCTAssertTrue(vänta(10) { styr.sampleCount >= LinkLeader.burst }, "pingen kom inte fram")

        // Kodningen: storleken och tiden för en bild.
        let ci = CIContext(options: [.cacheIntermediates: false])
        let pb = try ProvBild.buffert(ci)
        var tider: [Double] = []
        for _ in 0..<20 {
            let t = Date()
            _ = try XCTUnwrap(ForhandsKodare.jpeg(CIImage(cvPixelBuffer: pb).oriented(.right), ci: ci))
            tider.append(Date().timeIntervalSince(t))
        }
        tider.sort()
        print(String(format: "PROV: förhandsbild kodning median %.1f ms, max %.1f ms (simulatorn)",
                     tider[tider.count / 2] * 1000, (tider.last ?? 0) * 1000))

        // 240 rutor i sekunden i 4 s: takten 12 och högst en i flykt.
        kalla.stall(hz: Forhandstakt.hz(kanSkicka: folj.kanForhandsbild, inspelar: false, tryck: .nominal))
        rutor(kalla, pb, sekunder: 4)
        XCTAssertTrue(vänta(3) { styr.andraBild.bild != nil }, "bilden kom inte fram")
        let nu = LinkClock.now()
        XCTAssertTrue(styr.forhandsbildVisas(nu: nu, inspelar: false))
        XCTAssertFalse(styr.forhandsbildVisas(nu: nu, inspelar: true), "rutan visas under den styrandes serie")
        let m = styr.forhandsbildMatt(nu: nu)
        let d = try XCTUnwrap(m.fordrojning, "ingen fördröjning: klockan saknas")
        let medel = Double(logg.bytes.reduce(0, +)) / Double(max(1, logg.bytes.count))
        print(String(format: "PROV: förhandsbild %ld skickade på 4 s, %.1f bilder/s hos Lead, fördröjning median %.0f ms, "
                     + "%.1f kB per bild (%.2f Mbit/s), högst %ld i flykt, %ld×%ld px",
                     logg.skickade, m.hz, d * 1000, medel / 1000, medel * 4 / 3 * m.hz * 8 / 1e6, logg.iFlyktMax,
                     logg.storlek?.w ?? 0, logg.storlek?.h ?? 0))
        XCTAssertLessThanOrEqual(logg.iFlyktMax, 1, "mer än en bild i flykt")
        XCTAssertEqual(Double(logg.skickade) / 4, Forhandstakt.aktiv, accuracy: 3)
        XCTAssertLessThan(d, 0.3)
        XCTAssertEqual(logg.storlek?.w, 360)
        XCTAssertEqual(logg.storlek?.h, 640)
        XCTAssertLessThan(medel, Double(LinkPreview.maxBytes))
        let bild = try XCTUnwrap(styr.andraBild.bild)
        XCTAssertEqual(bild.size.width * bild.scale, 360)
        XCTAssertEqual(bild.size.height * bild.scale, 640)
        try FileManager.default.createDirectory(atPath: Self.ut, withIntermediateDirectories: true)
        try XCTUnwrap(bild.pngData()).write(to: URL(fileURLWithPath: "\(Self.ut)/andra-bild-mottagen.png"))
        print("PROV: skrev andra-bild-mottagen.png")

        // Under inspelningen pausad (den säkra vägen, MS35): inga bilder, och rutan går efter 1,5 s.
        kalla.stall(hz: Forhandstakt.hz(kanSkicka: true, inspelar: true, tryck: .nominal))
        let fore = logg.skickade
        rutor(kalla, pb, sekunder: 2)
        XCTAssertEqual(logg.skickade, fore, "bilder under inspelningen")
        XCTAssertFalse(styr.forhandsbildVisas(nu: LinkClock.now(), inspelar: false), "rutan står kvar utan bilder")

        // Varm ("fair"): färre bilder.
        kalla.stall(hz: Forhandstakt.hz(kanSkicka: true, inspelar: false, tryck: .fair))
        let fair = logg.skickade
        rutor(kalla, pb, sekunder: 2)
        XCTAssertEqual(Double(logg.skickade - fair) / 2, Forhandstakt.varm, accuracy: 2)
        XCTAssertTrue(styr.forhandsbildVisas(nu: LinkClock.now(), inspelar: false))

        // Tappet: bilden är borta hos den styrande (den sparas inte), och kommer igen efteråt.
        folj.suspend(3)
        XCTAssertTrue(vänta(8) { styr.andraBild.bild == nil }, "bilden stod kvar efter tappet")
        XCTAssertFalse(styr.forhandsbildVisas(nu: LinkClock.now(), inspelar: false))
        kalla.stall(hz: 0)                                         // som inspelningens skärm när kopplingen föll
        kalla.stall(hz: Forhandstakt.aktiv)
        XCTAssertTrue(rutor(kalla, pb, sekunder: 20) { styr.andraBild.bild != nil && folj.kanForhandsbild },
                      "bilden kom inte tillbaka efter tappet")
        print("PROV: förhandsbild pausad under inspelningen, \(Int(Forhandstakt.varm)) bilder/s varm, borta vid tappet och tillbaka")
    }

    // MARK: - Hjälp

    /// Kamerans rutor 240 gånger i sekunden, med huvudtråden igång emellan, tills tiden gått eller
    /// villkoret håller.
    @discardableResult
    private func rutor(_ k: ForhandsKalla, _ pb: CVPixelBuffer, sekunder: Double,
                       tills villkor: () -> Bool = { false }) -> Bool {
        let slut = Date().addingTimeInterval(sekunder)
        while Date() < slut {
            if villkor() { return true }
            let t = Date()
            k.ruta(pb, tid: LinkClock.now())
            RunLoop.main.run(until: t.addingTimeInterval(1.0 / 240))
        }
        return villkor()
    }

    private func vänta(_ sekunder: TimeInterval, _ villkor: () -> Bool) -> Bool {
        let slut = Date().addingTimeInterval(sekunder)
        while Date() < slut {
            if villkor() { return true }
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        return villkor()
    }

    private func väntaPå<T>(_ sekunder: TimeInterval, _ värde: () -> T?) -> T? {
        var ut: T?
        _ = vänta(sekunder) {
            ut = värde()
            return ut != nil
        }
        return ut
    }
}

// MARK: - Rutan och den stora bilden

extension SwingLabProvVyer {
    /// Lead med den andra telefonens bild: rutan nere till vänster utan att knappen flyttar, också
    /// med en varning och med stor text; ingen ruta under serien; den stora bilden med och utan
    /// hjälplinjerna; och raden i kugghjulet. Färgerna som B85 (bilden är grå).
    func testDenAndraTelefonensBild() throws {
        let b = AndraBild(bild: try ProvBild.mottagen())
        try skarm(InspelningsLager(status: .kopplad, varning: nil, andraBild: b), "insp-lead-andra-bild",
                  farger: [.rod, .gron])
        try skarm(InspelningsLager(status: .kopplad, varning: .sammaVy(.dtl, kanByta: true), lutning: provLutning(6),
                                   andraBild: b),
                  "insp-lead-andra-bild-varning", farger: [.rod, .gron, .gul])
        try skarm(InspelningsLager(status: .kopplad, varning: .sammaVy(.dtl, kanByta: true), andraBild: b),
                  "insp-lead-andra-bild-text", farger: [.rod, .gron, .gul], textstorlek: .accessibility3)
        try skarm(InspelningsLager(status: .spelarIn(sekunder: 42), varning: nil, andraBild: b),
                  "insp-lead-andra-bild-spelar-in", farger: [.rod])
        try skarm(InspelningsLager(status: .kopplad, varning: nil, andraBild: b, andraBildStor: true),
                  "insp-lead-andra-bild-stor", farger: [])
        try skarm(InspelningsLager(status: .kopplad, varning: nil, andraBild: b, andraBildStor: true, hjalplinjer: false),
                  "insp-lead-andra-bild-stor-utan-linjer", farger: [])

        // Kugghjulet: fördröjningen och takten under "Other phone", bara hos Lead och när bilden kommer.
        let lead = InspelningsInstallningar.rader(
            roll: .lead, vy: .dtl, andraVy: .fo, fps: 240, lutning: provLutning(0.8), horda: nil, minuter: 40,
            tryck: .nominal, mikrofon: .inbyggd, andraBild: (fordrojning: 0.12, hz: 12))
        XCTAssertEqual(lead.map(\.varde), ["Lead\u{00A0}\u{00B7} DTL", "Follow\u{00A0}\u{00B7} FO",
                                           "0.12 s\u{00A0}\u{00B7} 12 fps", "240 fps", "0.8°", "about 40 min",
                                           "Normal", "Built-in"])
        let pausad = InspelningsInstallningar.rader(
            roll: .lead, vy: .dtl, andraVy: .fo, fps: 240, lutning: nil, horda: nil, minuter: nil,
            tryck: .nominal, mikrofon: nil, andraBild: (fordrojning: nil, hz: 0))
        XCTAssertEqual(pausad.count, 4)
        let folj = InspelningsInstallningar.rader(
            roll: .follow, vy: .fo, andraVy: .dtl, fps: 240, lutning: nil, horda: nil, minuter: nil,
            tryck: .nominal, mikrofon: nil, andraBild: (fordrojning: 0.1, hz: 12))
        XCTAssertEqual(folj.count, 4)
        try rendera(InspelningsInstallningar(rader: lead, hjalplinjer: .constant(true)).background(Theme.surface),
                    namn: "insp-installningar-andra-bild", accent: false)
    }
}
