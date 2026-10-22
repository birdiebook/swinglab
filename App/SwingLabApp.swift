import SwiftUI

@main
struct SwingLabApp: App {
    var body: some Scene {
        WindowGroup {
            StartView()
                .preferredColorScheme(.dark)
        }
    }
}

/// Startvyn (S2_SPEC §12 S2a). Knapparna öppnas i senare etapper: Nytt pass i S2c,
/// Hämta ur Bilder i S2d och Hämta Att jobba på i S2f. Formspråket är BESLUT B13:
/// bara etiketter, ingen beskrivande text.
struct StartView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SwingLab")
                .font(.system(size: 30, weight: .semibold))
                .tracking(-0.6)
                .foregroundStyle(Theme.text)
                .padding(.top, 8)
                .padding(.bottom, 18)

            Button("Nytt pass") {}
                .buttonStyle(PrimaryButtonStyle())
                .disabled(true)

            VStack(spacing: 0) {
                Button("Hämta ur Bilder") {}
                Button("Hämta Att jobba på") {}
            }
            .buttonStyle(RowButtonStyle())
            .disabled(true)
            .padding(.top, 22)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.ground, ignoresSafeAreaEdges: .all)
    }
}
