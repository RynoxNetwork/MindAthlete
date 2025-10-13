import Foundation

protocol HTTPClient {
    func send<T: Decodable>(_ request: URLRequest, decodeTo type: T.Type) async throws -> T
}

final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send<T>(_ request: URLRequest, decodeTo type: T.Type) async throws -> T where T : Decodable {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}

enum NetworkError: Error {
    case invalidResponse
    case decodingFailed
    case unauthorized
    case unexpected
}
