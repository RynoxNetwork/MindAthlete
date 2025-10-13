import SwiftUI

public enum MATypography {
    public static func display(_ text: String) -> some View {
        Text(text)
            .font(.system(.largeTitle, design: .rounded))
            .fontWeight(.bold)
            .foregroundColor(MAColorPalette.textPrimary)
    }

    public static func title(_ text: String) -> some View {
        Text(text)
            .font(.system(.title2, design: .rounded))
            .fontWeight(.semibold)
            .foregroundColor(MAColorPalette.textPrimary)
    }

    public static func body(_ text: String) -> some View {
        Text(text)
            .font(.system(.body, design: .rounded))
            .foregroundColor(MAColorPalette.textSecondary)
    }

    public static func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(.footnote, design: .rounded))
            .foregroundColor(MAColorPalette.textSecondary)
    }
}
