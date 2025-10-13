import Foundation

struct UserDTO: Codable {
    let id: String
    let email: String
    let sport: String?
    let university: String?
    let consent: Bool
    let created_at: Date
}
