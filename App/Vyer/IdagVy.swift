import SwiftUI
import Swing

/// Idag (skissens skärm 1): dagen, Starta pass, senaste passet som rader med ett
/// kompakt spann, och den första saken att jobba på. Inte inkopplad: startvyn
/// ersätts av den här när S2:s data finns.
struct IdagVy: View {
    let visning: Idagvisning
    var startaPass: () -> Void = {}
    var oppnaPasset: () -> Void = {}
    var oppnaJobba: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Idag")
                    .font(.system(size: 30, weight: .semibold))
                    .tracking(-0.6)
                    .foregroundStyle(Theme.text)
                Spacer()
                Under(text: visning.dag)
            }
            .padding(.top, 8)
            .padding(.bottom, 18)

            Button("Starta pass", action: startaPass)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.bottom, 22)

            if let senaste = visning.senaste {
                Button(action: oppnaPasset) {
                    Sektion(etikett: "Senaste passet", hoger: senaste) {
                        VStack(spacing: 0) {
                            ForEach(visning.rader, id: \.id) { r in
                                HStack(spacing: 12) {
                                    Text(r.namn)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.secondary)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    SpannVy(spann: r.spann, kompakt: true)
                                        .frame(width: 92)
                                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                                        Text(r.varde)
                                            .font(Theme.number(14))
                                            .foregroundStyle(Theme.text)
                                        Text(r.enhet)
                                            .font(.system(size: 14))
                                            .foregroundStyle(Theme.tertiary)
                                    }
                                    .frame(width: 66, alignment: .trailing)
                                }
                                .frame(minHeight: 34)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            if let f = visning.forsta {
                Button(action: oppnaJobba) {
                    Sektion(etikett: "Att jobba på") {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(f.namn)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            Text(f.tanke)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Theme.text)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 6)
                            HStack(spacing: 8) {
                                ForEach(Array(f.kedja.enumerated()), id: \.offset) { i, namn in
                                    if i > 0 {
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(Theme.tertiary)
                                    }
                                    Text(namn)
                                        .font(.system(size: 13))
                                        .foregroundStyle(i == 0 ? Theme.text : Theme.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.top, 14)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .background(Theme.ground)
    }
}
