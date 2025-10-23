//
//  MAButton 2.swift
//  MindAthlete
//
//  Created by Renato Riva on 10/12/25.
//


import SwiftUI

public struct MAButton: View {
    public enum Style {
        case primary
        case secondary
        case tertiary
        case outline
    }

    private let title: String
    private let style: Style
    private let action: () -> Void

    public init(_ title: String, style: Style = .primary, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.headline, design: .rounded))
                .fontWeight(.semibold)
                .padding(.vertical, MASpacing.sm)
                .padding(.horizontal, MASpacing.lg)
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(MAButtonStyle(style: style))
        .accessibilityAddTraits(.isButton)
    }
}

struct MAButtonStyle: ButtonStyle {
    let style: MAButton.Style
    @Environment(\.isEnabled) private var isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(backgroundColor(isPressed: configuration.isPressed))
            .foregroundColor(foregroundColor)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
            .opacity(isEnabled ? 1 : 0.6)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return Color.white
        case .secondary:
            return MAColorPalette.primary
        case .tertiary:
            return MAColorPalette.textPrimary
        case .outline:
            return MAColorPalette.primary
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch style {
        case .primary:
            return isPressed ? MAColorPalette.primary700 : MAColorPalette.primary
        case .secondary:
            return isPressed ? MAColorPalette.primary100 : MAColorPalette.primary.opacity(0.12)
        case .tertiary:
            return Color.clear
        case .outline:
            return isPressed ? MAColorPalette.primary.opacity(0.06) : Color.maSurface
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary:
            return .clear
        case .secondary:
            return MAColorPalette.primary
        case .tertiary:
            return MAColorPalette.surfaceAlt
        case .outline:
            return MAColorPalette.primary
        }
    }

    private var borderWidth: CGFloat {
        switch style {
        case .outline:
            return 2
        case .secondary, .primary:
            return 0
        case .tertiary:
            return 1
        }
    }
}
