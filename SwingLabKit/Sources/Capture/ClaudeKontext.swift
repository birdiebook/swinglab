import Foundation
import Swing

// Claude-appen på telefonen (S5b, BESLUT B52): passen som de sparas (`PassState`) görs om till
// analysens rader, och underlaget byggs ur passet och de tidigare passen som kan jämföras
// (samma klubba, vy och längd, METOD MS14). Svaret sparas som en fil från PC:n (`FocusInbox`).
// Knapparna "Ask Claude" och "Paste from Claude" kommer i S5b-2.

extension PassState {
    /// Passets slag som analysen läser: de som räknas, i passets ordning, med passets vy och
    /// klubba, och de första i serie 1 som första serien (METOD MT2, som `visningsPass`).
    public var claudeRader: Passrader {
        let v = visningsPass
        let klubba = PassSetup.clubLabel(setup.club)
        let slag = v.svingar.enumerated().map { i, s in
            Slagrad(vy: s.vy, klubba: klubba, matt: s.matt, forstaSerien: i < v.serie1)
        }
        return Passrader(pass: id, slag: slag)
    }
}

public enum ClaudeKontext {
    /// Tiden i ISO 8601 med telefonens zon ("2026-11-20T21:15:00+01:00"), för `skapad`.
    public static func skapad(_ d: Date, zon: TimeZone = .current) -> String {
        let f = ISO8601DateFormatter()
        f.timeZone = zon
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: d)
    }

    /// Underlaget för `nu`: passet och de tidigare passen som kan jämföras (`PassHistory.earlier`),
    /// och alla hämtade filer (`FocusInbox.readAll`). nil när passet inte har några slag som räknas.
    public static func underlag(nu: PassState, alla: [PassState], filer: [AttJobbaPa], katalog: Katalog,
                                skapad: Date = Date(), zon: TimeZone = .current) -> ClaudeUnderlag? {
        guard !nu.countedSwings.isEmpty else { return nil }
        let passen = PassHistory.earlier(nu, among: alla).map(\.claudeRader) + [nu.claudeRader]
        return ClaudeUnderlag(passen: passen, filer: filer, skapad: Self.skapad(skapad, zon: zon), katalog: katalog)
    }
}

extension FocusInbox {
    public enum ClaudeResult: Sendable {
        /// Filen att spara i `AttJobbaPa/` under `fileName`, som en från PC:n.
        case accepted(focus: AttJobbaPa, fileName: String, data: Data)
        /// Felen på engelska (`Kontrollfel.text`): fältet, aldrig värdet.
        case rejected([Kontrollfel])
    }

    /// "Paste from Claude": urklippet kontrolleras mot passet som underlaget gällde (ClaudeSvar,
    /// BESLUT B54) och tas emot som "Import focus" gör. Inget ändras när det inte går igenom.
    public static func acceptClaude(_ text: String, underlag: ClaudeUnderlag) -> ClaudeResult {
        switch underlag.svar(text) {
        case let .fel(f):
            return .rejected(f)
        case let .godkand(data, _):
            guard let r = try? accept(data) else { return .rejected([Kontrollfel("pass", "pass_form")]) }
            return .accepted(focus: r.focus, fileName: r.fileName, data: data)
        }
    }
}
