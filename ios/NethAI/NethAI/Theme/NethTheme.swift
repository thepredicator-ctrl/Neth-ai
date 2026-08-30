import SwiftUI

// MARK: - Neth-AI Design Identity
// Deep black + charcoal + vivid glowing orange + amber + subtle white.
// No blue. No corporate. Pure futuristic AI device.

enum NethTheme {
    // Backgrounds
    static let black = Color(hex: 0x050505)
    static let voidBlack = Color(hex: 0x000000)
    static let charcoal = Color(hex: 0x121212)
    static let charcoalRaised = Color(hex: 0x1A1A1A)
    static let panelDark = Color(hex: 0x0E0E0E)

    // Glow
    static let orange = Color(hex: 0xFF7A18)
    static let orangeBright = Color(hex: 0xFF9A3C)
    static let orangeDeep = Color(hex: 0xE05A0A)
    static let amber = Color(hex: 0xFFB347)
    static let ember = Color(hex: 0xFFD27A)

    // Text
    static let textPrimary = Color(hex: 0xF4F4F4)
    static let textSecondary = Color(hex: 0xA8A8A8)
    static let textTertiary = Color(hex: 0x6E6E6E)

    // Lines / dividers
    static let hairline = Color(hex: 0x2A2A2A)
    static let hairlineWarm = Color(hex: 0x3A2418)

    // Status
    static let errorGlow = Color(hex: 0xFF5A2A)

    // Fonts
    static let displayFont = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let titleFont = Font.system(.title2, design: .rounded).weight(.semibold)
    static let bodyFont = Font.system(.body, design: .default)
    static let monoFont = Font.system(.caption, design: .monospaced)

    // Glow strength by state
    static func glowColor(for state: OrbState) -> Color {
        switch state {
        case .idle:        return orange.opacity(0.55)
        case .listening:   return amber.opacity(0.85)
        case .thinking:    return orangeBright.opacity(0.95)
        case .generating:  return orange.opacity(1.0)
        case .complete:    return ember.opacity(0.7)
        case .error:       return errorGlow.opacity(0.9)
        }
    }

    static func pulseSpeed(for state: OrbState) -> Double {
        switch state {
        case .idle:        return 3.4
        case .listening:   return 1.1
        case .thinking:    return 0.7
        case .generating:  return 0.45
        case .complete:    return 2.2
        case .error:       return 0.9
        }
    }
}

enum OrbState: String, CaseIterable, Sendable {
    case idle
    case listening
    case thinking
    case generating
    case complete
    case error

    var label: String {
        switch self {
        case .idle:        return "Ready"
        case .listening:   return "Listening"
        case .thinking:    return "Thinking"
        case .generating:  return "Generating"
        case .complete:    return "Done"
        case .error:       return "Error"
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8)  & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
