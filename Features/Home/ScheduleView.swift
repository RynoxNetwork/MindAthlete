import Combine
import SwiftUI
import UIKit

enum AgendaMode: String, CaseIterable, Identifiable {
    case day = "Día"
    case week = "Semana"

    var id: Self { self }
}

enum AgendaScheduleSource: String, Hashable {
    case google
    case notion
    case manual
    case external
    case unknown

    init(provider: String?) {
        switch provider?.lowercased() {
        case "google":
            self = .google
        case "notion":
            self = .notion
        case "local", "manual":
            self = .manual
        case "external":
            self = .external
        case .none:
            self = .manual
        default:
            self = .unknown
        }
    }

    var analyticsValue: String {
        switch self {
        case .unknown:
            return "unknown"
        default:
            return rawValue
        }
    }
}

enum AgendaCategory: String, CaseIterable, Identifiable {
    case personal
    case training
    case work
    case client
    case study
    case recovery
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .personal: return "Personal"
        case .training: return "Entrenamiento"
        case .work: return "Trabajo"
        case .client: return "Clientes"
        case .study: return "Estudio"
        case .recovery: return "Recuperación"
        case .other: return "Otro"
        }
    }

    var defaultHex: String {
        switch self {
        case .personal: return "#63C174"
        case .training: return "#1BA6A6"
        case .work: return "#F2C94C"
        case .client: return "#4E9CFF"
        case .study: return "#8B6FF2"
        case .recovery: return "#76C7C5"
        case .other: return "#475569"
        }
    }

    var databaseKind: String {
        switch self {
        case .training, .recovery: return "entreno"
        case .study: return "clase"
        case .client: return "otro"
        case .work: return "otro"
        case .personal, .other: return "otro"
        }
    }

    var iconName: String {
        switch self {
        case .personal: return "heart"
        case .training: return "figure.run"
        case .work: return "briefcase"
        case .client: return "person.2"
        case .study: return "book"
        case .recovery: return "sparkles"
        case .other: return "circle"
        }
    }

    static var primary: [AgendaCategory] {
        [.personal, .training, .work, .client, .study]
    }
}

enum AgendaWeekday: String, CaseIterable, Identifiable {
    case monday = "Mon"
    case tuesday = "Tue"
    case wednesday = "Wed"
    case thursday = "Thu"
    case friday = "Fri"
    case saturday = "Sat"
    case sunday = "Sun"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .monday: return "Lun"
        case .tuesday: return "Mar"
        case .wednesday: return "Mié"
        case .thursday: return "Jue"
        case .friday: return "Vie"
        case .saturday: return "Sáb"
        case .sunday: return "Dom"
        }
    }

    var calendarValue: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }

    static func from(date: Date, calendar: Calendar = .current) -> AgendaWeekday {
        let weekday = calendar.component(.weekday, from: date)
        return AgendaWeekday.allCases.first { $0.calendarValue == weekday } ?? .monday
    }
}

struct AgendaCategoryColor: Equatable {
    let hex: String
    let textHex: String

    var backgroundColor: Color { Color(hex: hex) }
    var textColor: Color { Color(hex: textHex) }
}

final class AgendaColorStore: ObservableObject {
    @Published private(set) var colors: [AgendaCategory: AgendaCategoryColor] = [:]

    private let defaults: UserDefaults
    private let keyPrefix = "agenda.category.color."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reload()
    }

    func color(for category: AgendaCategory) -> AgendaCategoryColor {
        colors[category] ?? Self.makeColor(hex: category.defaultHex)
    }

    func update(color: Color, for category: AgendaCategory) {
        let hex = Self.hexString(from: color)
        defaults.set(hex, forKey: keyPrefix + category.rawValue)
        colors[category] = Self.makeColor(hex: hex)
    }

    func reset(_ category: AgendaCategory) {
        defaults.removeObject(forKey: keyPrefix + category.rawValue)
        colors[category] = Self.makeColor(hex: category.defaultHex)
    }

    func reload() {
        var palette: [AgendaCategory: AgendaCategoryColor] = [:]
        for category in AgendaCategory.allCases {
            let stored = defaults.string(forKey: keyPrefix + category.rawValue)
            palette[category] = Self.makeColor(hex: stored ?? category.defaultHex)
        }
        colors = palette
    }
}

private extension AgendaColorStore {
    static func makeColor(hex: String) -> AgendaCategoryColor {
        let sanitized = sanitize(hex: hex)
        let text = idealTextHex(for: sanitized)
        return AgendaCategoryColor(hex: sanitized, textHex: text)
    }

    static func sanitize(hex: String) -> String {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !value.hasPrefix("#") {
            value = "#\(value)"
        }
        if value.count == 4 {
            let digits = value.dropFirst()
            var expanded = "#"
            for char in digits {
                expanded.append(char)
                expanded.append(char)
            }
            value = expanded
        }
        if value.count != 7 {
            return "#1BA6A6"
        }
        return value
    }

    static func idealTextHex(for hex: String) -> String {
        guard let components = rgbComponents(for: hex) else { return "#FFFFFF" }
        let luminance = relativeLuminance(r: components.r, g: components.g, b: components.b)
        return luminance > 0.55 ? "#0F172A" : "#FFFFFF"
    }

    static func rgbComponents(for hex: String) -> (r: Double, g: Double, b: Double)? {
        let sanitized = sanitize(hex: hex)
        guard sanitized.count == 7 else { return nil }
        let start = sanitized.index(after: sanitized.startIndex)
        let rString = String(sanitized[start..<sanitized.index(start, offsetBy: 2)])
        let gStart = sanitized.index(start, offsetBy: 2)
        let gString = String(sanitized[gStart..<sanitized.index(gStart, offsetBy: 2)])
        let bStart = sanitized.index(gStart, offsetBy: 2)
        let bString = String(sanitized[bStart..<sanitized.index(bStart, offsetBy: 2)])
        guard
            let r = UInt8(rString, radix: 16),
            let g = UInt8(gString, radix: 16),
            let b = UInt8(bString, radix: 16)
        else { return nil }
        return (Double(r) / 255.0, Double(g) / 255.0, Double(b) / 255.0)
    }

    static func relativeLuminance(r: Double, g: Double, b: Double) -> Double {
        func adjust(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * adjust(r) + 0.7152 * adjust(g) + 0.0722 * adjust(b)
    }

    static func hexString(from color: Color) -> String {
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return "#1BA6A6"
        }
        return String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }
}

struct AgendaEventViewData: Identifiable, Equatable {
    let id: UUID
    let title: String
    let start: Date
    let end: Date
    let notes: String?
    let category: AgendaCategory
    let source: AgendaScheduleSource
    let trainingType: String?
    let studyFocus: String?
    let recurrence: AgendaRecurrence?
    let isOverride: Bool
    let recurrenceSummary: String?
}

struct AgendaDaySection: Identifiable, Equatable {
    let date: Date
    let events: [AgendaEventViewData]

    var id: Date { date }
}

struct AgendaFreeSlotViewData: Identifiable, Equatable {
    let id: UUID
    let start: Date
    let end: Date

    var durationMinutes: Int {
        max(0, Int(end.timeIntervalSince(start) / 60))
    }
}

struct AgendaSuggestionViewData: Identifiable, Equatable {
    enum Style {
        case primary
        case secondary
    }

    let id: UUID
    let slot: AgendaFreeSlotViewData
    let title: String
    let detail: String
    let actionTitle: String
    let style: Style
    let rationale: String?
    let recommendationId: UUID?

    init(
        id: UUID = UUID(),
        slot: AgendaFreeSlotViewData,
        title: String,
        detail: String,
        actionTitle: String,
        style: Style,
        rationale: String? = nil,
        recommendationId: UUID? = nil
    ) {
        self.id = id
        self.slot = slot
        self.title = title
        self.detail = detail
        self.actionTitle = actionTitle
        self.style = style
        self.rationale = rationale
        self.recommendationId = recommendationId
    }
}

