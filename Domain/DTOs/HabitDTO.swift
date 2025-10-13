import Foundation

struct HabitDTO: Codable {
    let id: String
    let user_id: String
    let name: String
    let target_per_week: Int
    let active: Bool
}
