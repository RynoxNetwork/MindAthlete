
import Combine
import Foundation
import SwiftUI

@MainActor
final class HabitsViewModel: ObservableObject {
    struct Habit: Identifiable, Sendable, Hashable {
        let id: UUID
        var name: String
        var description: String
        var goalPerWeek: Int
        var isActive: Bool
    }

    struct HabitLog: Identifiable, Sendable, Hashable {
        let id: UUID
        let habitId: UUID
        let performedAt: Date
        var adherence: Double
        var notes: String?
    }

    // MARK: - Published state
    @Published private(set) var habits: [Habit]
    @Published private(set) var logs: [HabitLog]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let database: DatabaseServiceProtocol
    private let analytics: AnalyticsServiceProtocol
    private let userId: String

    // MARK: - Configuration
    let freeTierActiveHabitLimit = 3

    // MARK: - Init
    init(
        userId: String,
        database: DatabaseServiceProtocol,
        analytics: AnalyticsServiceProtocol,
        habits: [Habit] = [],
        logs: [HabitLog] = []
    ) {
        self.userId = userId
        self.database = database
        self.analytics = analytics
        self.habits = habits
        self.logs = logs
    }

    // MARK: - Loading
    func load() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let fetched = try await database.fetchHabits(for: userId)
            habits = fetched.map { model in
                Habit(
                    id: UUID(uuidString: model.id) ?? UUID(),
                    name: model.name,
                    description: "Tu hábito personalizado",
                    goalPerWeek: model.targetPerWeek,
                    isActive: model.active
                )
            }
            analytics.track(event: AnalyticsEvent(name: "habits_loaded", parameters: [:]))
        } catch {
            errorMessage = "No pudimos cargar tus hábitos."
            analytics.track(event: AnalyticsEvent(name: "habits_load_failed", parameters: ["error": error.localizedDescription]))
        }
    }

    // MARK: - Derived data
    var activeHabits: [Habit] {
        habits.filter { $0.isActive }
    }

    var shouldShowFreeTierBanner: Bool {
        activeHabits.count >= freeTierActiveHabitLimit
    }

    var combinedWeekProgress: (done: Double, goal: Int) {
        let interval = currentWeekInterval()
        return activeHabits.reduce(into: (done: 0.0, goal: 0)) { acc, habit in
            let progress = weekProgress(for: habit, logs: logs, in: interval)
            acc.done += progress.done
            acc.goal += progress.goal
        }
    }

    var bestCurrentStreak: Int {
        activeHabits.map { currentStreak(for: $0, logs: logs) }.max() ?? 0
    }

    var averageMonthlyAdherence: [Double] {
        monthlyAdherence(logs)
    }

    func logs(for habit: Habit) -> [HabitLog] {
        logs.filter { $0.habitId == habit.id }.sorted { $0.performedAt > $1.performedAt }
    }

    // MARK: - User actions
    func toggleToday(for habit: Habit, partial: Bool = false) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard !logs.contains(where: { $0.habitId == habit.id && calendar.isDate($0.performedAt, inSameDayAs: today) }) else {
            return
        }

        let log = HabitLog(
            id: UUID(),
            habitId: habit.id,
            performedAt: Date(),
            adherence: partial ? 0.5 : 1,
            notes: nil
        )

        withAnimation {
            logs.append(log)
        }

        analytics.track(event: AnalyticsEvent(name: "habit_logged", parameters: ["habit_id": habit.id.uuidString, "partial": partial]))
    }

    func addNote(_ note: String, to habit: Habit) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if let index = logs.firstIndex(where: { $0.habitId == habit.id && calendar.isDate($0.performedAt, inSameDayAs: today) }) {
            logs[index].notes = note
        } else {
            let log = HabitLog(id: UUID(), habitId: habit.id, performedAt: Date(), adherence: 0.5, notes: note)
            logs.append(log)
        }
    }

    func createHabit(name: String, description: String, goalPerWeek: Int, isActive: Bool) {
        let habit = Habit(id: UUID(), name: name, description: description, goalPerWeek: goalPerWeek, isActive: isActive)
        withAnimation {
            habits.append(habit)
        }
        analytics.track(event: AnalyticsEvent(name: "habit_created", parameters: ["goal_per_week": goalPerWeek]))
    }

    func updateGoal(for habit: Habit, goal: Int) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index].goalPerWeek = max(0, min(goal, 7))
    }

    func setActive(_ isActive: Bool, for habit: Habit) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index].isActive = isActive
    }

    // MARK: - Pure helpers (PRD-aligned)
    func currentStreak(for habit: Habit, logs: [HabitLog]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let habitLogs = logs.filter { $0.habitId == habit.id }
        let uniqueDays = Set(habitLogs.map { calendar.startOfDay(for: $0.performedAt) })

        var streak = 0
        var day = today
        while uniqueDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    func weekProgress(for habit: Habit, logs: [HabitLog], in week: DateInterval) -> (done: Double, goal: Int) {
        let calendar = Calendar.current
        let habitLogs = logs.filter { $0.habitId == habit.id && week.contains($0.performedAt) }
        let done = habitLogs.reduce(0.0) { $0 + max(0, min($1.adherence, 1)) }
        let goal = max(habit.goalPerWeek, 0)
        return (done, goal)
    }

    func monthlyAdherence(_ logs: [HabitLog], for habit: Habit? = nil) -> [Double] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = (0..<30).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        return days.map { day in
            let filtered = logs.filter {
                let matchesHabit = habit == nil || $0.habitId == habit!.id
                return matchesHabit && calendar.isDate($0.performedAt, inSameDayAs: day)
            }
            guard !filtered.isEmpty else { return 0 }
            let total = filtered.reduce(0.0) { $0 + $1.adherence }
            return max(0, min(total / Double(filtered.count), 1))
        }
    }

    func currentWeekInterval(reference: Date = Date()) -> DateInterval {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: reference)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let firstWeekday = calendar.firstWeekday
        let daysFromStart = (weekday - firstWeekday + 7) % 7
        let start = calendar.date(byAdding: .day, value: -daysFromStart, to: startOfDay) ?? startOfDay
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return DateInterval(start: start, end: end)
    }
}

