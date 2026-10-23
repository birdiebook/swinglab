import SwiftUI
import Swing

/// Infobladet (BESLUT B41): måttets namn och fyra rader (vad, varför, tecknet och källan
/// i grått), svartvitt enligt design/README. Den enda platsen med beskrivande text; ett
/// blad (sheet) i halv höjd öppnas med ett tryck på en måttrad eller ⓘ.
struct InfobladVy: View {
    let blad: Infoblad

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(verbatim: blad.namn)
                .typsnitt(22, .semibold)
                .foregroundStyle(Theme.text)
                .padding(.bottom, 4)
            Text(verbatim: blad.vad)
                .typsnitt(16)
                .foregroundStyle(Theme.text)
            Text(verbatim: blad.varfor)
                .typsnitt(16)
                .foregroundStyle(Theme.text)
            Text(verbatim: blad.tecken)
                .typsnitt(16, .medium, siffror: true)
                .foregroundStyle(Theme.text)
            Text(verbatim: "\(Texter.kallaRubrik): \(blad.kalla)")
                .typsnitt(14)
                .foregroundStyle(Theme.tertiary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(blad.upplasning)
    }
}

/// Bladets innehåll i ett sheet: halv höjd, svart botten.
struct InfobladArk: View {
    let blad: Infoblad

    var body: some View {
        ScrollView { InfobladVy(blad: blad) }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.ground)
    }
}

/// Bladet som sheet, med tillståndet hos den som visar det.
private struct InfobladSheet: ViewModifier {
    let blad: Infoblad?
    @Binding var visas: Bool

    func body(content: Content) -> some View {
        content.sheet(isPresented: $visas) {
            if let blad { InfobladArk(blad: blad) }
        }
    }
}

/// Ett tryck på raden öppnar bladet (passet och granskningen).
private struct InfobladTryck: ViewModifier {
    let blad: Infoblad?
    @State private var visas = false

    func body(content: Content) -> some View {
        if blad == nil {
            content
        } else {
            content
                .contentShape(Rectangle())
                .onTapGesture { visas = true }
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { visas = true }
                .modifier(InfobladSheet(blad: blad, visas: $visas))
        }
    }
}

extension View {
    /// Ett tryck öppnar infobladet; utan blad händer inget (BESLUT B41).
    func infoblad(_ blad: Infoblad?) -> some View { modifier(InfobladTryck(blad: blad)) }
}

/// Den lilla ⓘ som öppnar bladet där raden redan har ett annat tryck (Today, Progress).
/// Tryckytan är 44×44 pt, men raden räknar den som 28 hög. `visa` = vyn som visar bladet
/// håller tillståndet själv (Today, `sheet(item:)`); utan den har knappen sitt eget.
struct InfoKnapp: View {
    let blad: Infoblad?
    var visa: (() -> Void)? = nil
    @State private var visas = false

    var body: some View {
        if blad != nil {
            Button { if let visa { visa() } else { visas = true } } label: {
                Image(systemName: "info.circle")
                    .typsnitt(13)
                    .foregroundStyle(Theme.tertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, -8)
            .accessibilityLabel(Text("About the measure"))
            .modifier(InfobladSheet(blad: blad, visas: $visas))
        }
    }
}
