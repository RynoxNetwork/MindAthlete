import Foundation

struct Mood: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let date: Date
    let score: Int
    let energy: Int
    let tags: [String]
    let notes: String?
}
