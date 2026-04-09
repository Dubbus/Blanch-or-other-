import Foundation

// MARK: - Request Builder
// OOP Pattern: Builder
// Constructs URLRequest objects step by step using a fluent API.
// Instead of manually assembling URLs, headers, and bodies everywhere,
// callers chain methods: RequestBuilder(baseURL).path("/products").query("season", id).auth(token).build()
//
// Why Builder pattern here:
// - URLRequest construction involves many optional parts (path, queries, headers, body, method)
// - Without Builder, every call site would repeat the same boilerplate
// - Builder makes the intent readable and catches errors at build-time

final class RequestBuilder {
    private let baseURL: String
    private var path: String = ""
    private var queryItems: [URLQueryItem] = []
    private var method: String = "GET"
    private var headers: [String: String] = [:]
    private var body: Data?

    init(baseURL: String) {
        self.baseURL = baseURL
        self.headers["Content-Type"] = "application/json"
    }

    // MARK: - Fluent API (each method returns self for chaining)

    @discardableResult
    func setPath(_ path: String) -> RequestBuilder {
        self.path = path
        return self
    }

    @discardableResult
    func addQuery(_ name: String, _ value: String?) -> RequestBuilder {
        if let value {
            queryItems.append(URLQueryItem(name: name, value: value))
        }
        return self
    }

    @discardableResult
    func setMethod(_ method: String) -> RequestBuilder {
        self.method = method
        return self
    }

    @discardableResult
    func setAuth(_ token: String?) -> RequestBuilder {
        if let token {
            headers["Authorization"] = "Bearer \(token)"
        }
        return self
    }

    @discardableResult
    func setBody<T: Encodable>(_ value: T) -> RequestBuilder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        self.body = try? encoder.encode(value)
        return self
    }

    @discardableResult
    func addHeader(_ name: String, _ value: String) -> RequestBuilder {
        headers[name] = value
        return self
    }

    // MARK: - Build

    func build() throws -> URLRequest {
        guard var components = URLComponents(string: baseURL + path) else {
            throw NetworkError.invalidURL
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return request
    }
}
