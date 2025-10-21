import SwiftUI

// MARK: - Models

struct STEvent: Identifiable, Codable, Sendable {
    let id: UUID
    let title: String
    let start: Date
    let end: Date
    let tag: String?
}

struct STFreeSlot: Identifiable, Sendable {
    let id: UUID
    let start: Date
    let end: Date
}

struct STSuggestion: Identifiable, Sendable {
    let id: UUID
    let title: String
    let detail: String
    let actionTitle: String
}

struct STMessage: Identifiable, Sendable {
    enum Role { case user, assistant }
    let id: UUID
    let role: Role
    let text: String
    let time: Date
}

// MARK: - Color Fallbacks

extension Color {
    static let agendaPrimary = Color("AgendaPrimary", bundle: nil)
    static let agendaSecondary = Color("AgendaSecondary", bundle: nil)
    
    static var agendaPrimaryFallback: Color {
        agendaPrimary != Color("AgendaPrimary", bundle: nil) ? agendaPrimary : .teal.opacity(0.9)
    }
    static var agendaSecondaryFallback: Color {
        agendaSecondary != Color("AgendaSecondary", bundle: nil) ? agendaSecondary : .orange.opacity(0.9)
    }
}

// MARK: - Pure Functions

func stComputeFreeSlots(events: [STEvent], day: Date, minGapMinutes: Int = 15) -> [STFreeSlot] {
    let calendar = Calendar.current
    let dayStart = calendar.startOfDay(for: day)
    let dayEnd = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: dayStart)!
    
    // Sort events by start
    let sortedEvents = events.filter {
        calendar.isDate($0.start, inSameDayAs: day)
    }.sorted(by: { $0.start < $1.start })
    
    var freeSlots: [STFreeSlot] = []
    var marker = dayStart
    
    for event in sortedEvents {
        // Gap from marker to event.start
        let gap = event.start.timeIntervalSince(marker)
        if gap >= Double(minGapMinutes * 60) {
            freeSlots.append(STFreeSlot(id: UUID(), start: marker, end: event.start))
        }
        if event.end > marker {
            marker = event.end
        }
    }
    // Gap from last event end to day end
    let lastGap = dayEnd.timeIntervalSince(marker)
    if lastGap >= Double(minGapMinutes * 60) {
        freeSlots.append(STFreeSlot(id: UUID(), start: marker, end: dayEnd))
    }
    
    return freeSlots
}

func stMakeSuggestions(from slots: [STFreeSlot]) -> [STSuggestion] {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    
    var suggestions: [STSuggestion] = []
    for slot in slots.prefix(2) {
        let startStr = formatter.string(from: slot.start)
        let endStr = formatter.string(from: slot.end)
        let title = "Free from \(startStr) to \(endStr)"
        let detail = "Use this time to rest or plan."
        let actionTitle = "Add Reminder"
        suggestions.append(STSuggestion(id: slot.id, title: title, detail: detail, actionTitle: actionTitle))
    }
    return suggestions
}

// MARK: - ScheduleTabView

