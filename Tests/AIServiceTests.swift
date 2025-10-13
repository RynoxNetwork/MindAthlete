/*/
import XCTest
@testable import MindAthlete

final class AIServiceTests: XCTestCase {
    func testMockRecommendations() async throws {
        let service = AIService(useMock: true)
        let response = try await service.recommendations(for: "user-1", period: "last_7_days")
        XCTAssertEqual(response.recommendations.count, 3)
        XCTAssertEqual(response.modelVersion, "mock-2024.1")
    }
}

*/


