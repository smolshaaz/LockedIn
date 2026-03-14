import Foundation

final class LockedInAPIService {
    private let client: APIClient

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    func loadProfile() async throws -> UserProfile? {
        let envelope = try await client.get("/v1/profile", as: ProfileEnvelope.self)
        return envelope.profile
    }

    func completeOnboarding(profile: UserProfile) async throws -> UserProfile {
        struct Response: Codable { let profile: UserProfile }
        let response = try await client.post("/v1/profile/onboarding", body: profile, as: Response.self)
        return response.profile
    }

    func updateProfile(name: String?, goals: [String]?, constraints: [String]?) async throws -> UserProfile {
        struct Request: Codable {
            let name: String?
            let goals: [String]?
            let constraints: [String]?
        }
        struct Response: Codable { let profile: UserProfile }

        let response = try await client.patch(
            "/v1/profile",
            body: Request(name: name, goals: goals, constraints: constraints),
            as: Response.self
        )
        return response.profile
    }

    func sendChat(request: ChatRequest) async throws -> CoachReply {
        try await client.post("/v1/chat", body: request, as: CoachReply.self)
    }

    func submitWeeklyCheckin(_ request: WeeklyCheckinRequest) async throws -> WeeklyCheckinResponse {
        try await client.post("/v1/checkins/weekly", body: request, as: WeeklyCheckinResponse.self)
    }

    func fetchLifeScore() async throws -> LifeScoreBreakdown {
        try await client.get("/v1/lifescore", as: LifeScoreBreakdown.self)
    }
}
