//
//  SupabaseConfiguration.swift
//  MindAthlete
//
//  Created by Renato Riva on 10/12/25.
//


import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct SupabaseConfiguration: Sendable {
    let restURL: URL
    let apiKey: String
    let schema: String

    init(restURL: URL, apiKey: String, schema: String = "public") {
        self.restURL = restURL
        self.apiKey = apiKey
        self.schema = schema
    }
}

enum DatabaseServiceError: Error, LocalizedError {
    case invalidURL
    case requestFailed(underlying: Error)
    case unexpectedStatusCode(code: Int, data: Data?)
    case decodingFailed(underlying: Error)
    case encodingFailed(underlying: Error)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The Supabase URL provided was invalid."
        case let .requestFailed(underlying):
            return "The database request failed: \(underlying.localizedDescription)"
        case let .unexpectedStatusCode(code, _):
            return "Supabase responded with an unexpected status code: \(code)."
        case let .decodingFailed(underlying):
            return "Failed to decode the Supabase response: \(underlying.localizedDescription)"
        case let .encodingFailed(underlying):
            return "Failed to encode the Supabase payload: \(underlying.localizedDescription)"
        case .emptyResponse:
            return "Supabase returned an empty response when data was expected."
        }
    }
}

protocol SupabaseDatabaseServicing {
    func getMoods(for userId: String) async throws -> [Mood]
    func saveMood(_ mood: Mood) async throws -> Mood
    func updateMood(_ mood: Mood) async throws -> Mood
    func deleteMood(id: String) async throws

    func getHabits(for userId: String) async throws -> [Habit]
    func saveHabit(_ habit: Habit) async throws -> Habit
    func updateHabit(_ habit: Habit) async throws -> Habit
    func deleteHabit(id: String) async throws

    func getHabitLogs(for habitId: String) async throws -> [HabitLog]
    func saveHabitLog(_ log: HabitLog) async throws -> HabitLog
    func updateHabitLog(_ log: HabitLog) async throws -> HabitLog
    func deleteHabitLog(id: String) async throws

    func getSessions(for userId: String) async throws -> [Session]
    func saveSession(_ session: Session) async throws -> Session
    func updateSession(_ session: Session) async throws -> Session
    func deleteSession(id: String) async throws

    func getEvents(for userId: String) async throws -> [Event]
    func saveEvent(_ event: Event) async throws -> Event
    func updateEvent(_ event: Event) async throws -> Event
    func deleteEvent(id: String) async throws

    func getRecommendations(for userId: String) async throws -> [Recommendation]
    func saveRecommendation(_ recommendation: Recommendation) async throws -> Recommendation
    func updateRecommendation(_ recommendation: Recommendation) async throws -> Recommendation
    func deleteRecommendation(id: String) async throws
}

final class SupabaseDatabaseClient: SupabaseDatabaseServicing {
    private let configuration: SupabaseConfiguration
    private let urlSession: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        configuration: SupabaseConfiguration,
        urlSession: URLSession = .shared,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.configuration = configuration
        self.urlSession = urlSession
        self.encoder = encoder
        self.decoder = decoder
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Moods

