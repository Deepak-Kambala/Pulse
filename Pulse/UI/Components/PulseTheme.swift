import SwiftUI
import AppKit

enum PulseTheme {
    // Sleek Obsidian (Dark) & Crisp Alabaster (Light)
    static let background = Color(nsColor: adaptive(dark: 0x0C0D10, light: 0xF5F6F8))
    static let sidebar = Color(nsColor: adaptive(dark: 0x111216, light: 0xECEEF2))
    static let card = Color(nsColor: adaptive(dark: 0x15171C, light: 0xFFFFFF))
    static let secondaryCard = Color(nsColor: adaptive(dark: 0x1B1E25, light: 0xF1F3F6))
    static let primaryText = Color(nsColor: adaptive(dark: 0xF2F4F7, light: 0x111317))
    static let secondaryText = Color(nsColor: adaptive(dark: 0x8A919E, light: 0x5C6470))
    static let tertiaryText = Color(nsColor: adaptive(dark: 0x585F6B, light: 0x8C95A4))
    static let border = Color(nsColor: adaptive(dark: 0x22262E, light: 0xE2E5EB))
    static let hairline = Color(nsColor: adaptiveAlpha(dark: 0xFFFFFF, darkAlpha: 0.06, light: 0x000000, lightAlpha: 0.06))

    static let accent = Color(nsColor: adaptive(dark: 0x3ED6B5, light: 0x10A37F))
    static let secondaryAccent = Color(nsColor: adaptive(dark: 0x38BDF8, light: 0x0284C7))

    // Semantic Status Colors
    static let healthy = Color(nsColor: adaptive(dark: 0x34D399, light: 0x15803D))
    static let warning = Color(nsColor: adaptive(dark: 0xF59E0B, light: 0xB45309))
    static let critical = Color(nsColor: adaptive(dark: 0xF87171, light: 0xDC2626))
    static let neutral = Color(nsColor: adaptive(dark: 0x6B7280, light: 0x6B7280))

    static func color(for status: HealthStatus) -> Color {
        switch status {
        case .healthy: return healthy
        case .warning: return warning
        case .critical: return critical
        case .neutral: return neutral
        }
    }

    private static func adaptive(dark: UInt32, light: UInt32) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return nsColor(hex: isDark ? dark : light, alpha: 1.0)
        }
    }

    private static func adaptiveAlpha(dark: UInt32, darkAlpha: CGFloat, light: UInt32, lightAlpha: CGFloat) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return nsColor(hex: isDark ? dark : light, alpha: isDark ? darkAlpha : lightAlpha)
        }
    }

    private static func nsColor(hex: UInt32, alpha: CGFloat) -> NSColor {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: alpha)
    }
}
