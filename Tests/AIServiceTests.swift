#if canImport(XCTest)
import XCTest
@testable import MindAthlete

final class AIServiceTests: XCTestCase {
    func testMockRecommendations() async throws {
        let service = AIService(useMock: true)
        let response = try await service.recommendations(for: "user-1", period: "last_7_days")
        XCTAssertEqual(response.recommendations.count, 3)
        XCTAssertEqual(response.modelVersion, "mock-2024.11")
    }

    func testMockDailyRecommendation() async throws {
        let service = AIService(useMock: true)
        let response = try await service.dailyRecommendation(for: "user-1", date: Date())
        XCTAssertFalse(response.recommendations.isEmpty)
        XCTAssertEqual(response.modelVersion, "mock-2024.11")
        XCTAssertFalse(response.escalate)
    }

    func testMockChatStream() async throws {
        let service = AIService(useMock: true)
        let messages = [ChatMessagePayload(role: .user, content: "Necesito ayuda")]
        let stream = service.chatStream(userId: "user-1", chatId: nil, messages: messages, tone: nil, targetGoal: nil)

        var received = ""
        var finished = false

        for try await event in stream {
            if let delta = event.delta {
                received += delta
            }
            if event.finished {
                finished = true
            }
        }

        XCTAssertTrue(finished)
        XCTAssertTrue(received.contains("respiración triangular"))
    }

    func testMockHabitPlan() async throws {
        let service = AIService(useMock: true)
        let plan = try await service.generateHabitPlan(for: "user-1", timeframe: "next 7 days", context: nil)
        XCTAssertFalse(plan.habits.isEmpty)
        XCTAssertEqual(plan.habits.first?.title, "Checklist pre-entreno")
    }

    func testMockEscalation() async throws {
        let service = AIService(useMock: true)
        let response = try await service.escalate(for: "user-1", context: nil, reason: nil)
        XCTAssertTrue(response.escalate)
        XCTAssertNotNil(response.bookingURL)
    }
}
#endif
