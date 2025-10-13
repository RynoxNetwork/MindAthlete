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
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(MAButtonStyle(style: style))
        .accessibilityAddTraits(.isButton)
    }
}

struct MAButtonStyle: ButtonStyle {
    let style: MAButton.Style

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(backgroundColor(isPressed: configuration.isPressed))
            .foregroundColor(foregroundColor)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(borderColor, lineWidth: style == .tertiary ? 1 : 0)
            )
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return Color.white
        case .secondary:
            return MAColorPalette.primary
        case .tertiary:
            return MAColorPalette.textPrimary
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
        }
    }
}

