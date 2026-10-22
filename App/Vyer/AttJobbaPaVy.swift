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
            Navrad(titel: "Att jobba på", hoger: { Under(text: visning.fran) }, tillbaka: tillbaka)
            ForEach(Array(visning.saker.enumerated()), id: \.offset) { i, s in
                SakVy(sak: s, antal: visning.saker.count)
                    .padding(.top, i == 0 ? 0 : 28)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Etikett(text: antal > 1 ? "\(sak.ordning) · \(sak.rubrik)" : sak.rubrik)
                Spacer()
                if let m = sak.markning { MarkningVy(markning: m) }
            }
            .padding(.top, 8)
            Text(sak.namn)
                .font(.system(size: 30, weight: .semibold))
                .tracking(-0.6)
                .foregroundStyle(Theme.text)
                .padding(.top, 4)
            StortTal(varde: sak.nu, enhet: sak.enhet)
                .padding(.top, 10)
            if let mal = sak.mal {
                SpannVy(spann: mal)
                    .padding(.top, 12)
            }
            Color.clear.frame(height: 14)

            if !sak.foljd.isEmpty {
                Sektion {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(sak.foljd.enumerated()), id: \.offset) { _, f in
                            HStack(spacing: 8) {
                                HStack(spacing: 6) {
                                    ForEach(Array(f.vag.enumerated()), id: \.offset) { j, namn in
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(Theme.tertiary)
                                        Text(namn)
                                            .font(.system(size: 14))
                                            .foregroundStyle(j == f.vag.count - 1 ? Theme.text : Theme.tertiary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 8)
                                HStack(alignment: .firstTextBaseline, spacing: f.enhet == "°" ? 1 : 3) {
                                    Text(f.varde)
                                        .font(Theme.number(15))
                                        .foregroundStyle(Theme.text)
                                    Text(f.enhet)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.tertiary)
                                }
                            }
                            .frame(minHeight: 32)
                        }
                    }
                }
            }

            Sektion(etikett: "Övning") {
                Text(sak.ovning)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .top, spacing: 4) {
                    ForEach(Array(sak.steg.enumerated()), id: \.offset) { _, s in
                        VStack(alignment: .leading, spacing: 7) {
                            Rectangle()
                                .fill(s.lage == .klart ? Theme.secondary : s.lage == .nu ? Theme.text : Theme.line)
                                .frame(height: 3)
                                .clipShape(.rect(cornerRadius: 2))
                            Text(s.namn)
                                .font(.system(size: 12))
                                .foregroundStyle(s.lage == .nu ? Theme.text : Theme.tertiary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 14)
            }

            if let r = sak.rorlighet {
                Sektion(etikett: "Rörlighet", hoger: r.test) {
                    if let o = r.ovning {
                        Text(o)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Theme.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Sektion(etikett: "Tanke") {
                Text(sak.tanke)
                    .font(.system(size: 30, weight: .medium))
                    .tracking(-0.3)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }

            Sektion(etikett: "Klart när") {
                Text(sak.villkor)
                    .font(Theme.number(20))
                    .foregroundStyle(Theme.text)
                    .padding(.top, 6)
                Under(text: sak.villkorUnder)
                    .padding(.top, 4)
            }
        }
    }
}
