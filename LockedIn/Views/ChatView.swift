import SwiftUI

struct ChatView: View {
    @ObservedObject var vm: ChatViewModel
    let currentObjective: String?

    @State private var showContextRow = false

    var body: some View {
        VStack(spacing: 0) {
            if showContextRow {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current objective: \(currentObjective ?? "Set this in quick setup")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LockPalette.textPrimary)
                    Text("Protocol version: v1.0 · Direct mode active")
                        .font(.caption)
                        .foregroundStyle(LockPalette.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(LockPalette.card)
            }

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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        contextChip(
                            title: vm.wantsProtocol ? "Protocol On" : "Protocol Off",
                            isActive: vm.wantsProtocol
                        ) {
                            vm.wantsProtocol.toggle()
                        }

                        ForEach(MaxxDomain.allCases) { domain in
                            contextChip(
                                title: domain.shortTitle,
                                isActive: vm.selectedDomain == domain
                            ) {
                                vm.selectedDomain = (vm.selectedDomain == domain) ? nil : domain
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Message LOCK", text: $vm.draft, axis: .vertical)
                        .padding(12)
                        .background(LockPalette.cardAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(LockPalette.textPrimary)

                    Button(vm.isSending ? "..." : "Send") {
                        Task { await vm.send() }
                    }
                    .buttonStyle(LockPrimaryButtonStyle())
                    .frame(width: 88)
                    .disabled(vm.isSending)
                }

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(showContextRow ? "Hide Context" : "Show Context") {
                    showContextRow.toggle()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(LockPalette.accent)
            }
        }
    }

    private func contextChip(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(isActive ? LockPalette.accent : LockPalette.cardAlt)
                .foregroundStyle(LockPalette.textPrimary)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(LockPalette.stroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
