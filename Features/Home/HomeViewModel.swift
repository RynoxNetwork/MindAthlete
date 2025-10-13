
import Combine
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var todaysRecommendation: RecommendationResponse?
    @Published var habits: [Habit] = []
    @Published var moods: [Mood] = []
    @Published var isLoading: Bool = false

    private let aiService: AIServiceProtocol
    private let database: DatabaseServiceProtocol
    private let analytics: AnalyticsServiceProtocol
    private let userId: String

    init(userId: String,
         aiService: AIServiceProtocol,
         database: DatabaseServiceProtocol,
         analytics: AnalyticsServiceProtocol) {
        self.userId = userId
        self.aiService = aiService
        self.database = database
        self.analytics = analytics
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            async let recommendationTask = aiService.recommendations(for: userId, period: "last_7_days")
            async let habitsTask = database.fetchHabits(for: userId)
            async let moodsTask = database.fetchMoods(for: userId)

            let (recommendation, habits, moods) = try await (recommendationTask, habitsTask, moodsTask)
            self.todaysRecommendation = recommendation
            self.habits = habits
            self.moods = moods
            analytics.track(event: AnalyticsEvent(name: "home_loaded", parameters: ["user_id": userId]))
        } catch {
            analytics.track(event: AnalyticsEvent(name: "home_load_failed", parameters: ["error": error.localizedDescription]))
        }
    }
}
