import SwiftUI

@main
struct SwingLabApp: App {
    @State private var store = Store()

    var body: some Scene {
        WindowGroup {
            StartView()
                .environment(store)
                .preferredColorScheme(.dark)
        }
    }
}

/// Startvyn (S2_SPEC §12). Nytt pass (S2c) och Hämta ur Bilder (S2d) öppnar
/// uppställningen; Hämta Att jobba på öppnas i S2f. Formspråket är BESLUT B13:
/// bara etiketter, ingen beskrivande text.
struct StartView: View {
    @Environment(Store.self) private var store
    @State private var flow: PassFlowView.Mode?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SwingLab")
                .font(.system(size: 30, weight: .semibold))
                .tracking(-0.6)
                .foregroundStyle(Theme.text)
                .padding(.top, 8)
                .padding(.bottom, 18)

            Button("Nytt pass") { flow = .record }
                .buttonStyle(PrimaryButtonStyle())

            VStack(spacing: 0) {
                Button("Hämta ur Bilder") { flow = .photos }
                Button("Hämta Att jobba på") {}
                    .disabled(true)
            }
            .buttonStyle(RowButtonStyle())
            .padding(.top, 22)

            if let problem = store.problem {
                Text(problem)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.flag)
                    .padding(.top, 12)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.ground, ignoresSafeAreaEdges: .all)
        .fullScreenCover(item: $flow) { mode in
            PassFlowView(mode: mode) { flow = nil }
                .environment(store)
        }
    }
}
