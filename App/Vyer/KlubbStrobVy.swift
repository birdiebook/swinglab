import AVFoundation
import SwiftUI
import Swing
import Capture

/// Stroboskopet för ett slag (PLAN S7-2, METOD MF7): valt i granskningens meny ("Club trail"),
/// räknat först då och bara för det slaget. Klubbmodellens huvud ur varje ruta från P1 till P9,
/// som film där huvudena läggs på efter hand (8 gånger långsammare, i loop) och som bild vid P1
/// (`KlubbStrobLasare`). Inget sparas i passet; filmen och bilden går att dela. Ett prov på att
/// modellen ser klubban, inget mått (B92).
struct KlubbStrobVy: View {
    let passID: String
    let shotID: String
    var onClose: () -> Void

    @Environment(Store.self) private var store
    @State private var framsteg = 0.0
    @State private var bild: CGImage?
    @State private var film: URL?
    @State private var visarFilm = true
    @State private var fel: String?
    @State private var spelare = AVQueuePlayer()
    @State private var loop: AVPlayerLooper?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Navrad(titel: String(localized: "Club trail"), hoger: { dela }, tillbaka: onClose)
            if let bild {
                if film != nil {
                    Picker("", selection: $visarFilm) {
                        Text("Video").tag(true)
                        Text("Image").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                Group {
                    if visarFilm, film != nil {
                        PlayerSurface(player: spelare)
                    } else {
                        Image(decorative: bild, scale: 1).resizable()
                    }
                }
                .aspectRatio(CGFloat(bild.width) / CGFloat(bild.height), contentMode: .fit)
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
        .onChange(of: visarFilm) { _, spela in spela ? spelare.play() : spelare.pause() }
        .onDisappear {
            spelare.pause()
            loop = nil
        }
    }

    /// Delningen: det som visas.
    @ViewBuilder private var dela: some View {
        let symbol = Image(systemName: "square.and.arrow.up")
            .typsnitt(17, .medium)
            .foregroundStyle(Theme.secondary)
            .frame(width: 40, height: 40)
        if visarFilm, let film {
            ShareLink(item: film) { symbol }
        } else if let bild {
            let b = Image(decorative: bild, scale: 1)
            ShareLink(item: b, preview: SharePreview(Text("Club trail"), image: b)) { symbol }
        }
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
        // Filmen i appens tillfälliga mapp, en per slag: den ersätts nästa gång.
        let mal = FileManager.default.temporaryDirectory.appending(path: "club-trail-\(shotID).mp4")
        let svar = await KlubbStrobLasare.rakna(shot: s, series: series, url: url, offset: offset, film: mal) { v in
            Task { @MainActor in framsteg = v }
        }
        switch svar {
        case .klar(let b, let f, _, _):
            if let f {
                loop = AVPlayerLooper(player: spelare, templateItem: AVPlayerItem(url: f))
                spelare.isMuted = true
                spelare.play()
            }
            film = f
            bild = b
        case .fel(let t): fel = t
        case .avbruten: break
        }
    }
}
