import SwiftUI
import Swing

/// Idag (skissens skärm 1, fliken Today i S4c): dagen, Starta pass, senaste passet som
/// rader med ett kompakt spann (det som övas i accenten, BESLUT B31), och sakerna att
/// jobba på med tanken. Datan kommer som värden (Idagvisning ur passen på telefonen),
/// så att provet kan rita skärmen.
struct IdagVy: View {
    let visning: Idagvisning
    var startaPass: () -> Void = {}
    /// Hämta ur Bilder (S2d); nil = raden visas inte.
    var importera: (() -> Void)? = nil
    var oppnaPasset: () -> Void = {}
    var oppnaJobba: () -> Void = {}
    /// Bladet som visas (BESLUT B41): ⓘ på en rad eller radens VoiceOver-åtgärd.
    @State private var blad: Infoblad?

    private func namn(_ r: Idagvisning.Rad) -> some View {
        Text(r.namn)
            .typsnitt(14)
            .foregroundStyle(r.ovas ? Theme.acc : Theme.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Talet med enheten direkt efter för grader ("+2.0°"); "—" grått och utan enhet.
    private func tal(_ r: Idagvisning.Rad) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: r.enhet == "°" ? 0 : 2) {
            Text(r.varde)
                .typsnitt(14, .medium, siffror: true)
                .foregroundStyle(r.varde == "—" ? Theme.tertiary : Theme.text)
            if r.varde != "—" {
                Text(r.enhet)
                    .typsnitt(14)
                    .foregroundStyle(Theme.tertiary)
            }
        }
        .fixedSize()
    }

    /// Spannet; tempot utan säker start bakifrån har inget (METOD M40).
    @ViewBuilder
    private func spann(_ r: Idagvisning.Rad) -> some View {
        if let s = r.spann {
            SpannVy(spann: s, kompakt: true, accent: r.ovas)
        } else {
            Color.clear.frame(height: 1)
        }
    }

    /// En sak: måttets namn, tanken och kedjan (saken i accenten).
    private func sak(_ f: Idagvisning.Forsta) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(f.namn)
                .typsnitt(22, .semibold)
                .foregroundStyle(Theme.text)
            Text(f.tanke)
                .typsnitt(20, .medium)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            if f.kedja.count > 1 {
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .padding(.bottom, importera == nil ? 22 : 8)
            if let importera {
                Button("Import from Photos", action: importera)
                    .buttonStyle(RowButtonStyle())
                    .padding(.bottom, 14)
            }

            if let senaste = visning.senaste {
                // Ett tryck på sektionen öppnar passet; raden ⓘ öppnar bladet (BESLUT B41),
                // så sektionen är ingen Button (en knapp i en knapp tar fel tryck).
                VStack(spacing: 0) {
                    Sektion(etikett: String(localized: "Last session"), hoger: senaste) {
                        VStack(spacing: 0) {
                            ForEach(visning.rader, id: \.id) { r in
                                // En rad när den får plats; med stor text namnet över spannet och talet.
                                ViewThatFits(in: .horizontal) {
                                    HStack(spacing: 12) {
                                        namn(r).frame(maxWidth: .infinity, alignment: .leading)
                                        spann(r)
                                            .frame(minWidth: 40, idealWidth: 92, maxWidth: 92)
                                        tal(r).frame(minWidth: 66, alignment: .trailing)
                                            .layoutPriority(1)
                                        InfoKnapp(blad: r.info) { blad = r.info }
                                    }
                                    VStack(alignment: .leading, spacing: 6) {
                                        namn(r)
                                        HStack(spacing: 12) {
                                            spann(r)
                                            tal(r)
                                            InfoKnapp(blad: r.info) { blad = r.info }
                                        }
                                    }
                                    .padding(.vertical, 6)
                                }
                                .frame(minHeight: 34)
                                // VoiceOver: dubbeltryck öppnar passet som förut, och bladet är en
                                // namngiven åtgärd på raden (BESLUT B41).
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(r.upplasning)
                                .accessibilityAddTraits(.isButton)
                                .accessibilityAction { oppnaPasset() }
                                .accessibilityAction(named: Text("About the measure")) { blad = r.info }
                            }
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: oppnaPasset)
                .accessibilityAddTraits(.isButton)
            }

            if !visning.fokus.isEmpty {
                Button(action: oppnaJobba) {
                    Sektion(etikett: String(localized: "Focus"), hoger: visning.vecka) {
                        VStack(alignment: .leading, spacing: 22) {
                            ForEach(Array(visning.fokus.enumerated()), id: \.offset) { _, f in
                                sak(f)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .background(Theme.ground)
        .sheet(item: $blad) { InfobladArk(blad: $0) }
    }
}
