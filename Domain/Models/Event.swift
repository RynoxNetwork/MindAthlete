
import Foundation

struct Event: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let type: String
    let date: Date
    let importance: Int
}
