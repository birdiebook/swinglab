import SwiftUI
import Swing
import Capture

// Ett parat pass på den styrande telefonen (S6g, BESLUT B82, METOD MS31): en rad "Paired" i
// Sessions, och inne i passet växlingen DTL, FO och 3D med raden om vad som finns ("14 swings · 12
// from both phones"), förloppet och "Get full video". Formspråket B13: svartvitt, etiketter och
// tal, ingen förklarande text. Allt som värden, så att provet kan rita det.

/// Valet i passet: en av vyerna eller 3D.
enum Parvy: Int, CaseIterable {
    case dtl, fo, treD

    var vy: Vy? {
        switch self {
        case .dtl: return .dtl
        case .fo: return .fo
        case .treD: return nil
        }
    }

    static func av(_ vy: Vy) -> Parvy { vy == .dtl ? .dtl : .fo }

    var etikett: String {
        switch self {
        case .dtl: return Texter.vyKort(.dtl)
        case .fo: return Texter.vyKort(.fo)
        case .treD: return Texter.treD
        }
    }
}

/// Huvudet i ett parat pass som värden.
struct ParadLage: Equatable {
    /// Den här telefonens vy.
    var egen: Vy
    var valt: Parvy
    /// "14 swings · 12 from both phones"
    var franBada: String?
    /// "Getting video from other phone · 60 %", eller nil när inget pågår.
    var forlopp: String?
    /// Den andra telefonen har samma vy (BESLUT B83).
    var sammaVy = false
    /// "Get full video" går att begära (någon parad serie saknas hel och originalen finns); visas
    /// bara när den andra vyn är vald (BESLUT B84).
    var kanHamtaHela = true
    var hamtarHela = false
    /// Den styrandes slag som har den andra vyns video, och de av dem där klicket inte hördes.
    var annanKlipp: Set<String> = []
    var utanKlick: Set<String> = []

    /// Valet visar den andra telefonens vy.
    var annan: Bool { valt.vy.map { $0 != egen } ?? false }
}

/// Växlingen och raderna under passets rubrik.
struct ParadHuvud: View {
    let lage: ParadLage
    var onVal: (Parvy) -> Void = { _ in }
    var onHela: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Segment(alternativ: Parvy.allCases.map(\.etikett), valt: Binding(
                get: { lage.valt.rawValue }, set: { onVal(Parvy(rawValue: $0) ?? .dtl) }))
                .padding(.bottom, 4)
            if let f = lage.franBada {
                Text(verbatim: f)
                    .typsnitt(14, siffror: true)
                    .foregroundStyle(Theme.secondary)
            }
            if let f = lage.forlopp {
                Text(verbatim: f)
                    .typsnitt(13, siffror: true)
                    .foregroundStyle(Theme.tertiary)
            }
            if lage.sammaVy {
                // Vit som felraden i B60: signalfärgen är bara för uppställningen (B13).
                Text(verbatim: Texter.sammaVyIPasset)
                    .typsnitt(13, .semibold)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if lage.kanHamtaHela && lage.annan {
                Button(action: onHela) {
                    Text("Get full video")
                        .typsnitt(15, .medium)
                        .foregroundStyle(lage.hamtarHela ? Theme.tertiary : Theme.secondary)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(lage.hamtarHela)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Svingarna i den andra vyn (B84): numret, serien och tiden, och om den andra telefonens video
/// finns ("—" annars) eller kom utan klick. Inga miniatyrer ur den här vyns video och inget utsnitt
/// att redigera; ett tryck öppnar granskningen med den andra vyn vald.
struct AnnanSlagLista: View {
    let pass: PassState
    let lage: ParadLage
    var onTryck: (String) -> Void = { _ in }

    var body: some View {
        let rader = ShotRow.rows(pass).filter { r in pass.shots.first { $0.id == r.id }?.wantsDetail == true }
        VStack(alignment: .leading, spacing: 0) {
            Skarmrubrik("Shots")
                .padding(.bottom, 8)
            ForEach(rader) { r in
                Button { onTryck(r.id) } label: {
                    HStack(spacing: 14) {
                        Text(verbatim: "\(r.number)")
                            .typsnitt(22, .medium, siffror: true)
                            .foregroundStyle(Theme.text)
                        Text(verbatim: String(localized: "Set \(r.series)") + Texter.skilje + String(localized: "\(r.time) s"))
                            .typsnitt(13, siffror: true)
                            .foregroundStyle(Theme.secondary)
                        Spacer(minLength: 8)
                        if !lage.annanKlipp.contains(r.id) {
                            Text(verbatim: Texter.ingenVideo)
                                .typsnitt(15)
                                .foregroundStyle(Theme.tertiary)
                        } else if lage.utanKlick.contains(r.id) {
                            Text(verbatim: Texter.ingetKlickKort)
                                .typsnitt(13)
                                .foregroundStyle(Theme.tertiary)
                        }
                    }
                    .padding(.vertical, 12)
                    .frame(minHeight: 52)
                    .contentShape(.rect)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.hair).frame(height: 1) }
                }
                .buttonStyle(.plain)
                .disabled(!lage.annanKlipp.contains(r.id))
            }
        }
        .padding(20)
    }
}

/// Raden i Sessions: den styrandes parade pass som "Paired" med länken, följarens som sin vy med
/// "paired" (BESLUT B82).
struct SessionRadRubrik: View {
    let rad: Sessionsrad

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if rad.styr {
                Image(systemName: "link")
                    .typsnitt(13, .semibold)
                    .foregroundStyle(Theme.secondary)
            }
            Text(verbatim: rad.vyNamn)
                .typsnitt(17, .medium)
                .foregroundStyle(Theme.text)
            if rad.parad && !rad.styr {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Image(systemName: "link")
                        .typsnitt(11, .semibold)
                    Text(verbatim: Texter.parad)
                        .typsnitt(13)
                }
                .foregroundStyle(Theme.secondary)
            }
        }
    }
}

/// Uppställningens varning när båda telefonerna har samma vy (BESLUT B83): i signalfärgen, som
/// uppställningens andra varningar, och en knapp som byter den här telefonens vy innan första
/// serien. Värden in, så att provet kan rita den.
struct SammaVyVarning: View {
    let vy: Vy
    /// Byt den här telefonens vy; nil när passet redan har serier.
    var onByt: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Text(verbatim: Texter.sammaVy(vy))
                .typsnitt(15, .semibold)
                .foregroundStyle(Theme.flag)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if let onByt {
                Button(action: onByt) {
                    Text(verbatim: Texter.bytVy(Vyvakt.annan(vy)))
                        .typsnitt(15, .semibold)
                        .foregroundStyle(Theme.ground)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 36)
                        .background(Theme.text, in: .rect(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.black.opacity(0.6), in: .rect(cornerRadius: 4))
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
    }
}
