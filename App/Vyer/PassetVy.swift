import SwiftUI
import Swing

/// Passet (skissens skärm 5): dagen, filtret Alla/FO/DTL, klubban och slagen, och
/// ett kort per mått i katalogens ordning. Datan kommer som värden (Passvisning),
/// så att provet kan rita skärmen utan app och utan telefon. Inne i en session (`vy`) visas
/// bara sessionens vy, utan filtret (PLAN S4e, BESLUT B64).
struct PassetVy: View {
    let visning: Passvisning
    var tillbaka: () -> Void = {}
    var dela: () -> Void = {}
    /// Raden överst (tillbaka, dagen, dela); utan den när passet visas inne i slagens skärm
    /// efter Analyze, som har sin egen (S4b).
    var navrad = true
    /// Sessionens vy: bara dess kort, genom katalogens vy (`Vyfilter`), och vyns namn i
    /// stället för filtret. nil = filtret Alla/FO/DTL (skissen).
    var vy: Vy? = nil
    @State private var filter: Passvisning.Filter

    init(visning: Passvisning, filter: Passvisning.Filter = .alla, vy: Vy? = nil, navrad: Bool = true,
         tillbaka: @escaping () -> Void = {}, dela: @escaping () -> Void = {}) {
        self.visning = visning
        self.tillbaka = tillbaka
        self.dela = dela
        self.navrad = navrad
        self.vy = vy
        _filter = State(initialValue: filter)
    }

    /// Korten som visas: sessionens vy, eller filtrets.
    private var korten: [Mattkort] {
        vy.map { visning.kort(i: $0) } ?? visning.filtrerat(filter)
    }

    @ViewBuilder private var vanster: some View {
        if let vy {
            Text(verbatim: Texter.vyNamn(vy))
                .typsnitt(15, .semibold)
                .foregroundStyle(Theme.text)
        } else {
            segment
        }
    }

    private var segment: some View {
        Segment(alternativ: Passvisning.Filter.allCases.map(\.etikett), valt: Binding(
            get: { Passvisning.Filter.allCases.firstIndex(of: filter) ?? 0 },
            set: { filter = Passvisning.Filter.allCases[$0] }))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if navrad {
                Navrad(titel: visning.titel, hoger: {
                    Button(action: dela) {
                        Image(systemName: "square.and.arrow.up")
                            .typsnitt(17, .medium)
                            .foregroundStyle(Theme.secondary)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                }, tillbaka: tillbaka)
            }
            ViewThatFits(in: .horizontal) {
                HStack {
                    vanster
                    Spacer()
                    Under(text: visning.undertitel).fixedSize()
                }
                VStack(alignment: .leading, spacing: 8) {
                    vanster
                    Under(text: visning.undertitel)
                }
            }
            .padding(.bottom, 6)
            ForEach(korten) { kort in
                MattkortVy(kort: kort)
            }
        }
        .padding(.horizontal, 20)
        .background(Theme.ground)
    }
}
