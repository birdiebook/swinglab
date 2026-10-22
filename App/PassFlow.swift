import SwiftUI
import Swing
import Capture

/// Ett nytt pass från startvyn: uppställningen, sedan kameran (S2c) eller Bilder (S2d).
/// Formspråket är BESLUT B13 med systemvyer i mörkt läge; S4 ger formen senare.
struct PassFlowView: View {
    enum Mode: String, Identifiable {
        case record, photos
        var id: String { rawValue }
    }

    let mode: Mode
    var onClose: () -> Void

    @Environment(Store.self) private var store
    @State private var setup = PassSetup()
    @State private var pass: PassState?

    var body: some View {
        if let binding = Binding($pass) {
            switch mode {
            case .record: RecordView(pass: binding, onClose: onClose)
            case .photos: ImportView(pass: binding, onClose: onClose)
            }
        } else {
            NavigationStack {
                SetupView(setup: $setup, primary: mode == .record ? "Kamera" : "Välj klipp") {
                    pass = store.newPass(setup: setup)
                }
                .navigationTitle(mode == .record ? "Nytt pass" : "Hämta ur Bilder")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Stäng", action: onClose) }
                }
            }
        }
    }
}

/// Uppställningen: vy, spelhand, klubba och avstånd till bollen (S2_SPEC §4.4, §5).
struct SetupView: View {
    @Binding var setup: PassSetup
    let primary: String
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Picker("Vy", selection: $setup.view) {
                    Text("DTL").tag(Vy.dtl)
                    Text("FO").tag(Vy.fo)
                }
                .pickerStyle(.segmented)
                Picker("Spelhand", selection: $setup.hand) {
                    Text("Höger").tag(Hand.hoger)
                    Text("Vänster").tag(Hand.vanster)
                }
                .pickerStyle(.segmented)
                Picker("Klubba", selection: $setup.club) {
                    ForEach(PassSetup.clubs, id: \.self) { Text(PassSetup.clubLabel($0)).tag($0) }
                }
                Stepper(value: $setup.distance, in: PassSetup.distanceRange, step: PassSetup.distanceStep) {
                    HStack {
                        Text("Avstånd")
                        Spacer()
                        Text("\(Swedish.decimal(setup.distance, digits: 1)) m").font(Theme.number(17))
                    }
                }
            }
            .scrollContentBackground(.hidden)

            Button(primary, action: onConfirm)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .background(Theme.ground, ignoresSafeAreaEdges: .all)
    }
}

/// Raderna i ett kvitto eller ljusprovets kort: etikett, tal, en färg per rad.
struct ReceiptCard: View {
    var title: String?
    let rows: [ReceiptRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
                    .padding(.bottom, 6)
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    Text(row.label).foregroundStyle(Theme.secondary)
                    Spacer(minLength: 8)
                    if row.light != .good {
                        Circle()
                            .strokeBorder(Theme.flag, lineWidth: 1.5)
                            .background(Circle().fill(row.light == .tooDark ? Theme.flag : .clear))
                            .frame(width: 8, height: 8)
                    }
                    Text(row.value)
                        .font(Theme.number(17))
                        .foregroundStyle(row.light == .good ? Theme.text : Theme.flag)
                }
                .font(.system(size: 15))
                .frame(minHeight: 30)
            }
        }
        .padding(14)
        .background(Theme.surface, in: .rect(cornerRadius: 4))
    }
}

/// En serie som värden ur filen. Samma väg för en inspelning och ett importerat
/// original (S2_SPEC §3); vyn lägger till den i passet och sparar.
enum SeriesMaker {
    static func make(url: URL, nr: Int, file: String, source: SeriesSource, club: String, start: Date,
                     startHost: Double?, microphone: String?) async throws -> SeriesRecord {
        let facts = try await MediaReader.facts(url, microphone: microphone)
        return SeriesRecord.make(nr: nr, source: source, club: club, file: file, start: start,
                                 startHost: startHost, facts: facts)
    }
}
