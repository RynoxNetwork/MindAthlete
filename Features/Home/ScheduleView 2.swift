import SwiftUI

// MARK: - Models (UI-only / mock)
struct DemoAgendaEvent: Identifiable, Codable, Sendable {
    let id: UUID
    let title: String
    let start: Date
    let end: Date
    let tag: String?
}

struct FreeSlot: Identifiable, Sendable {
    let id: UUID
    let start: Date
    let end: Date
}

struct Suggestion: Identifiable, Sendable {
    let id: UUID
    let title: String
    let detail: String
    let actionTitle: String
}

struct Message: Identifiable, Sendable {
    enum Role { case user, assistant }
    let id: UUID
    let role: Role
    let text: String
    let time: Date
}

// MARK: - Utilities
private let scheduleTeal = Color.teal.opacity(0.9)
private let scheduleOrange = Color.orange.opacity(0.9)

private func dayBounds(for date: Date, calendar: Calendar = .current) -> (Date, Date) {
    let start = calendar.startOfDay(for: date)
    let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? date
    return (start, end)
}

// Compute free slots within a day with a minimum gap
func computeFreeSlots(events: [DemoAgendaEvent], day: Date, minGapMinutes: Int = 15) -> [FreeSlot] {
    let cal = Calendar.current
    let bounds = dayBounds(for: day, calendar: cal)
    var cursor = bounds.0
    var slots: [FreeSlot] = []

    for e in events.sorted(by: { $0.start < $1.start }) {
        if e.start > cursor {
            let end = min(e.start, bounds.1)
            let minutes = Int(end.timeIntervalSince(cursor) / 60)
            if minutes >= minGapMinutes {
                slots.append(FreeSlot(id: UUID(), start: cursor, end: end))
            }
        }
        cursor = max(cursor, e.end)
        if cursor >= bounds.1 { break }
    }

    if cursor < bounds.1 {
        let minutes = Int(bounds.1.timeIntervalSince(cursor) / 60)
        if minutes >= minGapMinutes {
            slots.append(FreeSlot(id: UUID(), start: cursor, end: bounds.1))
        }
    }

    return slots
}

func makeSuggestions(from slots: [FreeSlot]) -> [Suggestion] {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    guard let first = slots.first else { return [] }

    let firstDetail = "\(formatter.string(from: first.start))–\(formatter.string(from: first.end))"
    var suggestions: [Suggestion] = [
        Suggestion(id: UUID(), title: "Respiración 4-7-8 – 5 min", detail: firstDetail, actionTitle: "Programar"),
    ]

    if slots.count > 1 {
        let second = slots[1]
        let secondDetail = "\(formatter.string(from: second.start))–\(formatter.string(from: second.end))"
        suggestions.append(Suggestion(id: UUID(), title: "Mindfulness – 10 min", detail: secondDetail, actionTitle: "Programar"))
    }
    return suggestions
}

// MARK: - ScheduleView
struct ScheduleView: View {
    enum Mode: String, CaseIterable, Identifiable { case day = "Día", week = "Semana"; var id: String { rawValue } }

    @State private var mode: Mode = .day
    @State private var selectedDay: Date = Date()
    @State private var isGoogleLinked = false
    @State private var isNotionLinked = false
    @State private var showLinkSheet = false
    @State private var showCoachSheet = false
    @State private var messages: [Message] = []

