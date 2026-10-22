import SwiftUI
import Swing

/// Att jobba på (skissens skärm 6): de 1–3 saker som PC:n och Claude valt (S5), i
/// svingens ordning, med en sektion per sak i skissens form: måttets namn, kedjan
/// (saken först, sedan följdfelen, med pilar), övningen, tanken och "klart när"
/// som ett villkor i tal.
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

/// En sak: rubriken med ordningen, kedjan, övningen, tanken och villkoret.
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
                .padding(.bottom, 14)

            Sektion {
                HStack(alignment: .top, spacing: 6) {
                    ForEach(Array(sak.kedja.enumerated()), id: \.offset) { i, l in
                        if i > 0 {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.tertiary)
                                .padding(.top, 24)
                        }
                        Lanken(lank: l, forst: i == 0)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    // Kedjan har alltid tre platser, så att talen står på samma ställe.
                    ForEach(sak.kedja.count..<max(sak.kedja.count, 3), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                    }
                }
            }

            Sektion(etikett: "Övning") {
                Text(sak.ovning)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let f = sak.fysik {
                    Etikett(text: "Rörlighet")
                        .padding(.top, 16)
                    Text(f)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
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
                HStack(alignment: .top, spacing: 12) {
                    Talruta(etikett: "Serie 1", varde: sak.serie1, enhet: sak.enhet)
                    Talruta(etikett: "Pass", varde: sak.passet, enhet: sak.enhet)
                    Talruta(etikett: "Pass i rad", varde: "\(sak.iRad)", enhet: "/ \(sak.iRadKrav)")
                }
                .padding(.top, 14)
            }
        }
    }

    /// Ett mått i kedjan: namnet, talet nu och passet saken valdes på → nu.
    private struct Lanken: View {
        let lank: AttJobbaPaVisning.Lank
        let forst: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(lank.namn)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(forst ? Theme.text : Theme.secondary)
                    .lineLimit(1)
                StortTal(varde: lank.varde, enhet: lank.enhet, storlek: 22, enhetStorlek: 12)
                Text(lank.fran)
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(Theme.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private struct Talruta: View {
        let etikett: String
        let varde: String
        let enhet: String

        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Etikett(text: etikett)
                StortTal(varde: varde, enhet: enhet, storlek: 26, enhetStorlek: 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