struct ScheduleTabView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case day = "Día"
        case week = "Semana"
        var id: Self { self }
    }
    
    // MARK: States
    
    @State private var mode: Mode = .day
    @State private var selectedDay: Date = Date()
    
    @State private var isGoogleLinked: Bool = false
    @State private var isNotionLinked: Bool = false
    
    @State private var showLinkSheet: Bool = false
    @State private var showCoachSheet: Bool = false
    
    @State private var messages: [STMessage] = []
    
    // MARK: Sample Events for Preview/Demo
    @State private var events: [STEvent] = []
    
    // MARK: Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Picker segmented
                Picker("Mode", selection: $mode.animation(.easeInOut)) {
                    ForEach(Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .sensoryFeedback(.selection, trigger: mode)
                
                STMiniHeaderView(selectedDay: $selectedDay)
                    .padding(.top, 6)
                
                ScrollView {
                    VStack(spacing: 16) {
                        if !isGoogleLinked && !isNotionLinked {
                            STCalendarLinkInlineCard(
                                isGoogleLinked: $isGoogleLinked,
                                isNotionLinked: $isNotionLinked,
                                showLinkSheet: $showLinkSheet
                            )
                            .padding(.horizontal)
                            .transition(.opacity)
                        }
                        
                        Group {
                            switch mode {
                            case .day:
                                dayView
                            case .week:
                                weekView
                            }
                        }
                        .contentTransition(.opacity)
                        
                        suggestionsSection
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Agenda")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Coach") {
                        showCoachSheet.toggle()
                    }
                    .accessibilityIdentifier("CoachButton")
                }
            }
            .sheet(isPresented: $showLinkSheet) {
                STCalendarLinkSheet(isGoogleLinked: $isGoogleLinked, isNotionLinked: $isNotionLinked)
            }
            .sheet(isPresented: $showCoachSheet) {
                STCoachChatSheetView(messages: $messages)
            }
            .onAppear {
                if events.isEmpty {
                    events = ScheduleTabView.generateMockEvents(for: selectedDay)
                }
            }
            .onChange(of: selectedDay) { newDay in
                // regenerate mock events on day change in preview/demo
                events = ScheduleTabView.generateMockEvents(for: newDay)
            }
        }
        .navigationViewStyle(.stack)
    }
    
    // MARK: Subviews
    
    private var dayView: some View {
        let dayEvents = events.filter { Calendar.current.isDate($0.start, inSameDayAs: selectedDay) }
        let freeSlots = stComputeFreeSlots(events: dayEvents, day: selectedDay)
        
        return VStack(alignment: .leading, spacing: 16) {
            // Events list
            ForEach(dayEvents) { event in
                STEventCardView(event: event)
                    .transition(.move(edge: .bottom).combined(with: .opacity).animation(.easeInOut.delay(0.05 * Double(events.firstIndex(where: { $0.id == event.id }) ?? 0))))
            }
            if dayEvents.isEmpty {
                Text("No hay eventos para este día.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(12)
                    .transition(.opacity)
            }
            
            // Free slots pills
            STFreeSlotPills(slots: freeSlots)
            
        }
    }
    
    private var weekView: some View {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDay)?.start ?? selectedDay
        
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
        
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(days, id: \.self) { day in
                    let eventsForDay = events.filter { calendar.isDate($0.start, inSameDayAs: day) }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(day, format: .dateTime.weekday(.abbreviated))
                            .font(.callout.bold())
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 6) {
                            ForEach(eventsForDay) { event in
                                STWeekEventBar(event: event)
                                    .transition(.opacity.animation(.easeInOut.delay(0.05 * Double(events.firstIndex(where: { $0.id == event.id }) ?? 0))))
                            }
                            if eventsForDay.isEmpty {
                                Spacer(minLength: 44)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(width: 90)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var suggestionsSection: some View {
        let dayEvents = events.filter { Calendar.current.isDate($0.start, inSameDayAs: selectedDay) }
        let freeSlots = stComputeFreeSlots(events: dayEvents, day: selectedDay)
        let suggestions = stMakeSuggestions(from: freeSlots)
        
        return VStack(alignment: .leading, spacing: 12) {
            if !suggestions.isEmpty {
                Text("Sugerencias")
                    .font(.title3.bold())
                    .padding(.bottom, 4)
                
                ForEach(suggestions) { suggestion in
                    STSuggestionCardView(suggestion: suggestion)
                        .transition(.move(edge: .leading).combined(with: .opacity).animation(.easeInOut.delay(0.1 * Double(suggestions.firstIndex(where: { $0.id == suggestion.id }) ?? 0))))
                }
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Week compact event bar
    
    struct STWeekEventBar: View {
        let event: STEvent
        
        var body: some View {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.agendaPrimaryFallback)
                    .frame(width: 8, height: 8)
                Text(event.title)
                    .font(.footnote)
                    .lineLimit(1)
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(Color.agendaPrimaryFallback.opacity(0.2))
            .cornerRadius(8)
        }
    }
}

// MARK: - Subviews

struct STMiniHeaderView: View {
    @Binding var selectedDay: Date
    
    private let calendar = Calendar.current
    private let weekdays = Calendar.current.shortWeekdaySymbols
    
    private var days: [Date] {
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDay)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(selectedDay, format: .dateTime.year().month().day())
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(days, id: \.self) { day in
                        dayButton(for: day)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 4)
        .background(
            Color(.secondarySystemBackground)
                .opacity(0.9)
                .cornerRadius(12)
        )
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func dayButton(for day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        VStack(spacing: 4) {
            Text(day, format: .dateTime.weekday(.narrow))
                .font(.caption2)
                .foregroundColor(isSelected ? .white : .secondary)
            
            Text(day, format: .dateTime.day())
                .font(.headline.monospacedDigit())
                .foregroundColor(isSelected ? .white : .primary)
        }
        .frame(width: 40, height: 56)
        .background(isSelected ? Color.agendaPrimaryFallback : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut) {
                selectedDay = day
            }
        }
        .accessibilityLabel(Text(day, format: .dateTime.weekday().day().month()))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct STEventCardView: View {
    let event: STEvent
    private let calendar = Calendar.current
    
    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: event.start)) – \(formatter.string(from: event.end))"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(event.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                if let tag = event.tag {
                    Text(tag)
                        .font(.caption.bold())
                        .padding(6)
                        .background(Color.agendaSecondaryFallback.opacity(0.3))
                        .foregroundColor(Color.agendaSecondaryFallback)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            Text(timeRange)
                .font(.subheadline.monospacedDigit())
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct STSuggestionCardView: View {
    let suggestion: STSuggestion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(suggestion.title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(suggestion.detail)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: {
                // Placeholder action
            }) {
                Text(suggestion.actionTitle)
                    .font(.callout.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.agendaPrimaryFallback)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct STCalendarLinkInlineCard: View {
    @Binding var isGoogleLinked: Bool
    @Binding var isNotionLinked: Bool
    @Binding var showLinkSheet: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Para ver tu agenda, conecta un calendario")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 24) {
                Button {
                    withAnimation(.spring()) {
                        isGoogleLinked.toggle()
                    }
                    SensoryFeedback.shared.trigger(.success)
                } label: {
                    Label("Google", systemImage: isGoogleLinked ? "checkmark.circle.fill" : "calendar")
                        .font(.callout.bold())
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(isGoogleLinked ? Color.teal.opacity(0.2) : Color.gray.opacity(0.2))
                        .foregroundColor(isGoogleLinked ? .teal : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .symbolEffect(.bounce, value: isGoogleLinked)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Conectar Google Calendar")
                
                Button {
                    withAnimation(.spring()) {
                        isNotionLinked.toggle()
                    }
                    SensoryFeedback.shared.trigger(.success)
                } label: {
                    Label("Notion", systemImage: isNotionLinked ? "checkmark.circle.fill" : "calendar.badge.plus")
                        .font(.callout.bold())
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(isNotionLinked ? Color.orange.opacity(0.2) : Color.gray.opacity(0.2))
                        .foregroundColor(isNotionLinked ? .orange : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .symbolEffect(.bounce, value: isNotionLinked)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Conectar Notion Calendar")
            }
            
            Button("Más opciones") {
                showLinkSheet = true
            }
            .font(.footnote.bold())
            .foregroundColor(.accentColor)
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
    }
}

struct STCoachChatSheetView: View {
    @Binding var messages: [STMessage]
    @Environment(\.dismiss) private var dismiss
    @State private var inputText: String = ""
    @FocusState private var inputFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(messages) { msg in
                                messageView(msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    .onChange(of: messages.count) { _ in
                        if let last = messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                HStack {
                    TextField("Escribe un mensaje...", text: $inputText)
                        .textFieldStyle(.roundedBorder)
                        .focused($inputFocused)
                        .submitLabel(.send)
                        .onSubmit(sendMessage)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .accentColor)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .navigationTitle("Coach")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
            .onTapGesture {
                inputFocused = false
            }
        }
    }
    
    @ViewBuilder
    private func messageView(_ msg: STMessage) -> some View {
        HStack {
            if msg.role == .assistant {
                Spacer()
            }
            
            VStack(alignment: msg.role == .user ? .trailing : .leading, spacing: 4) {
                Text(msg.text)
                    .foregroundColor(msg.role == .user ? .white : .primary)
                    .padding(10)
                    .background(msg.role == .user ? Color.accentColor : Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .font(.body)
                
                Text(msg.time, style: .time)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            if msg.role == .user {
                Spacer(minLength: 40)
            }
        }
        .padding(msg.role == .user ? .leading : .trailing, 40)
    }
    
    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let newMsg = STMessage(id: UUID(), role: .user, text: trimmed, time: Date())
        messages.append(newMsg)
        inputText = ""
        
        // Simulate assistant reply after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let reply = STMessage(id: UUID(), role: .assistant, text: "Gracias por tu mensaje: \"\(trimmed)\". Estoy aquí para ayudarte.", time: Date())
            messages.append(reply)
        }
    }
}

struct STCalendarLinkSheet: View {
    @Binding var isGoogleLinked: Bool
    @Binding var isNotionLinked: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Conectar Calendarios") {
                    Toggle(isOn: $isGoogleLinked.animation(.spring())) {
                        Label("Google Calendar", systemImage: "calendar")
                    }
                    Toggle(isOn: $isNotionLinked.animation(.spring())) {
                        Label("Notion Calendar", systemImage: "calendar.badge.plus")
                    }
                }
                
                Section {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Calendarios")
        }
    }
}

struct STFreeSlotPills: View {
    let slots: [STFreeSlot]
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(slots) { slot in
                    Text("\(formatter.string(from: slot.start))–\(formatter.string(from: slot.end))")
                        .font(.callout.monospacedDigit())
                        .padding(.vertical, 6)
                        .padding(.horizontal, 14)
                        .background(Color.agendaSecondaryFallback.opacity(0.3))
                        .foregroundColor(Color.agendaSecondaryFallback)
                        .clipShape(Capsule())
                        .accessibilityLabel("Disponible de \(formatter.string(from: slot.start)) a \(formatter.string(from: slot.end))")
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Sensory Feedback Wrapper

final class SensoryFeedback {
    static let shared = SensoryFeedback()
    private init() {}
    
    func trigger(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
        #endif
    }
}

extension View {
    /// Simplified sensory feedback using Combine-like trigger
    func sensoryFeedback<T: Equatable>(_ type: UINotificationFeedbackGenerator.FeedbackType, trigger: T) -> some View {
        self.onChange(of: trigger) { _ in
            SensoryFeedback.shared.trigger(type)
        }
    }
}

// MARK: - Preview + Helpers

extension ScheduleTabView {
    static func generateMockEvents(for day: Date) -> [STEvent] {
        let calendar = Calendar.current
        guard let base = calendar.dateInterval(of: .day, for: day)?.start else {
            return []
        }
        return [
            STEvent(id: UUID(), title: "Reunión con equipo", start: calendar.date(byAdding: .hour, value: 9, to: base)!, end: calendar.date(byAdding: .hour, value: 10, to: base)!, tag: "Trabajo"),
            STEvent(id: UUID(), title: "Llamada con cliente", start: calendar.date(byAdding: .hour, value: 11, to: base)!, end: calendar.date(byAdding: .hour, value: 11, minute: 30, second: 0, to: base)!, tag: "Cliente"),
            STEvent(id: UUID(), title: "Almuerzo", start: calendar.date(byAdding: .hour, value: 13, to: base)!, end: calendar.date(byAdding: .hour, value: 14, to: base)!, tag: nil),
            STEvent(id: UUID(), title: "Revisión de proyecto", start: calendar.date(byAdding: .hour, value: 15, to: base)!, end: calendar.date(byAdding: .hour, value: 16, to: base)!, tag: "Trabajo"),
            STEvent(id: UUID(), title: "Yoga", start: calendar.date(byAdding: .hour, value: 18, to: base)!, end: calendar.date(byAdding: .hour, value: 19, to: base)!, tag: "Personal")
        ]
    }
}

extension Calendar {
    func date(byAdding component: Calendar.Component, value: Int, minute: Int = 0, second: Int = 0, to date: Date) -> Date? {
        var date = self.date(byAdding: component, value: value, to: date)
        if let dateUnwrapped = date {
            date = self.date(bySettingHour: self.component(.hour, from: dateUnwrapped), minute: minute, second: second, of: dateUnwrapped)
        }
        return date
    }
}

#Preview("Agenda – Día") {
    ScheduleTabView()
}

#Preview("Agenda – Semana") {
    ScheduleTabView()
}
