//
//  MASectionHeader.swift
//  MindAthlete
//
//  Created by Renato Riva on 10/12/25.
//

import SwiftUI

public struct MASectionHeader: View {
    private let title: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack {
            Text(title)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(MAColorPalette.textPrimary)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(MAColorPalette.primary)
            }
        }
        .padding(.vertical, MASpacing.sm)
    }
}
