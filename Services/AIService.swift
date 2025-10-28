import Foundation
import Supabase

protocol AIServiceProtocol {
    func recommendations(for userId: String, period: String) async throws -> RecommendationResponse
    func dailyRecommendation(for userId: String, date: Date) async throws -> DailyRecommendationResponseDTO
    func chatStream(
        userId: String,
        chatId: UUID?,
        messages: [ChatMessagePayload],
        tone: String?,
        targetGoal: String?
    ) -> AsyncThrowingStream<ChatStreamEvent, Error>
    func generateHabitPlan(for userId: String, timeframe: String?, context: [String: String]?) async throws -> HabitPlanResponseDTO
    func escalate(for userId: String, context: [String: String]?, reason: String?) async throws -> EscalationResponseDTO
}

final class AIService: AIServiceProtocol {
    private let httpClient: HTTPClient
    private let streamingSession: URLSession
    private let baseURL: URL
    private let useMock: Bool
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        httpClient: HTTPClient = URLSessionHTTPClient(),
        streamingSession: URLSession = .shared,
        baseURL: URL? = URL(string: "https://api.mindathlete.app"),
        useMock: Bool = ProcessInfo.processInfo.environment["USE_MOCK_AI"] == "1"
    ) {
        self.httpClient = httpClient
        self.streamingSession = streamingSession
        self.baseURL = baseURL ?? URL(string: "https://api.mindathlete.app")!
        self.useMock = useMock

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // MARK: - Public API

    func recommendations(for userId: String, period: String) async throws -> RecommendationResponse {
        if useMock {
            return RecommendationResponse(
                recommendations: [
                    "Respira profundo 4-7-8 antes de tu sesión dura de hoy.",
                    "Usa la visualización de objetivos al terminar la jornada académica.",
                    "Comparte en tu diario una victoria pequeña para reforzar confianza."
                ],
                preCompetition: "Realiza tres ciclos de respiración y afirma tu palabra ancla 45 minutos antes del encuentro.",
                rationale: "Generado localmente (modo mock) según tu carga semanal y hábitos activos.",
                modelVersion: "mock-2024.11"
            )
        }

        let payload = ["user_id": userId, "period": period]
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        var request = try await makeRequest(path: "api/recommendations/generate", method: "POST", body: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await httpClient.send(request, decodeTo: RecommendationResponse.self)
    }

    func dailyRecommendation(for userId: String, date: Date) async throws -> DailyRecommendationResponseDTO {
        if useMock {
            let context = DailyRecommendationEventContextDTO(
                title: "Entrenamiento técnico",
                kind: "entreno",
                start: date.addingTimeInterval(3600),
                end: date.addingTimeInterval(5400),
                notes: "Trabajo de velocidad"
            )
            return DailyRecommendationResponseDTO(
                recommendations: [
                    "Agenda una respiración cuadrada 20 minutos antes del entrenamiento para centrarte.",
                    "Reserva 10 minutos tras la sesión para registrar sensaciones en el diario."
                ],
                rationale: "Mock: Ajustado a tu bloque libre antes del entrenamiento técnico.",
                eventContext: [context],
                escalate: false,
                modelVersion: "mock-2024.11"
            )
        }

        let payload: [String: Any] = [
            "date": Self.dayFormatter.string(from: date)
        ]
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        var request = try await makeRequest(path: "api/recommendations/daily", method: "POST", body: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: DailyRecommendationResponseDTO = try await httpClient.send(request, decodeTo: DailyRecommendationResponseDTO.self)
        return data
    }

    func chatStream(
        userId: String,
        chatId: UUID?,
        messages: [ChatMessagePayload],
        tone: String?,
        targetGoal: String?
    ) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        if useMock {
            return AsyncThrowingStream { continuation in
                let mockChatId = chatId ?? UUID()
                let response = "Entiendo la presión que estás sintiendo. Hagamos 3 ciclos de respiración triangular y luego define una acción pequeña para hoy."
                let chunks = response.chunked(into: 60)
                for chunk in chunks {
                    continuation.yield(ChatStreamEvent(chatId: mockChatId, delta: chunk, finished: false, escalate: false, habitHint: "Respiración triangular", bookingURL: nil, model: "mock-2024.11"))
                }
                continuation.yield(ChatStreamEvent(chatId: mockChatId, delta: nil, finished: true, escalate: false, habitHint: "Respiración triangular", bookingURL: nil, model: "mock-2024.11"))
                continuation.finish()
            }
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var payload: [String: Any] = [
                        "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] }
                    ]
                    if let chatId {
                        payload["chat_id"] = chatId.uuidString
                    }
                    if let tone {
                        payload["tone"] = tone
                    }
                    if let targetGoal {
                        payload["target_goal"] = targetGoal
                    }
                    let body = try JSONSerialization.data(withJSONObject: payload, options: [])
                    var request = try await makeRequest(path: "api/coach/chat", method: "POST", body: body)
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("application/json", forHTTPHeaderField: "Accept")

                    let (bytes, response) = try await streamingSession.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse, (200 ..< 300).contains(httpResponse.statusCode) else {
                        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                        throw NetworkError.unexpected
                    }

                    for try await line in bytes.lines {
                        guard !line.isEmpty, let data = line.data(using: .utf8) else { continue }
                        let event = try decoder.decode(ChatStreamEvent.self, from: data)
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func generateHabitPlan(for userId: String, timeframe: String?, context: [String: String]?) async throws -> HabitPlanResponseDTO {
        if useMock {
            return HabitPlanResponseDTO(
                habits: [
                    HabitPlanItemDTO(title: "Checklist pre-entreno", recommendedStartDate: Date(), frequency: "daily", rationale: "Alinear mentalmente tu sesión"),
                    HabitPlanItemDTO(title: "Microvisualización nocturna", recommendedStartDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()), frequency: "3x semana", rationale: "Refuerza confianza antes de competir")
                ],
                summary: "Plan generado en modo mock basado en tu enfoque actual."
            )
        }

        var payload: [String: Any] = [:]
        if let timeframe {
            payload["timeframe"] = timeframe
        }
        if let context, !context.isEmpty {
            payload["context"] = context
        }
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        var request = try await makeRequest(path: "api/coach/habit-plan", method: "POST", body: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await httpClient.send(request, decodeTo: HabitPlanResponseDTO.self)
    }

    func escalate(for userId: String, context: [String: String]?, reason: String?) async throws -> EscalationResponseDTO {
        if useMock {
            return EscalationResponseDTO(escalate: true, bookingURL: URL(string: "https://mindathlete.app/agenda"), message: "Mock: agenda una sesión con nuestro equipo.")
        }

        var payload: [String: Any] = [:]
        if let context, !context.isEmpty {
            payload["context"] = context
        } else {
            payload["context"] = [:]
        }
        if let reason {
            payload["reason"] = reason
        }
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        var request = try await makeRequest(path: "api/escalate", method: "POST", body: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await httpClient.send(request, decodeTo: EscalationResponseDTO.self)
    }

    // MARK: - Helpers

    private func makeRequest(path: String, method: String, body: Data? = nil) async throws -> URLRequest {
        var request = URLRequest(url: endpointURL(for: path))
        request.httpMethod = method
        request.httpBody = body
        if let token = await authToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func endpointURL(for path: String) -> URL {
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return baseURL.appendingPathComponent(cleanPath)
    }

    private func authToken() async -> String? {
        do {
            let session = try await MAClients.shared.auth.session
            return session.accessToken
        } catch {
            return nil
        }
    }
}

// MARK: - Payloads

// MARK: - Utilities

private extension String {
    func chunked(into size: Int) -> [String] {
        guard size > 0 else { return [self] }
        var result: [String] = []
        var current = ""
        for character in self {
            current.append(character)
            if current.count >= size {
                result.append(current)
                current.removeAll(keepingCapacity: true)
            }
        }
        if !current.isEmpty {
            result.append(current)
        }
        return result
    }
}
