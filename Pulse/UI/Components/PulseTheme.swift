import SwiftUI
import AppKit

enum PulseTheme {
    // Adaptive Colors (Dark primary + Light mode support)
    static let background = Color(nsColor: adaptive(dark: 0x101114, light: 0xF4F5F7))
    static let sidebar = Color(nsColor: adaptive(dark: 0x15171B, light: 0xEAECEF))
    static let card = Color(nsColor: adaptive(dark: 0x1A1D22, light: 0xFFFFFF))
    static let secondaryCard = Color(nsColor: adaptive(dark: 0x20242A, light: 0xF0F2F5))
    static let primaryText = Color(nsColor: adaptive(dark: 0xF5F6F7, light: 0x111317))
    static let secondaryText = Color(nsColor: adaptive(dark: 0x9299A3, light: 0x5C6470))
    static let border = Color(nsColor: adaptive(dark: 0x2B3037, light: 0xDDE1E7))
    static let accent = Color(nsColor: adaptive(dark: 0x45D6B0, light: 0x14B894))
    static let secondaryAccent = Color(nsColor: adaptive(dark: 0x22B8E8, light: 0x0284C7))

    // Semantic Status Colors
    static let healthy = Color(nsColor: adaptive(dark: 0x3ECF8E, light: 0x169C5E))
    static let warning = Color(nsColor: adaptive(dark: 0xE5A93C, light: 0xC97A10))
    static let critical = Color(nsColor: adaptive(dark: 0xE05A5A, light: 0xC93434))
    static let neutral = Color(nsColor: adaptive(dark: 0x8E95A0, light: 0x6B7280))

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
            return nsColor(hex: isDark ? dark : light)
        }
    }

    private static func nsColor(hex: UInt32) -> NSColor {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}
