
import Foundation

struct User: Identifiable, Codable, Equatable {
    let id: String
    let email: String
    let sport: String?
    let university: String?
    let consent: Bool
    let createdAt: Date
}

extension User {
    static var mock: User {
        User(id: "mock-user", email: "deportista@mindathlete.app", sport: "Atletismo", university: "USIL", consent: true, createdAt: Date())
    }
}
