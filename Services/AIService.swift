
import Foundation

protocol AIServiceProtocol {
    func recommendations(for userId: String, period: String) async throws -> RecommendationResponse
}

final class AIService: AIServiceProtocol {
    private let httpClient: HTTPClient
    private let baseURL: URL
    private let useMock: Bool

    init(httpClient: HTTPClient = URLSessionHTTPClient(), baseURL: URL? = URL(string: "https://api.mindathlete.app"), useMock: Bool = ProcessInfo.processInfo.environment["USE_MOCK_AI"] == "1") {
        self.httpClient = httpClient
        self.baseURL = baseURL ?? URL(string: "https://api.mindathlete.app")!
        self.useMock = useMock
    }

    func recommendations(for userId: String, period: String) async throws -> RecommendationResponse {
        if useMock {
            return RecommendationResponse(
                recommendations: [
                    "Recuerda inhalar contando 4 y exhalar en 6 antes de tu entrenamiento.",
                    "Agenda un micro-break de 5 minutos para visualizar tu objetivo semanal.",
                    "Comparte cómo te sientes con tu equipo, la comunidad te sostiene."
                ],
                preCompetition: "En tu próxima competencia, realiza el protocolo de respiración 4-7-8 tres veces antes de iniciar.",
                rationale: "Basado en tu energía media alta y eventos próximos, reforzamos foco y calma.",
                modelVersion: "mock-2024.1"
            )
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/recommendations/generate"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = ["user_id": userId, "period": period]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        return try await httpClient.send(request, decodeTo: RecommendationResponse.self)
    }
}
