/*/
import XCTest
@testable import MindAthlete

final class AuthServiceTests: XCTestCase {
    func testMockSignInAssignsUser() async throws {
        let service = AuthService()
        let user = try await service.signIn(email: "test@mindathlete.app", password: "123456")
        XCTAssertEqual(service.currentUser?.id, user.id)
    }
}
*/
