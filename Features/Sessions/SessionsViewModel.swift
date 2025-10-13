
import Combine
import Foundation

@MainActor
final class SessionsViewModel: ObservableObject {
    @Published var sessions: [Session] = []
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
            // Placeholder: fetch from database once implemented
            sessions = []
            analytics.track(event: AnalyticsEvent(name: "sessions_loaded", parameters: [:]))
        } catch {
            analytics.track(event: AnalyticsEvent(name: "sessions_load_failed", parameters: ["error": error.localizedDescription]))
        }
    }
}
