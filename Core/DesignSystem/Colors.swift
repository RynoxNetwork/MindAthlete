import SwiftUI


public enum MAColorPalette {
    public static let primary700 = Color(hex: "#128B8B")
    public static let primary = Color(hex: "#1BA6A6")
    public static let primary100 = Color(hex: "#C6ECEC")

    public static let accent700 = Color(hex: "#C77300")
    public static let accent = Color(hex: "#F18F01")
    public static let accent100 = Color(hex: "#FAD6A8")

    public static let textPrimary = Color(hex: "#0F172A")
    public static let textSecondary = Color(hex: "#475569")
    public static let background = Color(hex: "#F8FAFC")
    public static let surface = Color.white
    public static let surfaceAlt = Color(hex: "#E2E8F0")

    public static let success = Color(hex: "#22C55E")
    public static let warning = Color(hex: "#FBBF24")
    public static let danger = Color(hex: "#EF4444")
}

public extension Color {
    init(hex: String) {
        let sanitized = hex.replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch sanitized.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }

        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
    static var maBackground: Color {
        Color("Background", bundle: .main)
    }

    static var maSurface: Color {
        Color("Surface", bundle: .main)
    }
}
