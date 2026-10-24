import SwiftUI
import Swing
import Capture

// Sessions, appens förstasida (PLAN S4e, BESLUT B64): alla pass på telefonen, senaste först.
// Raden säger vyn, dagen och klockslaget, klubban och svingarna; ett tryck öppnar passet,
// ett svep raderar det efter en fråga, och + uppe till höger startar ett nytt (Record eller
// Import from Photos). Formspråket B13: svartvitt, inga värdeord, ingen beskrivande text
// utom i raderingens fråga, som säger vad som försvinner. METOD MS20

/// Raderna ur passen, utanför huvudtråden (`Store.reading`, som flikarna i S4c).
enum Sessionslista {
    @MainActor
    static func load(_ store: Store) async -> [Sessionsrad] {
        let ids = store.index.passes.map(\.id)
        let root = store.root
        let hojd = store.settings.heightM
        return await Task.detached(priority: .userInitiated) {
            Sessionsrad.rader(Store.reading(ids, root: root, height: hojd))
        }.value
    }
}

/// En rad: vyn (med "paired" för två telefoner), dagen och klockslaget med klubban, och
/// svingarna till höger. Värden in, så att provet kan rita den.
struct SessionRadVy: View {
    let rad: Sessionsrad
    /// Pilen till höger: raden öppnar passet (inte i raderingens fråga).
    var pil = true

    private var vyn: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: rad.vyNamn)
                .typsnitt(17, .medium)
                .foregroundStyle(Theme.text)
            if rad.parad {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Image(systemName: "link")
                        .typsnitt(11, .semibold)
                    Text(verbatim: Texter.parad)
                        .typsnitt(13)
                }
                .foregroundStyle(Theme.secondary)
            }
        }
    }

    private var under: some View {
        Text(verbatim: rad.tid + Texter.skilje + rad.klubba)
            .monospacedDigit()
            .typsnitt(14)
            .foregroundStyle(Theme.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var svingar: some View {
        if let n = rad.svingar {
            VStack(alignment: .trailing, spacing: 0) {
                Text(verbatim: "\(n)")
                    .typsnitt(22, .medium, siffror: true)
                    .foregroundStyle(Theme.text)
                Text(verbatim: Texter.svingEtikett(n))
                    .typsnitt(11)
                    .foregroundStyle(Theme.tertiary)
            }
        } else {
            Text(verbatim: Texter.ejAnalyserat)
                .typsnitt(13)
                .foregroundStyle(Theme.tertiary)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                vyn
                under
            }
            Spacer(minLength: 8)
            svingar.fixedSize()
            if pil {
                Image(systemName: "chevron.right")
                    .typsnitt(13, .semibold)
                    .foregroundStyle(Theme.tertiary)
            }
        }
        .padding(.vertical, 12)
        .frame(minHeight: 64)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rad.upplasning)
    }
}

/// Rubriken med + (Record och Import from Photos).
struct SessionsRubrik: View {
    var nytt: (PassFlowView.Mode) -> Void = { _ in }

    var body: some View {
        HStack(alignment: .center) {
            Text("Sessions")
                .tracking(-0.6)
                .typsnitt(30, .semibold)
                .foregroundStyle(Theme.text)
            Spacer(minLength: 8)
            Menu {
                Button("Record") { nytt(.record) }
                Button("Import from Photos") { nytt(.photos) }
            } label: {
                Image(systemName: "plus")
                    .typsnitt(22, .medium)
                    .foregroundStyle(Theme.text)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel(Text("New session"))
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
    }
}

/// Sessions: rubriken med +, listan och den tomma raden. Listan är en `List` för svepet,
/// alltså UIKit: provet fångar den ur ett riktigt fönster.
struct SessionsVy: View {
    let rader: [Sessionsrad]
    /// Inga pass i indexet: den tomma raden (inte medan raderna läses).
    var tom = false
    var problem: String? = nil
    var nytt: (PassFlowView.Mode) -> Void = { _ in }
    var oppna: (String) -> Void = { _ in }
    var radera: (Sessionsrad) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SessionsRubrik(nytt: nytt)
                .padding(.horizontal, 20)
            if let problem {
                Text(problem)
                    .typsnitt(13, .semibold)
                    .foregroundStyle(Theme.flag)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            if tom {
                Text("No sessions")
                    .typsnitt(15)
                    .foregroundStyle(Theme.secondary)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.hair).frame(height: 1) }
                    .padding(.horizontal, 20)
                Spacer(minLength: 0)
            } else {
                List {
                    ForEach(rader) { rad in
                        Button { oppna(rad.id) } label: { SessionRadVy(rad: rad) }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                            .listRowBackground(Theme.ground)
                            .listRowSeparatorTint(Theme.hair)
                            .accessibilityAddTraits(.isButton)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button { radera(rad) } label: { Label("Delete", systemImage: "trash") }
                                    .tint(Theme.line)
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 64)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.ground, ignoresSafeAreaEdges: .all)
    }
}

/// Frågan efter svepet: passets rad, vad som försvinner, Delete och Cancel. Ett blad och inte
/// en systemdialog, så att provet kan rita den (som B60:s fråga). BESLUT B64
struct RaderaPassVy: View {
    let rad: Sessionsrad
    var onDelete: () -> Void = {}
    var onCancel: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Delete session?")
                .typsnitt(22, .semibold)
                .foregroundStyle(Theme.text)
                .padding(.bottom, 6)
            SessionRadVy(rad: rad, pil: false)
                .overlay(alignment: .top) { Rectangle().fill(Theme.hair).frame(height: 1) }
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.hair).frame(height: 1) }
            VStack(alignment: .leading, spacing: 4) {
                Under(text: String(localized: "Video, joints and measures are removed from this phone."))
                if rad.parad {
                    Under(text: String(localized: "The other phone keeps its session."))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 12)
            .padding(.bottom, 22)
            Button("Delete", action: onDelete)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.bottom, 8)
            Button("Cancel", action: onCancel)
                .buttonStyle(RowButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Theme.ground)
    }
}
