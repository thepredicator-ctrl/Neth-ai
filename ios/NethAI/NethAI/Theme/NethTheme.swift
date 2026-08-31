import SwiftUI

// MARK: - Neth-AI Design Identity — Audi Red / Grey / Silver
// Premium automotive aesthetic: deep red core, brushed silver rings,
// metallic grey panels, sharp minimal lines. No gradients where avoidable.

enum NethTheme {
    // Backgrounds — metallic dark greys
    static let black = Color(hex: 0x0A0A0A)
    static let voidBlack = Color(hex: 0x000000)
    static let charcoal = Color(hex: 0x1A1A1A)
    static let charcoalRaised = Color(hex: 0x242424)
    static let panelDark = Color(hex: 0x141414)
    static let panelMetal = Color(hex: 0x1E1E1E)

    // Primary — Audi red
    static let orange = Color(hex: 0xCC0000)        // Audi red (kept name for compat)
    static let orangeBright = Color(hex: 0xE2001A)  // brighter red
    static let orangeDeep = Color(hex: 0x8B0000)    // dark red
    static let amber = Color(hex: 0xFF3333)         // light red
    static let ember = Color(hex: 0xFF6666)         // pale red

    // Silver / metallic
    static let silver = Color(hex: 0xC0C0C0)
    static let silverBright = Color(hex: 0xE8E8E8)
    static let silverDark = Color(hex: 0x808080)
    static let steel = Color(hex: 0x4A4A4A)

    // Text
    static let textPrimary = Color(hex: 0xF5F5F5)
    static let textSecondary = Color(hex: 0xB0B0B0)
    static let textTertiary = Color(hex: 0x707070)

    // Lines / dividers
    static let hairline = Color(hex: 0x333333)
    static let hairlineWarm = Color(hex: 0x4A2020)

    // Status
    static let errorGlow = Color(hex: 0xFF0000)

    // Fonts
    static let displayFont = Font.system(.largeTitle, design: .default).weight(.bold)
    static let titleFont = Font.system(.title2, design: .default).weight(.semibold)
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
