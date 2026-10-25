import SwiftUI
import Swing
import Capture

// Inspelningens skärm (PLAN S2j, BESLUT B85, METOD MS32): ovanpå kamerans bild bara det som
// kräver ställningstagande. Överst Close, statusen och kugghjulet (under serien bara REC-pillen),
// en varning i taget, lutningen när den är för stor, och inspelningsknappen nere i mitten.
// Resten står i kugghjulets blad. Värden in, så att provet kan rita lägena utan kamera.
// Heldragna svarta rutor med vit text, så att texten syns mot all video.

struct InspelningsLager: View {
    let status: InspelningsStatus
    let varning: InspelningsVarning?
    /// Lutningen när den visas (LutningsVisare); nil = inget mitt på skärmen.
    var lutning: Lutning? = nil
    var stangEtikett: LocalizedStringKey = "Close"
    var stangAktiv = true
    var kanSpelaIn = true
    var arbetar = false
    /// Ljusprovets kort efter ett prov (startat i kugghjulet).
    var ljusprov: [ReceiptRow]? = nil
    var onStang: () -> Void = {}
    var onInstallningar: () -> Void = {}
    var onKnapp: () -> Void = {}
    var onByt: () -> Void = {}

    private var inspelar: Bool {
        if case .spelarIn = status { return true }
        return false
    }

