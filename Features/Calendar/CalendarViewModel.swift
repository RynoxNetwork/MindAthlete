
import Combine
import Foundation

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var events: [Event] = []
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
            events = try await database.fetchEvents(for: userId)
            analytics.track(event: AnalyticsEvent(name: "calendar_loaded", parameters: [:]))
        } catch {
            analytics.track(event: AnalyticsEvent(name: "calendar_load_failed", parameters: ["error": error.localizedDescription]))
        }
    }
}
