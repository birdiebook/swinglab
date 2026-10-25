import SwiftUI
import UniformTypeIdentifiers
import Swing
import Capture
import TreD

// 3D i appen (S6c-2, BESLUT B62, METOD MS19): passets kort, raden för den andra telefonens
// paket och lutningen i uppställningen. Svartvitt, inga värdeord och ingen accent (3D övas
// aldrig, B14, B37); bara tal, enheter och korta skäl i grått (B13).

/// Passets kort "3D": rubriken "3D · no markers" och antalet svingar, de fem måtten med passets
/// median och skillnaden mot förra passet, och skälen i grått. Ett mått utan median visar "—".
/// Ett tryck på en rad öppnar infobladet (BESLUT B41).
struct TreDKortVy: View {
    let kort: TreDKort
    /// Figuren i 3D (S6d, BESLUT B73): raden "3D" under måtten öppnar den; nil = ingen figur.
    var onFigur: (() -> Void)? = nil

    var body: some View {
        Sektion(etikett: kort.rubrik, hoger: kort.svingar) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(kort.rader) { r in
                    rad(r)
                }
                if let onFigur {
                    Button(action: onFigur) {
                        HStack(spacing: 10) {
                            Image(systemName: "rotate.3d")
                                .typsnitt(15, .medium)
                                .accessibilityHidden(true)
                            Text(verbatim: Texter.treD)
                                .typsnitt(15, .semibold)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .typsnitt(13, .medium)
                                .foregroundStyle(Theme.tertiary)
                                .accessibilityHidden(true)
                        }
                        .foregroundStyle(Theme.text)
                        .frame(minHeight: 44)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.hair).frame(height: 1) }
                }
                ForEach(kort.skal, id: \.self) { s in
                    Text(verbatim: s)
                        .typsnitt(13)
                        .foregroundStyle(Theme.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func rad(_ r: TreDKort.Rad) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(verbatim: r.namn)
                .typsnitt(15)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(verbatim: r.varde.map { Tal.medEnhet($0, r.enhet) } ?? "—")
                    .typsnitt(20, .medium, siffror: true)
                    .foregroundStyle(r.varde == nil ? Theme.tertiary : Theme.text)
                if let m = r.mot {
                    Text(verbatim: m)
                        .typsnitt(12, siffror: true)
                        .foregroundStyle(r.tydlig ? Theme.secondary : Theme.tertiary)
                }
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .top) { Rectangle().fill(Theme.hair).frame(height: 1) }
        .accessibilityElement(children: .combine)
        .infoblad(r.info)
    }
}

/// "Import other phone": den andra telefonens paket ur Filer eller AirDrop (BESLUT B61), när
/// kopplingen inte fanns under passet. Grå text som Claude-raden; räkningen visas som ett hjul.
struct AnnanTelefonRad: View {
    let koppling: TreDKoppling
    /// Efter importen av slagen: klippen ur samma paket (S6g, `KlippKoppling.importera`).
    var efterImport: ((URL) async -> Void)? = nil
    @State private var valj = false

    /// Följarens överföring: "Sent", "Waiting for other phone", eller den andra telefonens nej.
    private var status: String? {
        switch koppling.status {
        case .vantar?: return String(localized: "Waiting for other phone")
        case .skickat?: return String(localized: "Sent")
        case .annatPass?: return String(localized: "Other phone has another session – Import")
        case .annanVersion?: return String(localized: "Other phone has another app version – Import")
        case nil: return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let status {
                Text(verbatim: status)
                    .typsnitt(13)
                    .foregroundStyle(Theme.tertiary)
                    .padding(.top, 8)
            }
            HStack(spacing: 12) {
                Button("Import other phone") { valj = true }
                    .typsnitt(15, .medium)
                    .foregroundStyle(Theme.secondary)
                    .frame(minHeight: 44)
                    .disabled(koppling.raknar)
                Spacer(minLength: 0)
                if koppling.raknar { ProgressView().controlSize(.small) }
            }
            if let p = koppling.problem {
                Text(verbatim: p)
                    .typsnitt(13, .semibold)
                    .foregroundStyle(Theme.text)
            }
            if let v = koppling.varning {
                Text(verbatim: v)
                    .typsnitt(13)
                    .foregroundStyle(Theme.tertiary)
            }
        }
        .overlay(alignment: .top) { Rectangle().fill(Theme.hair).frame(height: 1) }
        .fileImporter(isPresented: $valj, allowedContentTypes: [.zip]) { r in
            if case let .success(url) = r {
                Task {
                    await koppling.importera(url)
                    await efterImport?(url)
                }
            }
        }
    }
}

/// Lutningen mitt på skärmen (B39, B85, MS17, MS19, MS32): en vit horisontlinje genom bildens
/// mitt, vriden med lutningen åt sidan, bildens vågräta streckad, och under den en svart ruta med
/// talet i hela grader och "Level the phone"; över 45° från lodlinjen är talet den vinkeln
/// (`LutningsVisare.vinkel`), och med två telefoner står också "Tilt too large for 3D" där. Svartvitt. Inspelningen visar den bara när lutningen är för stor (`LutningsVisare`).
struct LutningVy: View {
    let lutning: Lutning?
    /// Raden "Tilt too large for 3D" över 45°: bara med två telefoner (B85).
    var for3D = true

    var body: some View {
        if let l = lutning {
            GeometryReader { geo in
                let m = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                ZStack {
                    Canvas { c, s in
                        let v = l.sida * .pi / 180
                        let r = s.width * 0.42
                        let d = CGPoint(x: cos(v) * r, y: sin(v) * r)
                        // Bildens vågräta, streckad: avståndet till linjen är lutningen.
                        var h = Path()
                        h.move(to: CGPoint(x: m.x - r, y: m.y))
                        h.addLine(to: CGPoint(x: m.x + r, y: m.y))
                        c.stroke(h, with: .color(Theme.text.opacity(0.7)), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                        var p = Path()
                        p.move(to: CGPoint(x: m.x - d.x, y: m.y - d.y))
                        p.addLine(to: CGPoint(x: m.x + d.x, y: m.y + d.y))
                        c.stroke(p, with: .color(Theme.text), lineWidth: 3)
                    }
                    VStack(spacing: 2) {
                        Text(verbatim: LutningsVisare.text(l))
                            .typsnitt(28, .bold, siffror: true)
                        Text(verbatim: Texter.inspLutning)
                            .typsnitt(15, .semibold)
                        if l.forStorFor3D, for3D {
                            Text(verbatim: Texter.lutningForStor)
                                .typsnitt(13, .semibold)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.ground, in: .rect(cornerRadius: 12))
                    .frame(maxWidth: geo.size.width - 64)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits([.isStaticText, .updatesFrequently])
                    .padding(.top, m.y + 28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .allowsHitTesting(false)
        }
    }
}
