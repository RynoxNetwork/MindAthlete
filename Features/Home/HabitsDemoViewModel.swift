#if DEMO_UI
import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - UI Models (Mock / UI-only)
public struct Habit: Identifiable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var description: String
    public var goalPerWeek: Int // 0..7
    public var isActive: Bool

    public init(id: UUID = UUID(), name: String, description: String, goalPerWeek: Int, isActive: Bool) {
        self.id = id
        self.name = name
        self.description = description
        self.goalPerWeek = goalPerWeek
        self.isActive = isActive
    }
}

public struct HabitLog: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let habitId: UUID
    public let performedAt: Date
    public var adherence: Double // 0..1
    public var notes: String?

    public init(id: UUID = UUID(), habitId: UUID, performedAt: Date, adherence: Double, notes: String? = nil) {
        self.id = id
        self.habitId = habitId
        self.performedAt = performedAt
        self.adherence = adherence
        self.notes = notes
    }
}

// MARK: - Brand Palette
public enum BrandPalette {
    public static let turquoise = Color.teal.opacity(0.9)
    public static let orange = Color.orange.opacity(0.9)
}

// MARK: - ViewModel
@MainActor
final class HabitsDemoViewModel: ObservableObject {
    // UI State
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // Data
    @Published var habits: [Habit]
    @Published var logs: [HabitLog]

    // Free tier gating (UI-only)
    let freeTierActiveHabitLimit = 3

    init(habits: [Habit] = HabitsDemoViewModel.mockHabits(), logs: [HabitLog] = HabitsDemoViewModel.mockLogs()) {
        self.habits = habits
        self.logs = logs
    }

    // MARK: - Interactions
    func toggleToday(for habit: Habit, partial: Bool = false) {
        let today = Calendar.current.startOfDay(for: Date())
        // idempotent per day
        if let existingIndex = logs.firstIndex(where: { $0.habitId == habit.id && Calendar.current.isDate($0.performedAt, inSameDayAs: today) }) {
            // If already exists, do nothing (idempotent)
            // Could allow toggling off, but PRD says one log per day
            withAnimation { /* no-op */ }
            return
        }
        let adherence = partial ? 0.5 : 1.0
        let new = HabitLog(habitId: habit.id, performedAt: Date(), adherence: adherence)
        withAnimation { logs.append(new) }
        // Light haptic
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }

    func addNote(_ note: String, for habit: Habit) {
        let today = Calendar.current.startOfDay(for: Date())
        if let idx = logs.firstIndex(where: { $0.habitId == habit.id && Calendar.current.isDate($0.performedAt, inSameDayAs: today) }) {
            logs[idx].notes = note
        } else {
            // Create a partial log with note if none exists yet
            let new = HabitLog(habitId: habit.id, performedAt: Date(), adherence: 0.5, notes: note)
            logs.append(new)
        }
    }

    func createHabit(name: String, description: String, goalPerWeek: Int, isActive: Bool) {
        let habit = Habit(name: name, description: description, goalPerWeek: goalPerWeek, isActive: isActive)
        habits.append(habit)
    }

    // MARK: - Pure helpers (PRD-aligned)
    func currentStreak(for habit: Habit, logs: [HabitLog]) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let habitLogs = logs.filter { $0.habitId == habit.id }
        let uniqueDays = Set(habitLogs.map { cal.startOfDay(for: $0.performedAt) })

        var streak = 0
        var day = today
        while uniqueDays.contains(day) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    func weekProgress(for habit: Habit, logs: [HabitLog], in week: DateInterval) -> (done: Double, goal: Int) {
        let cal = Calendar.current
        let habitLogs = logs.filter { $0.habitId == habit.id && week.contains($0.performedAt) }
        let done = habitLogs.reduce(0.0) { $0 + min(max($1.adherence, 0), 1) }
        let goal = max(habit.goalPerWeek, 0)
        return (done, goal)
    }

    func monthlyAdherence(_ logs: [HabitLog], for habit: Habit? = nil) -> [Double] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let days = (0..<30).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
        var result: [Double] = []
        for d in days {
            let dayLogs = logs.filter { (habit == nil || $0.habitId == habit!.id) && cal.isDate($0.performedAt, inSameDayAs: d) }
            if dayLogs.isEmpty {
                result.append(0)
            } else {
                // Average adherence for the day (across habits)
                let avg = dayLogs.reduce(0.0) { $0 + $1.adherence } / Double(dayLogs.count)
                result.append(min(max(avg, 0), 1))
            }
        }
        return result
    }

    // MARK: - Aggregates for Dashboard
    var activeHabits: [Habit] { habits.filter { $0.isActive } }

    var combinedWeekProgress: (done: Double, goal: Int) {
        let interval = currentWeekInterval()
        var done: Double = 0
        var goal: Int = 0
        for h in activeHabits {
            let p = weekProgress(for: h, logs: logs, in: interval)
            done += p.done
            goal += p.goal
        }
        return (done, goal)
    }

    var bestCurrentStreak: Int {
        activeHabits.map { currentStreak(for: $0, logs: logs) }.max() ?? 0
    }

    var averageMonthlyAdherence: [Double] {
        monthlyAdherence(logs, for: nil)
    }

    func currentWeekInterval(reference: Date = Date()) -> DateInterval {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: reference)
        let weekday = cal.component(.weekday, from: startOfDay)
        let firstWeekday = cal.firstWeekday
        let daysFromStart = (weekday - firstWeekday + 7) % 7
        let start = cal.date(byAdding: .day, value: -daysFromStart, to: startOfDay) ?? startOfDay
        let end = cal.date(byAdding: .day, value: 7, to: start) ?? start
        return DateInterval(start: start, end: end)
    }
}

// MARK: - Mock Data
extension HabitsDemoViewModel {
    static func mockHabits() -> [Habit] {
        return [
            Habit(name: "Respiración 4-7-8", description: "5 minutos de respiración para bajar estrés.", goalPerWeek: 5, isActive: true),
            Habit(name: "Estiramientos", description: "Movilidad 10 min post-entreno.", goalPerWeek: 4, isActive: true),
            Habit(name: "Diario", description: "Escribir 3 cosas positivas.", goalPerWeek: 7, isActive: false)
        ]
    }

    static func mockLogs() -> [HabitLog] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: today)! }
        let h1 = mockHabits()[0].id
        let h2 = mockHabits()[1].id
        return [
            HabitLog(habitId: h1, performedAt: day(-1), adherence: 1),
            HabitLog(habitId: h1, performedAt: day(-2), adherence: 1),
            HabitLog(habitId: h1, performedAt: day(-4), adherence: 0.5),
            HabitLog(habitId: h2, performedAt: day(-1), adherence: 1),
            HabitLog(habitId: h2, performedAt: day(-3), adherence: 1),
        ]
    }
}

// MARK: - Small helpers for UI
extension Double {
    var clamped01: Double { min(max(self, 0), 1) }
}

#endif
