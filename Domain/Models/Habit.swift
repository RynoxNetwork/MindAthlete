import Foundation

struct Habit: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let name: String
    let targetPerWeek: Int
    let active: Bool
}
