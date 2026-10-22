import SwiftUI
import Swing

/// Att jobba på (skissens skärm 6): de 1–3 saker som PC:n och Claude valt (S5), i
/// svingens ordning, med en sektion per sak i skissens form. Vyn visar
/// `att_jobba_pa.json` som den är (docs/FORMAT.md): inget räknas om på telefonen.
struct AttJobbaPaVy: View {
    let visning: AttJobbaPaVisning
    var tillbaka: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Navrad(titel: String(localized: "Work on"), hoger: { Under(text: visning.fran) }, tillbaka: tillbaka)
            ForEach(Array(visning.saker.enumerated()), id: \.offset) { i, s in
                SakVy(sak: s, antal: visning.saker.count)
                    .padding(.top, i == 0 ? 0 : 28)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(s.upplasningHel)
            }
        }
        .padding(.horizontal, 20)
        .background(Theme.ground)
    }
}

/// En sak: rubriken med ordningen och veckan, Du nu mot målet, kedjan av följdfel,
/// övningen med stegen, rörligheten, tanken och villkoret. Talen är filens.
struct SakVy: View {
    let sak: AttJobbaPaVisning.Sakvisning
    let antal: Int

    private func vag(_ f: AttJobbaPaVisning.Foljd) -> some View {
        HStack(spacing: 6) { vagDelar(f) }
    }

    @ViewBuilder private func vagDelar(_ f: AttJobbaPaVisning.Foljd) -> some View {
        ForEach(Array(f.vag.enumerated()), id: \.offset) { j, namn in
            Image(systemName: "arrow.right")
                .typsnitt(10, .semibold)
                .foregroundStyle(Theme.tertiary)
            Text(namn)
                .typsnitt(14)
                .foregroundStyle(j == f.vag.count - 1 ? Theme.text : Theme.tertiary)
        }
    }

    /// Följdfelets tal, gradtecknet direkt efter.
    private func tal(_ f: AttJobbaPaVisning.Foljd) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: f.enhet == "°" ? 0 : 3) {
            Text(f.varde)
                .typsnitt(15, .medium, siffror: true)
                .foregroundStyle(Theme.text)
            Text(f.enhet)
                .typsnitt(13)
                .foregroundStyle(Theme.tertiary)
        }
        .fixedSize()
    }

    private func stegstreck(_ lage: AttJobbaPaVisning.Steglage) -> some View {
        Rectangle()
            .fill(lage == .klart ? Theme.secondary : lage == .nu ? Theme.text : Theme.line)
            .clipShape(.rect(cornerRadius: 2))
    }

    private func stegnamn(_ s: (namn: String, lage: AttJobbaPaVisning.Steglage)) -> some View {
        Text(s.namn)
            .typsnitt(12)
            .foregroundStyle(s.lage == .nu ? Theme.text : Theme.tertiary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Etikett(text: antal > 1 ? "\(sak.ordning) · \(sak.rubrik)" : sak.rubrik, farg: Theme.acc)
                Spacer()
                if let m = sak.markning { MarkningVy(markning: m) }
            }
            .padding(.top, 8)
            Text(sak.namn)
                .tracking(-0.6)
                .typsnitt(30, .semibold)
                .foregroundStyle(Theme.text)
                .padding(.top, 4)
            StortTal(varde: sak.nu, enhet: sak.enhet)
                .padding(.top, 10)
            if let mal = sak.mal {
                SpannVy(spann: mal, accent: true)
                    .padding(.top, 12)
            }
            Color.clear.frame(height: 14)

            if !sak.foljd.isEmpty {
                Sektion {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(sak.foljd.enumerated()), id: \.offset) { _, f in
                            // Vägen bryts i stället för att klippas; talet står till höger
                            // när det får plats och under vägen med stor text.
                            ViewThatFits(in: .horizontal) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    vag(f).fixedSize()
                                    Spacer(minLength: 8)
                                    tal(f)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Radbrytning(mellan: 6) { vagDelar(f) }
                                    tal(f)
                                }
                                .padding(.vertical, 4)
                            }
                            .frame(minHeight: 32)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(f.upplasning)
                        }
                    }
                }
            }

            Sektion(etikett: String(localized: "Drill")) {
                Text(sak.ovning)
                    .typsnitt(17, .medium)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                // Stegen bredvid varandra; med stor text under varandra, så att inget
                // namn bryts mitt i ordet.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 4) {
                        ForEach(Array(sak.steg.enumerated()), id: \.offset) { _, s in
                            VStack(alignment: .leading, spacing: 7) {
                                stegstreck(s.lage).frame(height: 3)
                                stegnamn(s).lineLimit(1).fixedSize()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(sak.steg.enumerated()), id: \.offset) { _, s in
                            HStack(spacing: 10) {
                                stegstreck(s.lage).frame(width: 24, height: 3)
                                stegnamn(s).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(.top, 14)
            }

            if let r = sak.rorlighet {
                Sektion(etikett: String(localized: "Mobility"), hoger: r.test) {
                    if let o = r.ovning {
                        Text(o)
                            .typsnitt(17, .medium)
                            .foregroundStyle(Theme.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Sektion(etikett: String(localized: "Thought")) {
                Text(sak.tanke)
                    .tracking(-0.3)
                    .typsnitt(30, .medium)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }

            Sektion(etikett: String(localized: "Done when")) {
                Text(sak.villkor)
                    .typsnitt(20, .medium, siffror: true)
                    .foregroundStyle(Theme.text)
                    .padding(.top, 6)
                Under(text: sak.villkorUnder)
                    .padding(.top, 4)
            }
        }
    }
}
