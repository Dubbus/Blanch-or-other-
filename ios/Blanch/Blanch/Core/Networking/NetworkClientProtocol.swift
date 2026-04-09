import Foundation

// MARK: - Network Client Protocol
// OOP Pattern: Protocol (Interface Segregation)
// Defines the contract for making network requests.
// Any class conforming to this can be swapped in — real client, mock client, cached client.
// This is how we enable unit testing without hitting the real API.

protocol NetworkClientProtocol: AnyObject {
    func request<T: Decodable>(_ request: URLRequest) async throws -> T
}

// MARK: - Network Errors

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case httpError(statusCode: Int, data: Data?)
    case decodingError(Error)
    case unauthorized
    case forbidden
    case notFound
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .httpError(let code, _):
            return "Server error (\(code))"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .unauthorized:
            return "Please sign in to continue"
        case .forbidden:
            return "Premium subscription required"
        case .notFound:
            return "Not found"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
