import SwiftUI

extension Color {
    // MARK: - Warm Organic Sage Palette (watchOS)

    public static let kokoroLinen = Color(hex: "#F7F5F0")
    public static let kokoroCardWhite = Color(hex: "#FFFFFF")
    public static let kokoroBorder = Color(hex: "#EBE7DE")
    public static let kokoroSage = Color(hex: "#4E7259")
    public static let kokoroSageDeep = Color(hex: "#36523F")
    public static let kokoroSageSoft = Color(hex: "#E9EFEA")
    public static let kokoroBlush = Color(hex: "#CC7A6E")
    public static let kokoroBlushDeep = Color(hex: "#AB584C")
    public static let kokoroBlushSoft = Color(hex: "#FCEEEB")
    public static let kokoroEspresso = Color(hex: "#2D2421")
    public static let kokoroEspressoMuted = Color(hex: "#6B5E57")
    public static let kokoroEspressoSubtle = Color(hex: "#9E9088")

    // Semantic Tokens
    public static let appBackground = kokoroLinen
    public static let cardBackground = kokoroCardWhite
    public static let secondaryCardBackground = kokoroSageSoft
    public static let cardBorder = kokoroBorder
    public static let primaryText = kokoroEspresso
    public static let secondaryText = kokoroEspressoMuted
    public static let subtleText = kokoroEspressoSubtle
    public static let buttonPrimary = kokoroSage
    public static let buttonPrimaryText = Color.white
    public static let buttonSecondary = kokoroSageSoft
    public static let buttonSecondaryText = kokoroSageDeep
    public static let buttonAccent = kokoroBlush
    public static let buttonAccentText = Color.white
    public static let buttonText = buttonPrimaryText
    public static let kokoroPink = kokoroBlush
    public static let kokoroCocoa = kokoroEspresso
    public static let kokoroCream = kokoroLinen
    public static let kokoroPeriwinkle = kokoroSageSoft

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
