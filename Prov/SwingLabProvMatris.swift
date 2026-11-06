// MATRISEN: TEXTSTORLEK × MÖRKT OCH LJUST (PLAN S4i, METOD MS41). Huvudskärmarna i galleriet
// ritas en gång till i tre textstorlekar (standard, xxxLarge och AX3) och båda lägena, och
// läggs bredvid varandra i ett kontaktark per skärm: /tmp/swinglab_prov/matris/<namn>.png, på
// ci-resultat som resultat/<sha>.matris.<namn>.png. Arket är till för ögat och för en granskning
// av bilderna; det jämförs inte med någon referens (BESLUT B100).
//
// Kroken sitter i `rendera` (ImageRenderer) och `fanga` (ett riktigt fönster, för List och
// svepet): samma vy med samma påhittade data som galleriets bild, så att matrisen inte bygger
// passen en gång till.
//
// Appen är bara mörk (BESLUT B13; SwingLabApp sätter .preferredColorScheme(.dark)). Den ljusa
// kolumnen visar därför var en vy tar färg ur systemet i stället för ur Theme: där skiljer den
// sig från den mörka, och provet skriver hur stor andel av punkterna som skiljer.

import XCTest
import SwiftUI
import UIKit
@testable import SwingLab

extension SwingLabProvVyer {

    /// Huvudskärmarna: förstasidan, Me, passet, granskningen, Claudes blad och kugghjulets blad.
    static let matrisSkarmar: Set<String> = ["sessions", "me", "session-dtl", "parad-granskning-dtl", "claude-blad",
                                             "insp-installningar-lead"]
    /// Standard, den största utan hjälpmedel och en av hjälpmedlens. METOD MS41
    static let matrisStorlekar: [(storlek: DynamicTypeSize, namn: String)] =
        [(.large, "standard"), (.xxxLarge, "xxxLarge"), (.accessibility3, "AX3")]
    static let matrisLagen: [(lage: ColorScheme, namn: String)] = [(.dark, "mörkt"), (.light, "ljust")]
    static let matrisMapp = "/tmp/swinglab_prov/matris"

    /// Kroken i `rendera`: vyn i matrisens sex lägen, @1x, med `rendera`s ram och bakgrund.
    func matris(_ vy: some View, namn: String) throws {
        var celler: [(String, UIImage?)] = []
        for s in Self.matrisStorlekar {
            for l in Self.matrisLagen {
                let innehall = vy
                    .environment(\.dynamicTypeSize, s.storlek)
                    .padding(.vertical, 16)
                    .frame(width: Self.bredd)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(Theme.ground)
                    .environment(\.colorScheme, l.lage)
                    .environment(\.locale, Locale(identifier: "sv_SE"))
                let r = ImageRenderer(content: innehall)
                r.scale = 1
                r.proposedSize = ProposedViewSize(width: Self.bredd, height: nil)
                celler.append(("\(s.namn) · \(l.namn)", r.uiImage))
            }
        }
        try kontaktark(celler, namn: namn)
    }

    /// Kroken i `fanga`: vyn i ett riktigt fönster (390 × 844), i matrisens sex lägen, @1x.
    func matrisFonster(_ vy: some View, namn: String) async throws {
        let scen = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        var celler: [(String, UIImage?)] = []
        for s in Self.matrisStorlekar {
            for l in Self.matrisLagen {
                let fonster = UIWindow(windowScene: scen)
                fonster.frame = CGRect(x: 0, y: 0, width: Self.bredd, height: 844)
                fonster.overrideUserInterfaceStyle = l.lage == .dark ? .dark : .light
                let host = UIHostingController(rootView: AnyView(vy.environment(\.dynamicTypeSize, s.storlek)
                    .environment(\.locale, Locale(identifier: "sv_SE"))))
                host.view.backgroundColor = .black
                fonster.rootViewController = host
                fonster.isHidden = false
                try await Task.sleep(for: .seconds(1))
                let format = UIGraphicsImageRendererFormat()
                format.scale = 1
                let bild = UIGraphicsImageRenderer(bounds: fonster.bounds, format: format).image { _ in
                    _ = fonster.drawHierarchy(in: fonster.bounds, afterScreenUpdates: true)
                }
                fonster.isHidden = true
                celler.append(("\(s.namn) · \(l.namn)", bild))
            }
        }
        try kontaktark(celler, namn: namn)
    }

    /// Cellerna i en rad (mörkt och ljust bredvid varandra per storlek) med etiketten över, och
    /// en rad i loggen: höjden per storlek och hur stor andel av punkterna som skiljer ljust från
    /// mörkt (en kanal mer än 8 av 255, som MS40). METOD MS41
    func kontaktark(_ celler: [(String, UIImage?)], namn: String) throws {
        let lucka: CGFloat = 12, rubrik: CGFloat = 30, w: CGFloat = Self.bredd
        var h: CGFloat = 100
        for cell in celler {
            if let bild = cell.1 {
                let hc: CGFloat = bild.size.height * w / max(bild.size.width, 1)
                if hc > h { h = hc }
            }
        }
        let storlek = CGSize(width: CGFloat(celler.count) * (w + lucka) + lucka, height: rubrik + h + lucka)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let ark = UIGraphicsImageRenderer(size: storlek, format: format).image { ctx in
            UIColor(white: 0.3, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: storlek))
            let text: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 15, weight: .semibold),
                                                       .foregroundColor: UIColor.white]
            for (i, cell) in celler.enumerated() {
                let x = lucka + CGFloat(i) * (w + lucka)
                (cell.0 as NSString).draw(at: CGPoint(x: x, y: 7), withAttributes: text)
                if let bild = cell.1 {
                    bild.draw(in: CGRect(x: x, y: rubrik, width: w, height: bild.size.height * w / max(bild.size.width, 1)))
                } else {
                    ("ritades inte" as NSString).draw(at: CGPoint(x: x, y: rubrik + 8), withAttributes: text)
                }
            }
        }
        try FileManager.default.createDirectory(atPath: Self.matrisMapp, withIntermediateDirectories: true)
        try XCTUnwrap(ark.pngData()).write(to: URL(fileURLWithPath: "\(Self.matrisMapp)/\(namn).png"))

        // Cellerna kommer i par: mörkt, ljust för varje storlek.
        var hojder: [String] = [], ljust: [String] = []
        for k in stride(from: 0, to: celler.count - 1, by: 2) {
            let (morkt, ljus) = (celler[k].1, celler[k + 1].1)
            hojder.append(morkt.map { "\(Int($0.size.height))" } ?? "–")
            if let m = morkt.flatMap({ Bildpunkter($0) }), let l = ljus.flatMap({ Bildpunkter($0) }),
               let s = m.skillnad(mot: l) {
                ljust.append(String(format: "%.1f %%", Double(s.antal) / Double(m.bredd * m.hojd) * 100))
            } else {
                ljust.append("–")
            }
        }
        let storlekar = Self.matrisStorlekar.map { $0.namn }.joined(separator: " · ")
        print("MATRIS: \(namn): höjd \(hojder.joined(separator: " · ")) pt (\(storlekar)); ljust skiljer från mörkt i "
              + "\(ljust.joined(separator: " · ")) av punkterna → matris/\(namn).png (\(Int(storlek.width))×\(Int(storlek.height)) px)")
        XCTAssertFalse(celler.allSatisfy { $0.1 == nil }, "\(namn): ingen cell i matrisen ritades")
    }
}
