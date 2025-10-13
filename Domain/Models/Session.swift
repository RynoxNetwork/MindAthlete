
import Foundation

struct Session: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let type: String
    let durationMin: Int
    let perceivedHelp: Int?
    let notes: String?
}
