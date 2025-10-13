
import Foundation

struct MoodDTO: Codable {
    let id: String
    let user_id: String
    let date: Date
    let score: Int
    let energy: Int
    let tags: [String]
    let notes: String?
}
