
import Foundation

struct HabitLog: Identifiable, Codable, Equatable {
    let id: String
    let habitId: String
    let date: Date
    let value: Bool
}
