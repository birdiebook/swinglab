import SwiftUI

/// Formspråket (BESLUT B13, design/README.md): svart, vitt och gråskala med en enda
/// accent för det du övar på (BESLUT B31), inga skuggor eller gradienter, hörn på 2–4 punkter.
enum Theme {
    static let ground = Color(hex: 0x000000)
    static let surface = Color(hex: 0x0D0D0D)
    static let raised = Color(hex: 0x161616)
    static let hair = Color(hex: 0x1C1C1C)
    static let line = Color(hex: 0x2E2E2E)
    static let cam = Color(hex: 0x0A0A0A)
    static let tertiary = Color(hex: 0x6B6B6B)
    static let secondary = Color(hex: 0xA3A3A3)
    static let text = Color(hex: 0xFFFFFF)
    /// Accenten, isblå: bara det du övar på (måtten i Att jobba på), som tunna linjer,
    /// markören och en etikett; aldrig ytor, knappar eller bakgrunder (design/README.md regel 10).
    static let acc = Color(hex: 0x6FD3F7)
    /// Bara varningar i uppställningen.
    static let flag = Color(hex: 0xB98A4A)
    /// Inspelningens status (BESLUT B85, undantaget från B13 regel 6), bara på inspelningens
    /// skärm: grönt för "Connected", rött för REC-pillen och inspelningsknappens fält, och gult
    /// för varningens ikon.
    static let live = Color(hex: 0x30D158)
    static let rec = Color(hex: 0xD70015)
    static let recKnapp = Color(hex: 0xFF3B30)
    static let varning = Color(hex: 0xF5B54A)

    /// Stora tal: tabellsiffror, så att de inte hoppar när de ändras.
    static func number(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Primärknappen: ett vitt fält med svart text, överallt (B13 regel 8). Texten
/// skalas med Dynamisk text och bryts hellre än kortas; fältet växer med den.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Field(configuration: configuration)
    }

    private struct Field: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .typsnitt(17, .semibold)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.ground)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Theme.text, in: .rect(cornerRadius: 4))
                .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.3)
        }
    }
}

/// En rad med en tunn linje ovanför, för det som inte är primärt.
struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Row(configuration: configuration)
    }

    private struct Row: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .typsnitt(17, .medium)
                .foregroundStyle(isEnabled ? Theme.text : Theme.tertiary)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .contentShape(.rect)
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.hair).frame(height: 1)
                }
                .opacity(configuration.isPressed ? 0.6 : 1)
        }
    }
}
