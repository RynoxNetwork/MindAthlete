import SwiftUI

public struct ScheduleHeader: View {
    @Binding var selectedDay: Date

    public init(selectedDay: Binding<Date>) {
        self._selectedDay = selectedDay
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Agenda")
                    .font(.title2.weight(.semibold))
                Text(formattedDate(selectedDay))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(.ultraThinMaterial)
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("EEEE, d MMMM")
        return f.string(from: date)
    }
}

#Preview {
    StatefulPreviewWrapper(Date()) { binding in
        ScheduleHeader(selectedDay: binding)
    }
}

// Helper for previews
struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State var value: Value
    var content: (Binding<Value>) -> Content
    init(_ value: Value, content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: value)
        self.content = content
    }
    var body: some View { content($value) }
}
