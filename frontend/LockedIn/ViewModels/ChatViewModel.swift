import Foundation
import Combine

struct ChatBubble: Identifiable {
    let id = UUID()
    let role: String
    var content: String
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var draft = ""
    @Published var wantsProtocol = false
    @Published var selectedDomain: MaxxDomain? {
        didSet {
            guard let selectedDomain else { return }
            addSelectedDomain(selectedDomain)
        }
    }
    @Published private(set) var selectedDomains: [MaxxDomain] = []
    @Published var messages: [ChatBubble] = [
        ChatBubble(role: "assistant", content: "LOCK online. Give me your objective and your current bottleneck.")
    ]
    @Published var isSending = false
    @Published var errorMessage: String?

    private let api: LockedInAPIService

    init(api: LockedInAPIService) {
        self.api = api
    }

    func registerMentionedDomain(_ domain: MaxxDomain) {
        selectedDomain = domain
        wantsProtocol = true
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatBubble(role: "user", content: text))
        let assistantIndex = messages.count
        messages.append(ChatBubble(role: "assistant", content: ""))
        draft = ""
        errorMessage = nil
        isSending = true
        defer { isSending = false }

        do {
            let request = ChatRequest(
                threadId: "main-thread",
                message: text,
                context: buildContext(for: text)
            )

            var streamedText = ""
            var doneMessage: String?

            try await api.streamChat(request: request) { [weak self] event in
                guard let self else { return }

                switch event {
                case .meta:
                    break
                case .token(let token):
                    streamedText += token
                    self.updateAssistantMessage(at: assistantIndex, content: streamedText)
                case .protocolPlan(let protocolPlan):
                    self.messages.append(
                        ChatBubble(
                            role: "assistant",
                            content: self.renderProtocol(protocolPlan)
                        )
                    )
                case .tasks(let taskSync):
                    self.messages.append(
                        ChatBubble(
                            role: "assistant",
                            content: "Task sync: \(taskSync.autoActivated.count) active, \(taskSync.createdDrafts.count) draft."
                        )
                    )
                case .done(let message):
                    doneMessage = message
                }
            }

            if streamedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               (doneMessage?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
                let fallback = try await api.sendChat(request: request)
                let fallbackText = fallback.message.trimmingCharacters(in: .whitespacesAndNewlines)
                if !fallbackText.isEmpty {
                    updateAssistantMessage(at: assistantIndex, content: fallbackText)
                }
            }

            if let doneMessage,
               !doneMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updateAssistantMessage(at: assistantIndex, content: doneMessage)
            }

            if messages.indices.contains(assistantIndex),
               messages[assistantIndex].content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                messages[assistantIndex].content = "No response generated."
            }
        } catch {
            if messages.indices.contains(assistantIndex),
               messages[assistantIndex].content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                messages.remove(at: assistantIndex)
            }
            let friendly = presentableErrorMessage(from: error)
            errorMessage = friendly
            messages.append(ChatBubble(role: "assistant", content: "Request failed: \(friendly)"))
        }
    }

    private func renderProtocol(_ protocolPlan: ProtocolPlan) -> String {
        let steps = protocolPlan.steps.map { "- \($0.title): \($0.action)" }.joined(separator: "\n")
        return "Protocol (\(protocolPlan.horizonDays)d): \(protocolPlan.objective)\n\(steps)"
    }

    private func updateAssistantMessage(at index: Int, content: String) {
        guard messages.indices.contains(index) else { return }
        messages[index].content = content
    }

    private func buildContext(for message: String) -> ChatContext {
        let mentioned = extractMentionedDomains(from: message)
        var merged = selectedDomains
        if let selectedDomain {
            merged.append(selectedDomain)
        }
        merged.append(contentsOf: mentioned)
        let domains = uniqueDomains(merged)
        let inferredWantsProtocol = wantsProtocol || !domains.isEmpty || requestsProtocol(message)

        return ChatContext(
            wantsProtocol: inferredWantsProtocol,
            urgency: .normal,
            domain: domains.first,
            domains: domains.isEmpty ? nil : domains,
            urgencyByDomain: nil
        )
    }

    private func requestsProtocol(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("protocol")
            || normalized.contains("plan")
            || normalized.contains("roadmap")
            || normalized.contains("task")
            || normalized.contains("maxx")
    }

    private func addSelectedDomain(_ domain: MaxxDomain) {
        if !selectedDomains.contains(domain) {
            selectedDomains.append(domain)
        }
    }

    private func uniqueDomains(_ domains: [MaxxDomain]) -> [MaxxDomain] {
        var seen = Set<MaxxDomain>()
        var ordered: [MaxxDomain] = []
        for domain in domains {
            if seen.contains(domain) { continue }
            seen.insert(domain)
            ordered.append(domain)
        }
        return ordered
    }

    private func extractMentionedDomains(from message: String) -> [MaxxDomain] {
        let tokens = message.split(whereSeparator: \.isWhitespace)
        var domains: [MaxxDomain] = []

        for token in tokens {
            guard token.hasPrefix("@") else { continue }
            let raw = token.dropFirst()
            let cleaned = raw.prefix { character in
                character.isLetter || character.isNumber || character == "_" || character == "-"
            }

            guard !cleaned.isEmpty else { continue }
            if let domain = domainFromMention(String(cleaned)) {
                domains.append(domain)
            }
        }

        return uniqueDomains(domains)
    }

    private func domainFromMention(_ token: String) -> MaxxDomain? {
        let normalized = token
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)

        switch normalized {
        case "gym", "gymmaxx", "fitness", "workout", "training":
            return .gym
        case "face", "facemaxx", "looks", "skin", "grooming":
            return .face
        case "money", "moneymaxx", "finance", "income", "career":
            return .money
        case "mind", "mindmaxx", "focus", "mental", "mindset":
            return .mind
        case "social", "socialmaxx", "network", "friends", "relationship":
            return .social
        default:
            return nil
        }
    }

    private func presentableErrorMessage(from error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("429") || message.contains("quota") || message.contains("rate limit") {
            return "Model quota reached. Wait a bit, then retry with one short message."
        }
        if message.contains("cannot connect")
            || message.contains("timed out")
            || message.contains("network")
            || message.contains("offline") {
            return "Cannot reach backend. Check LOCK_API_BASE_URL and server health."
        }
        return error.localizedDescription
    }
}