struct AgendaRecurrenceEngine {
    static func generateOccurrences(master: AgendaEvent, recurrence: AgendaRecurrence, calendar: Calendar, horizonMonths: Int, notes: String) -> [AgendaEvent] {
        guard recurrence.isRecurring else { return [] }
        let horizon = recurrence.endDate ?? calendar.date(byAdding: .month, value: horizonMonths, to: master.start) ?? master.start
        guard horizon > master.start else { return [] }

        let duration = max(60, Int(master.end.timeIntervalSince(master.start)))
        var dates: [Date] = []

        switch recurrence.frequency {
        case .daily:
            var next = calendar.date(byAdding: .day, value: 1, to: master.start) ?? master.start
            while next <= horizon {
                dates.append(next)
                guard let candidate = calendar.date(byAdding: .day, value: 1, to: next) else { break }
                next = candidate
            }
        case .weekly, .biweekly:
            let repeatSetRaw = Set((recurrence.repeatDays.isEmpty ? [weekdayKey(for: master.start, calendar: calendar)] : recurrence.repeatDays))
            let repeatWeekdays = repeatSetRaw.compactMap { AgendaWeekday(rawValue: $0) }
            let repeatSet = Set(repeatWeekdays.isEmpty ? [AgendaWeekday.from(date: master.start, calendar: calendar)] : repeatWeekdays)
            let baseWeekStart = startOfWeek(for: master.start, calendar: calendar)
            var cursor = calendar.startOfDay(for: master.start)
            guard let firstStep = calendar.date(byAdding: .day, value: 1, to: cursor) else { return [] }
            cursor = firstStep
            while cursor <= horizon {
                let currentWeekStart = startOfWeek(for: cursor, calendar: calendar)
                let weeksBetween = calendar.dateComponents([.weekOfYear], from: baseWeekStart, to: currentWeekStart).weekOfYear ?? 0
                if recurrence.frequency == .biweekly && weeksBetween % 2 != 0 {
                    guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                    cursor = nextDay
                    continue
                }
                let weekday = AgendaWeekday.from(date: cursor, calendar: calendar)
                if repeatSet.contains(weekday) {
                    if let candidate = combine(date: cursor, withTimeFrom: master.start, calendar: calendar), candidate > master.start, candidate <= horizon {
                        dates.append(candidate)
                    }
                }
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = nextDay
            }
        case .monthly:
            var monthOffset = 1
            while let candidate = calendar.date(byAdding: .month, value: monthOffset, to: master.start) {
                if candidate > horizon { break }
                dates.append(candidate)
                monthOffset += 1
            }
        case .none:
            break
        }

        let uniqueDates = Array(Set(dates)).sorted()
        return uniqueDates.map { startDate in
            AgendaEvent(
                id: UUID(),
                title: master.title,
                start: startDate,
                end: startDate.addingTimeInterval(TimeInterval(duration)),
                kind: master.kind,
                notes: notes,
                source: master.source,
                recurrence: nil,
                overrideParentId: master.id,
                isOverride: false
            )
        }
    }

    private static func weekdayKey(for date: Date, calendar: Calendar) -> String {
        AgendaWeekday.from(date: date, calendar: calendar).rawValue
    }

    private static func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        if let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start {
            return start
        }
        return calendar.startOfDay(for: date)
    }

    private static func combine(date: Date, withTimeFrom reference: Date, calendar: Calendar) -> Date? {
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: reference)
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        return calendar.date(from: components)
    }
}

struct AgendaEventDraft: Identifiable {
    let id = UUID()
    var category: AgendaCategory?
    var title: String
    var start: Date
    var end: Date
    var notes: String
    var trainingType: String
    var studyFocus: String
    var recurrenceEnabled: Bool
    var recurrenceFrequency: AgendaRecurrenceFrequency
    var repeatDays: Set<AgendaWeekday>
    var recurrenceHasEndDate: Bool
    var recurrenceEndDate: Date

    init(
        category: AgendaCategory? = nil,
        title: String = "",
        start: Date = Date(),
        end: Date = Date().addingTimeInterval(3600),
        notes: String = "",
        trainingType: String = "",
        studyFocus: String = "",
        recurrenceEnabled: Bool = false,
        recurrenceFrequency: AgendaRecurrenceFrequency = .none,
        repeatDays: Set<AgendaWeekday> = [],
        recurrenceHasEndDate: Bool = false,
        recurrenceEndDate: Date? = nil
    ) {
        self.category = category
        self.title = title
        self.start = start
        self.end = end
        self.notes = notes
        self.trainingType = trainingType
        self.studyFocus = studyFocus
        self.recurrenceEnabled = recurrenceEnabled
        self.recurrenceFrequency = recurrenceFrequency
        self.repeatDays = repeatDays
        self.recurrenceHasEndDate = recurrenceHasEndDate
        self.recurrenceEndDate = recurrenceEndDate ?? end
    }

    var sanitizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var duration: TimeInterval {
        max(0, end.timeIntervalSince(start))
    }

    var recurrence: AgendaRecurrence? {
        guard recurrenceEnabled else { return nil }
        var days: [String] = []
        if recurrenceFrequency == .weekly || recurrenceFrequency == .biweekly {
            if repeatDays.isEmpty {
                days = [AgendaWeekday.from(date: start).rawValue]
            } else {
                days = repeatDays.sorted { $0.calendarValue < $1.calendarValue }.map(\.rawValue)
            }
        }
        let endDate = recurrenceHasEndDate ? max(recurrenceEndDate, start) : nil
        return AgendaRecurrence(
            frequency: recurrenceFrequency,
            repeatDays: days,
            endDate: endDate
        )
    }

    var recurrenceSummary: String {
        guard let recurrence else { return "No se repite" }
        switch recurrence.frequency {
        case .none:
            return "No se repite"
        case .daily:
            return "Repite diariamente"
        case .weekly:
            let days = formattedRepeatDays
            return days.isEmpty ? "Repite semanalmente" : "Repite semanalmente \(days)"
        case .biweekly:
            let days = formattedRepeatDays
            return days.isEmpty ? "Repite cada 2 semanas" : "Repite cada 2 semanas \(days)"
        case .monthly:
            return "Repite cada mes"
        }
    }

    private var formattedRepeatDays: String {
        let days: [AgendaWeekday]
        if repeatDays.isEmpty {
            days = [AgendaWeekday.from(date: start)]
        } else {
            days = repeatDays.sorted { $0.calendarValue < $1.calendarValue }
        }
        let labels = days.map(\.displayName)
        return labels.isEmpty ? "" : "los \(labels.joined(separator: ", "))"
    }

    var isValid: Bool {
        guard category != nil else { return false }
        guard !sanitizedTitle.isEmpty else { return false }
        guard end > start else { return false }

        if recurrenceEnabled {
            switch recurrenceFrequency {
            case .weekly, .biweekly:
                if repeatDays.isEmpty { return true }
            default:
                break
            }
            if recurrenceHasEndDate, recurrenceEndDate < start {
                return false
            }
        }
        return true
    }

    mutating func toggleRepeatDay(_ day: AgendaWeekday) {
        if repeatDays.contains(day) {
            repeatDays.remove(day)
        } else {
            repeatDays.insert(day)
        }
    }
}

struct AgendaError: Identifiable {
    let id = UUID()
    let message: String
}

@MainActor
final class AgendaViewModel: ObservableObject {
    @Published var mode: AgendaMode = .day
    @Published private(set) var selectedDate: Date
    @Published private(set) var sections: [AgendaDaySection] = []
    @Published private(set) var weekDays: [Date] = []
    @Published private(set) var suggestions: [AgendaSuggestionViewData] = []
    @Published private(set) var isLoading = false
    @Published private(set) var connectCardVisible = true
    @Published private(set) var linkedSources: Set<AgendaScheduleSource> = []
    @Published private(set) var palette: [AgendaCategory: AgendaCategoryColor] = [:]
    @Published private(set) var eventsByDate: [Date: [AgendaEvent]] = [:]
    @Published var presentedError: AgendaError?

    let colorStore: AgendaColorStore

    private let calendarService: CalendarService
    private let database: SupabaseDatabaseService?
    private let aiService: AIServiceProtocol
    private let analytics: AnalyticsServiceProtocol
    private let notificationService: NotificationServiceProtocol
    private let userId: String
    private let isPreview: Bool