// MARK: - Preview factory
extension HabitsViewModel {
    static func preview() -> HabitsViewModel {
        let today = Date()
        let calendar = Calendar.current

        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today)!
        }

        let habits = [
            Habit(id: UUID(), name: "Respiración 4-7-8", description: "5 minutos para bajar el estrés antes de competir.", goalPerWeek: 5, isActive: true),
            Habit(id: UUID(), name: "Estiramientos post-entreno", description: "Movilidad de cadera y hombros.", goalPerWeek: 4, isActive: true),
            Habit(id: UUID(), name: "Diario de gratitud", description: "Escribe 3 aprendizajes del día.", goalPerWeek: 7, isActive: true),
            Habit(id: UUID(), name: "Visualización", description: "2 minutos antes de entrenar.", goalPerWeek: 3, isActive: false)
        ]

        let logs: [HabitLog] = [
            HabitLog(id: UUID(), habitId: habits[0].id, performedAt: day(-1), adherence: 1, notes: nil),
            HabitLog(id: UUID(), habitId: habits[0].id, performedAt: day(-2), adherence: 1, notes: nil),
            HabitLog(id: UUID(), habitId: habits[0].id, performedAt: day(-3), adherence: 0.5, notes: "Sesión corta"),
            HabitLog(id: UUID(), habitId: habits[1].id, performedAt: day(-1), adherence: 1, notes: nil),
            HabitLog(id: UUID(), habitId: habits[1].id, performedAt: day(-3), adherence: 1, notes: nil),
            HabitLog(id: UUID(), habitId: habits[1].id, performedAt: day(-5), adherence: 1, notes: nil),
            HabitLog(id: UUID(), habitId: habits[2].id, performedAt: day(-1), adherence: 1, notes: "Gran día"),
            HabitLog(id: UUID(), habitId: habits[2].id, performedAt: day(-2), adherence: 1, notes: nil),
            HabitLog(id: UUID(), habitId: habits[2].id, performedAt: day(-5), adherence: 0.5, notes: nil)
        ]

        return HabitsViewModel(
            userId: "preview",
            database: DatabaseService(),
            analytics: AnalyticsService(),
            habits: habits,
            logs: logs
        )
    }
}