    var body: some View {
        ZStack {
            if let lutning { LutningVy(lutning: lutning) }
            VStack(spacing: 12) {
                topp
                if let varning {
                    VarningsRuta(varning: varning, onByt: varning.bytTill != nil ? onByt : nil)
                }
                Spacer(minLength: 0)
                if let ljusprov, !inspelar {
                    ReceiptCard(rows: ljusprov).padding(.horizontal, 16)
                }
                knappRad
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder private var topp: some View {
        if inspelar {
            StatusPill(status: status).padding(.horizontal, 16)
        } else {
            // En rad som i skissen; med stor text pillen under knapparna i stället för att bryta dem.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    stang.frame(maxWidth: .infinity, alignment: .leading)
                    if status.text != nil { StatusPill(status: status).fixedSize() }
                    kugge.frame(maxWidth: .infinity, alignment: .trailing)
                }
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        stang
                        Spacer(minLength: 8)
                        kugge
                    }
                    if status.text != nil { StatusPill(status: status) }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var stang: some View {
        Button(action: onStang) {
            Text(stangEtikett)
                .typsnitt(15, .semibold)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(Theme.ground, in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(!stangAktiv)
        .opacity(stangAktiv ? 1 : 0.4)
    }

    private var kugge: some View {
        Button(action: onInstallningar) {
            Image(systemName: "gearshape")
                .typsnitt(20)
                .foregroundStyle(Theme.text)
                .padding(10)
                .frame(minWidth: 44, minHeight: 44)
                .background(Theme.ground, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Settings"))
    }

    private var knappRad: some View {
        HStack {
            Color.clear.frame(width: 80, height: 44)
            Spacer()
            InspelningsKnapp(inspelar: inspelar, action: onKnapp)
                .disabled(!kanSpelaIn)
                .opacity(kanSpelaIn ? 1 : 0.4)
            Spacer()
            ZStack {
                if arbetar { ProgressView().tint(Theme.text) }
            }
            .frame(width: 80, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }
}

/// Statusen överst i mitten: "● Connected" i grönt, "Searching" i grått, "Other phone lost" med
/// den gula ikonen, och under serien den röda pillen "● REC 0:42 · 3 swings". VoiceOver läser den
/// som text som ändras ofta.
struct StatusPill: View {
    let status: InspelningsStatus
    /// Punkten växer med texten (Dynamisk text).
    @ScaledMetric(relativeTo: .body) private var punkt: CGFloat = 12

    var body: some View {
        if let text = status.text {
            HStack(spacing: 8) {
                markor
                Text(verbatim: text)
                    .typsnitt(17, .bold, siffror: true)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(forgrund)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .frame(minHeight: 44)
            .background(bakgrund, in: .capsule)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: text))
            .accessibilityAddTraits([.isStaticText, .updatesFrequently])
        }
    }

    @ViewBuilder private var markor: some View {
        switch status {
        case .tappad:
            Image(systemName: "exclamationmark.triangle").foregroundStyle(Theme.varning)
                .typsnitt(15, .bold)
        case .spelarIn:
            Circle().fill(Theme.text).frame(width: punkt, height: punkt)
        case .kopplad:
            Circle().fill(Theme.live).frame(width: punkt, height: punkt)
        case .soker, .ingen:
            Circle().fill(Theme.secondary).frame(width: punkt, height: punkt)
        }
    }

    private var forgrund: Color {
        switch status {
        case .kopplad: return Theme.live
        case .soker: return Theme.secondary
        default: return Theme.text
        }
    }

    private var bakgrund: Color {
        if case .spelarIn = status { return Theme.rec }
        return Theme.ground
    }
}

/// En varning i en svart ruta med den gula ikonen och vit text; VoiceOver läser upp den när den
/// kommer. "Both phones are DTL" har knappen "Switch to FO" före första serien (BESLUT B83).
struct VarningsRuta: View {
    let varning: InspelningsVarning
    var onByt: (() -> Void)? = nil

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                rad
                Spacer(minLength: 8)
                knapp
            }
            VStack(alignment: .leading, spacing: 10) {
                rad
                knapp
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.ground, in: .rect(cornerRadius: 12))
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
        .onChange(of: varning.text, initial: true) { _, text in
            AccessibilityNotification.Announcement(text).post()
        }
    }

    private var rad: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .typsnitt(17, .bold)
                .foregroundStyle(Theme.varning)
                .accessibilityHidden(true)
            Text(verbatim: varning.text)
                .typsnitt(15, .bold)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isStaticText)
        }
    }

    @ViewBuilder private var knapp: some View {
        if let onByt, let vy = varning.bytTill {
            Button(action: onByt) {
                Text(verbatim: Texter.bytVy(vy))
                    .typsnitt(15, .semibold)
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(Theme.ground)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 36)
                    .background(Theme.text, in: .rect(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }
}

/// Inspelningsknappen som i iPhones kameraapp: en vit ring med ett rött fält, en cirkel för start
/// och en kvadrat för stopp.
struct InspelningsKnapp: View {
    let inspelar: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Theme.ground.opacity(0.35)).frame(width: 80, height: 80)
                Circle().stroke(Theme.text, lineWidth: 4).frame(width: 76, height: 76)
                RoundedRectangle(cornerRadius: inspelar ? 6 : 31)
                    .fill(Theme.recKnapp)
                    .frame(width: inspelar ? 30 : 62, height: inspelar ? 30 : 62)
            }
            .frame(width: 80, height: 80)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(inspelar ? Text("Stop") : Text("Record"))
    }
}

/// Kugghjulets blad "Recording": raderna med etikett och värde i grått, hjälplinjerna och Light
/// test. Rader som inte gäller lämnas bort av `rader`. Utan ScrollView, så att provet kan rita det;
/// inspelningen lägger det i en.
struct InspelningsInstallningar: View {
    struct Rad {
        let etikett: LocalizedStringKey
        let varde: String
    }

    enum Mikrofon { case inbyggd, extern, av }

    let rader: [Rad]
    @Binding var hjalplinjer: Bool
    var ljusprovAktivt = true
    var onLjusprov: () -> Void = {}
    var onKlar: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    rubrik
                    Spacer()
                    klar
                }
                VStack(alignment: .leading, spacing: 4) {
                    rubrik
                    klar
                }
            }
            .padding(.bottom, 8)
            ForEach(rader.indices, id: \.self) { i in
                rad(rader[i])
            }
            Toggle(isOn: $hjalplinjer) {
                Text("Guide lines").typsnitt(17).foregroundStyle(Theme.text)
            }
            .toggleStyle(Reglage())
            .frame(minHeight: 48)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
            Button(action: onLjusprov) {
                Text("Light test")
                    .typsnitt(17, .semibold)
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(!ljusprovAktivt)
            .opacity(ljusprovAktivt ? 1 : 0.4)
            .padding(.top, 12)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var rubrik: some View {
        Text("Recording").typsnitt(20, .bold).foregroundStyle(Theme.text)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private var klar: some View {
        Button(action: onKlar) {
            Text("Done").typsnitt(17, .semibold).foregroundStyle(Theme.text).frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    private func rad(_ r: Rad) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                Text(r.etikett).typsnitt(17).foregroundStyle(Theme.text)
                Spacer(minLength: 12)
                Text(verbatim: r.varde).typsnitt(17, siffror: true).foregroundStyle(Theme.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(r.etikett).typsnitt(17).foregroundStyle(Theme.text)
                Text(verbatim: r.varde).typsnitt(17, siffror: true).foregroundStyle(Theme.secondary)
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }

    /// Raderna som gäller, i skissens ordning. METOD MS32
    static func rader(roll: LinkRole, vy: Vy, andraVy: Vy?, fps: Double, lutning: Lutning?,
                      horda: (par: Int, av: Int, rest: Double?)?, minuter: Int?, tryck: Pressure,
                      mikrofon: Mikrofon?) -> [Rad] {
        func rollNamn(_ r: LinkRole) -> String? {
            switch r {
            case .lead: return Texter.inspRollStyr
            case .follow: return Texter.inspRollFolj
            case .solo: return nil
            }
        }
        var ut = [Rad(etikett: "This phone", varde: Texter.inspTelefon(roll: rollNamn(roll), vy: vy))]
        if roll != .solo, let andraVy {
            ut.append(Rad(etikett: "Other phone",
                          varde: Texter.inspTelefon(roll: rollNamn(roll == .lead ? .follow : .lead), vy: andraVy)))
        }
        if fps > 0 { ut.append(Rad(etikett: "Frame rate", varde: Texter.inspFps(Int(fps.rounded())))) }
        if let lutning {
            ut.append(Rad(etikett: "Tilt", varde: Taltext.decimal(abs(lutning.sida), digits: 1) + "°"))
        }
        if roll == .lead, let h = horda {
            ut.append(Rad(etikett: "Swings heard on both",
                          varde: Texter.inspHorda(h.par, av: h.av, ms: h.rest.map { Taltext.decimal($0 * 1000, digits: 1) })))
        }
        if let minuter { ut.append(Rad(etikett: "Storage", varde: Texter.inspMinuter(minuter))) }
        ut.append(Rad(etikett: "Thermal", varde: Receipt.pressureName(tryck).capitalized))
        if let mikrofon {
            let v: String
            switch mikrofon {
            case .inbyggd: v = Texter.inspMikInbyggd
            case .extern: v = Texter.inspMikExtern
            case .av: v = Texter.inspMikAv
            }
            ut.append(Rad(etikett: "Microphone", varde: v))
        }
        return ut
    }
}

/// Reglaget för hjälplinjerna, svartvitt (BESLUT B85: grönt bara för inspelningens status), ritat
/// med former så att provet kan rita det. VoiceOver läser det som ett reglage.
struct Reglage: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label
                Spacer(minLength: 12)
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule().fill(configuration.isOn ? Theme.text : Theme.line).frame(width: 51, height: 31)
                    Circle().fill(configuration.isOn ? Theme.ground : Theme.text).frame(width: 27, height: 27)
                        .padding(2)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(configuration.isOn ? AccessibilityTraits([.isToggle, .isSelected]) : AccessibilityTraits.isToggle)
    }
}
