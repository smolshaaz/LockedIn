import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var store: ExperienceStore

    @ObservedObject var vm: ChatViewModel

    @FocusState private var isComposerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(vm.messages) { message in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(message.role.uppercased())
                                .font(.caption2)
                                .foregroundStyle(LockPalette.textMuted)

                            Text(message.content)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(message.role == "assistant" ? LockPalette.card : LockPalette.cardAlt)
                                .foregroundStyle(LockPalette.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(message.role == "assistant" ? LockPalette.accent.opacity(0.7) : LockPalette.stroke, lineWidth: 1)
                                )
                        }
                    }
                }
                .padding()
            }

            Divider()
                .overlay(LockPalette.stroke)

            VStack(alignment: .leading, spacing: 10) {
                composerSection

                if let error = vm.errorMessage {
                    Text(error)
                        .foregroundStyle(LockPalette.accent)
                        .font(.caption)
                }
            }
            .padding()
            .background(LockPalette.background)
        }
        .lockScreenBackground()
        .navigationTitle("LOCK")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(LockPalette.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var composerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            composerInput

            HStack {
                Spacer(minLength: 0)
                sendButton
            }
        }
        .padding(10)
        .background(LockPalette.cardAlt)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isComposerFocused ? LockPalette.accent.opacity(0.65) : LockPalette.stroke, lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            if mentionQuery != nil {
                mentionSuggestionsCard
                    .frame(maxHeight: 220)
                    .offset(y: -228)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .zIndex(3)
            }
        }
        .animation(.easeOut(duration: 0.16), value: mentionQuery != nil)
        .animation(.easeOut(duration: 0.12), value: mentionQuery ?? "")
    }

    private var composerInput: some View {
        TextField("Talk to LOCK...", text: $vm.draft, axis: .vertical)
            .focused($isComposerFocused)
            .lineLimit(1...4)
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled(false)
            .foregroundStyle(LockPalette.textPrimary)
            .tint(LockPalette.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Message input")
    }

    private var sendButton: some View {
        Button {
            Task { await vm.send() }
        } label: {
            ZStack {
                Circle()
                    .fill(canSend ? LockPalette.accent : LockPalette.card)
                    .frame(width: 44, height: 44)

                if vm.isSending {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .accessibilityLabel("Send message")
    }

    private var canSend: Bool {
        !vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !vm.isSending
    }

    private var mentionSuggestionsCard: some View {
        let options = mentionOptions

        return VStack(alignment: .leading, spacing: 0) {
            if options.isEmpty {
                Text("No matching Maxx")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LockPalette.textMuted)
                    .padding(12)
            } else {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, card in
                    Button {
                        insertMention(for: card.domain)
                    } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(LockPalette.accent)
                                .frame(width: 8, height: 8)

                            Text(card.domain.title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(LockPalette.textPrimary)

                            Spacer()

                            Text(card.statusTone.label.lowercased())
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(LockPalette.textMuted)
                        }
                        .frame(minHeight: 44)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)

                    if index != options.count - 1 {
                        Divider()
                            .overlay(LockPalette.stroke)
                    }
                }
            }
        }
        .background(LockPalette.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(LockPalette.stroke, lineWidth: 1)
        )
    }

    private var mentionQuery: String? {
        activeMention?.query
    }

    private var mentionOptions: [ProtocolCardViewState] {
        guard let query = mentionQuery else { return [] }
        let cards = store.protocolCards()

        if query.isEmpty {
            return cards
        }

        let normalized = query.lowercased()
        return cards.filter { card in
            card.domain.title.lowercased().contains(normalized) ||
            card.domain.shortTitle.lowercased().contains(normalized) ||
            card.domain.rawValue.lowercased().contains(normalized)
        }
    }

    private var activeMention: (range: Range<String.Index>, query: String)? {
        guard let atIndex = vm.draft.lastIndex(of: "@") else { return nil }

        if atIndex > vm.draft.startIndex {
            let previousCharacter = vm.draft[vm.draft.index(before: atIndex)]
            guard previousCharacter.isWhitespace else { return nil }
        }

        let suffixStart = vm.draft.index(after: atIndex)
        let suffix = vm.draft[suffixStart..<vm.draft.endIndex]

        if suffix.contains(where: { $0.isWhitespace || $0 == "@" }) {
            return nil
        }

        if suffix.contains(where: { !isValidMentionCharacter($0) }) {
            return nil
        }

        let query = String(suffix)
        guard query.count <= 24 else { return nil }

        return (atIndex..<vm.draft.endIndex, query)
    }

    private func insertMention(for domain: MaxxDomain) {
        guard let mentionRange = activeMention?.range else { return }
        vm.draft.replaceSubrange(mentionRange, with: "@\(domain.title) ")
        vm.registerMentionedDomain(domain)
    }

    private func isValidMentionCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_" || character == "-"
    }

}
