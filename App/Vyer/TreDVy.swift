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

    var body: some View {
        Sektion(etikett: kort.rubrik, hoger: kort.svingar) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(kort.rader) { r in
                    rad(r)
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

/// Uppställningens lutning (B39, MS17, MS19): en tunn horisontlinje genom bildens mitt, vriden
/// med lutningen åt sidan, och talet i grader. Över 45° från lodlinjen: "Tilt too large for 3D".
/// Svartvitt och utan värdeord. Utan prov (simulatorn) ritas inget.
struct LutningVy: View {
    let lutning: Lutning?

    var body: some View {
        if let l = lutning {
            ZStack {
                Canvas { c, s in
                    let v = l.sida * .pi / 180
                    let r = s.width * 0.36
                    let m = CGPoint(x: s.width / 2, y: s.height / 2)
                    let d = CGPoint(x: cos(v) * r, y: sin(v) * r)
                    c.linje(CGPoint(x: m.x - d.x, y: m.y - d.y), CGPoint(x: m.x + d.x, y: m.y + d.y),
                            Theme.text.opacity(0.85), 1)
                    // Bildens vågräta som korta streck vid sidorna: avståndet till linjen är lutningen.
                    c.linje(CGPoint(x: m.x - r - 14, y: m.y), CGPoint(x: m.x - r - 4, y: m.y), Theme.secondary, 1)
                    c.linje(CGPoint(x: m.x + r + 4, y: m.y), CGPoint(x: m.x + r + 14, y: m.y), Theme.secondary, 1)
                }
                VStack(spacing: 4) {
                    Text(verbatim: Tal.medEnhet(Tal.tal(abs(l.sida), decimaler: 1), "°"))
                        .typsnitt(15, .medium, siffror: true)
                        .foregroundStyle(Theme.text)
                    if l.forStorFor3D {
                        Text(verbatim: Texter.lutningForStor)
                            .typsnitt(13, .semibold)
                            .foregroundStyle(Theme.text)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.ground.opacity(0.6), in: .rect(cornerRadius: 2))
                .offset(y: 36)
            }
            .allowsHitTesting(false)
            .accessibilityElement(children: .combine)
        }
    }
}

/// Lutningen ur telefonens rörelse medan inspelningen är öppen (`GravityRecorder`, 10 gånger i
/// sekunden). METOD MS19
struct LevandeLutning: View {
    @State private var lutning: Lutning?

    var body: some View {
        LutningVy(lutning: lutning)
            .task {
                GravityRecorder.shared.startLive()
                defer { GravityRecorder.shared.stopLive() }
                while !Task.isCancelled {
                    if let g = GravityRecorder.shared.latest { lutning = Lutning(gravity: [g.x, g.y, g.z]) }
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }
    }
}
