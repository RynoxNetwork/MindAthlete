
import Combine
import Foundation

@MainActor
final class HabitsViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    private let database: DatabaseServiceProtocol
    private let analytics: AnalyticsServiceProtocol
    private let userId: String

    init(userId: String, database: DatabaseServiceProtocol, analytics: AnalyticsServiceProtocol) {
        self.userId = userId
        self.database = database
        self.analytics = analytics
    }

    func load() async {
        do {
            habits = try await database.fetchHabits(for: userId)
            analytics.track(event: AnalyticsEvent(name: "habits_loaded", parameters: [:]))
        } catch {
            analytics.track(event: AnalyticsEvent(name: "habits_load_failed", parameters: ["error": error.localizedDescription]))
        }
    }
}
