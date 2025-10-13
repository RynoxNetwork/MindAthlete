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