    private var cancellables: Set<AnyCancellable> = []
    private var rawEvents: [AgendaEvent] = []
    private var availabilityBlocks: [TimeIntervalBlock] = []
    private var recommendationRows: [RecommendationRow] = []
    private var subscriptionTier: SubscriptionTier = .free
    private var lastSuggestionIds: Set<UUID> = []
    private var currentRange: ClosedRange<Date>?
    private var didLoad = false
    private var lastMultipleEventsTrackedDate: Date?

    private let metadataPrefix = "[MA_META]"
    private let metadataSuffix = "[/MA_META]"
    private let calendar = Calendar.current
    private let recurrenceGenerationHorizonMonths = 3
    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    init(
        userId: String,
        calendarService: CalendarService? = nil,
        database: SupabaseDatabaseService? = nil,
        aiService: AIServiceProtocol? = nil,
        analytics: AnalyticsServiceProtocol? = nil,
        notificationService: NotificationServiceProtocol? = nil,
        colorStore: AgendaColorStore? = nil,
        selectedDate: Date = Date(),
        isPreview: Bool = false
    ) {
        self.userId = userId
        self.calendarService = calendarService ?? SupabaseCalendarService()
        if let database {
            self.database = database
        } else if isPreview {
            self.database = nil
        } else {
            self.database = SupabaseDatabaseService()
        }
        self.aiService = aiService ?? AIService()
        self.analytics = analytics ?? AnalyticsService()
        self.notificationService = notificationService ?? NotificationService()
        self.colorStore = colorStore ?? AgendaColorStore()
        self.selectedDate = selectedDate
        self.isPreview = isPreview

        palette = self.colorStore.colors
        self.colorStore.$colors
            .receive(on: DispatchQueue.main)
            .sink { [weak self] colors in
                self?.palette = colors
            }
            .store(in: &cancellables)

        recalcWeekDays()

        if isPreview {
            applyPreviewData()
        }
    }

    var categories: [AgendaCategory] {
        AgendaCategory.primary + [.recovery, .other]
    }

    func color(for category: AgendaCategory) -> AgendaCategoryColor {
        palette[category] ?? colorStore.color(for: category)
    }

    func loadIfNeeded() async {
        guard !isPreview else { return }
        if didLoad { return }
        await load()
    }

    func load(force: Bool = false) async {
        if force {
            didLoad = false
        }
        await load()
    }

    private func load() async {
        guard !isPreview else { return }
        if isLoading { return }
        if didLoad { return }

        isLoading = true
        defer { isLoading = false }

        let range = range(for: mode, around: selectedDate)
        currentRange = range

        do {
            async let entitlementsTask = database?.listEntitlements()
            async let calendarsTask = database?.listExternalCalendars()
            async let availabilityTask = database?.listAvailabilityBlocks(range: range)
            async let recommendationsTask = database?.listRecommendations()
            async let eventsTask = calendarService.listEvents(from: range.lowerBound, to: range.upperBound)

            if let entitlements = try await entitlementsTask {
                subscriptionTier = determineTier(from: entitlements)
            }

            if let calendars = try await calendarsTask {
                linkedSources = Set(calendars.map { AgendaScheduleSource(provider: $0.provider) })
            }

            let events = try await eventsTask
            rawEvents = events.sorted { $0.start < $1.start }
            rebuildEventsByDate()

            if let availability = try await availabilityTask {
                availabilityBlocks = availability.map { TimeIntervalBlock(start: $0.start_at, end: $0.end_at) }
            } else {
                availabilityBlocks = []
            }

            if let recs = try await recommendationsTask {
                recommendationRows = recs
            } else {
                recommendationRows = []
            }

            didLoad = true
            updateConnectCardVisibility()
            recalcWeekDays()
            computeSections()
            computeSuggestions()
        } catch {
            presentedError = AgendaError(message: error.localizedDescription)
        }
    }

    func setMode(_ newMode: AgendaMode) {
        guard mode != newMode else { return }
        mode = newMode
        recalcWeekDays()
        computeSections()
        computeSuggestions()
        Task { await ensureDataCoversSelectedDate() }
    }

    func setSelectedDate(_ date: Date) {
        guard !calendar.isDate(date, inSameDayAs: selectedDate) else { return }
        selectedDate = date
        recalcWeekDays()
        computeSections()
        computeSuggestions()
        Task { await ensureDataCoversSelectedDate() }
    }

    func makeDraft(for date: Date) -> AgendaEventDraft {
        let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        let end = calendar.date(byAdding: .minute, value: 60, to: start) ?? start.addingTimeInterval(3600)
        let defaultEnd = calendar.date(byAdding: .month, value: 1, to: end) ?? end
        return AgendaEventDraft(category: nil, title: "", start: start, end: end, recurrenceEndDate: defaultEnd)
    }

    func saveManualEvent(_ draft: AgendaEventDraft) async -> Bool {
        guard draft.isValid else {
            presentedError = AgendaError(message: "Completa la categoría, título y horario.")
            return false
        }

        let metadata = metadataDictionary(from: draft)
        let notes = encodeNotes(userNotes: draft.notes, metadata: metadata)
        let recurrence = draft.recurrence
        let event = AgendaEvent(
            id: UUID(),
            title: draft.sanitizedTitle,
            start: draft.start,
            end: draft.end,
            kind: draft.category?.databaseKind,
            notes: notes,
            source: "local",
            recurrence: recurrence,
            overrideParentId: nil,
            isOverride: false
        )

        if isPreview {
            var created = [event]
            if let recurrence, recurrence.isRecurring {
                let generated = generateOccurrences(master: event, recurrence: recurrence, notes: notes)
                created.append(contentsOf: generated)
            }
            rawEvents.append(contentsOf: created)
            rawEvents.sort { $0.start < $1.start }
            rebuildEventsByDate()
            updateConnectCardVisibility()
            computeSections()
            computeSuggestions()
            return true
        }

        do {
            let created = try await calendarService.createLocalEvent(event)
            var createdEvents: [AgendaEvent] = [created]

            if let recurrence, recurrence.isRecurring {
                let generated = generateOccurrences(master: created, recurrence: recurrence, notes: notes)
                if !generated.isEmpty {
                    let stored = try await calendarService.createEventOccurrences(for: created.id, occurrences: generated)
                    createdEvents.append(contentsOf: stored)
                    analytics.track(event: AnalyticsEvent(name: "agenda_recurring_event_created", parameters: [
                        "frequency": recurrence.frequency.rawValue,
                        "occurrences": stored.count + 1
                    ]))
                }
            }

            rawEvents.append(contentsOf: createdEvents)
            rawEvents.sort { $0.start < $1.start }
            rebuildEventsByDate()
            updateConnectCardVisibility()
            computeSections()
            computeSuggestions()
            analytics.track(event: AnalyticsEvent(name: "agenda_event_created", parameters: [
                "category": draft.category?.rawValue ?? "unknown",
                "recurring": recurrence?.isRecurring ?? false
            ]))
            analytics.track(event: AnalyticsEvent(name: "agenda_category_assigned", parameters: [
                "category": draft.category?.rawValue ?? "unknown"
            ]))
            return true
        } catch {
            presentedError = AgendaError(message: error.localizedDescription)
            return false
        }
    }

    func linkCalendar(_ source: AgendaScheduleSource) async {
        guard !isPreview else { return }
        do {
            switch source {
            case .google:
                try await calendarService.linkGoogleAccount()
            case .notion:
                try await calendarService.linkNotionAccount()
            default:
                return
            }
            analytics.track(event: AnalyticsEvent(name: "agenda_link_calendar", parameters: ["provider": source.analyticsValue]))
            linkedSources.insert(source)
            connectCardVisible = false
            await load(force: true)
        } catch {
            presentedError = AgendaError(message: error.localizedDescription)
        }
    }

    func acceptSuggestion(_ suggestion: AgendaSuggestionViewData) {
        analytics.track(event: AnalyticsEvent(name: "agenda_suggestion_accepted", parameters: [
            "slot_start": suggestion.slot.start.timeIntervalSince1970,
            "style": suggestion.style == .primary ? "ai" : "manual",
            "action": suggestion.actionTitle
        ]))
        Task {
            await notificationService.scheduleSuggestionReminder(
                title: suggestion.actionTitle,
                body: suggestion.rationale ?? suggestion.detail,
                at: suggestion.slot.start
            )
        }
    }

