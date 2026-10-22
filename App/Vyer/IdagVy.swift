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

    private func namn(_ r: Idagvisning.Rad) -> some View {
        Text(r.namn)
            .typsnitt(14)
            .foregroundStyle(r.ovas ? Theme.acc : Theme.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Talet med enheten direkt efter för grader ("+2.0°").
    private func tal(_ r: Idagvisning.Rad) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: r.enhet == "°" ? 0 : 2) {
            Text(r.varde)
                .typsnitt(14, .medium, siffror: true)
                .foregroundStyle(Theme.text)
            Text(r.enhet)
                .typsnitt(14)
                .foregroundStyle(Theme.tertiary)
        }
        .fixedSize()
    }

    private var rubrik: some View {
        Text("Today")
            .tracking(-0.6)
            .typsnitt(30, .semibold)
            .foregroundStyle(Theme.text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Rubriken och dagen bredvid varandra, eller under varandra med stor text.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    rubrik.fixedSize()
                    Spacer()
                    Under(text: visning.dag).fixedSize()
                }
                VStack(alignment: .leading, spacing: 4) {
                    rubrik
                    Under(text: visning.dag)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 18)

            Button("Start session", action: startaPass)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.bottom, 22)

            if let senaste = visning.senaste {
                Button(action: oppnaPasset) {
                    Sektion(etikett: String(localized: "Last session"), hoger: senaste) {
                        VStack(spacing: 0) {
                            ForEach(visning.rader, id: \.id) { r in
                                // En rad när den får plats; med stor text namnet över spannet och talet.
                                ViewThatFits(in: .horizontal) {
                                    HStack(spacing: 12) {
                                        namn(r).frame(maxWidth: .infinity, alignment: .leading)
                                        SpannVy(spann: r.spann, kompakt: true, accent: r.ovas)
                                            .frame(minWidth: 40, idealWidth: 92, maxWidth: 92)
                                        tal(r).frame(minWidth: 66, alignment: .trailing)
                                            .layoutPriority(1)
                                    }
                                    VStack(alignment: .leading, spacing: 6) {
                                        namn(r)
                                        HStack(spacing: 12) {
                                            SpannVy(spann: r.spann, kompakt: true, accent: r.ovas)
                                            tal(r)
                                        }
                                    }
                                    .padding(.vertical, 6)
                                }
                                .frame(minHeight: 34)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(r.upplasning)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            if let f = visning.forsta {
                Button(action: oppnaJobba) {
                    Sektion(etikett: String(localized: "Work on")) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(f.namn)
                                .typsnitt(22, .semibold)
                                .foregroundStyle(Theme.text)
                            Text(f.tanke)
                                .typsnitt(20, .medium)
                                .foregroundStyle(Theme.text)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 6)
                            Radbrytning(mellan: 8) {
                                ForEach(Array(f.kedja.enumerated()), id: \.offset) { i, namn in
                                    if i > 0 {
                                        Image(systemName: "arrow.right")
                                            .typsnitt(10, .semibold)
                                            .foregroundStyle(Theme.tertiary)
                                    }
                                    Text(namn)
                                        .typsnitt(13)
                                        .foregroundStyle(i == 0 ? Theme.acc : Theme.secondary)
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
