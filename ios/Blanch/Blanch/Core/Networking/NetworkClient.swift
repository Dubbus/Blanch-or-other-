import Foundation

// MARK: - Network Client
// OOP Pattern: Class with Protocol Conformance
// This is the concrete implementation of NetworkClientProtocol.
// It owns a URLSession and handles JSON decoding, error mapping, and auth headers.
// In tests, we swap this out for a MockNetworkClient that returns canned responses.

final class NetworkClient: NetworkClientProtocol, @unchecked Sendable {
    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    func request<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown(URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw NetworkError.decodingError(error)
            }
        case 401:
            throw NetworkError.unauthorized
        case 403:
            throw NetworkError.forbidden
        case 404:
            throw NetworkError.notFound
        default:
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    // Convenience: build a full URL from a path
    func buildURL(path: String) -> URL? {
        URL(string: baseURL + path)
    }
}
