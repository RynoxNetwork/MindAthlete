import Combine
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    struct HeroContent {
        let greeting: String
        let quote: String
    }

    struct AgendaPreview {
        struct Item: Identifiable {
            let id = UUID()
            let timeRange: String
            let title: String
            let iconName: String?
        }

        struct FreeSlot: Identifiable {
            let id = UUID()
            let label: String
            let minutes: Int
        }

        let items: [Item]
        let freeSlots: [FreeSlot]
    }

    struct DailyRecommendationViewData {
        let title: String
        let body: String
        let scheduledAt: Date
        let actionTitle: String
    }

    struct HabitsProgressViewData {
        let streak: Int
        let completionPercent: Double
        let message: String
    }

    struct FreeSlotRaw {
        let start: Date
        let end: Date
        var minutes: Int { Int(end.timeIntervalSince(start) / 60) }
    }

    @Published var hero: HeroContent?
    @Published var hasCheckInToday: Bool = false
    @Published var agendaPreview: AgendaPreview?
    @Published var recommendation: DailyRecommendationViewData?
    @Published var habitsProgress: HabitsProgressViewData?
    @Published var isLoading: Bool = false

    private let userId: String
    private let userName: String?
    private let analytics: AnalyticsServiceProtocol
    private let databaseService: SupabaseDatabaseService
    private let calendarService: SupabaseCalendarService
    private let quoteService: QuoteService

    init(userId: String,
         userName: String?,
         analytics: AnalyticsServiceProtocol,
         databaseService: SupabaseDatabaseService? = nil,
         calendarService: SupabaseCalendarService? = nil,
         quoteService: QuoteService? = nil) {
        self.userId = userId
        self.userName = userName
        self.analytics = analytics
        self.databaseService = databaseService ?? SupabaseDatabaseService()
        self.calendarService = calendarService ?? SupabaseCalendarService()
        self.quoteService = quoteService ?? QuoteService()
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)?.addingTimeInterval(-1) ?? today

        let heroContent = buildHeroContent()
        hero = heroContent
        analytics.track(event: AnalyticsEvent(name: "home_quote_shown", parameters: ["quote": heroContent.quote]))

        do {
            async let moodsTask = databaseService.fetchMoods()
            async let habitsTask = databaseService.listHabits()
            async let habitLogsTask = databaseService.listHabitLogs(for: nil)
            async let eventsTask = calendarService.listEvents(from: startOfDay, to: endOfDay)
            async let sleepPrefsTask = databaseService.getSleepPreferences()

            let moods = try await moodsTask
            let habits = try await habitsTask
            let habitLogs = try await habitLogsTask
            let events = try await eventsTask
            let sleepPrefs = try await sleepPrefsTask
            hasCheckInToday = didCheckInToday(moods: moods, calendar: calendar)

            let sortedEvents = events.sorted { $0.start < $1.start }
            let freeSlotsRaw = computeFreeSlots(events: sortedEvents, dayBounds: (startOfDay, endOfDay))
            agendaPreview = buildAgendaPreview(events: sortedEvents, freeSlots: freeSlotsRaw)
            analytics.track(event: AnalyticsEvent(name: "agenda_preview_shown", parameters: ["events": sortedEvents.count, "free_slots": freeSlotsRaw.count]))

            let context = CoachContext(
                todayEvents: sortedEvents,
                freeBlocks: freeSlotsRaw.map { TimeIntervalBlock(start: $0.start, end: $0.end) },
                latestPOMS: (nil as POMSResult?),
                idep: (nil as IDEPResult?),
                sleepPrefs: sleepPrefs.map { row in
                    SleepPrefs(
                        targetWakeTime: row.target_wake_time.flatMap { parseTimeComponents($0) },
                        cycles: row.cycles ?? 5,
                        bufferMinutes: row.buffer_minutes ?? 15
                    )
                },
                energy: latestMood(moods: moods)?.energy,
                stress: latestMood(moods: moods)?.stress,
                upcomingGoal: (nil as Goal?)
            )

            if let reco = buildDailyRecommendation(context: context, slots: freeSlotsRaw) {
                recommendation = reco
                analytics.track(event: AnalyticsEvent(name: "daily_reco_shown", parameters: ["time": reco.scheduledAt.timeIntervalSince1970]))
            } else {
                recommendation = nil
            }

            habitsProgress = buildHabitsProgress(habits: habits, logs: habitLogs, calendar: calendar)
            if let progress = habitsProgress {
                analytics.track(event: AnalyticsEvent(name: "habits_preview_shown", parameters: ["streak": progress.streak, "completion": progress.completionPercent]))
            }

            analytics.track(event: AnalyticsEvent(name: "home_loaded", parameters: ["user_id": userId, "events": sortedEvents.count]))
        } catch {
            analytics.track(event: AnalyticsEvent(name: "home_load_failed", parameters: ["error": error.localizedDescription]))
        }
    }

    // MARK: - Builders

    private func buildHeroContent() -> HeroContent {
        let firstName: String?
        if let userName {
            if userName.contains("@") {
                firstName = userName.split(separator: "@").first.map { String($0).capitalized }
            } else {
                firstName = userName.split(separator: " ").first.map { String($0).capitalized }
            }
        } else {
            firstName = nil
        }

        let greeting: String
        if let firstName {
            greeting = "\(firstName), bienvenido de vuelta"
        } else {
            greeting = "Bienvenido de vuelta"
        }

        return HeroContent(greeting: greeting, quote: quoteService.randomQuote())
    }

    private func didCheckInToday(moods: [MoodRow], calendar: Calendar) -> Bool {
        moods.contains { row in
            if let created = row.created_at {
                return calendar.isDate(created, inSameDayAs: Date())
            }
            return false
        }
    }

    private func latestMood(moods: [MoodRow]) -> MoodRow? {
        moods.sorted { ($0.created_at ?? .distantPast) > ($1.created_at ?? .distantPast) }.first
    }

    private func buildAgendaPreview(events: [AgendaEvent], freeSlots: [FreeSlotRaw]) -> AgendaPreview {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let eventItems = events.prefix(3).map { event in
            AgendaPreview.Item(
                timeRange: "\(timeFormatter.string(from: event.start))",
                title: event.title,
                iconName: icon(for: event.kind)
            )
        }

        let freeSlotItems = freeSlots
            .sorted { $0.minutes > $1.minutes }
            .prefix(2)
            .map { slot in
                AgendaPreview.FreeSlot(
                    label: "\(timeFormatter.string(from: slot.start))–\(timeFormatter.string(from: slot.end))",
                    minutes: slot.minutes
                )
            }

        return AgendaPreview(items: Array(eventItems), freeSlots: Array(freeSlotItems))
    }

    private func buildDailyRecommendation(context: CoachContext, slots: [FreeSlotRaw]) -> DailyRecommendationViewData? {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        // Regla 1: Competencia próxima
        if let competition = context.todayEvents.first(where: { $0.kind == "competencia" }) {
            let target = competition.start.addingTimeInterval(-20 * 60)
            if let slot = slots.first(where: { slotContains($0, target: target, duration: 180) }) {
                return DailyRecommendationViewData(
                    title: "Respiración box 3 min",
                    body: "Prepárate antes de la competencia. Toma 3 minutos a las \(timeFormatter.string(from: target)).",
                    scheduledAt: target,
                    actionTitle: "Iniciar respiración"
                )
            }
        }

        // Regla 2: Energía baja
        if let energy = context.energy, energy <= 4 {
            if let slot = slots.first(where: { slot in
                slot.minutes >= 15 && isBetweenNoon(slot.start, calendar: calendar)
            }) {
                let start = slot.start.addingTimeInterval(5 * 60)
                return DailyRecommendationViewData(
                    title: "Respiración 4-7-8",
                    body: "Recarga energía en tu hueco de \(slotLabel(slot)). Dedica 3 minutos a calmar tu sistema." ,
                    scheduledAt: start,
                    actionTitle: "Respirar 3 min"
                )
            }
        }

        if let slot = slots.first(where: { $0.minutes >= 20 }) {
            return DailyRecommendationViewData(
                title: "Journaling 5 min",
                body: "Tienes un espacio de \(slotLabel(slot)). Aprovecha para escribir cómo te sientes y qué harás hoy.",
                scheduledAt: slot.start.addingTimeInterval(5 * 60),
                actionTitle: "Escribir ahora"
            )
        }

        if let slot = slots.first {
            return DailyRecommendationViewData(
                title: "Micro reset 90 s",
                body: "Haz un reset rápido en tu hueco de \(slotLabel(slot)). 10 respiraciones profundas bastan.",
                scheduledAt: slot.start.addingTimeInterval(2 * 60),
                actionTitle: "Iniciar micro reset"
            )
        }

        return DailyRecommendationViewData(
            title: "Micro reset 90 s",
            body: "Aunque tu agenda esté llena, tómate 90 segundos ahora para centrarte.",
            scheduledAt: Date(),
            actionTitle: "Respirar ahora"
        )
    }

    private func buildHabitsProgress(habits: [HabitRow], logs: [HabitLogRow], calendar: Calendar) -> HabitsProgressViewData {
        guard !habits.isEmpty else {
            return HabitsProgressViewData(streak: 0, completionPercent: 0, message: "Crea tu primer hábito para iniciar tu racha.")
        }

        let today = calendar.startOfDay(for: Date())
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        let daysElapsed = max(calendar.dateComponents([.day], from: startOfMonth, to: today).day ?? 0, 0) + 1

        let logsThisMonth = logs.filter { calendar.isDate($0.performed_at, equalTo: today, toGranularity: .month) }
        let uniqueDays = Set(logsThisMonth.map { calendar.startOfDay(for: $0.performed_at) })

        var streak = 0
        var cursor = today
        while uniqueDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        let completion = daysElapsed > 0 ? Double(uniqueDays.count) / Double(daysElapsed) : 0
        let percent = max(0, min(1, completion))

        let message: String
        if streak > 0 {
            message = "Vas \(streak) día\(streak == 1 ? "" : "s") seguidos. Mantén el ritmo!"
        } else {
            message = "Hoy es un buen día para sumar tu primer check-in."
        }

        return HabitsProgressViewData(streak: streak, completionPercent: percent, message: message)
    }

    private func computeFreeSlots(events: [AgendaEvent], dayBounds: (Date, Date), minMinutes: Int = 15) -> [FreeSlotRaw] {
        var cursor = dayBounds.0
        var blocks: [FreeSlotRaw] = []

        for event in events.sorted(by: { $0.start < $1.start }) {
            if event.start > cursor {
                let blockEnd = min(event.start, dayBounds.1)
                let block = FreeSlotRaw(start: cursor, end: blockEnd)
                if block.minutes >= minMinutes {
                    blocks.append(block)
                }
            }
            cursor = max(cursor, event.end)
            if cursor >= dayBounds.1 { break }
        }

        if cursor < dayBounds.1 {
            let block = FreeSlotRaw(start: cursor, end: dayBounds.1)
            if block.minutes >= minMinutes {
                blocks.append(block)
            }
        }

        return blocks
    }

    private func icon(for kind: String?) -> String? {
        switch kind {
        case "clase": return "book"
        case "entreno": return "figure.run"
        case "competencia": return "flag.checkered"
        case "examen": return "brain"
        default: return "calendar"
        }
    }

    private func parseTimeComponents(_ timeString: String) -> DateComponents {
        let parts = timeString.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return DateComponents(hour: 7, minute: 0) }
        return DateComponents(hour: hour, minute: minute)
    }

    private func slotContains(_ slot: FreeSlotRaw, target: Date, duration: TimeInterval) -> Bool {
        target >= slot.start && target.addingTimeInterval(duration) <= slot.end
    }

    private func isBetweenNoon(_ date: Date, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= 12 && hour < 15
    }

    private func slotLabel(_ slot: FreeSlotRaw) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: slot.start))–\(formatter.string(from: slot.end))"
    }

    func trackRecommendationTap() {
        analytics.track(event: AnalyticsEvent(name: "daily_reco_clicked", parameters: ["user_id": userId]))
    }
}

