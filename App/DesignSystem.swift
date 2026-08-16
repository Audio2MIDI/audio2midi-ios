import SwiftUI

enum StudioColor {
    static let black = Color(red: 0.025, green: 0.025, blue: 0.03)
    static let surface = Color(red: 0.075, green: 0.078, blue: 0.09)
    static let raised = Color(red: 0.115, green: 0.12, blue: 0.14)
    static let line = Color.white.opacity(0.12)
    static let secondary = Color.white.opacity(0.58)
    static let blue = Color(red: 0.071, green: 0.325, blue: 1.0)
    static let danger = Color(red: 1.0, green: 0.29, blue: 0.31)
}

struct StudioButtonStyle: ButtonStyle {
    let prominent: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(prominent ? .white : .primary)
            .background(prominent ? StudioColor.blue : StudioColor.raised)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct SectionLabel: View {
    let text: LocalizedStringKey
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(StudioColor.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Wordmark: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(StudioColor.blue)
            Text("Audio2MIDI")
                .font(.system(size: 17, weight: .bold, design: .rounded))
        }
    }
}

