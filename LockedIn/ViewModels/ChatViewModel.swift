import Foundation
import Combine

struct ChatBubble: Identifiable {
    let id = UUID()
    let role: String
    let content: String
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var draft = ""
    @Published var wantsProtocol = false
    @Published var selectedDomain: MaxxDomain?
    @Published var messages: [ChatBubble] = [
        ChatBubble(role: "assistant", content: "LOCK online. Give me your objective and your current bottleneck.")
    ]
    @Published var isSending = false
    @Published var errorMessage: String?

    private let api: LockedInAPIService

    init(api: LockedInAPIService) {
        self.api = api
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatBubble(role: "user", content: text))
        draft = ""
        isSending = true
        defer { isSending = false }

        do {
            let request = ChatRequest(
                threadId: "main-thread",
                message: text,
                context: ChatContext(wantsProtocol: wantsProtocol, urgency: "normal", domain: selectedDomain)
            )

            let reply = try await api.sendChat(request: request)
            messages.append(ChatBubble(role: "assistant", content: reply.message))

            if let protocolPlan = reply.suggestedProtocol {
                let steps = protocolPlan.steps.map { "- \($0.title): \($0.action)" }.joined(separator: "\n")
                messages.append(
                    ChatBubble(
                        role: "assistant",
                        content: "Protocol (\(protocolPlan.horizonDays)d): \(protocolPlan.objective)\n\(steps)"
                    )
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            messages.append(ChatBubble(role: "assistant", content: "Request failed. Fix the bottleneck and try again."))
        }
    }
}
