import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case requestFailed
    case serverError(String)
    case decodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL."
        case .requestFailed:
            return "Request failed."
        case .serverError(let message):
            return message
        case .decodeFailed(let details):
            return details.isEmpty ? "Failed to decode response." : details
        }
    }
}

final class APIClient {
    private static let productionFallbackBaseURL = "https://lockedin-co8j.onrender.com"
    private static let placeholderBaseURLs: Set<String> = [
        "https://api.lockedin.app",
        "http://api.lockedin.app",
        "api.lockedin.app",
    ]

    private let baseURL: URL
    private let userID: String

    init(baseURL: String? = nil, userID: String? = nil) {
        self.baseURL = APIClient.resolveBaseURL(from: baseURL)
        self.userID = APIClient.resolveUserID(from: userID)
#if DEBUG
        print("[APIClient] baseURL=\(self.baseURL.absoluteString)")
#endif
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

    func delete<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        try await request(path: path, method: "DELETE", body: Optional<Data>.none, as: type)
    }

    func streamPost<B: Encodable>(_ path: String, body: B) async throws -> URLSession.AsyncBytes {
        let data = try JSONEncoder().encode(body)
        let request = try buildRequest(path: path, method: "POST", body: data)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.requestFailed
        }

        guard (200...299).contains(http.statusCode) else {
            throw APIError.serverError("Stream request failed with status \(http.statusCode).")
        }

        return bytes
    }

    private func request<T: Decodable>(path: String, method: String, body: Data?, as type: T.Type) async throws -> T {
        let request = try buildRequest(path: path, method: method, body: body)

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
            let raw = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            let snippet = String(raw.prefix(320))
            throw APIError.decodeFailed("Failed to decode response. Payload: \(snippet)")
        }
    }

    private func buildRequest(path: String, method: String, body: Data?) throws -> URLRequest {
        guard let endpoint = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(userID, forHTTPHeaderField: "X-User-Id")
        request.httpBody = body
        return request
    }

    private static func resolveBaseURL(from explicit: String?) -> URL {
        let sources: [String?] = [
            explicit,
            UserDefaults.standard.string(forKey: "LOCK_API_BASE_URL"),
            ProcessInfo.processInfo.environment["LOCK_API_BASE_URL"],
            Bundle.main.object(forInfoDictionaryKey: "LOCK_API_BASE_URL") as? String,
            productionFallbackBaseURL,
        ]

        for source in sources {
            guard let normalized = normalizeBaseURL(source),
                  let url = URL(string: normalized) else {
                continue
            }
            if placeholderBaseURLs.contains(normalized.lowercased()) {
                continue
            }
            return url
        }

        return URL(string: productionFallbackBaseURL)!
    }

    private static func resolveUserID(from explicit: String?) -> String {
        let sources: [String?] = [
            explicit,
            UserDefaults.standard.string(forKey: "LOCK_API_USER_ID"),
            ProcessInfo.processInfo.environment["LOCK_API_USER_ID"],
            Bundle.main.object(forInfoDictionaryKey: "LOCK_API_USER_ID") as? String,
            "ios-dev-user",
        ]

        for source in sources {
            let candidate = source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !candidate.isEmpty { return candidate }
        }

        return "ios-dev-user"
    }

    private static func normalizeBaseURL(_ raw: String?) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        // Xcode build settings or manual paste can include wrapping quotes.
        while (value.hasPrefix("\"") && value.hasSuffix("\""))
            || (value.hasPrefix("'") && value.hasSuffix("'")) {
            value = String(value.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if !value.contains("://") {
            value = "https://\(value)"
        }

        while value.hasSuffix("/") {
            value.removeLast()
        }

        return value
    }
}