    func trackFreeSlotTap(_ slot: AgendaFreeSlotViewData) {
        analytics.track(event: AnalyticsEvent(name: "agenda_free_slot_tapped", parameters: [
            "start": slot.start.timeIntervalSince1970,
            "duration": slot.durationMinutes
        ]))
    }

    private func ensureDataCoversSelectedDate() async {
        guard !isPreview else { return }
        guard let currentRange else {
            await load(force: true)
            return
        }
        if selectedDate < currentRange.lowerBound || selectedDate > currentRange.upperBound {
            await load(force: true)
        }
    }

    private func range(for mode: AgendaMode, around date: Date) -> ClosedRange<Date> {
        let startOfDay = calendar.startOfDay(for: date)
        switch mode {
        case .day:
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)?.addingTimeInterval(-60) ?? startOfDay.addingTimeInterval(86340)
            return startOfDay...endOfDay
        case .week:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? startOfDay
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)?.addingTimeInterval(-60) ?? startOfWeek.addingTimeInterval(7 * 86400 - 60)
            return startOfWeek...endOfWeek
        }
    }

    private func recalcWeekDays() {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? calendar.startOfDay(for: selectedDate)
        weekDays = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    private func computeSections() {
        guard !weekDays.isEmpty else {
            sections = []
            return
        }
        var grouped = eventsByDate
        if grouped.isEmpty {
            var temp: [Date: [AgendaEvent]] = [:]
            for event in rawEvents {
                let key = calendar.startOfDay(for: event.start)
                temp[key, default: []].append(event)
            }
            for key in temp.keys {
                temp[key]?.sort { $0.start < $1.start }
            }
            grouped = temp
            eventsByDate = temp
        }
        var newSections: [AgendaDaySection] = []
        for day in weekDays {
            let key = calendar.startOfDay(for: day)
            let eventsForDay = (grouped[key] ?? []).map { makeViewData(from: $0) }
            newSections.append(AgendaDaySection(date: day, events: eventsForDay))
        }
        sections = newSections

        if let todaySection = newSections.first(where: { calendar.isDate($0.date, inSameDayAs: selectedDate) }),
           todaySection.events.count > 1 {
            let key = calendar.startOfDay(for: selectedDate)
            if lastMultipleEventsTrackedDate != key {
                analytics.track(event: AnalyticsEvent(name: "agenda_multiple_events_shown", parameters: [
                    "count": todaySection.events.count,
                    "mode": mode.rawValue
                ]))
                lastMultipleEventsTrackedDate = key
            }
        }
    }

    private func computeSuggestions() {
        let slots = freeSlots(for: selectedDate)
        guard !slots.isEmpty else {
            suggestions = []
            lastSuggestionIds = []
            return
        }

        let baseContext = recommendationRows
            .filter { ($0.context ?? "").lowercased().contains("agenda") || ($0.context ?? "").lowercased().contains("slot") }
            .sorted { ($0.created_at ?? .distantPast) > ($1.created_at ?? .distantPast) }

        var premiumQueue = baseContext
        var generated: [AgendaSuggestionViewData] = []

        for (index, slot) in slots.enumerated() {
            let detail = "Libre de \(timeRangeText(for: slot)) (\(slot.durationMinutes) min)"
            if subscriptionTier == .premium, !premiumQueue.isEmpty {
                let recommendation = premiumQueue.removeFirst()
                let action = recommendation.message ?? defaultActionTitle(for: slot, position: index)
                let rationale = buildRationale(for: slot, recommendation: recommendation)
                generated.append(
                    AgendaSuggestionViewData(
                        slot: slot,
                        title: action,
                        detail: detail,
                        actionTitle: action,
                        style: .primary,
                        rationale: rationale,
                        recommendationId: recommendation.id
                    )
                )
            } else {
                let action = defaultActionTitle(for: slot, position: index)
                let rationale = fallbackRationale(for: slot, position: index)
                generated.append(
                    AgendaSuggestionViewData(
                        slot: slot,
                        title: action,
                        detail: detail,
                        actionTitle: "Añadir recordatorio",
                        style: .secondary,
                        rationale: rationale
                    )
                )
            }
        }

        suggestions = generated

        let newIds = Set(generated.map(\.id))
        if newIds != lastSuggestionIds {
            analytics.track(event: AnalyticsEvent(name: "agenda_suggestion_shown", parameters: [
                "count": generated.count,
                "tier": subscriptionTier.rawValue
            ]))
            lastSuggestionIds = newIds
        }
    }

    private func rebuildEventsByDate() {
        var grouped: [Date: [AgendaEvent]] = [:]
        for event in rawEvents {
            let key = calendar.startOfDay(for: event.start)
            grouped[key, default: []].append(event)
        }
        for key in grouped.keys {
            grouped[key]?.sort { $0.start < $1.start }
        }
        eventsByDate = grouped
    }

    private func generateOccurrences(master: AgendaEvent, recurrence: AgendaRecurrence, notes: String) -> [AgendaEvent] {
        AgendaRecurrenceEngine.generateOccurrences(
            master: master,
            recurrence: recurrence,
            calendar: calendar,
            horizonMonths: recurrenceGenerationHorizonMonths,
            notes: notes
        )
    }

    private func freeSlots(for date: Date) -> [AgendaFreeSlotViewData] {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)?.addingTimeInterval(-60) ?? startOfDay.addingTimeInterval(86340)

        let matchingAvailability = availabilityBlocks.filter { block in
            (block.start >= startOfDay && block.start <= endOfDay) ||
            (block.end >= startOfDay && block.end <= endOfDay)
        }

        let blocks: [TimeIntervalBlock]
        if !matchingAvailability.isEmpty {
            blocks = matchingAvailability
        } else {
            let dayEvents = eventsByDate[startOfDay] ?? []

            var computed: [TimeIntervalBlock] = []
            var cursor = startOfDay

            for event in dayEvents {
                if event.start > cursor {
                    let block = TimeIntervalBlock(start: cursor, end: event.start)
                    if block.duration >= 15 * 60 {
                        computed.append(block)
                    }
                }
                if event.end > cursor {
                    cursor = event.end
                }
            }

            if cursor < endOfDay {
                let block = TimeIntervalBlock(start: cursor, end: endOfDay)
                if block.duration >= 15 * 60 {
                    computed.append(block)
                }
            }
            blocks = computed
        }

        return blocks
            .sorted { $0.start < $1.start }
            .map { AgendaFreeSlotViewData(id: UUID(), start: $0.start, end: $0.end) }
    }

    private func timeRangeText(for slot: AgendaFreeSlotViewData) -> String {
        "\(timeFormatter.string(from: slot.start)) a \(timeFormatter.string(from: slot.end))"
    }

    private func defaultActionTitle(for slot: AgendaFreeSlotViewData, position: Int) -> String {
        if slot.durationMinutes >= 60 {
            return position.isMultiple(of: 2) ? "Diario 10 min" : "Mindfulness 5 min"
        } else if slot.durationMinutes >= 30 {
            return "Respiración consciente"
        } else {
            return "Micro pausa activa"
        }
    }

    private func fallbackRationale(for slot: AgendaFreeSlotViewData, position: Int) -> String {
        let hour = calendar.component(.hour, from: slot.start)
        if hour < 10 {
            return "Empieza la mañana con claridad escribiendo tus prioridades."
        } else if hour < 16 {
            return "Un respiro guiado ahora ayuda a sostener tu energía para el resto del día."
        } else {
            return "Una visualización breve te permite cerrar la jornada con calma."
        }
    }

    private func buildRationale(for slot: AgendaFreeSlotViewData, recommendation: RecommendationRow) -> String {
        if let reason = recommendation.reason, let summary = extractSummary(from: reason) {
            return summary
        }
        let base = "Libre \(timeRangeText(for: slot))."
        if let message = recommendation.message {
            return "\(base) \(message)"
        }
        return "\(base) Usa unos minutos para respirar y visualizar tu objetivo."
    }

    private func extractSummary(from reason: [String: AnyCodable]) -> String? {
        guard let data = try? JSONEncoder().encode(reason),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return nil
        }
        if let summary = json["summary"] as? String {
            return summary
        }
        if let rationale = json["rationale"] as? String {
            return rationale
        }
        if let text = json["text"] as? String {
            return text
        }
        return nil
    }

    private func metadataDictionary(from draft: AgendaEventDraft) -> [String: String] {
        var metadata: [String: String] = [:]
        if let category = draft.category {
            metadata["category"] = category.rawValue
        }
        let training = draft.trainingType.trimmingCharacters(in: .whitespacesAndNewlines)
        if !training.isEmpty {
            metadata["training_type"] = training
        }
        let study = draft.studyFocus.trimmingCharacters(in: .whitespacesAndNewlines)
        if !study.isEmpty {
            metadata["study_focus"] = study
        }
        return metadata
    }

    private func decodeNotes(_ notes: String?) -> (metadata: [String: String], body: String) {
        guard var content = notes, !content.isEmpty else { return ([:], "") }
        guard content.hasPrefix(metadataPrefix),
              let prefixRange = content.range(of: metadataPrefix),
              let suffixRange = content.range(of: metadataSuffix) else {
            return ([:], content)
        }
        let jsonRange = prefixRange.upperBound..<suffixRange.lowerBound
        let jsonString = String(content[jsonRange])
        let remainder = content[suffixRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        let metadata: [String: String]
        if let data = jsonString.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
            metadata = dict
        } else {
            metadata = [:]
        }
        return (metadata, remainder)
    }

    private func encodeNotes(userNotes: String, metadata: [String: String]) -> String {
        guard !metadata.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: metadata, options: []),
              let json = String(data: data, encoding: .utf8) else {
            return userNotes
        }
        if userNotes.isEmpty {
            return "\(metadataPrefix)\(json)\(metadataSuffix)"
        } else {
            return "\(metadataPrefix)\(json)\(metadataSuffix)\n\(userNotes)"
        }
    }

    private func resolveCategory(from event: AgendaEvent, metadata: [String: String]) -> AgendaCategory {
        if let stored = metadata["category"], let category = AgendaCategory(rawValue: stored) {
            return category
        }
        if let kind = event.kind?.lowercased() {
            switch kind {
            case "entreno": return .training
            case "clase": return .study
            case "competencia": return .client
            case "examen": return .study
            default: break
            }
        }
        let title = event.title.lowercased()
        if title.contains("entren") || title.contains("gym") {
            return .training
        }
        if title.contains("clase") || title.contains("estudio") || title.contains("universidad") {
            return .study
        }
        if title.contains("cliente") || title.contains("reunión") || title.contains("meeting") {
            return .client
        }
        if title.contains("trabajo") || title.contains("project") {
            return .work
        }
        return .personal
    }

    private func makeViewData(from event: AgendaEvent) -> AgendaEventViewData {
        let decoded = decodeNotes(event.notes)
        let metadata = decoded.metadata
        let category = resolveCategory(from: event, metadata: metadata)
        let source = AgendaScheduleSource(provider: event.source)
        let summary = recurrenceDescription(for: event)
        return AgendaEventViewData(
            id: event.id,
            title: event.title,
            start: event.start,
            end: event.end,
            notes: decoded.body.isEmpty ? nil : decoded.body,
            category: category,
            source: source,
            trainingType: metadata["training_type"],
            studyFocus: metadata["study_focus"],
            recurrence: event.recurrence,
            isOverride: event.isOverride,
            recurrenceSummary: summary
        )
    }

    private func recurrenceDescription(for event: AgendaEvent) -> String? {
        guard let recurrence = event.recurrence, recurrence.isRecurring else { return nil }
        let suffix: String
        if let end = recurrence.endDate {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "es_ES")
            formatter.dateStyle = .medium
            suffix = " hasta \(formatter.string(from: end))"
        } else {
            suffix = ""
        }
        switch recurrence.frequency {
        case .daily:
            return "Repite diariamente\(suffix)"
        case .weekly:
            return "Repite semanalmente \(formatRepeatDays(recurrence.repeatDays, fallback: event.start))\(suffix)"
        case .biweekly:
            return "Repite cada 2 semanas \(formatRepeatDays(recurrence.repeatDays, fallback: event.start))\(suffix)"
        case .monthly:
            return "Repite cada mes\(suffix)"
        case .none:
            return nil
        }
    }

    private func formatRepeatDays(_ raw: [String], fallback: Date) -> String {
        let weekdays = raw.compactMap { AgendaWeekday(rawValue: $0) }
        let ordered = weekdays.isEmpty ? [AgendaWeekday.from(date: fallback)] : weekdays.sorted { $0.calendarValue < $1.calendarValue }
        let labels = ordered.map(\.displayName)
        guard !labels.isEmpty else { return "" }
        return "los \(labels.joined(separator: ", "))"
    }

    private func updateConnectCardVisibility() {
        let hasExternal = linkedSources.contains(.google) || linkedSources.contains(.notion)
        let hasManual = rawEvents.contains { AgendaScheduleSource(provider: $0.source) == .manual }
        connectCardVisible = !(hasExternal || hasManual)
    }

    private func determineTier(from entitlements: [EntitlementRow]) -> SubscriptionTier {
        entitlements.contains(where: { $0.active && $0.product.lowercased().contains("premium") }) ? .premium : .free
    }

    private func applyPreviewData() {
        let base = calendar.startOfDay(for: selectedDate)
        let event1 = AgendaEvent(
            id: UUID(),
            title: "Clase de biomecánica",
            start: calendar.date(byAdding: .hour, value: 9, to: base)!,
            end: calendar.date(byAdding: .hour, value: 10, to: base)!,
            kind: "clase",
            notes: encodeNotes(userNotes: "Repasar apuntes clave.", metadata: ["category": AgendaCategory.study.rawValue, "study_focus": "Biomecánica"]),
            source: "local"
        )
        let event2 = AgendaEvent(
            id: UUID(),
            title: "Entrenamiento fuerza",
            start: calendar.date(byAdding: .hour, value: 12, to: base)!,
            end: calendar.date(byAdding: .hour, value: 13, to: base)!,
            kind: "entreno",
            notes: encodeNotes(userNotes: "Serie principal 5x5.", metadata: ["category": AgendaCategory.training.rawValue, "training_type": "Fuerza"]),
            source: "local",
            recurrence: AgendaRecurrence(
                frequency: .weekly,
                repeatDays: [AgendaWeekday.tuesday.rawValue, AgendaWeekday.thursday.rawValue],
                endDate: calendar.date(byAdding: .weekOfYear, value: 6, to: base)
            )
        )
        let event3 = AgendaEvent(
            id: UUID(),
            title: "Revisión con cliente",
            start: calendar.date(byAdding: .hour, value: 16, to: base)!,
            end: calendar.date(byAdding: .hour, value: 17, to: base)!,
            kind: "otro",
            notes: encodeNotes(userNotes: "Preparar feedback.", metadata: ["category": AgendaCategory.client.rawValue]),
            source: "local"
        )
        var previewEvents = [event1, event2, event3]
        if let recurrence = event2.recurrence {
            let generated = generateOccurrences(master: event2, recurrence: recurrence, notes: event2.notes ?? "")
            previewEvents.append(contentsOf: generated)
        }
        rawEvents = previewEvents.sorted { $0.start < $1.start }
        rebuildEventsByDate()
        availabilityBlocks = [
            TimeIntervalBlock(start: calendar.date(byAdding: .hour, value: 7, to: base)!, end: calendar.date(byAdding: .hour, value: 8, to: base)!),
            TimeIntervalBlock(start: calendar.date(byAdding: .hour, value: 18, to: base)!, end: calendar.date(byAdding: .hour, value: 19, to: base)!)
        ]
        subscriptionTier = .premium
        updateConnectCardVisibility()
        computeSections()
        computeSuggestions()
    }
}

