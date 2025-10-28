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
        let rationale: String?
        let scheduledAt: Date?
        let actionTitle: String
        let escalate: Bool
        let bookingURL: URL?
        let modelVersion: String
        let events: [DailyRecommendationEventContextDTO]
        let raw: DailyRecommendationResponseDTO
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
    @Published private var latestAssessments: [AssessmentInstrument: Date] = [:]
    @Published private var subscriptionTier: SubscriptionTier = .free

    private let userId: String
    private let userName: String?
    private let analytics: AnalyticsServiceProtocol
    private let databaseService: SupabaseDatabaseService
    private let calendarService: SupabaseCalendarService
    private let quoteService: QuoteService
    private let aiService: AIServiceProtocol

    init(userId: String,
         userName: String?,
         analytics: AnalyticsServiceProtocol,
         aiService: AIServiceProtocol? = nil,
         databaseService: SupabaseDatabaseService? = nil,
         calendarService: SupabaseCalendarService? = nil,
         quoteService: QuoteService? = nil) {
        self.userId = userId
        self.userName = userName
        self.analytics = analytics
        self.aiService = aiService ?? AIService()
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
            async let entitlementsTask = databaseService.listEntitlements()
            async let assessmentsTask = databaseService.listAssessments()
            async let moodsTask = databaseService.fetchMoods()
            async let habitsTask = databaseService.listHabits()
            async let habitLogsTask = databaseService.listHabitLogs(for: nil)
            async let eventsTask = calendarService.listEvents(from: startOfDay, to: endOfDay)
            async let sleepPrefsTask = databaseService.getSleepPreferences()

            let entitlements = try await entitlementsTask
            subscriptionTier = determineTier(from: entitlements)

            let moods = try await moodsTask
            let habits = try await habitsTask
            let habitLogs = try await habitLogsTask
            let events = try await eventsTask
            let sleepPrefs = try await sleepPrefsTask
            let assessments = try await assessmentsTask
            latestAssessments = mapLatestAssessments(from: assessments)
            hasCheckInToday = didCheckInToday(moods: moods, calendar: calendar)

            let sortedEvents = events.sorted { $0.start < $1.start }
            let freeSlotsRaw = computeFreeSlots(events: sortedEvents, dayBounds: (startOfDay, endOfDay))
            agendaPreview = buildAgendaPreview(events: sortedEvents, freeSlots: freeSlotsRaw)
            analytics.track(event: AnalyticsEvent(name: "agenda_preview_shown", parameters: ["events": sortedEvents.count, "free_slots": freeSlotsRaw.count]))

            do {
                let dailyTip = try await aiService.dailyRecommendation(for: userId, date: today)
                let viewData = makeDailyRecommendationViewData(from: dailyTip)
                recommendation = viewData
                analytics.track(
                    event: AnalyticsEvent(
                        name: "daily_tip_requested",
                        parameters: [
                            "model": dailyTip.modelVersion,
                            "tier": subscriptionTier.rawValue,
                            "escalate": dailyTip.escalate
                        ]
                    )
                )
            } catch {
                recommendation = nil
                analytics.track(
                    event: AnalyticsEvent(
                        name: "daily_tip_failed",
                        parameters: [
                            "error": error.localizedDescription,
                            "tier": subscriptionTier.rawValue
                        ]
                    )
                )
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

    var pendingTests: [AssessmentInstrument] {
        let statuses = testStatuses
        return AssessmentInstrument.allCases.filter { instrument in
            guard let status = statuses[instrument] else { return false }
            switch status {
            case .neverTaken:
                return true
            case .available(let lastTaken):
                if subscriptionTier == .premium {
                    return lastTaken == nil
                }
                return true
            case .lockedUntil:
                return true
            }
        }
    }

    var testStatuses: [AssessmentInstrument: AssessmentStatus] {
        let calendar = Calendar.current
        let now = Date()
        var result: [AssessmentInstrument: AssessmentStatus] = [:]
        for instrument in AssessmentInstrument.allCases {
            let status = AssessmentEligibility.status(
                for: instrument,
                lastTaken: latestAssessments[instrument],
                tier: subscriptionTier,
                referenceDate: now,
                calendar: calendar
            )
            result[instrument] = status
        }
        return result
    }

    func trackHomeTestsCTA() {
        analytics.track(
            event: AnalyticsEvent(
                name: "test_cta_home_clicked",
                parameters: [
                    "pending": pendingTests.count,
                    "tier": subscriptionTier.rawValue
                ]
            )
        )
    }

    func makeTestsOverviewViewModel() -> TestsOverviewViewModel {
        TestsOverviewViewModel(
            databaseService: databaseService,
            analytics: analytics
        )
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

    private func makeDailyRecommendationViewData(from response: DailyRecommendationResponseDTO) -> DailyRecommendationViewData {
        let fallback = "Kai está disponible en el chat si necesitas ajustar tu plan hoy."
        let body = response.recommendations.first ?? fallback
        let scheduledAt = response.eventContext.first?.start
        let title = response.escalate ? "Kai detectó señales importantes" : "Recomendación de hoy"
        let actionTitle = response.escalate ? "Solicitar apoyo profesional" : "Abrir chat con Kai"

        return DailyRecommendationViewData(
            title: title,
            body: body,
            rationale: response.rationale,
            scheduledAt: scheduledAt,
            actionTitle: actionTitle,
            escalate: response.escalate,
            bookingURL: nil,
            modelVersion: response.modelVersion,
            events: response.eventContext,
            raw: response
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

    func trackRecommendationTap() {
        var parameters: [String: Any] = ["user_id": userId]
        if let recommendation {
            parameters["model"] = recommendation.modelVersion
            parameters["escalate"] = recommendation.escalate
        }
        analytics.track(event: AnalyticsEvent(name: "daily_tip_card_tapped", parameters: parameters))
    }

    func escalateFromDailyTip() async -> EscalationResponseDTO? {
        guard let recommendation else { return nil }
        let context: [String: String] = [
            "source": "daily_tip",
            "model": recommendation.modelVersion,
            "recommendation": recommendation.body
        ]
        do {
            let response = try await aiService.escalate(for: userId, context: context, reason: "daily_tip_escalation")
            analytics.track(
                event: AnalyticsEvent(
                    name: "escalation_triggered",
                    parameters: [
                        "source": "daily_tip",
                        "escalate": response.escalate,
                        "booking_url": response.bookingURL?.absoluteString ?? "none"
                    ]
                )
            )
            return response
        } catch {
            analytics.track(
                event: AnalyticsEvent(
                    name: "escalation_failed",
                    parameters: [
                        "source": "daily_tip",
                        "error": error.localizedDescription
                    ]
                )
            )
            return nil
        }
    }

    private func determineTier(from entitlements: [EntitlementRow]) -> SubscriptionTier {
        entitlements.contains(where: { $0.active && $0.product.lowercased().contains("premium") }) ? .premium : .free
    }

    private func mapLatestAssessments(from rows: [AssessmentRow]) -> [AssessmentInstrument: Date] {
        rows.reduce(into: [AssessmentInstrument: Date]()) { result, row in
            guard let instrument = AssessmentInstrument(rawValue: row.instrument) else { return }
            if let existing = result[instrument] {
                if row.taken_at > existing {
                    result[instrument] = row.taken_at
                }
            } else {
                result[instrument] = row.taken_at
            }
        }
    }
}
