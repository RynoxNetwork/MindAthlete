import SwiftUI

struct MAColors {
    // MARK: - Primary (Turquesa Mate)
    static let primary = Color(red: 0.106, green: 0.651, blue: 0.651) // #1BA6A6
    static let primary700 = Color(red: 0.071, green: 0.545, blue: 0.545) // #128B8B
    static let primary100 = Color(red: 0.776, green: 0.933, blue: 0.933) // #C6ECEC
    
    // MARK: - Accent (Naranja Mate)
    static let accent = Color(red: 0.945, green: 0.561, blue: 0.004) // #F18F01
    static let accent700 = Color(red: 0.784, green: 0.451, blue: 0.0) // #C77300
    static let accent100 = Color(red: 0.980, green: 0.839, blue: 0.659) // #FAD6A8
    
    // MARK: - Neutrales (Slate)
    static let textPrimary = Color(red: 0.059, green: 0.094, blue: 0.145) // #0F172A
    static let textSecondary = Color(red: 0.280, green: 0.333, blue: 0.412) // #475569
    static let textTertiary = Color(red: 0.549, green: 0.596, blue: 0.663) // #8B94A5
    static let backgroundLight = Color(red: 0.973, green: 0.980, blue: 0.988) // #F8FAFC
    static let backgroundMedium = Color(red: 0.949, green: 0.953, blue: 0.969) // #F1F5FB
    static let borderLight = Color(red: 0.929, green: 0.933, blue: 0.949) // #EDED51 (adjusted)
    
    // MARK: - Semantic
    static let success = Color(red: 0.165, green: 0.733, blue: 0.490) // #2ABC7A
    static let warning = Color(red: 0.984, green: 0.733, blue: 0.251) // #FBBB40
    static let error = Color(red: 0.941, green: 0.353, blue: 0.353) // #F05A5A
    static let info = Color(red: 0.306, green: 0.620, blue: 0.922) // #4E9EEB
    
    // MARK: - Dark Mode Adjustments
    static let backgroundDark = Color(red: 0.106, green: 0.110, blue: 0.129) // #1B1C21
    static let textPrimaryDark = Color(red: 0.973, green: 0.976, blue: 0.984) // #F8FAFC
    static let textSecondaryDark = Color(red: 0.729, green: 0.741, blue: 0.776) // #BABBCC
}

// MARK: - Environment Key for Color Scheme
struct ColorSchemeKey: EnvironmentKey {
    static let defaultValue: ColorScheme? = nil
}

extension EnvironmentValues {
    var colorScheme: ColorScheme? {
        get { self[ColorSchemeKey.self] }
        set { self[ColorSchemeKey.self] = newValue }
    }
}
