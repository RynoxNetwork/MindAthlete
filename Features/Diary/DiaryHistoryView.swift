
import SwiftUI

struct DiaryHistoryView: View {
    let moods: [Mood]

    var body: some View {
        List(moods) { mood in
            VStack(alignment: .leading, spacing: MASpacing.xs) {
                Text(mood.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(MAColorPalette.textPrimary)
                MATypography.caption("Ánimo: \(mood.score) · Energía: \(mood.energy)")
            }
            .padding(.vertical, MASpacing.xs)
        }
        .listStyle(.plain)
    }
}
