//
//  RecommendationResponse.swift
//  MindAthlete
//
//  Created by Renato Riva on 10/12/25.
//

import Foundation

struct RecommendationResponse: Codable, Equatable {
    let recommendations: [String]
    let preCompetition: String?
    let rationale: String
    let modelVersion: String

    enum CodingKeys: String, CodingKey {
        case recommendations
        case preCompetition = "pre_competition"
        case rationale
        case modelVersion = "model_version"
    }
}

struct DailyRecommendationEventContextDTO: Codable, Equatable {
    let title: String
    let kind: String?
    let start: Date
    let end: Date?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case title
        case kind
        case start
        case end
        case notes
    }
}

struct DailyRecommendationResponseDTO: Codable, Equatable {
    let recommendations: [String]
    let rationale: String?
    let eventContext: [DailyRecommendationEventContextDTO]
    let escalate: Bool
    let modelVersion: String

    enum CodingKeys: String, CodingKey {
        case recommendations
        case rationale
        case eventContext = "event_context"
        case escalate
        case modelVersion = "model_version"
    }
}

enum ChatMessageRole: String, Codable {
    case user
    case assistant
    case system
}

struct ChatMessagePayload: Codable, Identifiable, Equatable {
    let id: UUID
    let role: ChatMessageRole
    let content: String

    init(id: UUID = UUID(), role: ChatMessageRole, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

struct ChatStreamEvent: Codable {
    let chatId: UUID
    let delta: String?
    let finished: Bool
    let escalate: Bool?
    let habitHint: String?
    let bookingURL: URL?
    let model: String?

    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case delta
        case finished
        case escalate
        case habitHint = "habit_hint"
        case bookingURL = "booking_url"
        case model
    }
}

struct HabitPlanItemDTO: Codable, Equatable, Identifiable {
    let id: UUID
    let title: String
    let recommendedStartDate: Date?
    let frequency: String
    let rationale: String?

    init(id: UUID = UUID(), title: String, recommendedStartDate: Date?, frequency: String, rationale: String?) {
        self.id = id
        self.title = title
        self.recommendedStartDate = recommendedStartDate
        self.frequency = frequency
        self.rationale = rationale
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case recommendedStartDate = "recommended_start_date"
        case frequency
        case rationale
    }
}

struct HabitPlanResponseDTO: Codable, Equatable {
    let habits: [HabitPlanItemDTO]
    let summary: String?
}

struct EscalationResponseDTO: Codable, Equatable {
    let escalate: Bool
    let bookingURL: URL?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case escalate
        case bookingURL = "booking_url"
        case message
    }
}
