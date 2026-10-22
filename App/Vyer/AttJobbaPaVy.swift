import SwiftUI
import Swing

/// Att jobba på (skissens skärm 6): temat, kedjan som tre mått med pilar (det första
/// först), övningen med sina steg, tanken och "klart när" som ett villkor i tal.
struct AttJobbaPaVy: View {
    let visning: AttJobbaPaVisning
    var tillbaka: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Navrad(titel: "Att jobba på", hoger: { Under(text: visning.block) }, tillbaka: tillbaka)
            Text(visning.tema)
                .font(.system(size: 30, weight: .semibold))
                .tracking(-0.6)
                .foregroundStyle(Theme.text)
                .padding(.top, 8)
                .padding(.bottom, 14)

            Sektion {
                HStack(alignment: .top, spacing: 6) {
                    ForEach(Array(visning.kedja.enumerated()), id: \.offset) { i, l in
                        if i > 0 {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.tertiary)
                                .padding(.top, 24)
                        }
                        Lanken(lank: l, forst: i == 0)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            Sektion(etikett: "Övning") {
                Text(visning.ovning)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Theme.text)
                HStack(alignment: .top, spacing: 4) {
                    ForEach(Array(visning.steg.enumerated()), id: \.offset) { _, s in
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

            Sektion(etikett: "Tanke") {
                Text(visning.tanke)
                    .font(.system(size: 30, weight: .medium))
                    .tracking(-0.3)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }

            Sektion(etikett: "Klart när") {
                Text(visning.villkor)
                    .font(Theme.number(20))
                    .foregroundStyle(Theme.text)
                    .padding(.top, 6)
                Under(text: visning.villkorUnder)
                    .padding(.top, 4)
                HStack(alignment: .top, spacing: 12) {
                    Talruta(etikett: "Serie 1", varde: visning.serie1, enhet: visning.enhet)
                    Talruta(etikett: "Pass", varde: visning.passet, enhet: visning.enhet)
                    Talruta(etikett: "Pass i rad", varde: "\(visning.iRad)", enhet: "/ \(visning.iRadKrav)")
                }
                .padding(.top, 14)
            }
        }
        .padding(.horizontal, 20)
        .background(Theme.ground)
    }

    /// Ett mått i kedjan: namnet, talet nu och blockets början → nu.
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