    // Mock events for demo
    @State private var events: [DemoAgendaEvent] = mockEvents()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MiniHeaderView(selectedDay: $selectedDay)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .background(.ultraThinMaterial)
                    .scrollTransition(.animated.threshold(.visible(0.6))) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0.85)
                            .scaleEffect(phase.isIdentity ? 1 : 0.98)
                    }

                Picker("Modo", selection: $mode) {
                    ForEach(Mode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .sensoryFeedback(.selection, trigger: mode)

                ScrollView {
                    VStack(spacing: 16) {
                        if !isGoogleLinked && !isNotionLinked {
                            CalendarLinkInlineCard(isGoogleLinked: $isGoogleLinked, isNotionLinked: $isNotionLinked, showLinkSheet: $showLinkSheet)
                                .transition(.opacity)
                        }

                        Group {
                            if mode == .day {
                                dayContent
                            } else {
                                weekContent
                            }
                        }
                        .contentTransition(.opacity)

                        suggestionsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Agenda")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCoachSheet = true
                    } label: {
                        Label("Coach", systemImage: "person.wave.2")
                    }
                    .accessibilityLabel("Abrir Coach")
                }
            }
            .sheet(isPresented: $showLinkSheet) {
                CalendarLinkSheetView(isGoogleLinked: $isGoogleLinked, isNotionLinked: $isNotionLinked)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showCoachSheet) {
                CoachChatSheetView(messages: $messages)
            }
        }
    }

    // MARK: Sections
    private var dayContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            let todaysEvents = events.filter { Calendar.current.isDate($0.start, inSameDayAs: selectedDay) }
            ScheduleSectionHeader("Hoy")
            if todaysEvents.isEmpty {
                EmptyStateCard()
            } else {
                ForEach(todaysEvents) { event in
                    EventCardView(event: event)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }

            let slots = computeFreeSlots(events: todaysEvents, day: selectedDay)
            if !slots.isEmpty {
                FreeSlotPills(slots: slots)
            }
        }
        .opacity(1)
        .offset(y: 0)
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: selectedDay)
    }

    private var weekContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScheduleSectionHeader("Esta semana")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<7, id: \.self) { offset in
                        let day = Calendar.current.date(byAdding: .day, value: offsetFromStartOfWeek(offset), to: selectedDay) ?? selectedDay
                        VStack(alignment: .leading, spacing: 8) {
                            Text(shortWeekday(for: day))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(dayNumber(for: day))
                                .font(.headline)
                                .foregroundStyle(Calendar.current.isDate(day, inSameDayAs: selectedDay) ? scheduleTeal : .primary)
                            // Compact bars
                            let dayEvents = events.filter { Calendar.current.isDate($0.start, inSameDayAs: day) }
                            VStack(spacing: 4) {
                                ForEach(dayEvents.prefix(3)) { e in
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(scheduleTeal.opacity(0.25))
                                        .frame(width: 44, height: 6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(scheduleTeal.opacity(0.5), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(8)
                        .background(
                            Capsule().fill(Calendar.current.isDate(day, inSameDayAs: selectedDay) ? scheduleTeal.opacity(0.12) : Color.clear)
                        )
                        .onTapGesture {
                            withAnimation(.snappy) { selectedDay = day }
                        }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel("\(formattedDate(day))")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScheduleSectionHeader("Sugerencias")
            let todaysEvents = events.filter { Calendar.current.isDate($0.start, inSameDayAs: selectedDay) }
            let slots = computeFreeSlots(events: todaysEvents, day: selectedDay)
            let suggestions = makeSuggestions(from: slots)
            if suggestions.isEmpty {
                Text("Sin sugerencias por ahora")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(suggestions) { s in
                    SuggestionCardView(suggestion: s)
                }
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: selectedDay)
    }

    // MARK: Helpers
    private func shortWeekday(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("EEE")
        return f.string(from: date)
    }
    private func dayNumber(for date: Date) -> String {
        let d = Calendar.current.component(.day, from: date)
        return String(d)
    }
    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("EEEE, d MMMM")
        return f.string(from: date)
    }
    private func offsetFromStartOfWeek(_ offset: Int) -> Int {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: selectedDay)
        let startOfWeekOffset = cal.firstWeekday - weekday
        return startOfWeekOffset + offset
    }
}

// MARK: - Subviews
private struct MiniHeaderView: View {
    @Binding var selectedDay: Date

    var body: some View {
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
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("EEEE, d MMMM")
        return f.string(from: date)
    }
}

private struct ScheduleSectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.title2.weight(.semibold))
    }
}

private struct EventCardView: View {
    let event: DemoAgendaEvent
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeRange(event))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text(event.title)
                    .font(.headline)
                if let tag = event.tag {
                    Text(tag)
                        .font(.caption2)
                        .foregroundStyle(scheduleOrange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(scheduleOrange.opacity(0.12)))
                }
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 6)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title), \(timeRange(event))")
    }
    private func timeRange(_ e: DemoAgendaEvent) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return "\(f.string(from: e.start))–\(f.string(from: e.end))"
    }
}

private struct SuggestionCardView: View {
    let suggestion: Suggestion
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill").foregroundStyle(scheduleOrange)
                Text(suggestion.title).font(.headline)
            }
            Text(suggestion.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(suggestion.actionTitle) {}
                .buttonStyle(.borderedProminent)
                .tint(scheduleTeal)
                .accessibilityLabel("\(suggestion.actionTitle) \(suggestion.title)")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 6)
        )
    }
}

