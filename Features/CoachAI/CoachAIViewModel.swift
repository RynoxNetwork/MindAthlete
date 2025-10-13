
import Combine
import Foundation

@MainActor
final class CoachAIViewModel: ObservableObject {
    @Published var recommendations: RecommendationResponse?
    @Published var isLoading = false

    private let aiService: AIServiceProtocol
    private let analytics: AnalyticsServiceProtocol
    private let userId: String

    init(userId: String, aiService: AIServiceProtocol, analytics: AnalyticsServiceProtocol) {
        self.userId = userId
        self.aiService = aiService
        self.analytics = analytics
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            recommendations = try await aiService.recommendations(for: userId, period: "last_7_days")
            analytics.track(event: AnalyticsEvent(name: "coach_ai_loaded", parameters: [:]))
        } catch {
            analytics.track(event: AnalyticsEvent(name: "coach_ai_failed", parameters: ["error": error.localizedDescription]))
        }
    }
}
