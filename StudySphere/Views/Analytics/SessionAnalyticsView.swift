import SwiftUI
import VISOR

@LazyViewModel(SessionAnalyticsViewModel.self)
struct SessionAnalyticsView: View {

    var content: some View {
        Group {
            if viewModel.latestSession != nil {
                analyticsContent
            } else {
                ContentUnavailableView(
                    "No Analytics Yet",
                    systemImage: "chart.bar",
                    description: Text("Complete a study session to see your analytics.")
                )
            }
        }
        .navigationTitle("Session Analytics")
    }

    // MARK: - Main content

    private var analyticsContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                focusMVPSection
                statCardsSection
                peerContributionsSection
                accountabilityPartnerSection
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Focus MVP

    private var focusMVPSection: some View {
        VStack(spacing: 16) {
            Text("FOCUS MVP")
                .font(.caption.weight(.heavy))
                .tracking(2)
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.cyan, .blue, .cyan],
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 108, height: 108)

                avatarView
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())

                Circle()
                    .fill(.tint)
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 38, y: 38)
            }

            VStack(spacing: 4) {
                Text(String(format: "%.1f%%", viewModel.overallSyncRate * 100))
                    .font(.title2.bold().monospacedDigit())
                Text("SYNC RATE")
                    .font(.caption2.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
            }

            Text("In flow for \(formattedDuration(viewModel.totalFlowTime))")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.tint.opacity(0.15), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private var avatarView: some View {
        if let image = viewModel.state.profileImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Stat cards

    private var statCardsSection: some View {
        HStack(spacing: 12) {
            milestonesCard
            recoveryCard
        }
    }

    private var milestonesCard: some View {
        let milestones = viewModel.collectiveMilestones
        return VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "scope")
                .font(.title3)
                .foregroundStyle(.tint)

            Text("COLLECTIVE\nMILESTONES")
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(milestones.completed)/\(milestones.total)")
                .font(.title3.bold().monospacedDigit())

            ProgressView(value: Double(milestones.completed), total: Double(milestones.total))
                .tint(.cyan)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var recoveryCard: some View {
        let delta = viewModel.recoveryTimeDelta
        return VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "bolt.fill")
                .font(.title3)
                .foregroundStyle(.tint)

            Text("GROUP\nRECOVERY TIME")
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(shortDuration(viewModel.groupRecoveryTime))
                .font(.title3.bold().monospacedDigit())

            HStack(spacing: 2) {
                Image(systemName: delta <= 0 ? "arrow.down" : "arrow.up")
                    .font(.caption2)
                Text("\(shortDuration(abs(delta))) from avg")
                    .font(.caption2)
            }
            .foregroundStyle(delta <= 0 ? .green : .orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Peer contributions

    private var peerContributionsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Peer Contributions")
                    .font(.headline)
                Spacer()
            }

            ForEach(viewModel.peerContributions) { participant in
                PeerContributionRow(participant: participant)
            }
        }
    }

    // MARK: - Accountability partner

    @ViewBuilder
    private var accountabilityPartnerSection: some View {
        if let partner = viewModel.topAccountabilityPartner {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .frame(width: 40, height: 40)
                        .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accountability Partner")
                            .font(.subheadline.bold())
                        Text("You and \(partner.name) have focused together for \(viewModel.totalPeerFocusHours) hours this week.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    // Nudge action placeholder
                } label: {
                    Text("Nudge Team")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(16)
            .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Formatting

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func shortDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let minutes = total / 60
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Peer Contribution Row

private struct PeerContributionRow: View {
    let participant: ParticipantAnalytics

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.fill.tertiary)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundStyle(.secondary)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(participant.name)
                    .font(.subheadline.bold())
                Text(activityPhase)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.0f%%", participant.focusScore * 100))
                    .font(.subheadline.bold().monospacedDigit())

                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(.tint.opacity(0.3))
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(.tint)
                                .frame(width: proxy.size.width * participant.focusScore)
                        }
                }
                .frame(width: 48, height: 6)
            }
        }
        .padding(12)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var activityPhase: String {
        switch participant.focusScore {
        case 0.85...: "Deep Work Phase"
        case 0.65..<0.85: "Active Sprint"
        default: "Recovery Mode"
        }
    }
}