struct ScheduleTabView: View {
    @StateObject private var viewModel: AgendaViewModel
    @State private var builderDraft = AgendaEventDraft()
    @State private var showingBuilder = false
    @State private var expandedEvents: Set<UUID> = []
    @State private var showingColorSettings = false

    private let calendar = Calendar.current

    init(viewModel: AgendaViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: MASpacing.xl, pinnedViews: []) {
                    headerSection

                    if viewModel.connectCardVisible {
                        AgendaConnectCard(
                            onGoogle: {
                                Task { await viewModel.linkCalendar(.google) }
                            },
                            onNotion: {
                                Task { await viewModel.linkCalendar(.notion) }
                            },
                            onCreate: {
                                builderDraft = viewModel.makeDraft(for: viewModel.selectedDate)
                                showingBuilder = true
                            }
                        )
                    }

                    if viewModel.mode == .day {
                        dayView
                    } else {
                        weekView
                    }

                    if !viewModel.suggestions.isEmpty {
                        suggestionsSection
                    }
                }
                .padding(.horizontal, MASpacing.lg)
                .padding(.top, MASpacing.sm)
                .padding(.bottom, MASpacing.xl)
            }
            .background(Color.maBackground.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingColorSettings = true
                    } label: {
                        Image(systemName: "paintpalette.fill")
                            .foregroundColor(MAColorPalette.primary)
                    }
                    .accessibilityLabel("Colores de categorías")
                }
            }
            .sheet(isPresented: $showingBuilder) {
                NavigationStack {
                    AgendaEventBuilderView(
                        draft: $builderDraft,
                        categories: viewModel.categories,
                        colorProvider: viewModel.color(for:),
                        onSave: { draft in
                            await viewModel.saveManualEvent(draft)
                        }
                    )
                }
            }
            .sheet(isPresented: $showingColorSettings) {
                NavigationStack {
                    AgendaColorSettingsView(store: viewModel.colorStore)
                }
            }
            .alert(item: $viewModel.presentedError) { error in
                Alert(
                    title: Text("No pudimos actualizar la agenda"),
                    message: Text(error.message),
                    dismissButton: .default(Text("Entendido"))
                )
            }
            .task {
                await viewModel.loadIfNeeded()
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: MASpacing.lg) {
            Text("Agenda")
                .font(.system(.largeTitle, design: .rounded).bold())
                .foregroundColor(MAColorPalette.textPrimary)

            Picker("Modo", selection: Binding(
                get: { viewModel.mode },
                set: { viewModel.setMode($0) }
            )) {
                ForEach(AgendaMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: MASpacing.xs) {
                Text(viewModel.selectedDate, format: .dateTime.weekday(.wide))
                    .font(.system(.title2, design: .rounded).bold())
                    .foregroundColor(MAColorPalette.textPrimary)
                Text(viewModel.selectedDate, format: .dateTime.day().month(.wide).year())
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(MAColorPalette.textSecondary)
            }

            AgendaDateStrip(
                dates: viewModel.weekDays,
                selectedDate: viewModel.selectedDate
            ) { date in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    viewModel.setSelectedDate(date)
                }
            }

            if viewModel.mode == .day {
                MAButton("Añadir evento") {
                    builderDraft = viewModel.makeDraft(for: viewModel.selectedDate)
                    showingBuilder = true
                }
            }
        }
    }

    private var dayView: some View {
        let section = viewModel.sections.first { calendar.isDate($0.date, inSameDayAs: viewModel.selectedDate) }
        return VStack(alignment: .leading, spacing: MASpacing.md) {
            if let section, !section.events.isEmpty {
                ForEach(section.events) { event in
                    AgendaEventCard(
                        event: event,
                        color: viewModel.color(for: event.category),
                        isExpanded: expandedEvents.contains(event.id),
                        onToggleNotes: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expandedEvents.contains(event.id) {
                                    expandedEvents.remove(event.id)
                                } else {
                                    expandedEvents.insert(event.id)
                                }
                            }
                        }
                    )
                }
            } else {
                MACard {
                    VStack(alignment: .leading, spacing: MASpacing.sm) {
                        Text("Sin eventos para este día")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(MAColorPalette.textPrimary)
                        Text("Añade una clase, práctica o compromiso para mantenerte enfocado.")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(MAColorPalette.textSecondary)
                    }
                }
            }
        }
    }

    private var weekView: some View {
        VStack(spacing: MASpacing.md) {
            ForEach(viewModel.sections) { section in
                MACard(title: section.date.formatted(.dateTime.weekday(.wide).day())) {
                    if section.events.isEmpty {
                        Text("Sin eventos")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(MAColorPalette.textSecondary)
                    } else {
                        VStack(spacing: MASpacing.sm) {
                            ForEach(section.events) { event in
                                AgendaWeekEventRow(event: event, color: viewModel.color(for: event.category))
                            }
                        }
                    }
                    Button {
                        builderDraft = viewModel.makeDraft(for: section.date)
                        showingBuilder = true
                    } label: {
                        HStack(spacing: MASpacing.xs) {
                            Image(systemName: "plus.circle.fill")
                            Text("Añadir evento")
                                .font(.system(.footnote, design: .rounded).bold())
                        }
                        .foregroundColor(MAColorPalette.accent)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, MASpacing.sm)
                }
            }
        }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: MASpacing.md) {
            Text("Sugerencias")
                .font(.system(.title3, design: .rounded).bold())
                .foregroundColor(MAColorPalette.textPrimary)

            VStack(spacing: MASpacing.md) {
                ForEach(viewModel.suggestions) { suggestion in
                    AgendaSuggestionCard(
                        suggestion: suggestion,
                        onAction: {
                            viewModel.trackFreeSlotTap(suggestion.slot)
                            viewModel.acceptSuggestion(suggestion)
                        }
                    )
                }
            }
        }
    }
}

