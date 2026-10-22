import SwiftUI
import Swing
import Capture

/// Ett nytt pass från startvyn: uppställningen, sedan kameran (S2c) eller Bilder (S2d),
/// och efter kvittot Continue till passet med slagen och Analyze (S2e). Passet står
/// redan i startvyns lista när första serien sparats. Formspråket är BESLUT B13 med
/// systemvyer i mörkt läge; S4 ger formen senare.
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
    /// Efter Continue: passet med slagen.
    @State private var shots = false
    /// Serierna som ännu inte redigerats, i tur före slagen (S2i).
    @State private var editQueue: [Int] = []

    var body: some View {
        if shots, let pass {
            if let nr = editQueue.first {
                ClipEditorView(passID: pass.id, seriesNr: nr) { editQueue.removeFirst() }
                    .id(nr)
            } else {
                PassShotsView(passID: pass.id, onClose: onClose)
            }
        } else if let binding = Binding($pass) {
            switch mode {
            case .record: RecordView(pass: binding, onClose: onClose, onContinue: proceed)
            case .photos: ImportView(pass: binding, onClose: onClose, onContinue: proceed)
            }
        } else {
            NavigationStack {
                SetupView(setup: $setup, titel: mode == .record ? "New session" : "Import from Photos",
                          primary: mode == .record ? "Camera" : "Choose clips") {
                    pass = store.newPass(setup: setup)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Close", action: onClose) }
                }
            }
        }
    }

    /// Continue: först redigeraren för varje serie som inte redigerats (fönstret och
    /// utsnittet, S2i), sedan passet med slagen och Analyze.
    private func proceed() {
        if let id = pass?.id {
            editQueue = store.load(id)?.series.filter { $0.edit == nil }.map(\.nr) ?? []
        }
        shots = true
    }
}

/// Uppställningen: vy, spelhand, klubba och avstånd till bollen (S2_SPEC §4.4, §5).
struct SetupView: View {
    @Binding var setup: PassSetup
    /// Rubriken står i innehållet, inte i navigeringsraden, så att den bryts i stället
    /// för att kortas vid största textstorleken.
    let titel: LocalizedStringKey
    let primary: LocalizedStringKey
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Skarmrubrik(titel)
                .padding(.horizontal, 20)
            Form {
                Picker("View", selection: $setup.view) {
                    Text("DTL").tag(Vy.dtl)
                    Text("FO").tag(Vy.fo)
                }
                .pickerStyle(.segmented)
                Picker("Hand", selection: $setup.hand) {
                    Text("Right").tag(Hand.hoger)
                    Text("Left").tag(Hand.vanster)
                }
                .pickerStyle(.segmented)
                Picker("Club", selection: $setup.club) {
                    ForEach(PassSetup.clubs, id: \.self) { Text(verbatim: PassSetup.clubLabel($0)).tag($0) }
                }
                Stepper(value: $setup.distance, in: PassSetup.distanceRange, step: PassSetup.distanceStep) {
                    HStack {
                        Text("Distance")
                        Spacer()
                        Text(verbatim: "\(Taltext.decimal(setup.distance, digits: 1)) m").font(Theme.number(17))
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
