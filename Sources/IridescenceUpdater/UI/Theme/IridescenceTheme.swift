import SwiftUI
import AppKit
import IridescenceCore

/// Design tokens and styling for Iridescence Updater, adhering to The Prismatic Atelier (v2.1.0).
public enum IridescenceTheme {

    // MARK: - Dynamic Colors

    public static let canvas = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? NSColor(srgbRed: 0x11/255.0, green: 0x0D/255.0, blue: 0x17/255.0, alpha: 1.0)
                      : NSColor(srgbRed: 0xFA/255.0, green: 0xF9/255.0, blue: 0xFC/255.0, alpha: 1.0)
    })

    public static let cardSurface = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? NSColor(srgbRed: 0x1A/255.0, green: 0x15/255.0, blue: 0x23/255.0, alpha: 1.0)
                      : NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    })

    public static let surfaceSubtle = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? NSColor(srgbRed: 0x24/255.0, green: 0x1D/255.0, blue: 0x30/255.0, alpha: 1.0)
                      : NSColor(srgbRed: 0xF2/255.0, green: 0xEF/255.0, blue: 0xF7/255.0, alpha: 1.0)
    })

    public static let hairline = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? NSColor(srgbRed: 0xED/255.0, green: 0xE8/255.0, blue: 0xF3/255.0, alpha: 0.10)
                      : NSColor(srgbRed: 0x16/255.0, green: 0x10/255.0, blue: 0x1D/255.0, alpha: 0.09)
    })

    public static let textPrimary = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? NSColor(srgbRed: 0xED/255.0, green: 0xE8/255.0, blue: 0xF3/255.0, alpha: 1.0)
                      : NSColor(srgbRed: 0x16/255.0, green: 0x10/255.0, blue: 0x1D/255.0, alpha: 1.0)
    })

    public static let textSecondary = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? NSColor(srgbRed: 0xA3/255.0, green: 0x99/255.0, blue: 0xB2/255.0, alpha: 1.0)
                      : NSColor(srgbRed: 0x6E/255.0, green: 0x65/255.0, blue: 0x78/255.0, alpha: 1.0)
    })

    public static let textMuted = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? NSColor(srgbRed: 0x6E/255.0, green: 0x64/255.0, blue: 0x7D/255.0, alpha: 1.0)
                      : NSColor(srgbRed: 0x99/255.0, green: 0x8F/255.0, blue: 0xA6/255.0, alpha: 1.0)
    })

    // Spectral Accents
    public static let deepViolet = Color(red: 0x70/255.0, green: 0x2E/255.0, blue: 0xE4/255.0)
    public static let electricBlue = Color(red: 0x22/255.0, green: 0x66/255.0, blue: 0xF2/255.0)
    public static let luminousCyan = Color(red: 0x0C/255.0, green: 0xC0/255.0, blue: 0xE8/255.0)
    public static let turquoise = Color(red: 0x12/255.0, green: 0xCC/255.0, blue: 0xB8/255.0)
    public static let ultraviolet = Color(red: 0x8A/255.0, green: 0x38/255.0, blue: 0xF5/255.0)
    public static let magenta = Color(red: 0xDC/255.0, green: 0x3E/255.0, blue: 0xA0/255.0)
    public static let warmCoral = Color(red: 0xEE/255.0, green: 0x76/255.0, blue: 0x6A/255.0)
    public static let emeraldPhosphor = Color(red: 0x04/255.0, green: 0x78/255.0, blue: 0x57/255.0)

    public static func accentForName(_ name: String) -> Color {
        switch name.lowercased() {
        case "violet": return deepViolet
        case "blue": return electricBlue
        case "cyan": return luminousCyan
        case "presence", "emerald": return emeraldPhosphor
        case "ultraviolet": return ultraviolet
        case "coral": return warmCoral
        default: return luminousCyan
        }
    }

    // MARK: - Typography

    public static func fontMono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if NSFont(name: "0xProto NF", size: size) != nil {
            return Font.custom("0xProto NF", size: size).weight(weight)
        }
        return Font.system(size: size, weight: weight, design: .monospaced)
    }

    // MARK: - Corner Radii
    public static let radiusSm: CGFloat = 6
    public static let radiusMd: CGFloat = 10
    public static let radiusLg: CGFloat = 14
    public static let radiusPill: CGFloat = 9999
}
