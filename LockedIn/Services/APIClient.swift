import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case requestFailed
    case serverError(String)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL."
        case .requestFailed:
            return "Request failed."
        case .serverError(let message):
            return message
        case .decodeFailed:
            return "Failed to decode response."
        }
    }
}

final class APIClient {
    private let baseURL: URL
    private let userID: String

    init(baseURL: String = "http://127.0.0.1:3000", userID: String = "ios-dev-user") {
        self.baseURL = URL(string: baseURL) ?? URL(string: "http://127.0.0.1:3000")!
        self.userID = userID
    }

    func get<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        try await request(path: path, method: "GET", body: Optional<Data>.none, as: type)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B, as type: T.Type) async throws -> T {
        let data = try JSONEncoder().encode(body)
        return try await request(path: path, method: "POST", body: data, as: type)
    }

    func patch<T: Decodable, B: Encodable>(_ path: String, body: B, as type: T.Type) async throws -> T {
        let data = try JSONEncoder().encode(body)
        return try await request(path: path, method: "PATCH", body: data, as: type)
    }

    private func request<T: Decodable>(path: String, method: String, body: Data?, as type: T.Type) async throws -> T {
        guard let endpoint = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(userID, forHTTPHeaderField: "X-User-Id")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.requestFailed
        }

        guard (200...299).contains(http.statusCode) else {
            if let payload = String(data: data, encoding: .utf8) {
                throw APIError.serverError(payload)
            }
            throw APIError.requestFailed
        }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw APIError.decodeFailed
        }
    }
}
