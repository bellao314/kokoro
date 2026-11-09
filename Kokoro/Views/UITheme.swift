import SwiftUI

#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif

extension Color {
    // MARK: - Warm Organic Sage Palette

    /// Soft linen background canvas (#F7F5F0)
    public static let kokoroLinen = Color(hex: "#F7F5F0")

    /// Crisp white card surface (#FFFFFF)
    public static let kokoroCardWhite = Color(hex: "#FFFFFF")

    /// Subtle card border and divider (#EBE7DE)
    public static let kokoroBorder = Color(hex: "#EBE7DE")

    /// Botanical Sage Green - Primary Accent (#4E7259)
    public static let kokoroSage = Color(hex: "#4E7259")

    /// Deep Sage for high-contrast text and active states (#36523F)
    public static let kokoroSageDeep = Color(hex: "#36523F")

    /// Soft Sage Wash for chips, pills, and secondary backgrounds (#E9EFEA)
    public static let kokoroSageSoft = Color(hex: "#E9EFEA")

    /// Muted Blush Accent (#CC7A6E)
    public static let kokoroBlush = Color(hex: "#CC7A6E")

    /// Deep Blush for high-contrast indicators (#AB584C)
    public static let kokoroBlushDeep = Color(hex: "#AB584C")

    /// Soft Blush Wash for alert backgrounds (#FCEEEB)
    public static let kokoroBlushSoft = Color(hex: "#FCEEEB")

    /// Rich Espresso Typography - Primary (#2D2421)
    public static let kokoroEspresso = Color(hex: "#2D2421")

    /// Rich Espresso Typography - Secondary / Muted (#6B5E57)
    public static let kokoroEspressoMuted = Color(hex: "#6B5E57")

    /// Rich Espresso Typography - Subtle / Caption (#9E9088)
    public static let kokoroEspressoSubtle = Color(hex: "#9E9088")

    // MARK: - Semantic Tokens (Decoupled from System Dark Mode)

    /// Base canvas background
    public static let appBackground = kokoroLinen

    /// Primary card background
    public static let cardBackground = kokoroCardWhite

    /// Secondary card background / fill
    public static let secondaryCardBackground = kokoroSageSoft

    /// Card outline border
    public static let cardBorder = kokoroBorder

    /// Primary typography (Headings, key numbers, titles)
    public static let primaryText = kokoroEspresso

    /// Secondary typography (Labels, subtitles, units)
    public static let secondaryText = kokoroEspressoMuted

    /// Subtle typography (Timestamps, footnote text)
    public static let subtleText = kokoroEspressoSubtle

    /// Primary button background: Botanical Sage Green (#4E7259)
    public static let buttonPrimary = kokoroSage

    /// Primary button text: Crisp White (#FFFFFF)
    public static let buttonPrimaryText = Color.white

    /// Secondary button background: Soft Sage Wash (#E9EFEA)
    public static let buttonSecondary = kokoroSageSoft

    /// Secondary button text: Deep Sage (#36523F)
    public static let buttonSecondaryText = kokoroSageDeep

    /// Accent button background: Muted Blush (#CC7A6E)
    public static let buttonAccent = kokoroBlush

    /// Accent button text: Crisp White (#FFFFFF)
    public static let buttonAccentText = Color.white

    /// Backward-compatible alias
    public static let buttonText = buttonPrimaryText
    public static let kokoroPink = kokoroBlush
    public static let kokoroCocoa = kokoroEspresso
    public static let kokoroCream = kokoroLinen
    public static let kokoroPeriwinkle = kokoroSageSoft

    // MARK: - Hex Initializer
    public init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
}
