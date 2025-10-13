//
//  MAChip.swift
//  MindAthlete
//
//  Created by Renato Riva on 10/12/25.
//

import SwiftUI

public struct MAChip: View {
    public enum ChipStyle {
        case filled
        case outlined
    }

    private let text: String
    private let style: ChipStyle

    public init(_ text: String, style: ChipStyle = .filled) {
        self.text = text
        self.style = style
    }

    public var body: some View {
        Text(text)
            .font(.system(.footnote, design: .rounded))
            .padding(.vertical, MASpacing.xs)
            .padding(.horizontal, MASpacing.sm)
            .background(background)
            .foregroundColor(foreground)
            .overlay(
                Capsule()
                    .stroke(borderColor, lineWidth: style == .outlined ? 1 : 0)
            )
            .clipShape(Capsule())
    }

    private var background: Color {
        switch style {
        case .filled:
            return MAColorPalette.primary.opacity(0.12)
        case .outlined:
            return Color.clear
        }
    }

    private var foreground: Color {
        switch style {
        case .filled:
            return MAColorPalette.primary700
        case .outlined:
            return MAColorPalette.textPrimary
        }
    }

    private var borderColor: Color {
        switch style {
        case .filled:
            return .clear
        case .outlined:
            return MAColorPalette.surfaceAlt
        }
    }
}
