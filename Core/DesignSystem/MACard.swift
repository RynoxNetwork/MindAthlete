import SwiftUI

public struct MACard<Content: View>: View {
    private let title: String?
    private let content: Content

    public init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MASpacing.md) {
            if let title {
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(MAColorPalette.textPrimary)
            }
            content
        }
        .padding(MASpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.maSurface)
                .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
        )
        .accessibilityElement(children: .contain)
    }
}