    func getMoods(for userId: String) async throws -> [Mood] {
        let query = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "select", value: "*")
        ]
        let request = try makeRequest(path: "moods", method: .get, queryItems: query)
        return try await perform(request, as: [Mood].self)
    }

    func saveMood(_ mood: Mood) async throws -> Mood {
        let request = try makeRequest(path: "moods", method: .post, body: mood, preferRepresentation: true)
        return try await performSingle(request, as: Mood.self)
    }

    func updateMood(_ mood: Mood) async throws -> Mood {
        let query = [URLQueryItem(name: "id", value: "eq.\(mood.id)")]
        let request = try makeRequest(path: "moods", method: .patch, queryItems: query, body: mood, preferRepresentation: true)
        return try await performSingle(request, as: Mood.self)
    }

    func deleteMood(id: String) async throws {
        let query = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let request = try makeRequest(path: "moods", method: .delete, queryItems: query)
        try await performEmpty(request)
    }

    // MARK: - Habits

    func getHabits(for userId: String) async throws -> [Habit] {
        let query = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "select", value: "*")
        ]
        let request = try makeRequest(path: "habits", method: .get, queryItems: query)
        return try await perform(request, as: [Habit].self)
    }

    func saveHabit(_ habit: Habit) async throws -> Habit {
        let request = try makeRequest(path: "habits", method: .post, body: habit, preferRepresentation: true)
        return try await performSingle(request, as: Habit.self)
    }

    func updateHabit(_ habit: Habit) async throws -> Habit {
        let query = [URLQueryItem(name: "id", value: "eq.\(habit.id)")]
        let request = try makeRequest(path: "habits", method: .patch, queryItems: query, body: habit, preferRepresentation: true)
        return try await performSingle(request, as: Habit.self)
    }

    func deleteHabit(id: String) async throws {
        let query = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let request = try makeRequest(path: "habits", method: .delete, queryItems: query)
        try await performEmpty(request)
    }

    // MARK: - Habit Logs

    func getHabitLogs(for habitId: String) async throws -> [HabitLog] {
        let query = [
            URLQueryItem(name: "habit_id", value: "eq.\(habitId)"),
            URLQueryItem(name: "select", value: "*")
        ]
        let request = try makeRequest(path: "habit_logs", method: .get, queryItems: query)
        return try await perform(request, as: [HabitLog].self)
    }

    func saveHabitLog(_ log: HabitLog) async throws -> HabitLog {
        let request = try makeRequest(path: "habit_logs", method: .post, body: log, preferRepresentation: true)
        return try await performSingle(request, as: HabitLog.self)
    }

    func updateHabitLog(_ log: HabitLog) async throws -> HabitLog {
        let query = [URLQueryItem(name: "id", value: "eq.\(log.id)")]
        let request = try makeRequest(path: "habit_logs", method: .patch, queryItems: query, body: log, preferRepresentation: true)
        return try await performSingle(request, as: HabitLog.self)
    }

    func deleteHabitLog(id: String) async throws {
        let query = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let request = try makeRequest(path: "habit_logs", method: .delete, queryItems: query)
        try await performEmpty(request)
    }

    // MARK: - Sessions

    func getSessions(for userId: String) async throws -> [Session] {
        let query = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "select", value: "*")
        ]
        let request = try makeRequest(path: "sessions", method: .get, queryItems: query)
        return try await perform(request, as: [Session].self)
    }

    func saveSession(_ session: Session) async throws -> Session {
        let request = try makeRequest(path: "sessions", method: .post, body: session, preferRepresentation: true)
        return try await performSingle(request, as: Session.self)
    }

    func updateSession(_ session: Session) async throws -> Session {
        let query = [URLQueryItem(name: "id", value: "eq.\(session.id)")]
        let request = try makeRequest(path: "sessions", method: .patch, queryItems: query, body: session, preferRepresentation: true)
        return try await performSingle(request, as: Session.self)
    }

    func deleteSession(id: String) async throws {
        let query = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let request = try makeRequest(path: "sessions", method: .delete, queryItems: query)
        try await performEmpty(request)
    }

    // MARK: - Events

    func getEvents(for userId: String) async throws -> [Event] {
        let query = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "select", value: "*")
        ]
        let request = try makeRequest(path: "events", method: .get, queryItems: query)
        return try await perform(request, as: [Event].self)
    }

    func saveEvent(_ event: Event) async throws -> Event {
        let request = try makeRequest(path: "events", method: .post, body: event, preferRepresentation: true)
        return try await performSingle(request, as: Event.self)
    }

    func updateEvent(_ event: Event) async throws -> Event {
        let query = [URLQueryItem(name: "id", value: "eq.\(event.id)")]
        let request = try makeRequest(path: "events", method: .patch, queryItems: query, body: event, preferRepresentation: true)
        return try await performSingle(request, as: Event.self)
    }

    func deleteEvent(id: String) async throws {
        let query = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let request = try makeRequest(path: "events", method: .delete, queryItems: query)
        try await performEmpty(request)
    }

    // MARK: - Recommendations

    func getRecommendations(for userId: String) async throws -> [Recommendation] {
        let query = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "select", value: "*")
        ]
        let request = try makeRequest(path: "recommendations", method: .get, queryItems: query)
        return try await perform(request, as: [Recommendation].self)
    }

    func saveRecommendation(_ recommendation: Recommendation) async throws -> Recommendation {
        let request = try makeRequest(path: "recommendations", method: .post, body: recommendation, preferRepresentation: true)
        return try await performSingle(request, as: Recommendation.self)
    }

    func updateRecommendation(_ recommendation: Recommendation) async throws -> Recommendation {
        let query = [URLQueryItem(name: "id", value: "eq.\(recommendation.id)")]
        let request = try makeRequest(path: "recommendations", method: .patch, queryItems: query, body: recommendation, preferRepresentation: true)
        return try await performSingle(request, as: Recommendation.self)
    }

    func deleteRecommendation(id: String) async throws {
        let query = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let request = try makeRequest(path: "recommendations", method: .delete, queryItems: query)
        try await performEmpty(request)
    }

    // MARK: - Request helpers

    private func makeRequest(path: String, method: SupabaseHTTPMethod, queryItems: [URLQueryItem] = [], preferRepresentation: Bool = false) throws -> URLRequest {
        try makeRequest(path: path, method: method, queryItems: queryItems, body: Optional<Data>.none, preferRepresentation: preferRepresentation)
    }

    private func makeRequest<Body: Encodable>(path: String, method: SupabaseHTTPMethod, queryItems: [URLQueryItem] = [], body: Body, preferRepresentation: Bool) throws -> URLRequest {
        do {
            let data = try encoder.encode(body)
            return try makeRequest(path: path, method: method, queryItems: queryItems, body: data, preferRepresentation: preferRepresentation)
        } catch {
            throw DatabaseServiceError.encodingFailed(underlying: error)
        }
    }

    private func makeRequest(path: String, method: SupabaseHTTPMethod, queryItems: [URLQueryItem], body: Data?, preferRepresentation: Bool) throws -> URLRequest {
        guard var components = URLComponents(url: configuration.restURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw DatabaseServiceError.invalidURL
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw DatabaseServiceError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(configuration.apiKey, forHTTPHeaderField: "apikey")
        request.setValue(configuration.schema, forHTTPHeaderField: "Accept-Profile")
        request.setValue(configuration.schema, forHTTPHeaderField: "Content-Profile")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if preferRepresentation {
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        }
        request.httpBody = body
        return request
    }

    private func performEmpty(_ request: URLRequest) async throws {
        let (_, response) = try await data(for: request)
        guard (200 ... 299).contains(response.statusCode) else {
            throw DatabaseServiceError.unexpectedStatusCode(code: response.statusCode, data: nil)
        }
    }

    private func perform<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response) = try await data(for: request)
        guard (200 ... 299).contains(response.statusCode) else {
            throw DatabaseServiceError.unexpectedStatusCode(code: response.statusCode, data: data)
        }
        do {
            if data.isEmpty, let emptyValue = [] as? T {
                return emptyValue
            }
            return try decoder.decode(T.self, from: data)
        } catch {
            throw DatabaseServiceError.decodingFailed(underlying: error)
        }
    }

    private func performSingle<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let items = try await perform(request, as: [T].self)
        guard let item = items.first else {
            throw DatabaseServiceError.emptyResponse
        }
        return item
    }

    private func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw DatabaseServiceError.invalidURL
            }
            return (data, httpResponse)
        } catch {
            throw DatabaseServiceError.requestFailed(underlying: error)
        }
    }
}

private enum SupabaseHTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}