private struct FreeSlotPills: View {
    let slots: [FreeSlot]
    var body: some View {
        HStack(spacing: 8) {
            ForEach(slots) { slot in
                Text(label(slot))
                    .font(.caption)
                    .monospacedDigit()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().strokeBorder(scheduleTeal.opacity(0.35)))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Huecos libres")
    }
    private func label(_ slot: FreeSlot) -> String {
        let f = DateFormatter(); f.timeStyle = .short
        return "\(f.string(from: slot.start))–\(f.string(from: slot.end))"
    }
}

private struct CalendarLinkInlineCard: View {
    @Binding var isGoogleLinked: Bool
    @Binding var isNotionLinked: Bool
    @Binding var showLinkSheet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: "calendar"); Text("Vincula tus calendarios") }.font(.headline)
            Text("Conecta Google Calendar y Notion para ver tus eventos aquí.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button {
                    isGoogleLinked.toggle()
                } label: {
                    Label(isGoogleLinked ? "Google conectado" : "Vincular Google Calendar", systemImage: isGoogleLinked ? "checkmark.circle.fill" : "link")
                }
                .buttonStyle(.bordered)
                .symbolEffect(.bounce, value: isGoogleLinked)
                .sensoryFeedback(SwiftUI.SensoryFeedback.success, trigger: isGoogleLinked)

                Button {
                    isNotionLinked.toggle()
                } label: {
                    Label(isNotionLinked ? "Notion conectado" : "Vincular Notion Calendar", systemImage: isNotionLinked ? "checkmark.circle.fill" : "link")
                }
                .buttonStyle(.bordered)
                .symbolEffect(.bounce, value: isNotionLinked)
                .sensoryFeedback(SwiftUI.SensoryFeedback.success, trigger: isNotionLinked)
            }

            Button {
                showLinkSheet = true
            } label: {
                Label("Gestionar conexiones", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.borderedProminent)
            .tint(scheduleTeal)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 6)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct CalendarLinkSheetView: View {
    @Binding var isGoogleLinked: Bool
    @Binding var isNotionLinked: Bool
    var body: some View {
        NavigationStack {
            Form {
                Section("Conexiones") {
                    Toggle(isOn: $isGoogleLinked) { Label("Google Calendar", systemImage: "g.circle") }
                        .symbolEffect(.bounce, value: isGoogleLinked)
                    Toggle(isOn: $isNotionLinked) { Label("Notion Calendar", systemImage: "n.circle") }
                        .symbolEffect(.bounce, value: isNotionLinked)
                }
                Section(footer: Text("TODO: integrar servicios reales.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Calendarios")
        }
    }
}

private struct CoachChatSheetView: View {
    @Binding var messages: [Message]
    @State private var draft: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { msg in
                                HStack(alignment: .top) {
                                    if msg.role == .assistant { Image(systemName: "sparkles").foregroundStyle(scheduleOrange) }
                                    Text(msg.text).padding(10).background(
                                        RoundedRectangle(cornerRadius: 10).fill(msg.role == .assistant ? scheduleOrange.opacity(0.12) : scheduleTeal.opacity(0.12))
                                    )
                                    if msg.role == .user { Image(systemName: "person.fill").foregroundStyle(scheduleTeal) }
                                }
                                .frame(maxWidth: .infinity, alignment: msg.role == .assistant ? .leading : .trailing)
                                .id(msg.id)
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: messages.count) { _ in
                        if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                }
                HStack(spacing: 8) {
                    TextField("Pregunta al coach…", text: $draft)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        send()
                    } label: { Image(systemName: "paperplane.fill") }
                    .buttonStyle(.borderedProminent)
                    .tint(scheduleTeal)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(12)
                .background(.bar)
            }
            .navigationTitle("Coach")
        }
        .onAppear {
            if messages.isEmpty {
                messages.append(Message(id: UUID(), role: .assistant, text: "¿Dónde te gustaría colocar una sesión de respiración hoy?", time: Date()))
            }
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        messages.append(Message(id: UUID(), role: .user, text: text, time: Date()))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let reply = "Te sugiero una respiración 4-7-8 de 5 minutos a las 12:30, en tu siguiente hueco libre."
            messages.append(Message(id: UUID(), role: .assistant, text: reply, time: Date()))
        }
    }
}

private struct EmptyStateCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No hay eventos para hoy")
                .font(.headline)
            Button("Programar sesión rápida") {}
                .buttonStyle(.bordered)
                .tint(scheduleTeal)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 6)
        )
    }
}

// MARK: - Mock Data
private func mockEvents() -> [DemoAgendaEvent] {
    let cal = Calendar.current
    let today = Date()
    func date(_ h: Int, _ m: Int) -> Date { cal.date(bySettingHour: h, minute: m, second: 0, of: today) ?? today }
    return [
        DemoAgendaEvent(id: UUID(), title: "Clase", start: date(9, 0), end: date(10, 0), tag: nil),
        DemoAgendaEvent(id: UUID(), title: "Entreno", start: date(11, 0), end: date(12, 0), tag: "Mindfulness"),
        DemoAgendaEvent(id: UUID(), title: "Estudio", start: date(14, 0), end: date(15, 30), tag: nil),
    ]
}

#Preview("Agenda – Día") {
    ScheduleView()
}

#Preview("Agenda – Semana") {
    var view = ScheduleView()
    view
}

