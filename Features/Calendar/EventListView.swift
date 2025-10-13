
import SwiftUI

struct EventListView: View {
    let events: [Event]

    var body: some View {
        List(events) { event in
            VStack(alignment: .leading, spacing: MASpacing.xs) {
                Text(event.type)
                    .font(.system(.headline, design: .rounded))
                MATypography.caption(event.date.formatted(date: .abbreviated, time: .shortened))
            }
            .padding(.vertical, MASpacing.xs)
        }
        .listStyle(.plain)
    }
}