private struct AgendaDateStrip: View {
    let dates: [Date]
    let selectedDate: Date
    let onSelect: (Date) -> Void
    private let calendar = Calendar.current

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MASpacing.sm) {
                ForEach(dates, id: \.self) { date in
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    Button {
                        onSelect(date)
                    } label: {
                        VStack(spacing: MASpacing.xs) {
                            Text(date, format: .dateTime.weekday(.narrow))
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(isSelected ? .white : MAColorPalette.textSecondary)
                            Text(date, format: .dateTime.day())
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(isSelected ? .white : MAColorPalette.textPrimary)
                        }
                        .frame(width: 52, height: 72)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(isSelected ? MAColorPalette.primary : MAColorPalette.surfaceAlt)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(date.formatted(date: .abbreviated, time: .omitted))
                }
            }
            .padding(.vertical, MASpacing.xs)
        }
    }
}

private struct AgendaConnectCard: View {
    let onGoogle: () -> Void
    let onNotion: () -> Void
    let onCreate: () -> Void

    var body: some View {
        MACard(title: "Conecta o crea tu horario") {
            Text("Sincroniza Google, Notion o arma tu agenda manual para obtener recomendaciones personalizadas.")
                .font(.system(.body, design: .rounded))
                .foregroundColor(MAColorPalette.textSecondary)

            HStack(spacing: MASpacing.md) {
                AgendaSourceButton(title: "Google", systemImage: "globe", action: onGoogle)
                AgendaSourceButton(title: "Notion", systemImage: "square.stack.3d.up", action: onNotion)
                AgendaSourceButton(title: "Crear horario", systemImage: "plus.circle.fill", action: onCreate)
            }
        }
    }
}

