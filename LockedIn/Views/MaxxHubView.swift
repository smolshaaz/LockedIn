import SwiftUI

struct MaxxHubView: View {
    @EnvironmentObject private var store: ExperienceStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Protocol OS")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(LockPalette.textPrimary)
                Text("Choose a domain lab and execute the next high-leverage move.")
                    .foregroundStyle(LockPalette.textMuted)

                ForEach(MaxxDomain.allCases) { domain in
                    NavigationLink {
                        DomainLabView(domain: domain)
                    } label: {
                        DomainCard(state: store.state(for: domain))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .lockScreenBackground()
        .navigationTitle("Maxx")
        .toolbarBackground(LockPalette.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

private struct DomainCard: View {
    let state: DomainOSState

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(LockPalette.stroke, lineWidth: 8)
                    .frame(width: 58, height: 58)

                Circle()
                    .trim(from: 0, to: CGFloat(state.compliance) / 100)
                    .stroke(LockPalette.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 58, height: 58)

                Text("\(state.compliance)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LockPalette.textPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(state.domain.title)
                    .font(.headline)
                    .foregroundStyle(LockPalette.textPrimary)
                Text("\(state.level) · Next: \(state.nextMove)")
                    .font(.caption)
                    .foregroundStyle(LockPalette.textMuted)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(LockPalette.textMuted)
        }
        .padding(14)
        .background(LockPalette.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(LockPalette.stroke, lineWidth: 1)
        )
    }
}

struct DomainLabView: View {
    @EnvironmentObject private var store: ExperienceStore

    let domain: MaxxDomain
    @State private var selectedSection: DomainLabSection = .protocolStack

    var state: DomainOSState {
        store.state(for: domain)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                Picker("Section", selection: $selectedSection) {
                    ForEach(DomainLabSection.allCases) { section in
                        Text(section.title).tag(section)
                    }
                }
                .pickerStyle(.segmented)

                sectionContent
            }
            .padding()
        }
        .lockScreenBackground()
        .navigationTitle(domain.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(LockPalette.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(state.level) · Compliance \(state.compliance)%")
                .font(.headline)
                .foregroundStyle(LockPalette.textPrimary)
            Text(state.nextMove)
                .font(.subheadline)
                .foregroundStyle(LockPalette.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(LockPalette.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(LockPalette.stroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .protocolStack:
            card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Protocol Stack")
                        .font(.headline)
                        .foregroundStyle(LockPalette.textPrimary)
                    ForEach(state.protocolStack, id: \.self) { item in
                        Label(item, systemImage: "bolt.fill")
                            .foregroundStyle(LockPalette.textSecondary)
                    }
                    Text("Upgrade trigger: complete 80% weekly compliance.")
                        .font(.caption)
                        .foregroundStyle(LockPalette.textMuted)
                }
            }

        case .dailyActions:
            card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Execution Queue")
                        .font(.headline)
                        .foregroundStyle(LockPalette.textPrimary)

                    ForEach(state.dailyActions) { action in
                        Button {
                            store.toggleDomainAction(domain: domain, actionID: action.id)
                        } label: {
                            HStack {
                                Image(systemName: action.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(action.isCompleted ? .green : LockPalette.textMuted)
                                Text(action.title)
                                    .foregroundStyle(LockPalette.textSecondary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

        case .metrics:
            card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Domain Metrics")
                        .font(.headline)
                        .foregroundStyle(LockPalette.textPrimary)
                    ForEach(state.metrics) { metric in
                        HStack {
                            Text(metric.title)
                                .foregroundStyle(LockPalette.textSecondary)
                            Spacer()
                            Text(metric.value)
                                .fontWeight(.semibold)
                                .foregroundStyle(LockPalette.accent)
                        }
                    }
                }
            }

        case .resources:
            card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Resources")
                        .font(.headline)
                        .foregroundStyle(LockPalette.textPrimary)
                    ForEach(state.resources, id: \.self) { resource in
                        Label(resource, systemImage: "book.closed.fill")
                            .foregroundStyle(LockPalette.textSecondary)
                    }
                }
            }

        case .reflection:
            card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reflection Prompts")
                        .font(.headline)
                        .foregroundStyle(LockPalette.textPrimary)
                    ForEach(state.reflections, id: \.self) { reflection in
                        Text("• \(reflection)")
                            .foregroundStyle(LockPalette.textSecondary)
                    }
                }
            }
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content().lockCard()
    }
}
