#if canImport(XCTest)
import XCTest
@testable import MindAthlete

final class AgendaRecurrenceTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    @MainActor
    func testWeeklyRecurrenceGeneratesOccurrences() {
        let start = makeDate(year: 2024, month: 4, day: 1, hour: 9)
        let end = makeDate(year: 2024, month: 4, day: 1, hour: 10)
        let recurrence = AgendaRecurrence(
            frequency: .weekly,
            repeatDays: [AgendaWeekday.monday.rawValue, AgendaWeekday.wednesday.rawValue],
            endDate: calendar.date(byAdding: .weekOfYear, value: 2, to: start)
        )
        let master = AgendaEvent(
            id: UUID(),
            title: "Entrenamiento",
            start: start,
            end: end,
            kind: "entreno",
            notes: "Notas",
            source: "local",
            recurrence: recurrence
        )

        let generated = AgendaRecurrenceEngine.generateOccurrences(
            master: master,
            recurrence: recurrence,
            calendar: calendar,
            horizonMonths: 3,
            notes: master.notes ?? ""
        )

        XCTAssertEqual(generated.count, 4, "Esperábamos 4 ocurrencias adicionales")
        let weekdays = generated.map { calendar.component(.weekday, from: $0.start) }
        XCTAssertTrue(weekdays.allSatisfy { $0 == AgendaWeekday.monday.calendarValue || $0 == AgendaWeekday.wednesday.calendarValue })
        XCTAssertEqual(generated.first?.start, makeDate(year: 2024, month: 4, day: 3, hour: 9)) // Miércoles de la misma semana
    }

    @MainActor
    func testBiWeeklyRecurrenceSkipsAlternateWeeks() {
        let start = makeDate(year: 2024, month: 6, day: 4, hour: 18) // Martes
        let end = makeDate(year: 2024, month: 6, day: 4, hour: 19)
        let recurrence = AgendaRecurrence(
            frequency: .biweekly,
            repeatDays: [AgendaWeekday.tuesday.rawValue],
            endDate: calendar.date(byAdding: .weekOfYear, value: 6, to: start)
        )
        let master = AgendaEvent(
            id: UUID(),
            title: "Sesión bi-semanal",
            start: start,
            end: end,
            kind: "entreno",
            notes: "Notas",
            source: "local",
            recurrence: recurrence
        )

        let generated = AgendaRecurrenceEngine.generateOccurrences(
            master: master,
            recurrence: recurrence,
            calendar: calendar,
            horizonMonths: 3,
            notes: master.notes ?? ""
        )

        XCTAssertEqual(generated.count, 3)
        let intervals = generated.map { $0.start.timeIntervalSince(start) }
        let twoWeeks: TimeInterval = 14 * 24 * 3600
        for (index, value) in intervals.enumerated() {
            XCTAssertEqual(value, twoWeeks * Double(index + 1), accuracy: 60)
        }
    }

    @MainActor
    func testSavingMultipleEventsPerDayInPreviewMode() async {
        let base = makeDate(year: 2024, month: 5, day: 20, hour: 9)
        let viewModel = AgendaViewModel(
            userId: "test-user",
            calendarService: nil,
            database: nil,
            aiService: nil,
            analytics: AnalyticsService(),
            notificationService: NotificationService(),
            colorStore: AgendaColorStore(),
            selectedDate: base,
            isPreview: true
        )

        var firstDraft = AgendaEventDraft(
            category: .training,
            title: "Entrenamiento matutino",
            start: base,
            end: calendar.date(byAdding: .hour, value: 1, to: base)!
        )
        _ = await viewModel.saveManualEvent(firstDraft)

        let secondStart = calendar.date(byAdding: .hour, value: 2, to: base)!
        var secondDraft = AgendaEventDraft(
            category: .study,
            title: "Bloque de estudio",
            start: secondStart,
            end: calendar.date(byAdding: .hour, value: 1, to: secondStart)!
        )
        _ = await viewModel.saveManualEvent(secondDraft)

        let dayKey = calendar.startOfDay(for: base)
        let eventsForDay = viewModel.eventsByDate[dayKey] ?? []
        XCTAssertEqual(eventsForDay.count, 2, "Se esperaban múltiples eventos agrupados en la misma fecha")
    }

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.calendar = calendar
        return components.date ?? Date()
    }
}
#endif