private struct AgendaSourceButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MASpacing.sm) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.system(.subheadline, design: .rounded).bold())
            }
            .padding(.vertical, MASpacing.sm)
            .padding(.horizontal, MASpacing.md)
            .frame(maxWidth: .infinity)
            .background(MAColorPalette.primary.opacity(0.12))
            .foregroundColor(MAColorPalette.primary)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct AgendaEventCard: View {
    let event: AgendaEventViewData
    let color: AgendaCategoryColor
    let isExpanded: Bool
    let onToggleNotes: () -> Void

    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        MACard {
            VStack(alignment: .leading, spacing: MASpacing.sm) {
                HStack(alignment: .center, spacing: MASpacing.sm) {
                    VStack(alignment: .leading, spacing: MASpacing.xs) {
                        HStack(spacing: MASpacing.xs) {
                            Text(event.title)
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(MAColorPalette.textPrimary)
                            if let recurrence = event.recurrence, recurrence.isRecurring {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(.caption, design: .rounded).bold())
                                    .foregroundColor(MAColorPalette.accent)
                                    .accessibilityLabel("Evento recurrente")
                            }
                        }
                        Text("\(formatter.string(from: event.start)) – \(formatter.string(from: event.end))")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(MAColorPalette.textSecondary)
                    }
                    Spacer()
                    Text(event.category.title.uppercased())
                        .font(.system(.caption, design: .rounded).bold())
                        .padding(.vertical, MASpacing.xs)
                        .padding(.horizontal, MASpacing.sm)
                        .background(color.backgroundColor)
                        .foregroundColor(color.textColor)
                        .clipShape(Capsule())
                        .accessibilityLabel("Categoría \(event.category.title)")
                }

                if let summary = event.recurrenceSummary {
                    Label(summary, systemImage: "repeat")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(MAColorPalette.accent)
                }
                if event.isOverride {
                    Text("Instancia personalizada")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(MAColorPalette.textSecondary)
                }
                if let training = event.trainingType, !training.isEmpty {
                    Label("Tipo de entreno: \(training)", systemImage: "figure.run")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundColor(MAColorPalette.textSecondary)
                }
                if let study = event.studyFocus, !study.isEmpty {
                    Label("Enfoque de estudio: \(study)", systemImage: "book")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundColor(MAColorPalette.textSecondary)
                }
                Label(sourceLabel, systemImage: "link")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(MAColorPalette.textSecondary)

                if let notes = event.notes, !notes.isEmpty {
                    Button(action: onToggleNotes) {
                        HStack(spacing: MASpacing.xs) {
                            Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            Text(isExpanded ? "Ocultar notas" : "Mostrar notas")
                        }
                        .font(.system(.footnote, design: .rounded).bold())
                        .foregroundColor(MAColorPalette.accent)
                    }
                    .buttonStyle(.plain)

                    if isExpanded {
                        Text(notes)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundColor(MAColorPalette.textSecondary)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var sourceLabel: String {
        switch event.source {
        case .google: return "Evento de Google"
        case .notion: return "Evento de Notion"
        case .manual: return "Creado en MindAthlete"
        case .external: return "Calendario externo"
        case .unknown: return "Origen desconocido"
        }
    }
}

private struct AgendaWeekEventRow: View {
    let event: AgendaEventViewData
    let color: AgendaCategoryColor

    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        HStack(spacing: MASpacing.sm) {
            Circle()
                .fill(color.backgroundColor.opacity(0.9))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: MASpacing.xs) {
                    Text(event.title)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(MAColorPalette.textPrimary)
                        .lineLimit(1)
                    if let recurrence = event.recurrence, recurrence.isRecurring {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(MAColorPalette.accent)
                    }
                }
                Text("\(formatter.string(from: event.start)) – \(formatter.string(from: event.end))")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(MAColorPalette.textSecondary)
            }
            Spacer()
            Text(event.category.title)
                .font(.system(.caption2, design: .rounded).bold())
                .foregroundColor(color.textColor)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(color.backgroundColor.opacity(0.85))
                .clipShape(Capsule())
        }
    }
}

private struct AgendaSuggestionCard: View {
    let suggestion: AgendaSuggestionViewData
    let onAction: () -> Void

