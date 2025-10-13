import Foundation

struct RecommendationDTO: Codable {
    let id: String
    let user_id: String
    let date: Date
    let message: String
    let reason: String
    let model_version: String
}

