import SwiftUI
import Swing
import Capture

/// Stroboskopet för ett slag (PLAN S7-2, METOD MF7): valt i granskningens meny ("Club trail"),
/// räknat först då och bara för det slaget. Klubbmodellens huvud ur varje ruta från P1 till P9
/// inklistrat i bilden vid P1 (`KlubbStrobLasare`). Bilden sparas inte i passet; den går att
/// dela. Ett prov på att modellen ser klubban, inget mått (B92). B13: bara bilden.
struct KlubbStrobVy: View {
    let passID: String
    let shotID: String
    var onClose: () -> Void

    @Environment(Store.self) private var store
    @State private var framsteg = 0.0
    @State private var bild: CGImage?
    @State private var fel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Navrad(titel: String(localized: "Club trail"), hoger: {
                if let bild {
                    let b = Image(decorative: bild, scale: 1)
                    ShareLink(item: b, preview: SharePreview(Text("Club trail"), image: b)) {
                        Image(systemName: "square.and.arrow.up")
                            .typsnitt(17, .medium)
                            .foregroundStyle(Theme.secondary)
                            .frame(width: 40, height: 40)
                    }
                }
            }, tillbaka: onClose)
            if let bild {
                Image(decorative: bild, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
            } else if let fel {
                Text(verbatim: fel)
                    .typsnitt(13)
                    .foregroundStyle(Theme.tertiary)
            } else {
                ProgressView(value: framsteg).tint(Theme.text)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .background(Theme.ground, ignoresSafeAreaEdges: .all)
        .preferredColorScheme(.dark)
        .task { await rakna() }
    }

    /// Seriens fil, eller klippet när originalet är borttaget (som klubbhuvudets bana, S7b).
    private func rakna() async {
        guard let p = store.load(passID), let s = p.shots.first(where: { $0.id == shotID }), let rel = s.joints,
              let series = store.joints(rel, in: passID), let serie = p.series.first(where: { $0.nr == s.series }) else {
            fel = String(localized: "The video could not be read")
            return
        }
        var url = store.url(serie.file, in: passID)
        var offset = 0.0
        if !FileManager.default.fileExists(atPath: url.path), let clip = s.clip, let o = ShotImages.clipOffset(s) {
            url = store.url(clip, in: passID)
            offset = o
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            fel = String(localized: "The video is not on this phone")
            return
        }
        let svar = await KlubbStrobLasare.rakna(shot: s, series: series, url: url, offset: offset) { v in
            Task { @MainActor in framsteg = v }
        }
        switch svar {
        case .klar(let b, _, _): bild = b
        case .fel(let t): fel = t
        case .avbruten: break
        }
    }
}
