import SwiftUI
import Swing
import Capture

/// Jag (skissens skärm 8, fliken Me): längden, spelhanden och klubborna, som är standarden
/// för nya pass (ett pass behåller sin längd, METOD MS16), och "Import focus" (S2f, BESLUT
/// B28), som låg i Me → Sessions före S4e (BESLUT B64). Datan kommer som värden, så att
/// provet kan rita skärmen; `editable: false` ritar längden utan menyn (ImageRenderer ritar
/// inte UIKit).
struct JagVy: View {
    /// Längden, m; nil = inte angiven (passen mäts då med 1,80 m, märkt antagen).
    let heightM: Double?
    let hand: Hand
    /// Klubborna i Jag (manifestets id).
    let clubs: [String]
    var editable = true
    var onHeight: (Double) -> Void = { _ in }
    var onHand: (Hand) -> Void = { _ in }
    var onClub: (String) -> Void = { _ in }
    /// Filer för `att_jobba_pa.json` (S2f).
    var onImportFocus: () -> Void = {}
    /// Filer för modellens förslag till klubbmarkeringen (S7d, BESLUT B93).
    var onImportSuggestions: () -> Void = {}
    /// Svaret efter hämtningen ("Focus saved", eller fältet som är fel), och om det är ett fel.
    var importResult: String? = nil
    var importFailed = false

    private var rubrik: some View {
        Text("Me")
            .tracking(-0.6)
            .typsnitt(30, .semibold)
            .foregroundStyle(Theme.text)
    }

    private func rad<Hoger: View>(_ etikett: LocalizedStringKey, @ViewBuilder hoger: () -> Hoger) -> some View {
        HStack(spacing: 12) {
            Text(etikett)
                .typsnitt(17, .medium)
                .foregroundStyle(Theme.text)
            Spacer(minLength: 8)
            hoger()
        }
        .frame(minHeight: 52)
        .overlay(alignment: .top) { Rectangle().fill(Theme.hair).frame(height: 1) }
    }

    private var langd: some View {
        Text(verbatim: heightM.map { "\(Int(($0 * 100).rounded())) cm" } ?? "—")
            .typsnitt(17, siffror: true)
            .foregroundStyle(Theme.secondary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rubrik
                .padding(.top, 8)
                .padding(.bottom, 18)

            rad("Height") {
                if editable {
                    Menu {
                        Picker("Height", selection: Binding(get: { heightM.map { Int(($0 * 100).rounded()) } ?? 180 },
                                                            set: { onHeight(Double($0) / 100) })) {
                            ForEach(Array(ShotMeasuring.heightChoicesCm), id: \.self) { cm in
                                Text(verbatim: "\(cm) cm").tag(cm)
                            }
                        }
                    } label: { langd }
                } else {
                    langd
                }
            }

            rad("Hand") {
                Segment(alternativ: [String(localized: "Right"), String(localized: "Left")], valt: Binding(
                    get: { hand == .vanster ? 1 : 0 },
                    set: { onHand($0 == 1 ? .vanster : .hoger) }))
            }

            Etikett(text: String(localized: "Clubs"))
                .padding(.top, 26)
                .padding(.bottom, 12)
            Flode {
                ForEach(PassSetup.clubs, id: \.self) { id in
                    Chip(text: PassSetup.clubLabel(id), vald: clubs.contains(id)) { onClub(id) }
                }
            }
            .padding(.bottom, 14)

            Button("Import focus", action: onImportFocus)
                .buttonStyle(RowButtonStyle())
                .padding(.top, 26)
            Button("Import club suggestions", action: onImportSuggestions)
                .buttonStyle(RowButtonStyle())
            if let importResult {
                Text(verbatim: importResult)
                    .typsnitt(13, .semibold)
                    .foregroundStyle(importFailed ? Theme.flag : Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 20)
        .background(Theme.ground)
    }
}
