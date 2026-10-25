import SwiftUI
import Swing

/// Passet (skissens skärm 5): dagen, filtret Alla/DTL/FO, klubban och slagen, och korten i
/// läsordningen (PLAN S4h, BESLUT B94): överst Focus eller de röda måtten, sedan korten rött, gult
/// och grönt, och sist "More measures (n)" med de mått som inte kan säga bra eller dåligt, ett
/// tryck bort. Datan kommer som värden (Passvisning), så att provet kan rita skärmen utan app och
/// utan telefon. Inne i en session (`vy`) visas bara sessionens vy, utan filtret (PLAN S4e, BESLUT B64).
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
    /// "More measures" utfällt (provet ritar det utfällt).
    @State private var visaFler: Bool

    init(visning: Passvisning, filter: Passvisning.Filter = .alla, vy: Vy? = nil, navrad: Bool = true,
         visaFler: Bool = false, tillbaka: @escaping () -> Void = {}, dela: @escaping () -> Void = {}) {
        self.visning = visning
        self.tillbaka = tillbaka
        self.dela = dela
        self.navrad = navrad
        self.vy = vy
        _filter = State(initialValue: filter)
        _visaFler = State(initialValue: visaFler)
    }

    /// Korten som visas i läsordningen: sessionens vy, eller filtrets (PLAN S4h).
    private var lista: Passlista {
        vy.map { visning.lista(i: $0) } ?? visning.lista(filter)
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
            let l = lista
            if let topp = l.topp {
                PassToppVy(topp: topp, upplasning: l.toppUpplasning ?? "")
            }
            ForEach(l.kort) { kort in
                MattkortVy(kort: kort)
            }
            if let rad = l.flerRad {
                FlerRad(text: rad, oppen: visaFler) { visaFler.toggle() }
                if visaFler {
                    ForEach(l.fler) { kort in
                        MattkortVy(kort: kort)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .background(Theme.ground)
    }
}

/// Passets översta kort (PLAN S4h, BESLUT B94): Focus (måtten som övas, rubriken i accenten,
/// BESLUT B31) eller de röda måtten, ett per rad med namnet, talet och läget. Korten står också i
/// listan under; det här är vad man läser först.
struct PassToppVy: View {
    let topp: Passlista.Topp
    var upplasning = ""
    /// Lägets symbol växer med texten (research 8 punkt 10).
    @ScaledMetric(relativeTo: .body) private var symbol: CGFloat = 12

    private var focus: Bool {
        if case .focus = topp { return true }
        return false
    }

    var body: some View {
        Sektion {
            VStack(alignment: .leading, spacing: 10) {
                Etikett(text: topp.rubrik, farg: focus ? Theme.acc : Theme.tertiary)
                ForEach(topp.kort) { k in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(verbatim: k.namn)
                            .typsnitt(16, .medium)
                            .foregroundStyle(Theme.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Text(verbatim: Tal.medEnhet(k.varde, k.varde == "—" ? "" : k.enhet))
                            .typsnitt(17, .medium, siffror: true)
                            .foregroundStyle(Theme.text)
                        LageSymbol(lage: k.lage, storlek: symbol)
                            .frame(width: symbol)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(upplasning)
    }
}

/// Raden längst ner i passet: "More measures (n)" och en pil; ett tryck fäller ut korten utan dom
/// (PLAN S4h, BESLUT B94).
struct FlerRad: View {
    let text: String
    let oppen: Bool
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(verbatim: text)
                    .foregroundStyle(Theme.secondary)
                Spacer(minLength: 8)
                Image(systemName: oppen ? "chevron.up" : "chevron.down")
                    .typsnitt(13, .semibold)
                    .foregroundStyle(Theme.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(RowButtonStyle())
        .accessibilityValue(oppen ? Text(verbatim: Texter.oppen) : Text(verbatim: Texter.stangd))
    }
}