    var body: some View {
        MACard {
            VStack(alignment: .leading, spacing: MASpacing.sm) {
                Text(suggestion.title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(MAColorPalette.textPrimary)
                Text(suggestion.detail)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(MAColorPalette.textSecondary)
                if let rationale = suggestion.rationale {
                    Text(rationale)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundColor(MAColorPalette.textSecondary)
                    Text("¿Por qué esta sugerencia?")
                        .font(.system(.caption, design: .rounded).bold())
                        .foregroundColor(MAColorPalette.accent)
                        .padding(.top, MASpacing.xs)
                }
                if suggestion.style == .primary {
                    MAButton(suggestion.actionTitle, style: .primary, action: onAction)
                        .accessibilityLabel("\(suggestion.actionTitle) para \(suggestion.detail)")
                } else {
                    Button(action: onAction) {
                        Text(suggestion.actionTitle)
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(MAColorPalette.accent.opacity(0.12))
                            .foregroundColor(MAColorPalette.accent)
                            .cornerRadius(24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(MAColorPalette.accent, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(suggestion.actionTitle) para \(suggestion.detail)")
                }
            }
        }
    }
}

private struct AgendaEventBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var draft: AgendaEventDraft
    let categories: [AgendaCategory]
    let colorProvider: (AgendaCategory) -> AgendaCategoryColor
    let onSave: (AgendaEventDraft) async -> Bool

    @State private var isSaving = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case title, notes, training, study
    }

    private var quickActions: [AgendaQuickAction] {
        [
            AgendaQuickAction(title: "Añadir clase", category: .study, defaultTitle: "Clase", trainingType: nil, studyFocus: "Estudio guiado"),
            AgendaQuickAction(title: "Añadir práctica", category: .training, defaultTitle: "Práctica", trainingType: "Cardio ligero", studyFocus: nil)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: MASpacing.lg) {
                quickActionsSection
                categorySection
                scheduleSection
                recurrenceSection
                metadataSection
                notesSection
            }
            .padding(.horizontal, MASpacing.lg)
            .padding(.vertical, MASpacing.lg)
        }
        .navigationTitle("Nuevo evento")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Guardar")
                    }
                }
                .disabled(!draft.isValid || isSaving)
            }
        }
        .onChange(of: draft.recurrenceEnabled) { enabled in
            if enabled && draft.recurrenceFrequency == .none {
                draft.recurrenceFrequency = .weekly
            }
        }
        .onChange(of: draft.recurrenceFrequency) { newValue in
            if newValue != .weekly && newValue != .biweekly {
                draft.repeatDays.removeAll()
            }
        }
        .onChange(of: draft.start) { newValue in
            if draft.recurrenceEndDate < newValue {
                draft.recurrenceEndDate = newValue
            }
        }
        .onChange(of: draft.recurrenceHasEndDate) { hasEnd in
            if !hasEnd {
                draft.recurrenceEndDate = draft.end
            }
        }
    }

    private var quickActionsSection: some View {
        MACard(title: "Accesos rápidos") {
            VStack(spacing: MASpacing.sm) {
                ForEach(quickActions) { action in
                    Button {
                        draft.category = action.category
                        draft.title = action.defaultTitle
                        if let training = action.trainingType {
                            draft.trainingType = training
                        }
                        if let study = action.studyFocus {
                            draft.studyFocus = study
                        }
                    } label: {
                        HStack {
                            Text(action.title)
                                .font(.system(.subheadline, design: .rounded).bold())
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(.footnote, design: .rounded))
                        }
                        .padding(.vertical, MASpacing.sm)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(action.title)
                    if action.id != quickActions.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var categorySection: some View {
        MACard(title: "Categoría") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: MASpacing.sm) {
                ForEach(categories, id: \.self) { category in
                    let color = colorProvider(category)
                    Button {
                        draft.category = category
                    } label: {
                        HStack {
                            Image(systemName: category.iconName)
                            Text(category.title)
                                .font(.system(.callout, design: .rounded).bold())
                        }
                        .padding(.vertical, MASpacing.sm)
                        .padding(.horizontal, MASpacing.md)
                        .frame(maxWidth: .infinity)
                        .background(draft.category == category ? color.backgroundColor : MAColorPalette.surfaceAlt)
                        .foregroundColor(draft.category == category ? color.textColor : MAColorPalette.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Categoría \(category.title)")
                }
            }
        }
    }

    private var scheduleSection: some View {
        MACard(title: "Horario") {
            VStack(alignment: .leading, spacing: MASpacing.md) {
                TextField("Título (ej. Clase de cálculo)", text: $draft.title)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .rounded))
                    .focused($focusedField, equals: .title)

                DatePicker("Inicio", selection: $draft.start, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .font(.system(.subheadline, design: .rounded))
                DatePicker("Fin", selection: $draft.end, in: draft.start..., displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .font(.system(.subheadline, design: .rounded))
            }
        }
    }

    private var recurrenceSection: some View {
        MACard(title: "Repetición") {
            Toggle("Repetir evento", isOn: $draft.recurrenceEnabled.animation())
                .tint(MAColorPalette.accent)

            if draft.recurrenceEnabled {
                Picker("Frecuencia", selection: $draft.recurrenceFrequency) {
                    Text("Sin repetición").tag(AgendaRecurrenceFrequency.none)
                    Text("Diaria").tag(AgendaRecurrenceFrequency.daily)
                    Text("Semanal").tag(AgendaRecurrenceFrequency.weekly)
                    Text("Bi-semanal").tag(AgendaRecurrenceFrequency.biweekly)
                    Text("Mensual").tag(AgendaRecurrenceFrequency.monthly)
                }
                .pickerStyle(.segmented)
                .tint(MAColorPalette.primary)
                .padding(.top, MASpacing.xs)

                if draft.recurrenceFrequency == .weekly || draft.recurrenceFrequency == .biweekly {
                    VStack(alignment: .leading, spacing: MASpacing.xs) {
                        Text("Días de repetición")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(MAColorPalette.textSecondary)
                        let columns = Array(repeating: GridItem(.flexible(), spacing: MASpacing.sm), count: 4)
                        LazyVGrid(columns: columns, spacing: MASpacing.sm) {
                            ForEach(AgendaWeekday.allCases) { day in
                                repeatDayChip(for: day)
                            }
                        }
                    }
                    .padding(.top, MASpacing.sm)
                }

                Toggle("Definir fecha de finalización", isOn: $draft.recurrenceHasEndDate.animation())
                    .tint(MAColorPalette.accent)
                    .padding(.top, MASpacing.sm)

                if draft.recurrenceHasEndDate {
                    DatePicker("Termina", selection: $draft.recurrenceEndDate, in: draft.start..., displayedComponents: .date)
                        .datePickerStyle(.compact)
                } else {
                    Text("Sin fecha de término")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(MAColorPalette.textSecondary)
                }

                Text(draft.recurrenceSummary)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(MAColorPalette.textSecondary)
                    .padding(.top, MASpacing.sm)
            }
        }
    }

    private var metadataSection: some View {
        MACard(title: "Detalles adicionales") {
            VStack(alignment: .leading, spacing: MASpacing.md) {
                if draft.category == .study {
                    TextField("Materia o foco de estudio", text: $draft.studyFocus)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .study)
                }
                if draft.category == .training || draft.category == .recovery {
                    TextField("Tipo de entreno (ej. Fuerza, Cardio)", text: $draft.trainingType)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .training)
                }
            }
        }
    }

    private func repeatDayChip(for day: AgendaWeekday) -> some View {
        let isSelected = draft.repeatDays.contains(day)
        return Button {
            draft.toggleRepeatDay(day)
        } label: {
            Text(day.displayName)
                .font(.system(.footnote, design: .rounded).bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, MASpacing.xs)
                .background(isSelected ? MAColorPalette.accent : MAColorPalette.surfaceAlt)
                .foregroundColor(isSelected ? .white : MAColorPalette.textSecondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(MAColorPalette.accent.opacity(isSelected ? 0 : 0.5), lineWidth: isSelected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Repetir el \(day.displayName)")
    }

    private var notesSection: some View {
        MACard(title: "Notas") {
            TextEditor(text: $draft.notes)
                .frame(minHeight: 120)
                .font(.system(.body, design: .rounded))
                .focused($focusedField, equals: .notes)
        }
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        let success = await onSave(draft)
        isSaving = false
        if success {
            dismiss()
        }
    }
}

private struct AgendaQuickAction: Identifiable {
    let id = UUID()
    let title: String
    let category: AgendaCategory
    let defaultTitle: String
    let trainingType: String?
    let studyFocus: String?
}

struct AgendaColorSettingsView: View {
    @ObservedObject var store: AgendaColorStore

    var body: some View {
        List {
            Section("Colores de etiquetas") {
                ForEach(AgendaCategory.primary + [.recovery, .other], id: \.self) { category in
                    HStack {
                        VStack(alignment: .leading, spacing: MASpacing.xs) {
                            Text(category.title)
                                .font(.system(.body, design: .rounded))
                            Text(store.color(for: category).hex)
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(MAColorPalette.textSecondary)
                        }
                        Spacer()
                        ColorPicker(
                            "",
                            selection: Binding(
                                get: { Color(hex: store.color(for: category).hex) },
                                set: { store.update(color: $0, for: category) }
                            ),
                            supportsOpacity: false
                        )
                        .labelsHidden()
                    }
                }
            }

            Section {
                Button("Restablecer colores") {
                    AgendaCategory.allCases.forEach(store.reset)
                }
                .foregroundColor(MAColorPalette.primary)
            }
        }
        .navigationTitle("Colores de agenda")
    }
}

#if DEBUG
extension AgendaViewModel {
    static func preview() -> AgendaViewModel {
        AgendaViewModel(
            userId: "preview",
            calendarService: PreviewCalendarService(),
            database: nil,
            aiService: PreviewAIService(),
            analytics: AnalyticsService(),
            notificationService: PreviewNotificationService(),
            colorStore: AgendaColorStore(),
            isPreview: true
        )
    }
}

private struct PreviewCalendarService: CalendarService {
    func linkGoogleAccount() async throws {}
    func linkNotionAccount() async throws {}
    func syncExternalCalendars() async throws {}
    func createLocalEvent(_ event: AgendaEvent) async throws -> AgendaEvent { event }
    func createEventOccurrences(for masterId: UUID, occurrences: [AgendaEvent]) async throws -> [AgendaEvent] { occurrences }
    func listEvents(from: Date, to: Date) async throws -> [AgendaEvent] { [] }
    func computeAvailability(from: Date, to: Date, minBlock: TimeInterval) async throws -> [TimeIntervalBlock] { [] }
}

private struct PreviewAIService: AIServiceProtocol {
    func recommendations(for userId: String, period: String) async throws -> RecommendationResponse {
        RecommendationResponse(
            recommendations: ["Respira profundo 4-7-8", "Visualiza tu próximo entrenamiento"],
            preCompetition: nil,
            rationale: "Mock",
            modelVersion: "preview"
        )
    }

    func dailyRecommendation(for userId: String, date: Date) async throws -> DailyRecommendationResponseDTO {
        DailyRecommendationResponseDTO(
            recommendations: ["Reserva 5 minutos para respirar antes de tu bloque libre de la tarde."],
            rationale: "Mock preview",
            eventContext: [],
            escalate: false,
            modelVersion: "preview"
        )
    }

    func chatStream(userId: String, chatId: UUID?, messages: [ChatMessagePayload], tone: String?, targetGoal: String?) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let id = chatId ?? UUID()
            continuation.yield(ChatStreamEvent(chatId: id, delta: "Hola desde el preview 👋", finished: false, escalate: false, habitHint: nil, bookingURL: nil, model: "preview"))
            continuation.yield(ChatStreamEvent(chatId: id, delta: nil, finished: true, escalate: false, habitHint: nil, bookingURL: nil, model: "preview"))
            continuation.finish()
        }
    }

    func generateHabitPlan(for userId: String, timeframe: String?, context: [String: String]?) async throws -> HabitPlanResponseDTO {
        HabitPlanResponseDTO(
            habits: [
                HabitPlanItemDTO(title: "Respiración matutina", recommendedStartDate: Date(), frequency: "daily", rationale: "Comienza el día centrado.")
            ],
            summary: "Mock preview plan"
        )
    }

    func escalate(for userId: String, context: [String: String]?, reason: String?) async throws -> EscalationResponseDTO {
        EscalationResponseDTO(escalate: false, bookingURL: nil, message: "Preview no escala.")
    }
}

private struct PreviewNotificationService: NotificationServiceProtocol {
    func requestAuthorization() async -> Bool { true }
    func scheduleDailyCheckIn(at hour: Int, minute: Int) async {}
    func schedulePreCompetitionReminder(for event: Event) async {}
    func scheduleSuggestionReminder(title: String, body: String, at date: Date) async {}
}

@MainActor
struct ScheduleTabView_Previews: PreviewProvider {
    static var previews: some View {
        ScheduleTabView(viewModel: AgendaViewModel.preview())
            .previewDisplayName("Agenda – Día")
    }
}
#endif
