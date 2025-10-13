
import Combine
import Foundation

@MainActor
final class DiaryViewModel: ObservableObject {
    @Published var moods: [Mood] = []
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
            moods = try await database.fetchMoods(for: userId)
            analytics.track(event: AnalyticsEvent(name: "diary_loaded", parameters: [:]))
        } catch {
            analytics.track(event: AnalyticsEvent(name: "diary_load_failed", parameters: ["error": error.localizedDescription]))
        }
    }
}
