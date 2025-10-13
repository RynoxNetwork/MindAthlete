/*
import XCTest
import SwiftUI
@testable import MindAthlete

final class HomeViewSnapshotTests: XCTestCase {
    func testHomeViewRenders() {
        let viewModel = HomeViewModel(
            userId: "user",
            aiService: MockAIService(),
            database: MockDatabaseService(),
            analytics: MockAnalyticsService()
        )
        let view = HomeView(viewModel: viewModel)
        let renderer = ImageRenderer(content: view.frame(width: 320, height: 640))
#if canImport(UIKit)
        let image = renderer.uiImage
        XCTAssertNotNil(image)
#elseif canImport(AppKit)
        let image = renderer.nsImage
        XCTAssertNotNil(image)
#else
        XCTFail("Unsupported platform for snapshot rendering")
#endif
    }
}

private final class MockAIService: AIServiceProtocol {
    func recommendations(for userId: String, period: String) async throws -> RecommendationResponse {
        RecommendationResponse(
            recommendations: ["Visualiza tu competencia con detalle."],
            preCompetition: "Respira profundo antes de la salida.",
            rationale: "Mock",
            modelVersion: "test"
        )
    }
}

private final class MockDatabaseService: DatabaseServiceProtocol {
    func fetchMoods(for userId: String) async throws -> [Mood] { [] }
    func saveMood(_ mood: Mood) async throws {}
    func fetchHabits(for userId: String) async throws -> [Habit] { [] }
    func saveHabit(_ habit: Habit) async throws {}
    func fetchEvents(for userId: String) async throws -> [Event] { [] }
    func saveEvent(_ event: Event) async throws {}
}

private final class MockAnalyticsService: AnalyticsServiceProtocol {
    func configure() {}
    func track(event: AnalyticsEvent) {}
}

*/
