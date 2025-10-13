
import Foundation

struct Recommendation: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let date: Date
    let message: String
    let reason: String
    let modelVersion: String
}
