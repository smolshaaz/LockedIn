import Foundation

final class LockedInAPIService {
    private let client: APIClient
    private let decoder = JSONDecoder()

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

    func bootstrapTestingUser() async throws -> UserProfile {
        struct EmptyBody: Codable {}
        struct Response: Codable { let profile: UserProfile? }

        let response = try await client.post("/v1/testing/bootstrap", body: EmptyBody(), as: Response.self)
        guard let profile = response.profile else {
            throw APIError.serverError("Testing bootstrap did not return a profile.")
        }
        return profile
    }

    func updateProfile(_ request: ProfileUpdateRequest) async throws -> UserProfile {
        struct Response: Codable { let profile: UserProfile }

        let response = try await client.patch(
            "/v1/profile",
            body: request,
            as: Response.self
        )
        return response.profile
    }

    func exportUserData() async throws -> UserDataExport {
        let envelope = try await client.get("/v1/profile/export", as: UserDataExportEnvelope.self)
        return envelope.exportData
    }

    func deleteAccountData() async throws {
        _ = try await client.delete("/v1/profile", as: DeleteAccountDataResponse.self)
    }

    func sendChat(request: ChatRequest) async throws -> CoachReply {
        try await client.post("/v1/chat", body: request, as: CoachReply.self)
    }

    func streamChat(
        request: ChatRequest,
        onEvent: @MainActor @escaping (ChatStreamEvent) -> Void
    ) async throws {
        let bytes = try await client.streamPost("/v1/chat/stream", body: request)
        var currentEvent = "message"
        var dataLines: [String] = []

        func flushEvent() async throws {
            guard !dataLines.isEmpty else { return }
            let payload = dataLines.joined(separator: "\n")
            if let event = parseChatStreamEvent(event: currentEvent, payload: payload) {
                await onEvent(event)
            }
            currentEvent = "message"
            dataLines.removeAll(keepingCapacity: true)
        }

        for try await line in bytes.lines {
            if line.isEmpty {
                try await flushEvent()
                continue
            }

            if line.hasPrefix("event:") {
                currentEvent = line
                    .dropFirst("event:".count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }

            if line.hasPrefix("data:") {
                let data = line
                    .dropFirst("data:".count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                dataLines.append(data)
            }
        }

        try await flushEvent()
    }

    private func parseChatStreamEvent(event: String, payload: String) -> ChatStreamEvent? {
        guard let data = payload.data(using: .utf8) else { return nil }

        switch event {
        case "meta":
            guard let decoded = try? decoder.decode(ChatStreamMetaPayload.self, from: data) else {
                return nil
            }
            return .meta(decoded)
        case "token":
            guard let decoded = try? decoder.decode(ChatStreamTokenPayload.self, from: data) else {
                return nil
            }
            return .token(decoded.token)
        case "protocol":
            guard let decoded = try? decoder.decode(ProtocolPlan.self, from: data) else {
                return nil
            }
            return .protocolPlan(decoded)
        case "tasks":
            guard let decoded = try? decoder.decode(ChatTaskSync.self, from: data) else {
                return nil
            }
            return .tasks(decoded)
        case "done":
            guard let decoded = try? decoder.decode(ChatStreamDonePayload.self, from: data) else {
                return nil
            }
            return .done(decoded.message)
        default:
            return nil
        }
    }

    func submitWeeklyCheckin(_ request: WeeklyCheckinRequest) async throws -> WeeklyCheckinResponse {
        try await client.post("/v1/checkins/weekly", body: request, as: WeeklyCheckinResponse.self)
    }

    func fetchLifeScore() async throws -> LifeScoreBreakdown {
        try await client.get("/v1/lifescore", as: LifeScoreBreakdown.self)
    }

    func fetchHomeTaskQueue() async throws -> BackendTaskQueue {
        let envelope = try await client.get("/v1/tasks/home", as: BackendTaskQueueEnvelope.self)
        return envelope.queue
    }

    func fetchTaskSnapshot() async throws -> BackendTaskSnapshot {
        let envelope = try await client.get("/v1/tasks", as: BackendTaskSnapshotEnvelope.self)
        return envelope.snapshot
    }

    func fetchProtocolTasks(domain: MaxxDomain) async throws -> [BackendCoachingTask] {
        let envelope = try await client.get("/v1/tasks/protocol/\(domain.rawValue)", as: BackendProtocolTasksEnvelope.self)
        return envelope.tasks
    }

    func fetchMaxxDetail(domain: MaxxDomain) async throws -> BackendMaxxDetail {
        let envelope = try await client.get("/v1/maxx/\(domain.rawValue)", as: BackendMaxxDetailEnvelope.self)
        return envelope.detail
    }

    func mutateTask(_ request: TaskMutationRequestPayload) async throws -> BackendTaskMutationResponse {
        try await client.post(
            "/v1/tasks/mutate",
            body: request,
            as: BackendTaskMutationResponse.self
        )
    }

    func recordTaskEvent(taskId: String, action: TaskEventAction) async throws -> BackendCoachingTask {
        struct Request: Codable {
            let action: TaskEventAction
        }

        let response = try await client.post(
            "/v1/tasks/\(taskId)/events",
            body: Request(action: action),
            as: BackendTaskEventResponse.self
        )
        return response.task
    }
}
